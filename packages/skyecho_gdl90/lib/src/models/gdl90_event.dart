import 'dart:typed_data';

import 'gdl90_message.dart';

/// Wrapper for GDL90 parse results using sealed class pattern.
///
/// Per Critical Discovery 05: UDP is lossy; malformed frames are expected.
/// Parser never throws exceptions—instead wraps results in events for robust
/// error handling without breaking streams.
///
/// Per Insight #3: Three event types provide type-safe exhaustive matching:
/// - [Gdl90DataEvent]: Successful parse containing a [Gdl90Message]
/// - [Gdl90ErrorEvent]: Parse failure with diagnostic information
/// - [Gdl90IgnoredEvent]: Message ID explicitly ignored via ignoreMessageIds
///
/// Example pattern matching:
/// ```dart
/// switch (event) {
///   case Gdl90DataEvent(:final message):
///     handleMessage(message);
///   case Gdl90ErrorEvent(:final reason, :final hint):
///     log.warning('Error: $reason. Hint: $hint');
///   case Gdl90IgnoredEvent(:final messageId):
///     // Explicitly ignored, no action needed
///     return;
/// }
/// ```
sealed class Gdl90Event {}

/// Successful parse result containing a GDL90 message.
final class Gdl90DataEvent extends Gdl90Event {
  final Gdl90Message message;

  Gdl90DataEvent(this.message);
}

/// Parse failure with diagnostic information.
///
/// Contains:
/// - `reason`: Human-readable error description
/// - `rawBytes`: Original frame bytes (optional)
/// - `hint`: Actionable guidance for debugging (optional)
final class Gdl90ErrorEvent extends Gdl90Event {
  final String reason;
  final Uint8List? rawBytes;
  final String? hint;

  Gdl90ErrorEvent({
    required this.reason,
    this.rawBytes,
    this.hint,
  });
}

/// Message ID explicitly ignored via ignoreMessageIds parameter.
///
/// Per Insight #1: Prevents ErrorEvent flooding when firmware adds new message
/// types. Per Insight #3: Type-safe alternative to nullable return (no null
/// checks needed in pattern matching).
final class Gdl90IgnoredEvent extends Gdl90Event {
  final int messageId;

  Gdl90IgnoredEvent({required this.messageId});
}
