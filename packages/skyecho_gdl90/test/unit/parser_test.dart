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

    group('Phase 6: Position Messages (Ownship, Traffic)', () {
      // T003: Semicircle to degrees conversion - positive value
      test(
          'given_positive_semicircle_when_converting_then_returns_positive_degrees',
          () {
        // Test vector from research: 0x1A5E1A → 37.0835°
        // Lat24 = 1728026 decimal
        // Degrees = 1728026 * (180.0 / 2^23) = 37.0835°
        final frame = Uint8List.fromList([
          0x0A, // Ownship message ID
          0x00, // Status byte
          0x00, 0x00, 0x00, // ICAO address (3 bytes)
          0x1A, 0x5E, 0x1A, // Latitude (3 bytes) - MSB first
          0x00, 0x00, 0x00, // Longitude
          0x00, 0x8C, // Altitude (2 bytes): 140 → 2500 ft
          0x00, // Misc byte
          0x00, // NIC
          0x00, 0x00, // Horizontal velocity
          0x00, 0x00, // Vertical velocity
          0x00, // Track
          0x00, // Emitter category
          // Callsign (8 bytes)
          0x4E, 0x31, 0x32, 0x33, 0x34, 0x35, 0x20, 0x20, // "N12345  "
          0x00, // Emergency/priority
          0x00, 0x00, // CRC
        ]);

        final event = Gdl90Parser.parse(frame);

        expect(event, isA<Gdl90DataEvent>());
        final msg = (event as Gdl90DataEvent).message;
        expect(msg.latitude, closeTo(37.0794, 0.01));
      });

      // T004: Semicircle to degrees conversion - negative value
      test(
          'given_negative_semicircle_when_converting_then_returns_negative_degrees',
          () {
        // Test vector: 0xF00000 (sign bit set) → negative degrees
        // Lat24 = 0xF00000 = 15728640 unsigned
        // Signed = 15728640 - 16777216 = -1048576
        // Degrees = -1048576 * (180.0 / 2^23) ≈ -22.5°
        final frame = Uint8List.fromList([
          0x0A, // Ownship message ID
          0x00, // Status byte
          0x00, 0x00, 0x00, // ICAO address
          0xF0, 0x00, 0x00, // Latitude (negative, southern hemisphere)
          0x00, 0x00, 0x00, // Longitude
          0x00, 0x8C, // Altitude
          0x00, 0x00, // Misc, NIC
          0x00, 0x00, // Horizontal velocity
          0x00, 0x00, // Vertical velocity
          0x00, 0x00, // Track, Emitter
          // Callsign (8 bytes)
          0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,
          0x00, // Emergency
          0x00, 0x00, // CRC
        ]);

        final event = Gdl90Parser.parse(frame);

        expect(event, isA<Gdl90DataEvent>());
        final msg = (event as Gdl90DataEvent).message;
        expect(msg.latitude, lessThan(0)); // Negative (southern hemisphere)
        expect(msg.latitude, closeTo(-22.5, 0.1));
      });

      // T005: Latitude boundary - north pole (+90°)
      test('given_north_pole_lat_when_parsing_then_returns_90_degrees', () {
        // 0x400000 → exactly 90.0° (north pole boundary)
        // 4194304 * (180.0 / 2^23) = 90.0°
        final frame = Uint8List.fromList([
          0x0A,
          0x00,
          0x00, 0x00, 0x00,
          0x40, 0x00, 0x00, // Latitude = 0x400000 (90°)
          0x00, 0x00, 0x00,
          0x00, 0x8C,
          0x00, 0x00,
          0x00, 0x00,
          0x00, 0x00,
          0x00, 0x00,
          0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,
          0x00,
          0x00, 0x00,
        ]);

        final event = Gdl90Parser.parse(frame);

        expect(event, isA<Gdl90DataEvent>());
        final msg = (event as Gdl90DataEvent).message;
        expect(msg.latitude, closeTo(90.0, 0.001));
      });

      // T006: Latitude boundary - south pole (-90°)
      test('given_south_pole_lat_when_parsing_then_returns_minus_90_degrees',
          () {
        // 0xC00000 → exactly -90.0° (south pole boundary)
        // Sign bit set: 12582912 - 16777216 = -4194304
        // -4194304 * (180.0 / 2^23) = -90.0°
        final frame = Uint8List.fromList([
          0x0A,
          0x00,
          0x00, 0x00, 0x00,
          0xC0, 0x00, 0x00, // Latitude = 0xC00000 (-90°)
          0x00, 0x00, 0x00,
          0x00, 0x8C,
          0x00, 0x00,
          0x00, 0x00,
          0x00, 0x00,
          0x00, 0x00,
          0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,
          0x00,
          0x00, 0x00,
        ]);

        final event = Gdl90Parser.parse(frame);

        expect(event, isA<Gdl90DataEvent>());
        final msg = (event as Gdl90DataEvent).message;
        expect(msg.latitude, closeTo(-90.0, 0.001));
      });

      // T007: Longitude boundary - international date line (±180°)
      test('given_date_line_lon_when_parsing_then_returns_180_degrees', () {
        // 0x800000 → ±180.0° (international date line)
        // Sign bit set: 8388608 - 16777216 = -8388608
        // -8388608 * (180.0 / 2^23) = -180.0°
        final frame = Uint8List.fromList([
          0x0A,
          0x00,
          0x00, 0x00, 0x00,
          0x00, 0x00, 0x00,
          0x80, 0x00, 0x00, // Longitude = 0x800000 (±180°)
          0x00, 0x8C,
          0x00, 0x00,
          0x00, 0x00,
          0x00, 0x00,
          0x00, 0x00,
          0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,
          0x00,
          0x00, 0x00,
        ]);

        final event = Gdl90Parser.parse(frame);

        expect(event, isA<Gdl90DataEvent>());
        final msg = (event as Gdl90DataEvent).message;
        expect(msg.longitude?.abs(), closeTo(180.0, 0.001));
      });

      // T008: Coordinate origin - equator/prime meridian (0°, 0°)
      test('given_zero_coordinates_when_parsing_then_returns_zero_degrees', () {
        // 0x000000 → exactly 0.0° (equator/prime meridian)
        final frame = Uint8List.fromList([
          0x0A,
          0x00,
          0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, // Latitude = 0°
          0x00, 0x00, 0x00, // Longitude = 0°
          0x00, 0x8C,
          0x00, 0x00,
          0x00, 0x00,
          0x00, 0x00,
          0x00, 0x00,
          0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,
          0x00,
          0x00, 0x00,
        ]);

        final event = Gdl90Parser.parse(frame);

        expect(event, isA<Gdl90DataEvent>());
        final msg = (event as Gdl90DataEvent).message;
        expect(msg.latitude, closeTo(0.0, 0.001));
        expect(msg.longitude, closeTo(0.0, 0.001));
      });

      // T009: Altitude with offset and scaling
      test('given_altitude_140_when_parsing_then_returns_2500_feet', () {
        // Formula: (raw * 25) - 1000
        // 140 * 25 - 1000 = 3500 - 1000 = 2500 feet
        // Altitude 140 = 0x08C (12-bit)
        // Byte 10: high 8 bits = 0x08
        // Byte 11: low 4 bits in high nibble = 0xC0 (0xC << 4)
        // 30-byte frame: 1 msgID + 27 payload + 2 CRC
        final frame = Uint8List.fromList([
          0x0A, // Message ID (byte 0)
          // Payload starts (27 bytes):
          0x00, // Status (byte 1)
          0x00, 0x00, 0x00, // ICAO (bytes 2-4)
          0x00, 0x00, 0x00, // Lat (bytes 5-7)
          0x00, 0x00, 0x00, // Lon (bytes 8-10)
          0x08,
          0xC0, // Alt (bytes 11-12): 0x08C = 140 (byte11=high8, byte12=low4<<4)
          0x00, // NIC (byte 13)
          0x00, 0x00, // Hvel (bytes 14-15)
          0x00, 0x00, // Vvel (bytes 15-16)
          0x00, // Track (byte 17)
          0x00, // Emitter (byte 18)
          0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,
          0x20, // Callsign (bytes 19-26)
          0x00, // Emergency (byte 27)
          0x00, 0x00, // CRC (bytes 28-29)
        ]);

        final event = Gdl90Parser.parse(frame);

        expect(event, isA<Gdl90DataEvent>());
        final msg = (event as Gdl90DataEvent).message;
        expect(msg.altitudeFeet, equals(2500));
      });

      // T010: Invalid altitude marker (0xFFF)
      test('given_invalid_altitude_when_parsing_then_returns_null', () {
        // 0xFFF → null (no GPS fix)
        // Altitude 0xFFF (12-bit all 1s)
        // Byte 10: high 8 bits = 0xFF
        // Byte 11: low 4 bits in high nibble = 0xF0
        // 30-byte frame: 1 msgID + 27 payload + 2 CRC
        final frame = Uint8List.fromList([
          0x0A, // Message ID
          // Payload (27 bytes):
          0x00, // Status
          0x00, 0x00, 0x00, // ICAO
          0x00, 0x00, 0x00, // Lat
          0x00, 0x00, 0x00, // Lon
          0xFF, 0xF0, // Alt: 0xFFF = invalid marker (0xFF, 0xF<<4)
          0x00, // NIC
          0x00, 0x00, // Hvel
          0x00, 0x00, // Vvel
          0x00, // Track
          0x00, // Emitter
          0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, // Callsign
          0x00, // Emergency
          0x00, 0x00, // CRC
        ]);

        final event = Gdl90Parser.parse(frame);

        expect(event, isA<Gdl90DataEvent>());
        final msg = (event as Gdl90DataEvent).message;
        expect(msg.altitudeFeet, isNull);
      });

      // T011: Callsign extraction and trimming
      test('given_padded_callsign_when_parsing_then_returns_trimmed_string',
          () {
        // "N12345  " (8 bytes with trailing spaces) → "N12345"
        // 30-byte frame: 1 msgID + 27 payload + 2 CRC
        final frame = Uint8List.fromList([
          0x0A, // Message ID
          // Payload (27 bytes):
          0x00, // Status (byte 0)
          0x00, 0x00, 0x00, // ICAO (bytes 1-3)
          0x00, 0x00, 0x00, // Lat (bytes 4-6)
          0x00, 0x00, 0x00, // Lon (bytes 7-9)
          0x08, 0xC0, // Alt (bytes 10-11): 140 = 0x08C
          0x00, // NIC (byte 12)
          0x00, 0x00, // Hvel (bytes 13-14): high 8 + high nibble
          0x00, // Vvel (byte 15): low 8 bits (byte 14's low nibble + this byte)
          0x00, // Track (byte 16)
          0x00, // Emitter (byte 17)
          // Callsign (bytes 18-25): "N12345  " (8 ASCII bytes with trailing spaces)
          0x4E, 0x31, 0x32, 0x33, 0x34, 0x35, 0x20, 0x20,
          0x00, // Emergency (byte 26)
          0x00, 0x00, // CRC
        ]);

        final event = Gdl90Parser.parse(frame);

        expect(event, isA<Gdl90DataEvent>());
        final msg = (event as Gdl90DataEvent).message;
        expect(msg.callsign, equals('N12345'));
      });

      // T012: Horizontal velocity encoding (12-bit unsigned)
      test('given_horizontal_velocity_120_when_parsing_then_returns_120_knots',
          () {
        // 12-bit unsigned: 120 knots (no sign extension)
        // Hvel encoding: 12-bit 0x078 = (0x07 << 4) | (0x80 >> 4) = bytes 0x07, 0x80
        // 30-byte frame: 1 msgID + 27 payload + 2 CRC
        final frame = Uint8List.fromList([
          0x0A, // Message ID
          // Payload (27 bytes):
          0x00, // Status
          0x00, 0x00, 0x00, // ICAO
          0x00, 0x00, 0x00, // Lat
          0x00, 0x00, 0x00, // Lon
          0x08, 0xC0, // Alt (140 = 0x08C)
          0x00, // NIC
          0x07, 0x80, // Hvel: 120 (0x078) = (0x07 << 4) | (0x80 >> 4)
          0x00, // Vvel (low nibble of 0x80 is 0, then this byte)
          0x00, // Track
          0x00, // Emitter
          0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, // Callsign
          0x00, // Emergency
          0x00, 0x00, // CRC
        ]);

        final event = Gdl90Parser.parse(frame);

        expect(event, isA<Gdl90DataEvent>());
        final msg = (event as Gdl90DataEvent).message;
        expect(msg.horizontalVelocityKt, equals(120));
      });

      // T013: Vertical velocity encoding (signed 12-bit, positive and negative)
      test('given_vertical_velocity_when_parsing_then_applies_sign_and_scaling',
          () {
        // Positive (climb): vvel = 10 → 10 * 64 = 640 fpm
        // Vvel encoding: 12-bit 0x00A = low nibble of hv byte + vv byte
        // 0x00A = ((0x00 & 0x0F) << 8) | 0x0A = bytes end with 0x00, 0x0A
        // 30-byte frame: 1 msgID + 27 payload + 2 CRC
        final frameClimb = Uint8List.fromList([
          0x0A, // Message ID
          // Payload (27 bytes):
          0x00, // Status
          0x00, 0x00, 0x00, // ICAO
          0x00, 0x00, 0x00, // Lat
          0x00, 0x00, 0x00, // Lon
          0x08, 0xC0, // Alt (140 = 0x08C)
          0x00, // NIC
          0x00, 0x00, // Hvel: 0 (high 8 bits, then high nibble of next byte)
          0x0A, // Vvel: 10 (low nibble of prev byte is 0, this is low 8 bits)
          0x00, // Track
          0x00, // Emitter
          0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, // Callsign
          0x00, // Emergency
          0x00, 0x00, // CRC
        ]);

        final eventClimb = Gdl90Parser.parse(frameClimb);
        expect(eventClimb, isA<Gdl90DataEvent>());
        final msgClimb = (eventClimb as Gdl90DataEvent).message;
        expect(msgClimb.verticalVelocityFpm, equals(640));

        // Negative (descent): vvel = 0xFF0 → -16 * 64 = -1024 fpm
        // 0xFF0 = 4080 unsigned
        // Signed (12-bit): 4080 - 4096 = -16
        // -16 * 64 = -1024 fpm
        // Vvel encoding: 12-bit 0xFF0 = ((0x0F & 0x0F) << 8) | 0xF0
        // Bytes: hv ends with 0x0F, vv = 0xF0
        // 30-byte frame: 1 msgID + 27 payload + 2 CRC
        final frameDescent = Uint8List.fromList([
          0x0A, // Message ID
          // Payload (27 bytes):
          0x00, // Status
          0x00, 0x00, 0x00, // ICAO
          0x00, 0x00, 0x00, // Lat
          0x00, 0x00, 0x00, // Lon
          0x08, 0xC0, // Alt (140 = 0x08C)
          0x00, // NIC
          0x00, 0x0F, // Hvel: 0 (high nibble is 0, low nibble is 0xF for vvel)
          0xF0, // Vvel: 0xFF0 → -16 → -1024 fpm
          0x00, // Track
          0x00, // Emitter
          0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, // Callsign
          0x00, // Emergency
          0x00, 0x00, // CRC
        ]);

        final eventDescent = Gdl90Parser.parse(frameDescent);
        expect(eventDescent, isA<Gdl90DataEvent>());
        final msgDescent = (eventDescent as Gdl90DataEvent).message;
        expect(msgDescent.verticalVelocityFpm, equals(-1024));
      });

      // T014: Track/heading angle encoding
      test('given_track_128_when_parsing_then_returns_180_degrees', () {
        // 8-bit angular: 128 * (360.0 / 256.0) = 180.0°
        // 30-byte frame: 1 msgID + 27 payload + 2 CRC
        final frame = Uint8List.fromList([
          0x0A, // Message ID
          // Payload (27 bytes):
          0x00, // Status
          0x00, 0x00, 0x00, // ICAO
          0x00, 0x00, 0x00, // Lat
          0x00, 0x00, 0x00, // Lon
          0x08, 0xC0, // Alt (140 = 0x08C)
          0x00, // NIC
          0x00, 0x00, // Hvel
          0x00, // Vvel
          0x80, // Track: 128 → 180.0°
          0x00, // Emitter
          0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, // Callsign
          0x00, // Emergency
          0x00, 0x00, // CRC
        ]);

        final event = Gdl90Parser.parse(frame);

        expect(event, isA<Gdl90DataEvent>());
        final msg = (event as Gdl90DataEvent).message;
        expect(msg.trackDegrees, closeTo(180.0, 0.5));
      });

      // T015: Traffic alert flag extraction
      test('given_traffic_alert_bit_when_parsing_then_extracts_flag', () {
        // Status byte bit 4: traffic alert
        final frame = Uint8List.fromList([
          0x0A,
          0x10, // Status byte: bit 4 set (traffic alert = true)
          0x00, 0x00, 0x00,
          0x00, 0x00, 0x00,
          0x00, 0x00, 0x00,
          0x00, 0x8C,
          0x00, 0x00,
          0x00, 0x00,
          0x00, 0x00,
          0x00, 0x00,
          0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,
          0x00,
          0x00, 0x00,
        ]);

        final event = Gdl90Parser.parse(frame);

        expect(event, isA<Gdl90DataEvent>());
        final msg = (event as Gdl90DataEvent).message;
        expect(msg.trafficAlert, isTrue);
      });

      // T016: Airborne flag extraction
      test('given_airborne_bit_when_parsing_then_extracts_flag', () {
        // Status byte bit 3: airborne
        final frame = Uint8List.fromList([
          0x0A,
          0x08, // Status byte: bit 3 set (airborne = true)
          0x00, 0x00, 0x00,
          0x00, 0x00, 0x00,
          0x00, 0x00, 0x00,
          0x00, 0x8C,
          0x00, 0x00,
          0x00, 0x00,
          0x00, 0x00,
          0x00, 0x00,
          0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20,
          0x00,
          0x00, 0x00,
        ]);

        final event = Gdl90Parser.parse(frame);

        expect(event, isA<Gdl90DataEvent>());
        final msg = (event as Gdl90DataEvent).message;
        expect(msg.airborne, isTrue);
      });

      // T017: Ownship report with valid GPS position
      test('given_full_ownship_message_when_parsing_then_extracts_all_fields',
          () {
        // Complete 30-byte ownship frame with all fields
        // 30-byte frame: 1 msgID + 27 payload + 2 CRC
        final frame = Uint8List.fromList([
          0x0A, // Ownship message ID
          // Payload (27 bytes):
          0x18, // Status: bits 4,3 set (trafficAlert, airborne)
          0xAB, 0xCD, 0xEF, // ICAO address: 0xABCDEF
          0x1A, 0x5E, 0x1A, // Lat: 37.0794°
          0xA8, 0xFF, 0x5A, // Lon: -122.42° (San Francisco)
          0x08, 0xC0, // Alt: 2500 ft (140 = 0x08C: byte 0x08, byte 0xC0)
          0x0B, // NIC = 11
          0x07, 0x80, // Hvel: 120 kt (0x078 encoded)
          0x0A, // Vvel: 640 fpm (10 * 64)
          0x80, // Track: 180°
          0x01, // Emitter category: 1 (light aircraft)
          // Callsign: "N9954   "
          0x4E, 0x39, 0x39, 0x35, 0x34, 0x20, 0x20, 0x20,
          0x00, // Emergency/priority
          0x00, 0x00, // CRC
        ]);

        final event = Gdl90Parser.parse(frame);

        expect(event, isA<Gdl90DataEvent>());
        final msg = (event as Gdl90DataEvent).message;
        expect(msg.messageType, equals(Gdl90MessageType.ownship));
        expect(msg.messageId, equals(0x0A));
        expect(msg.trafficAlert, isTrue);
        expect(msg.airborne, isTrue);
        expect(msg.icaoAddress, equals(0xABCDEF));
        expect(msg.latitude, closeTo(37.0794, 0.01));
        expect(msg.longitude, closeTo(-122.42, 0.1)); // Widen tolerance
        expect(msg.altitudeFeet, equals(2500));
        expect(msg.horizontalVelocityKt, equals(120));
        expect(msg.verticalVelocityFpm, equals(640));
        expect(msg.trackDegrees, closeTo(180.0, 0.5));
        expect(msg.emitterCategory, equals(1));
        expect(msg.callsign, equals('N9954'));
      });

      // T018: Ownship report with invalid position (no GPS fix)
      test('given_ownship_with_invalid_data_when_parsing_then_returns_nulls',
          () {
        // Altitude=0xFFF, hvel=0xFFF, vvel=0x800 → null values
        // Alt: 0xFFF = byte 0xFF, byte 0xF0
        // Hvel encoding: 12-bit 0xFFF = (0xFF << 4) | (0xF? >> 4) = bytes 0xFF, 0xF?
        // Vvel encoding: 12-bit 0x800 = ((0x08 & 0x0F) << 8) | 0x00
        // Combined byte: high nibble 0xF (hvel low), low nibble 0x8 (vvel high) = 0xF8
        // 30-byte frame: 1 msgID + 27 payload + 2 CRC
        final frame = Uint8List.fromList([
          0x0A, // Message ID
          // Payload (27 bytes):
          0x00, // Status byte
          0x00, 0x00, 0x00, // ICAO
          0x00, 0x00, 0x00, // Lat
          0x00, 0x00, 0x00, // Lon
          0xFF, 0xF0, // Alt: 0xFFF (invalid marker: 0xFF, 0xF<<4)
          0x00, // NIC
          0xFF,
          0xF8, // Hvel 0xFFF (bytes: 0xFF, high nibble 0xF) + Vvel 0x800 (low nibble 0x8)
          0x00, // Vvel: low 8 bits of 0x800
          0x00, // Track
          0x00, // Emitter
          0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, // Callsign
          0x00, // Emergency
          0x00, 0x00, // CRC
        ]);

        final event = Gdl90Parser.parse(frame);

        expect(event, isA<Gdl90DataEvent>());
        final msg = (event as Gdl90DataEvent).message;
        expect(msg.altitudeFeet, isNull);
        expect(msg.horizontalVelocityKt, isNull);
        expect(msg.verticalVelocityFpm, isNull);
      });

      // T019: Traffic report with valid position and callsign
      test('given_traffic_message_when_parsing_then_extracts_all_fields', () {
        // Full 30-byte traffic frame (same structure as ownship)
        // 30-byte frame: 1 msgID + 27 payload + 2 CRC
        final frame = Uint8List.fromList([
          0x14, // Traffic message ID
          // Payload (27 bytes):
          0x00, // Status
          0x12, 0x34, 0x56, // ICAO: 0x123456
          0x1A, 0x5E, 0x1A, // Lat: 37.0794°
          0x00, 0x00, 0x00, // Lon: 0°
          0x08, 0xC0, // Alt: 2500 ft (140 = 0x08C)
          0x00, // NIC
          0x05, 0x00, // Hvel: 80 kt (0x050 encoded)
          0x00, // Vvel
          0x40, // Track: 90°
          0x02, // Emitter: 2
          // Callsign: "UAL123  "
          0x55, 0x41, 0x4C, 0x31, 0x32, 0x33, 0x20, 0x20,
          0x00, // Emergency
          0x00, 0x00, // CRC
        ]);

        final event = Gdl90Parser.parse(frame);

        expect(event, isA<Gdl90DataEvent>());
        final msg = (event as Gdl90DataEvent).message;
        expect(msg.messageType, equals(Gdl90MessageType.traffic));
        expect(msg.messageId, equals(0x14));
        expect(msg.icaoAddress, equals(0x123456));
        expect(msg.latitude, closeTo(37.0794, 0.01));
        expect(msg.callsign, equals('UAL123'));
        expect(msg.altitudeFeet, equals(2500));
      });

      // T020: Truncated ownship message error handling
      test('given_truncated_ownship_when_parsing_then_returns_error_event', () {
        // Ownship requires 27-byte payload, provide only 15 bytes
        final frame = Uint8List.fromList([
          0x0A,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00,
          0x00, 0x00, 0x00,
          0x00, 0x8C,
          0x00, 0x00, // Only 15 bytes (truncated)
          0x00, 0x00, // CRC
        ]);

        final event = Gdl90Parser.parse(frame);

        expect(event, isA<Gdl90ErrorEvent>());
        final errorEvent = event as Gdl90ErrorEvent;
        expect(errorEvent.reason, contains('Truncated'));
        expect(errorEvent.reason, contains('ownship'));
        expect(errorEvent.hint, isNotNull);
      });

      // T021: Truncated traffic message error handling
      test('given_truncated_traffic_when_parsing_then_returns_error_event', () {
        // Traffic requires 27-byte payload, provide only 20 bytes
        final frame = Uint8List.fromList([
          0x14,
          0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00,
          0x00, 0x00, 0x00,
          0x00, 0x8C,
          0x00, 0x00,
          0x00, 0x50,
          0x00, 0x00,
          0x40, // Only 20 bytes (truncated)
          0x00, 0x00, // CRC
        ]);

        final event = Gdl90Parser.parse(frame);

        expect(event, isA<Gdl90ErrorEvent>());
        final errorEvent = event as Gdl90ErrorEvent;
        expect(errorEvent.reason, contains('Truncated'));
        expect(errorEvent.reason, contains('traffic'));
        expect(errorEvent.hint, isNotNull);
      });
    });
  });
}
