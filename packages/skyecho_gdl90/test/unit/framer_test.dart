import 'dart:typed_data';

import 'package:skyecho_gdl90/src/crc.dart';
import 'package:skyecho_gdl90/src/framer.dart';
import 'package:test/test.dart';

void main() {
  group('Gdl90Framer - Core Functionality', () {
    // T001: Single frame extraction
    test('extracts single valid frame from byte stream', () {
      // Purpose: Validates basic framing (0x7E delimiters)
      // Quality Contribution: Ensures framing protocol is correctly implemented
      // Acceptance Criteria:
      //   - Detects 0x7E start/end flags
      //   - Extracts message bytes
      //   - Validates CRC before emitting

      // Arrange
      final framer = Gdl90Framer();
      final List<Uint8List> frames = [];

      // Valid heartbeat: 7E 00 81 41 DB D0 08 02 B3 8B 7E
      // (FAA test vector from Phase 2)
      final input = Uint8List.fromList([
        0x7E, // Start flag
        0x00, 0x81, 0x41, 0xDB, 0xD0, 0x08, 0x02, // Message
        0xB3, 0x8B, // CRC
        0x7E, // End flag
      ]);

      // Act
      framer.addBytes(input, (frame) => frames.add(frame));

      // Assert
      expect(frames.length, equals(1));
      expect(frames[0].length, equals(9)); // 7 bytes message + 2 bytes CRC
      expect(frames[0][0], equals(0x00)); // Message ID
    });

    // T002: Escape sequence handling at multiple positions
    test('handles escape sequences at multiple positions correctly', () {
      // Purpose: Validates escape sequence de-escaping (0x7D ^ 0x20)
      // Quality Contribution: Prevents data corruption in escaped frames
      // Acceptance Criteria:
      //   - 0x7D 0x5E → 0x7E (flag escape)
      //   - 0x7D 0x5D → 0x7D (escape escape)
      //   - Position 1 (immediately after message ID) works correctly

      // Arrange
      final framer = Gdl90Framer();
      final List<Uint8List> frames = [];

      // Clear message: 00 7E 01 7D 02
      // Escaped: 00 7D5E 01 7D5D 02
      final messageBytes = Uint8List.fromList([0x00, 0x7E, 0x01, 0x7D, 0x02]);
      final crc = Gdl90Crc.compute(messageBytes);

      final input = Uint8List.fromList([
        0x7E, // Start
        0x00, // Message ID
        0x7D, 0x5E, // Position 1: Escaped 0x7E
        0x01, // Regular byte
        0x7D, 0x5D, // Escaped 0x7D
        0x02, // Regular byte
        crc & 0xFF, // CRC LSB
        (crc >> 8) & 0xFF, // CRC MSB
        0x7E, // End
      ]);

      // Act
      framer.addBytes(input, (frame) => frames.add(frame));

      // Assert
      expect(frames.isNotEmpty, isTrue, reason: 'Frame should be extracted');
      final clear = frames[0];
      expect(clear[0], equals(0x00), reason: 'Message ID');
      expect(clear[1], equals(0x7E),
          reason: 'Position 1: De-escaped from 7D5E');
      expect(clear[2], equals(0x01), reason: 'Regular byte');
      expect(clear[3], equals(0x7D), reason: 'De-escaped from 7D5D');
      expect(clear[4], equals(0x02), reason: 'Regular byte');
    });

    // T003: Multiple frames in continuous stream
    test('extracts multiple frames from continuous stream', () {
      // Purpose: Validates stateful frame extraction
      // Quality Contribution: Ensures framing works across multiple messages
      // Acceptance Criteria: Both frames extracted independently

      // Arrange
      final framer = Gdl90Framer();
      final List<Uint8List> frames = [];

      // Two back-to-back frames
      final input = Uint8List.fromList([
        // Frame 1
        0x7E, 0x00, 0x81, 0x41, 0xDB, 0xD0, 0x08, 0x02, 0xB3, 0x8B, 0x7E,
        // Frame 2
        0x7E, 0x00, 0x81, 0x41, 0xDB, 0xD0, 0x08, 0x02, 0xB3, 0x8B, 0x7E,
      ]);

      // Act
      framer.addBytes(input, (frame) => frames.add(frame));

      // Assert
      expect(
        frames.length,
        equals(2),
        reason: 'Both frames should be extracted',
      );
    });

    // T004: Invalid CRC frame rejection
    test('rejects frame with invalid CRC and continues', () {
      // Purpose: Validates robustness to corrupted frames
      // Quality Contribution: Prevents crashes from bad data
      // Acceptance Criteria:
      //   - Invalid frame is silently discarded
      //   - Subsequent valid frame is parsed

      // Arrange
      final framer = Gdl90Framer();
      final List<Uint8List> frames = [];

      // Bad frame followed by good frame
      final input = Uint8List.fromList([
        // Bad CRC
        0x7E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0x7E,
        // Good
        0x7E, 0x00, 0x81, 0x41, 0xDB, 0xD0, 0x08, 0x02, 0xB3, 0x8B, 0x7E,
      ]);

      // Act
      framer.addBytes(input, (frame) => frames.add(frame));

      // Assert
      expect(frames.length, equals(1), reason: 'Only good frame extracted');
    });

    // T005: Incomplete frame buffering
    test('buffers incomplete frame across multiple addBytes calls', () {
      // Purpose: Validates stateful buffering for streaming input
      // Quality Contribution: Handles real UDP fragmentation
      // Acceptance Criteria: Partial frame completed on next chunk

      // Arrange
      final framer = Gdl90Framer();
      final List<Uint8List> frames = [];

      // Split frame across two chunks
      final chunk1 = Uint8List.fromList([0x7E, 0x00, 0x81, 0x41]);
      final chunk2 =
          Uint8List.fromList([0xDB, 0xD0, 0x08, 0x02, 0xB3, 0x8B, 0x7E]);

      // Act
      framer.addBytes(chunk1, (frame) => frames.add(frame));
      expect(frames.length, equals(0), reason: 'Incomplete - no frame yet');

      framer.addBytes(chunk2, (frame) => frames.add(frame));

      // Assert
      expect(
        frames.length,
        equals(1),
        reason: 'Frame completed on second chunk',
      );
    });

    // T006: Escaped CRC bytes
    test('handles escaped CRC bytes correctly', () {
      // Purpose: Validates CRC escaping edge case
      // Quality Contribution: Ensures CRC values 0x7E/0x7D are handled
      // Acceptance Criteria: CRC bytes containing special values are de-escaped

      // Arrange
      final framer = Gdl90Framer();
      final List<Uint8List> frames = [];

      // Create message where CRC will contain 0x7E or 0x7D
      // Message: 00 FF (simple 2-byte message)
      final messageBytes = Uint8List.fromList([0x00, 0xFF]);
      final crc = Gdl90Crc.compute(messageBytes);

      // Build frame with potentially escaped CRC
      final frameBuilder = <int>[0x7E, 0x00, 0xFF];

      // Escape CRC LSB if needed
      final crcLsb = crc & 0xFF;
      if (crcLsb == 0x7E || crcLsb == 0x7D) {
        frameBuilder.addAll([0x7D, crcLsb ^ 0x20]);
      } else {
        frameBuilder.add(crcLsb);
      }

      // Escape CRC MSB if needed
      final crcMsb = (crc >> 8) & 0xFF;
      if (crcMsb == 0x7E || crcMsb == 0x7D) {
        frameBuilder.addAll([0x7D, crcMsb ^ 0x20]);
      } else {
        frameBuilder.add(crcMsb);
      }

      frameBuilder.add(0x7E); // End flag

      final input = Uint8List.fromList(frameBuilder);

      // Act
      framer.addBytes(input, (frame) => frames.add(frame));

      // Assert
      expect(
        frames.isNotEmpty,
        isTrue,
        reason: 'Frame with escaped CRC should be extracted',
      );
    });
  });

  group('Gdl90Framer - Edge Cases', () {
    // T007: No flags in stream
    test('produces no frames when no flags in byte stream', () {
      // Purpose: Validates framer ignores data without flags
      // Quality Contribution: Ensures framer doesn't crash on non-GDL90 data

      // Arrange
      final framer = Gdl90Framer();
      final List<Uint8List> frames = [];

      final input = Uint8List.fromList([0x00, 0x01, 0x02, 0x03, 0x04]);

      // Act
      framer.addBytes(input, (frame) => frames.add(frame));

      // Assert
      expect(frames.length, equals(0), reason: 'No frames without flags');
    });

    // T008: Escape at end of buffer with valid completion
    test('buffers incomplete escape and completes on next byte', () {
      // Purpose: Validates escape sequence buffering across chunks
      // Quality Contribution: Handles fragmented escape sequences

      // Arrange
      final framer = Gdl90Framer();
      final List<Uint8List> frames = [];

      // Chunk 1 ends with 0x7D (incomplete escape)
      final chunk1 = Uint8List.fromList([0x7E, 0x00, 0x7D]);
      // Chunk 2 starts with 0x5E (completes escape to 0x7E)
      final messageBytes = Uint8List.fromList([0x00, 0x7E]);
      final crc = Gdl90Crc.compute(messageBytes);

      // Build chunk2 with proper CRC escaping
      final chunk2Builder = <int>[0x5E]; // Completes escape

      final crcLsb = crc & 0xFF;
      if (crcLsb == 0x7E || crcLsb == 0x7D) {
        chunk2Builder.addAll([0x7D, crcLsb ^ 0x20]);
      } else {
        chunk2Builder.add(crcLsb);
      }

      final crcMsb = (crc >> 8) & 0xFF;
      if (crcMsb == 0x7E || crcMsb == 0x7D) {
        chunk2Builder.addAll([0x7D, crcMsb ^ 0x20]);
      } else {
        chunk2Builder.add(crcMsb);
      }

      chunk2Builder.add(0x7E); // End flag

      final chunk2 = Uint8List.fromList(chunk2Builder);

      // Act
      framer.addBytes(chunk1, (frame) => frames.add(frame));
      expect(frames.length, equals(0), reason: 'Incomplete escape');

      framer.addBytes(chunk2, (frame) => frames.add(frame));

      // Assert
      expect(frames.length, equals(1), reason: 'Escape completed');
      expect(frames[0][1], equals(0x7E), reason: 'De-escaped from 7D 5E');
    });

    // T008b: Escape followed by flag (state machine priority)
    test('treats escape-then-flag as corrupted frame and starts new frame', () {
      // Purpose: Validates flag detection takes precedence over escape
      // Quality Contribution: Prevents state machine bug where flag gets
      // de-escaped

      // Arrange
      final framer = Gdl90Framer();
      final List<Uint8List> frames = [];

      // Frame 1: [00 7D] then flag 0x7E (incomplete escape = corrupted)
      // Frame 2: [01 02] with valid CRC
      final frame2Msg = Uint8List.fromList([0x01, 0x02]);
      final frame2Crc = Gdl90Crc.compute(frame2Msg);

      final input = Uint8List.fromList([
        0x7E, 0x00, 0x7D, 0x7E, // Frame 1: corrupted (incomplete escape)
        0x01, 0x02, // Frame 2 message
        frame2Crc & 0xFF,
        (frame2Crc >> 8) & 0xFF,
        0x7E, // End frame 2
      ]);

      // Act
      framer.addBytes(input, (frame) => frames.add(frame));

      // Assert
      expect(
        frames.length,
        equals(1),
        reason: 'Only second frame should be emitted',
      );
      expect(
        frames[0][0],
        equals(0x01),
        reason: 'First byte of second frame',
      );
    });

    // T009: Truncated frame (missing CRC bytes)
    test('rejects frame with less than 3 bytes', () {
      // Purpose: Validates minimum frame length enforcement
      // Quality Contribution: Prevents index out of bounds errors

      // Arrange
      final framer = Gdl90Framer();
      final List<Uint8List> frames = [];

      // Frame with only 1 byte (no CRC)
      final input = Uint8List.fromList([
        0x7E, 0x00, 0x7E, // Too short (1 byte message, no CRC)
      ]);

      // Act
      framer.addBytes(input, (frame) => frames.add(frame));

      // Assert
      expect(
        frames.length,
        equals(0),
        reason: 'Frame too short should be rejected',
      );
    });

    // T010: Empty frame
    test('rejects frame containing only CRC (zero-length message)', () {
      // Purpose: Validates empty message rejection
      // Quality Contribution: Ensures frames have actual data

      // Arrange
      final framer = Gdl90Framer();
      final List<Uint8List> frames = [];

      // Frame with 0 message bytes, only CRC
      final input = Uint8List.fromList([
        0x7E, 0xFF, 0xFF, 0x7E, // 2 CRC bytes, no message
      ]);

      // Act
      framer.addBytes(input, (frame) => frames.add(frame));

      // Assert
      expect(
        frames.length,
        equals(0),
        reason: 'Empty frame should be rejected',
      );
    });

    // T010b: Unbounded buffer growth protection
    test('discards frame exceeding 868-byte limit and resets', () {
      // Purpose: Validates DoS protection via buffer size limit
      // Quality Contribution: Prevents memory exhaustion attacks

      // Arrange
      final framer = Gdl90Framer();
      final List<Uint8List> frames = [];

      // Start frame, then send 900 bytes without closing flag
      final largeData = Uint8List(910);
      largeData[0] = 0x7E; // Start flag
      for (var i = 1; i < 910; i++) {
        largeData[i] = i & 0xFF;
      }

      // Act
      framer.addBytes(largeData, (frame) => frames.add(frame));

      // Now send a valid frame - should work (buffer was cleared)
      final validFrame = Uint8List.fromList([
        0x7E,
        0x00,
        0x81,
        0x41,
        0xDB,
        0xD0,
        0x08,
        0x02,
        0xB3,
        0x8B,
        0x7E,
      ]);
      framer.addBytes(validFrame, (frame) => frames.add(frame));

      // Assert
      expect(frames.length, equals(1),
          reason: 'Buffer should have been cleared at 868-byte limit, '
              'then valid frame should parse');
    });
  });

  group('Gdl90Framer - Stress Testing', () {
    // T015: Stress test with 1000 consecutive frames
    test('extracts 1000 consecutive frames without memory leaks', () {
      // Purpose: Validates performance and robustness at scale
      // Quality Contribution: Ensures buffer clearing and no memory leaks

      // Arrange
      final framer = Gdl90Framer();
      final List<Uint8List> frames = [];

      // FAA heartbeat frame
      final singleFrame = Uint8List.fromList([
        0x7E,
        0x00,
        0x81,
        0x41,
        0xDB,
        0xD0,
        0x08,
        0x02,
        0xB3,
        0x8B,
        0x7E,
      ]);

      // Build stream of 1000 frames
      final streamBuilder = <int>[];
      for (var i = 0; i < 1000; i++) {
        streamBuilder.addAll(singleFrame);
      }
      final input = Uint8List.fromList(streamBuilder);

      // Act
      framer.addBytes(input, (frame) => frames.add(frame));

      // Assert
      expect(
        frames.length,
        equals(1000),
        reason: 'All 1000 frames should be extracted',
      );

      // Verify each frame is correct
      for (var i = 0; i < frames.length; i++) {
        expect(
          frames[i].length,
          equals(9),
          reason: 'Frame $i should have 9 bytes',
        );
        expect(
          frames[i][0],
          equals(0x00),
          reason: 'Frame $i should have message ID 0x00',
        );
      }
    });
  });

  group('Gdl90Framer - Re-Entrancy Protection', () {
    // T014b: Re-entrant call detection
    test('throws StateError on re-entrant addBytes call', () {
      // Purpose: Validates re-entrancy guard prevents state corruption
      // Quality Contribution: Prevents subtle bugs from callback re-entrance

      // Arrange
      final framer = Gdl90Framer();
      bool reEntrancyDetected = false;

      void reEntrantCallback(Uint8List frame) {
        // Attempt to call addBytes again from within callback
        try {
          final moreData = Uint8List.fromList([0x7E, 0x00, 0x7E]);
          framer.addBytes(moreData, (f) {});
          // Should not reach here
        } on StateError catch (e) {
          reEntrancyDetected = true;
          expect(e.message, contains('Re-entrant addBytes() call detected'));
        }
      }

      // Valid frame
      final input = Uint8List.fromList([
        0x7E,
        0x00,
        0x81,
        0x41,
        0xDB,
        0xD0,
        0x08,
        0x02,
        0xB3,
        0x8B,
        0x7E,
      ]);

      // Act
      framer.addBytes(input, reEntrantCallback);

      // Assert
      expect(
        reEntrancyDetected,
        isTrue,
        reason: 'StateError should be thrown on re-entrant call',
      );
    });
  });
}
