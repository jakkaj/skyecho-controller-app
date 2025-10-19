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
      case 0x07: // Uplink
      case 0x09: // HAT
      case 0x0A: // Ownship
      case 0x0B: // Ownship Geo Altitude
      case 0x14: // Traffic
      case 0x1E: // Basic Report
      case 0x1F: // Long Report
        return Gdl90ErrorEvent(
          reason: 'Unsupported message type: 0x${messageId.toRadixString(16)}',
          hint: 'This message type will be implemented in Phase 5-7',
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

  /// Parse heartbeat message (ID 0x00) - stub implementation.
  ///
  /// Per Insight #5: Defensive assertion validates messageId matches expected
  /// value to catch routing table bugs in debug mode (zero cost in release).
  ///
  /// Phase 4 stub returns minimal message with null fields. Actual field
  /// parsing will be implemented in Phase 5.
  static Gdl90Event _parseHeartbeat(int messageId, Uint8List payload) {
    // Defensive assertion (Insight #5)
    assert(
      messageId == 0x00,
      'Heartbeat parser received ID: 0x${messageId.toRadixString(16).toUpperCase()}',
    );

    // Length check: heartbeat requires 6-byte payload (after CRC stripped)
    // Original message: 7 bytes total (messageId + 6 payload bytes)
    if (payload.length < 6) {
      return Gdl90ErrorEvent(
        reason:
            'Truncated heartbeat message: expected 6 bytes, got ${payload.length}',
        hint:
            'Heartbeat payload format: [status1, status2, timestamp_msb, timestamp_lsb, msg_count_uplink, msg_count_basic_long]',
      );
    }

    // Stub: return minimal message with null fields
    // Actual field parsing in Phase 5
    return Gdl90DataEvent(Gdl90Message(
      messageType: Gdl90MessageType.heartbeat,
      messageId: messageId,
      // All fields null (actual parsing in Phase 5)
    ));
  }
}
