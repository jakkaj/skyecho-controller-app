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
  final Uint8List? uplinkPayload;

  // Initialization fields (ID 0x02)
  final int? audioInhibit;
  final int? audioTest;

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
    this.uplinkPayload,
    // Initialization
    this.audioInhibit,
    this.audioTest,
  });
}
