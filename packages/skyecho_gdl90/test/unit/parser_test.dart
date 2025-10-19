import 'dart:typed_data';

import 'package:skyecho_gdl90/src/models/gdl90_event.dart';
import 'package:skyecho_gdl90/src/models/gdl90_message.dart';
import 'package:skyecho_gdl90/src/parser.dart';
import 'package:test/test.dart';

void main() {
  group('Gdl90Parser', () {
    // T008: Message ID 0x00 routes to heartbeat parser
    test('routes ID 0x00 to heartbeat parser, returns DataEvent', () {
      // FAA heartbeat test vector from Phase 2/3
      // Frame structure: [messageId (1 byte), payload (6 bytes), crc (2 bytes)]
      final heartbeatFrame = Uint8List.fromList([
        0x00, 0x81, 0x41, 0xDB, 0xD0, 0x08, 0x02, // Message (7 bytes)
        0xB3, 0x8B, // CRC (2 bytes) - already validated by framer
      ]);

      final event = Gdl90Parser.parse(heartbeatFrame);

      expect(event, isA<Gdl90DataEvent>());
      final dataEvent = event as Gdl90DataEvent;
      expect(dataEvent.message.messageType, equals(Gdl90MessageType.heartbeat));
      expect(dataEvent.message.messageId, equals(0x00));

      // Phase 5: Fields now populated
      expect(dataEvent.message.gpsPosValid, isNotNull);
    });

    // T009: Unknown message ID handling
    test('returns ErrorEvent for unknown message ID 0xFF', () {
      final unknownFrame = Uint8List.fromList([
        0xFF, 0x00, 0x00, // Unknown ID, minimal payload
        0x00, 0x00, // Fake CRC
      ]);

      final event = Gdl90Parser.parse(unknownFrame);

      expect(event, isA<Gdl90ErrorEvent>());
      final errorEvent = event as Gdl90ErrorEvent;
      expect(errorEvent.reason, contains('Unknown message ID: 0xFF'));
      expect(errorEvent.rawBytes, equals(unknownFrame));
    });

    // T010: Truncated message handling
    test('returns ErrorEvent for truncated heartbeat message', () {
      // Heartbeat requires 7-byte payload, provide only 2 bytes
      final truncatedFrame = Uint8List.fromList([
        0x00, 0x81, // ID + partial payload
        0x00, 0x00, // CRC
      ]);

      final event = Gdl90Parser.parse(truncatedFrame);

      expect(event, isA<Gdl90ErrorEvent>());
      final errorEvent = event as Gdl90ErrorEvent;
      expect(errorEvent.reason, contains('Truncated'));
      expect(errorEvent.hint, isNotNull);
    });

    // T011: CRC bytes stripped before message parsing
    test('strips trailing CRC bytes before parsing', () {
      final heartbeatWithCrc = Uint8List.fromList([
        0x00, 0x81, 0x41, 0xDB, 0xD0, 0x08, 0x02, // Message (7 bytes)
        0xB3, 0x8B, // CRC (2 bytes) - MUST BE STRIPPED
      ]);

      final event = Gdl90Parser.parse(heartbeatWithCrc);

      // Parser should extract payload as frame.sublist(1, frame.length - 2)
      // Payload: [0x81, 0x41, 0xDB, 0xD0, 0x08, 0x02] (6 bytes, CRC removed)
      // If CRC not stripped, parsing would fail
      expect(event, isA<Gdl90DataEvent>());
    });

    // T011b: Ignored message IDs return IgnoredEvent
    test('returns IgnoredEvent for ignored message ID', () {
      final unknownFrame = Uint8List.fromList([
        0xFF,
        0x00,
        0x00,
        0x00,
        0x00,
      ]);

      // With ignore list
      final ignoredEvent = Gdl90Parser.parse(
        unknownFrame,
        ignoreMessageIds: {0xFF},
      );

      expect(ignoredEvent, isA<Gdl90IgnoredEvent>());
      final ignored = ignoredEvent as Gdl90IgnoredEvent;
      expect(ignored.messageId, equals(0xFF));

      // Without ignore list - should return ErrorEvent
      final errorEvent = Gdl90Parser.parse(unknownFrame);
      expect(errorEvent, isA<Gdl90ErrorEvent>());
    });

    // Multiple frames processed without exceptions
    test('processes multiple frames without exceptions', () {
      final heartbeatFrame = Uint8List.fromList([
        0x00,
        0x81,
        0x41,
        0xDB,
        0xD0,
        0x08,
        0x02,
        0xB3,
        0x8B,
      ]);
      final unknownIdFrame = Uint8List.fromList([
        0xFF,
        0x00,
        0x00,
        0x00,
        0x00,
      ]);
      final truncatedFrame = Uint8List.fromList([
        0x00,
        0x81,
        0x00,
        0x00,
      ]);

      final frames = [
        heartbeatFrame, // Valid heartbeat
        unknownIdFrame, // Unknown ID
        truncatedFrame, // Truncated
        heartbeatFrame, // Another valid
      ];

      final events = frames.map((f) => Gdl90Parser.parse(f)).toList();

      expect(events.length, equals(4));
      expect(events[0], isA<Gdl90DataEvent>());
      expect(events[1], isA<Gdl90ErrorEvent>());
      expect(events[2], isA<Gdl90ErrorEvent>());
      expect(events[3], isA<Gdl90DataEvent>());

      // No exceptions thrown; all frames processed
    });

    // ========================================================================
    // Phase 5: Core Message Types (Heartbeat, Initialization)
    // RED Phase Tests - These tests should FAIL until GREEN phase implementation
    // ========================================================================

    group('Phase 5: Heartbeat field extraction', () {
      // T002: GPS position valid flag extraction
      test(
          'given_heartbeat_status1_bit7_when_parsing_then_extracts_gpsPosValid',
          () {
        // Heartbeat with status1 = 0x81 (bits 7 and 0 set)
        // bit 7 = gpsPosValid = true
        // bit 0 = uatInitialized = true
        final frame = Uint8List.fromList([
          0x00, // Message ID
          0x81, // Status byte 1: bits 7,0 set (0b10000001)
          0x01, // Status byte 2: bit 0 set (utcOk)
          0x00, 0x00, // Timestamp bytes
          0x00, 0x00, // Message count bytes
          0x00, 0x00, // CRC (will be stripped)
        ]);

        final event = Gdl90Parser.parse(frame);

        expect(event, isA<Gdl90DataEvent>());
        final msg = (event as Gdl90DataEvent).message;
        expect(msg.gpsPosValid, equals(true));
        expect(msg.uatInitialized, equals(true));
      });

      // T003: UTC validity flag extraction
      test('given_heartbeat_status2_bit0_when_parsing_then_extracts_utcOk', () {
        // Heartbeat with status2 bit 0 set
        final frame = Uint8List.fromList([
          0x00, // Message ID
          0x00, // Status byte 1: all clear
          0x01, // Status byte 2: bit 0 set (utcOk = true)
          0x00, 0x00, // Timestamp bytes
          0x00, 0x00, // Message count bytes
          0x00, 0x00, // CRC
        ]);

        final event = Gdl90Parser.parse(frame);

        expect(event, isA<Gdl90DataEvent>());
        final msg = (event as Gdl90DataEvent).message;
        expect(msg.utcOk, equals(true));
      });

      // T004: 17-bit timestamp extraction
      test('given_heartbeat_timestamp_when_parsing_then_extracts_timeOfDay',
          () {
        // 17-bit timestamp = 43200 seconds (12:00:00 UTC) = 0x0A8C0
        // status2 bit 7 = 0, tsLSB = 0xC0, tsMSB = 0xA8
        final frame = Uint8List.fromList([
          0x00, // Message ID
          0x00, // Status byte 1
          0x00, // Status byte 2: bit 7 = 0 (timestamp high bit)
          0xC0, // Timestamp LSB
          0xA8, // Timestamp MSB
          0x00, 0x00, // Message count bytes
          0x00, 0x00, // CRC
        ]);

        final event = Gdl90Parser.parse(frame);

        expect(event, isA<Gdl90DataEvent>());
        final msg = (event as Gdl90DataEvent).message;
        expect(msg.timeOfDaySeconds, equals(43200));
      });

      // T005: Message count extraction
      test('given_heartbeat_counts_when_parsing_then_extracts_uplinkAndBasic',
          () {
        // uplinkCount = 8 (5-bit field, bits 7-3 of byte 5)
        // basicLongCount = 512 (10-bit field, bits 1-0 of byte 5 + byte 6)
        // counts1 = 0b01000010 = 0x42 (bits 7-3 = 01000 = 8, bits 1-0 = 10)
        // counts2 = 0x00 (completes 10-bit value: 0b1000000000 = 512)
        final frame = Uint8List.fromList([
          0x00, // Message ID
          0x00, // Status byte 1
          0x00, // Status byte 2
          0x00, 0x00, // Timestamp bytes
          0x42, // Message counts 1: uplink=8 (bits 7-3), basic high bits=2 (bits 1-0)
          0x00, // Message counts 2: basic low byte=0 (full value = 2<<8 + 0 = 512)
          0x00, 0x00, // CRC
        ]);

        final event = Gdl90Parser.parse(frame);

        expect(event, isA<Gdl90DataEvent>());
        final msg = (event as Gdl90DataEvent).message;
        expect(msg.messageCountUplink, equals(8));
        expect(msg.messageCountBasicAndLong, equals(512));
      });

      // T006: All heartbeat status flags (10 boolean flags)
      test(
          'given_heartbeat_all_status_flags_when_parsing_then_extracts_all_10_flags',
          () {
        // Status1 = 0xED = 0b11101101 (bits 7,6,5,3,2,0 set; bit 4,1 clear)
        // Status2 = 0x61 = 0b01100001 (bits 6,5,0 set; bit 7 clear)
        final frame = Uint8List.fromList([
          0x00, // Message ID
          0xED, // Status byte 1: bits 7,6,5,3,2,0 set
          0x61, // Status byte 2: bits 6,5,0 set
          0x00, 0x00, // Timestamp
          0x00, 0x00, // Counts
          0x00, 0x00, // CRC
        ]);

        final event = Gdl90Parser.parse(frame);

        expect(event, isA<Gdl90DataEvent>());
        final msg = (event as Gdl90DataEvent).message;

        // Status byte 1 flags
        expect(msg.gpsPosValid, equals(true)); // bit 7
        expect(msg.maintRequired, equals(true)); // bit 6
        expect(msg.identActive, equals(true)); // bit 5
        expect(msg.ownshipAnonAddr, equals(false)); // bit 4
        expect(msg.batteryLow, equals(true)); // bit 3
        expect(msg.ratcs, equals(true)); // bit 2
        expect(msg.uatInitialized, equals(true)); // bit 0

        // Status byte 2 flags
        expect(msg.csaRequested, equals(true)); // bit 6
        expect(msg.csaNotAvailable, equals(true)); // bit 5
        expect(msg.utcOk, equals(true)); // bit 0
      });

      // T007: Timestamp boundary values
      test(
          'given_heartbeat_boundary_timestamps_when_parsing_then_handles_0_and_max',
          () {
        // Test timestamp = 0
        final frameZero = Uint8List.fromList([
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
        ]);
        final eventZero = Gdl90Parser.parse(frameZero);
        expect(eventZero, isA<Gdl90DataEvent>());
        expect(
            (eventZero as Gdl90DataEvent).message.timeOfDaySeconds, equals(0));

        // Test timestamp = 131071 (0x1FFFF, max 17-bit value)
        // status2 bit 7 = 1, tsLSB = 0xFF, tsMSB = 0xFF
        final frameMax = Uint8List.fromList([
          0x00, // Message ID
          0x00, // Status byte 1
          0x80, // Status byte 2: bit 7 = 1 (timestamp high bit)
          0xFF, // Timestamp LSB
          0xFF, // Timestamp MSB
          0x00, 0x00, // Counts
          0x00, 0x00, // CRC
        ]);
        final eventMax = Gdl90Parser.parse(frameMax);
        expect(eventMax, isA<Gdl90DataEvent>());
        expect((eventMax as Gdl90DataEvent).message.timeOfDaySeconds,
            equals(131071));
      });
    });

    group('Phase 5: Initialization message parsing', () {
      // T008: Initialization message raw byte storage
      test('given_initialization_message_when_parsing_then_stores_audio_fields',
          () {
        // Initialization message ID 0x02, 18-byte payload
        final frame = Uint8List.fromList([
          0x02, // Message ID
          0x01, // audioInhibit
          0x00, // audioTest
          // Remaining 16 bytes (reserved, not extracted in Phase 5)
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, // CRC
        ]);

        final event = Gdl90Parser.parse(frame);

        expect(event, isA<Gdl90DataEvent>());
        final msg = (event as Gdl90DataEvent).message;
        expect(msg.messageType, equals(Gdl90MessageType.initialization));
        expect(msg.audioInhibit, equals(1));
        expect(msg.audioTest, equals(0));
      });
    });
  });
}
