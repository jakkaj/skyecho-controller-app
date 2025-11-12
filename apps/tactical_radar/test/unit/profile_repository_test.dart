import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tactical_radar/models/aircraft_profile.dart';
import 'package:tactical_radar/services/profile_repository.dart';

void main() {
  late ProfileRepository repository;

  setUp(() async {
    // Use real SharedPreferences with test values for isolation
    SharedPreferences.setMockInitialValues({});
    repository = ProfileRepository.instance;
    await repository.init();
  });

  test(
      'given_new_profile_when_saving_then_retrieves_successfully_with_json_round_trip',
      () async {
    /*
    Test Doc:
    - Why: Validates core CRUD operation and JSON serialization (AC #1). Prevents
      catastrophic data loss if serialization breaks - ALL profiles would be lost
      on app restart.
    - Contract: Repository persists profiles with all fields intact across save
      and load cycles; fromJson and toJson maintain data integrity
    - Usage Notes: Call save() to persist; call getAll() to retrieve; profiles
      persist after app restart via SharedPreferences
    - Quality Contribution: Ensures JSON serialization works correctly; catches
      storage corruption issues early; documents persistence contract
    - Worked Example: save(Profile(hex='ABC123', callsign='VH-ABC', id='uuid-1',
      createdAt=T1, updatedAt=T2)) → getAll() returns [Profile(hex='ABC123',
      callsign='VH-ABC', id='uuid-1', createdAt=T1, updatedAt=T2)]
    */

    // Arrange
    final now = DateTime.now();
    final profile = AircraftProfile(
      id: 'test-uuid-123',
      icaoHex: '7CC599',
      callsign: 'VH-ABC',
      createdAt: now,
      updatedAt: now,
    );

    // Act
    await repository.save(profile);
    final profiles = await repository.getAll();

    // Assert - Verify all fields survive round-trip
    expect(profiles, hasLength(1));
    expect(profiles.first.id, 'test-uuid-123');
    expect(profiles.first.icaoHex, '7CC599');
    expect(profiles.first.callsign, 'VH-ABC');
    expect(
      profiles.first.createdAt.millisecondsSinceEpoch,
      now.millisecondsSinceEpoch,
    );
    expect(
      profiles.first.updatedAt.millisecondsSinceEpoch,
      now.millisecondsSinceEpoch,
    );

    // Test JSON serialization explicitly
    final json = profile.toJson();
    final fromJson = AircraftProfile.fromJson(json);
    expect(fromJson.id, profile.id);
    expect(fromJson.icaoHex, profile.icaoHex);
    expect(fromJson.callsign, profile.callsign);
    expect(
      fromJson.createdAt.millisecondsSinceEpoch,
      profile.createdAt.millisecondsSinceEpoch,
    );
    expect(
      fromJson.updatedAt.millisecondsSinceEpoch,
      profile.updatedAt.millisecondsSinceEpoch,
    );
  });

  test(
      'given_various_hex_formats_when_normalizing_then_returns_uppercase_6_digit',
      () async {
    /*
    Test Doc:
    - Why: Prevent duplicates via case/prefix variations (Discovery 05). If
      normalization breaks, users can create profiles with "7cc599" and "7CC599"
      (duplicates), breaking hex uniqueness constraint.
    - Contract: Hex normalization strips 0x/0X prefix, converts to uppercase,
      pads to 6 digits; uniqueness check is case-insensitive
    - Usage Notes: All hex inputs normalized before storage; getByHex() works
      case-insensitively; users can enter any format
    - Quality Contribution: Catches normalization bugs; prevents user confusion
      from apparent duplicates; validates business logic correctness
    - Worked Example: save(hex='0x7cc599') → stored as '7CC599'; save(hex='ABC')
      → stored as '000ABC'; getByHex('7cc599') finds profile with hex '7CC599'
    */

    // Arrange - Test cases mapping input to expected normalized output
    final testCases = [
      ('0x7cc599', '7CC599'), // Strip 0x prefix + uppercase
      ('7cc599', '7CC599'), // Uppercase only
      ('ABC123', 'ABC123'), // Already normalized
      ('0XABC', '000ABC'), // Strip 0X + uppercase + pad to 6 digits
      ('abc', '000ABC'), // Lowercase + pad
      ('0x1', '000001'), // Minimal hex with prefix
    ];

    for (final (input, expected) in testCases) {
      // Act - Save profile with input hex
      final profile = AircraftProfile(
        id: 'test-$input',
        icaoHex: input,
        callsign: 'TEST-$input',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.save(profile);

      // Act - Retrieve by same input (case-insensitive lookup)
      final saved = await repository.getByHex(input);

      // Assert - Verify normalized form matches expected
      expect(saved, isNotNull, reason: 'Failed to find profile for: $input');
      expect(saved!.icaoHex, expected,
          reason: 'Normalization failed for input: $input');

      // Cleanup for next iteration to avoid duplicates
      await repository.delete(saved.id);
    }
  });

  test(
      'given_existing_hex_when_saving_duplicate_then_throws_duplicate_error',
      () async {
    /*
    Test Doc:
    - Why: Enforce hex uniqueness constraint (AC #11)
    - Contract: Repository throws DuplicateHexError if hex already exists for
      a different profile; error includes actionable hint
    - Usage Notes: Check for existing hex before save OR catch DuplicateHexError
      for user feedback with SnackBar
    - Quality Contribution: Prevents duplicate profiles; documents error handling
      contract; validates uniqueness enforcement
    - Worked Example: save(Profile(hex='ABC123', id='1')) → success;
      save(Profile(hex='ABC123', id='2')) → throws DuplicateHexError with hint
    */

    // Arrange - Save first profile
    final profile1 = AircraftProfile(
      id: 'test-1',
      icaoHex: 'ABC123',
      callsign: 'VH-ABC',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await repository.save(profile1);

    // Arrange - Create duplicate with same hex but different ID
    final duplicate = AircraftProfile(
      id: 'test-2',
      icaoHex: 'ABC123', // Same hex (will be normalized to ABC123)
      callsign: 'VH-XYZ', // Different callsign
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Act & Assert - Verify duplicate throws error
    expect(
      () => repository.save(duplicate),
      throwsA(isA<DuplicateHexError>()),
    );

    // Additional assertion - Verify error message is actionable
    try {
      await repository.save(duplicate);
      fail('Expected DuplicateHexError to be thrown');
    } on DuplicateHexError catch (e) {
      expect(e.message, contains('ABC123'));
      expect(e.message, contains('VH-ABC')); // Existing profile callsign
      expect(e.hint, contains('Edit'));
      expect(e.hint, contains('different hex'));
    }
  });

  test(
      'given_case_insensitive_hex_when_checking_duplicates_then_detects_correctly',
      () async {
    /*
    Test Doc:
    - Why: Validate case-insensitive duplicate detection works correctly
    - Contract: Normalization ensures '7cc599' and '7CC599' are treated as same
      hex for uniqueness validation
    - Usage Notes: Users can enter hex in any case; system prevents duplicates
    - Quality Contribution: Catches case-sensitivity bugs in uniqueness logic
    - Worked Example: save(hex='7cc599') → success; save(hex='7CC599') → error
    */

    // Arrange - Save profile with lowercase hex
    final profile1 = AircraftProfile(
      id: 'test-lowercase',
      icaoHex: '7cc599', // lowercase
      callsign: 'VH-ABC',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await repository.save(profile1);

    // Act - Try to save with uppercase version
    final profile2 = AircraftProfile(
      id: 'test-uppercase',
      icaoHex: '7CC599', // UPPERCASE (same as above when normalized)
      callsign: 'VH-XYZ',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Assert - Should throw duplicate error
    expect(
      () => repository.save(profile2),
      throwsA(isA<DuplicateHexError>()),
    );
  });
}
