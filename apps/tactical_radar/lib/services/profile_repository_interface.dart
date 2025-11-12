import '../models/aircraft_profile.dart';

/// Abstract interface for aircraft profile storage operations.
///
/// This interface defines the contract for managing saved aircraft profiles
/// in local device storage. Implementations should provide persistent storage
/// using appropriate platform APIs (e.g., SharedPreferences).
///
/// Following the service layer pattern used in this codebase (see
/// GdlServiceInterface), this interface enables test mocking with in-memory
/// implementations while the concrete implementation uses SharedPreferences.
///
/// Example usage:
/// ```dart
/// final repository = ProfileRepository(); // or mock implementation
/// await repository.init();
///
/// final profile = AircraftProfile(...);
/// await repository.save(profile);
///
/// final all = await repository.getAll();
/// ```
abstract class ProfileRepositoryInterface {
  /// Initializes the repository and loads existing profiles from storage.
  ///
  /// Must be called before any other operations.
  ///
  /// Throws [Exception] if storage initialization fails.
  Future<void> init();

  /// Retrieves all saved aircraft profiles.
  ///
  /// Returns an empty list if no profiles exist.
  ///
  /// Profiles are sorted alphabetically by callsign.
  Future<List<AircraftProfile>> getAll();

  /// Saves an aircraft profile to storage.
  ///
  /// If a profile with the same [id] exists, it will be updated.
  /// If the normalized hex already exists for a different profile,
  /// throws [DuplicateHexError].
  ///
  /// The hex value is normalized before storage (uppercase, 6 digits,
  /// no 0x prefix).
  ///
  /// Throws [DuplicateHexError] if hex already exists.
  /// Throws [ArgumentError] if validation fails.
  Future<void> save(AircraftProfile profile);

  /// Deletes a profile by its unique ID.
  ///
  /// Does nothing if the profile doesn't exist.
  Future<void> delete(String id);

  /// Retrieves a profile by its ICAO hex code.
  ///
  /// The hex parameter is normalized before lookup (case-insensitive).
  ///
  /// Returns null if no profile with the given hex exists.
  ///
  /// Example:
  /// ```dart
  /// final profile = await repository.getByHex('7cc599'); // case-insensitive
  /// final profile2 = await repository.getByHex('0x7CC599'); // strips 0x prefix
  /// ```
  Future<AircraftProfile?> getByHex(String hex);
}
