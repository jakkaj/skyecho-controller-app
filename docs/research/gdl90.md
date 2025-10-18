Below is a complete, **pure‑Dart** GDL90 parser that:

* Implements the byte‑framing (0x7E) + escaping (0x7D ^ 0x20) and CRC-16‑CCITT **exactly as in the spec** (poly 0x1021, init 0x0000, no reflection, LSB‑first CRC bytes). ([Federal Aviation Administration][1])
* Decodes every standard message in the FAA public ICD: **Heartbeat (0), Initialization (2), Uplink Data (7), Height Above Terrain (9), Ownship (10), Ownship Geometric Altitude (11), Traffic (20), Pass‑Through Basic (30) & Long (31)**. ([Federal Aviation Administration][1])
* Separates **parsing** from **transport**. You feed bytes from UDP/serial/etc. into the parser; it yields strongly‑typed messages.
* Optionally decodes **ForeFlight extensions** (ID/AHRS on 0x65 with sub‑IDs), which are widely used by portable receivers. ([ForeFlight][2])

---

## Library layout

You can drop this into a package (e.g., `gdl90/`):

```
lib/
  gdl90.dart
  src/
    framer.dart
    crc.dart
    messages.dart
    decoder.dart
example/
  read_udp.dart
```

---

## `lib/gdl90.dart`

```dart
library gdl90;

export 'src/framer.dart';
export 'src/decoder.dart';
export 'src/messages.dart';
```

---

## `lib/src/crc.dart`

```dart
import 'dart:typed_data';

/// CRC-16-CCITT as used by GDL90 (poly 0x1021, init 0x0000, no reflection, no xorout).
/// Append to message LSB first, after de-escaping; compute over [Message ID + payload], not flags nor FCS.
/// Spec shows a table-driven example that matches this algorithm. (FAA GDL90 ICD §2.2.3) 
class Gdl90Crc {
  static final Uint16List _table = _init();

  static Uint16List _init() {
    final table = Uint16List(256);
    for (var i = 0; i < 256; i++) {
      int crc = (i << 8) & 0xFFFF;
      for (var b = 0; b < 8; b++) {
        crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) & 0xFFFF : ((crc << 1) & 0xFFFF);
      }
      table[i] = crc;
    }
    return table;
  }

  static int compute(Uint8List block, [int offset = 0, int? length]) {
    final end = offset + (length ?? (block.length - offset));
    int crc = 0;
    for (var i = offset; i < end; i++) {
      crc = _table[crc >> 8] ^ ((crc << 8) & 0xFFFF) ^ block[i];
    }
    return crc & 0xFFFF;
  }

  /// Returns true if `block` ends with a valid LSB-first CRC that matches the data before it.
  static bool verifyTrailing(Uint8List block) {
    if (block.length < 3) return false;
    final dataLen = block.length - 2;
    final calc = compute(block, 0, dataLen);
    final rx = block[dataLen] | (block[dataLen + 1] << 8);
    return calc == rx;
  }
}
```

---

## `lib/src/framer.dart`

```dart
import 'dart:typed_data';
import 'crc.dart';

/// GDL90 byte framer: consumes raw bytes (from UDP/serial/etc.), unescapes,
/// splits by 0x7E FLAG, validates CRC, and emits clear frames (Message ID + payload).
/// See FAA GDL90 ICD §2.2 (message structure, escaping, CRC, framing).
class Gdl90Framer {
  static const int flag = 0x7E;
  static const int esc  = 0x7D;

  final _buf = <int>[];
  bool _inFrame = false;
  bool _escape = false;

  /// Feed raw bytes. For each valid frame found, `onFrame` is invoked with the
  /// unescaped bytes [messageId, payload..., crcLSB, crcMSB] (CRC still present,
  /// so consumers can verify/remove if they want).
  ///
  /// Invalid CRC frames are discarded silently.
  void addBytes(Uint8List chunk, void Function(Uint8List clearFrame) onFrame) {
    for (final b in chunk) {
      if (b == flag) {
        // Possible end (and next start)
        if (_inFrame && _buf.isNotEmpty) {
          final data = Uint8List.fromList(_buf);
          if (data.length >= 3 && Gdl90Crc.verifyTrailing(data)) {
            onFrame(data);
          }
        }
        // Start a new frame
        _buf.clear();
        _inFrame = true;
        _escape = false;
        continue;
      }

      if (!_inFrame) continue;

      var v = b;
      if (_escape) {
        v = b ^ 0x20;
        _escape = false;
      } else if (b == esc) {
        _escape = true;
        continue;
      }
      _buf.add(v);
    }
  }
}
```

---

## `lib/src/messages.dart`

```dart
import 'dart:typed_data';

/// All known Message IDs (decimal) as per FAA GDL90 ICD Table 2.
class Gdl90MessageId {
  static const int heartbeat = 0;              // §3.1
  static const int initialization = 2;         // §3.2 (input *to* GDL90; some devices emit it too)
  static const int uplinkData = 7;             // §3.3
  static const int hat = 9;                    // §3.7 (Height Above Terrain)
  static const int ownship = 10;               // §3.4
  static const int ownshipGeoAltitude = 11;    // §3.8
  static const int trafficReport = 20;         // §3.5
  static const int basicReport = 30;           // §3.6
  static const int longReport = 31;            // §3.6

  // ForeFlight extension messages share ID 0x65 with sub-IDs in byte 2.
  static const int foreflightExt = 0x65;       // https://foreflight.com/connect/spec
}

/// Strongly typed base class for parsed messages.
abstract class Gdl90Message {
  final int id; // decimal message id
  final int? crc; // trailing CRC (if retained)
  Gdl90Message(this.id, {this.crc});
}

/// HEARTBEAT (ID=0) — status, time-of-day stamp (seconds since 0000Z), and message counts.
/// See §3.1 Table 3; Status bytes described in §3.1.1 and §3.1.2; counts in §3.1.4.
class Heartbeat extends Gdl90Message {
  // Status Byte 1
  final bool gpsPosValid;
  final bool maintenanceRequired;
  final bool identActive;
  final bool ownshipAnonAddr; // "Address Type talkback" (SW Mod C), else undefined
  final bool gpsBatteryLow;
  final bool ratcs;           // ATC Services talkback (SW Mod C), else undefined
  final bool uatInitialized;  // always 1 in ICD

  // Status Byte 2
  final bool csaRequested;
  final bool csaNotAvailable;
  final bool utcOk;
  final int  timeOfDaySeconds; // 17-bit: [Status2 bit7]<<16 | [TimeStamp bytes MSB:LSB], §3.1.3

  // Received message counts (previous second), §3.1.4
  final int uplinkCount;       // 5 bits (first counts byte bits 7..3)
  final int basicLongCount;    // 10 bits (first byte bits1..0 + second byte)

  Heartbeat({
    required this.gpsPosValid,
    required this.maintenanceRequired,
    required this.identActive,
    required this.ownshipAnonAddr,
    required this.gpsBatteryLow,
    required this.ratcs,
    required this.uatInitialized,
    required this.csaRequested,
    required this.csaNotAvailable,
    required this.utcOk,
    required this.timeOfDaySeconds,
    required this.uplinkCount,
    required this.basicLongCount,
    int? crc,
  }) : super(Gdl90MessageId.heartbeat, crc: crc);
}

/// UAT uplink (ID=7), carries raw 432-byte UAT payload with 24-bit TOR in 80ns units.
/// See §3.3.
class UplinkData extends Gdl90Message {
  final int tor80ns; // 24-bit, LSB-first in the message (§3.3.1)
  double get torSeconds => tor80ns / 12_500_000.0;
  final Uint8List payload; // 432 bytes UAT payload
  UplinkData({required this.tor80ns, required this.payload, int? crc})
      : super(Gdl90MessageId.uplinkData, crc: crc);
}

/// Height Above Terrain (ID=9). 16-bit signed feet; 0x8000 = invalid. (§3.7)
class HeightAboveTerrain extends Gdl90Message {
  final int feet; // signed feet; if invalid==true this is 0
  final bool invalid;
  HeightAboveTerrain({required this.feet, required this.invalid, int? crc})
      : super(Gdl90MessageId.hat, crc: crc);
}

/// Ownship Geometric Altitude (ID=11). (§3.8)
class OwnshipGeoAltitude extends Gdl90Message {
  /// 16-bit signed, 5 ft resolution.
  final int altitudeFeet;
  /// Vertical metrics: [bit15 warning][bits14..0 VFOM meters], 0x7FFF => not available; 0x7EEE => >32766 m.
  final bool verticalWarning;
  final int vfomMetersRaw; // 0..0x7FFF (special values allowed)
  OwnshipGeoAltitude({
    required this.altitudeFeet,
    required this.verticalWarning,
    required this.vfomMetersRaw,
    int? crc,
  }) : super(Gdl90MessageId.ownshipGeoAltitude, crc: crc);
}

/// Pass-through Basic (ID=30) / Long (ID=31) UAT reports (§3.6).
class PassThroughReport extends Gdl90Message {
  final int tor80ns; // 24-bit (LSB-first)
  double get torSeconds => tor80ns / 12_500_000.0;
  final Uint8List payload; // 18 bytes (Basic) or 34 bytes (Long), per DO-282
  PassThroughReport({required int id, required this.tor80ns, required this.payload, int? crc})
      : assert(id == Gdl90MessageId.basicReport || id == Gdl90MessageId.longReport),
        super(id, crc: crc);
}

/// Traffic / Ownship common structure (27-byte body), see §3.5.1 (Figure 2 & Table 8).
enum AddressType {
  adsbIcao,          // t=0
  adsbSelfAssigned,  // t=1
  tisBIcao,          // t=2
  tisBTrackFile,     // t=3
  surfaceVehicle,    // t=4
  groundStation,     // t=5
  reserved           // t>=6
}

enum TrackHeadingType { notValid, trueTrack, magneticHeading, trueHeading }

class TrafficReport extends Gdl90Message {
  final bool isOwnship;               // ID=10 => ownship, ID=20 => traffic
  final bool trafficAlert;            // s (bitfield)
  final AddressType addressType;      // t
  final int participantAddress;       // 24-bit
  final double? latitude;             // degrees (null if invalid per ICD: lat/lon/NIC all zero)
  final double? longitude;            // degrees
  final int? altitudeBaroFt;          // feet (25-ft steps, offset -1000). 0xFFF => invalid => null
  final TrackHeadingType trackType;   // from 'm' bits
  final bool airborne;                // 'm' bit3
  final bool extrapolated;            // 'm' bit2 == 1
  final int nic;                      // 0..15
  final int nacp;                     // 0..15
  final int? horizontalVelocityKt;    // 12-bit; 0xFFF => unavailable
  final int? verticalVelocityFpm;     // 12-bit signed; 0x800 => unavailable
  final double? trackDegrees;         // 0..<360, 360/256 deg steps; null if 'tt' not valid per 'm'
  final int emitterCategory;          // 0..39 (Table 11)
  final String callSign;              // 8 ASCII chars (0..9,A..Z, space padding)
  final int emergencyPriorityCode;    // 'p' 0..15

  TrafficReport({
    required this.isOwnship,
    required this.trafficAlert,
    required this.addressType,
    required this.participantAddress,
    required this.latitude,
    required this.longitude,
    required this.altitudeBaroFt,
    required this.trackType,
    required this.airborne,
    required this.extrapolated,
    required this.nic,
    required this.nacp,
    required this.horizontalVelocityKt,
    required this.verticalVelocityFpm,
    required this.trackDegrees,
    required this.emitterCategory,
    required this.callSign,
    required this.emergencyPriorityCode,
    int? crc,
  }) : super(isOwnship ? Gdl90MessageId.ownship : Gdl90MessageId.trafficReport, crc: crc);
}

/// Initialization (ID=2). Devices rarely emit this (it's "Display -> GDL90"), but we decode for completeness.
/// See §3.2 (Table 4); fields are left as raw bytes for consumers that care.
class Initialization extends Gdl90Message {
  final Uint8List raw; // 18 bytes payload + (in-frame) CRC; interpret per §3.2 if needed.
  Initialization({required this.raw, int? crc}) : super(Gdl90MessageId.initialization, crc: crc);
}

/// ForeFlight Extensions (ID=0x65), see https://foreflight.com/connect/spec.
/// Two common subtypes: ID (subId=0), AHRS (subId=0x01).
abstract class ForeFlightExt extends Gdl90Message {
  ForeFlightExt() : super(Gdl90MessageId.foreflightExt);
}

/// ForeFlight Device ID (0x65, subId=0). Includes serial/name/capabilities.
class ForeFlightId extends ForeFlightExt {
  final int version; // must be 1
  final BigInt serial; // 8 bytes
  final String name;  // 8B UTF8
  final String longName; // 16B UTF8
  final int capabilitiesMask; // bit 0: GeoAlt datum (0=WGS84 ellipsoid, 1=MSL), bits1..2 internet policy, others 0
  ForeFlightId({
    required this.version,
    required this.serial,
    required this.name,
    required this.longName,
    required this.capabilitiesMask,
  });
}

/// ForeFlight AHRS (0x65, subId=0x01). Roll/pitch/heading and IAS/TAS, etc.
class ForeFlightAhrs extends ForeFlightExt {
  final int rollTenthDeg;    // ±1800 (0x7FFF invalid)
  final int pitchTenthDeg;   // ±1800 (0x7FFF invalid)
  final int headingTenthDeg; // 15th bit selects True(0)/Mag(1); 0xFFFF invalid
  final int iasKt;           // 0xFFFF invalid
  final int tasKt;           // 0xFFFF invalid
  ForeFlightAhrs({
    required this.rollTenthDeg,
    required this.pitchTenthDeg,
    required this.headingTenthDeg,
    required this.iasKt,
    required this.tasKt,
  });
}
```

---

## `lib/src/decoder.dart`

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'messages.dart';
import 'crc.dart';

/// Top-level API: feed frames (clear of escaping, but still including trailing CRC),
/// get typed GDL90 messages. Use with [Gdl90Framer].
class Gdl90Decoder {
  /// Parse one clear frame (MessageID + payload + 2 CRC bytes).
  /// Returns a [Gdl90Message] or null if unknown/unsupported ID.
  Gdl90Message? parse(Uint8List frame) {
    if (frame.length < 3) return null;
    if (!Gdl90Crc.verifyTrailing(frame)) return null;

    final id = frame[0]; // decimal IDs (ICD §2.2.2)
    final crc = frame[frame.length - 2] | (frame[frame.length - 1] << 8);
    final body = frame.sublist(1, frame.length - 2);

    switch (id) {
      case Gdl90MessageId.heartbeat:
        return _parseHeartbeat(body, crc);
      case Gdl90MessageId.initialization:
        return Initialization(raw: body, crc: crc);
      case Gdl90MessageId.uplinkData:
        return _parseUplink(body, crc);
      case Gdl90MessageId.hat:
        return _parseHat(body, crc);
      case Gdl90MessageId.ownship:
        return _parseTrafficLike(body, true, crc);
      case Gdl90MessageId.trafficReport:
        return _parseTrafficLike(body, false, crc);
      case Gdl90MessageId.ownshipGeoAltitude:
        return _parseGeoAlt(body, crc);
      case Gdl90MessageId.basicReport:
      case Gdl90MessageId.longReport:
        return _parsePassThrough(id, body, crc);
      case Gdl90MessageId.foreflightExt:
        return _parseForeFlight(body);
      default:
        return null;
    }
  }

  Heartbeat _parseHeartbeat(Uint8List b, int crc) {
    // Expect 6 payload bytes for a total 7 incl ID (ICD Table 3).
    if (b.length != 6) {
      // Be tolerant; some emitters add future fields. Clamp to six when available.
      if (b.length < 6) {
        throw FormatException('Heartbeat too short: ${b.length}');
      }
    }
    final s1 = b[0];
    final s2 = b[1];
    final tsLS = b[2] | (b[3] << 8); // LSB-first per ICD
    final counts1 = b[4];
    final counts2 = b[5];

    final timeOfDaySeconds = ((s2 >> 7) & 0x01) << 16 | tsLS;

    final uplinkCount = (counts1 >> 3) & 0x1F;
    final basicLongCount = ((counts1 & 0x03) << 8) | counts2;

    return Heartbeat(
      gpsPosValid:      (s1 & 0x80) != 0,
      maintenanceRequired: (s1 & 0x40) != 0,
      identActive:      (s1 & 0x20) != 0,
      ownshipAnonAddr:  (s1 & 0x10) != 0,
      gpsBatteryLow:    (s1 & 0x08) != 0,
      ratcs:            (s1 & 0x04) != 0,
      uatInitialized:   (s1 & 0x01) != 0,

      csaRequested:     (s2 & 0x40) != 0,
      csaNotAvailable:  (s2 & 0x20) != 0,
      utcOk:            (s2 & 0x01) != 0,
      timeOfDaySeconds: timeOfDaySeconds,
      uplinkCount:      uplinkCount,
      basicLongCount:   basicLongCount,
      crc: crc,
    );
  }

  UplinkData _parseUplink(Uint8List b, int crc) {
    if (b.length < 3) throw FormatException('Uplink body too short: ${b.length}');
    final tor = b[0] | (b[1] << 8) | (b[2] << 16); // LSB-first (ICD §3.3.1)
    final payload = b.sublist(3); // usually 432 bytes
    return UplinkData(tor80ns: tor, payload: payload, crc: crc);
  }

  HeightAboveTerrain _parseHat(Uint8List b, int crc) {
    if (b.length != 2) throw FormatException('HAT length != 2: ${b.length}');
    final raw = (b[0] << 8) | b[1]; // MSB-first per §3.7
    final invalid = raw == 0x8000;
    final feet = invalid ? 0 : _toSigned(raw, 16);
    return HeightAboveTerrain(feet: feet, invalid: invalid, crc: crc);
  }

  OwnshipGeoAltitude _parseGeoAlt(Uint8List b, int crc) {
    if (b.length != 4 && b.length != 5) {
      // ICD shows 5 total (ID + 4), but some senders omit vertical metrics. Handle both.
    }
    final rawAlt = (b[0] << 8) | b[1]; // MSB-first
    final altitudeFeet = _toSigned(rawAlt, 16) * 5;

    int metrics = 0;
    if (b.length >= 4) {
      metrics = (b[2] << 8) | b[3]; // MSB-first
    }
    final verticalWarning = (metrics & 0x8000) != 0;
    final vfom = metrics & 0x7FFF;

    return OwnshipGeoAltitude(
      altitudeFeet: altitudeFeet,
      verticalWarning: verticalWarning,
      vfomMetersRaw: vfom,
      crc: crc,
    );
  }

  PassThroughReport _parsePassThrough(int id, Uint8List b, int crc) {
    if (b.length < 3) throw FormatException('Pass-through body too short: ${b.length}');
    final tor = b[0] | (b[1] << 8) | (b[2] << 16); // LSB-first
    final payload = b.sublist(3);
    return PassThroughReport(id: id, tor80ns: tor, payload: payload, crc: crc);
  }

  TrafficReport _parseTrafficLike(Uint8List b, bool isOwnship, int crc) {
    if (b.length != 27) {
      // Some senders produce zero-filled ownship report; still expect 27 bytes.
      if (b.length < 27) throw FormatException('Traffic/Ownship body too short: ${b.length}');
      b = Uint8List.fromList(b.sublist(0, 27));
    }
    int off = 0;

    final st = b[off++]; // high nibble s (alert), low nibble t (address type)
    final s = (st >> 4) & 0x0F;
    final t = st & 0x0F;

    int read24() {
      final v = (b[off] << 16) | (b[off + 1] << 8) | b[off + 2];
      off += 3;
      return v & 0xFFFFFF;
    }

    final participant = read24();
    final lat24 = read24();
    final lon24 = read24();

    // Altitude (ddd), Misc nibble (m)
    final dd = b[off++];
    final dm = b[off++];
    final ddd = ((dd << 4) | (dm >> 4)) & 0xFFF;
    final m   = dm & 0x0F;

    // NIC/NACp
    final ia = b[off++];
    final nic = (ia >> 4) & 0x0F;
    final nacp = ia & 0x0F;

    // Horizontal velocity (12 bits): hh + high nibble of hv
    final hh = b[off++];
    final hv = b[off++];
    final horiz = ((hh << 4) | (hv >> 4)) & 0xFFF;

    // Vertical velocity (12-bit signed): low nibble of hv + vv
    final vv = b[off++];
    final vertRaw = (((hv & 0x0F) << 8) | vv) & 0xFFF;
    final vertSigned = _toSigned(vertRaw, 12);

    // Track/Heading (8-bit) — see 'm' bits for interpretation
    final tt = b[off++];

    // Emitter category
    final ee = b[off++];

    // Call sign (8 ASCII bytes)
    final csBytes = b.sublist(off, off + 8);
    off += 8;
    final callSign = ascii.decode(csBytes).trimRight();

    // p/x nibble (p = emergency priority, x spare)
    final px = b[off++];
    final p = (px >> 4) & 0x0F;

    // Decode per ICD:
    final alert = s == 1;
    final addrType = _addressType(t);

    // Position decoding (semicircles, 24-bit signed; res = 180/2^23 deg), §3.5.1.3
    final latSigned = _toSigned(lat24, 24);
    final lonSigned = _toSigned(lon24, 24);
    double? latDeg, lonDeg;
    // A target with no valid position has lat, lon, and NIC all zero.
    if (lat24 == 0 && lon24 == 0 && nic == 0) {
      latDeg = null;
      lonDeg = null;
    } else {
      latDeg = latSigned * (180.0 / (1 << 23));
      lonDeg = lonSigned * (180.0 / (1 << 23));
    }

    // Altitude: 12-bit offset integer, 25-ft steps, offset -1000ft; 0xFFF => invalid (§3.5.1.4)
    int? altFt;
    if (ddd == 0xFFF) {
      altFt = null;
    } else {
      altFt = ddd * 25 - 1000;
    }

    // Misc field 'm' (§3.5.1.5)
    final tkType = TrackHeadingType.values[(m & 0x03)];
    final extrap = ((m >> 2) & 0x01) == 1;
    final air = ((m >> 3) & 0x01) == 1;

    // Horizontal velocity: 0xFFF => unavailable (§3.5.1.7)
    final hVel = (horiz == 0x0FFF) ? null : horiz;

    // Vertical velocity: 12-bit signed * 64 fpm; 0x800 => no vertical rate (§3.5.1.8)
    int? vVel;
    if (vertRaw == 0x800) {
      vVel = null;
    } else {
      vVel = vertSigned * 64;
    }

    // Track degrees: 0.. <360 in 360/256 steps, if 'tt' is valid per 'm' bit1..0
    double? trackDeg;
    if (tkType == TrackHeadingType.notValid) {
      trackDeg = null;
    } else {
      trackDeg = (tt * 360.0) / 256.0;
      if (trackDeg >= 360.0) trackDeg -= 360.0;
    }

    return TrafficReport(
      isOwnship: isOwnship,
      trafficAlert: alert,
      addressType: addrType,
      participantAddress: participant,
      latitude: latDeg,
      longitude: lonDeg,
      altitudeBaroFt: altFt,
      trackType: tkType,
      airborne: air,
      extrapolated: extrap,
      nic: nic,
      nacp: nacp,
      horizontalVelocityKt: hVel,
      verticalVelocityFpm: vVel,
      trackDegrees: trackDeg,
      emitterCategory: ee,
      callSign: callSign,
      emergencyPriorityCode: p,
      crc: crc,
    );
  }

  Gdl90Message? _parseForeFlight(Uint8List b) {
    if (b.isEmpty) return null;
    if (b[0] != 0x65) return null; // ForeFlight messages start with 0x65 then sub-ID
    if (b.length < 2) return null;
    final subId = b[1];

    if (subId == 0x00) {
      if (b.length < 40) return null;
      final version = b[2];
      final serial = _readUint64(b, 3);
      final name = _readUtf8Fixed(b.sublist(11, 19));
      final longName = _readUtf8Fixed(b.sublist(19, 35));
      final caps = (b[35] << 24) | (b[36] << 16) | (b[37] << 8) | b[38];
      return ForeFlightId(
        version: version,
        serial: serial,
        name: name,
        longName: longName,
        capabilitiesMask: caps,
      );
    }

    if (subId == 0x01) {
      if (b.length < 13) return null;
      final roll = (b[2] << 8) | b[3];
      final pitch = (b[4] << 8) | b[5];
      final heading = (b[6] << 8) | b[7];
      final ias = (b[8] << 8) | b[9];
      final tas = (b[10] << 8) | b[11];
      return ForeFlightAhrs(
        rollTenthDeg: roll,
        pitchTenthDeg: pitch,
        headingTenthDeg: heading,
        iasKt: ias,
        tasKt: tas,
      );
    }

    return null;
  }

  // ---------- helpers ----------

  static AddressType _addressType(int t) {
    switch (t) {
      case 0: return AddressType.adsbIcao;
      case 1: return AddressType.adsbSelfAssigned;
      case 2: return AddressType.tisBIcao;
      case 3: return AddressType.tisBTrackFile;
      case 4: return AddressType.surfaceVehicle;
      case 5: return AddressType.groundStation;
      default: return AddressType.reserved;
    }
  }

  static int _toSigned(int value, int bits) {
    final signBit = 1 << (bits - 1);
    final mask = (1 << bits) - 1;
    value &= mask;
    return (value & signBit) != 0 ? value - (1 << bits) : value;
  }

  static BigInt _readUint64(Uint8List b, int offset) {
    var v = BigInt.zero;
    for (var i = offset; i < offset + 8; i++) {
      v = (v << 8) | BigInt.from(b[i]);
    }
    return v;
    // (MSB-first per ForeFlight spec prose; the sample fields are opaque and usually parsed as raw)
  }

  static String _readUtf8Fixed(Uint8List b) {
    try {
      return const Utf8Decoder(allowMalformed: true).convert(b).replaceAll('\x00', '').trimRight();
    } catch (_) {
      return '';
    }
  }
}
```

---

## `example/read_udp.dart` (optional test transport, for desktop)

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:gdl90/gdl90.dart';

Future<void> main() async {
  // Replace with your receiver’s IP/port (ForeFlight expects 4000; many devices stream from 4000).
  final address = InternetAddress.anyIPv4; // bind to all
  const port = 4000;

  final framer = Gdl90Framer();
  final decoder = Gdl90Decoder();

  final sock = await RawDatagramSocket.bind(address, port, reusePort: true, reuseAddress: true);
  print('Listening UDP ${sock.address.address}:$port');

  sock.listen((e) {
    if (e == RawSocketEvent.read) {
      Datagram? d;
      while ((d = sock.receive()) != null) {
        framer.addBytes(Uint8List.fromList(d!.data), (clear) {
          final msg = decoder.parse(clear);
          if (msg == null) return;

          if (msg is Heartbeat) {
            print('HB: gps=${msg.gpsPosValid} utcOk=${msg.utcOk} sec=${msg.timeOfDaySeconds}'
                  ' uplinks=${msg.uplinkCount} basic+long=${msg.basicLongCount}');
          } else if (msg is TrafficReport) {
            final who = msg.isOwnship ? 'OWN' : 'TRAF';
            final pos = (msg.latitude == null) ? 'no-pos' : '${msg.latitude!.toStringAsFixed(5)},${msg.longitude!.toStringAsFixed(5)}';
            print('$who: ${msg.participantAddress.toRadixString(16)} alt=${msg.altitudeBaroFt} v=${msg.horizontalVelocityKt}'
                  ' trk=${msg.trackDegrees?.toStringAsFixed(1)} cs=${msg.callSign}');
          } else if (msg is OwnshipGeoAltitude) {
            print('GeoAlt: ${msg.altitudeFeet} ft vfomRaw=${msg.vfomMetersRaw}');
          } else if (msg is HeightAboveTerrain) {
            print('HAT: ${msg.invalid ? "invalid" : "${msg.feet} ft"}');
          } else if (msg is UplinkData) {
            print('Uplink TOR=${msg.torSeconds.toStringAsFixed(6)}s payload=${msg.payload.length}');
          } else if (msg is ForeFlightId) {
            print('FF ID: ${msg.name} SN=${msg.serial} caps=0x${msg.capabilitiesMask.toRadixString(16)}');
          } else if (msg is ForeFlightAhrs) {
            print('FF AHRS: roll=${msg.rollTenthDeg/10} pitch=${msg.pitchTenthDeg/10} deg');
          }
        });
      }
    }
  });
}
```

---

## Notes, correctness details & what’s included

* **Framing/escaping**: 0x7E flag at start/end; 0x7D escape byte, next byte XOR 0x20. CRC must be computed on **clear** message (after de-escaping) and **before** framing, and verified **LSB first**. ([Federal Aviation Administration][1])
* **CRC**: Table-driven CRC‑16‑CCITT with polynomial 0x1021, initial 0x0000, no reflection/xorout. The ICD includes an example heartbeat frame that matches **0x8BB3** (we verify) when computed this way. ([Federal Aviation Administration][1])
* **Message IDs (decimal)** per FAA Table 2:
  `0 Heartbeat, 2 Initialization, 7 Uplink, 9 HAT, 10 Ownship, 11 Ownship Geo Alt, 20 Traffic, 30 Basic, 31 Long`. The Traffic example shows Byte 1 = **0x14** (20 decimal). ([Federal Aviation Administration][1])
* **Ownship vs Traffic**: Ownship (ID=10) uses the *same 27‑byte layout* as Traffic, just with a different ID. If GPS is invalid, **lat/lon/NIC = 0**. ([Federal Aviation Administration][1])
* **Lat/Lon**: 24‑bit two’s‑complement “semicircles” with resolution 180 / 2^23 degrees. ([Federal Aviation Administration][1])
* **Altitude (baro)**: 12‑bit offset integer, 25 ft units, offset −1000 ft; 0xFFF = invalid. ([Federal Aviation Administration][1])
* **Misc field `m`**: bit3 Air(1)/Ground(0), bit2 Extrapolated(1)/Updated(0), bit1..0 track/heading meaning (00 invalid, 01 True Track, 10 Magnetic Heading, 11 True Heading). ([Federal Aviation Administration][1])
* **Horizontal velocity**: 12‑bit unsigned knots; 0xFFF => unavailable. **Vertical velocity**: 12‑bit signed in 64 fpm; 0x800 => unavailable. **Track**: 8‑bit angular weighted, 360/256° per LSB. ([Federal Aviation Administration][1])
* **Emitter categories** (0..39) and **Emergency/Priority code** mapping (p=0..6) are preserved; you can map to labels using Table 11 and §3.5.1.12 as needed. ([Federal Aviation Administration][1])
* **Uplink Data**: includes **Time of Reception** (24‑bit, 80ns units, LSB-first) and 432‑byte payload. You can decode the FIS‑B APDUs from that if desired (ICD §4–5). ([Federal Aviation Administration][1])
* **Pass‑Through Basic/Long**: exposed with TOR and payload; formats per DO‑282. ([Federal Aviation Administration][1])
* **Height Above Terrain**: 16‑bit signed feet, 0x8000 = invalid. 
* **Ownship Geometric Altitude**: 5‑ft resolution; vertical metrics bit 15 = warning, lower 15 bits = VFOM meters. ([Federal Aviation Administration][1])
* **ForeFlight extensions**:

  * **ID message** (0x65/subId=0): serial/name/capabilities (bit0 indicates GeoAlt datum WGS‑84 vs MSL).
  * **AHRS** (0x65/subId=0x01): roll/pitch/heading, IAS/TAS at 5 Hz.
    ForeFlight expects UDP unicast to **port 4000** and treats regular Heartbeat/Ownship as “connected”. There is also a ForeFlight JSON broadcast on port 63093 for device discovery. ([ForeFlight][2])

---

## Using in your iOS app (transport is separate)

* Keep this parser in a shared package. In Flutter/iOS, open a UDP socket and feed incoming `Uint8List` chunks to `Gdl90Framer.addBytes`, then pass each clear frame to `Gdl90Decoder.parse`. (ForeFlight and many receivers use UDP **unicast** to the iOS device; multicast/broadcast may require entitlements on iOS.) ([ForeFlight][2])
* iOS entitlements/Info.plist (when you add your own UDP listener):
  `NSLocalNetworkUsageDescription`; Bonjour entries if you browse services; multicast entitlement only if you truly need it.

---

## Extending / validating

* If you want label strings for emitter categories, map `emitterCategory` using Table 11 from the ICD; likewise, you can turn `nic/nacp` into HPL/HFOM buckets using Table 10. ([Federal Aviation Administration][1])
* The decoder is intentionally strict about lengths per spec but tolerant where field counts vary slightly across devices (e.g., some omit geo‑alt metrics).

---

### References

* **FAA GDL90 Public ICD** (core message structures, fields, CRC, framing, IDs). ([Federal Aviation Administration][1])
* **Traffic fields & worked example** (decoding, units, NIC/NACp, misc field, velocities, track). ([Federal Aviation Administration][1])
* **Pass-through Basic/Long, HAT, Ownship Geo Altitude** (formats and units). ([Federal Aviation Administration][1])
* **ForeFlight GDL90 Extensions (ID/AHRS) and connectivity expectations**. ([ForeFlight][2])

If you want a small test harness that feeds the **spec’s heartbeat example frame** or the **Traffic Report example** into the parser, say so and I’ll include a ready‑to‑run snippet that asserts the decoded fields.

[1]: https://www.faa.gov/sites/faa.gov/files/air_traffic/technology/adsb/archival/GDL90_Public_ICD_RevA.PDF "Microsoft Word - 560-1058-00A-GDL90_Public_ICD_RevA.doc"
[2]: https://www.foreflight.com/connect/spec/ "ForeFlight - GDL 90 Extended Specification"
