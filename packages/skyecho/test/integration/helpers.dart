/// Integration test helpers for SkyEcho device tests.
///
/// Provides reusable utilities for device detection, skip messages,
/// and debug output formatting.
library;

import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:skyecho/skyecho.dart';

/// Checks if a SkyEcho device is reachable at the given URL.
///
/// Attempts to connect to the device with a 5-second timeout. Returns `true`
/// if the device responds with HTTP 200, `false` otherwise (timeout, network
/// error, or non-200 status code).
///
/// **Usage**:
/// ```dart
/// setUpAll(() async {
///   deviceAvailable = await canReachDevice('http://192.168.4.1');
///   if (!deviceAvailable) {
///     print(deviceSetupMessage());
///   }
/// });
/// ```
///
/// **Parameters**:
/// - [url]: Full device URL (e.g., 'http://192.168.4.1')
///
/// **Returns**: `true` if device accessible, `false` otherwise
///
/// **Timeout**: 5 seconds (matches SkyEchoClient default)
Future<bool> canReachDevice(String url) async {
  try {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 5));
    return response.statusCode == 200;
  } catch (_) {
    return false;
  }
}

/// Returns a standardized skip message for integration tests.
///
/// Provides clear instructions for connecting to the SkyEcho WiFi network
/// when the device is unavailable.
///
/// **Usage**:
/// ```dart
/// if (!deviceAvailable) {
///   print(deviceSetupMessage());
/// }
/// ```
///
/// **Returns**: Multi-line string with WiFi setup instructions
String deviceSetupMessage() {
  return '''
⚠️  SkyEcho device not reachable at http://192.168.4.1
   Connect to SkyEcho WiFi network to run integration tests.

   Setup steps:
   1. Enable WiFi on your computer
   2. Connect to network: SkyEcho_XXXX (e.g., SkyEcho_3155)
   3. Wait for connection to establish
   4. Rerun tests: just test-integration''';
}

/// Prints formatted debug information for device status or configuration.
///
/// Accepts either a [DeviceStatus] or [SetupConfig] and prints a formatted
/// summary of key fields for debugging integration tests.
///
/// **Usage**:
/// ```dart
/// final status = await client.fetchStatus();
/// printDeviceInfo(status);
/// ```
///
/// **Parameters**:
/// - [data]: Either `DeviceStatus` or `SetupConfig` instance
void printDeviceInfo(dynamic data) {
  if (data is DeviceStatus) {
    print('✅ Successfully fetched status from real device:');
    print('   WiFi Version: ${data.wifiVersion}');
    print('   SSID: ${data.ssid}');
    print('   ADS-B Version: ${data.adsbVersion}');
    print('   Serial Number: ${data.serialNumber}');
    print('   Clients: ${data.clientsConnected}');
    print('   Coredump: ${data.coredump}');
    print('   Healthy: ${data.isHealthy}');
  } else if (data is SetupConfig) {
    print('✅ Successfully fetched config from real device:');
    print('   ICAO: ${data.icaoAddress}');
    print('   Callsign: ${data.callsign}');
    print('   Receiver Mode: ${data.receiverMode}');
    print('   Stall Speed: ${data.stallSpeedKnots} knots');
    print('   UAT Enabled: ${data.uatEnabled}');
    print('   1090ES Enabled: ${data.es1090Enabled}');
    print('   1090ES Transmit: ${data.es1090TransmitEnabled}');
  } else {
    print('⚠️  Unknown data type: ${data.runtimeType}');
  }
}
