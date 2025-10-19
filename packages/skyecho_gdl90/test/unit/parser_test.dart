import 'dart:typed_data';

import 'package:skyecho_gdl90/src/models/gdl90_event.dart';
import 'package:skyecho_gdl90/src/models/gdl90_message.dart';
import 'package:skyecho_gdl90/src/parser.dart';
import 'package:test/test.dart';

void main() {
  group('Gdl90Parser', () {
    // T008: Message ID 0x00 routes to heartbeat parser stub
    test('routes ID 0x00 to heartbeat parser, returns DataEvent', () {
      // FAA heartbeat test vector from Phase 2/3
      // Frame structure: [messageId (1 byte), payload (7 bytes), crc (2 bytes)]
      final heartbeatFrame = Uint8List.fromList([
        0x00, 0x81, 0x41, 0xDB, 0xD0, 0x08, 0x02, // Message (7 bytes)
        0xB3, 0x8B, // CRC (2 bytes) - already validated by framer
      ]);

      final event = Gdl90Parser.parse(heartbeatFrame);

      expect(event, isA<Gdl90DataEvent>());
      final dataEvent = event as Gdl90DataEvent;
      expect(dataEvent.message.messageType, equals(Gdl90MessageType.heartbeat));
      expect(dataEvent.message.messageId, equals(0x00));

      // All fields null in stub (actual parsing in Phase 5)
      expect(dataEvent.message.gpsPosValid, isNull);
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
  });
}
