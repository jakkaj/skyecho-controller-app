import 'package:skyecho/skyecho.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() {
  group('DeviceStatus integration with real device', () {
    bool? deviceAvailable;

    setUpAll(() async {
      // Check if device is accessible
      deviceAvailable = await canReachDevice('http://192.168.4.1');
      if (deviceAvailable != true) {
        print(deviceSetupMessage());
      }
    });

    test('given_real_device_when_fetching_status_then_returns_valid_device_status',
        () async {
      if (deviceAvailable != true) {
        markTestSkipped('Device not available at http://192.168.4.1');
      }
      /*
      Test Doc:
      - Why: Validates JSON API endpoint works with real device (integration test)
      - Contract: fetchStatus() successfully retrieves device status from GET /?action=get
      - Usage Notes: Requires device at http://192.168.4.1; skips gracefully if unavailable
      - Quality Contribution: Catches JSON API regressions; validates real device compatibility
      - Worked Example: Real device responds with JSON → DeviceStatus with populated fields
      */

      // Arrange
      final client = SkyEchoClient('http://192.168.4.1');

      // Act
      final status = await client.fetchStatus();

      // Assert - verify we got real data from device
      expect(status.wifiVersion, isNotNull,
          reason: 'WiFi version should be present');
      expect(status.ssid, isNotNull, reason: 'SSID should be present');
      expect(status.ssid, startsWith('SkyEcho'),
          reason: 'SSID should be SkyEcho device');
      expect(status.adsbVersion, isNotNull,
          reason: 'ADS-B version should be present');
      expect(status.serialNumber, isNotNull,
          reason: 'Serial number should be present');
      expect(status.clientsConnected, isNotNull,
          reason: 'Client count should be present');
      expect(status.coredump, isA<bool>(),
          reason: 'Coredump flag should be boolean');

      // Log the actual values for debugging
      printDeviceInfo(status);
    });

    test('given_real_device_when_checking_computed_properties_then_values_are_sensible',
        () async {
      if (deviceAvailable != true) {
        markTestSkipped('Device not available at http://192.168.4.1');
      }
      /*
      Test Doc:
      - Why: Validates computed properties (hasCoredump, isHealthy) work with real device data
      - Contract: Computed properties return sensible values based on device state
      - Usage Notes: Requires device at http://192.168.4.1; skips if unavailable
      - Quality Contribution: Ensures health heuristics work with real data
      - Worked Example: Real device with 1 client + no coredump → isHealthy=true
      */

      // Arrange
      final client = SkyEchoClient('http://192.168.4.1');

      // Act
      final status = await client.fetchStatus();

      // Assert - verify computed properties are sensible
      expect(status.hasCoredump, equals(status.coredump),
          reason: 'hasCoredump should match coredump field');

      // isHealthy should be true if no coredump and has clients
      if (!status.coredump &&
          status.clientsConnected != null &&
          status.clientsConnected! > 0) {
        expect(status.isHealthy, isTrue,
            reason: 'Device should be healthy with clients and no coredump');
      }

      print('✅ Computed properties validated:');
      print('   hasCoredump: ${status.hasCoredump}');
      print('   isHealthy: ${status.isHealthy}');
    });
  });
}
