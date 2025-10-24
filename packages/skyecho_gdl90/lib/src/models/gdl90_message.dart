import 'dart:typed_data';

/// GDL90 message types mapped to standard message IDs.
///
/// Maps to message IDs per FAA GDL90 Public ICD:
/// - 0x00: Heartbeat
/// - 0x02: Initialization
/// - 0x07: Uplink Data
/// - 0x09: Height Above Terrain (HAT)
/// - 0x0A: Ownship Report
/// - 0x0B: Ownship Geometric Altitude
/// - 0x14: Traffic Report
/// - 0x1E: Basic Report
/// - 0x1F: Long Report
/// - 0x65: ForeFlight Extension (ID and AHRS sub-messages)
enum Gdl90MessageType {
  heartbeat,
  initialization,
  uplinkData,
  hat,
  ownship,
  ownshipGeoAltitude,
  traffic,
  basicReport,
  longReport,
  foreFlightId,
  foreFlightAhrs,
}

/// Single unified message model containing all GDL90 message types.
///
/// Per Critical Discovery 04: Uses nullable fields to support all message
/// types in one class. Only [messageType] and [messageId] are required;
/// all other fields are populated selectively based on message type.
///
/// **Memory Characteristics** (Insight #2): This class contains ~40 nullable
/// fields to support all message types. Each instance allocates ~350-400 bytes
/// regardless of which fields are populated. At 1,000 messages/second, expect
/// ~350 KB/sec allocation rate. Dart's generational GC handles this efficiently
/// on modern hardware, but monitor memory pressure in production if sustaining
/// high message rates over extended flights.
///
/// Example usage:
/// ```dart
/// // Heartbeat message - only heartbeat fields populated
/// final heartbeat = Gdl90Message(
///   messageType: Gdl90MessageType.heartbeat,
///   messageId: 0x00,
///   gpsPosValid: true,
///   utcOk: true,
/// );
///
/// // Traffic message - only traffic fields populated
/// final traffic = Gdl90Message(
///   messageType: Gdl90MessageType.traffic,
///   messageId: 0x14,
///   latitude: 37.5,
///   longitude: -122.3,
///   callsign: 'N12345',
/// );
/// ```
class Gdl90Message {
  /// Message type (required)
  final Gdl90MessageType messageType;

  /// Raw message ID byte from frame (required)
  final int messageId;

  // Heartbeat fields (ID 0x00)
  /// Status byte 1, bit 7: GPS position is valid
  final bool? gpsPosValid;

  /// Status byte 1, bit 6: Maintenance required
  final bool? maintRequired;

  /// Status byte 1, bit 5: Ident switch active
  final bool? identActive;

  /// Status byte 1, bit 4: Address type talkback (ownship anonymous address)
  final bool? ownshipAnonAddr;

  /// Status byte 1, bit 3: GPS battery low
  final bool? batteryLow;

  /// Status byte 1, bit 2: RATCS (ATC Services talkback)
  final bool? ratcs;

  /// Status byte 1, bit 0: UAT initialized
  final bool? uatInitialized;

  /// Status byte 2, bit 6: CSA requested
  final bool? csaRequested;

  /// Status byte 2, bit 5: CSA not available
  final bool? csaNotAvailable;

  /// Status byte 2, bit 0: UTC timing is valid
  final bool? utcOk;

  /// 17-bit time of day in seconds since 0000Z
  final int? timeOfDaySeconds;

  /// 5-bit uplink message count
  final int? messageCountUplink;

  /// 10-bit basic and long message count
  final int? messageCountBasicAndLong;

  // Traffic/Ownship fields (ID 0x14, 0x0A)
  final double? latitude;
  final double? longitude;
  final int? altitudeFeet;
  final int? horizontalVelocityKt;
  final int? verticalVelocityFpm;
  final int? trackDegrees;
  final String? callsign;
  final int? emitterCategory;
  final int? icaoAddress;
  final bool? airborne;
  final bool? trafficAlert;

  // HAT fields (ID 0x09)
  final int? heightAboveTerrainFeet;

  // Uplink fields (ID 0x07)
  /// 24-bit time of reception in 80ns units (LSB-first)
  ///
  /// Used by:
  /// - Uplink Data (ID 0x07)
  /// - Pass-Through Basic (ID 0x1E)
  /// - Pass-Through Long (ID 0x1F)
  ///
  /// ⚠️ Wraparound Warning: 24-bit counter wraps every 1.34 seconds.
  /// Use wraparound-aware comparison for temporal ordering.
  final int? timeOfReception80ns;

  /// Variable-length UAT uplink payload (typically 432 bytes, max 1024 bytes)
  ///
  /// Raw FIS-B weather data bytes. Decoding deferred to future enhancement.
  final Uint8List? uplinkPayload;

  // Ownship Geometric Altitude fields (ID 0x0B)
  /// Geometric altitude in feet with 5-ft resolution
  final int? geoAltitudeFeet;

  /// Vertical warning flag from vertical metrics field (bit 15)
  final bool? verticalWarning;

  /// Vertical Figure of Merit in meters (raw value with special cases)
  ///
  /// Special values:
  /// - 0x7FFF (32767): Not available
  /// - 0x7EEE (32494): Exceeds 32766 meters
  ///
  /// Use computed property `vfomMeters` for null-safe access.
  final int? vfomMetersRaw;

  // Pass-Through fields (ID 0x1E, 0x1F)
  /// UAT basic report payload (typically 18 bytes)
  final Uint8List? basicReportPayload;

  /// UAT long report payload (typically 34 bytes)
  final Uint8List? longReportPayload;

  // Initialization fields (ID 0x02)
  final int? audioInhibit;
  final int? audioTest;

  // ForeFlight Extension fields (ID 0x65)
  /// ForeFlight sub-message ID (0x00 = ID message, 0x01 = AHRS message)
  final int? foreFlightSubId;

  /// ForeFlight protocol version (typically 0x01)
  final int? foreFlightVersion;

  /// Device serial number (64-bit big-endian)
  final int? serialNumber;

  /// Device name (8-byte UTF-8 string, typically null-padded)
  final String? deviceName;

  /// Device long name (16-byte UTF-8 string, typically null-padded)
  final String? deviceLongName;

  /// Capabilities bitmask (32-bit big-endian)
  ///
  /// Known capability flags:
  /// - Bit 0 (0x01): AHRS capable
  /// - Bit 1 (0x02): GPS capable
  /// - Bit 2 (0x04): Pressure altitude capable
  final int? capabilitiesMask;

  // ForeFlight AHRS fields (sub-ID 0x01) - not currently sent by SkyEcho
  /// Roll angle in degrees (positive = right wing down)
  final double? roll;

  /// Pitch angle in degrees (positive = nose up)
  final double? pitch;

  /// True heading in degrees (0-359)
  final double? heading;

  /// Slip/skid indicator in g-force (positive = right slip)
  final double? slipSkid;

  Gdl90Message({
    required this.messageType,
    required this.messageId,
    // Heartbeat
    this.gpsPosValid,
    this.maintRequired,
    this.identActive,
    this.ownshipAnonAddr,
    this.batteryLow,
    this.ratcs,
    this.uatInitialized,
    this.csaRequested,
    this.csaNotAvailable,
    this.utcOk,
    this.timeOfDaySeconds,
    this.messageCountUplink,
    this.messageCountBasicAndLong,
    // Traffic/Ownship
    this.latitude,
    this.longitude,
    this.altitudeFeet,
    this.horizontalVelocityKt,
    this.verticalVelocityFpm,
    this.trackDegrees,
    this.callsign,
    this.emitterCategory,
    this.icaoAddress,
    this.airborne,
    this.trafficAlert,
    // HAT
    this.heightAboveTerrainFeet,
    // Uplink
    this.timeOfReception80ns,
    this.uplinkPayload,
    // Geo Altitude
    this.geoAltitudeFeet,
    this.verticalWarning,
    this.vfomMetersRaw,
    // Pass-Through
    this.basicReportPayload,
    this.longReportPayload,
    // Initialization
    this.audioInhibit,
    this.audioTest,
    // ForeFlight Extension
    this.foreFlightSubId,
    this.foreFlightVersion,
    this.serialNumber,
    this.deviceName,
    this.deviceLongName,
    this.capabilitiesMask,
    // ForeFlight AHRS
    this.roll,
    this.pitch,
    this.heading,
    this.slipSkid,
  });

  /// Computed property: Time of reception in seconds
  ///
  /// Converts 80ns units to seconds for convenience.
  /// Returns null if [timeOfReception80ns] is null.
  double? get timeOfReceptionSeconds {
    if (timeOfReception80ns == null) return null;
    return timeOfReception80ns! / 12500000.0; // 1 second = 12.5M * 80ns
  }

  /// Computed property: VFOM in meters with null for special values
  ///
  /// Returns:
  /// - null if [vfomMetersRaw] is 0x7FFF (not available) or 0x7EEE (exceeds max)
  /// - Actual meters value otherwise
  ///
  /// For specialists needing to distinguish "not available" from "exceeds max",
  /// use [vfomMetersRaw] directly.
  int? get vfomMeters {
    if (vfomMetersRaw == null) return null;
    if (vfomMetersRaw == 0x7FFF || vfomMetersRaw == 0x7EEE) return null;
    return vfomMetersRaw;
  }
}
