# Error Handling Guide

This guide covers the SkyEcho library's error hierarchy, recovery patterns, and best practices for robust error handling.

## Table of Contents

1. [Error Hierarchy](#error-hierarchy)
2. [Error Types](#error-types)
3. [Catching Errors](#catching-errors)
4. [Recovery Patterns](#recovery-patterns)
5. [Best Practices](#best-practices)
6. [Common Scenarios](#common-scenarios)

## Error Hierarchy

All errors thrown by the SkyEcho library extend `SkyEchoError`, which provides:

- **`message`**: Descriptive error message explaining what went wrong
- **`hint`**: Optional actionable guidance to resolve the issue

```dart
abstract class SkyEchoError implements Exception {
  final String message;
  final String? hint;

  @override
  String toString() {
    if (hint == null || hint!.isEmpty) {
      return message;
    }
    return '$message\nHint: $hint';
  }
}
```

### Error Type Hierarchy

```
SkyEchoError (abstract base)
├── SkyEchoNetworkError    (connection, timeout, DNS)
├── SkyEchoHttpError       (4xx, 5xx status codes)
├── SkyEchoParseError      (JSON parsing, missing fields)
└── SkyEchoFieldError      (validation, invalid values)
```

**Key Design Principle**: All library errors extend `SkyEchoError`, enabling unified error handling while preserving specificity.

## Error Types

### SkyEchoNetworkError

**When Thrown**: Network operations fail before receiving HTTP response.

**Common Causes**:
- Device not reachable (wrong IP, not connected to WiFi)
- Connection timeout
- DNS resolution failure
- Network interface down

**Example**:

```dart
try {
  await client.ping();
} on SkyEchoNetworkError catch (e) {
  print(e.message); // "Network error: Connection refused"
  print(e.hint);    // "Check WiFi connection and device IP address"
}
```

**Real-World Examples**:

```dart
// Not connected to SkyEcho WiFi
SkyEchoNetworkError(
  'Network error: No route to host',
  hint: 'Check WiFi connection and device IP address',
)

// Device powered off
SkyEchoNetworkError(
  'Network error: Connection refused',
  hint: 'Check WiFi connection and device IP address',
)

// Timeout (slow network, device overloaded)
SkyEchoNetworkError(
  'Network error: Timeout',
  hint: 'Check WiFi connection and device IP address',
)
```

### SkyEchoHttpError

**When Thrown**: HTTP request completes but returns error status code.

**Common Causes**:
- 404 Not Found (wrong endpoint, firmware change)
- 500 Internal Server Error (device firmware crash)
- 503 Service Unavailable (device overloaded)

**Example**:

```dart
try {
  final status = await client.fetchStatus();
} on SkyEchoHttpError catch (e) {
  print(e.message); // "HTTP 404: Not Found"
  print(e.hint);    // "Ensure device is powered on and accessible at http://192.168.4.1"
}
```

**Real-World Examples**:

```dart
// Endpoint not found (firmware version mismatch?)
SkyEchoHttpError(
  'HTTP 404: Not Found',
  hint: 'Ensure device is powered on and accessible at http://192.168.4.1',
)

// Device internal error
SkyEchoHttpError(
  'HTTP 500: Internal Server Error',
  hint: 'Ensure device is powered on and accessible at http://192.168.4.1',
)
```

### SkyEchoParseError

**When Thrown**: Response received but JSON structure is invalid or unexpected.

**Common Causes**:
- Firmware version mismatch (API changed)
- Corrupted response
- Device returned HTML instead of JSON (error page)

**Example**:

```dart
try {
  final status = await client.fetchStatus();
} on SkyEchoParseError catch (e) {
  print(e.message); // "Failed to parse JSON response: Unexpected token"
  print(e.hint);    // "Device may have returned invalid JSON. Check device firmware."
}
```

**Real-World Examples**:

```dart
// JSON syntax error
SkyEchoParseError(
  'Failed to parse JSON response: FormatException: Unexpected character',
  hint: 'Device may have returned invalid JSON. Check device firmware.',
)

// Missing required field
SkyEchoParseError(
  'Failed to parse DeviceStatus from JSON: type \'Null\' is not a subtype of type \'String\'',
  hint: 'Ensure JSON has expected structure from GET /?action=get',
)

// Wrong structure
SkyEchoParseError(
  'Failed to parse SetupConfig from JSON: Field "setup" not found',
  hint: 'Ensure JSON has structure from GET /setup/?action=get',
)
```

### SkyEchoFieldError

**When Thrown**: Configuration field validation fails.

**Common Causes**:
- Invalid ICAO address (wrong length, blacklisted)
- Invalid callsign (too long, special characters)
- Out-of-range values (squawk code, stall speed)

**Example**:

```dart
try {
  final result = await client.applySetup((u) => u
    ..icaoAddress = '000000' // Blacklisted!
  );
} on SkyEchoFieldError catch (e) {
  print(e.message); // "ICAO address 000000 is reserved and invalid"
  print(e.hint);    // "Use a valid ICAO address (not 000000 or FFFFFF)"
}
```

**Real-World Examples**:

```dart
// Blacklisted ICAO
SkyEchoFieldError(
  'ICAO address 000000 is reserved and invalid',
  hint: 'Use a valid ICAO address (not 000000 or FFFFFF)',
)

// Invalid callsign length
SkyEchoFieldError(
  'Callsign too long: 9 characters (max 8)',
  hint: 'Shorten to 8 characters or less',
)

// Invalid squawk code (digit 8 not allowed in octal)
SkyEchoFieldError(
  'VFR squawk contains invalid digits: 1288',
  hint: 'Each digit must be 0-7 (octal), no 8 or 9 allowed',
)

// Odd longitude offset (device truncates to even)
SkyEchoFieldError(
  'GPS lon offset must be even: 7 meters',
  hint: 'Device truncates odd values. Use even (0, 2, 4, ...30)',
)
```

## Catching Errors

### Catch Specific Error Types

Catch specific error types when you have tailored recovery logic:

```dart
try {
  await client.ping();
} on SkyEchoNetworkError catch (e) {
  // Network-specific recovery
  print('Cannot reach device. Check WiFi connection.');
  return RetryResult.retry;
} on SkyEchoHttpError catch (e) {
  // HTTP-specific recovery
  print('Device returned HTTP error. May be overloaded.');
  return RetryResult.abort;
}
```

### Catch Base Error Type

Catch `SkyEchoError` when recovery logic is the same for all error types:

```dart
try {
  final status = await client.fetchStatus();
  print('Status: ${status.ssid}');
} on SkyEchoError catch (e) {
  print('Failed to fetch status: $e'); // toString() includes hint
  showErrorDialog(e.message, e.hint);
}
```

### Access Error Details

Extract message and hint separately:

```dart
try {
  await client.applySetup((u) => u..callsign = 'TOOLONG123');
} on SkyEchoFieldError catch (e) {
  print('Validation failed: ${e.message}');
  if (e.hint != null) {
    print('Suggestion: ${e.hint}');
  }
}
```

### Chain Error Handlers

Handle different error types with different strategies:

```dart
try {
  await client.ping();
} on SkyEchoNetworkError catch (e) {
  logger.error('Network failure', error: e);
  return NetworkStatus.unreachable;
} on SkyEchoHttpError catch (e) {
  logger.error('HTTP failure', error: e);
  return NetworkStatus.httpError;
} on SkyEchoParseError catch (e) {
  logger.error('Parse failure', error: e);
  return NetworkStatus.protocolError;
} on SkyEchoError catch (e) {
  logger.error('Unknown SkyEcho error', error: e);
  return NetworkStatus.unknownError;
}
```

## Recovery Patterns

### Pattern 1: Retry with Exponential Backoff

For transient network errors:

```dart
Future<DeviceStatus?> fetchStatusWithRetry({
  int maxAttempts = 3,
  Duration initialDelay = const Duration(seconds: 1),
}) async {
  int attempt = 0;
  Duration delay = initialDelay;

  while (attempt < maxAttempts) {
    try {
      return await client.fetchStatus();
    } on SkyEchoNetworkError catch (e) {
      attempt++;
      if (attempt >= maxAttempts) {
        print('Max retries exceeded: $e');
        rethrow;
      }
      print('Retry $attempt/$maxAttempts after ${delay.inSeconds}s...');
      await Future.delayed(delay);
      delay *= 2; // Exponential backoff
    }
  }
  return null;
}
```

### Pattern 2: Fallback to Cached Data

When real-time data isn't critical:

```dart
Future<DeviceStatus> fetchStatusOrCached() async {
  try {
    final status = await client.fetchStatus();
    _cache.store('status', status);
    return status;
  } on SkyEchoError catch (e) {
    print('Using cached status due to error: ${e.message}');
    final cached = _cache.get('status');
    if (cached != null) {
      return cached;
    }
    rethrow; // No cache available
  }
}
```

### Pattern 3: Graceful Degradation

Show partial UI when some operations fail:

```dart
Future<void> loadDeviceInfo() async {
  // Try to fetch status
  DeviceStatus? status;
  try {
    status = await client.fetchStatus();
  } on SkyEchoError catch (e) {
    print('Status unavailable: ${e.message}');
  }

  // Try to fetch config
  SetupConfig? config;
  try {
    config = await client.fetchSetupConfig();
  } on SkyEchoError catch (e) {
    print('Config unavailable: ${e.message}');
  }

  // Show what we got
  showUI(status: status, config: config);
}
```

### Pattern 4: User Prompts for Validation Errors

Let user fix validation errors:

```dart
Future<void> updateCallsign(String callsign) async {
  while (true) {
    try {
      await client.applySetup((u) => u..callsign = callsign);
      print('Callsign updated successfully!');
      break;
    } on SkyEchoFieldError catch (e) {
      print('Invalid callsign: ${e.message}');
      print('Hint: ${e.hint}');

      // Prompt user for new value
      final newCallsign = await promptUser('Enter new callsign:');
      if (newCallsign == null) {
        print('Update cancelled.');
        break;
      }
      callsign = newCallsign;
    }
  }
}
```

### Pattern 5: Pre-Validation

Validate before sending to device:

```dart
Future<void> safeApplyConfig(SetupUpdate update) async {
  // Build config manually to validate first
  final currentConfig = await client.fetchSetupConfig();
  final newConfig = currentConfig.copyWith(
    icaoAddress: update.icaoAddress,
    callsign: update.callsign,
    vfrSquawk: update.vfrSquawk,
    // ... other fields
  );

  try {
    // Validate locally before network call
    newConfig.validate();
  } on SkyEchoFieldError catch (e) {
    print('Validation failed: ${e.message}');
    print('Hint: ${e.hint}');
    return; // Don't send invalid config
  }

  // Validation passed, safe to send
  await client.applySetup((u) {
    // Apply update fields
  });
}
```

## Best Practices

### 1. Always Catch SkyEcho Errors

Never let SkyEcho errors propagate uncaught:

```dart
// BAD: Uncaught error crashes app
void fetchAndPrint() async {
  final status = await client.fetchStatus();
  print(status.ssid);
}

// GOOD: Handle errors gracefully
void fetchAndPrint() async {
  try {
    final status = await client.fetchStatus();
    print(status.ssid);
  } on SkyEchoError catch (e) {
    print('Error: $e');
  }
}
```

### 2. Display Hints to Users

Hints provide actionable guidance - show them:

```dart
try {
  await client.ping();
} on SkyEchoError catch (e) {
  showErrorDialog(
    title: 'Connection Failed',
    message: e.message,
    suggestion: e.hint ?? 'Check device and try again',
  );
}
```

### 3. Log Errors for Debugging

Include error details in logs:

```dart
try {
  await client.applySetup((u) => u..callsign = callsign);
} on SkyEchoError catch (e) {
  logger.error(
    'Failed to update callsign',
    error: e.message,
    hint: e.hint,
    stackTrace: StackTrace.current,
  );
  rethrow;
}
```

### 4. Validate Early

Validate user input before network calls:

```dart
// BAD: Network call before validation
Future<void> updateSquawk(int squawk) async {
  await client.applySetup((u) => u..vfrSquawk = squawk);
  // Error only discovered after network roundtrip
}

// GOOD: Validate first
Future<void> updateSquawk(int squawk) async {
  // Validate locally (fast, no network)
  SkyEchoValidation.validateVfrSquawk(squawk);

  // Validation passed, now make network call
  await client.applySetup((u) => u..vfrSquawk = squawk);
}
```

### 5. Provide Context in Error Messages

When rethrowing, add context:

```dart
Future<void> saveUserPreferences(UserConfig userConfig) async {
  try {
    await client.applySetup((u) => u
      ..callsign = userConfig.callsign
      ..vfrSquawk = userConfig.squawk
    );
  } on SkyEchoFieldError catch (e) {
    throw Exception(
      'Failed to save preferences: ${e.message}\n'
      'User input: callsign="${userConfig.callsign}", squawk=${userConfig.squawk}'
    );
  }
}
```

### 6. Handle Timeout Errors Specially

Network timeouts may need longer retry delays:

```dart
try {
  await client.fetchStatus();
} on SkyEchoNetworkError catch (e) {
  if (e.message.contains('Timeout')) {
    // Device may be overloaded, wait longer
    await Future.delayed(Duration(seconds: 5));
    return await client.fetchStatus(); // Retry once
  }
  rethrow;
}
```

## Common Scenarios

### Scenario 1: First-Time Device Connection

User may not be connected to device WiFi:

```dart
Future<void> initialConnection() async {
  try {
    await client.ping();
    print('Connected to device!');
  } on SkyEchoNetworkError catch (e) {
    print('Cannot reach device.');
    print('');
    print('Please ensure:');
    print('1. SkyEcho device is powered on');
    print('2. You are connected to SkyEcho WiFi (SSID: SkyEcho_XXXX)');
    print('3. Device IP is correct (default: http://192.168.4.1)');
    print('');
    print('Error details: ${e.message}');
  }
}
```

### Scenario 2: Configuration Update with Validation

Validate and provide clear feedback:

```dart
Future<void> updateDeviceConfig(String icao, String callsign) async {
  try {
    // Pre-validate to fail fast
    SkyEchoValidation.validateIcaoHex(icao);
    SkyEchoValidation.validateCallsign(callsign);

    // Apply config
    final result = await client.applySetup((u) => u
      ..icaoAddress = icao
      ..callsign = callsign
    );

    if (result.verified) {
      print('Configuration updated successfully!');
    } else {
      print('Warning: Update sent but verification failed');
    }
  } on SkyEchoFieldError catch (e) {
    print('Invalid configuration:');
    print('  ${e.message}');
    print('  ${e.hint}');
  } on SkyEchoNetworkError catch (e) {
    print('Network error during update:');
    print('  ${e.message}');
    print('  ${e.hint}');
    print('');
    print('Configuration may not have been applied.');
  }
}
```

### Scenario 3: Polling for Device Status

Robust polling with error handling:

```dart
Future<void> pollDeviceStatus() async {
  while (true) {
    try {
      final status = await client.fetchStatus();
      print('Status: ${status.isHealthy ? "Healthy" : "Unhealthy"}');
    } on SkyEchoNetworkError catch (e) {
      print('Device unreachable: ${e.message}');
    } on SkyEchoError catch (e) {
      print('Error: ${e.message}');
    }

    // Poll every 5 seconds
    await Future.delayed(Duration(seconds: 5));
  }
}
```

### Scenario 4: Batch Configuration Updates

Apply multiple updates with rollback on failure:

```dart
Future<void> batchUpdate(List<SetupUpdate> updates) async {
  // Save original config for rollback
  final original = await client.fetchSetupConfig();

  for (final update in updates) {
    try {
      await client.applySetup((u) {
        // Apply update fields
      });
    } on SkyEchoError catch (e) {
      print('Update failed: ${e.message}');
      print('Rolling back to original configuration...');

      try {
        // Restore original config
        await client.applySetup((u) {
          // Apply original fields
        });
        print('Rollback successful');
      } on SkyEchoError catch (rollbackError) {
        print('CRITICAL: Rollback failed: ${rollbackError.message}');
      }

      rethrow;
    }
  }
}
```

## Testing Error Handling

See the [Testing Guide](testing-guide.md) for details on testing error scenarios with `MockClient`.

Example:

```dart
test('given_network_error_when_fetching_status_then_throws_network_error', () {
  // Arrange
  final mockClient = MockClient((request) async {
    throw http.ClientException('Connection refused');
  });
  final client = SkyEchoClient('http://test', httpClient: mockClient);

  // Act & Assert
  expectLater(
    client.fetchStatus(),
    throwsA(isA<SkyEchoNetworkError>()),
  );
});
```

## Reference: Validation Rules

Quick reference for field validation rules (throws `SkyEchoFieldError`):

| Field | Rule | Example Error |
|-------|------|---------------|
| ICAO Address | 6 hex chars, not 000000/FFFFFF | "ICAO address must be exactly 6 hex characters" |
| Callsign | 1-8 alphanumeric, no spaces | "Callsign too long: 9 characters (max 8)" |
| VFR Squawk | 0000-7777 octal | "VFR squawk contains invalid digits: 1288" |
| Emitter Category | 0-7, 9-12, 14-15, 17-21 | "Invalid emitter category: 8" |
| Stall Speed | 0-127 knots | "Stall speed out of range: 150 knots" |
| GPS Lat Offset | 0-7 | "GPS lat offset out of range: 10 (must be 0-7)" |
| GPS Lon Offset | 0-31 meters, even only | "GPS lon offset must be even: 7 meters" |
| Aircraft Length | 0-7 | "Aircraft length out of range: 8 (must be 0-7)" |
| Aircraft Width | 0-1 | "Aircraft width out of range: 2 (must be 0 or 1)" |

For complete validation logic, see `SkyEchoValidation` class in `lib/skyecho.dart`.
