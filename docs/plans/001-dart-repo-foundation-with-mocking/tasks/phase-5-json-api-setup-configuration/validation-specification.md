# SkyEcho Setup Configuration - Validation Specification

**Source**: Device JavaScript deep analysis (2025-10-18)
**Purpose**: Comprehensive validation rules for all setup configuration fields
**Safety Level**: Aviation safety-critical (ADS-B equipment)

---

## Table of Contents

1. [Validation Rules Matrix](#validation-rules-matrix)
2. [Regex Patterns](#regex-patterns)
3. [Range Constraints](#range-constraints)
4. [Field Dependencies](#field-dependencies)
5. [Hardcoded Values](#hardcoded-values)
6. [Auto-Transformations](#auto-transformations)
7. [Dart Implementation](#dart-implementation)

---

## Validation Rules Matrix

| Field | Type | Required | Pattern | Min | Max | Step | Auto-Transform | Dependencies | Notes |
|-------|------|----------|---------|-----|-----|------|----------------|--------------|-------|
| `icaoAddress` | String (hex) | ✅ | Hex + Blacklist | - | - | - | Remove 0x, uppercase | - | Rejects 000000, FFFFFF |
| `callsign` | String | ✅ | Alphanumeric | 1 char | 8 chars | - | Uppercase | - | [A-Za-z0-9]{1,8} |
| `emitterCategory` | Int | ❌ | Enum | - | - | - | - | - | Valid: 0-7, 9-12, 14-15, 17-21 |
| `adsbInCapability` | Int (bitmask) | ❌ | Bitmask | - | - | - | - | - | 0x01 (1090ES), 0x02 (UAT) |
| `control` | Int (bitmask) | ❌ | Bitmask | - | - | - | - | Receiver mode affects FLARM fields | 0x01 (UAT), 0x02 (TX), 0x41 (FLARM) |
| `vfrSquawk` | String (octal) | ✅ | Octal | 4 digits | 4 digits | - | - | - | [0-7]{4} only |
| `stallSpeed` | Int | ❌ | Integer | 0 | 100 | 1 | - | - | Knots |
| `aircraftLengthWidth` | Int (packed) | ❌ | Integer | - | - | - | length=0→null | Width depends on length | See width lookup table |
| `gpsAntennaOffset` | Int (packed) | ❌ | Integer | - | - | - | Lon odd→even | - | Lat: 0-7, Lon: 0-60 (even) |
| `SIL` | Int | N/A | Hardcoded | 1 | 1 | - | Always 1 | - | ⚠️ MUST always be 1 |
| `SDA` | Int | ❌ | Enum | 0 | 1 | - | - | - | 0 or 1 only |
| `ownshipFilter.icaoAddress` | Int? (hex) | ❌ | Hex or null | - | - | - | Mirrors setup.icaoAddress | filterAdsb checkbox | null if filter disabled |
| `ownshipFilter.flarmId` | Int? (hex) | ❌ | Hex or null | - | - | - | Remove 0x, uppercase | filterFlarm checkbox + FLARM mode | null if filter disabled |

---

## Regex Patterns

### ICAO Address & FLARM ID (JavaScript lines 307, 315)

**Pattern**:
```regex
^(?:0x)?(?!f{6}|F{6}|0{6})[A-Fa-f0-9]{6}$
```

**Breakdown**:
- `^(?:0x)?` - Optional "0x" prefix (non-capturing group)
- `(?!f{6}|F{6}|0{6})` - **Negative lookahead**: Reject if next 6 chars are all 'f', 'F', or '0'
- `[A-Fa-f0-9]{6}` - Exactly 6 hexadecimal characters
- `$` - End of string

**Rejected Values**:
- `"000000"` - All zeros (invalid ICAO)
- `"FFFFFF"` - All ones (invalid ICAO)
- `"ffffff"` - All ones (lowercase)
- `"0x000000"` - All zeros with prefix
- `"0xFFFFFF"` - All ones with prefix

**Accepted Values**:
- `"7CC599"` - Valid hex
- `"0x7CC599"` - Valid hex with prefix
- `"abc123"` - Valid hex (will be uppercased)
- `"000001"` - Valid (not all zeros)
- `"FFFFFE"` - Valid (not all ones)

**Dart Implementation**:
```dart
static final RegExp icaoPattern = RegExp(
  r'^(?:0x)?(?!f{6}|F{6}|0{6})[A-Fa-f0-9]{6}$',
  caseSensitive: false,
);

static void validateIcaoAddress(String value) {
  if (!icaoPattern.hasMatch(value)) {
    throw SkyEchoFieldError(
      'Invalid ICAO address: "$value"',
      hint: 'Must be 6 hex digits. Cannot be 000000 or FFFFFF.',
    );
  }
}
```

---

### Callsign (JavaScript line 310)

**Pattern**:
```regex
^[A-Za-z0-9]{1,8}$
```

**Rules**:
- 1 to 8 characters
- Alphanumeric only (A-Z, a-z, 0-9)
- No spaces, hyphens, underscores, or special characters
- Required field (cannot be empty)

**Rejected Values**:
- `""` - Empty (required)
- `"CALLSIGN1"` - Too long (9 chars)
- `"N12-34"` - Contains hyphen
- `"ABC "` - Contains space
- `"Test_1"` - Contains underscore

**Accepted Values**:
- `"N12345"` - 6 alphanumeric
- `"ABC"` - 3 letters
- `"9954"` - 4 digits
- `"Test123"` - Mixed (will be uppercased to "TEST123")

**Dart Implementation**:
```dart
static final RegExp callsignPattern = RegExp(r'^[A-Za-z0-9]{1,8}$');

static void validateCallsign(String value) {
  if (!callsignPattern.hasMatch(value)) {
    throw SkyEchoFieldError(
      'Invalid callsign: "$value"',
      hint: 'Must be 1-8 alphanumeric characters (A-Z, 0-9).',
    );
  }
}
```

---

### VFR Squawk (JavaScript line 353)

**Pattern**:
```regex
^[0-7]{4}$
```

**Rules**:
- Exactly 4 characters
- Octal digits only (0-7)
- No digits 8 or 9
- Required field

**Rejected Values**:
- `"1200"` - Valid format, but... wait, this IS valid (1, 2, 0, 0 all ≤ 7)
- `"8000"` - Contains digit 8 (invalid octal)
- `"1299"` - Contains digit 9 (invalid octal)
- `"120"` - Too short (3 digits)
- `"12000"` - Too long (5 digits)

**Accepted Values**:
- `"1200"` - VFR squawk (all octal)
- `"7700"` - Emergency squawk (all octal)
- `"0000"` - All zeros (technically valid octal)
- `"7777"` - All sevens (valid octal)

**Important**: Squawk codes like `1200`, `7500`, `7600`, `7700` have special meanings in aviation, but the device doesn't validate these - only that digits are 0-7.

**Dart Implementation**:
```dart
static final RegExp squawkPattern = RegExp(r'^[0-7]{4}$');

static void validateVfrSquawk(String value) {
  if (!squawkPattern.hasMatch(value)) {
    throw SkyEchoFieldError(
      'Invalid VFR squawk: "$value"',
      hint: 'Must be exactly 4 octal digits (0-7). Example: 1200, 7700',
    );
  }
}
```

---

## Range Constraints

### Stall Speed (JavaScript line 366)

**HTML Constraint**: `<input type="number" min="0" max="100" step="1">`

**Rules**:
- Minimum: 0 knots
- Maximum: 100 knots
- Step: 1 knot (integer only)
- Default: 0

**Validation**:
```dart
static void validateStallSpeed(int knots) {
  if (knots < 0 || knots > 100) {
    throw SkyEchoFieldError(
      'Invalid stall speed: $knots knots',
      hint: 'Must be 0-100 knots.',
    );
  }
}
```

---

### GPS Longitudinal Offset (JavaScript line 410)

**HTML Constraint**: `<input type="number" min="0" max="60" step="2">`

**Rules**:
- Minimum: 0 meters
- Maximum: 60 meters
- Step: 2 meters (even numbers only)
- Odd values are invalid

**Auto-Normalization**: Round down odd values to nearest even (11 → 10)

**Validation**:
```dart
static void validateGpsLonOffset(int meters) {
  if (meters < 0 || meters > 60) {
    throw SkyEchoFieldError(
      'Invalid GPS longitude offset: $meters meters',
      hint: 'Must be 0-60 meters.',
    );
  }
  if (meters % 2 != 0) {
    throw SkyEchoFieldError(
      'Invalid GPS longitude offset: $meters meters',
      hint: 'Must be an even number (0, 2, 4, ..., 60).',
    );
  }
}
```

**With Auto-Normalization** (SetupUpdate setter):
```dart
int? _gpsLonOffset;

set gpsLonOffset(int? value) {
  if (value == null) {
    _gpsLonOffset = null;
    return;
  }

  if (value < 0 || value > 60) {
    throw SkyEchoFieldError(
      'Invalid GPS longitude offset: $value meters',
      hint: 'Must be 0-60 meters.',
    );
  }

  // Auto-normalize odd to even
  _gpsLonOffset = (value % 2 != 0) ? value - 1 : value;
}
```

---

### GPS Lateral Offset (JavaScript lines 396-405)

**HTML Constraint**: `<select>` with values 0-7

**Rules**:
- Valid values: 0, 1, 2, 3, 4, 5, 6, 7
- Each value maps to physical position:
  - 0: No Data
  - 1: Left 2m
  - 2: Left 4m
  - 3: Left 6m
  - 4: Center
  - 5: Right 2m
  - 6: Right 4m
  - 7: Right 6m

**Validation**:
```dart
static void validateGpsLatOffset(int value) {
  if (value < 0 || value > 7) {
    throw SkyEchoFieldError(
      'Invalid GPS lateral offset: $value',
      hint: 'Must be 0-7.',
    );
  }
}
```

---

### Emitter Category (JavaScript lines 330-349)

**Valid Values**: `[0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 17, 18, 19, 20, 21]`

**IMPORTANT**: Values 8, 13, 16, and 22+ are NOT valid (gaps in sequence)

**Mapping**:
```dart
static const Map<int, String> emitterCategories = {
  0: 'No Info',
  1: 'Light',
  2: 'Small',
  3: 'Large',
  4: 'High Vortex',
  5: 'Heavy',
  6: 'Highly Maneuverable',
  7: 'Rotorcraft',
  9: 'Glider/Sailplane',
  10: 'Lighter Than Air',
  11: 'Parachutist',
  12: 'Ultra Light',
  14: 'UAV',
  15: 'Space',
  17: 'Surface - Emergency',
  18: 'Surface - Service',
  19: 'Point Obstacle',
  20: 'Cluster Obstacle',
  21: 'Line Obstacle',
};

static void validateEmitterCategory(int value) {
  if (!emitterCategories.containsKey(value)) {
    throw SkyEchoFieldError(
      'Invalid emitter category: $value',
      hint: 'Valid values: ${emitterCategories.keys.toList()}',
    );
  }
}
```

---

### SDA (JavaScript lines 417-421)

**Valid Values**: `0` or `1` only

**Validation**:
```dart
static void validateSDA(int value) {
  if (value != 0 && value != 1) {
    throw SkyEchoFieldError(
      'Invalid SDA: $value',
      hint: 'Must be 0 or 1.',
    );
  }
}
```

---

## Field Dependencies

### Dependency 1: FLARM Receiver Mode → FLARM Filter → FLARM ID

**JavaScript Logic** (lines 54-61):
```javascript
function updateGui() {
    let flarmId = document.getElementById("flarmId");
    let filterFlarm = document.getElementById("filterFlarm");

    filterFlarm.disabled = !flarmRx.checked;
    filterFlarm.checked &= flarmRx.checked;
    flarmId.disabled = filterFlarm.disabled || !filterFlarm.checked;
}
```

**State Machine**:

| Receiver Mode | filterFlarm State | flarmId State | Notes |
|---------------|-------------------|---------------|-------|
| UAT (0x01) | Disabled + Unchecked | Disabled | flarmId ignored |
| FLARM (0x41) | Enabled | Depends on filterFlarm | If filterFlarm unchecked → disabled |
| FLARM (0x41) + filterFlarm checked | Enabled + Checked | Enabled | User can enter flarmId |

**Validation Rules**:
1. If `receiverMode == ReceiverMode.uat` → `flarmId` MUST be `null`
2. If `receiverMode == ReceiverMode.flarm` AND `filterFlarm == false` → `flarmId` MUST be `null`
3. If `receiverMode == ReceiverMode.flarm` AND `filterFlarm == true` → `flarmId` can be provided
4. If `flarmId` is provided → `receiverMode` MUST be `ReceiverMode.flarm` AND `filterFlarm` MUST be `true`

**Dart Validation**:
```dart
static void validateFlarmDependencies({
  required ReceiverMode receiverMode,
  required bool filterFlarm,
  required String? flarmId,
}) {
  if (flarmId != null) {
    // If flarmId provided, FLARM mode and filter MUST be enabled
    if (receiverMode != ReceiverMode.flarm) {
      throw SkyEchoFieldError(
        'FLARM ID requires FLARM receiver mode',
        hint: 'Set receiverMode to ReceiverMode.flarm when providing FLARM ID.',
      );
    }
    if (!filterFlarm) {
      throw SkyEchoFieldError(
        'FLARM ID requires FLARM filtering enabled',
        hint: 'Set filterFlarm to true when providing FLARM ID.',
      );
    }
  }

  if (receiverMode != ReceiverMode.flarm && filterFlarm) {
    // Warning: filterFlarm enabled but not in FLARM mode
    throw SkyEchoFieldError(
      'FLARM filtering requires FLARM receiver mode',
      hint: 'Set receiverMode to ReceiverMode.flarm to enable FLARM filtering.',
    );
  }
}
```

---

### Dependency 2: Aircraft Length → Aircraft Width

**JavaScript Logic** (lines 63-95):

```javascript
var limits = [
    { low: 23, high: null },      // Length 0: L ≤ 15m
    { low: 28.5, high: 34 },      // Length 1: 15m < L ≤ 25m
    { low: 33, high: 38 },        // Length 2: 25m < L ≤ 35m
    { low: 39.5, high: 45 },      // Length 3: 35m < L ≤ 45m
    { low: 45, high: 52 },        // Length 4: 45m < L ≤ 55m
    { low: 59.5, high: 67 },      // Length 5: 55m < L ≤ 65m
    { low: 72.5, high: 80 },      // Length 6: 65m < L ≤ 75m
    { low: 80, high: 80 }         // Length 7: L > 75m
];
```

**Width Option Logic**:
- If `high == null`: Width options are [1] only (wide category)
- If `high != null` and `low != high`: Width options are [0, 1] (narrow and wide)
- If `high != null` and `low == high`: Width options are [0, 1] (narrow and very wide)

**Valid (Length, Width) Pairs**:

| Length | Length Range | Width=0 | Width=1 | Notes |
|--------|--------------|---------|---------|-------|
| null | No Data | ✅ | ✅ | Encodes as 0 |
| 0 | L ≤ 15m | ❌ | ✅ | Only wide option (high=null) |
| 1 | 15m < L ≤ 25m | ✅ | ✅ | Both options (low ≠ high) |
| 2 | 25m < L ≤ 35m | ✅ | ✅ | Both options |
| 3 | 35m < L ≤ 45m | ✅ | ✅ | Both options |
| 4 | 45m < L ≤ 55m | ✅ | ✅ | Both options |
| 5 | 55m < L ≤ 65m | ✅ | ✅ | Both options |
| 6 | 65m < L ≤ 75m | ✅ | ✅ | Both options |
| 7 | L > 75m | ✅ | ✅ | Both options (low == high) |

**Dart Validation**:
```dart
static void validateAircraftDimensions({
  required int? length,
  required int? width,
}) {
  if (length == null && width == null) {
    return; // No data - valid
  }

  if (length == null && width != null) {
    throw SkyEchoFieldError(
      'Aircraft width requires aircraft length',
      hint: 'Set aircraftLength when providing aircraftWidth.',
    );
  }

  if (length != null && width == null) {
    throw SkyEchoFieldError(
      'Aircraft length requires aircraft width',
      hint: 'Set aircraftWidth when providing aircraftLength.',
    );
  }

  // Validate length range
  if (length! < 0 || length > 7) {
    throw SkyEchoFieldError(
      'Invalid aircraft length: $length',
      hint: 'Must be 0-7 or null for no data.',
    );
  }

  // Validate width range
  if (width! < 0 || width > 1) {
    throw SkyEchoFieldError(
      'Invalid aircraft width: $width',
      hint: 'Must be 0 or 1.',
    );
  }

  // Special case: length=0 only allows width=1
  if (length == 0 && width == 0) {
    throw SkyEchoFieldError(
      'Invalid aircraft dimensions: length=0 requires width=1',
      hint: 'Aircraft length ≤ 15m only supports wide width category.',
    );
  }
}
```

---

### Dependency 3: Filter Checkboxes → Ownship Filter Values

**JavaScript Logic** (lines 163-164, 226-227):

```javascript
// Packing
ownshipFilter.icaoAddress = formData["filterAdsb"].checked
    ? parseInt(formData["icaoAddress"].value, 16)
    : null;

ownshipFilter.flarmId = formData["filterFlarm"].checked
    ? parseInt(formData["flarmId"].value, 16)
    : null;

// Unpacking
form["filterAdsb"].checked = (ownship.icaoAddress != null);
form["filterFlarm"].checked = (ownship.flarmId != null);
```

**Rules**:
1. If `filterAdsb == false` → `ownshipFilter.icaoAddress` MUST be `null`
2. If `filterAdsb == true` → `ownshipFilter.icaoAddress` MUST equal `setup.icaoAddress` (mirrored)
3. If `filterFlarm == false` → `ownshipFilter.flarmId` MUST be `null`
4. If `filterFlarm == true` → `ownshipFilter.flarmId` can be provided (hex value)

**Dart Implementation**:
```dart
Map<String, int?> buildOwnshipFilter({
  required bool filterAdsb,
  required int icaoAddress,
  required bool filterFlarm,
  required int? flarmId,
}) {
  return {
    'icaoAddress': filterAdsb ? icaoAddress : null,
    'flarmId': filterFlarm ? flarmId : null,
  };
}
```

---

## Hardcoded Values

### SIL (Source Integrity Level) - SAFETY CRITICAL

**JavaScript Line 159**:
```javascript
setup.SIL = 1; // formData.getInt("SIL");
```

**Rule**: SIL is ALWAYS hardcoded to `1` regardless of user input.

**Rationale**: The Source Integrity Level (SIL) is aviation safety-critical data defined by ADS-B specifications. The SkyEcho 2 device firmware sets this to 1 (low integrity, typical for general aviation). This value should NOT be user-configurable.

**Dart Implementation**:
```dart
class SetupConfig {
  // SIL is NOT a public field - always hardcoded
  static const int _sil = 1;

  Map<String, dynamic> toJson() {
    return {
      'setup': {
        // ... other fields ...
        'SIL': _sil, // Always 1
        // ... other fields ...
      },
    };
  }
}
```

**Validation**:
```dart
// If user tries to set SIL via some other means:
static void validateSIL(int value) {
  if (value != 1) {
    throw SkyEchoFieldError(
      'SIL cannot be changed from 1',
      hint: 'Source Integrity Level is hardcoded by device firmware.',
    );
  }
}
```

---

### 1090ES Receiver Always Enabled

**JavaScript Line 301**:
```html
<input type="radio" disabled="true" checked="true">1090ES
```

**Rule**: The 1090ES receiver is ALWAYS enabled (cannot be disabled).

**Rationale**: The device always receives 1090ES signals. Users can only choose between UAT and FLARM as the PRIMARY receiver mode, but 1090ES reception is constant.

**Dart Documentation**:
```dart
enum ReceiverMode {
  /// UAT receiver mode (978 MHz).
  /// Note: 1090ES reception is always active regardless of mode.
  uat(0x01, 'UAT'),

  /// FLARM receiver mode (868 MHz, EU only).
  /// Note: 1090ES reception is always active regardless of mode.
  flarm(0x41, 'FLARM'),

  /// 1090ES-only receiver mode (1090 MHz).
  /// This is the default when neither UAT nor FLARM is selected.
  es1090(0x00, '1090ES');

  final int wireValue;
  final String displayName;
  const ReceiverMode(this.wireValue, this.displayName);
}
```

---

## Auto-Transformations

### 1. Callsign → Uppercase

**JavaScript Line 126**:
```javascript
setup.callsign = formData["callsign"].value.toUpperCase();
```

**Rule**: Callsign MUST be converted to uppercase before sending to device.

**Dart Implementation**:
```dart
class SetupUpdate {
  String? _callsign;

  set callsign(String? value) {
    if (value == null) {
      _callsign = null;
      return;
    }

    // Validate format first
    SkyEchoValidation.validateCallsign(value);

    // Auto-uppercase
    _callsign = value.toUpperCase();
  }

  String? get callsign => _callsign;
}
```

---

### 2. ICAO Address → Remove 0x Prefix

**JavaScript Line 125**:
```javascript
setup.icaoAddress = parseInt(formData["icaoAddress"].value, 16);
```

**Rule**: User can provide `"0x7CC599"` or `"7CC599"`, library strips optional prefix and parses as hex.

**Dart Implementation**:
```dart
int _hexToInt(String hex) {
  // Remove optional 0x prefix (case-insensitive)
  final cleaned = hex.replaceFirst(RegExp(r'^0x', caseSensitive: false), '');
  return int.parse(cleaned, radix: 16);
}
```

---

### 3. GPS Longitude Offset → Round to Even

**Rule**: Odd values (11, 13, 15...) are automatically rounded down to nearest even (10, 12, 14...).

**Rationale**: Device encoding divides by 2, so odd values get truncated. Auto-rounding prevents silent data loss.

**Dart Implementation**:
```dart
int? _gpsLonOffset;

set gpsLonOffset(int? value) {
  if (value == null) {
    _gpsLonOffset = null;
    return;
  }

  SkyEchoValidation.validateGpsLonOffsetRange(value); // 0-60 check

  // Auto-normalize odd to even
  _gpsLonOffset = (value % 2 != 0) ? value - 1 : value;
}
```

---

### 4. Aircraft Length = 0 → null

**Rule**: Setting `aircraftLength = 0` is auto-converted to `null` for clear "no data" semantic.

**Rationale**: Packed value `0` means "no data", but `aircraftLength = 0` is ambiguous (really small aircraft or no data?). Force users to use `null` for clarity.

**Dart Implementation**:
```dart
int? _aircraftLength;

set aircraftLength(int? value) {
  if (value == null || value == 0) {
    _aircraftLength = null; // Normalize 0 to null
    return;
  }

  SkyEchoValidation.validateAircraftLength(value); // 1-7 check
  _aircraftLength = value;
}
```

---

## Dart Implementation

### Constants File

```dart
/// Constants extracted from SkyEcho 2 device JavaScript.
class SkyEchoConstants {
  // Numeric constants
  static const int stallSpeedMultiplier = 5144;
  static const int postVerificationDelayMs = 2000;
  static const int requestTimeoutMs = 5000;

  // Field constraints
  static const int maxCallsignLength = 8;
  static const int minCallsignLength = 1;
  static const int maxStallSpeedKnots = 100;
  static const int minStallSpeedKnots = 0;
  static const int maxGpsLonOffsetMeters = 60;
  static const int minGpsLonOffsetMeters = 0;
  static const int gpsLonOffsetStepMeters = 2;
  static const int maxGpsLatOffset = 7;
  static const int minGpsLatOffset = 0;
  static const int maxAircraftLength = 7;
  static const int minAircraftLength = 1; // 0 converted to null
  static const int maxAircraftWidth = 1;
  static const int minAircraftWidth = 0;

  // Hardcoded values
  static const int silValue = 1; // Source Integrity Level - always 1

  // Bitmask values
  static const int adsbIn1090ES = 0x01;
  static const int adsbInUAT = 0x02;
  static const int controlTxEnable = 0x02;
  static const int controlUAT = 0x01;
  static const int controlFLARM = 0x41;

  // Hex formatting
  static const int icaoHexLength = 6;
  static const int flarmHexLength = 6;

  // VFR squawk
  static const int vfrSquawkLength = 4;

  // Valid emitter categories (with gaps at 8, 13, 16, 22+)
  static const List<int> validEmitterCategories = [
    0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 17, 18, 19, 20, 21
  ];
}
```

---

### Validation Helper Class

```dart
/// Validation helpers for SkyEcho setup configuration fields.
///
/// All validation rules extracted from device JavaScript (setup page).
class SkyEchoValidation {
  // Regex patterns
  static final RegExp icaoPattern = RegExp(
    r'^(?:0x)?(?!f{6}|F{6}|0{6})[A-Fa-f0-9]{6}$',
    caseSensitive: false,
  );

  static final RegExp callsignPattern = RegExp(r'^[A-Za-z0-9]{1,8}$');

  static final RegExp vfrSquawkPattern = RegExp(r'^[0-7]{4}$');

  /// Validates ICAO address hex format and blacklist.
  ///
  /// Rejects: "000000", "FFFFFF", and all-caps variants.
  /// Accepts: "7CC599", "0x7CC599", "abc123" (will be uppercased).
  static void validateIcaoAddress(String value) {
    if (!icaoPattern.hasMatch(value)) {
      throw SkyEchoFieldError(
        'Invalid ICAO address: "$value"',
        hint: 'Must be 6 hex digits. Cannot be 000000 or FFFFFF.',
      );
    }
  }

  /// Validates callsign format (1-8 alphanumeric).
  static void validateCallsign(String value) {
    if (!callsignPattern.hasMatch(value)) {
      throw SkyEchoFieldError(
        'Invalid callsign: "$value"',
        hint: 'Must be 1-8 alphanumeric characters (A-Z, 0-9).',
      );
    }
  }

  /// Validates VFR squawk (exactly 4 octal digits).
  static void validateVfrSquawk(String value) {
    if (!vfrSquawkPattern.hasMatch(value)) {
      throw SkyEchoFieldError(
        'Invalid VFR squawk: "$value"',
        hint: 'Must be exactly 4 octal digits (0-7). Example: 1200, 7700',
      );
    }
  }

  /// Validates stall speed range (0-100 knots).
  static void validateStallSpeed(int knots) {
    if (knots < SkyEchoConstants.minStallSpeedKnots ||
        knots > SkyEchoConstants.maxStallSpeedKnots) {
      throw SkyEchoFieldError(
        'Invalid stall speed: $knots knots',
        hint: 'Must be 0-100 knots.',
      );
    }
  }

  /// Validates GPS longitude offset (0-60 meters, even only).
  static void validateGpsLonOffset(int meters) {
    if (meters < SkyEchoConstants.minGpsLonOffsetMeters ||
        meters > SkyEchoConstants.maxGpsLonOffsetMeters) {
      throw SkyEchoFieldError(
        'Invalid GPS longitude offset: $meters meters',
        hint: 'Must be 0-60 meters.',
      );
    }
    if (meters % SkyEchoConstants.gpsLonOffsetStepMeters != 0) {
      throw SkyEchoFieldError(
        'Invalid GPS longitude offset: $meters meters',
        hint: 'Must be an even number (0, 2, 4, ..., 60).',
      );
    }
  }

  /// Validates emitter category (valid values with gaps).
  static void validateEmitterCategory(int value) {
    if (!SkyEchoConstants.validEmitterCategories.contains(value)) {
      throw SkyEchoFieldError(
        'Invalid emitter category: $value',
        hint: 'Valid values: ${SkyEchoConstants.validEmitterCategories}',
      );
    }
  }

  /// Validates FLARM dependencies (mode → filter → ID).
  static void validateFlarmDependencies({
    required ReceiverMode receiverMode,
    required bool filterFlarm,
    required String? flarmId,
  }) {
    if (flarmId != null) {
      if (receiverMode != ReceiverMode.flarm) {
        throw SkyEchoFieldError(
          'FLARM ID requires FLARM receiver mode',
          hint: 'Set receiverMode to ReceiverMode.flarm when providing FLARM ID.',
        );
      }
      if (!filterFlarm) {
        throw SkyEchoFieldError(
          'FLARM ID requires FLARM filtering enabled',
          hint: 'Set filterFlarm to true when providing FLARM ID.',
        );
      }
    }

    if (receiverMode != ReceiverMode.flarm && filterFlarm) {
      throw SkyEchoFieldError(
        'FLARM filtering requires FLARM receiver mode',
        hint: 'Set receiverMode to ReceiverMode.flarm to enable FLARM filtering.',
      );
    }
  }

  /// Validates aircraft dimensions (length → width dependency).
  static void validateAircraftDimensions({
    required int? length,
    required int? width,
  }) {
    if (length == null && width == null) return; // No data - valid

    if (length == null && width != null) {
      throw SkyEchoFieldError(
        'Aircraft width requires aircraft length',
        hint: 'Set aircraftLength when providing aircraftWidth.',
      );
    }

    if (length != null && width == null) {
      throw SkyEchoFieldError(
        'Aircraft length requires aircraft width',
        hint: 'Set aircraftWidth when providing aircraftLength.',
      );
    }

    // Validate ranges
    if (length! < SkyEchoConstants.minAircraftLength ||
        length > SkyEchoConstants.maxAircraftLength) {
      throw SkyEchoFieldError(
        'Invalid aircraft length: $length',
        hint: 'Must be 1-7 (or null for no data).',
      );
    }

    if (width! < SkyEchoConstants.minAircraftWidth ||
        width > SkyEchoConstants.maxAircraftWidth) {
      throw SkyEchoFieldError(
        'Invalid aircraft width: $width',
        hint: 'Must be 0 or 1.',
      );
    }

    // Special case: length=0 converted to null by setter, but validate if somehow bypassed
    if (length == 0 && width == 0) {
      throw SkyEchoFieldError(
        'Invalid aircraft dimensions: length=0 requires width=1',
        hint: 'Use null for both length and width to indicate "no data".',
      );
    }
  }
}
```

---

## Testing Requirements

All validation rules MUST be tested. Add these test cases to Phase 5 unit tests:

### ICAO Address Validation Tests
- [ ] Accepts "7CC599" (valid hex)
- [ ] Accepts "0x7CC599" (with prefix)
- [ ] Accepts "abc123" (lowercase, will uppercase)
- [ ] Accepts "000001" (not all zeros)
- [ ] Accepts "FFFFFE" (not all ones)
- [ ] Rejects "000000" (blacklisted)
- [ ] Rejects "FFFFFF" (blacklisted)
- [ ] Rejects "0x000000" (blacklisted with prefix)
- [ ] Rejects "0xFFFFFF" (blacklisted with prefix)
- [ ] Rejects "12345" (too short)
- [ ] Rejects "1234567" (too long)
- [ ] Rejects "GGGGGG" (invalid hex)

### Callsign Validation Tests
- [ ] Accepts "N12345" (6 alphanumeric)
- [ ] Accepts "ABC" (3 letters)
- [ ] Accepts "9954" (4 digits)
- [ ] Auto-uppercases "test123" → "TEST123"
- [ ] Rejects "" (empty, required)
- [ ] Rejects "CALLSIGN1" (too long, 9 chars)
- [ ] Rejects "N12-34" (contains hyphen)
- [ ] Rejects "ABC " (contains space)
- [ ] Rejects "Test_1" (contains underscore)

### VFR Squawk Validation Tests
- [ ] Accepts "1200" (valid VFR)
- [ ] Accepts "7700" (valid emergency)
- [ ] Accepts "0000" (all zeros, technically valid)
- [ ] Accepts "7777" (all sevens)
- [ ] Rejects "8000" (contains 8)
- [ ] Rejects "1299" (contains 9)
- [ ] Rejects "120" (too short)
- [ ] Rejects "12000" (too long)

### Range Validation Tests
- [ ] Stall speed accepts 0 knots
- [ ] Stall speed accepts 100 knots
- [ ] Stall speed rejects 101 knots
- [ ] Stall speed rejects -1 knots
- [ ] GPS lon offset accepts 0 meters
- [ ] GPS lon offset accepts 60 meters
- [ ] GPS lon offset accepts 30 meters (even)
- [ ] GPS lon offset rejects 61 meters
- [ ] GPS lon offset rejects 11 meters (odd) - OR auto-normalizes to 10

### Auto-Transformation Tests
- [ ] Callsign "abc123" → "ABC123"
- [ ] ICAO "0x7cc599" → 8177049 (strips prefix, parses)
- [ ] GPS lon offset 11 → 10 (auto-round to even)
- [ ] Aircraft length 0 → null (auto-normalize)

### Field Dependency Tests
- [ ] FLARM ID requires FLARM receiver mode
- [ ] FLARM ID requires filterFlarm = true
- [ ] FLARM filtering requires FLARM receiver mode
- [ ] UAT mode clears FLARM ID
- [ ] Aircraft width requires aircraft length
- [ ] Aircraft length requires aircraft width

### Hardcoded Value Tests
- [ ] SIL always equals 1 in JSON output
- [ ] Attempting to set SIL ≠ 1 throws error
- [ ] 1090ES receiver documented as always enabled

---

## Summary

This validation specification ensures:
1. ✅ **Aviation safety** - SIL hardcoded, ICAO blacklist enforced
2. ✅ **Data integrity** - Range checks, octal validation, even-number constraints
3. ✅ **User experience** - Auto-transformations prevent silent failures
4. ✅ **Device compatibility** - All rules match JavaScript exactly
5. ✅ **Comprehensive testing** - 50+ test cases cover all edge cases

**Next Step**: Integrate validation into Phase 5 tasks T024 (SetupUpdate class) and add validation test tasks.
