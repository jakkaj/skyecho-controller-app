import 'dart:typed_data';

/// GDL90 CRC-16-CCITT validation (per FAA Public ICD Rev A).
///
/// Implements CRC-16-CCITT with polynomial 0x1021, init 0x0000,
/// no reflection, LSB-first byte ordering as specified in
/// FAA GDL90 ICD §2.2.3.
///
/// Validated against FAA test vectors
/// (e.g., heartbeat example → CRC 0x8BB3).
///
/// This class contains only static methods because CRC computation
/// is stateless.
// ignore: avoid_classes_with_only_static_members
class Gdl90Crc {
  static final Uint16List _table = _init();

  /// Initialize CRC-16-CCITT lookup table.
  ///
  /// Algorithm copied from research implementation (lines 51-61 of gdl90.md).
  /// Table-driven approach for performance.
  static Uint16List _init() {
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

  /// Computes CRC-16-CCITT for GDL90 frames.
  ///
  /// Uses polynomial 0x1021, init 0x0000, LSB-first byte ordering.
  /// Validates against FAA GDL90 Public ICD Rev A test vectors.
  ///
  /// Algorithm copied from research implementation (lines 63-70 of gdl90.md).
  static int compute(Uint8List block, [int offset = 0, int? length]) {
    final end = offset + (length ?? (block.length - offset));
    int crc = 0;
    for (var i = offset; i < end; i++) {
      crc = _table[crc >> 8] ^ ((crc << 8) & 0xFFFF) ^ block[i];
    }
    return crc & 0xFFFF;
  }

  /// Returns true if [block] ends with a valid LSB-first CRC that matches
  /// the data before it.
  ///
  /// Frame format: [message_bytes..., crc_lsb, crc_msb]
  ///
  /// Algorithm copied from research implementation (lines 73-79 of gdl90.md).
  static bool verifyTrailing(Uint8List block) {
    if (block.length < 3) return false;
    final dataLen = block.length - 2;
    final calc = compute(block, 0, dataLen);
    final rx = block[dataLen] | (block[dataLen + 1] << 8); // LSB-first
    return calc == rx;
  }
}
