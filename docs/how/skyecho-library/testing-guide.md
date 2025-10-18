# Testing Guide

This guide covers how to write tests for SkyEcho library integrations using Test-Assisted Development (TAD) methodology.

## Table of Contents

1. [Testing Philosophy: TAD](#testing-philosophy-tad)
2. [Test Doc Format](#test-doc-format)
3. [Unit Testing](#unit-testing)
4. [Integration Testing](#integration-testing)
5. [Mocking Strategies](#mocking-strategies)
6. [Example Tests](#example-tests)
7. [Coverage Goals](#coverage-goals)

## Testing Philosophy: TAD

This project uses **Test-Assisted Development (TAD)**, not traditional Test-Driven Development (TDD).

### TAD vs TDD

| Aspect | TDD | TAD |
|--------|-----|-----|
| When | Write tests BEFORE code | Write tests DURING/AFTER code |
| Purpose | Drive design | Document and verify behavior |
| Coverage | 100% by default | Targeted (critical paths, edge cases) |
| Test Lifecycle | All tests permanent | Scratch → Promote workflow |

### The Scratch → Promote Workflow

1. **Scratch Phase**: Write exploratory tests in `test/scratch/` (gitignored)
   - Quick experiments
   - Debug specific behaviors
   - Validate assumptions

2. **Promote Phase**: Move valuable tests to `test/unit/` or `test/integration/`
   - Tests that prevent regressions
   - Tests for critical paths
   - Tests for opaque/complex behavior
   - Tests for edge cases

3. **Delete Phase**: Delete scratch tests that don't add durable value
   - Trivial tests (e.g., "constructor sets field")
   - One-off debugging probes
   - Tests duplicating existing coverage

### Promotion Criteria

Promote a test if it meets ANY of these:

- **Critical Path**: Tests core functionality (ping, fetchStatus, applySetup)
- **Opaque Behavior**: Documents non-obvious logic (bitmask unpacking, stall speed conversion)
- **Regression-Prone**: Prevents known bugs (HTTP keep-alive workaround)
- **Edge Case**: Tests boundary conditions (blacklisted ICAO, octal squawk validation)

## Test Doc Format

**Every promoted test MUST include a Test Doc comment** with 5 required fields:

```dart
test('given_valid_json_when_parsing_status_then_extracts_all_fields', () {
  /*
  Test Doc:
  - Why: Validates core JSON parsing logic for device status endpoint
  - Contract: DeviceStatus.fromJson returns non-null status with populated fields
  - Usage Notes: Pass complete JSON structure; parser tolerates missing optional fields
  - Quality Contribution: Catches API structure changes; documents expected JSON format
  - Worked Example: {"wifiVersion": "0.2.41"} → status.wifiVersion = "0.2.41"
  */

  // Arrange-Act-Assert with clear phases
});
```

### The 5 Required Fields

1. **Why**: Explains why this test exists (what behavior it verifies)
   - Example: "Validates core JSON parsing logic for device status endpoint"

2. **Contract**: States the expected behavior/guarantee
   - Example: "DeviceStatus.fromJson returns non-null status with populated fields"

3. **Usage Notes**: How to use the tested API correctly
   - Example: "Pass complete JSON structure; parser tolerates missing optional fields"

4. **Quality Contribution**: What quality issues this test prevents
   - Example: "Catches API structure changes; documents expected JSON format"

5. **Worked Example**: Concrete input → output example
   - Example: `{"wifiVersion": "0.2.41"} → status.wifiVersion = "0.2.41"`

### Test Naming Convention

Use `given_when_then` pattern:

```
given_<precondition>_when_<action>_then_<expected_result>
```

Examples:
- `given_valid_json_when_parsing_status_then_extracts_all_fields`
- `given_network_error_when_fetching_status_then_throws_network_error`
- `given_blacklisted_icao_when_validating_then_throws_field_error`

## Unit Testing

Unit tests run **fast** (< 5 seconds total), **offline** (no network), and use **mocks** for HTTP.

### Setting Up MockClient

Use `MockClient` from `package:http/testing.dart`:

```dart
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skyecho/skyecho.dart';
import 'package:test/test.dart';

void main() {
  group('SkyEchoClient ping', () {
    test('given_reachable_device_when_pinging_then_succeeds', () {
      /*
      Test Doc:
      - Why: Validates basic connectivity check works with 200 OK
      - Contract: ping() completes without throwing when device returns 200
      - Usage Notes: ping() is a no-op if successful (no return value)
      - Quality Contribution: Ensures ping doesn't throw on success
      - Worked Example: GET / returns 200 → ping() completes
      */

      // Arrange
      final mockClient = MockClient((request) async {
        return http.Response('OK', 200);
      });
      final client = SkyEchoClient('http://test', httpClient: mockClient);

      // Act & Assert (should not throw)
      expectLater(client.ping(), completes);
    });

    test('given_unreachable_device_when_pinging_then_throws_network_error', () {
      /*
      Test Doc:
      - Why: Validates network errors are caught and wrapped in SkyEchoNetworkError
      - Contract: ping() throws SkyEchoNetworkError when HTTP client throws ClientException
      - Usage Notes: Network errors include timeouts, connection refused, DNS failures
      - Quality Contribution: Ensures all network errors are properly wrapped
      - Worked Example: ClientException('refused') → SkyEchoNetworkError with hint
      */

      // Arrange
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });
      final client = SkyEchoClient('http://test', httpClient: mockClient);

      // Act & Assert
      expectLater(
        client.ping(),
        throwsA(isA<SkyEchoNetworkError>()
            .having((e) => e.message, 'message', contains('Connection refused'))
            .having((e) => e.hint, 'hint', isNotNull)),
      );
    });
  });
}
```

### Mocking JSON Responses

Create realistic JSON fixtures for testing:

```dart
test('given_valid_json_when_fetching_status_then_parses_all_fields', () {
  /*
  Test Doc:
  - Why: Validates JSON parsing extracts all expected fields
  - Contract: fetchStatus() returns DeviceStatus with all fields populated
  - Usage Notes: JSON structure from GET /?action=get endpoint
  - Quality Contribution: Catches missing field extractions
  - Worked Example: Full JSON → status with all fields set
  */

  // Arrange
  final jsonResponse = '''
  {
    "wifiVersion": "0.2.41-SkyEcho",
    "ssid": "SkyEcho_3155",
    "clientCount": 1,
    "adsbVersion": "2.6.13",
    "serialNumber": "0655339053",
    "coredump": false
  }
  ''';

  final mockClient = MockClient((request) async {
    return http.Response(jsonResponse, 200);
  });
  final client = SkyEchoClient('http://test', httpClient: mockClient);

  // Act
  final status = await client.fetchStatus();

  // Assert
  expect(status.wifiVersion, '0.2.41-SkyEcho');
  expect(status.ssid, 'SkyEcho_3155');
  expect(status.clientsConnected, 1);
  expect(status.adsbVersion, '2.6.13');
  expect(status.serialNumber, '0655339053');
  expect(status.coredump, false);
  expect(status.isHealthy, true);
});
```

### Testing Error Scenarios

Test all error types:

```dart
group('Error handling', () {
  test('given_404_response_when_fetching_status_then_throws_http_error', () {
    /*
    Test Doc:
    - Why: Validates HTTP errors are properly wrapped
    - Contract: Non-200 responses throw SkyEchoHttpError with status code
    - Usage Notes: All 4xx/5xx errors are wrapped the same way
    - Quality Contribution: Ensures HTTP errors have actionable hints
    - Worked Example: 404 response → SkyEchoHttpError with hint
    */

    // Arrange
    final mockClient = MockClient((request) async {
      return http.Response('Not Found', 404);
    });
    final client = SkyEchoClient('http://test', httpClient: mockClient);

    // Act & Assert
    expectLater(
      client.fetchStatus(),
      throwsA(isA<SkyEchoHttpError>()
          .having((e) => e.message, 'message', contains('404'))),
    );
  });

  test('given_invalid_json_when_fetching_status_then_throws_parse_error', () {
    /*
    Test Doc:
    - Why: Validates malformed JSON is caught and wrapped
    - Contract: Invalid JSON throws SkyEchoParseError with helpful hint
    - Usage Notes: FormatException from jsonDecode is wrapped
    - Quality Contribution: Ensures parsing errors don't leak raw exceptions
    - Worked Example: "not json" response → SkyEchoParseError
    */

    // Arrange
    final mockClient = MockClient((request) async {
      return http.Response('not json', 200);
    });
    final client = SkyEchoClient('http://test', httpClient: mockClient);

    // Act & Assert
    expectLater(
      client.fetchStatus(),
      throwsA(isA<SkyEchoParseError>()
          .having((e) => e.hint, 'hint', isNotNull)),
    );
  });
});
```

### Testing Validation

Test field validation logic:

```dart
group('ICAO validation', () {
  test('given_blacklisted_icao_when_validating_then_throws_field_error', () {
    /*
    Test Doc:
    - Why: Validates blacklist enforcement (000000, FFFFFF are reserved)
    - Contract: validateIcaoHex throws SkyEchoFieldError for blacklisted values
    - Usage Notes: Blacklist applies to both lowercase and uppercase
    - Quality Contribution: Prevents invalid ICAO addresses from being sent
    - Worked Example: "000000" → SkyEchoFieldError with hint
    */

    // Act & Assert
    expect(
      () => SkyEchoValidation.validateIcaoHex('000000'),
      throwsA(isA<SkyEchoFieldError>()
          .having((e) => e.message, 'message', contains('reserved'))
          .having((e) => e.hint, 'hint', contains('not 000000 or FFFFFF'))),
    );
  });

  test('given_valid_icao_when_validating_then_does_not_throw', () {
    /*
    Test Doc:
    - Why: Validates valid ICAO addresses are accepted
    - Contract: validateIcaoHex does not throw for valid 6-hex-char values
    - Usage Notes: Accepts with or without "0x" prefix
    - Quality Contribution: Ensures validation isn't overly strict
    - Worked Example: "7CC599" → no exception
    */

    // Act & Assert (should not throw)
    expect(
      () => SkyEchoValidation.validateIcaoHex('7CC599'),
      returnsNormally,
    );
  });
});
```

## Integration Testing

Integration tests run **against real hardware** and require physical device.

### Prerequisites

1. SkyEcho 2 device powered on
2. Connected to SkyEcho WiFi (SSID: `SkyEcho_XXXX`)
3. Device accessible at `http://192.168.4.1`

### Running Integration Tests

```bash
cd packages/skyecho

# Run only integration tests
dart test test/integration/

# Skip integration tests (useful for CI)
dart test test/unit/
```

### Writing Integration Tests

Integration tests use real `SkyEchoClient` (no mocking):

```dart
import 'package:skyecho/skyecho.dart';
import 'package:test/test.dart';

void main() {
  // Skip all tests if device not available
  final client = SkyEchoClient('http://192.168.4.1');

  group('Device status API (integration)', () {
    test('given_real_device_when_fetching_status_then_returns_valid_data',
        () async {
      /*
      Test Doc:
      - Why: Validates library works with real device firmware
      - Contract: fetchStatus() returns DeviceStatus with real data
      - Usage Notes: Requires physical device at 192.168.4.1
      - Quality Contribution: Catches API changes in new firmware versions
      - Worked Example: Real device → status with ssid, versions, etc.
      */

      try {
        // Act
        final status = await client.fetchStatus();

        // Assert
        expect(status, isNotNull);
        expect(status.ssid, isNotNull);
        expect(status.wifiVersion, isNotNull);
        expect(status.adsbVersion, isNotNull);
        print('✓ Status: SSID=${status.ssid}, WiFi=${status.wifiVersion}');
      } on SkyEchoNetworkError {
        // Skip test if device not available
        print('⊘ Device not reachable, skipping test');
        markTestSkipped('Device not available');
      }
    }, timeout: Timeout(Duration(seconds: 10)));
  });
}
```

### Safe Integration Tests

Never enable ADS-B transmit in tests:

```dart
test('given_real_device_when_updating_config_then_applies_safely', () async {
  /*
  Test Doc:
  - Why: Validates configuration updates work end-to-end
  - Contract: applySetup() updates device config and verifies
  - Usage Notes: Uses safe values only (no transmit flags)
  - Quality Contribution: Catches POST/persistence/verification bugs
  - Worked Example: Update callsign → verified config has new callsign
  */

  try {
    // Arrange - Save original config
    final original = await client.fetchSetupConfig();

    // Act - Apply safe update
    final result = await client.applySetup((u) => u
      ..callsign = 'TEST'
      ..vfrSquawk = 1200
    );

    // Assert
    expect(result.success, true);
    expect(result.verified, true);
    expect(result.verifiedConfig?.callsign, 'TEST');

    // Cleanup - Restore original
    await client.applySetup((u) => u
      ..callsign = original.callsign
      ..vfrSquawk = original.vfrSquawk
    );

    print('✓ Config update successful');
  } on SkyEchoNetworkError {
    markTestSkipped('Device not available');
  }
}, timeout: Timeout(Duration(seconds: 15)));
```

## Mocking Strategies

### Strategy 1: Fixture-Based Mocking

Capture real device responses as fixtures:

```dart
// test/fixtures/status_response.json
{
  "wifiVersion": "0.2.41-SkyEcho",
  "ssid": "SkyEcho_3155",
  "clientCount": 1,
  "adsbVersion": "2.6.13",
  "serialNumber": "0655339053",
  "coredump": false
}
```

Use in tests:

```dart
import 'dart:io';

test('given_fixture_when_parsing_then_matches_real_device', () {
  // Arrange
  final jsonFixture = File('test/fixtures/status_response.json')
      .readAsStringSync();

  final mockClient = MockClient((request) async {
    return http.Response(jsonFixture, 200);
  });
  final client = SkyEchoClient('http://test', httpClient: mockClient);

  // Act
  final status = await client.fetchStatus();

  // Assert
  expect(status.wifiVersion, '0.2.41-SkyEcho');
});
```

### Strategy 2: Parameterized Mock Responses

Create reusable mock builders:

```dart
http.Response mockStatusResponse({
  String wifiVersion = '0.2.41-SkyEcho',
  String ssid = 'SkyEcho_3155',
  int clientCount = 1,
  String adsbVersion = '2.6.13',
  String serialNumber = '0655339053',
  bool coredump = false,
}) {
  final json = {
    'wifiVersion': wifiVersion,
    'ssid': ssid,
    'clientCount': clientCount,
    'adsbVersion': adsbVersion,
    'serialNumber': serialNumber,
    'coredump': coredump,
  };
  return http.Response(jsonEncode(json), 200);
}

test('given_custom_mock_when_parsing_then_uses_custom_values', () {
  // Arrange
  final mockClient = MockClient((request) async {
    return mockStatusResponse(ssid: 'CustomSSID');
  });
  final client = SkyEchoClient('http://test', httpClient: mockClient);

  // Act
  final status = await client.fetchStatus();

  // Assert
  expect(status.ssid, 'CustomSSID');
});
```

### Strategy 3: Conditional Mock Routing

Route different URLs to different responses:

```dart
test('given_multi_endpoint_test_when_calling_then_routes_correctly', () {
  // Arrange
  final mockClient = MockClient((request) async {
    if (request.url.path == '/' && request.url.query.contains('action=get')) {
      return mockStatusResponse();
    } else if (request.url.path == '/setup/' && request.url.query.contains('action=get')) {
      return mockSetupConfigResponse();
    }
    return http.Response('Not Found', 404);
  });

  final client = SkyEchoClient('http://test', httpClient: mockClient);

  // Act & Assert
  expectLater(client.fetchStatus(), completes);
  expectLater(client.fetchSetupConfig(), completes);
});
```

## Example Tests

### Example 1: Testing Transformation Logic

```dart
test('given_device_stall_speed_when_converting_then_matches_formula', () {
  /*
  Test Doc:
  - Why: Validates stall speed conversion formula (device int → knots)
  - Contract: _stallSpeedFromDevice(x) = ceil(x / 514.4) knots
  - Usage Notes: Device stores stall speed as integer using 514.4 multiplier
  - Quality Contribution: Catches formula regressions; documents conversion
  - Worked Example: device=25000 → ceil(25000/514.4) = 49.0 knots
  */

  // Test is internal, so we test via SetupConfig.fromJson
  final json = {
    'setup': {
      'icaoAddress': 8240025,
      'callsign': 'TEST',
      'emitterCategory': 1,
      'adsbInCapability': 3,
      'aircraftLengthWidth': 0,
      'gpsAntennaOffset': 0,
      'SIL': 1,
      'SDA': 0,
      'stallSpeed': 25000,
      'vfrSquawk': 1200,
      'control': 0,
    },
    'ownshipFilter': {
      'icaoAddress': 8240025,
      'flarmId': null,
    },
  };

  final config = SetupConfig.fromJson(json);

  expect(config.stallSpeedKnots, closeTo(49.0, 0.1));
});
```

### Example 2: Testing Error Hierarchy

```dart
test('given_all_error_types_when_catching_as_base_then_succeeds', () {
  /*
  Test Doc:
  - Why: Validates polymorphic error handling works correctly
  - Contract: All error subclasses are catchable as SkyEchoError base
  - Usage Notes: Use "on SkyEchoError catch (e)" for unified handling
  - Quality Contribution: Ensures type hierarchy supports polymorphism
  - Worked Example: throw SkyEchoNetworkError → catch as SkyEchoError succeeds
  */

  final errors = [
    SkyEchoNetworkError('net'),
    SkyEchoHttpError('http'),
    SkyEchoParseError('parse'),
    SkyEchoFieldError('field'),
  ];

  for (final error in errors) {
    expect(() {
      try {
        throw error;
      } on SkyEchoError catch (e) {
        expect(e, isA<SkyEchoError>());
        return;
      }
      fail('Should have caught as SkyEchoError');
    }, returnsNormally);
  }
});
```

### Example 3: Testing Edge Cases

```dart
test('given_null_optional_fields_when_parsing_status_then_tolerates_nulls', () {
  /*
  Test Doc:
  - Why: Validates parser gracefully handles missing optional fields
  - Contract: DeviceStatus.fromJson tolerates null for all fields except coredump
  - Usage Notes: Parser should never throw on missing optional fields
  - Quality Contribution: Ensures robustness against firmware variations
  - Worked Example: {coredump: false} → DeviceStatus with nulls for other fields
  */

  final minimalJson = {'coredump': false};

  final status = DeviceStatus.fromJson(minimalJson);

  expect(status.coredump, false);
  expect(status.wifiVersion, isNull);
  expect(status.ssid, isNull);
  expect(status.adsbVersion, isNull);
});
```

## Coverage Goals

### Target Coverage

- **Core business logic**: 90% minimum
- **Parsing logic (JSON)**: 100% required
- **Error handling paths**: 90% minimum
- **Validation logic**: 100% required

### Running Coverage

```bash
cd packages/skyecho

# Run tests with coverage
dart test --coverage=coverage

# Install coverage tools (one-time)
dart pub global activate coverage

# Generate LCOV report
dart pub global run coverage:format_coverage \
  --lcov \
  --in=coverage \
  --out=coverage/lcov.info \
  --report-on=lib

# View coverage (macOS with lcov installed)
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Coverage Exemptions

Some code is exempt from coverage requirements:

- Debug/logging code
- Unreachable defensive assertions
- Platform-specific code (if any)

Mark exemptions with comments:

```dart
// coverage:ignore-start
if (kDebugMode) {
  print('Debug info: $data');
}
// coverage:ignore-end
```

## Test Organization

### Directory Structure

```
test/
├── unit/                      # Fast offline tests
│   ├── errors_test.dart       # Error hierarchy tests
│   ├── validation_test.dart   # Field validation tests
│   ├── parsing_test.dart      # JSON parsing tests
│   └── client_test.dart       # HTTP client tests
├── integration/               # Real device tests
│   ├── status_api_test.dart
│   └── config_api_test.dart
├── fixtures/                  # Captured responses
│   ├── status_response.json
│   └── setup_config_response.json
└── scratch/                   # Temporary tests (gitignored)
    └── debug_probe.dart
```

### Test File Naming

- Unit tests: `<feature>_test.dart`
- Integration tests: `<feature>_api_test.dart`
- Helpers: `<feature>_helpers.dart`

## Best Practices

### 1. Keep Unit Tests Fast

- **Goal**: < 5 seconds total for all unit tests
- **Strategy**: Use mocks, no sleep(), no network

### 2. Use AAA Pattern

Always structure tests as Arrange-Act-Assert:

```dart
test('description', () {
  // Arrange
  final input = createInput();

  // Act
  final result = performAction(input);

  // Assert
  expect(result, expectedValue);
});
```

### 3. One Assertion Per Test

Focus on single behavior:

```dart
// BAD: Multiple unrelated assertions
test('device status', () {
  expect(status.ssid, isNotNull);
  expect(status.isHealthy, true);
  expect(status.wifiVersion, '0.2.41');
});

// GOOD: Focused assertions
test('given_valid_status_when_checking_health_then_returns_true', () {
  expect(status.isHealthy, true);
});
```

### 4. Test Behavior, Not Implementation

```dart
// BAD: Tests implementation detail
test('status uses specific field name', () {
  expect(status.toString(), contains('_ssid'));
});

// GOOD: Tests behavior
test('given_healthy_device_when_checking_health_then_returns_true', () {
  expect(status.isHealthy, true);
});
```

### 5. Use Descriptive Test Names

Test names should explain the scenario:

```dart
// BAD
test('ICAO validation', () { ... });

// GOOD
test('given_blacklisted_icao_when_validating_then_throws_field_error', () { ... });
```

## Troubleshooting Tests

### Issue: Integration Tests Fail

**Solution**: Check device connectivity

```bash
# Verify device is reachable
curl http://192.168.4.1

# Check WiFi connection
networksetup -getairportnetwork en0  # macOS
```

### Issue: Flaky Tests

**Solution**: Avoid timing dependencies

```dart
// BAD: Timing-dependent
test('waits 2 seconds', () async {
  await Future.delayed(Duration(seconds: 2));
  expect(result, expectedValue);
});

// GOOD: Mock time or use fake timers
test('waits persistence delay', () async {
  // Use constants instead of magic numbers
  await Future.delayed(SkyEchoConstants.postPersistenceDelay);
});
```

### Issue: Test Coverage Too Low

**Solution**: Focus on untested paths

```bash
# Generate coverage report
dart test --coverage=coverage

# Identify untested lines
dart pub global run coverage:format_coverage ...
genhtml coverage/lcov.info -o coverage/html
```

## Reference: Test Doc Template

Copy this template for new tests:

```dart
test('given_<precondition>_when_<action>_then_<result>', () {
  /*
  Test Doc:
  - Why: <Why this test exists - what behavior it verifies>
  - Contract: <Expected behavior/guarantee>
  - Usage Notes: <How to use the tested API correctly>
  - Quality Contribution: <What quality issues this test prevents>
  - Worked Example: <Concrete input → output example>
  */

  // Arrange
  final input = createInput();

  // Act
  final result = performAction(input);

  // Assert
  expect(result, expectedValue);
});
```
