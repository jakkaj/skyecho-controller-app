/// Aircraft profile model for storing callsign and ICAO hex pairs.
///
/// This immutable model represents a saved aircraft configuration that can be
/// quickly selected from a dropdown on the home screen. Profiles are persisted
/// to local device storage using JSON serialization.
///
/// Example:
/// ```dart
/// final profile = AircraftProfile(
///   id: 'uuid-123',
///   icaoHex: '7CC599',
///   callsign: 'VH-ABC',
///   createdAt: DateTime.now(),
///   updatedAt: DateTime.now(),
/// );
/// ```
class AircraftProfile {
  /// Unique identifier for this profile (UUID v4 format recommended).
  final String id;

  /// ICAO hex code in normalized format (uppercase, 6 digits, no 0x prefix).
  ///
  /// Example: "7CC599", "ABC123"
  final String icaoHex;

  /// Aircraft callsign or tail number.
  ///
  /// Example: "VH-ABC", "N12345"
  final String callsign;

  /// Timestamp when this profile was first created.
  final DateTime createdAt;

  /// Timestamp when this profile was last modified.
  final DateTime updatedAt;

  /// Creates a new aircraft profile with all required fields.
  const AircraftProfile({
    required this.id,
    required this.icaoHex,
    required this.callsign,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates an aircraft profile from a JSON map.
  ///
  /// Expects keys: 'id', 'icaoHex', 'callsign', 'createdAt', 'updatedAt'
  ///
  /// Timestamps should be in ISO 8601 format.
  ///
  /// Throws [FormatException] if timestamps are invalid.
  factory AircraftProfile.fromJson(Map<String, dynamic> json) {
    return AircraftProfile(
      id: json['id'] as String,
      icaoHex: json['icaoHex'] as String,
      callsign: json['callsign'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Converts this profile to a JSON map for serialization.
  ///
  /// Timestamps are converted to ISO 8601 format.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'icaoHex': icaoHex,
      'callsign': callsign,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Creates a copy of this profile with optional field overrides.
  ///
  /// Useful for updating profiles while maintaining immutability.
  ///
  /// Example:
  /// ```dart
  /// final updated = profile.copyWith(
  ///   callsign: 'NEW-CALLSIGN',
  ///   updatedAt: DateTime.now(),
  /// );
  /// ```
  AircraftProfile copyWith({
    String? id,
    String? icaoHex,
    String? callsign,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AircraftProfile(
      id: id ?? this.id,
      icaoHex: icaoHex ?? this.icaoHex,
      callsign: callsign ?? this.callsign,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AircraftProfile &&
        other.id == id &&
        other.icaoHex == icaoHex &&
        other.callsign == callsign &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      icaoHex,
      callsign,
      createdAt,
      updatedAt,
    );
  }

  @override
  String toString() {
    return 'AircraftProfile(id: $id, icaoHex: $icaoHex, callsign: $callsign)';
  }
}
