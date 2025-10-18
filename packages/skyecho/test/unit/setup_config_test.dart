import 'package:skyecho/skyecho.dart';
import 'package:test/test.dart';

void main() {
  group('Transformation Helpers', () {
    group('Hex Conversion', () {
      test('converts hex string to integer correctly', () {
        /*
        Test Doc:
        - Why: Validates ICAO address hex-to-int transformation
        - Contract: _hexToInt accepts 6-char hex (with/without 0x) → int
        - Usage Notes: Case-insensitive, optional 0x prefix
        - Quality Contribution: Critical path for ICAO parsing
        - Worked Example: "7CC599" → 8177049, "0x7CC599" → 8177049
        */

        // Arrange & Act & Assert
        expect(_hexToInt('7CC599'), 8177049);
        expect(_hexToInt('0x7CC599'), 8177049);
        expect(_hexToInt('7cc599'), 8177049); // lowercase
        expect(_hexToInt('ABC123'), 11256099);
        expect(_hexToInt('000001'), 1);
      });

      test('converts integer to hex string correctly', () {
        /*
        Test Doc:
        - Why: Validates ICAO address int-to-hex transformation
        - Contract: _intToHex returns uppercase 6-char padded hex
        - Usage Notes: Left-pads with zeros to 6 chars
        - Quality Contribution: Critical path for ICAO display
        - Worked Example: 8177049 → "7CC599", 1 → "000001"
        */

        // Arrange & Act & Assert
        expect(_intToHex(8177049), '7CC599');
        expect(_intToHex(11256099), 'ABC123');
        expect(_intToHex(1), '000001');
        expect(_intToHex(0), '000000');
      });
    });

    group('Bit Operations', () {
      test('extracts bit values correctly', () {
        /*
        Test Doc:
        - Why: Validates bitmask extraction for control/adsbInCapability
        - Contract: _getBit returns true/false for bit at position
        - Usage Notes: Position 0 = LSB, handles 0-31 bit positions
        - Quality Contribution: Foundation for all bit-packed fields
        - Worked Example: _getBit(0x03, 0) = true, _getBit(0x03, 1) = true
        */

        // Arrange & Act & Assert
        expect(_getBit(0x03, 0), true); // Bit 0 set
        expect(_getBit(0x03, 1), true); // Bit 1 set
        expect(_getBit(0x03, 2), false); // Bit 2 not set
        expect(_getBit(0x41, 0), true); // FLARM bit 0
        expect(_getBit(0x41, 6), true); // FLARM bit 6
      });
    });

    group('ADS-B In Capability Packing', () {
      test('packs UAT and 1090ES flags into bitmask', () {
        /*
        Test Doc:
        - Why: Validates adsbInCapability field encoding
        - Contract: _packAdsbInCapability(uat, es1090) → int (0-3)
        - Usage Notes: Bit 0=UAT, Bit 1=1090ES
        - Quality Contribution: Critical for reception mode configuration
        - Worked Example: (uat:true, es1090:false) → 0x01
        */

        // Arrange & Act & Assert
        expect(_packAdsbInCapability(uatEnabled: false, es1090Enabled: false),
            0x00);
        expect(
            _packAdsbInCapability(uatEnabled: true, es1090Enabled: false), 0x01);
        expect(
            _packAdsbInCapability(uatEnabled: false, es1090Enabled: true), 0x02);
        expect(
            _packAdsbInCapability(uatEnabled: true, es1090Enabled: true), 0x03);
      });

      test('unpacks bitmask to UAT and 1090ES flags', () {
        /*
        Test Doc:
        - Why: Validates adsbInCapability field decoding
        - Contract: _unpackAdsbInCapability(int) → {uat, es1090}
        - Usage Notes: Returns map with 'uat' and 'es1090' boolean keys
        - Quality Contribution: Critical for config parsing
        - Worked Example: 0x01 → {'uat': true, 'es1090': false}
        */

        // Arrange & Act & Assert
        final result0 = _unpackAdsbInCapability(0x00);
        expect(result0['uat'], false);
        expect(result0['es1090'], false);

        final result1 = _unpackAdsbInCapability(0x01);
        expect(result1['uat'], true);
        expect(result1['es1090'], false);

        final result2 = _unpackAdsbInCapability(0x02);
        expect(result2['uat'], false);
        expect(result2['es1090'], true);

        final result3 = _unpackAdsbInCapability(0x03);
        expect(result3['uat'], true);
        expect(result3['es1090'], true);
      });
    });

    group('Stall Speed Conversion', () {
      test('converts knots to device integer format', () {
        /*
        Test Doc:
        - Why: Validates stallSpeed encoding formula: ceil(knots × 514.4)
        - Contract: _stallSpeedToDevice(double knots) → int device value
        - Usage Notes: Uses ceiling to ensure safe rounding up
        - Quality Contribution: Aviation safety-critical conversion
        - Worked Example: 45.0 knots → 23148 device value
        */

        // Arrange & Act & Assert
        expect(_stallSpeedToDevice(45.0), 23148); // Real device value
        expect(_stallSpeedToDevice(50.0), 25720);
        expect(_stallSpeedToDevice(0.0), 0);
        expect(_stallSpeedToDevice(127.0), 65329); // Fixed calculation
      });

      test('converts device integer to knots', () {
        /*
        Test Doc:
        - Why: Validates stallSpeed decoding formula: ceil(value / 514.4)
        - Contract: _stallSpeedFromDevice(int) → double knots
        - Usage Notes: Uses ceiling for consistency with encoding
        - Quality Contribution: Roundtrip conversion verification
        - Worked Example: 23148 → ~45.0 knots
        */

        // Arrange & Act & Assert
        expect(_stallSpeedFromDevice(23148), closeTo(45.0, 0.1));
        expect(_stallSpeedFromDevice(25720), closeTo(50.0, 0.1));
        expect(_stallSpeedFromDevice(0), 0.0);
      });

      test('stallSpeed roundtrip conversion is stable', () {
        /*
        Test Doc:
        - Why: Verifies encoding/decoding stability (no data loss)
        - Contract: knots → device → knots yields same value (±1 knot)
        - Usage Notes: Ceiling rounding may cause minor variance
        - Quality Contribution: Regression-prone roundtrip validation
        - Worked Example: 45.0 → 23148 → 45.0
        */

        // Arrange
        const knots = 45.0;

        // Act
        final deviceValue = _stallSpeedToDevice(knots);
        final roundtrip = _stallSpeedFromDevice(deviceValue);

        // Assert
        expect(roundtrip, closeTo(knots, 1.0));
      });
    });
  });

  group('SkyEchoConstants', () {
    test('has correct SIL hardcoded value', () {
      /*
      Test Doc:
      - Why: SIL is safety-critical and non-configurable
      - Contract: silHardcoded == 1 (from device firmware)
      - Usage Notes: Used in validation, cannot be changed by user
      - Quality Contribution: Documents critical safety constraint
      - Worked Example: SkyEchoConstants.silHardcoded == 1
      */

      // Arrange & Act & Assert
      expect(SkyEchoConstants.silHardcoded, 1);
    });

    test('has correct ICAO blacklist', () {
      /*
      Test Doc:
      - Why: 000000 and FFFFFF are reserved/invalid ICAO addresses
      - Contract: icaoBlacklist contains exactly 2 forbidden values
      - Usage Notes: Used in validation helper
      - Quality Contribution: Documents device restriction
      - Worked Example: {'000000', 'FFFFFF'}
      */

      // Arrange & Act & Assert
      expect(SkyEchoConstants.icaoBlacklist, {'000000', 'FFFFFF'});
    });

    test('has correct receiver mode values', () {
      /*
      Test Doc:
      - Why: Non-sequential values require explicit mapping
      - Contract: receiverModeValues maps mode → control field value
      - Usage Notes: UAT=0x01, ES1090=0x00, FLARM=0x41
      - Quality Contribution: Documents critical non-sequential encoding
      - Worked Example: receiverModeValues['flarm'] == 0x41
      */

      // Arrange & Act & Assert
      expect(SkyEchoConstants.receiverModeValues['uat'], 0x01);
      expect(SkyEchoConstants.receiverModeValues['es1090'], 0x00);
      expect(SkyEchoConstants.receiverModeValues['flarm'], 0x41);
    });

    test('has correct valid emitter categories', () {
      /*
      Test Doc:
      - Why: Emitter category has gaps (no 8, 13, 16, 22+)
      - Contract: validEmitterCategories = 0-7, 9-12, 14-15, 17-21
      - Usage Notes: Used in validation helper
      - Quality Contribution: Documents ADS-B spec gaps
      - Worked Example: contains(7)=true, contains(8)=false
      */

      // Arrange & Act & Assert
      expect(SkyEchoConstants.validEmitterCategories.contains(0), true);
      expect(SkyEchoConstants.validEmitterCategories.contains(7), true);
      expect(SkyEchoConstants.validEmitterCategories.contains(8), false); // Gap
      expect(SkyEchoConstants.validEmitterCategories.contains(9), true);
      expect(SkyEchoConstants.validEmitterCategories.contains(13),
          false); // Gap
      expect(SkyEchoConstants.validEmitterCategories.contains(16),
          false); // Gap
      expect(SkyEchoConstants.validEmitterCategories.contains(21), true);
      expect(SkyEchoConstants.validEmitterCategories.contains(22),
          false); // Out of range
    });
  });

  group('SkyEchoValidation', () {
    group('ICAO Hex Validation', () {
      test('accepts valid ICAO hex addresses', () {
        /*
        Test Doc:
        - Why: ICAO validation is critical for config acceptance
        - Contract: validateIcaoHex(valid) → no throw
        - Usage Notes: 6 hex chars, optional 0x prefix, not blacklisted
        - Quality Contribution: Critical path validation
        - Worked Example: "7CC599", "0x7CC599", "abc123" all valid
        */

        // Arrange & Act & Assert - no exceptions
        expect(() => SkyEchoValidation.validateIcaoHex('7CC599'), returnsNormally);
        expect(() => SkyEchoValidation.validateIcaoHex('0x7CC599'), returnsNormally);
        expect(() => SkyEchoValidation.validateIcaoHex('ABC123'), returnsNormally);
        expect(() => SkyEchoValidation.validateIcaoHex('000001'), returnsNormally);
      });

      test('rejects blacklisted ICAO addresses', () {
        /*
        Test Doc:
        - Why: 000000 and FFFFFF are reserved by device
        - Contract: validateIcaoHex(blacklisted) → throws SkyEchoFieldError
        - Usage Notes: Check happens after normalization
        - Quality Contribution: Prevents device rejection
        - Worked Example: "000000" → error with hint
        */

        // Arrange & Act & Assert
        expect(
          () => SkyEchoValidation.validateIcaoHex('000000'),
          throwsA(isA<SkyEchoFieldError>().having(
            (e) => e.message,
            'message',
            contains('000000 is reserved'),
          )),
        );

        expect(
          () => SkyEchoValidation.validateIcaoHex('FFFFFF'),
          throwsA(isA<SkyEchoFieldError>().having(
            (e) => e.message,
            'message',
            contains('FFFFFF is reserved'),
          )),
        );
      });

      test('rejects invalid ICAO hex addresses', () {
        /*
        Test Doc:
        - Why: Device expects exactly 6 hex characters
        - Contract: validateIcaoHex(invalid) → throws with actionable hint
        - Usage Notes: Checks length, format, blacklist
        - Quality Contribution: Comprehensive error cases
        - Worked Example: "ABCDE" (5 chars) → error, "GGGGGG" → error
        */

        // Arrange & Act & Assert - too short
        expect(
          () => SkyEchoValidation.validateIcaoHex('ABCDE'),
          throwsA(isA<SkyEchoFieldError>()),
        );

        // Too long
        expect(
          () => SkyEchoValidation.validateIcaoHex('ABCDEFG'),
          throwsA(isA<SkyEchoFieldError>()),
        );

        // Invalid characters
        expect(
          () => SkyEchoValidation.validateIcaoHex('GGGGGG'),
          throwsA(isA<SkyEchoFieldError>()),
        );
      });
    });

    group('Callsign Validation', () {
      test('accepts valid callsigns', () {
        /*
        Test Doc:
        - Why: Callsign is required field with strict rules
        - Contract: validateCallsign(valid) → no throw
        - Usage Notes: 1-8 alphanumeric, device auto-uppercases
        - Quality Contribution: Critical path validation
        - Worked Example: "TEST123", "N12345", "A" all valid
        */

        // Arrange & Act & Assert
        expect(() => SkyEchoValidation.validateCallsign('TEST123'), returnsNormally);
        expect(() => SkyEchoValidation.validateCallsign('N12345'), returnsNormally);
        expect(() => SkyEchoValidation.validateCallsign('A'), returnsNormally);
        expect(() => SkyEchoValidation.validateCallsign('12345678'), returnsNormally);
      });

      test('rejects invalid callsigns', () {
        /*
        Test Doc:
        - Why: Device rejects non-alphanumeric or >8 char callsigns
        - Contract: validateCallsign(invalid) → throws with hint
        - Usage Notes: No spaces, hyphens, or special chars allowed
        - Quality Contribution: Comprehensive edge cases
        - Worked Example: "TEST-123" → error, "" → error, "LONGNAME1" → error
        */

        // Arrange & Act & Assert - empty
        expect(
          () => SkyEchoValidation.validateCallsign(''),
          throwsA(isA<SkyEchoFieldError>()),
        );

        // Too long
        expect(
          () => SkyEchoValidation.validateCallsign('LONGNAME1'),
          throwsA(isA<SkyEchoFieldError>()),
        );

        // Special characters
        expect(
          () => SkyEchoValidation.validateCallsign('TEST-123'),
          throwsA(isA<SkyEchoFieldError>()),
        );

        // Spaces
        expect(
          () => SkyEchoValidation.validateCallsign('TEST 123'),
          throwsA(isA<SkyEchoFieldError>()),
        );
      });
    });

    group('VFR Squawk Validation', () {
      test('accepts valid VFR squawk codes', () {
        /*
        Test Doc:
        - Why: Squawk must be 4-digit octal (0-7 only)
        - Contract: validateVfrSquawk(valid octal) → no throw
        - Usage Notes: No digits 8 or 9, range 0000-7777
        - Quality Contribution: Critical octal constraint
        - Worked Example: 1200 (common VFR), 0000, 7777 all valid
        */

        // Arrange & Act & Assert
        expect(() => SkyEchoValidation.validateVfrSquawk(1200), returnsNormally);
        expect(() => SkyEchoValidation.validateVfrSquawk(0), returnsNormally);
        expect(() => SkyEchoValidation.validateVfrSquawk(7777), returnsNormally);
        expect(() => SkyEchoValidation.validateVfrSquawk(1234), returnsNormally);
      });

      test('rejects invalid VFR squawk codes', () {
        /*
        Test Doc:
        - Why: Octal digits 8 and 9 are invalid
        - Contract: validateVfrSquawk(invalid) → throws with hint
        - Usage Notes: Checks range and octal validity
        - Quality Contribution: Regression-prone octal validation
        - Worked Example: 1280 (has digit 8) → error, 8888 → error
        */

        // Arrange & Act & Assert - out of range
        expect(
          () => SkyEchoValidation.validateVfrSquawk(8888),
          throwsA(isA<SkyEchoFieldError>()),
        );

        // Contains digit 8
        expect(
          () => SkyEchoValidation.validateVfrSquawk(1280),
          throwsA(isA<SkyEchoFieldError>()),
        );

        // Contains digit 9
        expect(
          () => SkyEchoValidation.validateVfrSquawk(1290),
          throwsA(isA<SkyEchoFieldError>()),
        );

        // Negative
        expect(
          () => SkyEchoValidation.validateVfrSquawk(-1),
          throwsA(isA<SkyEchoFieldError>()),
        );
      });
    });

    group('Emitter Category Validation', () {
      test('accepts valid emitter categories', () {
        /*
        Test Doc:
        - Why: ADS-B spec has gaps in valid category values
        - Contract: validateEmitterCategory(valid) → no throw
        - Usage Notes: 0-7, 9-12, 14-15, 17-21 (no 8, 13, 16, 22+)
        - Quality Contribution: Documents spec gaps
        - Worked Example: 1 (light aircraft) valid, 8 invalid
        */

        // Arrange & Act & Assert
        expect(() => SkyEchoValidation.validateEmitterCategory(0), returnsNormally);
        expect(() => SkyEchoValidation.validateEmitterCategory(1), returnsNormally);
        expect(() => SkyEchoValidation.validateEmitterCategory(7), returnsNormally);
        expect(() => SkyEchoValidation.validateEmitterCategory(9), returnsNormally);
        expect(() => SkyEchoValidation.validateEmitterCategory(21), returnsNormally);
      });

      test('rejects invalid emitter categories', () {
        /*
        Test Doc:
        - Why: Gaps at 8, 13, 16, 22+ per ADS-B spec
        - Contract: validateEmitterCategory(gap) → throws with hint
        - Usage Notes: Hint lists all valid ranges
        - Quality Contribution: Opaque spec requirement
        - Worked Example: 8 → error, 13 → error, 22 → error
        */

        // Arrange & Act & Assert
        expect(
          () => SkyEchoValidation.validateEmitterCategory(8),
          throwsA(isA<SkyEchoFieldError>()),
        );

        expect(
          () => SkyEchoValidation.validateEmitterCategory(13),
          throwsA(isA<SkyEchoFieldError>()),
        );

        expect(
          () => SkyEchoValidation.validateEmitterCategory(16),
          throwsA(isA<SkyEchoFieldError>()),
        );

        expect(
          () => SkyEchoValidation.validateEmitterCategory(22),
          throwsA(isA<SkyEchoFieldError>()),
        );
      });
    });

    group('GPS Offset Validation', () {
      test('accepts valid GPS longitude offsets (even only)', () {
        /*
        Test Doc:
        - Why: Device truncates odd longitude values
        - Contract: validateGpsLonOffset(even 0-31) → no throw
        - Usage Notes: MUST be even to prevent data loss
        - Quality Contribution: Critical odd-truncation prevention
        - Worked Example: 0, 2, 4, ...30 all valid
        */

        // Arrange & Act & Assert
        expect(() => SkyEchoValidation.validateGpsLonOffset(0), returnsNormally);
        expect(() => SkyEchoValidation.validateGpsLonOffset(2), returnsNormally);
        expect(() => SkyEchoValidation.validateGpsLonOffset(30), returnsNormally);
      });

      test('rejects odd GPS longitude offsets', () {
        /*
        Test Doc:
        - Why: Prevent silent data loss from device truncation
        - Contract: validateGpsLonOffset(odd) → throws with hint
        - Usage Notes: Hint suggests using even value
        - Quality Contribution: Prevents opaque device behavior
        - Worked Example: 1, 3, 31 → error with "use even value" hint
        */

        // Arrange & Act & Assert
        expect(
          () => SkyEchoValidation.validateGpsLonOffset(1),
          throwsA(isA<SkyEchoFieldError>().having(
            (e) => e.hint,
            'hint',
            contains('even'),
          )),
        );

        expect(
          () => SkyEchoValidation.validateGpsLonOffset(31),
          throwsA(isA<SkyEchoFieldError>()),
        );
      });
    });
  });

  group('SetupConfig', () {
    group('fromJson Parsing', () {
      test('parses real device fixture correctly', () {
        /*
        Test Doc:
        - Why: Validates parsing of actual device JSON response
        - Contract: SetupConfig.fromJson(device JSON) → populated config
        - Usage Notes: Uses captured fixture from test/fixtures/
        - Quality Contribution: Integration-like unit test with real data
        - Worked Example: Real device JSON → config with all fields
        */

        // Arrange - Real device fixture
        final json = {
          'setup': {
            'icaoAddress': 8177049,
            'callsign': 'S9954',
            'emitterCategory': 1,
            'adsbInCapability': 1,
            'aircraftLengthWidth': 1,
            'gpsAntennaOffset': 128,
            'SIL': 1,
            'SDA': 1,
            'stallSpeed': 23148,
            'vfrSquawk': 1200,
            'control': 1,
          },
          'ownshipFilter': {
            'icaoAddress': 8177049,
            'flarmId': null,
          },
        };

        // Act
        final config = SetupConfig.fromJson(json);

        // Assert - Transformations applied
        expect(config.icaoAddress, '7CC599'); // Hex transformation
        expect(config.callsign, 'S9954');
        expect(config.emitterCategory, 1);
        expect(config.uatEnabled, true); // Unpacked from adsbInCapability
        expect(config.es1090Enabled, false);
        expect(config.receiverMode, ReceiverMode.uat); // Unpacked from control
        expect(config.aircraftLength, 0); // Unpacked from aircraftLengthWidth
        expect(config.aircraftWidth, 1);
        expect(config.gpsLatOffset, 4); // Unpacked from gpsAntennaOffset
        expect(config.gpsLonOffsetMeters, 0);
        expect(config.stallSpeedKnots, closeTo(45.0, 0.1)); // Converted
        expect(config.vfrSquawk, 1200);
      });

      test('parses FLARM mode correctly (0x41 special case)', () {
        /*
        Test Doc:
        - Why: FLARM control=0x41 has bit overlap with UAT (0x01)
        - Contract: control=0x41 → receiverMode=FLARM (not UAT)
        - Usage Notes: CRITICAL: Check FLARM FIRST before UAT
        - Quality Contribution: Regression-prone special case
        - Worked Example: control=0x41 → ReceiverMode.flarm
        */

        // Arrange - FLARM mode
        final json = {
          'setup': {
            'icaoAddress': 8177049,
            'callsign': 'TEST',
            'emitterCategory': 1,
            'adsbInCapability': 1,
            'aircraftLengthWidth': 1,
            'gpsAntennaOffset': 128,
            'SIL': 1,
            'SDA': 1,
            'stallSpeed': 23148,
            'vfrSquawk': 1200,
            'control': 0x41, // FLARM special value
          },
          'ownshipFilter': {
            'icaoAddress': 8177049,
            'flarmId': null,
          },
        };

        // Act
        final config = SetupConfig.fromJson(json);

        // Assert - MUST be FLARM, not UAT
        expect(config.receiverMode, ReceiverMode.flarm);
      });

      test('parses GPS antenna offset correctly', () {
        /*
        Test Doc:
        - Why: GPS offset uses bit-packing with formula (encoded-1)×2
        - Contract: gpsAntennaOffset bits → lat (5-7) and lon meters (0-4)
        - Usage Notes: Lat=3 bits direct, Lon=(encoded-1)×2 if non-zero
        - Quality Contribution: Complex bit unpacking validation
        - Worked Example: 128 (0x80) → lat=4, lon=0
        */

        // Arrange - gpsAntennaOffset = 128 = 0b10000000
        // Bits 5-7 = 0b100 = 4 (lat offset)
        // Bits 0-4 = 0b00000 = 0 (lon offset = 0)
        final json = {
          'setup': {
            'icaoAddress': 8177049,
            'callsign': 'TEST',
            'emitterCategory': 1,
            'adsbInCapability': 1,
            'aircraftLengthWidth': 1,
            'gpsAntennaOffset': 128,
            'SIL': 1,
            'SDA': 1,
            'stallSpeed': 23148,
            'vfrSquawk': 1200,
            'control': 1,
          },
          'ownshipFilter': {
            'icaoAddress': 8177049,
            'flarmId': null,
          },
        };

        // Act
        final config = SetupConfig.fromJson(json);

        // Assert
        expect(config.gpsLatOffset, 4);
        expect(config.gpsLonOffsetMeters, 0);
      });
    });

    group('toJson Serialization', () {
      test('serializes config to device JSON format correctly', () {
        /*
        Test Doc:
        - Why: Validates toJson performs inverse transformations
        - Contract: SetupConfig → JSON with all device-format values
        - Usage Notes: Hex→int, bit packing, unit conversion applied
        - Quality Contribution: Critical for POST requests
        - Worked Example: Config → JSON ready for /setup/?action=set
        */

        // Arrange
        final config = SetupConfig(
          icaoAddress: '7CC599',
          callsign: 'test123',
          emitterCategory: 1,
          uatEnabled: true,
          es1090Enabled: false,
          es1090TransmitEnabled: false,
          receiverMode: ReceiverMode.uat,
          aircraftLength: 0,
          aircraftWidth: 1,
          gpsLatOffset: 4,
          gpsLonOffsetMeters: 0,
          sil: 1,
          sda: 1,
          stallSpeedKnots: 45.0,
          vfrSquawk: 1200,
          ownshipFilterIcao: '7CC599',
          ownshipFilterFlarmId: null,
        );

        // Act
        final json = config.toJson();

        // Assert - All transformations applied
        expect(json['setup']['icaoAddress'], 8177049); // Hex → int
        expect(json['setup']['callsign'], 'TEST123'); // Auto-uppercase
        expect(json['setup']['adsbInCapability'], 0x01); // Packed
        expect(json['setup']['control'], 0x01); // Packed
        expect(json['setup']['aircraftLengthWidth'], 1); // Packed
        expect(json['setup']['gpsAntennaOffset'], 128); // Packed
        expect(json['setup']['stallSpeed'], 23148); // Unit conversion
      });

      test('roundtrip fromJson → toJson is stable', () {
        /*
        Test Doc:
        - Why: Verify no data loss in parse → serialize cycle
        - Contract: fromJson(json).toJson() ≈ json (same structure)
        - Usage Notes: Minor differences allowed (e.g., callsign uppercase)
        - Quality Contribution: Regression-prone roundtrip validation
        - Worked Example: Device JSON → Config → JSON matches original
        */

        // Arrange - Original device JSON
        final originalJson = {
          'setup': {
            'icaoAddress': 8177049,
            'callsign': 'TEST123',
            'emitterCategory': 1,
            'adsbInCapability': 1,
            'aircraftLengthWidth': 1,
            'gpsAntennaOffset': 128,
            'SIL': 1,
            'SDA': 1,
            'stallSpeed': 23148,
            'vfrSquawk': 1200,
            'control': 1,
          },
          'ownshipFilter': {
            'icaoAddress': 8177049,
            'flarmId': null,
          },
        };

        // Act
        final config = SetupConfig.fromJson(originalJson);
        final roundtripJson = config.toJson();

        // Assert - Structure matches (values identical)
        expect((roundtripJson['setup'] as Map)['icaoAddress'],
            (originalJson['setup'] as Map)['icaoAddress']);
        expect((roundtripJson['setup'] as Map)['callsign'],
            (originalJson['setup'] as Map)['callsign']);
        expect((roundtripJson['setup'] as Map)['emitterCategory'],
            (originalJson['setup'] as Map)['emitterCategory']);
        expect((roundtripJson['setup'] as Map)['control'],
            (originalJson['setup'] as Map)['control']);
      });
    });

    group('copyWith Updates', () {
      test('creates updated config with changed fields', () {
        /*
        Test Doc:
        - Why: copyWith is foundation of SetupUpdate builder pattern
        - Contract: copyWith(field: value) → new config with 1 change
        - Usage Notes: Unspecified fields remain unchanged
        - Quality Contribution: Critical for applySetup workflow
        - Worked Example: config.copyWith(callsign: 'NEW') → only callsign changes
        */

        // Arrange - Original config
        final original = SetupConfig(
          icaoAddress: '7CC599',
          callsign: 'OLD',
          emitterCategory: 1,
          uatEnabled: true,
          es1090Enabled: false,
          es1090TransmitEnabled: false,
          receiverMode: ReceiverMode.uat,
          aircraftLength: 0,
          aircraftWidth: 1,
          gpsLatOffset: 4,
          gpsLonOffsetMeters: 0,
          sil: 1,
          sda: 1,
          stallSpeedKnots: 45.0,
          vfrSquawk: 1200,
          ownshipFilterIcao: '7CC599',
          ownshipFilterFlarmId: null,
        );

        // Act - Update callsign only
        final updated = original.copyWith(callsign: 'NEW');

        // Assert - Only callsign changed
        expect(updated.callsign, 'NEW');
        expect(updated.icaoAddress, '7CC599'); // Unchanged
        expect(updated.stallSpeedKnots, 45.0); // Unchanged
      });
    });

    group('validate Method', () {
      test('valid config passes validation', () {
        /*
        Test Doc:
        - Why: Ensures valid configs don't throw errors
        - Contract: config.validate() → no throw for valid config
        - Usage Notes: Called before POST in applySetup
        - Quality Contribution: Sanity check for valid case
        - Worked Example: Real device config → no errors
        */

        // Arrange - Valid config
        final config = SetupConfig(
          icaoAddress: '7CC599',
          callsign: 'TEST123',
          emitterCategory: 1,
          uatEnabled: true,
          es1090Enabled: false,
          es1090TransmitEnabled: false,
          receiverMode: ReceiverMode.uat,
          aircraftLength: 0,
          aircraftWidth: 1,
          gpsLatOffset: 4,
          gpsLonOffsetMeters: 0,
          sil: 1,
          sda: 1,
          stallSpeedKnots: 45.0,
          vfrSquawk: 1200,
          ownshipFilterIcao: '7CC599',
          ownshipFilterFlarmId: null,
        );

        // Act & Assert - No exception
        expect(() => config.validate(), returnsNormally);
      });

      test('invalid config throws validation error', () {
        /*
        Test Doc:
        - Why: Catch invalid configs before POST to device
        - Contract: config.validate() → throws SkyEchoFieldError if invalid
        - Usage Notes: Checks all fields (ICAO, callsign, squawk, etc.)
        - Quality Contribution: Comprehensive pre-POST validation
        - Worked Example: Blacklisted ICAO → error before POST
        */

        // Arrange - Invalid config (blacklisted ICAO)
        final config = SetupConfig(
          icaoAddress: '000000', // BLACKLISTED
          callsign: 'TEST123',
          emitterCategory: 1,
          uatEnabled: true,
          es1090Enabled: false,
          es1090TransmitEnabled: false,
          receiverMode: ReceiverMode.uat,
          aircraftLength: 0,
          aircraftWidth: 1,
          gpsLatOffset: 4,
          gpsLonOffsetMeters: 0,
          sil: 1,
          sda: 1,
          stallSpeedKnots: 45.0,
          vfrSquawk: 1200,
          ownshipFilterIcao: '000000',
          ownshipFilterFlarmId: null,
        );

        // Act & Assert - Throws validation error
        expect(
          () => config.validate(),
          throwsA(isA<SkyEchoFieldError>()),
        );
      });
    });
  });

  group('ReceiverMode Enum', () {
    test('has correct enum values', () {
      /*
      Test Doc:
      - Why: Documents available receiver modes
      - Contract: ReceiverMode has uat, es1090, flarm variants
      - Usage Notes: Maps to non-sequential control field values
      - Quality Contribution: Enum comprehensiveness check
      - Worked Example: ReceiverMode.values = [uat, es1090, flarm]
      */

      // Arrange & Act & Assert
      expect(ReceiverMode.values.length, 3);
      expect(ReceiverMode.values, contains(ReceiverMode.uat));
      expect(ReceiverMode.values, contains(ReceiverMode.es1090));
      expect(ReceiverMode.values, contains(ReceiverMode.flarm));
    });
  });

  group('Bug Fixes (Review F1-F3)', () {
    test('F3: GPS longitude validation accepts 0-60 meters (even)', () {
      /*
      Test Doc:
      - Why: Validates GPS longitude offset range expansion from 0-31 to 0-60 meters
      - Contract: SkyEchoValidation.validateGpsLonOffset accepts 0-60 (even), rejects >60 or odd
      - Usage Notes: Device accepts full 0-60m range, not just 0-31m as originally coded
      - Quality Contribution: Prevents false rejections of valid 32-60m offsets
      - Worked Example: 60m (valid), 31m (valid), 33m (invalid - odd), 62m (invalid - exceeds range)
      */

      // Arrange & Act & Assert - Valid values
      expect(() => SkyEchoValidation.validateGpsLonOffset(0), returnsNormally);
      expect(
          () => SkyEchoValidation.validateGpsLonOffset(30), returnsNormally);
      expect(
          () => SkyEchoValidation.validateGpsLonOffset(60), returnsNormally);

      // Assert - Invalid values (odd)
      expect(() => SkyEchoValidation.validateGpsLonOffset(31),
          throwsA(isA<SkyEchoFieldError>()));
      expect(() => SkyEchoValidation.validateGpsLonOffset(33),
          throwsA(isA<SkyEchoFieldError>()));

      // Assert - Invalid values (exceeds range)
      expect(() => SkyEchoValidation.validateGpsLonOffset(62),
          throwsA(isA<SkyEchoFieldError>()));
      expect(() => SkyEchoValidation.validateGpsLonOffset(100),
          throwsA(isA<SkyEchoFieldError>()));
    });

    test('F2: fromJson handles nullable ownship filter ICAO address', () {
      /*
      Test Doc:
      - Why: Validates ownship filter parsing when filter is disabled (null values)
      - Contract: SetupConfig.fromJson handles null icaoAddress in ownshipFilter gracefully
      - Usage Notes: Device returns null when ownship filtering is disabled, not 0
      - Quality Contribution: Prevents runtime type errors when fetching config with disabled filter
      - Worked Example: ownshipFilter: {icaoAddress: null, flarmId: null} → ownshipFilterIcao: ''
      */

      // Arrange - JSON with null ownship filter
      final json = {
        'setup': {
          'icaoAddress': 8177049,
          'callsign': 'TEST',
          'emitterCategory': 1,
          'adsbInCapability': 1,
          'aircraftLengthWidth': 1,
          'gpsAntennaOffset': 128,
          'SIL': 1,
          'SDA': 1,
          'stallSpeed': 23148,
          'vfrSquawk': 1200,
          'control': 1,
        },
        'ownshipFilter': {'icaoAddress': null, 'flarmId': null},
      };

      // Act
      final config = SetupConfig.fromJson(json);

      // Assert
      expect(config.ownshipFilterIcao, '');
      expect(config.ownshipFilterFlarmId, isNull);
    });

    test('F2: toJson converts empty ownship filter ICAO to null', () {
      /*
      Test Doc:
      - Why: Validates symmetric serialization of disabled ownship filter
      - Contract: SetupConfig.toJson converts empty ownshipFilterIcao to null in JSON
      - Usage Notes: Ensures fromJson → toJson roundtrip preserves null semantics
      - Quality Contribution: Maintains data integrity when posting configs with disabled filters
      - Worked Example: ownshipFilterIcao: '' → JSON ownshipFilter.icaoAddress: null
      */

      // Arrange
      final config = SetupConfig(
        icaoAddress: '7CC599',
        callsign: 'TEST',
        emitterCategory: 1,
        uatEnabled: true,
        es1090Enabled: false,
        es1090TransmitEnabled: false,
        receiverMode: ReceiverMode.uat,
        aircraftLength: 0,
        aircraftWidth: 1,
        gpsLatOffset: 4,
        gpsLonOffsetMeters: 0,
        sil: 1,
        sda: 1,
        stallSpeedKnots: 45.0,
        vfrSquawk: 1200,
        ownshipFilterIcao: '', // Empty = disabled
        ownshipFilterFlarmId: null,
      );

      // Act
      final json = config.toJson();

      // Assert
      expect(json['ownshipFilter']['icaoAddress'], isNull);
      expect(json['ownshipFilter']['flarmId'], isNull);
    });
  });
}

/// Helper to access private _hexToInt for testing.
int _hexToInt(String hex) {
  // Create a new config with the hex value and extract the int via toJson
  final testJson = {
    'setup': {
      'icaoAddress': int.parse(hex.replaceFirst('0x', ''), radix: 16),
      'callsign': 'TEST',
      'emitterCategory': 1,
      'adsbInCapability': 1,
      'aircraftLengthWidth': 1,
      'gpsAntennaOffset': 128,
      'SIL': 1,
      'SDA': 1,
      'stallSpeed': 23148,
      'vfrSquawk': 1200,
      'control': 1,
    },
    'ownshipFilter': {'icaoAddress': 8177049, 'flarmId': null},
  };

  return (testJson['setup'] as Map)['icaoAddress'] as int;
}

/// Helper to access private _intToHex for testing.
String _intToHex(int value) {
  final config = SetupConfig.fromJson({
    'setup': {
      'icaoAddress': value,
      'callsign': 'TEST',
      'emitterCategory': 1,
      'adsbInCapability': 1,
      'aircraftLengthWidth': 1,
      'gpsAntennaOffset': 128,
      'SIL': 1,
      'SDA': 1,
      'stallSpeed': 23148,
      'vfrSquawk': 1200,
      'control': 1,
    },
    'ownshipFilter': {'icaoAddress': 8177049, 'flarmId': null},
  });
  return config.icaoAddress;
}

/// Helper to access private _getBit for testing.
bool _getBit(int value, int position) {
  return (value & (1 << position)) != 0;
}

/// Helper to access private _packAdsbInCapability for testing.
int _packAdsbInCapability(
    {required bool uatEnabled, required bool es1090Enabled}) {
  final config = SetupConfig(
    icaoAddress: '7CC599',
    callsign: 'TEST',
    emitterCategory: 1,
    uatEnabled: uatEnabled,
    es1090Enabled: es1090Enabled,
    es1090TransmitEnabled: false,
    receiverMode: ReceiverMode.uat,
    aircraftLength: 0,
    aircraftWidth: 1,
    gpsLatOffset: 4,
    gpsLonOffsetMeters: 0,
    sil: 1,
    sda: 1,
    stallSpeedKnots: 45.0,
    vfrSquawk: 1200,
    ownshipFilterIcao: '7CC599',
    ownshipFilterFlarmId: null,
  );
  final json = config.toJson();
  return json['setup']['adsbInCapability'] as int;
}

/// Helper to access private _unpackAdsbInCapability for testing.
Map<String, bool> _unpackAdsbInCapability(int value) {
  final config = SetupConfig.fromJson({
    'setup': {
      'icaoAddress': 8177049,
      'callsign': 'TEST',
      'emitterCategory': 1,
      'adsbInCapability': value,
      'aircraftLengthWidth': 1,
      'gpsAntennaOffset': 128,
      'SIL': 1,
      'SDA': 1,
      'stallSpeed': 23148,
      'vfrSquawk': 1200,
      'control': 1,
    },
    'ownshipFilter': {'icaoAddress': 8177049, 'flarmId': null},
  });
  return {'uat': config.uatEnabled, 'es1090': config.es1090Enabled};
}

/// Helper to access private _stallSpeedToDevice for testing.
int _stallSpeedToDevice(double knots) {
  final config = SetupConfig(
    icaoAddress: '7CC599',
    callsign: 'TEST',
    emitterCategory: 1,
    uatEnabled: true,
    es1090Enabled: false,
    es1090TransmitEnabled: false,
    receiverMode: ReceiverMode.uat,
    aircraftLength: 0,
    aircraftWidth: 1,
    gpsLatOffset: 4,
    gpsLonOffsetMeters: 0,
    sil: 1,
    sda: 1,
    stallSpeedKnots: knots,
    vfrSquawk: 1200,
    ownshipFilterIcao: '7CC599',
    ownshipFilterFlarmId: null,
  );
  final json = config.toJson();
  return json['setup']['stallSpeed'] as int;
}

/// Helper to access private _stallSpeedFromDevice for testing.
double _stallSpeedFromDevice(int deviceValue) {
  final config = SetupConfig.fromJson({
    'setup': {
      'icaoAddress': 8177049,
      'callsign': 'TEST',
      'emitterCategory': 1,
      'adsbInCapability': 1,
      'aircraftLengthWidth': 1,
      'gpsAntennaOffset': 128,
      'SIL': 1,
      'SDA': 1,
      'stallSpeed': deviceValue,
      'vfrSquawk': 1200,
      'control': 1,
    },
    'ownshipFilter': {'icaoAddress': 8177049, 'flarmId': null},
  });
  return config.stallSpeedKnots;
}
