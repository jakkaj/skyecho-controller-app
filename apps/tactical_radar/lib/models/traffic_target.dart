import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Immutable model representing a traffic target for UI consumption.
///
/// Separate from Gdl90Message domain model per Discovery 04 (layer boundaries).
/// Includes calculated relativeAltitude string for display.
class TrafficTarget {
  /// ICAO 24-bit address (unique aircraft identifier).
  final int icao;

  /// Geographic position of traffic aircraft.
  final LatLng position;

  /// Barometric altitude in feet MSL.
  final int altitude;

  /// Altitude differential relative to ownship (+/-XXXft or LEVEL).
  ///
  /// Format:
  /// - "+500ft" (500ft above ownship)
  /// - "-200ft" (200ft below ownship)
  /// - "LEVEL" (same altitude as ownship)
  /// - "N/A" (ownship altitude unknown)
  final String relativeAltitude;

  /// Aircraft callsign (up to 8 characters, may be empty).
  final String callsign;

  /// True heading in degrees (0-359).
  final int heading;

  /// Whether aircraft is airborne (vs ground).
  final bool isAirborne;

  /// Timestamp when this target was last updated.
  final DateTime lastUpdate;

  const TrafficTarget({
    required this.icao,
    required this.position,
    required this.altitude,
    required this.relativeAltitude,
    required this.callsign,
    required this.heading,
    required this.isAirborne,
    required this.lastUpdate,
  });

  /// Create from GDL90 traffic message with ownship altitude for differential.
  factory TrafficTarget.fromGdl90Message({
    required dynamic message,
    int? ownshipAltitude,
  }) {
    final lat = message.latitude as double?;
    final lon = message.longitude as double?;

    if (lat == null || lon == null) {
      throw ArgumentError('Traffic message missing lat/lon');
    }

    final icao = message.icaoAddress as int?;
    if (icao == null) {
      throw ArgumentError('Traffic message missing ICAO address');
    }

    final trafficAlt = (message.altitudeFeet as int?) ?? 0;
    final relAlt = _calculateRelativeAltitude(trafficAlt, ownshipAltitude);

    return TrafficTarget(
      icao: icao,
      position: LatLng(lat, lon),
      altitude: trafficAlt,
      relativeAltitude: relAlt,
      callsign: (message.callsign as String?)?.trim() ?? 'N/A',
      heading: (message.trackDegrees as int?) ?? 0,
      isAirborne: (message.airborne as bool?) ?? true,
      lastUpdate: DateTime.now(),
    );
  }

  /// Calculate relative altitude differential.
  ///
  /// Returns formatted string:
  /// - "+500ft" if traffic is 500ft above ownship
  /// - "-200ft" if traffic is 200ft below ownship
  /// - "LEVEL" if at same altitude
  /// - "N/A" if ownship altitude is unknown
  static String _calculateRelativeAltitude(int trafficAlt, int? ownAlt) {
    if (ownAlt == null) return 'N/A';

    final diff = trafficAlt - ownAlt;
    if (diff > 0) {
      return '+${diff}ft';
    } else if (diff < 0) {
      return '${diff}ft'; // Negative sign already present
    } else {
      return 'LEVEL';
    }
  }

  /// Get color coding based on altitude separation.
  ///
  /// Returns:
  /// - Red: <1000ft vertical separation (high collision risk)
  /// - Yellow: <5000ft vertical separation (moderate risk)
  /// - Green: ≥5000ft vertical separation (low risk)
  String getColorCode() {
    // Parse relative altitude to get absolute difference
    if (relativeAltitude == 'N/A' || relativeAltitude == 'LEVEL') {
      return 'red'; // Unknown or same altitude = high risk
    }

    // Extract numeric value from string (e.g., "+500ft" → 500)
    final numStr = relativeAltitude.replaceAll(RegExp(r'[^\d-]'), '');
    final absDiff = int.tryParse(numStr)?.abs() ?? 0;

    if (absDiff < 1000) {
      return 'red';
    } else if (absDiff < 5000) {
      return 'yellow';
    } else {
      return 'green';
    }
  }

  /// Copy with updated fields.
  TrafficTarget copyWith({
    int? icao,
    LatLng? position,
    int? altitude,
    String? relativeAltitude,
    String? callsign,
    int? heading,
    bool? isAirborne,
    DateTime? lastUpdate,
  }) {
    return TrafficTarget(
      icao: icao ?? this.icao,
      position: position ?? this.position,
      altitude: altitude ?? this.altitude,
      relativeAltitude: relativeAltitude ?? this.relativeAltitude,
      callsign: callsign ?? this.callsign,
      heading: heading ?? this.heading,
      isAirborne: isAirborne ?? this.isAirborne,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }

  @override
  String toString() =>
      'TrafficTarget($callsign @ $position, $relativeAltitude)';
}
