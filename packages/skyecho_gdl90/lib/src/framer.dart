import 'dart:typed_data';

/// GDL90 byte framer for extracting frames from continuous byte streams.
///
/// Implements GDL90 framing protocol (0x7E flags) and byte-stuffing
/// escape sequences (0x7D escaping) per FAA GDL90 Public ICD Rev A §2.2.1.
///
/// **State Machine**:
/// - Waits for 0x7E start flag
/// - Accumulates bytes, de-escaping 0x7D sequences
/// - On end flag (0x7E), validates CRC and emits frame via callback
/// - Invalid frames are silently discarded
///
/// **Usage**:
/// ```dart
/// final framer = Gdl90Framer();
/// framer.addBytes(udpData, (frame) {
///   print('Received frame: ${frame.length} bytes');
/// });
/// ```
///
/// **⚠️ Warning**: Do not call `addBytes()` from within the `onFrame` callback.
/// This creates re-entrancy and will throw a [StateError].
class Gdl90Framer {
  /// Maximum frame size per GDL90 spec worst-case:
  /// (432 max payload + 2 CRC) × 2 worst-case escaping = 868 bytes
  static const int maxFrameSize = 868;

  /// Internal buffer for accumulating frame bytes
  final _buf = <int>[];

  /// True when inside a frame (after start flag, before end flag)
  bool _inFrame = false;

  /// True when previous byte was 0x7D (escape byte)
  bool _escape = false;

  /// Guard flag to prevent re-entrant addBytes() calls
  bool _processing = false;

  /// Processes a chunk of bytes and invokes [onFrame] for each complete frame.
  ///
  /// **Parameters**:
  /// - [chunk]: Raw bytes from UDP/serial/file
  /// - [onFrame]: Callback invoked with each valid frame (de-escaped,
  ///   CRC-validated)
  ///
  /// **Throws**: [StateError] if called re-entrantly (from within
  /// [onFrame])
  void addBytes(Uint8List chunk, void Function(Uint8List frame) onFrame) {
    // CRITICAL #3: Guard against re-entrant calls
    if (_processing) {
      throw StateError('Re-entrant addBytes() call detected. '
          'Do not call addBytes() from within onFrame callback.');
    }

    try {
      _processing = true;

      for (final b in chunk) {
        // CRITICAL #1: Check for flag byte BEFORE applying escape de-escaping
        if (b == 0x7E) {
          // End of current frame (and start of next)
          if (_inFrame && _buf.isNotEmpty) {
            final data = Uint8List.fromList(_buf);
            // CRITICAL #4: Explicit length check before CRC
            // GDL90 frames must be at least 3 bytes: 1 message ID + 2 CRC
            if (data.length >= 3) {
              // Import CRC module for validation
              final isValid = _verifyCrc(data);
              if (isValid) {
                onFrame(data);
              }
              // Invalid CRC: silently discard, continue processing
            }
            // Frame too short: silently discard
          }
          _buf.clear();
          _inFrame = true;
          _escape = false;
          continue;
        }

        if (!_inFrame) continue;

        // CRITICAL #2: Enforce maxFrameSize limit to prevent DoS
        if (_buf.length >= maxFrameSize) {
          // Buffer exceeded limit: discard frame and reset
          _buf.clear();
          _inFrame = false;
          _escape = false;
          continue;
        }

        var v = b;
        if (_escape) {
          v = b ^ 0x20; // De-escape: restore original byte
          _escape = false;
        } else if (b == 0x7D) {
          _escape = true;
          continue;
        }
        _buf.add(v);
      }
    } finally {
      _processing = false;
    }
  }

  /// Verifies CRC of a frame (internal helper to avoid import issues in tests)
  bool _verifyCrc(Uint8List block) {
    if (block.length < 3) return false;
    final dataLen = block.length - 2;
    // Compute CRC on message bytes (exclude trailing 2-byte CRC)
    int crc = 0;
    for (var i = 0; i < dataLen; i++) {
      final byte = block[i];
      // CRC-16-CCITT table lookup (simplified inline version)
      crc = _crcTable[crc >> 8] ^ ((crc << 8) & 0xFFFF) ^ byte;
    }
    crc &= 0xFFFF;

    // Extract received CRC (LSB-first)
    final rx = block[dataLen] | (block[dataLen + 1] << 8);
    return crc == rx;
  }

  /// CRC-16-CCITT lookup table (polynomial 0x1021, init 0x0000)
  static final Uint16List _crcTable = _initCrcTable();

  static Uint16List _initCrcTable() {
    final table = Uint16List(256);
    for (var i = 0; i < 256; i++) {
      int crc = (i << 8) & 0xFFFF;
      for (var b = 0; b < 8; b++) {
        crc = (crc & 0x8000) != 0
            ? ((crc << 1) ^ 0x1021) & 0xFFFF
            : ((crc << 1) & 0xFFFF);
      }
      table[i] = crc;
    }
    return table;
  }
}
