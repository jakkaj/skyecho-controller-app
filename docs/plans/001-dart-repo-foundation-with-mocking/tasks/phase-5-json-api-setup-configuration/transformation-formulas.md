# SkyEcho JSON API Transformation Formulas

**Source**: Setup page JavaScript (`http://192.168.4.1/setup`)
**Captured**: 2025-10-18
**Firmware**: WiFi 0.2.41-SkyEcho, ADS-B 2.6.13

This document extracts all transformation formulas from the device's JavaScript code for implementing Phase 5.

---

## 1. Hex Conversion (icaoAddress)

### Dart → JSON (Packing)
**JavaScript** (line 125):
```javascript
setup.icaoAddress = parseInt(formData["icaoAddress"].value, 16);
```

**Dart Implementation**:
```dart
int _hexToInt(String hex) {
  // Remove optional 0x prefix, parse as hex
  final cleaned = hex.replaceFirst(RegExp(r'^0x', caseSensitive: false), '');
  return int.parse(cleaned, radix: 16);
}
```

**Example**: `"7CC599"` → `8177049`

### JSON → Dart (Unpacking)
**JavaScript** (line 190):
```javascript
form["icaoAddress"].value = setup.icaoAddress.toString(16).padStart(6, '0');
```

**Dart Implementation**:
```dart
String _intToHex(int value) {
  return value.toRadixString(16).toUpperCase().padLeft(6, '0');
}
```

**Example**: `8177049` → `"7CC599"`

---

## 2. ADS-B In Capability (Bitmask)

### Dart → JSON (Packing)
**JavaScript** (lines 129-134):
```javascript
var adsbInCapability = 0;
var capabilities = formData["adsbInCapability"];
for (var i = 0; i < capabilities.length; i++)
    adsbInCapability |= (capabilities[i].checked) ? capabilities[i].value : 0;

setup.adsbInCapability = adsbInCapability;
```

**HTML Values** (lines 360-362):
```html
<input type="checkbox" name="adsbInCapability" value="1">1090ES
<input type="checkbox" name="adsbInCapability" value="2">UAT
```

**Bit Layout**:
- Bit 0 (0x01): 1090ES capability
- Bit 1 (0x02): UAT capability

**Dart Implementation**:
```dart
int _packAdsbInCapability({required bool es1090, required bool uat}) {
  int result = 0;
  if (es1090) result |= 0x01;
  if (uat) result |= 0x02;
  return result;
}
```

**Example**: `{es1090: true, uat: true}` → `3` (0x03)

### JSON → Dart (Unpacking)
**JavaScript** (lines 196-198):
```javascript
var capabilities = form["adsbInCapability"];
for (var i = 0; i < capabilities.length; i++)
    capabilities[i].checked = ((capabilities[i].value & setup.adsbInCapability) == capabilities[i].value);
```

**Dart Implementation**:
```dart
Map<String, bool> _unpackAdsbInCapability(int value) {
  return {
    'es1090': (value & 0x01) != 0,
    'uat': (value & 0x02) != 0,
  };
}
```

**Example**: `3` → `{es1090: true, uat: true}`

---

## 3. Control Field (1090ES Transmit + Receiver Mode)

### Dart → JSON (Packing)
**JavaScript** (lines 136-141):
```javascript
var pingControlState = 0;
var controls = formData["pingControlState"];
for (var i = 0; i < controls.length; i++)
    pingControlState |= (controls[i].checked) ? controls[i].value : 0;

setup.control = pingControlState;
```

**HTML Values** (lines 292-301):
```html
<!-- 1090ES Transmit Enable -->
<input type="checkbox" name="pingControlState" value="2">Enable

<!-- Receiver Mode -->
<input type="radio" name="pingControlState" value="1" checked>UAT
<input type="radio" name="pingControlState" value="65">FLARM (EU ONLY)
<!-- 1090ES radio is disabled -->
```

**Bit Layout**:
- Bit 1 (0x02): 1090ES Transmit Enable
- Bit 0 (0x01): Receiver Mode = UAT
- Bit 0 + Bit 6 (0x41 = 65): Receiver Mode = FLARM
- (Assumed) 0x00: Receiver Mode = 1090ES (radio disabled in HTML, needs validation)

**IMPORTANT**:
- FLARM mode uses bit 6 (0x40) + bit 0 (0x01) = 0x41 (65 decimal)!
- 1090ES receiver mode value is **ASSUMED to be 0x00** (no bits set) since radio is disabled in HTML
- When unpacking, check FLARM (0x41) FIRST before UAT (0x01) due to bit overlap

**Dart Implementation**:
```dart
enum ReceiverMode {
  uat(0x01, 'UAT'),
  flarm(0x41, 'FLARM'),
  es1090(0x00, '1090ES');  // ASSUMED - needs integration test validation

  final int wireValue;
  final String displayName;
  const ReceiverMode(this.wireValue, this.displayName);
}

int _packControl({required bool enable1090ESTransmit, required ReceiverMode receiverMode}) {
  int result = receiverMode.wireValue;
  if (enable1090ESTransmit) result |= 0x02;
  return result;
}
```

**Example**: `{enable1090ESTransmit: true, receiverMode: ReceiverMode.uat}` → `3` (0x03 = 0x02 | 0x01)

### JSON → Dart (Unpacking)
**JavaScript** (lines 200-202):
```javascript
var controls = form["pingControlState"];
for (var i = 0; i < controls.length; i++)
    controls[i].checked = ((controls[i].value & setup.control) == controls[i].value);
```

**Dart Implementation**:
```dart
Map<String, dynamic> _unpackControl(int value) {
  final enable1090ESTransmit = (value & 0x02) != 0;

  ReceiverMode receiverMode;
  if ((value & 0x41) == 0x41) {
    receiverMode = ReceiverMode.flarm;
  } else if ((value & 0x01) == 0x01) {
    receiverMode = ReceiverMode.uat;
  } else {
    receiverMode = ReceiverMode.es1090;
  }

  return {
    'enable1090ESTransmit': enable1090ESTransmit,
    'receiverMode': receiverMode,
  };
}
```

**Example**: `3` → `{enable1090ESTransmit: true, receiverMode: ReceiverMode.uat}`

---

## 4. Stall Speed (Unit Conversion)

### Dart → JSON (Packing)
**JavaScript** (line 157):
```javascript
setup.stallSpeed = Math.ceil((formData.getInt("stallSpeed") * 5144) / 10);
```

**Formula**: `ceil((knots × 5144) / 10)` = `ceil(knots × 514.4)`

**Dart Implementation**:
```dart
int _knotsToDeviceUnits(double knots) {
  return ((knots * 514.4).ceil());
}
```

**Example**: `50.0` knots → `25720` device units

### JSON → Dart (Unpacking)
**JavaScript** (line 193):
```javascript
form["stallSpeed"].value = Math.ceil((setup.stallSpeed * 10) / 5144);
```

**Formula**: `ceil((deviceValue × 10) / 5144)` = `ceil(deviceValue / 514.4)`

**Dart Implementation**:
```dart
double _deviceUnitsToKnots(int deviceValue) {
  return (deviceValue / 514.4).ceilToDouble();
}
```

**Example**: `25720` device units → `50.0` knots

**Note**: Roundtrip may have precision loss due to `ceil()` operations.

---

## 5. Aircraft Length + Width (Bit-Packed)

### Dart → JSON (Packing)
**JavaScript** (line 149):
```javascript
setup.aircraftLengthWidth = (aircraftLength << 1) | aircraftWidth;
```

**Bit Layout**:
- Bits 1-7: Aircraft length (0-7 = length categories)
- Bit 0: Aircraft width (0 or 1)

**Dart Implementation**:
```dart
int _packAircraftLengthWidth({required int length, required int width}) {
  return (length << 1) | (width & 0x01);
}
```

**Example**: `{length: 3, width: 1}` → `7` (binary: 0000 0111)

### JSON → Dart (Unpacking)
**JavaScript** (lines 205-206):
```javascript
var aircraftLength = (aircraftLengthWidth == 0) ? null : aircraftLengthWidth >> 1;
var aircraftWidth = aircraftLengthWidth & 0x01;
```

**Dart Implementation**:
```dart
Map<String, int?> _unpackAircraftLengthWidth(int value) {
  if (value == 0) {
    return {'length': null, 'width': null};
  }
  return {
    'length': value >> 1,
    'width': value & 0x01,
  };
}
```

**Example**: `7` → `{length: 3, width: 1}`

**Edge Cases**:
- `aircraftLengthWidth = 0` is special: unpacks to `{length: null, width: null}` (no data)
- `aircraftLengthWidth = 1` unpacks to `{length: 0, width: 1}` - questionable semantic (really small aircraft or no data?)
- **Auto-normalization in SetupUpdate**: Setting `aircraftLength = 0` automatically converts to `null` for clear "no data" intent

---

## 6. GPS Antenna Offset (Bit-Packed)

### Dart → JSON (Packing)
**JavaScript** (lines 151-155):
```javascript
var latGpsOffset = formData.getInt("gpsLatOffset");
var lonGpsOffset = formData.getInt("gpsLonOffset");
var lonGpsOffset = (lonGpsOffset != 0) ? (lonGpsOffset / 2 + 1) : 0;

setup.gpsAntennaOffset = (latGpsOffset << 5) | lonGpsOffset;
```

**Bit Layout**:
- Bits 5-7: Lateral GPS offset (0-7)
- Bits 0-4: Longitudinal GPS offset (encoded: `(meters / 2) + 1`, or 0 for no offset)

**Dart Implementation**:
```dart
int _packGpsAntennaOffset({required int lateral, required int longitudinal}) {
  final lonEncoded = (longitudinal != 0) ? (longitudinal ~/ 2 + 1) : 0;
  return (lateral << 5) | (lonEncoded & 0x1F);
}
```

**Example**: `{lateral: 4, longitudinal: 10}` → `133` (binary: 1000 0101 = (4 << 5) | ((10/2)+1))

### JSON → Dart (Unpacking)
**JavaScript** (lines 212-214):
```javascript
var latGpsOffset = gpsAntennaOffset >> 5;
var lonGpsOffset = (gpsAntennaOffset & 0x1F);
lonGpsOffset = (lonGpsOffset) ? 2 * (lonGpsOffset - 1) : 0;
```

**Dart Implementation**:
```dart
Map<String, int> _unpackGpsAntennaOffset(int value) {
  final lateral = value >> 5;
  final lonEncoded = value & 0x1F;
  final longitudinal = (lonEncoded != 0) ? 2 * (lonEncoded - 1) : 0;
  return {
    'lateral': lateral,
    'longitudinal': longitudinal,
  };
}
```

**Example**: `133` → `{lateral: 4, longitudinal: 10}`

**Edge Cases**:
- **Longitude must be even** (0, 2, 4, ..., 60): Device divides by 2, so odd values get truncated
- `lonGpsOffset = 0` has special encoding: stored as 0 (not `(0/2)+1`)
- `lonGpsOffset = 11` (odd) becomes `(11/2)+1 = 6`, then unpacks to `2*(6-1) = 10` - **silent data loss!**
- Maximum longitude: 5 bits for encoded value (0-31), with 0 special = actual range 0-60 meters in steps of 2
- **Auto-normalization in SetupUpdate**: Setting odd `gpsLonOffset` (e.g., 11) automatically rounds down to nearest even (10) to prevent silent corruption

---

## 7. Ownship Filter

### Dart → JSON (Packing)
**JavaScript** (lines 162-164):
```javascript
let ownshipFilter = {};
ownshipFilter.icaoAddress = formData["filterAdsb"].checked ? parseInt(formData["icaoAddress"].value, 16) : null;
ownshipFilter.flarmId = formData["filterFlarm"].checked ? parseInt(formData["flarmId"].value, 16) : null;
```

**Logic**:
- If "Filter ADS-B" checkbox checked → set `icaoAddress` to same value as setup.icaoAddress
- If "Filter FLARM" checkbox checked → set `flarmId` to FLARM ID (hex)
- Otherwise → set to `null`

**Dart Implementation**:
```dart
Map<String, int?> _buildOwnshipFilter({
  required bool filterAdsb,
  required String icaoAddressHex,
  required bool filterFlarm,
  String? flarmIdHex,
}) {
  return {
    'icaoAddress': filterAdsb ? _hexToInt(icaoAddressHex) : null,
    'flarmId': (filterFlarm && flarmIdHex != null) ? _hexToInt(flarmIdHex) : null,
  };
}
```

### JSON → Dart (Unpacking)
**JavaScript** (lines 224-227):
```javascript
var ownship = settings.ownshipFilter;
form["flarmId"].value = ownship.flarmId ? ownship.flarmId.toString(16).padStart(6, '0') : "";
form["filterFlarm"].checked = (ownship.flarmId != null)
form["filterAdsb"].checked = (ownship.icaoAddress != null);
```

**Dart Implementation**:
```dart
Map<String, dynamic> _unpackOwnshipFilter(Map<String, dynamic> ownship) {
  return {
    'filterAdsb': ownship['icaoAddress'] != null,
    'filterFlarm': ownship['flarmId'] != null,
    'icaoAddressHex': ownship['icaoAddress'] != null ? _intToHex(ownship['icaoAddress'] as int) : null,
    'flarmIdHex': ownship['flarmId'] != null ? _intToHex(ownship['flarmId'] as int) : null,
  };
}
```

---

## User-Friendly Field Mapping

This table shows how SetupUpdate friendly property names map to JSON API fields:

| SetupUpdate Property | Type | JSON Field | JSON Type | Notes |
|---------------------|------|------------|-----------|-------|
| `icaoHex` | String | `setup.icaoAddress` | int | Hex string ↔ int conversion |
| `callsign` | String | `setup.callsign` | String | Direct mapping (uppercased) |
| `emitterCategory` | int | `setup.emitterCategory` | int | Direct mapping |
| `enable1090ESTransmit` | bool | `setup.control` | int | Bit 1 (0x02) of control field |
| `receiverMode` | ReceiverMode enum | `setup.control` | int | Bits 0+6 of control field |
| `enableUATCapability` | bool | `setup.adsbInCapability` | int | Bit 1 (0x02) |
| `enable1090ESCapability` | bool | `setup.adsbInCapability` | int | Bit 0 (0x01) |
| `vfrSquawk` | int | `setup.vfrSquawk` | int | Direct mapping (octal validation) |
| `stallSpeed` | double (knots) | `setup.stallSpeed` | int | Unit conversion (× 514.4) |
| `aircraftLength` | int? | `setup.aircraftLengthWidth` | int | Upper 7 bits (>> 1) |
| `aircraftWidth` | int? | `setup.aircraftLengthWidth` | int | Bit 0 (& 0x01) |
| `gpsLatOffset` | int | `setup.gpsAntennaOffset` | int | Upper 3 bits (>> 5) |
| `gpsLonOffset` | int | `setup.gpsAntennaOffset` | int | Lower 5 bits with encoding |
| `sda` | int | `setup.SDA` | int | Direct mapping |
| `filterAdsb` | bool | `ownshipFilter.icaoAddress` | int? | null if false, mirrors icaoAddress if true |
| `filterFlarm` | bool | `ownshipFilter.flarmId` | int? | null if false, hex value if true |
| `flarmIdHex` | String? | `ownshipFilter.flarmId` | int? | Hex string ↔ int, null if filterFlarm=false |

**Note**: Multiple SetupUpdate properties may map to a single JSON field (e.g., `enable1090ESTransmit` and `receiverMode` both update `setup.control`).

---

## JSON API Field Summary Table

| Field | Type | Packing Formula | Unpacking Formula | JavaScript Lines |
|-------|------|-----------------|-------------------|------------------|
| `icaoAddress` | Hex | `parseInt(hex, 16)` | `value.toString(16).padStart(6, '0')` | 125, 190 |
| `adsbInCapability` | Bitmask | OR checkboxes (1090ES=0x01, UAT=0x02) | AND each bit | 129-134, 196-198 |
| `control` | Bitmask | OR checkboxes (TX=0x02, UAT=0x01, FLARM=0x41) | AND each bit | 136-141, 200-202 |
| `stallSpeed` | Unit conversion | `ceil(knots × 514.4)` | `ceil(deviceValue / 514.4)` | 157, 193 |
| `aircraftLengthWidth` | Bit-packed | `(length << 1) \| width` | `length = value >> 1, width = value & 0x01` | 149, 205-206 |
| `gpsAntennaOffset` | Bit-packed | `(lat << 5) \| ((lon/2)+1 & 0x1F)` | `lat = value >> 5, lon = 2×((value&0x1F)-1)` | 151-155, 212-214 |
| `ownshipFilter.icaoAddress` | Hex (nullable) | `filterAdsb ? parseInt(hex, 16) : null` | `value?.toString(16).padStart(6, '0')` | 163, 225 |
| `ownshipFilter.flarmId` | Hex (nullable) | `filterFlarm ? parseInt(hex, 16) : null` | `value?.toString(16).padStart(6, '0')` | 164, 225 |

---

## Critical Discoveries

### Original Discoveries (From Initial Analysis)

1. **FLARM Receiver Mode Uses Bit 6**: The value `65` (0x41) sets BOTH bit 0 and bit 6, not a sequential encoding. This is unusual and could easily be missed.

2. **StallSpeed Uses `ceil()` Operations**: Both packing and unpacking use ceiling operations, which means roundtrip may not be exact. For example, `49.8 knots → 25629 device → 50.0 knots`.

3. **GPS Longitudinal Offset Encoding**: The longitudinal offset is encoded as `(meters / 2) + 1`, not a direct bit value. `0` means "no offset", not "0 meters offset".

4. **Aircraft Length/Width = 0 Means "No Data"**: Unlike other fields, a value of `0` for `aircraftLengthWidth` is treated specially as "no data" (returns null), not as "length=0, width=0".

5. **Ownship Filter Mirrors Setup**: The `ownshipFilter.icaoAddress` mirrors the `setup.icaoAddress` when filtering is enabled - it's not a separate field entry.

6. **POST Verification Wait Time = 2 Seconds**: Device JavaScript waits 2 seconds after POST before reloading config (line 173: `setTimeout(loadSettings, 2000)`). This is the device's own behavior and should be matched in `applySetup()` verification workflow. The Python test script uses 1 second which may be too short.

7. **GPS Longitude Must Be Even**: Device encoding uses `(meters / 2) + 1`, meaning odd values (11m, 13m, etc.) get silently truncated to even values. SetupUpdate implements auto-normalization (round down to nearest even) to prevent silent data loss and verification failures.

8. **Aircraft Length Zero Ambiguity**: `aircraftLengthWidth = 0` means "no data", but `aircraftLengthWidth = 1` unpacks to `{length: 0, width: 1}`. SetupUpdate normalizes `aircraftLength = 0` to `null` for clear "no data" semantic.

---

### Additional Discoveries (From Deep JavaScript Analysis)

9. **SIL Hardcoded to 1 (SAFETY-CRITICAL)**: Line 159 shows `setup.SIL = 1;` - the Source Integrity Level is ALWAYS 1 regardless of user input. This is aviation safety-critical data. The library MUST always send `"SIL": 1` and reject any attempt to set other values.

10. **Callsign Auto-Uppercase**: Line 126 shows `setup.callsign = formData["callsign"].value.toUpperCase();` - Device expects uppercase callsigns. Library must transform to uppercase before sending.

11. **ICAO/FLARM Address Blacklist**: HTML validation pattern (lines 307, 315) uses negative lookahead `(?!f{6}|F{6}|0{6})` to REJECT addresses `000000` and `FFFFFF` (all zeros/all ones are invalid ICAO addresses). Library must enforce this blacklist.

12. **VFR Squawk Must Be Octal**: Pattern `[0-7]{4}` (line 353) means squawk codes MUST be 4 octal digits (0-7 only). Values like `8000` or `1234` with digits 8-9 are invalid. Library must validate octal-only.

13. **StallSpeed Maximum = 100 Knots**: HTML input constraint `max="100"` (line 366) limits stall speed to 0-100 knots. Device likely rejects values > 100. Library must validate this range.

14. **GPS Longitude Offset Maximum = 60 Meters**: HTML input constraint `max="60"` and `step="2"` (line 410) means longitude offset is 0-60 meters in 2-meter increments. Values > 60 or odd values are invalid.

15. **Ownship Filter Uses `null` Not `0`**: Lines 163-164 show `ownshipFilter.icaoAddress = filterAdsb.checked ? parseInt(...) : null;` - When filtering is disabled, send `null` in JSON, NOT `0` or omitting the field. This distinguishes "filter disabled" from "filter enabled with address 0".

16. **Factory Reset API**: Lines 254-271 show undocumented endpoint: POST `{"loadDefaults": true}` to `/?action=set` triggers factory reset instead of config update. Library should expose this as `factoryReset()` method.

17. **Field Dependencies - FLARM Mode Controls Filter Availability**: Lines 54-61 show that selecting FLARM receiver mode enables/disables the FLARM filter checkbox and FLARM ID field. If UAT mode selected, `flarmId` should be ignored/cleared. Library should validate this dependency.

18. **Aircraft Width Depends on Aircraft Length**: Lines 63-95 show complex lookup table where each length category (0-7) has different valid width options. For example, length=0 only allows width=0 or 1, but length=3 might allow 0-2. Library should validate width is valid for selected length.

19. **Emitter Category Has Gaps**: Lines 330-349 show valid values are `[0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 17, 18, 19, 20, 21]` - values 8, 13, 16, and 22+ are NOT valid. Library must validate against this list.

20. **Request Timeout = 5 Seconds**: Lines 116, 248 show `xhr.timeout = 5000;` - Both GET and POST requests timeout after 5 seconds. Library should match this timeout value.

21. **1090ES Receiver Always Enabled**: Line 301 shows 1090ES receiver radio button is `disabled="true"` and `checked="true"` - this mode is ALWAYS active and cannot be disabled. Only UAT vs FLARM can be selected. Library should document this non-configurable behavior.

---

**Next Steps**: Use these formulas to implement tasks T014-T020 (transformation helpers) in Phase 5.
