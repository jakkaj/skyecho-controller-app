import 'dart:typed_data';

import 'package:skyecho_gdl90/src/models/gdl90_event.dart';
import 'package:skyecho_gdl90/src/models/gdl90_message.dart';
import 'package:test/test.dart';

void main() {
  group('Gdl90Event', () {
    // T006: Gdl90DataEvent wrapper containing message
    test('creates DataEvent with message, extracts via pattern matching', () {
      final msg = Gdl90Message(
        messageType: Gdl90MessageType.heartbeat,
        messageId: 0x00,
      );
      final event = Gdl90DataEvent(msg);

      // Pattern matching extraction
      switch (event) {
        case Gdl90DataEvent(:final message):
          expect(message.messageType, equals(Gdl90MessageType.heartbeat));
          expect(message.messageId, equals(0x00));
      }
    });

    // T007: Gdl90ErrorEvent wrapper with diagnostic info
    test(
        'creates ErrorEvent with reason, hint, rawBytes; validates all fields accessible',
        () {
      final rawBytes = Uint8List.fromList([0xFF, 0x00, 0x00]);
      final event = Gdl90ErrorEvent(
        reason: 'Unknown message ID: 0xFF',
        hint: 'Only IDs 0x00-0x1F are supported in this phase',
        rawBytes: rawBytes,
      );

      expect(event.reason, contains('Unknown message ID'));
      expect(event.hint, contains('supported'));
      expect(event.rawBytes, equals(rawBytes));
    });

    // T011b (part 1): Gdl90IgnoredEvent wrapper with messageId
    test('creates IgnoredEvent with messageId', () {
      final event = Gdl90IgnoredEvent(messageId: 0xFF);

      expect(event.messageId, equals(0xFF));

      // Pattern matching
      switch (event) {
        case Gdl90IgnoredEvent(:final messageId):
          expect(messageId, equals(0xFF));
      }
    });
  });
}
