import 'dart:typed_data';

import 'package:skyecho_gdl90/src/crc.dart';
import 'package:test/test.dart';

void main() {
  group('Gdl90Crc - FAA Test Vectors', () {
    test('test_faa_heartbeat_crc_validation', () {
      // FAA GDL90 Public ICD Rev A - Heartbeat example
      // (confirmed in research doc line 756)
      // Message: Heartbeat (ID=0) with 6 payload bytes
      // Expected CRC: 0x8BB3 (LSB-first: 0xB3, 0x8B)
      //
      // Complete frame with CRC appended LSB-first:
      // [Message ID + payload + CRC_LSB + CRC_MSB]
      final frame = Uint8List.fromList([
        0x00, // Message ID: Heartbeat
        0x81, // Status byte 1
        0x41, // Status byte 2
        0xDB, // Timestamp LSB
        0xD0, // Timestamp MSB
        0x08, // Message counts 1
        0x02, // Message counts 2
        0xB3, // CRC LSB
        0x8B, // CRC MSB
      ]);

      // Verify trailing CRC matches
      expect(Gdl90Crc.verifyTrailing(frame), isTrue,
          reason: 'FAA heartbeat example should validate with CRC 0x8BB3');

      // Verify compute() returns expected CRC for message bytes (without CRC)
      final messageBytes = frame.sublist(0, 7);
      expect(Gdl90Crc.compute(messageBytes), equals(0x8BB3),
          reason: 'Computed CRC should match FAA example 0x8BB3');
    });
  });

  group('Gdl90Crc - Core Functionality', () {
    test('test_crc_table_initialization_deterministic', () {
      // Validate table generation is consistent
      // Computing CRC on single byte should use table[byte]
      final singleByte = Uint8List.fromList([0x00]);
      final crc0 = Gdl90Crc.compute(singleByte);

      // Re-computing should give same result (deterministic)
      expect(Gdl90Crc.compute(singleByte), equals(crc0),
          reason: 'CRC computation should be deterministic');

      // Different single byte should give different CRC
      final byte255 = Uint8List.fromList([0xFF]);
      final crc255 = Gdl90Crc.compute(byte255);
      expect(crc255, isNot(equals(crc0)),
          reason: 'Different bytes should produce different CRCs');
    });

    test('test_crc_compute_simple_data', () {
      // Test compute() on known simple data
      // Using a predictable sequence
      final data = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);
      final crc = Gdl90Crc.compute(data);

      // CRC should be 16-bit value
      expect(crc, greaterThanOrEqualTo(0));
      expect(crc, lessThanOrEqualTo(0xFFFF));

      // Same data should always produce same CRC
      expect(Gdl90Crc.compute(data), equals(crc));
    });

    test('test_verify_trailing_valid_frame', () {
      // Create a frame with correct CRC appended
      final message = Uint8List.fromList([0x0A, 0x0B, 0x0C]);
      final crc = Gdl90Crc.compute(message);

      // Append CRC LSB-first
      final frame = Uint8List.fromList([
        ...message,
        crc & 0xFF, // CRC LSB
        (crc >> 8) & 0xFF, // CRC MSB
      ]);

      expect(Gdl90Crc.verifyTrailing(frame), isTrue,
          reason: 'Frame with correct CRC should verify');
    });

    test('test_verify_trailing_corrupted_frame', () {
      // Create a frame with WRONG CRC
      final message = Uint8List.fromList([0x0A, 0x0B, 0x0C]);
      final correctCrc = Gdl90Crc.compute(message);
      final wrongCrc = correctCrc ^ 0xFFFF; // Flip all bits

      final corruptedFrame = Uint8List.fromList([
        ...message,
        wrongCrc & 0xFF,
        (wrongCrc >> 8) & 0xFF,
      ]);

      expect(Gdl90Crc.verifyTrailing(corruptedFrame), isFalse,
          reason: 'Frame with corrupted CRC should not verify');
    });

    test('test_lsb_first_byte_ordering', () {
      // Explicitly test LSB-first byte ordering (critical for GDL90)
      // CRC value 0x8BB3 should be stored as bytes [0xB3, 0x8B]
      final message = Uint8List.fromList([0x12, 0x34]);
      final crc = Gdl90Crc.compute(message);

      // Build frame with CRC appended LSB-first
      final lsbFirst = Uint8List.fromList([
        ...message,
        crc & 0xFF, // LSB first
        (crc >> 8) & 0xFF, // MSB second
      ]);

      // Build frame with CRC appended MSB-first (WRONG for GDL90)
      final msbFirst = Uint8List.fromList([
        ...message,
        (crc >> 8) & 0xFF, // MSB first (wrong)
        crc & 0xFF, // LSB second (wrong)
      ]);

      expect(Gdl90Crc.verifyTrailing(lsbFirst), isTrue,
          reason: 'LSB-first CRC should verify (correct for GDL90)');

      // MSB-first should only validate if CRC happens to be palindromic
      // For most values, it will fail
      if (crc != ((crc & 0xFF) << 8 | (crc >> 8))) {
        expect(Gdl90Crc.verifyTrailing(msbFirst), isFalse,
            reason: 'MSB-first CRC should not verify (wrong for GDL90)');
      }
    });
  });

  group('Gdl90Crc - Edge Cases', () {
    test('test_edge_case_empty_data', () {
      // Empty data should compute CRC of init value (0x0000)
      final empty = Uint8List.fromList([]);
      final crc = Gdl90Crc.compute(empty);

      expect(crc, equals(0x0000),
          reason: 'Empty data should return init value');
    });

    test('test_edge_case_frame_too_short_for_crc', () {
      // Frames shorter than 3 bytes should return false
      // (min: 1 data byte + 2 CRC bytes)
      final tooShort1 = Uint8List.fromList([0x00]);
      final tooShort2 = Uint8List.fromList([0x00, 0x01]);

      expect(Gdl90Crc.verifyTrailing(tooShort1), isFalse,
          reason: '1-byte frame too short for CRC verification');
      expect(Gdl90Crc.verifyTrailing(tooShort2), isFalse,
          reason: '2-byte frame too short for CRC verification');
    });

    test('test_edge_case_null_bytes', () {
      // Message with all null bytes should compute valid CRC
      final nullMessage = Uint8List.fromList([0x00, 0x00, 0x00]);
      final crc = Gdl90Crc.compute(nullMessage);

      // CRC should be deterministic for null bytes
      expect(crc, greaterThanOrEqualTo(0));
      expect(crc, lessThanOrEqualTo(0xFFFF));

      // Build frame with correct CRC
      final frame = Uint8List.fromList([
        ...nullMessage,
        crc & 0xFF,
        (crc >> 8) & 0xFF,
      ]);

      expect(Gdl90Crc.verifyTrailing(frame), isTrue,
          reason: 'Null-byte frame with correct CRC should verify');
    });

    test('test_edge_case_maximum_length', () {
      // Large frame (1000 bytes) should not cause overflow
      final largeMessage = Uint8List(1000);
      // Fill with pattern to make it interesting
      for (var i = 0; i < largeMessage.length; i++) {
        largeMessage[i] = i & 0xFF;
      }

      final crc = Gdl90Crc.compute(largeMessage);

      // CRC should be 16-bit value (no overflow)
      expect(crc, greaterThanOrEqualTo(0));
      expect(crc, lessThanOrEqualTo(0xFFFF));

      // Build and verify large frame
      final largeFrame = Uint8List.fromList([
        ...largeMessage,
        crc & 0xFF,
        (crc >> 8) & 0xFF,
      ]);

      expect(Gdl90Crc.verifyTrailing(largeFrame), isTrue,
          reason: 'Large frame should compute CRC without overflow');
    });
  });
}
