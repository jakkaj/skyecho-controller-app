import 'package:skyecho_gdl90/src/models/gdl90_message.dart';
import 'package:test/test.dart';

void main() {
  group('Gdl90Message', () {
    // T002: Heartbeat message creation with selective field population
    test(
        'creates heartbeat message with heartbeat fields populated, traffic fields null',
        () {
      final msg = Gdl90Message(
        messageType: Gdl90MessageType.heartbeat,
        messageId: 0x00,
        gpsPosValid: true,
        utcOk: true,
        timeOfDaySeconds: 43200,
      );

      expect(msg.messageType, equals(Gdl90MessageType.heartbeat));
      expect(msg.messageId, equals(0x00));
      expect(msg.gpsPosValid, isTrue);
      expect(msg.utcOk, isTrue);
      expect(msg.timeOfDaySeconds, equals(43200));

      // Traffic/ownship fields should be null
      expect(msg.latitude, isNull);
      expect(msg.longitude, isNull);
      expect(msg.callsign, isNull);
    });

    // T003: Traffic message creation with selective field population
    test(
        'creates traffic message with traffic fields populated, heartbeat fields null',
        () {
      final msg = Gdl90Message(
        messageType: Gdl90MessageType.traffic,
        messageId: 0x14,
        latitude: 37.5,
        longitude: -122.3,
        altitudeFeet: 2500,
        callsign: 'N12345',
      );

      expect(msg.messageType, equals(Gdl90MessageType.traffic));
      expect(msg.messageId, equals(0x14));
      expect(msg.latitude, equals(37.5));
      expect(msg.longitude, equals(-122.3));
      expect(msg.altitudeFeet, equals(2500));
      expect(msg.callsign, equals('N12345'));

      // Heartbeat fields should be null
      expect(msg.gpsPosValid, isNull);
      expect(msg.utcOk, isNull);
      expect(msg.timeOfDaySeconds, isNull);
    });

    // T004: Ownship message creation with selective field population
    test('creates ownship message with ownship fields populated', () {
      final msg = Gdl90Message(
        messageType: Gdl90MessageType.ownship,
        messageId: 0x0A,
        latitude: 37.5,
        longitude: -122.3,
        altitudeFeet: 2500,
      );

      expect(msg.messageType, equals(Gdl90MessageType.ownship));
      expect(msg.messageId, equals(0x0A));
      expect(msg.latitude, equals(37.5));
      expect(msg.longitude, equals(-122.3));
      expect(msg.altitudeFeet, equals(2500));
    });
  });
}
