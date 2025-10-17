import 'package:skyecho/skyecho.dart';
import 'package:test/test.dart';

/// Integration tests for SetupConfig API with real SkyEcho device.
///
/// **Requires:** Physical SkyEcho 2 device at http://192.168.4.1
void main() {
  group('SetupConfig Integration Tests (Real Device)', () {
    late SkyEchoClient client;

    setUp(() {
      client = SkyEchoClient('http://192.168.4.1');
    });

    test('fetches setup configuration from real device', () async {
      /*
      Test Doc:
      - Why: Verify fetchSetupConfig works with real device JSON response
      - Contract: fetchSetupConfig() → SetupConfig with all fields populated
      - Usage Notes: Requires device at http://192.168.4.1
      - Quality Contribution: Real device integration smoke test
      - Worked Example: Device responds with setup JSON → parsed config
      */

      // Arrange & Act
      final config = await client.fetchSetupConfig();

      // Assert - Basic structure
      expect(config, isA<SetupConfig>());
      expect(config.icaoAddress, isNotNull);
      expect(config.callsign, isNotNull);
      expect(config.emitterCategory, greaterThanOrEqualTo(0));
      expect(config.stallSpeedKnots, greaterThanOrEqualTo(0));

      // Print for manual verification
      print('Fetched config from device:');
      print('  ICAO: ${config.icaoAddress}');
      print('  Callsign: ${config.callsign}');
      print('  Receiver Mode: ${config.receiverMode}');
      print('  Stall Speed: ${config.stallSpeedKnots} knots');
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('applies setup configuration and verifies roundtrip', () async {
      /*
      Test Doc:
      - Why: Verify applySetup POST → wait → GET verification cycle
      - Contract: applySetup() → ApplyResult with verified=true
      - Usage Notes: CRITICAL: Waits 2 seconds for device persistence
      - Quality Contribution: Full write-verify integration test
      - Worked Example: Update callsign → verify device accepted change
      */

      // Arrange - Fetch current config
      final originalConfig = await client.fetchSetupConfig();

      // Determine a new callsign (append TEST if space allows)
      final newCallsign =
          originalConfig.callsign.length < 7 ? '${originalConfig.callsign}T' : 'TEST';

      print('Original callsign: ${originalConfig.callsign}');
      print('New callsign: $newCallsign');

      // Act - Apply update with new callsign
      final result = await client.applySetup((update) {
        update.callsign = newCallsign;
      });

      // Assert - Update succeeded and was verified
      expect(result.success, true);
      expect(result.verified, true);
      expect(result.verifiedConfig, isNotNull);
      expect(result.verifiedConfig!.callsign, newCallsign);

      print('ApplyResult: ${result.message}');

      // Cleanup - Restore original callsign
      await client.applySetup((update) {
        update.callsign = originalConfig.callsign;
      });

      print('Restored original callsign: ${originalConfig.callsign}');
    }, timeout: const Timeout(Duration(seconds: 20))); // Allow for 2x 2-second waits

    test('factoryReset initiates device reset', () async {
      /*
      Test Doc:
      - Why: Verify factoryReset API sends loadDefaults payload
      - Contract: factoryReset() → ApplyResult with success=true
      - Usage Notes: **WARNING:** Resets device config (use with caution)
      - Quality Contribution: Critical but destructive operation test
      - Worked Example: POST {"loadDefaults": true} → 200 OK
      */

      // Skip this test by default to prevent accidental resets
      // Uncomment to run (requires manual device reconfiguration after)

      /*
      // Act
      final result = await client.factoryReset();

      // Assert
      expect(result.success, true);
      expect(result.message, contains('Factory reset'));

      print('Factory reset result: ${result.message}');
      */

      print('SKIPPED: Factory reset test (destructive operation)');
    }, skip: 'Destructive test - uncomment to run');
  });
}
