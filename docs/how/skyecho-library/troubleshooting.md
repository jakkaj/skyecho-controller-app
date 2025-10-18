# Troubleshooting Guide

This guide covers common issues, solutions, and debugging strategies when using the SkyEcho Controller Library.

## Table of Contents

1. [Quick Diagnostics](#quick-diagnostics)
2. [Connection Issues](#connection-issues)
3. [HTTP/Network Errors](#httpnetwork-errors)
4. [Parsing Errors](#parsing-errors)
5. [Validation Errors](#validation-errors)
6. [Configuration Issues](#configuration-issues)
7. [Known Issues](#known-issues)
8. [Debugging Techniques](#debugging-techniques)
9. [Getting Help](#getting-help)

## Quick Diagnostics

When something goes wrong, run this diagnostic checklist:

### Diagnostic Script

Create `diagnose.dart`:

```dart
import 'package:skyecho/skyecho.dart';

Future<void> main() async {
  print('SkyEcho Library Diagnostic Tool\n');

  final client = SkyEchoClient('http://192.168.4.1');

  // Test 1: Ping
  print('1. Testing connectivity...');
  try {
    await client.ping();
    print('   ✓ Device reachable\n');
  } on SkyEchoNetworkError catch (e) {
    print('   ✗ Network error: ${e.message}');
    print('   Hint: ${e.hint}\n');
    return; // Stop if can't reach device
  } on SkyEchoHttpError catch (e) {
    print('   ✗ HTTP error: ${e.message}');
    print('   Hint: ${e.hint}\n');
    return;
  }

  // Test 2: Fetch Status
  print('2. Testing status API...');
  try {
    final status = await client.fetchStatus();
    print('   ✓ Status retrieved');
    print('   SSID: ${status.ssid}');
    print('   WiFi Version: ${status.wifiVersion}');
    print('   ADS-B Version: ${status.adsbVersion}');
    print('   Health: ${status.isHealthy ? "Healthy" : "Unhealthy"}\n');
  } on SkyEchoParseError catch (e) {
    print('   ✗ Parse error: ${e.message}');
    print('   Hint: ${e.hint}\n');
  } on SkyEchoError catch (e) {
    print('   ✗ Error: ${e.message}\n');
  }

  // Test 3: Fetch Config
  print('3. Testing config API...');
  try {
    final config = await client.fetchSetupConfig();
    print('   ✓ Config retrieved');
    print('   ICAO: ${config.icaoAddress}');
    print('   Callsign: ${config.callsign}');
    print('   Transmit: ${config.es1090TransmitEnabled}\n');
  } on SkyEchoParseError catch (e) {
    print('   ✗ Parse error: ${e.message}');
    print('   Hint: ${e.hint}\n');
  } on SkyEchoError catch (e) {
    print('   ✗ Error: ${e.message}\n');
  }

  print('Diagnostics complete!');
}
```

Run it:

```bash
dart run diagnose.dart
```

Expected output (success):
```
SkyEcho Library Diagnostic Tool

1. Testing connectivity...
   ✓ Device reachable

2. Testing status API...
   ✓ Status retrieved
   SSID: SkyEcho_3155
   WiFi Version: 0.2.41-SkyEcho
   ADS-B Version: 2.6.13
   Health: Healthy

3. Testing config API...
   ✓ Config retrieved
   ICAO: 7CC599
   Callsign: N12345
   Transmit: false

Diagnostics complete!
```

## Connection Issues

### Issue: "Network error: Connection refused"

**Error Message**:
```
SkyEchoNetworkError: Network error: Connection refused
Hint: Check WiFi connection and device IP address
```

**Cause**: Device not reachable (wrong IP, not connected to WiFi, device powered off)

**Solutions**:

1. **Verify WiFi Connection**:
   ```bash
   # macOS
   networksetup -getairportnetwork en0
   # Expected: Current Wi-Fi Network: SkyEcho_XXXX

   # Linux
   nmcli connection show --active
   # Expected: SkyEcho_XXXX in list
   ```

2. **Verify IP Address**:
   ```bash
   # Ping device
   ping 192.168.4.1
   # Expected: 0% packet loss
   ```

3. **Check Device Power**:
   - Look for solid green LED on device
   - Try power cycling (unplug/replug or button press)

4. **Test with curl**:
   ```bash
   curl http://192.168.4.1
   # Expected: HTML response with "SkyEcho" in content
   ```

### Issue: "Network error: Timeout"

**Error Message**:
```
SkyEchoNetworkError: Network error: Timeout
Hint: Check WiFi connection and device IP address
```

**Cause**: Network too slow, device overloaded, or WiFi interference

**Solutions**:

1. **Increase Timeout**:
   ```dart
   final client = SkyEchoClient(
     'http://192.168.4.1',
     timeout: Duration(seconds: 10), // Increase from default 5s
   );
   ```

2. **Move Closer to Device**:
   - Check WiFi signal strength
   - Reduce distance to device
   - Remove obstacles between computer and device

3. **Reduce Concurrent Requests**:
   ```dart
   // BAD: Multiple simultaneous requests may overload device
   final futures = [
     client.fetchStatus(),
     client.fetchSetupConfig(),
     client.ping(),
   ];
   await Future.wait(futures);

   // GOOD: Sequential requests
   await client.ping();
   final status = await client.fetchStatus();
   final config = await client.fetchSetupConfig();
   ```

4. **Restart Device**:
   - Power cycle device
   - Wait 60 seconds for full boot
   - Retry connection

### Issue: "Network error: No route to host"

**Error Message**:
```
SkyEchoNetworkError: Network error: No route to host
Hint: Check WiFi connection and device IP address
```

**Cause**: Not connected to device WiFi network, wrong IP address, or routing issue

**Solutions**:

1. **Connect to Device WiFi**:
   ```bash
   # macOS
   networksetup -setairportnetwork en0 SkyEcho_3155

   # Linux
   nmcli device wifi connect SkyEcho_3155
   ```

2. **Check IP Assignment**:
   ```bash
   # macOS
   ifconfig en0 | grep inet
   # Expected: inet 192.168.4.x (where x = 2-254)

   # Linux
   ip addr show
   # Expected: 192.168.4.x address on WiFi interface
   ```

3. **Disable VPN/Proxy**:
   - VPNs may route traffic away from local network
   - Disable VPN temporarily
   - Check proxy settings

4. **Verify Default Route**:
   ```bash
   # macOS
   netstat -nr | grep default
   # Should show route via 192.168.4.1
   ```

## HTTP/Network Errors

### Issue: "HTTP 404: Not Found"

**Error Message**:
```
SkyEchoHttpError: HTTP 404: Not Found
Hint: Ensure device is powered on and accessible at http://192.168.4.1
```

**Cause**: Endpoint doesn't exist (firmware version mismatch, wrong URL path)

**Solutions**:

1. **Verify Endpoint with curl**:
   ```bash
   # Test status endpoint
   curl "http://192.168.4.1/?action=get"

   # Test config endpoint
   curl "http://192.168.4.1/setup/?action=get"
   ```

2. **Check Firmware Version**:
   ```dart
   final status = await client.fetchStatus();
   print('WiFi FW: ${status.wifiVersion}');
   print('ADS-B FW: ${status.adsbVersion}');

   // Compare to known compatible versions
   // Library tested with: WiFi 0.2.41, ADS-B 2.6.13
   ```

3. **Verify Base URL**:
   ```dart
   // GOOD: Correct format
   final client = SkyEchoClient('http://192.168.4.1');

   // BAD: Trailing slash
   final client = SkyEchoClient('http://192.168.4.1/');

   // BAD: Missing protocol
   final client = SkyEchoClient('192.168.4.1');
   ```

### Issue: "HTTP 500: Internal Server Error"

**Error Message**:
```
SkyEchoHttpError: HTTP 500: Internal Server Error
Hint: Ensure device is powered on and accessible at http://192.168.4.1
```

**Cause**: Device firmware crash, corrupted state, or malformed request

**Solutions**:

1. **Power Cycle Device**:
   - Unplug/replug USB or button press
   - Wait 60 seconds for reboot
   - Retry operation

2. **Check for Coredump**:
   ```dart
   final status = await client.fetchStatus();
   if (status.hasCoredump) {
     print('Device has crash dump! Recommend factory reset.');
   }
   ```

3. **Factory Reset** (if persistent):
   ```dart
   final client = SkyEchoClient('http://192.168.4.1');
   await client.factoryReset();
   // Device will reboot (wait 60 seconds)
   ```

### Issue: HTTP Keep-Alive Bug (Automatic Workaround)

**Symptom**: Second request in sequence fails or returns unexpected data

**Cause**: Device firmware bug where it closes connections on reused HTTP connections (keep-alive)

**Library Workaround**: Automatic (no user action needed)

The library calls `_resetConnection()` before every request to work around this bug:

```dart
void _resetConnection() {
  if (!_externalClient) {
    _httpClient.close();      // Close existing connection
    _httpClient = http.Client(); // Create fresh client
  }
}
```

**Impact**: Each request uses a fresh HTTP connection (slight performance penalty)

**User Action**: None required - workaround is automatic

## Parsing Errors

### Issue: "Failed to parse JSON response"

**Error Message**:
```
SkyEchoParseError: Failed to parse JSON response: FormatException: Unexpected character
Hint: Device may have returned invalid JSON. Check device firmware.
```

**Cause**: Device returned malformed JSON or HTML error page instead of JSON

**Solutions**:

1. **Inspect Raw Response**:
   ```bash
   # Test endpoint with curl
   curl "http://192.168.4.1/?action=get"
   # Expected: Valid JSON like {"wifiVersion": "0.2.41", ...}

   # If HTML returned instead, device may be in error state
   ```

2. **Check for HTML Error Pages**:
   ```bash
   curl -i "http://192.168.4.1/?action=get"
   # Check Content-Type header
   # Expected: application/json
   # If: text/html → device returning error page
   ```

3. **Update Firmware**:
   - Old firmware may have JSON bugs
   - Update via device web interface
   - Retest with updated firmware

### Issue: "Failed to parse DeviceStatus from JSON"

**Error Message**:
```
SkyEchoParseError: Failed to parse DeviceStatus from JSON: type 'Null' is not a subtype of type 'String'
Hint: Ensure JSON has expected structure from GET /?action=get
```

**Cause**: Required field missing in JSON response (firmware version change)

**Solutions**:

1. **Check JSON Structure**:
   ```bash
   curl "http://192.168.4.1/?action=get" | jq .
   # Verify all expected fields present:
   # - wifiVersion
   # - ssid
   # - clientCount
   # - adsbVersion
   # - serialNumber
   # - coredump
   ```

2. **Compare to Expected Structure**:
   ```dart
   // Expected JSON from GET /?action=get
   {
     "wifiVersion": "0.2.41-SkyEcho",
     "ssid": "SkyEcho_3155",
     "clientCount": 1,
     "adsbVersion": "2.6.13",
     "serialNumber": "0655339053",
     "coredump": false
   }
   ```

3. **Report Firmware Incompatibility**:
   - File GitHub issue with firmware versions
   - Include JSON response example
   - Library may need update for new firmware

## Validation Errors

### Issue: "ICAO address 000000 is reserved and invalid"

**Error Message**:
```
SkyEchoFieldError: ICAO address 000000 is reserved and invalid
Hint: Use a valid ICAO address (not 000000 or FFFFFF)
```

**Cause**: Trying to set blacklisted ICAO address (000000 or FFFFFF are reserved)

**Solution**:

```dart
// BAD: Blacklisted values
await client.applySetup((u) => u..icaoAddress = '000000'); // Error!
await client.applySetup((u) => u..icaoAddress = 'FFFFFF'); // Error!

// GOOD: Valid ICAO address
await client.applySetup((u) => u..icaoAddress = '7CC599');
```

**Valid ICAO addresses**:
- 6 hexadecimal characters (0-9, A-F)
- NOT 000000 or FFFFFF
- Example: 7CC599, A12345, ABC123

### Issue: "Callsign too long"

**Error Message**:
```
SkyEchoFieldError: Callsign too long: 9 characters (max 8)
Hint: Shorten to 8 characters or less
```

**Cause**: Callsign exceeds 8 characters

**Solution**:

```dart
// BAD: Too long
await client.applySetup((u) => u..callsign = 'VERYLONGCALL'); // 12 chars

// GOOD: 8 chars or less
await client.applySetup((u) => u..callsign = 'N12345'); // 6 chars
await client.applySetup((u) => u..callsign = 'TEST1234'); // 8 chars
```

**Callsign rules**:
- 1-8 characters
- Alphanumeric only (A-Z, 0-9)
- No spaces, dashes, or special characters
- Device auto-converts to uppercase

### Issue: "VFR squawk contains invalid digits"

**Error Message**:
```
SkyEchoFieldError: VFR squawk contains invalid digits: 1288
Hint: Each digit must be 0-7 (octal), no 8 or 9 allowed
```

**Cause**: Squawk code contains digits 8 or 9 (squawk codes are octal)

**Solution**:

```dart
// BAD: Contains digit 8 or 9
await client.applySetup((u) => u..vfrSquawk = 1288); // 8 not allowed!
await client.applySetup((u) => u..vfrSquawk = 1999); // 9 not allowed!

// GOOD: Octal digits only (0-7)
await client.applySetup((u) => u..vfrSquawk = 1200); // Standard VFR
await client.applySetup((u) => u..vfrSquawk = 7700); // Emergency
await client.applySetup((u) => u..vfrSquawk = 1234); // Valid
```

**Squawk code rules**:
- 4-digit octal number (0000-7777)
- Each digit must be 0-7 (no 8 or 9)
- Common values: 1200 (VFR), 7500 (hijack), 7600 (comm failure), 7700 (emergency)

### Issue: "GPS lon offset must be even"

**Error Message**:
```
SkyEchoFieldError: GPS lon offset must be even: 7 meters
Hint: Device truncates odd values. Use even (0, 2, 4, ...30)
```

**Cause**: GPS longitude offset must be even number (device limitation)

**Solution**:

```dart
// BAD: Odd value
await client.applySetup((u) => u..gpsLonOffsetMeters = 7); // Odd!

// GOOD: Even values only
await client.applySetup((u) => u..gpsLonOffsetMeters = 0);
await client.applySetup((u) => u..gpsLonOffsetMeters = 6);
await client.applySetup((u) => u..gpsLonOffsetMeters = 30);
```

**GPS longitude offset rules**:
- Range: 0-31 meters
- MUST be even (0, 2, 4, 6, ... 30)
- Device truncates odd values (use even to be explicit)

## Configuration Issues

### Issue: Configuration Not Persisting

**Symptom**: `applySetup()` succeeds but changes not visible after device reboot

**Cause**: Device requires 2-second delay for flash persistence

**Solution**: The library automatically handles this (no user action needed)

```dart
// Library implementation (automatic)
Future<ApplyResult> applySetup(...) async {
  // POST config
  await _postJson('/setup/?action=set', newConfig.toJson());

  // CRITICAL: Wait for device persistence
  await Future.delayed(SkyEchoConstants.postPersistenceDelay); // 2 seconds

  // Verify changes applied
  final verifiedConfig = await fetchSetupConfig();
  // ...
}
```

**If still not persisting**:
1. Check `ApplyResult.verified` is true
2. Verify device not power cycling during update
3. Try factory reset if persistent issue

### Issue: Verification Fails After Update

**Symptom**: `ApplyResult.verified` is false, but `success` is true

**Cause**: Device accepted POST but changes not reflected in subsequent GET (rare)

**Solution**:

```dart
final result = await client.applySetup((u) => u..callsign = 'TEST');

if (result.success && !result.verified) {
  print('Warning: Update sent but not verified');

  // Wait longer and retry verification
  await Future.delayed(Duration(seconds: 5));
  final config = await client.fetchSetupConfig();

  if (config.callsign == 'TEST') {
    print('Delayed verification succeeded');
  } else {
    print('Verification still failed - may need device reboot');
  }
}
```

### Issue: Cannot Change ICAO Address

**Symptom**: ICAO address update fails or reverts

**Cause**: Device may have hardcoded ICAO (check device documentation)

**Solution**:

1. **Verify ICAO is configurable** on your device model
2. **Try factory reset** to clear locked ICAO:
   ```dart
   await client.factoryReset();
   // Wait for reboot
   await Future.delayed(Duration(seconds: 35));

   // Try setting ICAO again
   await client.applySetup((u) => u..icaoAddress = '7CC599');
   ```

## Known Issues

### Issue 1: HTTP Keep-Alive Bug (Automatic Workaround)

**Status**: Known device firmware bug, library includes automatic workaround

**Symptom**: Second request in sequence fails or returns stale data

**Workaround**: Library calls `_resetConnection()` before every request

**User Impact**: None (automatic)

**Performance**: Slight overhead from fresh connections (~10ms per request)

### Issue 2: 2-Second POST Persistence Delay

**Status**: Device hardware limitation (flash write time)

**Symptom**: Changes not visible immediately after POST

**Workaround**: Library waits 2 seconds before verification GET

**User Impact**: Configuration updates take 3-5 seconds total

**Code**:
```dart
// Automatic delay in applySetup()
await Future.delayed(SkyEchoConstants.postPersistenceDelay); // 2s
```

### Issue 3: No HTTPS Support

**Status**: Device limitation (no SSL/TLS in firmware)

**Symptom**: Cannot use HTTPS URLs

**Workaround**: Use HTTP only (library enforces this)

**Security Note**: Only use on trusted local networks (aircraft WiFi)

### Issue 4: Single Concurrent Request Limit

**Status**: Device limitation (embedded web server)

**Symptom**: Concurrent requests may timeout or return errors

**Workaround**: Make requests sequentially, not in parallel

**Code**:
```dart
// BAD: Parallel requests may overload device
final futures = [client.fetchStatus(), client.fetchSetupConfig()];
await Future.wait(futures);

// GOOD: Sequential requests
final status = await client.fetchStatus();
final config = await client.fetchSetupConfig();
```

## Debugging Techniques

### Technique 1: Enable HTTP Logging

Log all HTTP requests/responses:

```dart
import 'package:http/http.dart' as http;

class LoggingClient extends http.BaseClient {
  final http.Client _inner;

  LoggingClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    print('→ ${request.method} ${request.url}');
    final response = await _inner.send(request);
    print('← ${response.statusCode}');
    return response;
  }
}

// Use with SkyEchoClient
final loggingClient = LoggingClient(http.Client());
final client = SkyEchoClient(
  'http://192.168.4.1',
  httpClient: loggingClient,
);
```

### Technique 2: Capture Raw Responses

Save device responses for analysis:

```bash
# Capture status response
curl "http://192.168.4.1/?action=get" > status_response.json

# Capture config response
curl "http://192.168.4.1/setup/?action=get" > config_response.json

# Pretty-print JSON
cat status_response.json | jq .
```

### Technique 3: Compare Firmware Versions

Test library against multiple firmware versions:

```dart
Future<void> testFirmwareCompatibility() async {
  final devices = {
    'http://192.168.4.1': 'Device A',
    'http://192.168.4.2': 'Device B',
  };

  for (final entry in devices.entries) {
    final client = SkyEchoClient(entry.key);

    try {
      final status = await client.fetchStatus();
      print('${entry.value}: WiFi=${status.wifiVersion}, ADS-B=${status.adsbVersion}');
    } catch (e) {
      print('${entry.value}: ERROR - $e');
    }
  }
}
```

### Technique 4: Minimal Reproduction

Create minimal test case:

```dart
// minimal_repro.dart
import 'package:skyecho/skyecho.dart';

Future<void> main() async {
  final client = SkyEchoClient('http://192.168.4.1');

  // Simplest operation that reproduces issue
  try {
    await client.ping();
    print('Success');
  } catch (e) {
    print('Error: $e');
    print('Stack trace:');
    print(StackTrace.current);
  }
}
```

### Technique 5: Check Library Version

Ensure you're using latest library version:

```bash
# Check pubspec.yaml
cat packages/skyecho/pubspec.yaml | grep version

# Check for updates (once published)
dart pub outdated
```

## Getting Help

### Self-Help Resources

1. **Documentation**:
   - [Getting Started Guide](getting-started.md)
   - [Error Handling Guide](error-handling.md)
   - [Testing Guide](testing-guide.md)
   - [Device Setup Guide](device-setup.md)

2. **Source Code**:
   - Read `lib/skyecho.dart` for implementation details
   - Check `example/main.dart` for usage examples
   - Review `test/unit/` for test examples

3. **Run Diagnostics**:
   ```bash
   dart run diagnose.dart  # From troubleshooting guide
   ```

### Reporting Issues

When filing GitHub issues, include:

1. **Environment**:
   ```
   - OS: macOS 13.2 / Linux Ubuntu 22.04 / Windows 11
   - Dart SDK: 3.2.0
   - Library Version: 1.0.0
   ```

2. **Device Info**:
   ```
   - Device Model: SkyEcho 2
   - WiFi Firmware: 0.2.41-SkyEcho
   - ADS-B Firmware: 2.6.13
   - Serial Number: 0655339053 (optional)
   ```

3. **Error Details**:
   ```dart
   // Full error message
   SkyEchoParseError: Failed to parse JSON response: ...
   Hint: Device may have returned invalid JSON. Check firmware.

   // Stack trace (if available)
   #0      SkyEchoClient.fetchStatus (package:skyecho/skyecho.dart:250)
   ...
   ```

4. **Minimal Reproduction**:
   ```dart
   import 'package:skyecho/skyecho.dart';

   Future<void> main() async {
     final client = SkyEchoClient('http://192.168.4.1');
     await client.fetchStatus(); // Error occurs here
   }
   ```

5. **Raw Device Response** (if applicable):
   ```bash
   curl "http://192.168.4.1/?action=get"
   # Include output
   ```

### Community Support

- **GitHub Discussions**: Ask questions, share usage patterns
- **GitHub Issues**: Report bugs, request features
- **Example Code**: Study `example/main.dart` for patterns

## FAQ

**Q: Why does every request take 2+ seconds?**

A: Device requires 2-second persistence delay after POST operations. GET operations are fast (<500ms).

**Q: Can I use this library over the internet?**

A: No, device only accessible on local WiFi network (192.168.4.0/24). No internet gateway.

**Q: Does library support HTTPS?**

A: No, device firmware only supports HTTP (no SSL/TLS).

**Q: Can I make parallel requests to speed things up?**

A: No, device web server handles one request at a time. Sequential requests are required.

**Q: Why does second request sometimes fail?**

A: Device has HTTP keep-alive bug. Library automatically works around this by resetting connection before each request.

**Q: How do I test without a physical device?**

A: Use unit tests with `MockClient` (see [Testing Guide](testing-guide.md)). Integration tests require real hardware.

**Q: Can I control multiple devices simultaneously?**

A: Yes, create separate `SkyEchoClient` instances for each device (different URLs).

**Q: Is it safe to enable ADS-B transmit in tests?**

A: **NO! NEVER enable transmit in automated tests.** Aviation frequencies are regulated. Library includes safety checks.

## Quick Reference: Error Types

| Error Type | Common Causes | First Step |
|------------|---------------|------------|
| `SkyEchoNetworkError` | WiFi disconnected, device off | Check WiFi connection |
| `SkyEchoHttpError` | Wrong endpoint, firmware crash | Check firmware version |
| `SkyEchoParseError` | Firmware version mismatch | Capture raw response |
| `SkyEchoFieldError` | Invalid input value | Check validation rules |

## Quick Reference: Validation Rules

| Field | Valid Range | Example Error |
|-------|-------------|---------------|
| ICAO Address | 6 hex chars, not 000000/FFFFFF | "ICAO address 000000 is reserved" |
| Callsign | 1-8 alphanumeric | "Callsign too long: 9 characters" |
| VFR Squawk | 0000-7777 (octal) | "VFR squawk contains invalid digits: 1288" |
| Stall Speed | 0-127 knots | "Stall speed out of range: 150 knots" |
| GPS Lon Offset | 0-31 meters, even only | "GPS lon offset must be even: 7 meters" |

## Next Steps

- Review [Error Handling Guide](error-handling.md) for error recovery patterns
- Check [Getting Started Guide](getting-started.md) for basic usage
- See [Testing Guide](testing-guide.md) for writing robust tests
- Consult [Device Setup Guide](device-setup.md) for hardware troubleshooting
