import 'dart:typed_data';

import 'models/gdl90_event.dart';
import 'models/gdl90_message.dart';

/// GDL90 message parser with message ID routing.
///
/// Per Critical Discovery 05: Parser never throws exceptions. All errors are
/// wrapped in [Gdl90ErrorEvent] to prevent stream breakage.
///
/// Per Insight #1: Optional [ignoreMessageIds] parameter allows suppressing
/// ErrorEvents for unknown message IDs (e.g., during firmware updates).
///
/// Per Insight #3: Returns non-nullable [Gdl90Event] with three sealed
/// subtypes ([Gdl90DataEvent], [Gdl90ErrorEvent], [Gdl90IgnoredEvent]) for
/// type-safe exhaustive pattern matching.
///
/// **⚠️ Re-Entrancy Warning** (Insight #4): This parser is typically invoked
/// from within [Gdl90Framer]'s `onFrame` callback. The framer guards against
/// re-entrant calls to `addBytes()`. Do not trigger additional framing
/// operations from within message processing code, as this will throw
/// [StateError].
///
/// **Safe Pattern**:
/// ```dart
/// framer.addBytes(chunk, (frame) {
///   final event = Gdl90Parser.parse(frame);
///   handleEvent(event); // handleEvent must NOT call framer.addBytes()
/// });
/// ```
class Gdl90Parser {
  /// Parse a GDL90 frame and route to type-specific parser.
  ///
  /// Frame structure from Phase 3 framer:
  /// - `frame[0]`: Message ID byte
  /// - `frame[1..n-2]`: Message payload
  /// - `frame[n-1..n]`: CRC bytes (already validated by framer)
  ///
  /// The parser strips the trailing 2-byte CRC before field extraction.
  ///
  /// Parameters:
  /// - [frame]: De-framed, de-escaped, CRC-validated frame from [Gdl90Framer]
  /// - [ignoreMessageIds]: Optional set of message IDs to ignore (returns
  ///   [Gdl90IgnoredEvent] instead of [Gdl90ErrorEvent] for unknown IDs)
  ///
  /// Returns:
  /// - [Gdl90DataEvent]: Successful parse containing [Gdl90Message]
  /// - [Gdl90ErrorEvent]: Parse failure with diagnostic info
  /// - [Gdl90IgnoredEvent]: Message ID in ignore list
  static Gdl90Event parse(Uint8List frame, {Set<int>? ignoreMessageIds}) {
    // Extract message ID
    final messageId = frame[0];

    // Check ignore list (Insight #1)
    if (ignoreMessageIds?.contains(messageId) ?? false) {
      return Gdl90IgnoredEvent(messageId: messageId);
    }

    // Strip trailing CRC (2 bytes) before field extraction
    final payload = frame.sublist(1, frame.length - 2);

    // Routing table
    switch (messageId) {
      case 0x00:
        return _parseHeartbeat(messageId, payload);

      case 0x02: // Initialization
        return _parseInitialization(messageId, payload);

      case 0x07: // Uplink
      case 0x09: // HAT
      case 0x0A: // Ownship
      case 0x0B: // Ownship Geo Altitude
      case 0x14: // Traffic
      case 0x1E: // Basic Report
      case 0x1F: // Long Report
        return Gdl90ErrorEvent(
          reason: 'Unsupported message type: 0x${messageId.toRadixString(16)}',
          hint: 'This message type will be implemented in Phase 6-7',
          rawBytes: frame,
        );

      default:
        return Gdl90ErrorEvent(
          reason:
              'Unknown message ID: 0x${messageId.toRadixString(16).toUpperCase()}',
          hint:
              'Expected IDs: 0x00, 0x02, 0x07, 0x09, 0x0A, 0x0B, 0x14, 0x1E, 0x1F',
          rawBytes: frame,
        );
    }
  }

  /// Parse heartbeat message (ID 0x00).
  ///
  /// Per Insight #5: Defensive assertion validates messageId matches expected
  /// value to catch routing table bugs in debug mode (zero cost in release).
  ///
  /// Extracts GPS status, UTC validity, 17-bit timestamp, message counts, and
  /// all 10 boolean status flags from status bytes 1 and 2.
  ///
  /// Payload structure (6 bytes after CRC strip):
  /// - Byte 0: Status byte 1 (8 boolean flags)
  /// - Byte 1: Status byte 2 (3 flags + timestamp high bit)
  /// - Bytes 2-3: Timestamp (16-bit LSB of 17-bit value)
  /// - Byte 4: Message counts 1 (5-bit uplink + 2-bit basic/long high)
  /// - Byte 5: Message counts 2 (8-bit basic/long low)
  static Gdl90Event _parseHeartbeat(int messageId, Uint8List payload) {
    // Defensive assertion (Insight #5)
    assert(
      messageId == 0x00,
      'Heartbeat parser received ID: 0x${messageId.toRadixString(16).toUpperCase()}',
    );

    // Length check: heartbeat requires 6-byte payload (after CRC stripped)
    if (payload.length < 6) {
      return Gdl90ErrorEvent(
        reason:
            'Truncated heartbeat message: expected 6 bytes, got ${payload.length}',
        hint:
            'Heartbeat payload format: [status1, status2, timestamp_msb, timestamp_lsb, msg_count_uplink, msg_count_basic_long]',
      );
    }

    // Extract status bytes
    final status1 = payload[0];
    final status2 = payload[1];

    // Status byte 1 flags (bits 7,6,5,4,3,2,0; bit 1 reserved)
    final gpsPosValid = (status1 & 0x80) != 0; // bit 7
    final maintRequired = (status1 & 0x40) != 0; // bit 6
    final identActive = (status1 & 0x20) != 0; // bit 5
    final ownshipAnonAddr = (status1 & 0x10) != 0; // bit 4
    final batteryLow = (status1 & 0x08) != 0; // bit 3
    final ratcs = (status1 & 0x04) != 0; // bit 2
    final uatInitialized = (status1 & 0x01) != 0; // bit 0

    // Status byte 2 flags (bits 6,5,0; bits 4-1 reserved, bit 7 used for timestamp)
    final csaRequested = (status2 & 0x40) != 0; // bit 6
    final csaNotAvailable = (status2 & 0x20) != 0; // bit 5
    final utcOk = (status2 & 0x01) != 0; // bit 0

    // Extract 17-bit timestamp (status2 bit 7 + 16-bit value from bytes 2-3)
    final timeHighBit =
        (status2 & 0x80) >> 7; // Extract bit 7, shift to position 0
    final timeLow16 = (payload[3] << 8) | payload[2]; // MSB then LSB
    final timeOfDaySeconds = (timeHighBit << 16) | timeLow16;

    // Extract message counts
    // Uplink: 5-bit field (bits 7-3 of byte 4)
    final messageCountUplink = (payload[4] & 0xF8) >> 3;

    // Basic/Long: 10-bit field (bits 1-0 of byte 4 + full byte 5)
    final basicLongHigh =
        (payload[4] & 0x03) << 8; // bits 1-0, shift to position 8-9
    final basicLongLow = payload[5];
    final messageCountBasicAndLong = basicLongHigh | basicLongLow;

    return Gdl90DataEvent(Gdl90Message(
      messageType: Gdl90MessageType.heartbeat,
      messageId: messageId,
      // Status byte 1 flags
      gpsPosValid: gpsPosValid,
      maintRequired: maintRequired,
      identActive: identActive,
      ownshipAnonAddr: ownshipAnonAddr,
      batteryLow: batteryLow,
      ratcs: ratcs,
      uatInitialized: uatInitialized,
      // Status byte 2 flags
      csaRequested: csaRequested,
      csaNotAvailable: csaNotAvailable,
      utcOk: utcOk,
      // Timestamp and counts
      timeOfDaySeconds: timeOfDaySeconds,
      messageCountUplink: messageCountUplink,
      messageCountBasicAndLong: messageCountBasicAndLong,
    ));
  }

  /// Parse initialization message (ID 0x02).
  ///
  /// Initialization messages are rarely emitted (only on device startup).
  /// Per FAA ICD §3.2 Table 4, payload is 18 bytes. We extract only the
  /// first two audio-related fields; remaining bytes are reserved.
  ///
  /// Payload structure (18 bytes after CRC strip):
  /// - Byte 0: Audio inhibit flag
  /// - Byte 1: Audio test flag
  /// - Bytes 2-17: Reserved (not extracted in Phase 5)
  static Gdl90Event _parseInitialization(int messageId, Uint8List payload) {
    assert(
      messageId == 0x02,
      'Initialization parser received ID: 0x${messageId.toRadixString(16).toUpperCase()}',
    );

    // Length check: initialization requires 18-byte payload
    if (payload.length < 18) {
      return Gdl90ErrorEvent(
        reason:
            'Truncated initialization message: expected 18 bytes, got ${payload.length}',
        hint: 'Per FAA ICD §3.2 Table 4, initialization payload is 18 bytes',
      );
    }

    // Extract audio fields (bytes 0-1)
    final audioInhibit = payload[0];
    final audioTest = payload[1];

    return Gdl90DataEvent(Gdl90Message(
      messageType: Gdl90MessageType.initialization,
      messageId: messageId,
      audioInhibit: audioInhibit,
      audioTest: audioTest,
    ));
  }
}
