import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/aircraft_profile.dart';
import 'profile_repository_interface.dart';

/// Custom exception thrown when attempting to save a profile with a
/// duplicate hex.
///
/// Provides actionable hint to edit existing profile or use different hex.
class DuplicateHexError implements Exception {
  /// Error message describing the duplicate hex.
  final String message;

  /// Actionable hint for resolving the error.
  final String hint;

  /// Creates a duplicate hex error with message and hint.
  DuplicateHexError(this.message, this.hint);

  @override
  String toString() => '$message\n$hint';
}

/// Events emitted by the repository when profiles change.
abstract class ProfileEvent {
  /// The profile that was affected by the change.
  final AircraftProfile profile;

  /// Creates a profile event with the affected profile.
  ProfileEvent(this.profile);
}

/// Event emitted when a profile is saved (created or updated).
class ProfileSavedEvent extends ProfileEvent {
  /// Creates a profile saved event.
  ProfileSavedEvent(super.profile);
}

/// Event emitted when a profile is deleted.
class ProfileDeletedEvent extends ProfileEvent {
  /// Creates a profile deleted event.
  ProfileDeletedEvent(super.profile);
}

/// Concrete implementation of aircraft profile repository using
/// SharedPreferences.
///
/// This singleton repository manages persistent storage of aircraft profiles
/// in local device storage. Profiles are stored as a JSON list under the key
/// 'saved_aircraft_profiles'.
///
/// Features:
/// - Hex normalization for case-insensitive uniqueness
/// - Change notification via broadcast stream
/// - Last-used profile tracking
/// - Alphabetical sorting with last-used pinning for dropdown
///
/// Example:
/// ```dart
/// final repository = ProfileRepository.instance;
/// await repository.init();
///
/// // Save profile
/// await repository.save(profile);
///
/// // Listen to changes
/// repository.changes.listen((event) {
///   if (event is ProfileSavedEvent) {
///     print('Profile saved: ${event.profile.callsign}');
///   }
/// });
/// ```
class ProfileRepository implements ProfileRepositoryInterface {
  /// Singleton instance of the profile repository.
  static final ProfileRepository instance = ProfileRepository._();

  ProfileRepository._();

  static const String _profilesKey = 'saved_aircraft_profiles';
  static const String _lastUsedHexKey = 'last_used_profile_hex';

  SharedPreferences? _prefs;
  List<AircraftProfile> _cachedProfiles = [];

  final _changeController = StreamController<ProfileEvent>.broadcast();

  /// Stream of profile change events.
  ///
  /// Emits [ProfileSavedEvent] when a profile is saved.
  /// Emits [ProfileDeletedEvent] when a profile is deleted.
  Stream<ProfileEvent> get changes => _changeController.stream;

  @override
  Future<void> init() async {
    print('[PROFILES] Initializing ProfileRepository');
    _prefs = await SharedPreferences.getInstance();
    await _loadProfiles();
    print('[PROFILES] Loaded ${_cachedProfiles.length} profiles from storage');
  }

  Future<void> _loadProfiles() async {
    final jsonString = _prefs?.getString(_profilesKey);
    if (jsonString == null || jsonString.isEmpty) {
      _cachedProfiles = [];
      return;
    }

    try {
      final jsonList = json.decode(jsonString) as List<dynamic>;
      _cachedProfiles = jsonList
          .map((item) =>
              AircraftProfile.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('[PROFILES] Error loading profiles: $e');
      _cachedProfiles = [];
    }
  }

  Future<void> _saveProfiles() async {
    final jsonList = _cachedProfiles.map((p) => p.toJson()).toList();
    final jsonString = json.encode(jsonList);
    await _prefs?.setString(_profilesKey, jsonString);
  }

  /// Normalizes ICAO hex code to standard format.
  ///
  /// Steps:
  /// 1. Trim whitespace
  /// 2. Convert to uppercase
  /// 3. Strip '0x' or '0X' prefix if present
  /// 4. Parse as hexadecimal integer
  /// 5. Convert back to hex string
  /// 6. Pad to 6 digits with leading zeros
  ///
  /// Examples:
  /// - '0x7cc599' → '7CC599'
  /// - '7cc599' → '7CC599'
  /// - 'ABC123' → 'ABC123'
  /// - '0XABC' → '000ABC'
  ///
  /// Throws [ArgumentError] if hex is empty.
  /// Throws [FormatException] if hex is not valid hexadecimal.
  String _normalizeHex(String hex) {
    if (hex.trim().isEmpty) {
      throw ArgumentError('Hex code cannot be empty');
    }

    String cleaned = hex.trim().toUpperCase();
    if (cleaned.startsWith('0X')) {
      cleaned = cleaned.substring(2);
    }

    // Parse as hex and convert back to ensure valid hex format
    final intValue = int.parse(cleaned, radix: 16);
    return intValue.toRadixString(16).toUpperCase().padLeft(6, '0');
  }

  @override
  Future<List<AircraftProfile>> getAll() async {
    // Return alphabetically sorted by callsign
    final sorted = List<AircraftProfile>.from(_cachedProfiles);
    sorted.sort((a, b) => a.callsign.compareTo(b.callsign));
    return sorted;
  }

  /// Returns profiles sorted for dropdown display.
  ///
  /// The last-used profile (by hex) is pinned to the top,
  /// with remaining profiles sorted alphabetically by callsign.
  ///
  /// Example:
  /// - Last used: "VH-ABC (7CC599)" [pinned to top]
  /// - "N12345 (ABC123)" [alphabetical]
  /// - "VH-XYZ (DEF456)" [alphabetical]
  Future<List<AircraftProfile>> getForDropdown() async {
    final lastUsedHex = await getLastUsedHex();
    if (lastUsedHex == null) {
      return getAll(); // No last-used, just alphabetical
    }

    final normalizedLastUsed = _normalizeHex(lastUsedHex);
    final sorted = List<AircraftProfile>.from(_cachedProfiles);

    sorted.sort((a, b) {
      // Pin last-used to top
      if (a.icaoHex == normalizedLastUsed) return -1;
      if (b.icaoHex == normalizedLastUsed) return 1;

      // Rest alphabetical by callsign
      return a.callsign.compareTo(b.callsign);
    });

    return sorted;
  }

  @override
  Future<void> save(AircraftProfile profile) async {
    print('[PROFILES] Saving profile: ${profile.callsign} (${profile.icaoHex})');

    // Normalize hex
    final normalizedHex = _normalizeHex(profile.icaoHex);
    final normalizedProfile = profile.copyWith(icaoHex: normalizedHex);

    // Check for duplicate hex (excluding same profile by ID)
    final existingWithHex = _cachedProfiles
        .where(
            (p) => p.icaoHex == normalizedHex && p.id != normalizedProfile.id)
        .toList();

    if (existingWithHex.isNotEmpty) {
      final existing = existingWithHex.first;
      throw DuplicateHexError(
        'Aircraft with hex $normalizedHex already exists '
            '(${existing.callsign})',
        'Edit the existing profile or use a different hex code.',
      );
    }

    // Update or add
    final index =
        _cachedProfiles.indexWhere((p) => p.id == normalizedProfile.id);
    if (index >= 0) {
      _cachedProfiles[index] = normalizedProfile;
    } else {
      _cachedProfiles.add(normalizedProfile);
    }

    await _saveProfiles();
    _changeController.add(ProfileSavedEvent(normalizedProfile));
    print('[PROFILES] Profile saved successfully');
  }

  @override
  Future<void> delete(String id) async {
    print('[PROFILES] Deleting profile: $id');

    final profile = _cachedProfiles.firstWhere(
      (p) => p.id == id,
      orElse: () => throw ArgumentError('Profile not found: $id'),
    );

    _cachedProfiles.removeWhere((p) => p.id == id);
    await _saveProfiles();
    _changeController.add(ProfileDeletedEvent(profile));
    print('[PROFILES] Profile deleted successfully');
  }

  @override
  Future<AircraftProfile?> getByHex(String hex) async {
    final normalizedHex = _normalizeHex(hex);
    try {
      return _cachedProfiles.firstWhere((p) => p.icaoHex == normalizedHex);
    } catch (e) {
      return null;
    }
  }

  /// Stores the last-used profile hex to SharedPreferences.
  ///
  /// Used for fallback when device is offline and for pinning in dropdown.
  Future<void> setLastUsed(String hex) async {
    final normalizedHex = _normalizeHex(hex);
    await _prefs?.setString(_lastUsedHexKey, normalizedHex);
    print('[PROFILES] Last used hex set to: $normalizedHex');
  }

  /// Retrieves the last-used profile hex from SharedPreferences.
  ///
  /// Returns null if no last-used hex is stored.
  Future<String?> getLastUsedHex() async {
    return _prefs?.getString(_lastUsedHexKey);
  }

  /// Disposes the repository and closes the change stream.
  ///
  /// Call this when the repository is no longer needed.
  void dispose() {
    _changeController.close();
  }
}
