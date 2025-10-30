import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Immutable model representing ownship (own aircraft) state for UI consumption.
///
/// Separate from Gdl90Message domain model per Discovery 04 (layer boundaries).
/// All fields are nullable to handle cases where GPS doesn't have a fix.
class OwnshipState {
  /// Geographic position of own aircraft.
  final LatLng? position;

  /// Barometric altitude in feet MSL.
  final int? altitude;

  /// True heading in degrees (0-359).
  final int? heading;

  /// Vertical speed in feet per minute (positive = climbing, negative = descending).
  final int? verticalSpeed;

  const OwnshipState({
    this.position,
    this.altitude,
    this.heading,
    this.verticalSpeed,
  });

  /// Create from GDL90 ownship message.
  factory OwnshipState.fromGdl90Message(dynamic message) {
    LatLng? pos;
    final lat = message.latitude as double?;
    final lon = message.longitude as double?;
    // Only create position if we have valid GPS fix (not 0,0)
    // GDL90 devices send lat=0.0, lon=0.0 when no GPS fix
    if (lat != null && lon != null && (lat != 0.0 || lon != 0.0)) {
      pos = LatLng(lat, lon);
    }

    return OwnshipState(
      position: pos,
      altitude: message.altitudeFeet as int?,
      heading: message.trackDegrees as int?,
      verticalSpeed: message.verticalVelocityFpm as int?,
    );
  }

  /// Create ownship state from phone GPS location.
  ///
  /// Used as fallback when no GDL90 ownship reports received.
  /// Altitude and heading may be null if GPS doesn't provide them.
  factory OwnshipState.fromPhoneGPS({
    required double latitude,
    required double longitude,
    double? altitude,
    double? heading,
  }) {
    return OwnshipState(
      position: LatLng(latitude, longitude),
      altitude: altitude?.round(),
      heading: heading?.round(),
      verticalSpeed: null, // Phone GPS doesn't provide vertical speed
    );
  }

  /// Copy with updated fields.
  OwnshipState copyWith({
    LatLng? position,
    int? altitude,
    int? heading,
    int? verticalSpeed,
  }) {
    return OwnshipState(
      position: position ?? this.position,
      altitude: altitude ?? this.altitude,
      heading: heading ?? this.heading,
      verticalSpeed: verticalSpeed ?? this.verticalSpeed,
    );
  }

  @override
  String toString() =>
      'OwnshipState(pos: $position, alt: $altitude ft, hdg: $heading°)';
}
