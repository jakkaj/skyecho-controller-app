# Device Setup Guide

This guide covers physical setup of the uAvionix SkyEcho 2 device for development and integration testing with the SkyEcho Controller Library.

## Table of Contents

1. [Hardware Overview](#hardware-overview)
2. [Initial Device Setup](#initial-device-setup)
3. [Network Configuration](#network-configuration)
4. [Integration Testing Setup](#integration-testing-setup)
5. [Development Workflows](#development-workflows)
6. [Troubleshooting Hardware](#troubleshooting-hardware)

## Hardware Overview

### What is SkyEcho 2?

The **uAvionix SkyEcho 2** is a certified ADS-B transceiver for general aviation aircraft:

- **ADS-B Out**: Transmits aircraft position/velocity on 1090ES or UAT frequencies
- **ADS-B In**: Receives traffic and weather from ground stations and nearby aircraft
- **WiFi Interface**: Provides web-based configuration and GDL90 data streaming
- **Portable**: Battery-powered, suction cup mount

**Use Cases**:
- ADS-B compliance for airspace requiring ADS-B Out
- Traffic and weather display on iPad/EFB apps
- Position data for autopilots and avionics

### Device Specifications

| Spec | Value |
|------|-------|
| Power | 5V USB or battery |
| WiFi | 802.11 b/g/n, WPA2 |
| IP Address | 192.168.4.1 (default) |
| Web Interface | HTTP (no HTTPS) |
| GDL90 Stream | TCP port 4000 |
| Frequencies | 1090MHz (ES), 978MHz (UAT) |

### Safety Warning

**Aviation frequencies are regulated. Never enable ADS-B transmit on the ground or in non-aviation contexts.**

The library includes runtime safety checks to prevent accidental transmit activation. The example CLI application enforces these checks.

## Initial Device Setup

### Step 1: Unbox and Inspect

1. Remove device from packaging
2. Verify contents:
   - SkyEcho 2 unit
   - USB power cable
   - Suction cup mount
   - Quick start guide

3. Inspect for damage (cracks, loose connectors)

### Step 2: Power On

**Option A: USB Power (Recommended for Development)**

1. Connect USB power cable to device
2. Connect to 5V USB power source (computer, wall adapter, battery pack)
3. Wait 30 seconds for boot
4. Status LED should turn solid green

**Option B: Internal Battery**

1. Ensure battery is charged (charge via USB for 2+ hours)
2. Press and hold power button for 3 seconds
3. Wait 30 seconds for boot
4. Status LED should turn solid green

### Step 3: Verify Boot

Device is ready when:
- Status LED is solid green (or blinking amber for GPS searching)
- WiFi network appears (SSID: `SkyEcho_XXXX`)

## Network Configuration

### Step 4: Connect to Device WiFi

#### macOS

```bash
# List available networks
networksetup -listallhardwareports

# Connect to SkyEcho
networksetup -setairportnetwork en0 SkyEcho_XXXX <password>

# Verify connection
networksetup -getairportnetwork en0
```

#### Linux

```bash
# Using nmcli
nmcli device wifi connect SkyEcho_XXXX password <password>

# Verify connection
nmcli connection show --active
```

#### Windows

1. Open WiFi settings
2. Select `SkyEcho_XXXX` network
3. Enter password (if configured)
4. Click Connect

### Step 5: Verify Web Interface

Open browser to `http://192.168.4.1`:

```bash
# Test via curl
curl http://192.168.4.1

# Expected: HTML page with "SkyEcho" in title
```

You should see the SkyEcho landing page with:
- Firmware versions
- Serial number
- Current configuration

### Step 6: Test Library Connectivity

Create a quick test script:

```dart
// test_connection.dart
import 'package:skyecho/skyecho.dart';

Future<void> main() async {
  final client = SkyEchoClient('http://192.168.4.1');

  try {
    await client.ping();
    print('✓ Device reachable');

    final status = await client.fetchStatus();
    print('✓ Status: SSID=${status.ssid}, WiFi=${status.wifiVersion}');

    final config = await client.fetchSetupConfig();
    print('✓ Config: ICAO=${config.icaoAddress}, Callsign=${config.callsign}');
  } on SkyEchoError catch (e) {
    print('✗ Error: $e');
  }
}
```

Run it:

```bash
dart run test_connection.dart
```

Expected output:
```
✓ Device reachable
✓ Status: SSID=SkyEcho_3155, WiFi=0.2.41-SkyEcho
✓ Config: ICAO=7CC599, Callsign=N12345
```

## Integration Testing Setup

### Prerequisites

Before running integration tests:

1. **Device Powered On**: Confirm solid green LED
2. **WiFi Connected**: Verify `SkyEcho_XXXX` connection
3. **Web Interface Accessible**: Test `curl http://192.168.4.1`
4. **Known Configuration**: Note current ICAO/callsign (for restoration)

### Running Integration Tests

```bash
cd packages/skyecho

# Run integration tests
dart test test/integration/

# Run specific integration test file
dart test test/integration/status_api_test.dart
```

### Integration Test Behavior

Tests will:
1. Attempt to connect to `http://192.168.4.1`
2. Skip gracefully if device not available
3. Read and modify device configuration (safely)
4. Restore original configuration after tests

**Important**: Integration tests may modify device configuration temporarily. They use safe values and restore original settings.

### Skipping Integration Tests

If device is not available, tests skip automatically:

```
00:00 +0: Device status API (integration) given_real_device_when_fetching_status_then_returns_valid_data
⊘ Device not reachable, skipping test
00:02 +0 -0: Device status API (integration) given_real_device_when_fetching_status_then_returns_valid_data (skipped)
```

To explicitly skip integration tests:

```bash
# Run only unit tests
dart test test/unit/
```

### CI/CD Considerations

For continuous integration without hardware:

```bash
# Run unit tests only (no device required)
dart test test/unit/

# Or use environment variable to skip integration
export SKIP_INTEGRATION=true
dart test
```

## Development Workflows

### Workflow 1: Rapid Prototyping (USB Power)

**Best for**: Quick experiments, development, testing

1. Connect device to computer via USB
2. Connect to device WiFi
3. Run Dart scripts directly
4. Device stays powered as long as USB connected

**Pros**: No battery drain, always-on connection
**Cons**: Tethered to computer

### Workflow 2: Portable Testing (Battery)

**Best for**: Field testing, mobility, aircraft installation testing

1. Charge device fully (2+ hours)
2. Power on via button
3. Connect to WiFi
4. Test with laptop on battery
5. Power off when done (press button 3 seconds)

**Pros**: Portable, realistic environment
**Cons**: Battery life limited (2-4 hours)

### Workflow 3: Automated Testing (CI/CD)

**Best for**: Continuous integration, regression testing

1. Run unit tests (no device required)
2. Skip integration tests in CI
3. Run integration tests manually before releases

```bash
# In CI pipeline
dart test test/unit/

# Manual integration testing
dart test test/integration/
```

### Workflow 4: Multi-Device Testing

**Best for**: Testing firmware version compatibility

1. Set up multiple SkyEcho devices (different firmware versions)
2. Note each device's SSID and IP (if non-default)
3. Test against each device sequentially

```dart
final devices = [
  'http://192.168.4.1',  // Device A (firmware 0.2.41)
  'http://192.168.4.2',  // Device B (firmware 0.2.39)
];

for (final url in devices) {
  final client = SkyEchoClient(url);
  await runTests(client);
}
```

## Best Practices

### 1. Save Original Configuration

Before modifying device config, save original:

```dart
final original = await client.fetchSetupConfig();

// Make changes...

// Restore later
await client.applySetup((u) => u
  ..icaoAddress = original.icaoAddress
  ..callsign = original.callsign
  ..vfrSquawk = original.vfrSquawk
  // ... other fields
);
```

### 2. Use Safe Test Values

Never use real aircraft identifiers in tests:

```dart
// GOOD: Safe test values
await client.applySetup((u) => u
  ..icaoAddress = '7CC599'  // Non-aviation test value
  ..callsign = 'TEST'
  ..vfrSquawk = 1200        // Standard VFR squawk
);

// BAD: Real aircraft identifier
await client.applySetup((u) => u
  ..icaoAddress = 'A12345'  // Real aircraft!
  ..callsign = 'N12345'
);
```

### 3. Never Enable Transmit in Tests

**Critical Safety Rule**: Never enable ADS-B transmit in automated tests:

```dart
// FORBIDDEN: NEVER do this
await client.applySetup((u) => u
  ..es1090TransmitEnabled = true  // DANGER!
);

// Example CLI enforces this with runtime assertion
if (update.es1090TransmitEnabled == true) {
  throw Exception(
    'SAFETY VIOLATION: Example code must never enable ADS-B transmit!'
  );
}
```

### 4. Handle Device Reboots

Some operations may cause device reboot:

```dart
// Factory reset triggers reboot
final result = await client.factoryReset();

// Wait for device to reboot (30+ seconds)
await Future.delayed(Duration(seconds: 35));

// Reconnect
await client.ping();
```

### 5. Test on Multiple Firmware Versions

Firmware changes may break parsing:

1. Keep test devices with different firmware versions
2. Run integration tests against each version
3. Update library when new firmware releases

## Troubleshooting Hardware

### Issue: Device Won't Power On

**Symptoms**: No LED, device unresponsive

**Solutions**:
1. Check USB cable (try different cable)
2. Check power source (try different USB port/adapter)
3. If battery: Charge for 2+ hours
4. Press and hold power button for 10 seconds (reset)

### Issue: WiFi Network Not Visible

**Symptoms**: `SkyEcho_XXXX` network not in WiFi list

**Solutions**:
1. Wait 60 seconds for full boot
2. Move closer to device (WiFi range limited)
3. Restart device (power cycle)
4. Check LED status:
   - Solid green: Ready
   - Blinking amber: Booting or GPS searching
   - Off: Not powered

### Issue: Cannot Connect to WiFi

**Symptoms**: WiFi connects but no internet, or timeout

**Solutions**:
1. Verify SSID matches device (check label on device)
2. Try password: (default is no password, check device label if set)
3. Disable other network interfaces (Ethernet, VPN)
4. Check IP address assigned:
   ```bash
   # macOS
   ifconfig en0 | grep inet
   # Should show 192.168.4.x
   ```

### Issue: Web Interface Returns 404

**Symptoms**: `curl http://192.168.4.1` returns 404 or timeout

**Solutions**:
1. Verify IP address is correct (ping test):
   ```bash
   ping 192.168.4.1
   ```
2. Try different browser (disable proxy)
3. Check device firmware version (may have changed endpoints)
4. Factory reset device (hold button 10 seconds)

### Issue: Library Throws Timeout Errors

**Symptoms**: `SkyEchoNetworkError: Timeout`

**Solutions**:
1. Check WiFi signal strength (move closer)
2. Increase client timeout:
   ```dart
   final client = SkyEchoClient(
     'http://192.168.4.1',
     timeout: Duration(seconds: 10),
   );
   ```
3. Restart device (may be overloaded)
4. Check other apps aren't consuming device bandwidth

### Issue: Integration Tests Fail

**Symptoms**: Tests throw network errors or skip

**Checklist**:
```bash
# 1. Device powered on?
curl http://192.168.4.1
# Expected: HTML response

# 2. Connected to device WiFi?
networksetup -getairportnetwork en0  # macOS
# Expected: SkyEcho_XXXX

# 3. IP reachable?
ping 192.168.4.1
# Expected: 0% packet loss

# 4. Library can connect?
dart run test_connection.dart
# Expected: ✓ Device reachable
```

### Issue: Device Stops Responding

**Symptoms**: Web interface hangs, library throws errors

**Solutions**:
1. Power cycle device (unplug/replug or button press)
2. Wait 60 seconds for full reboot
3. Reconnect to WiFi
4. If persistent: Factory reset (hold button 10 seconds)

### Issue: Firmware Mismatch

**Symptoms**: Parse errors, unexpected JSON structure

**Solutions**:
1. Check firmware version:
   ```dart
   final status = await client.fetchStatus();
   print('WiFi: ${status.wifiVersion}');
   print('ADS-B: ${status.adsbVersion}');
   ```
2. Update device firmware (via web interface)
3. Or update library to support new firmware version
4. Report incompatibility as GitHub issue

## Factory Reset

If device is in an unknown state, perform factory reset:

### Method 1: Via Library

```dart
final client = SkyEchoClient('http://192.168.4.1');
await client.factoryReset();

print('Device will reboot in 5 seconds...');
await Future.delayed(Duration(seconds: 35));

print('Reconnecting...');
await client.ping();
```

### Method 2: Via Button

1. Power on device
2. Press and hold power button for 10 seconds
3. LED will flash red
4. Release button
5. Wait 60 seconds for reboot
6. Device restored to factory settings

### Method 3: Via Web Interface

1. Open `http://192.168.4.1`
2. Navigate to Setup page
3. Click "Load Defaults" button
4. Confirm reset
5. Wait for device reboot

## Hardware Reference

### LED Status Indicators

| LED Color | Meaning |
|-----------|---------|
| Solid Green | Ready, GPS fix acquired |
| Blinking Green | GPS searching |
| Solid Amber | Booting |
| Blinking Amber | Firmware update in progress |
| Solid Red | Error state |
| Blinking Red | Critical error |

### Default Configuration

Fresh factory reset values:

```dart
ICAO Address:     000000 (invalid, must be set)
Callsign:         (empty)
VFR Squawk:       1200
Receiver Mode:    UAT + 1090ES
ES Transmit:      Disabled
UAT Enabled:      true
ES1090 Enabled:   true
Stall Speed:      0 knots
Emitter Category: 0 (no data)
```

### Network Details

```
SSID:        SkyEcho_XXXX (where XXXX = last 4 of serial)
Password:    (none by default, check device label)
IP Address:  192.168.4.1 (device)
Subnet:      192.168.4.0/24
DHCP Range:  192.168.4.2 - 192.168.4.254
Gateway:     192.168.4.1
DNS:         192.168.4.1 (device itself, no internet)
```

### Ports

```
HTTP:        80
GDL90:       4000 (TCP)
```

## Next Steps

Now that your device is set up:

1. **[Getting Started Guide](getting-started.md)**: Write your first script
2. **[Testing Guide](testing-guide.md)**: Run integration tests
3. **[Troubleshooting Guide](troubleshooting.md)**: Resolve common issues
4. **[Error Handling Guide](error-handling.md)**: Handle device errors gracefully
