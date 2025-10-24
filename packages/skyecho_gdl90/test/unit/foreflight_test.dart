import 'dart:typed_data';
import 'package:skyecho_gdl90/skyecho_gdl90.dart';
import 'package:test/test.dart';

void main() {
  group('ForeFlight Extension Messages (0x65)', () {
    // ST005: Full ForeFlight ID message parsing
    test('given_foreflight_id_fixture_when_parsed_then_all_fields_extracted',
        () {
      /*
      Test Doc:
      - Why: Validates ForeFlight Device ID message parsing against real captured data
      - Contract: Parser extracts version, serial, device name, long name, capabilities from 0x65 message
      - Usage Notes: Uses real SkyEcho capture; expects 39-byte payload after CRC stripped by parser
      - Quality Contribution: Ensures correct big-endian and UTF-8 handling for ForeFlight extensions
      - Worked Example: Serial 0x000000002715CE2D → 655740461, Name bytes "SkyEcho\0" → "SkyEcho"
      */

      // Arrange - Build complete frame: 0x7E + message ID + payload + CRC + 0x7E
      // Captured sample (41 bytes total before framing):
      // 65 00 01 00 00 00 00 27 15 ce 2d 53 6b 79 45 63 68 6f 00 53 6b 79 45 63 68 6f 00 00 00 00 00 00 00 00 00 00 00 00 2d f0

      final payload = Uint8List.fromList([
        0x65, // Message ID (ForeFlight)
        0x00, // Sub-ID (Device ID)
        0x01, // Version
        0x00, 0x00, 0x00, 0x00, 0x27, 0x15, 0xCE,
        0x2D, // Serial (BE): 655740461
        0x53, 0x6B, 0x79, 0x45, 0x63, 0x68, 0x6F, 0x00, // "SkyEcho\0"
        0x53, 0x6B, 0x79, 0x45, 0x63, 0x68, 0x6F, 0x00, // "SkyEcho\0" (long)
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // padding (8 bytes)
        0x00, 0x00, 0x00, 0x00, // Capabilities: 0
        0x2D, 0xF0, // CRC (will be stripped by parser)
      ]);

      // Act
      final event = Gdl90Parser.parse(payload);

      // Assert
      expect(event, isA<Gdl90DataEvent>(),
          reason: 'Should parse as valid data event');
      final message = (event as Gdl90DataEvent).message;
      expect(message.messageType, Gdl90MessageType.foreFlightId);
      expect(message.foreFlightSubId, 0);
      expect(message.foreFlightVersion, 1);
      expect(message.serialNumber, 655740461);
      expect(message.deviceName, 'SkyEcho');
      expect(message.deviceLongName, 'SkyEcho');
      expect(message.capabilitiesMask, 0);
    });

    // ST005b: Routing integration test
    test('given_message_id_0x65_when_parsed_then_routes_to_foreflight_parser',
        () {
      /*
      Test Doc:
      - Why: Catches forgotten routing table entry - ensures 0x65 actually gets routed
      - Contract: Parser routes message ID 0x65 to ForeFlight parser (not unknown message error)
      - Usage Notes: Integration test covering full parse path including routing
      - Quality Contribution: Prevents "parser works but never called" bug
      - Worked Example: Message ID 0x65 → _parseForeFlight() → Gdl90DataEvent (not Gdl90ErrorEvent)
      */

      // Arrange
      final payload = Uint8List.fromList([
        0x65, // Message ID
        0x00, // Sub-ID
        0x01, // Version
        // Minimal valid payload (38 bytes total after message ID)
        ...List.filled(36,
            0), // Fill with zeros for other fields (serial(8) + name(8) + long(16) + caps(4) = 36)
        0x00, 0x00, // CRC
      ]);

      // Act
      final event = Gdl90Parser.parse(payload);

      // Assert
      expect(event, isA<Gdl90DataEvent>(),
          reason:
              'Should route to ForeFlight parser, not emit unknown message error');
      expect(event, isNot(isA<Gdl90ErrorEvent>()),
          reason: 'Should not be error event if routing works');
    });

    // ST006: UTF-8 device name decoding
    test('given_utf8_device_name_when_parsed_then_extracts_string_correctly',
        () {
      /*
      Test Doc:
      - Why: Validates UTF-8 string extraction with null termination handling
      - Contract: Parser correctly decodes 8-byte and 16-byte UTF-8 strings, stops at null terminator
      - Usage Notes: Handles both null-terminated and fully-padded strings
      - Quality Contribution: Ensures device identification displays correctly
      - Worked Example: [0x53, 0x6B, 0x79, 0x00, ...] → "Sky" (stops at null)
      */

      // Arrange - Short name with early null termination
      final payload = Uint8List.fromList([
        0x65, 0x00, 0x01,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, // Serial: 1
        0x47, 0x50, 0x53, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, // "GPS\0" + garbage
        0x47, 0x50, 0x53, 0x20, 0x52, 0x65, 0x63, 0x65, // "GPS Receiver"
        0x69, 0x76, 0x65, 0x72, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, // Capabilities
        0x00, 0x00, // CRC
      ]);

      // Act
      final event = Gdl90Parser.parse(payload);

      // Assert
      final message = (event as Gdl90DataEvent).message;
      expect(message.deviceName, 'GPS',
          reason: 'Should stop at null terminator');
      expect(message.deviceLongName, 'GPS Receiver',
          reason: 'Should extract full name');
    });

    // ST006b: Invalid UTF-8 error handling
    test('given_invalid_utf8_when_parsed_then_returns_error_event', () {
      /*
      Test Doc:
      - Why: Tests architectural "never throw" pattern - ensures malformed UTF-8 doesn't throw
      - Contract: Parser returns Gdl90ErrorEvent for invalid UTF-8, never throws exception
      - Usage Notes: Critical for maintaining error handling architecture consistency
      - Quality Contribution: Prevents crashes from malformed device data
      - Worked Example: [0xFF, 0xFF, ...] → Gdl90ErrorEvent("Invalid UTF-8...")
      */

      // Arrange - Invalid UTF-8 sequence in device name
      final payload = Uint8List.fromList([
        0x65, 0x00, 0x01,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, // Serial
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, // Invalid UTF-8
        0x53, 0x6B, 0x79, 0x00, 0x00, 0x00, 0x00, 0x00, // Valid long name
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00,
      ]);

      // Act
      final event = Gdl90Parser.parse(payload);

      // Assert
      expect(event, isA<Gdl90ErrorEvent>(),
          reason: 'Should return error event for invalid UTF-8');
      final error = event as Gdl90ErrorEvent;
      expect(error.reason, contains('UTF-8'),
          reason: 'Error message should mention UTF-8');
    });

    // ST007: Big-endian multi-byte fields
    test('given_big_endian_fields_when_parsed_then_converts_correctly', () {
      /*
      Test Doc:
      - Why: Validates big-endian integer conversion (unusual for GDL90)
      - Contract: Parser correctly decodes 64-bit serial and 32-bit capabilities as big-endian
      - Usage Notes: ForeFlight spec uses big-endian (different from standard GDL90 little-endian)
      - Quality Contribution: Ensures device serial numbers display correctly
      - Worked Example: [0x00, 0x00, 0x00, 0x01] → 1 (not 16777216)
      */

      // Arrange
      final payload = Uint8List.fromList([
        0x65, 0x00, 0x01,
        0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF,
        0xFF, // Serial: 4294967295 (2^32-1)
        0x54, 0x65, 0x73, 0x74, 0x00, 0x00, 0x00, 0x00, // "Test"
        0x54, 0x65, 0x73, 0x74, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x01, // Capabilities: 1 (bit 0 set = WGS84 datum)
        0x00, 0x00,
      ]);

      // Act
      final event = Gdl90Parser.parse(payload);

      // Assert
      final message = (event as Gdl90DataEvent).message;
      expect(message.serialNumber, 4294967295,
          reason: 'Should decode 64-bit big-endian correctly');
      expect(message.capabilitiesMask, 1,
          reason: 'Should decode 32-bit big-endian correctly');
    });

    // ST008: Capabilities bitmask parsing
    test('given_capabilities_bitmask_when_parsed_then_preserves_value', () {
      /*
      Test Doc:
      - Why: Validates capabilities field extraction for future feature detection
      - Contract: Parser extracts capabilities bitmask without interpretation
      - Usage Notes: Bit 0 = altitude datum, bits 1-2 = internet policy, rest reserved
      - Quality Contribution: Enables future capability-based feature enablement
      - Worked Example: 0x00000001 → bit 0 set (WGS84 altitude datum)
      */

      // Arrange - Capabilities with multiple bits set
      final payload = Uint8List.fromList([
        0x65, 0x00, 0x01,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x42, // Serial: 66
        0x44, 0x65, 0x76, 0x00, 0x00, 0x00, 0x00, 0x00, // "Dev"
        0x44, 0x65, 0x76, 0x69, 0x63, 0x65, 0x00, 0x00, // "Device"
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x07, // Capabilities: 0b111 (bits 0-2 set)
        0x00, 0x00,
      ]);

      // Act
      final event = Gdl90Parser.parse(payload);

      // Assert
      final message = (event as Gdl90DataEvent).message;
      expect(message.capabilitiesMask, 7,
          reason: 'Should preserve raw bitmask value');
    });

    // ST010: Unknown sub-ID graceful handling
    test('given_unknown_subid_when_parsed_then_returns_error_event', () {
      /*
      Test Doc:
      - Why: Tests graceful degradation for future ForeFlight extension sub-IDs
      - Contract: Parser returns Gdl90ErrorEvent for unknown sub-IDs, stream continues
      - Usage Notes: Enables forward compatibility with future ForeFlight spec updates
      - Quality Contribution: Prevents parser crashes from new device firmware versions
      - Worked Example: Sub-ID 0x99 → Gdl90ErrorEvent("Unknown ForeFlight sub-ID: 0x99")
      */

      // Arrange - Unknown sub-ID
      final payload = Uint8List.fromList([
        0x65, // Message ID
        0x99, // Unknown sub-ID
        // Rest of payload doesn't matter
        ...List.filled(37, 0),
        0x00, 0x00, // CRC
      ]);

      // Act
      final event = Gdl90Parser.parse(payload);

      // Assert
      expect(event, isA<Gdl90ErrorEvent>(),
          reason: 'Should return error event for unknown sub-ID');
      final error = event as Gdl90ErrorEvent;
      expect(error.reason, contains('sub-ID'),
          reason: 'Error should mention sub-ID issue');
      expect(error.reason, contains('0x99'),
          reason: 'Error should include the unknown sub-ID value');
    });
  });
}
