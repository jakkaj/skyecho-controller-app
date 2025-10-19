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

      case 0x07: // Uplink Data
        return _parseUplink(messageId, payload);

      case 0x09: // Height Above Terrain
        return _parseHAT(messageId, payload);

      case 0x0A: // Ownship Report
        return _parseOwnship(messageId, payload);

      case 0x0B: // Ownship Geometric Altitude
        return _parseOwnshipGeoAltitude(messageId, payload);

      case 0x14: // Traffic Report
        return _parseTraffic(messageId, payload);

      case 0x1E: // Pass-Through Basic Report
      case 0x1F: // Pass-Through Long Report
        return _parsePassThrough(messageId, payload);

      default:
        return Gdl90ErrorEvent(
          reason:
              'Unknown message ID: 0x${messageId.toRadixString(16).toUpperCase()}',
          hint:
              'Supported IDs: 0x00 (Heartbeat), 0x02 (Initialization), 0x07 (Uplink), '
              '0x09 (HAT), 0x0A (Ownship), 0x0B (Geo Altitude), 0x14 (Traffic), '
              '0x1E (Basic Report), 0x1F (Long Report). Additional message types '
              'may be implemented in Phase 8+.',
          rawBytes: frame,
        );
    }
  }

  /// Converts an unsigned value to signed using two's complement.
  ///
  /// Handles any bit width (e.g., 12-bit for vertical velocity, 24-bit for
  /// lat/lon semicircles). Checks the sign bit and applies two's complement
  /// conversion if negative.
  ///
  /// Per Critical Discovery 03 and Insight #3: Generic helper replaces separate
  /// _toSigned24() and _toSigned12() methods. Used for:
  /// - 24-bit semicircle lat/lon conversion (sign bit = bit 23)
  /// - 12-bit signed vertical velocity (sign bit = bit 11)
  ///
  /// Example:
  /// ```dart
  /// // 24-bit negative latitude (southern hemisphere)
  /// final lat24 = 0xF00000; // Sign bit set
  /// final latSigned = _toSigned(lat24, 24); // Returns negative value
  ///
  /// // 12-bit negative vertical velocity (descent)
  /// final vvel12 = 0x810; // -16 in 12-bit two's complement
  /// final vvelSigned = _toSigned(vvel12, 12); // Returns -16
  /// ```
  ///
  /// Parameters:
  /// - [value]: Unsigned integer value to convert
  /// - [bits]: Bit width of the field (e.g., 12, 24)
  ///
  /// Returns: Signed integer after two's complement conversion
  static int _toSigned(int value, int bits) {
    final signBit = 1 << (bits - 1);
    final mask = (1 << bits) - 1;
    value &= mask;
    return (value & signBit) != 0 ? value - (1 << bits) : value;
  }

  /// Invalid altitude marker (12-bit field)
  static const int _ALTITUDE_INVALID = 0xFFF;

  /// Extracts altitude from 12-bit raw value with offset and scaling.
  ///
  /// Per Insight #2: Checks invalid marker (0xFFF) BEFORE applying formula
  /// to prevent altitude formula precedence trap. Without this check, 0xFFF
  /// would be interpreted as 101,375 feet instead of null (no GPS fix).
  ///
  /// Formula: (raw12bit * 25) - 1000 feet MSL
  /// - Range: -1000 to 101,350 feet (25-foot resolution)
  /// - Invalid marker: 0xFFF → null (no altitude data available)
  ///
  /// Example:
  /// ```dart
  /// final alt1 = _extractAltitudeFeet(140); // Returns 2500 feet
  /// final alt2 = _extractAltitudeFeet(0xFFF); // Returns null (invalid)
  /// final alt3 = _extractAltitudeFeet(40); // Returns 0 feet (sea level)
  /// final alt4 = _extractAltitudeFeet(0); // Returns -1000 feet (below sea level)
  /// ```
  ///
  /// Parameters:
  /// - [raw12bit]: 12-bit altitude value from GDL90 message
  ///
  /// Returns:
  /// - Non-null altitude in feet MSL if valid
  /// - null if invalid marker (0xFFF)
  static int? _extractAltitudeFeet(int raw12bit) {
    if (raw12bit == _ALTITUDE_INVALID) {
      return null; // Check BEFORE formula application
    }
    return (raw12bit * 25) - 1000;
  }

  /// Parse ownship report message (ID 0x0A).
  ///
  /// Extracts 27-byte position report for own aircraft including GPS coordinates,
  /// altitude, velocity, heading, and identification.
  ///
  /// Per Critical Discovery 03: Lat/lon encoded as 24-bit signed semicircles
  /// with scaling factor 180/2^23 degrees. Uses _toSigned(value, 24) for sign
  /// extension.
  ///
  /// Per Insight #2: Uses _extractAltitudeFeet() helper to check invalid marker
  /// (0xFFF) before applying altitude formula.
  ///
  /// Payload structure (27 bytes):
  /// - Byte 0: Status (bit 4=trafficAlert, bit 3=airborne)
  /// - Bytes 1-3: ICAO address (24-bit participant address)
  /// - Bytes 4-6: Latitude (24-bit signed semicircles, MSB-first)
  /// - Bytes 7-9: Longitude (24-bit signed semicircles, MSB-first)
  /// - Bytes 10-11: Altitude (12-bit) + Misc nibble
  /// - Byte 12: NIC/NACp
  /// - Bytes 13-14: Horizontal velocity (12-bit unsigned)
  /// - Bytes 14-15: Vertical velocity (12-bit signed, spans nibble boundary)
  /// - Byte 16: Track/heading (8-bit angular)
  /// - Byte 17: Emitter category
  /// - Bytes 18-25: Callsign (8 ASCII bytes, right-padded with spaces)
  /// - Byte 26: Emergency/priority code
  ///
  /// Returns [Gdl90DataEvent] with populated ownship fields, or [Gdl90ErrorEvent]
  /// if payload is truncated.
  static Gdl90Event _parseOwnship(int messageId, Uint8List payload) {
    assert(messageId == 0x0A,
        'Expected ownship message ID 0x0A, got 0x${messageId.toRadixString(16)}');

    // Validate payload length
    if (payload.length < 27) {
      return Gdl90ErrorEvent(
        reason:
            'Truncated ownship message: expected 27 bytes, got ${payload.length}',
        hint:
            'Ownship payload: [status, addr(3), lat(3), lon(3), alt(2), misc, nic, vel(2), vvel(2), track, emitter, callsign(8), emergency]',
      );
    }

    int offset = 0;

    // Status byte: bit 4 = traffic alert, bit 3 = airborne
    final status = payload[offset++];
    final trafficAlert = (status & 0x10) != 0; // bit 4
    final airborne = (status & 0x08) != 0; // bit 3

    // ICAO address (24-bit, 3 bytes, MSB-first)
    final icaoAddress = (payload[offset] << 16) |
        (payload[offset + 1] << 8) |
        payload[offset + 2];
    offset += 3;

    // Latitude (24-bit signed semicircles, MSB-first)
    final lat24 = (payload[offset] << 16) |
        (payload[offset + 1] << 8) |
        payload[offset + 2];
    offset += 3;
    final latSigned = _toSigned(lat24, 24);
    final latitude = latSigned * (180.0 / (1 << 23)); // Semicircle to degrees

    // Longitude (24-bit signed semicircles, MSB-first)
    final lon24 = (payload[offset] << 16) |
        (payload[offset + 1] << 8) |
        payload[offset + 2];
    offset += 3;
    final lonSigned = _toSigned(lon24, 24);
    final longitude = lonSigned * (180.0 / (1 << 23));

    // Altitude (12-bit) + Misc nibble
    // Byte 10: high 8 bits of altitude (dd)
    // Byte 11: low 4 bits of altitude (high nibble dm) + misc nibble (low nibble)
    final dd = payload[offset++];
    final dm = payload[offset++];
    final altitudeRaw = ((dd << 4) | (dm >> 4)) & 0xFFF;
    final altitudeFeet = _extractAltitudeFeet(altitudeRaw); // Uses helper

    // Misc nibble (low 4 bits of dm) - contains airborne bit (bit 3)
    // Note: airborne already extracted from status byte above

    // NIC/NACp (byte 12) - not extracted per non-goals
    offset++; // Skip NIC/NACp byte

    // Horizontal velocity (12-bit unsigned, spans 2 bytes)
    // Byte 13: high 8 bits (hh)
    // Byte 14: low 4 bits (high nibble of hv)
    final hh = payload[offset++];
    final hv = payload[offset++];
    final horizRaw = ((hh << 4) | (hv >> 4)) & 0xFFF;
    final horizontalVelocityKt = (horizRaw == 0xFFF) ? null : horizRaw;

    // Vertical velocity (12-bit signed, low nibble of hv + byte 15)
    final vv = payload[offset++];
    final vertRaw = (((hv & 0x0F) << 8) | vv) & 0xFFF;
    int? verticalVelocityFpm;
    if (vertRaw == 0x800) {
      verticalVelocityFpm =
          null; // Invalid marker (check BEFORE sign extension)
    } else {
      final vertSigned = _toSigned(vertRaw, 12);
      verticalVelocityFpm = vertSigned * 64; // 64 fpm per LSB
    }

    // Track/heading (8-bit angular)
    final trackRaw = payload[offset++];
    final trackDegrees = (trackRaw * 360.0 / 256.0).round();

    // Emitter category
    final emitterCategory = payload[offset++];

    // Callsign (8 ASCII bytes)
    final callsignBytes = payload.sublist(offset, offset + 8);
    offset += 8;
    final callsign = String.fromCharCodes(callsignBytes).trimRight();

    // Emergency/priority code (byte 26) - not extracted per non-goals
    offset++; // Skip emergency byte

    return Gdl90DataEvent(
      Gdl90Message(
        messageType: Gdl90MessageType.ownship,
        messageId: messageId,
        trafficAlert: trafficAlert,
        airborne: airborne,
        icaoAddress: icaoAddress,
        latitude: latitude,
        longitude: longitude,
        altitudeFeet: altitudeFeet,
        horizontalVelocityKt: horizontalVelocityKt,
        verticalVelocityFpm: verticalVelocityFpm,
        trackDegrees: trackDegrees,
        emitterCategory: emitterCategory,
        callsign: callsign,
      ),
    );
  }

  /// Parse traffic report message (ID 0x14).
  ///
  /// Identical structure to ownship report (ID 0x0A), but for other aircraft.
  /// Shares same field extraction logic with different message type enum.
  ///
  /// See [_parseOwnship] for complete field documentation.
  static Gdl90Event _parseTraffic(int messageId, Uint8List payload) {
    assert(messageId == 0x14,
        'Expected traffic message ID 0x14, got 0x${messageId.toRadixString(16)}');

    // Validate payload length
    if (payload.length < 27) {
      return Gdl90ErrorEvent(
        reason:
            'Truncated traffic message: expected 27 bytes, got ${payload.length}',
        hint:
            'Traffic payload: [status, addr(3), lat(3), lon(3), alt(2), misc, nic, vel(2), vvel(2), track, emitter, callsign(8), emergency]',
      );
    }

    int offset = 0;

    // Status byte: bit 4 = traffic alert, bit 3 = airborne
    final status = payload[offset++];
    final trafficAlert = (status & 0x10) != 0; // bit 4
    final airborne = (status & 0x08) != 0; // bit 3

    // ICAO address (24-bit, 3 bytes, MSB-first)
    final icaoAddress = (payload[offset] << 16) |
        (payload[offset + 1] << 8) |
        payload[offset + 2];
    offset += 3;

    // Latitude (24-bit signed semicircles, MSB-first)
    final lat24 = (payload[offset] << 16) |
        (payload[offset + 1] << 8) |
        payload[offset + 2];
    offset += 3;
    final latSigned = _toSigned(lat24, 24);
    final latitude = latSigned * (180.0 / (1 << 23));

    // Longitude (24-bit signed semicircles, MSB-first)
    final lon24 = (payload[offset] << 16) |
        (payload[offset + 1] << 8) |
        payload[offset + 2];
    offset += 3;
    final lonSigned = _toSigned(lon24, 24);
    final longitude = lonSigned * (180.0 / (1 << 23));

    // Altitude (12-bit) + Misc nibble
    final dd = payload[offset++];
    final dm = payload[offset++];
    final altitudeRaw = ((dd << 4) | (dm >> 4)) & 0xFFF;
    final altitudeFeet = _extractAltitudeFeet(altitudeRaw);

    // NIC/NACp (byte 12) - not extracted per non-goals
    offset++; // Skip NIC/NACp byte

    // Horizontal velocity (12-bit unsigned)
    final hh = payload[offset++];
    final hv = payload[offset++];
    final horizRaw = ((hh << 4) | (hv >> 4)) & 0xFFF;
    final horizontalVelocityKt = (horizRaw == 0xFFF) ? null : horizRaw;

    // Vertical velocity (12-bit signed)
    final vv = payload[offset++];
    final vertRaw = (((hv & 0x0F) << 8) | vv) & 0xFFF;
    int? verticalVelocityFpm;
    if (vertRaw == 0x800) {
      verticalVelocityFpm = null;
    } else {
      final vertSigned = _toSigned(vertRaw, 12);
      verticalVelocityFpm = vertSigned * 64;
    }

    // Track/heading (8-bit angular)
    final trackRaw = payload[offset++];
    final trackDegrees = (trackRaw * 360.0 / 256.0).round();

    // Emitter category
    final emitterCategory = payload[offset++];

    // Callsign (8 ASCII bytes)
    final callsignBytes = payload.sublist(offset, offset + 8);
    offset += 8;
    final callsign = String.fromCharCodes(callsignBytes).trimRight();

    // Emergency/priority code (byte 26) - not extracted per non-goals
    offset++; // Skip emergency byte

    return Gdl90DataEvent(
      Gdl90Message(
        messageType: Gdl90MessageType.traffic, // Different from ownship
        messageId: messageId,
        trafficAlert: trafficAlert,
        airborne: airborne,
        icaoAddress: icaoAddress,
        latitude: latitude,
        longitude: longitude,
        altitudeFeet: altitudeFeet,
        horizontalVelocityKt: horizontalVelocityKt,
        verticalVelocityFpm: verticalVelocityFpm,
        trackDegrees: trackDegrees,
        emitterCategory: emitterCategory,
        callsign: callsign,
      ),
    );
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

  /// Invalid HAT marker (16-bit field)
  static const int _HAT_INVALID = 0x8000;

  /// Parse Height Above Terrain message (ID 0x09).
  ///
  /// Extracts 16-bit signed height in feet with invalid marker check.
  /// Per Critical Insight #2: Checks invalid marker (0x8000) BEFORE sign
  /// conversion to prevent treating invalid value as -32768 feet.
  ///
  /// Payload structure (2 bytes after CRC strip):
  /// - Bytes 0-1: Height above terrain (16-bit signed MSB-first)
  ///   - Special value: 0x8000 → null (invalid marker)
  ///   - Range: -32768 to +32767 feet (when valid)
  ///
  /// Returns [Gdl90DataEvent] with [heightAboveTerrainFeet] populated, or
  /// [Gdl90ErrorEvent] if payload is truncated.
  static Gdl90Event _parseHAT(int messageId, Uint8List payload) {
    assert(
      messageId == 0x09,
      'HAT parser received ID: 0x${messageId.toRadixString(16).toUpperCase()}',
    );

    // Strict length validation: HAT requires exactly 2-byte payload
    if (payload.length != 2) {
      return Gdl90ErrorEvent(
        reason:
            'Truncated HAT message: expected 2 bytes, got ${payload.length}',
        hint: 'HAT payload format: [height_msb, height_lsb]',
      );
    }

    // Extract 16-bit MSB-first height
    final raw16bit = (payload[0] << 8) | payload[1];

    // Check invalid marker BEFORE sign conversion (Critical Insight #2)
    int? heightAboveTerrainFeet;
    if (raw16bit == _HAT_INVALID) {
      heightAboveTerrainFeet = null; // Invalid marker
    } else {
      heightAboveTerrainFeet = _toSigned(raw16bit, 16);
    }

    return Gdl90DataEvent(Gdl90Message(
      messageType: Gdl90MessageType.hat,
      messageId: messageId,
      heightAboveTerrainFeet: heightAboveTerrainFeet,
    ));
  }

  /// Maximum Uplink payload size in bytes (security limit per Insight #1)
  static const int _MAX_UPLINK_PAYLOAD_BYTES = 1024;

  /// Parse Uplink Data message (ID 0x07).
  ///
  /// Extracts 24-bit LSB-first time-of-reception (TOR) and variable-length
  /// UAT payload (typically 432 bytes, max 1024 bytes per security limit).
  ///
  /// Per Critical Insight #1: Enforces 1KB upper bound to prevent memory
  /// bomb DoS attacks from malicious or corrupt frames.
  ///
  /// Payload structure (3+ bytes after CRC strip):
  /// - Bytes 0-2: Time of reception (24-bit LSB-first, 80ns units)
  /// - Bytes 3+: Variable-length UAT uplink payload (max 1024 bytes)
  ///
  /// Returns [Gdl90DataEvent] with [timeOfReception80ns] and [uplinkPayload]
  /// populated, or [Gdl90ErrorEvent] if payload is truncated or exceeds limit.
  static Gdl90Event _parseUplink(int messageId, Uint8List payload) {
    assert(
      messageId == 0x07,
      'Uplink parser received ID: 0x${messageId.toRadixString(16).toUpperCase()}',
    );

    // Minimum length validation: 3 bytes for TOR
    if (payload.length < 3) {
      return Gdl90ErrorEvent(
        reason:
            'Truncated uplink message: expected >= 3 bytes, got ${payload.length}',
        hint: 'Uplink payload format: [tor_lsb, tor_mid, tor_msb, ...payload]',
      );
    }

    // Security validation: 1KB upper bound prevents memory bombs (Insight #1)
    if (payload.length > 3 + _MAX_UPLINK_PAYLOAD_BYTES) {
      return Gdl90ErrorEvent(
        reason:
            'Uplink payload exceeds 1KB security limit: ${payload.length - 3} bytes',
        hint:
            'Maximum allowed: ${_MAX_UPLINK_PAYLOAD_BYTES} bytes. This limit prevents memory exhaustion from malicious frames.',
      );
    }

    // Extract 24-bit LSB-first TOR
    final tor = payload[0] | (payload[1] << 8) | (payload[2] << 16);

    // Extract variable-length payload (everything after TOR)
    final uplinkPayload = payload.sublist(3);

    return Gdl90DataEvent(Gdl90Message(
      messageType: Gdl90MessageType.uplinkData,
      messageId: messageId,
      timeOfReception80ns: tor,
      uplinkPayload: uplinkPayload,
    ));
  }

  /// Parse Ownship Geometric Altitude message (ID 0x0B).
  ///
  /// Extracts 16-bit geometric altitude with 5-ft resolution (different from
  /// 25-ft Ownship altitude) and optional vertical metrics (warning flag +
  /// VFOM).
  ///
  /// Per Insight #4: VFOM special values (0x7FFF, 0x7EEE) are preserved in
  /// [vfomMetersRaw]; computed property [vfomMeters] returns null for both.
  ///
  /// Payload structure (2-4 bytes after CRC strip):
  /// - Bytes 0-1: Geometric altitude (16-bit signed MSB-first, 5-ft resolution)
  /// - Bytes 2-3: Vertical metrics (optional, 16-bit MSB-first)
  ///   - Bit 15: Vertical warning flag
  ///   - Bits 14-0: VFOM in meters (0x7FFF=not available, 0x7EEE=>32766m)
  ///
  /// Returns [Gdl90DataEvent] with [geoAltitudeFeet], [verticalWarning], and
  /// [vfomMetersRaw] populated. Defaults: verticalWarning=false, vfomMetersRaw=0x7FFF
  /// if metrics field missing.
  static Gdl90Event _parseOwnshipGeoAltitude(int messageId, Uint8List payload) {
    assert(
      messageId == 0x0B,
      'Geo Altitude parser received ID: 0x${messageId.toRadixString(16).toUpperCase()}',
    );

    // Flexible length validation: >= 2 bytes (vertical metrics optional)
    if (payload.length < 2) {
      return Gdl90ErrorEvent(
        reason:
            'Truncated geo altitude message: expected >= 2 bytes, got ${payload.length}',
        hint:
            'Geo altitude payload format: [alt_msb, alt_lsb, metrics_msb?, metrics_lsb?]',
      );
    }

    // Extract 16-bit altitude (MSB-first) with 5-ft resolution
    final raw16bit = (payload[0] << 8) | payload[1];
    final geoAltitudeFeet = _toSigned(raw16bit, 16) * 5;

    // Extract vertical metrics if present (optional field)
    bool verticalWarning;
    int vfomMetersRaw;

    if (payload.length >= 4) {
      // Vertical metrics present
      final metrics = (payload[2] << 8) | payload[3];
      verticalWarning = (metrics & 0x8000) != 0; // Bit 15
      vfomMetersRaw = metrics & 0x7FFF; // Bits 14-0
    } else {
      // Vertical metrics missing - use defaults
      verticalWarning = false;
      vfomMetersRaw = 0x7FFF; // "Not available" per Insight #4
    }

    return Gdl90DataEvent(Gdl90Message(
      messageType: Gdl90MessageType.ownshipGeoAltitude,
      messageId: messageId,
      geoAltitudeFeet: geoAltitudeFeet,
      verticalWarning: verticalWarning,
      vfomMetersRaw: vfomMetersRaw,
    ));
  }

  /// Parse Pass-Through message (ID 0x1E Basic, 0x1F Long).
  ///
  /// Unified method handles both Basic Report (ID 30, 18-byte payload) and
  /// Long Report (ID 31, 34-byte payload). Differentiates by [messageId] to
  /// populate correct payload field.
  ///
  /// Per Critical Insight #2: Defensive assertion catches routing table bugs
  /// where wrong message ID is passed to this method.
  ///
  /// ⚠️ IMPORTANT: This method depends on correct routing table configuration.
  /// Only call from switch cases 0x1E and 0x1F. Assertion will catch bugs in
  /// debug mode.
  ///
  /// Payload structure (3+ bytes after CRC strip):
  /// - Bytes 0-2: Time of reception (24-bit LSB-first, 80ns units)
  /// - Bytes 3+: Variable-length UAT report payload
  ///   - Basic (0x1E): typically 18 bytes
  ///   - Long (0x1F): typically 34 bytes
  ///
  /// Returns [Gdl90DataEvent] with [timeOfReception80ns] and either
  /// [basicReportPayload] or [longReportPayload] populated.
  static Gdl90Event _parsePassThrough(int messageId, Uint8List payload) {
    // Defensive assertion: Catch routing table mistakes (Insight #2)
    assert(
      messageId == 0x1E || messageId == 0x1F,
      'Invalid messageId 0x${messageId.toRadixString(16).toUpperCase()} for '
      '_parsePassThrough - only 0x1E/0x1F supported. '
      'This indicates a routing table bug.',
    );

    // Permissive length validation: >= 3 bytes for TOR
    if (payload.length < 3) {
      return Gdl90ErrorEvent(
        reason:
            'Truncated pass-through message: expected >= 3 bytes, got ${payload.length}',
        hint:
            'Pass-through payload format: [tor_lsb, tor_mid, tor_msb, ...uat_report]',
      );
    }

    // Extract 24-bit LSB-first TOR
    final tor = payload[0] | (payload[1] << 8) | (payload[2] << 16);

    // Extract variable-length UAT report payload
    final reportPayload = payload.sublist(3);

    // Determine message type and payload field from messageId
    final messageType = messageId == 0x1E
        ? Gdl90MessageType.basicReport
        : Gdl90MessageType.longReport;

    return Gdl90DataEvent(Gdl90Message(
      messageType: messageType,
      messageId: messageId,
      timeOfReception80ns: tor,
      basicReportPayload: messageId == 0x1E ? reportPayload : null,
      longReportPayload: messageId == 0x1F ? reportPayload : null,
    ));
  }
}
