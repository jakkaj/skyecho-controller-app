# Getting Started with SkyEcho Library

This guide walks through installation, setup, and basic usage of the SkyEcho Controller Library for programmatic control of uAvionix SkyEcho 2 ADS-B devices.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [First Connection](#first-connection)
4. [Basic Operations](#basic-operations)
5. [Complete Example](#complete-example)
6. [Next Steps](#next-steps)

## Prerequisites

### Hardware Requirements

- **SkyEcho 2 Device**: uAvionix SkyEcho 2 ADS-B transceiver
- **WiFi Connection**: Your computer must connect to the SkyEcho's WiFi network
  - Default SSID: `SkyEcho_XXXX` (where XXXX is the last 4 digits of serial number)
  - Default IP: `http://192.168.4.1`

### Software Requirements

- **Dart SDK**: Version 3.0.0 or later
  - Install from [dart.dev](https://dart.dev/get-dart)
  - Verify: `dart --version`

## Installation

### Option 1: Local Development (Monorepo)

If you're working within this repository:

```yaml
# pubspec.yaml
dependencies:
  skyecho:
    path: packages/skyecho/
```

Then install dependencies:

```bash
dart pub get
```

### Option 2: Future Published Package

Once published to pub.dev (not yet available):

```yaml
# pubspec.yaml
dependencies:
  skyecho: ^1.0.0
```

## First Connection

### Step 1: Connect to Device WiFi

1. Power on your SkyEcho 2 device
2. Connect your computer to the device's WiFi network
   - Network name: `SkyEcho_XXXX`
   - Password: (if configured on device)
3. Verify connection: Open browser to `http://192.168.4.1`

### Step 2: Create Your First Script

Create a new Dart file (e.g., `my_skyecho_app.dart`):

```dart
import 'package:skyecho/skyecho.dart';

Future<void> main() async {
  // Create client pointing to device
  final client = SkyEchoClient('http://192.168.4.1');

  try {
    // Test connectivity
    await client.ping();
    print('Device is reachable!');
  } on SkyEchoError catch (e) {
    print('Error: $e');
  }
}
```

Run it:

```bash
dart run my_skyecho_app.dart
```

Expected output:
```
Device is reachable!
```

### Step 3: Fetch Device Status

Expand your script to retrieve device information:

```dart
import 'package:skyecho/skyecho.dart';

Future<void> main() async {
  final client = SkyEchoClient('http://192.168.4.1');

  try {
    // Fetch device status
    final status = await client.fetchStatus();

    // Display key information
    print('SSID: ${status.ssid}');
    print('WiFi Version: ${status.wifiVersion}');
    print('ADS-B Version: ${status.adsbVersion}');
    print('Clients Connected: ${status.clientsConnected}');
    print('Serial Number: ${status.serialNumber}');
    print('Health: ${status.isHealthy ? "Healthy" : "Unhealthy"}');
  } on SkyEchoError catch (e) {
    print('Error: $e');
  }
}
```

Example output:
```
SSID: SkyEcho_3155
WiFi Version: 0.2.41-SkyEcho
ADS-B Version: 2.6.13
Clients Connected: 1
Serial Number: 0655339053
Health: Healthy
```

## Basic Operations

### Ping Device (Connectivity Check)

The simplest operation - verifies the device is reachable:

```dart
final client = SkyEchoClient('http://192.168.4.1');
await client.ping();
// If no exception is thrown, device is reachable
```

Use cases:
- Pre-flight connectivity check
- Network diagnostics
- Health monitoring

### Fetch Device Status

Retrieves current device state and firmware versions:

```dart
final status = await client.fetchStatus();

// Access fields
print(status.ssid);              // String?
print(status.wifiVersion);       // String?
print(status.adsbVersion);       // String?
print(status.clientsConnected);  // int?
print(status.serialNumber);      // String?
print(status.coredump);          // bool

// Computed properties
print(status.isHealthy);         // bool
print(status.hasCoredump);       // bool
```

**Important**: All fields except `coredump` are nullable. Always check for null before using.

### Fetch Device Configuration

Retrieves current device configuration settings:

```dart
final config = await client.fetchSetupConfig();

print('ICAO Address: ${config.icaoAddress}');
print('Callsign: ${config.callsign}');
print('VFR Squawk: ${config.vfrSquawk}');
print('Receiver Mode: ${config.receiverMode}');
print('Stall Speed: ${config.stallSpeedKnots} knots');
```

### Update Device Configuration

Update device settings using the builder pattern:

```dart
final result = await client.applySetup((update) => update
  ..callsign = 'N12345'
  ..vfrSquawk = 1200
  ..stallSpeedKnots = 48.0
);

if (result.verified) {
  print('Configuration applied successfully!');
} else {
  print('Warning: Configuration not verified');
}
```

**Critical Notes**:
- The library waits 2 seconds after POST for device persistence
- Verification GET confirms changes were applied
- See [Error Handling Guide](error-handling.md) for error recovery patterns

## Complete Example

Here's a complete script demonstrating all basic operations:

```dart
import 'package:skyecho/skyecho.dart';

Future<void> main() async {
  // Create client with default timeout (5 seconds)
  final client = SkyEchoClient('http://192.168.4.1');

  try {
    // 1. Check connectivity
    print('Checking device connectivity...');
    await client.ping();
    print('✓ Device reachable\n');

    // 2. Fetch and display status
    print('Fetching device status...');
    final status = await client.fetchStatus();
    print('✓ Status retrieved:');
    print('  SSID: ${status.ssid}');
    print('  WiFi: ${status.wifiVersion}');
    print('  ADS-B: ${status.adsbVersion}');
    print('  Health: ${status.isHealthy ? "Healthy" : "Unhealthy"}\n');

    // 3. Fetch and display configuration
    print('Fetching device configuration...');
    final config = await client.fetchSetupConfig();
    print('✓ Configuration retrieved:');
    print('  ICAO: ${config.icaoAddress}');
    print('  Callsign: ${config.callsign}');
    print('  Mode: ${config.receiverMode}');
    print('  Squawk: ${config.vfrSquawk}');
    print('  Transmit: ${config.es1090TransmitEnabled ? "ENABLED" : "Disabled"}\n');

    // 4. Update configuration (safe values only)
    print('Updating callsign to DEMO...');
    final result = await client.applySetup((update) => update
      ..callsign = 'DEMO'
      ..vfrSquawk = 1200
    );
    print('✓ Configuration updated:');
    print('  Success: ${result.success}');
    print('  Verified: ${result.verified}');
    print('  Message: ${result.message ?? "(none)"}');

  } on SkyEchoNetworkError catch (e) {
    print('Network error: ${e.message}');
    print('${e.hint}');
  } on SkyEchoHttpError catch (e) {
    print('HTTP error: ${e.message}');
    print('${e.hint}');
  } on SkyEchoParseError catch (e) {
    print('Parse error: ${e.message}');
    print('${e.hint}');
  } on SkyEchoFieldError catch (e) {
    print('Field validation error: ${e.message}');
    print('${e.hint}');
  } on SkyEchoError catch (e) {
    print('Unknown SkyEcho error: ${e.message}');
    print('${e.hint ?? "(no hint)"}');
  }
}
```

## Custom Configuration

### Custom Device URL

If your device is at a non-default address:

```dart
final client = SkyEchoClient('http://192.168.4.2');
```

### Custom Timeout

For slow networks or operations:

```dart
final client = SkyEchoClient(
  'http://192.168.4.1',
  timeout: Duration(seconds: 10),
);
```

### Custom HTTP Client (Advanced)

For testing or advanced networking scenarios:

```dart
import 'package:http/http.dart' as http;

final customClient = http.Client();
final skyecho = SkyEchoClient(
  'http://192.168.4.1',
  httpClient: customClient,
);
```

## Important Behavioral Notes

### HTTP Keep-Alive Bug Workaround

The SkyEcho device firmware has a bug where it closes connections on any request made on a reused HTTP connection (keep-alive). The library automatically works around this by calling `_resetConnection()` before every request.

**Impact**: Each request uses a fresh HTTP connection.

**User Action**: None required - workaround is automatic.

### POST Persistence Delay

After POSTing configuration changes, the device requires up to 2 seconds to persist changes to flash memory.

**Library Behavior**: `applySetup()` automatically waits 2 seconds before verification GET.

**User Action**: Be patient - don't interrupt during configuration updates.

### Validation Timing

Field validation occurs when:
1. `SetupConfig.validate()` is called explicitly
2. `applySetup()` is called (validates before POST)

**Example of pre-validation**:

```dart
final config = await client.fetchSetupConfig();
config.validate(); // Throws SkyEchoFieldError if any field is invalid
```

## Next Steps

Now that you've mastered the basics, explore these topics:

1. **[Error Handling Guide](error-handling.md)**: Learn about error types, recovery patterns, and best practices
2. **[Testing Guide](testing-guide.md)**: Write tests for your SkyEcho integration using TAD methodology
3. **[Device Setup Guide](device-setup.md)**: Physical device setup for integration testing
4. **[Troubleshooting Guide](troubleshooting.md)**: Common issues and solutions

## Quick Reference

### Common Imports

```dart
import 'package:skyecho/skyecho.dart';
```

### Essential Classes

- `SkyEchoClient`: Main HTTP client
- `DeviceStatus`: Device status model
- `SetupConfig`: Configuration model
- `SetupUpdate`: Builder for configuration updates
- `ApplyResult`: Result of configuration update
- `ReceiverMode`: Enum (uat, es1090, flarm)

### Essential Error Types

- `SkyEchoNetworkError`: Connection/timeout errors
- `SkyEchoHttpError`: HTTP status errors (4xx, 5xx)
- `SkyEchoParseError`: JSON parsing errors
- `SkyEchoFieldError`: Field validation errors

### Key Methods

```dart
// Connectivity
await client.ping();

// Status
final status = await client.fetchStatus();

// Configuration
final config = await client.fetchSetupConfig();
final result = await client.applySetup((u) => u..callsign = 'TEST');

// Factory reset (DESTRUCTIVE)
final result = await client.factoryReset();
```

## Example CLI Application

The library includes a complete CLI example at `packages/skyecho/example/main.dart`:

```bash
cd packages/skyecho

# See all commands
dart run example/main.dart --help

# Test connectivity
dart run example/main.dart ping

# View device status
dart run example/main.dart status

# View configuration
dart run example/main.dart config

# Demonstrate configuration update
dart run example/main.dart configure
```

Study this example to see production-quality error handling and command-line argument parsing.
