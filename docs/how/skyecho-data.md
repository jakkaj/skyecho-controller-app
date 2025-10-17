# SkyEcho 2 Device Data Structures & API Specification

**Document Version**: 1.0
**Device Firmware**: WiFi 0.2.41-SkyEcho, ADS-B 2.6.13
**Last Updated**: 2025-10-18
**Analysis Source**: Complete device JavaScript extraction + real device testing

---

## Table of Contents

1. [Overview](#overview)
2. [HTTP API Endpoints](#http-api-endpoints)
3. [Device Status API](#device-status-api)
4. [Setup Configuration API](#setup-configuration-api)
5. [Field Transformations](#field-transformations)
6. [Validation Rules](#validation-rules)
7. [Error Handling](#error-handling)
8. [Session Management](#session-management)
9. [Timing & Timeouts](#timing--timeouts)
10. [Examples](#examples)

---

## Overview

The SkyEcho 2 ADS-B transponder exposes a JSON-based HTTP API for configuration and status monitoring. The device runs an embedded web server at `http://192.168.4.1` (default) accessible via its WiFi network.

### API Characteristics

- **Protocol**: HTTP/1.1 (no HTTPS)
- **Content-Type**: `application/json` for POST requests
- **Session**: Cookie-based (managed via `Set-Cookie` headers)
- **Timeout**: 5 seconds for all requests
- **Base URL**: `http://192.168.4.1`

### Architecture Pattern

The device uses a **screen-scraping approach** where:
1. HTML pages (`/` and `/setup`) are served with embedded JavaScript
2. JavaScript handles form submission and JSON API communication
3. JSON API endpoints (`/?action=get`, `/setup/?action=get`, `/setup/?action=set`) provide programmatic access
4. The JavaScript source code IS the authoritative specification (no published API docs from uAvionix)

---

## HTTP API Endpoints

### Endpoint Summary

| Endpoint | Method | Purpose | Content-Type | Returns |
|----------|--------|---------|--------------|---------|
| `/` | GET | Landing page (HTML + status) | text/html | HTML page with status table |
| `/?action=get` | GET | Device status (JSON) | application/json | DeviceStatus JSON |
| `/setup` | GET | Setup page (HTML + form) | text/html | HTML page with config form |
| `/setup/?action=get` | GET | Current configuration (JSON) | application/json | SetupConfig JSON |
| `/setup/?action=set` | POST | Apply configuration (JSON) | application/json | 200 OK or error |
| `/setup/?action=set` | POST | Factory reset | application/json | 200 OK (special payload) |

---

## Device Status API

### GET `/?action=get`

**Purpose**: Fetch current device status including firmware versions, SSID, client count, serial number, and coredump flag.

**Request**:
```http
GET /?action=get HTTP/1.1
Host: 192.168.4.1
Cookie: [session-cookie-if-available]
```

**Response** (200 OK):
```json
{
  "wifiVersion": "0.2.41-SkyEcho",
  "ssid": "SkyEcho_3155",
  "clientCount": 1,
  "adsbVersion": "2.6.13",
  "serialNumber": "0655339053",
  "coredump": false
}
```

### DeviceStatus Field Specification

| Field | Type | Description | Example | Nullable | Source |
|-------|------|-------------|---------|----------|--------|
| `wifiVersion` | String | WiFi firmware version | `"0.2.41-SkyEcho"` | Yes | Device firmware |
| `ssid` | String | Device WiFi SSID | `"SkyEcho_3155"` | Yes | Device network config |
| `clientCount` | Integer | Number of connected WiFi clients | `1` | Yes | Active connections |
| `adsbVersion` | String | ADS-B firmware version | `"2.6.13"` | Yes | Device firmware |
| `serialNumber` | String | Device serial number | `"0655339053"` | Yes | Hardware ID |
| `coredump` | Boolean | Crash dump present flag | `false` | No (default: false) | Device health |

### Computed Properties (Client-Side)

The device JavaScript (and Dart library) compute additional properties:

```javascript
// JavaScript (setup page, derived logic)
hasCoredump = (coredump === true);
isHealthy = (coredump === false && clientCount != null && clientCount > 0);
```

**Logic**:
- `hasCoredump`: Direct boolean check of `coredump` field
- `isHealthy`: Device is healthy if NO coredump AND at least 1 client connected

---

## Setup Configuration API

### GET `/setup/?action=get`

**Purpose**: Fetch current device configuration including all setup fields and ownship filter settings.

**Request**:
```http
GET /setup/?action=get HTTP/1.1
Host: 192.168.4.1
Cookie: [session-cookie-if-available]
```

**Response** (200 OK):
```json
{
  "setup": {
    "icaoAddress": 8177049,
    "callsign": "S9954",
    "emitterCategory": 1,
    "adsbInCapability": 1,
    "aircraftLengthWidth": 1,
    "gpsAntennaOffset": 128,
    "SIL": 1,
    "SDA": 1,
    "stallSpeed": 23148,
    "vfrSquawk": 1200,
    "control": 1
  },
  "ownshipFilter": {
    "icaoAddress": 8177049,
    "flarmId": null
  }
}
```

### POST `/setup/?action=set`

**Purpose**: Apply new configuration to device. Device persists changes and returns 200 OK.

**Request**:
```http
POST /setup/?action=set HTTP/1.1
Host: 192.168.4.1
Content-Type: application/json
Cookie: [session-cookie-if-available]

{
  "setup": {
    "icaoAddress": 8177049,
    "callsign": "TEST123",
    "emitterCategory": 1,
    "adsbInCapability": 3,
    "aircraftLengthWidth": 1,
    "gpsAntennaOffset": 128,
    "SIL": 1,
    "SDA": 1,
    "stallSpeed": 25720,
    "vfrSquawk": 1200,
    "control": 3
  },
  "ownshipFilter": {
    "icaoAddress": 8177049,
    "flarmId": null
  }
}
```

**Response** (200 OK):
```http
HTTP/1.1 200 OK
Content-Type: text/plain

OK
```

**CRITICAL**: Device takes **up to 2 seconds** to persist changes. Client MUST wait 2 seconds before verification GET.

### POST `/setup/?action=set` (Factory Reset)

**Purpose**: Reset device to factory defaults.

**Request**:
```http
POST /setup/?action=set HTTP/1.1
Host: 192.168.4.1
Content-Type: application/json

{
  "loadDefaults": true
}
```

**Response** (200 OK):
```http
HTTP/1.1 200 OK
Content-Type: text/plain

OK
```

**Note**: Special payload `{"loadDefaults": true}` triggers reset instead of config update.

---

## Setup Configuration Fields

### Top-Level Structure

```json
{
  "setup": {
    // 11 configuration fields
  },
  "ownshipFilter": {
    // 2 filter fields
  }
}
```

### `setup` Object Fields (11 total)

#### 1. `icaoAddress` (Integer)

**Description**: ICAO 24-bit address in decimal format (hex converted to int).

**Type**: Integer (0 - 16777215)
**Device Storage**: Decimal integer
**User Input**: Hex string (e.g., `"7CC599"`)
**Transformation**: `parseInt(hex, 16)` → integer
**Validation**:
- Must be 6 hex characters when formatted
- **MUST NOT** be `000000` or `FFFFFF` (blacklisted)
- Optional `0x` prefix allowed in input

**Examples**:
```javascript
// User input: "7CC599" → Device: 8177049
// User input: "0x7CC599" → Device: 8177049
// User input: "ABC123" → Device: 11256099
// INVALID: "000000" → REJECTED
// INVALID: "FFFFFF" → REJECTED
```

**JavaScript (lines 125, 190)**:
```javascript
// Packing (user input → device)
setup.icaoAddress = parseInt(formData["icaoAddress"].value, 16);

// Unpacking (device → display)
form["icaoAddress"].value = setup.icaoAddress.toString(16).padStart(6, '0');
```

---

#### 2. `callsign` (String)

**Description**: Aircraft callsign (1-8 alphanumeric characters).

**Type**: String
**Device Storage**: Uppercase string
**User Input**: Mixed case string
**Transformation**: `toUpperCase()`
**Validation**:
- 1-8 characters
- Alphanumeric only: `[A-Za-z0-9]{1,8}`
- Required (cannot be empty)

**Examples**:
```javascript
// User input: "test123" → Device: "TEST123"
// User input: "N12345" → Device: "N12345"
// INVALID: "TEST-123" → REJECTED (hyphen)
// INVALID: "CALLSIGN1" → REJECTED (9 chars)
```

**JavaScript (line 126)**:
```javascript
setup.callsign = formData["callsign"].value.toUpperCase();
```

---

#### 3. `emitterCategory` (Integer)

**Description**: Aircraft type category per ADS-B specification.

**Type**: Integer
**Valid Values**: `[0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 17, 18, 19, 20, 21]`
**Note**: Values 8, 13, 16, and 22+ are **NOT valid** (gaps in ADS-B spec)

**Value Mappings**:
```javascript
{
  0: "No Info",
  1: "Light",
  2: "Small",
  3: "Large",
  4: "High Vortex",
  5: "Heavy",
  6: "Highly Maneuverable",
  7: "Rotorcraft",
  9: "Glider/Sailplane",
  10: "Lighter Than Air",
  11: "Parachutist",
  12: "Ultra Light",
  14: "UAV",
  15: "Space",
  17: "Surface - Emergency",
  18: "Surface - Service",
  19: "Point Obstacle",
  20: "Cluster Obstacle",
  21: "Line Obstacle"
}
```

---

#### 4. `adsbInCapability` (Integer - Bitmask)

**Description**: ADS-B receiver capabilities (which frequencies the device can receive).

**Type**: Integer (bitmask)
**Bit Layout**:
- Bit 0 (0x01): 1090ES capability
- Bit 1 (0x02): UAT capability
- Bits 2-7: Reserved

**Valid Values**:
```javascript
0b00 (0x00 / 0): No capability
0b01 (0x01 / 1): 1090ES only
0b10 (0x02 / 2): UAT only
0b11 (0x03 / 3): Both 1090ES and UAT
```

**JavaScript (lines 129-134, 196-198)**:
```javascript
// Packing (checkboxes → bitmask)
var adsbInCapability = 0;
var capabilities = formData["adsbInCapability"]; // Checkbox array
for (var i = 0; i < capabilities.length; i++)
    adsbInCapability |= (capabilities[i].checked) ? capabilities[i].value : 0;
setup.adsbInCapability = adsbInCapability;

// HTML checkboxes:
// <input type="checkbox" name="adsbInCapability" value="1">1090ES
// <input type="checkbox" name="adsbInCapability" value="2">UAT

// Unpacking (bitmask → checkboxes)
for (var i = 0; i < capabilities.length; i++)
    capabilities[i].checked = ((capabilities[i].value & setup.adsbInCapability) == capabilities[i].value);
```

**Examples**:
```javascript
// Both checked: 1090ES (1) | UAT (2) = 3
// Only 1090ES: 1
// Only UAT: 2
// Neither: 0
```

---

#### 5. `control` (Integer - Bitmask)

**Description**: Receiver mode and transmit enable flags (complex bitmask).

**Type**: Integer (bitmask)
**Bit Layout**:
- Bit 0 (0x01): UAT receiver mode flag
- Bit 1 (0x02): 1090ES transmit enable flag
- Bit 6 (0x40): FLARM mode flag
- Combined FLARM: 0x41 = 0x40 | 0x01

**Valid Values**:
```javascript
0x00 (0):   1090ES receiver only (no UAT, no FLARM, no TX)
0x01 (1):   UAT receiver mode (no TX)
0x02 (2):   1090ES receiver + TX enabled
0x03 (3):   UAT receiver mode + 1090ES TX enabled
0x41 (65):  FLARM receiver mode (no TX)
0x43 (67):  FLARM receiver mode + 1090ES TX enabled
```

**CRITICAL**: Bit 6 (0x40) is used by FLARM mode, creating overlap with bit 0.

**JavaScript (lines 136-141, 200-202)**:
```javascript
// Packing (radio buttons + checkbox → bitmask)
var pingControlState = 0;
var controls = formData["pingControlState"]; // Mixed radio + checkbox array
for (var i = 0; i < controls.length; i++)
    pingControlState |= (controls[i].checked) ? controls[i].value : 0;
setup.control = pingControlState;

// HTML form:
// <input type="checkbox" name="pingControlState" value="2">1090ES Transmit
// <input type="radio" name="pingControlState" value="1" checked>UAT
// <input type="radio" name="pingControlState" value="65">FLARM (EU ONLY)
// <input type="radio" disabled checked>1090ES (always enabled, not selectable)

// Unpacking (bitmask → form elements)
for (var i = 0; i < controls.length; i++)
    controls[i].checked = ((controls[i].value & setup.control) == controls[i].value);
```

**Unpacking Logic** (must check FLARM first due to bit overlap):
```javascript
// Correct unpacking order:
if ((control & 0x41) === 0x41) {
  receiverMode = "FLARM";
} else if (control & 0x01) {
  receiverMode = "UAT";
} else {
  receiverMode = "1090ES"; // Default (no bits set or only TX bit set)
}

transmitEnabled = (control & 0x02) !== 0;
```

---

#### 6. `vfrSquawk` (Integer)

**Description**: VFR squawk code (octal integer, 4 digits).

**Type**: Integer
**Valid Range**: 0000-7777 (octal)
**Validation**: All 4 digits must be 0-7 (no 8 or 9)
**Common Values**:
- `1200`: VFR (US)
- `7700`: Emergency
- `7600`: Lost communications
- `7500`: Hijack

**JavaScript (lines 143, 194)**:
```javascript
// Packing
setup.vfrSquawk = formData.getInt("vfrSquawk");

// Unpacking
form["vfrSquawk"].value = setup.vfrSquawk;
```

**HTML Validation**:
```html
<input type="text" pattern="[0-7]{4}" required>
```

**Examples**:
```javascript
// Valid: 1200, 0000, 7777, 7700
// INVALID: 8000 (digit 8)
// INVALID: 1299 (digit 9)
```

---

#### 7. `stallSpeed` (Integer)

**Description**: Aircraft stall speed in device-specific units (converted from knots).

**Type**: Integer
**User Input**: Knots (0-100)
**Device Storage**: Encoded units
**Transformation**: `ceil(knots × 514.4)` (pack), `ceil(deviceValue / 514.4)` (unpack)
**Validation**: 0-100 knots

**JavaScript (lines 157, 193)**:
```javascript
// Packing (knots → device units)
setup.stallSpeed = Math.ceil((formData.getInt("stallSpeed") * 5144) / 10);

// Unpacking (device units → knots)
form["stallSpeed"].value = Math.ceil((setup.stallSpeed * 10) / 5144);
```

**Formula**:
```
knots → device: ceil(knots × 514.4)
device → knots: ceil(deviceValue / 514.4)
```

**Examples**:
```javascript
// 50 knots → 25720 device units
// 45 knots → 23148 device units
// 100 knots → 51440 device units
// 0 knots → 0 device units
```

**Note**: Roundtrip may not be exact due to `ceil()` operations.

---

#### 8. `aircraftLengthWidth` (Integer - Bit-Packed)

**Description**: Aircraft dimensions encoded in single integer (length in upper 7 bits, width in bit 0).

**Type**: Integer (bit-packed)
**Bit Layout**:
- Bits 1-7: Aircraft length category (0-7, or 0 for "no data")
- Bit 0: Aircraft width category (0 or 1)

**JavaScript (lines 145-149, 204-209)**:
```javascript
// Packing
var aircraftLength = (aircraftLength == "null") ? 0 : parseInt(aircraftLength);
var aircraftWidth = formData.getInt("aircraftWidth");
setup.aircraftLengthWidth = (aircraftLength << 1) | aircraftWidth;

// Unpacking
var aircraftLength = (aircraftLengthWidth == 0) ? null : aircraftLengthWidth >> 1;
var aircraftWidth = aircraftLengthWidth & 0x01;
```

**Special Cases**:
- `aircraftLengthWidth = 0` → length=null, width=null ("no data")
- `aircraftLengthWidth = 1` → length=0, width=1 (L ≤ 15m, wide)

**Length Categories**:
```javascript
0: L ≤ 15m
1: 15m < L ≤ 25m
2: 25m < L ≤ 35m
3: 35m < L ≤ 45m
4: 45m < L ≤ 55m
5: 55m < L ≤ 65m
6: 65m < L ≤ 75m
7: L > 75m
```

**Width Dependency** (complex lookup table, lines 63-95):

Each length category has different valid width options. For example:
- Length 0 (L ≤ 15m): Only width=1 is valid (W ≤ 23m)
- Length 1-7: Both width=0 and width=1 are valid

---

#### 9. `gpsAntennaOffset` (Integer - Bit-Packed)

**Description**: GPS antenna offset from aircraft reference point (lateral and longitudinal).

**Type**: Integer (bit-packed)
**Bit Layout**:
- Bits 5-7: Lateral offset (0-7)
- Bits 0-4: Longitudinal offset (encoded, 0-31)

**JavaScript (lines 151-155, 211-216)**:
```javascript
// Packing
var latGpsOffset = formData.getInt("gpsLatOffset"); // 0-7
var lonGpsOffset = formData.getInt("gpsLonOffset"); // 0-60 (even numbers)
var lonGpsOffset = (lonGpsOffset != 0) ? (lonGpsOffset / 2 + 1) : 0; // Encode
setup.gpsAntennaOffset = (latGpsOffset << 5) | lonGpsOffset;

// Unpacking
var latGpsOffset = gpsAntennaOffset >> 5;
var lonGpsOffset = (gpsAntennaOffset & 0x1F);
lonGpsOffset = (lonGpsOffset) ? 2 * (lonGpsOffset - 1) : 0; // Decode
```

**Lateral Offset** (bits 5-7, values 0-7):
```javascript
0: No Data
1: Left 2m
2: Left 4m
3: Left 6m
4: Center
5: Right 2m
6: Right 4m
7: Right 6m
```

**Longitudinal Offset Encoding** (bits 0-4):
```javascript
// CRITICAL: Non-linear encoding!
0 meters → encoded as 0
2 meters → encoded as 2 (2/2 + 1 = 2)
4 meters → encoded as 3 (4/2 + 1 = 3)
6 meters → encoded as 4
...
60 meters → encoded as 31 (60/2 + 1 = 31)

// Formula:
if (meters == 0) {
  encoded = 0;
} else {
  encoded = (meters / 2) + 1;
}

// Reverse:
if (encoded == 0) {
  meters = 0;
} else {
  meters = 2 * (encoded - 1);
}
```

**Validation**:
- Lateral: 0-7
- Longitudinal: 0-60 meters, **even numbers only** (0, 2, 4, ..., 60)

**Examples**:
```javascript
// Lat=4 (center), Lon=10m
// Pack: (4 << 5) | ((10/2)+1) = 128 | 6 = 134

// Lat=0 (no data), Lon=0m
// Pack: (0 << 5) | 0 = 0

// Lat=5 (right 2m), Lon=60m
// Pack: (5 << 5) | ((60/2)+1) = 160 | 31 = 191
```

---

#### 10. `SIL` (Integer) - **HARDCODED**

**Description**: Source Integrity Level (ADS-B specification parameter).

**Type**: Integer
**Valid Values**: **ALWAYS 1**
**Device Behavior**: Hardcoded in firmware (line 159)

**JavaScript (line 159)**:
```javascript
setup.SIL = 1; // formData.getInt("SIL");
```

**CRITICAL**: SIL is **ALWAYS 1** regardless of any input. This is aviation safety-critical data that cannot be changed by users.

**Validation**: Library MUST reject any attempt to set SIL ≠ 1.

---

#### 11. `SDA` (Integer)

**Description**: System Design Assurance (ADS-B parameter).

**Type**: Integer
**Valid Values**: `0` or `1` only

**JavaScript (lines 160, 219)**:
```javascript
// Packing
setup.SDA = formData.getInt("SDA");

// Unpacking
form["SDA"].value = setup.SDA;
```

---

### `ownshipFilter` Object Fields (2 total)

#### 1. `ownshipFilter.icaoAddress` (Integer or null)

**Description**: ICAO address to filter for ownship (if ADS-B filtering enabled).

**Type**: Integer (hex converted) or `null`
**Logic**:
- If "Filter ADS-B" checkbox checked → mirrors `setup.icaoAddress`
- If "Filter ADS-B" checkbox unchecked → **`null`**

**JavaScript (lines 163, 226-227)**:
```javascript
// Packing
ownshipFilter.icaoAddress = formData["filterAdsb"].checked
    ? parseInt(formData["icaoAddress"].value, 16)
    : null;

// Unpacking
form["filterAdsb"].checked = (ownship.icaoAddress != null);
```

**CRITICAL**: Use `null` (not `0` or omitting field) when filter disabled.

---

#### 2. `ownshipFilter.flarmId` (Integer or null)

**Description**: FLARM ID to filter for ownship (if FLARM filtering enabled).

**Type**: Integer (hex converted) or `null`
**Logic**:
- If "Filter FLARM" checkbox checked AND FLARM receiver mode selected → hex value
- Otherwise → **`null`**

**JavaScript (lines 164, 225-227)**:
```javascript
// Packing
ownshipFilter.flarmId = formData["filterFlarm"].checked
    ? parseInt(formData["flarmId"].value, 16)
    : null;

// Unpacking
form["flarmId"].value = ownship.flarmId ? ownship.flarmId.toString(16).padStart(6, '0') : "";
form["filterFlarm"].checked = (ownship.flarmId != null);
```

**Field Dependencies** (lines 54-61):
```javascript
function updateGui() {
    let flarmId = document.getElementById("flarmId");
    let filterFlarm = document.getElementById("filterFlarm");

    // FLARM filter only enabled if FLARM receiver mode selected
    filterFlarm.disabled = !flarmRx.checked;
    filterFlarm.checked &= flarmRx.checked;

    // FLARM ID only enabled if FLARM filter checked
    flarmId.disabled = filterFlarm.disabled || !filterFlarm.checked;
}
```

**State Machine**:
1. UAT mode → filterFlarm disabled → flarmId disabled (must be `null`)
2. FLARM mode + filterFlarm unchecked → flarmId disabled (must be `null`)
3. FLARM mode + filterFlarm checked → flarmId enabled (can provide value)

---

## Field Transformations

### Transformation Summary Table

| Field | Input Type | Device Type | Transformation | Reverse Transformation | JavaScript Lines |
|-------|------------|-------------|----------------|------------------------|------------------|
| `icaoAddress` | String (hex) | Integer | `parseInt(hex, 16)` | `value.toString(16).padStart(6, '0')` | 125, 190 |
| `callsign` | String | String | `toUpperCase()` | (none) | 126 |
| `adsbInCapability` | Booleans | Integer (bitmask) | OR checkboxes | AND each bit | 129-134, 196-198 |
| `control` | Booleans | Integer (bitmask) | OR radios + checkbox | AND each bit (FLARM first) | 136-141, 200-202 |
| `vfrSquawk` | Integer | Integer | (direct) | (direct) | 143, 194 |
| `stallSpeed` | Integer (knots) | Integer (units) | `ceil(knots × 514.4)` | `ceil(units / 514.4)` | 157, 193 |
| `aircraftLengthWidth` | 2 Integers | Integer (packed) | `(length << 1) \| width` | `length = val >> 1, width = val & 0x01` | 145-149, 204-209 |
| `gpsAntennaOffset` | 2 Integers | Integer (packed) | `(lat << 5) \| ((lon/2)+1)` | `lat = val >> 5, lon = 2×((val&0x1F)-1)` | 151-155, 211-216 |
| `SIL` | (ignored) | Integer | **ALWAYS 1** | (always 1) | 159 |
| `SDA` | Integer | Integer | (direct) | (direct) | 160, 219 |
| `ownshipFilter.*` | String (hex) | Integer or null | `checked ? parseInt(hex, 16) : null` | `val ? val.toString(16).padStart(6, '0') : ""` | 163-164, 225-227 |

---

## Validation Rules

### Regex Patterns (from HTML validation attributes)

#### ICAO Address / FLARM ID
```regex
^(?:0x)?(?!f{6}|F{6}|0{6})[A-Fa-f0-9]{6}$
```

**Breakdown**:
- `(?:0x)?` - Optional "0x" prefix
- `(?!f{6}|F{6}|0{6})` - **Negative lookahead**: Reject all 'f', all 'F', or all '0'
- `[A-Fa-f0-9]{6}` - Exactly 6 hex digits

**Blacklist**: `000000`, `FFFFFF` (and all case variants with optional 0x prefix)

#### Callsign
```regex
^[A-Za-z0-9]{1,8}$
```

**Rules**: 1-8 alphanumeric characters, no special chars, required

#### VFR Squawk
```regex
^[0-7]{4}$
```

**Rules**: Exactly 4 octal digits (0-7 only)

### Range Constraints

| Field | Min | Max | Step | Special Rules |
|-------|-----|-----|------|---------------|
| `stallSpeed` | 0 knots | 100 knots | 1 | Integer only |
| `gpsLonOffset` | 0 meters | 60 meters | 2 | **Even numbers only** |
| `gpsLatOffset` | 0 | 7 | 1 | Enum values |
| `aircraftLength` | 0 (or null) | 7 | 1 | 0 means "no data" |
| `aircraftWidth` | 0 | 1 | 1 | Depends on length |
| `emitterCategory` | - | - | - | Valid: 0-7, 9-12, 14-15, 17-21 (gaps!) |
| `SDA` | 0 | 1 | 1 | Binary |

### Field Dependencies

#### FLARM Mode → Filter → ID Chain

```
if (receiverMode == FLARM) {
  filterFlarm can be enabled;
  if (filterFlarm == true) {
    flarmId can be provided;
  } else {
    flarmId must be null;
  }
} else {
  filterFlarm must be disabled;
  flarmId must be null;
}
```

#### Aircraft Length → Width Lookup

```javascript
// Length 0 (L ≤ 15m): Only width=1 valid
// Length 1-7: Both width=0 and width=1 valid
// Length null: width must also be null
```

#### Ownship Filter → Setup Field Mirroring

```javascript
if (filterAdsb == true) {
  ownshipFilter.icaoAddress = setup.icaoAddress; // Mirror
} else {
  ownshipFilter.icaoAddress = null;
}
```

---

## Error Handling

### HTTP Status Codes

| Status | Meaning | Action |
|--------|---------|--------|
| 200 OK | Success | Parse response or confirm change |
| 404 Not Found | Endpoint doesn't exist | Check URL/query params |
| 500 Internal Server Error | Device error | Check request format, retry |
| 0 (timeout) | Request timeout | Network issue or device offline |

### JavaScript Error Handling (lines 170-179, 239-244)

```javascript
// POST callback
function setCallback(status) {
    if (status == 200) {
        message = "Configuration updated.";
        setTimeout(loadSettings, 2000); // Wait 2s then reload
    } else {
        message = "Failed to set configuration. Error: ";
        message += (status != 0) ? xhr.responseText : "Timeout";
    }
    setStatus((status == 200), message);
}

// GET callback
if (xhr.status == 200) {
    updateForm(JSON.parse(this.responseText));
    message = "Configuration loaded.";
} else {
    message = "Failed to load configuration. Error: "
    message += (xhr.status != 0) ? xhr.responseText : "Timeout";
}
```

**Error Message Format**:
- Success: "Configuration updated."
- HTTP Error: "Failed to set configuration. Error: {xhr.responseText}"
- Timeout: "Failed to set configuration. Error: Timeout"

---

## Session Management

### Cookie Handling

The device uses cookie-based sessions (no authentication).

**JavaScript (lines 86-102, 104-111)**:
```javascript
// Simple cookie jar implementation
class _CookieJar {
  _cookies = {};

  // Ingest Set-Cookie headers
  ingest(setCookieHeaders) {
    for (const header of setCookieHeaders) {
      const parts = header.split(';');
      const nameValue = parts[0].trim();
      const [name, value] = nameValue.split('=');
      this._cookies[name] = value;
    }
  }

  // Generate Cookie header
  toHeader() {
    if (Object.keys(this._cookies).length === 0) return null;
    return Object.entries(this._cookies)
      .map(([k, v]) => `${k}=${v}`)
      .join('; ');
  }
}
```

**Usage**:
1. First request: No cookie
2. Device responds with `Set-Cookie` header
3. Store cookie(s) from header
4. Subsequent requests: Include `Cookie` header

**Example**:
```http
# First request
GET / HTTP/1.1
Host: 192.168.4.1

# Device response
HTTP/1.1 200 OK
Set-Cookie: session=abc123; Path=/

# Second request
GET /setup/?action=get HTTP/1.1
Host: 192.168.4.1
Cookie: session=abc123
```

---

## Timing & Timeouts

### Request Timeout (lines 116, 248)

```javascript
xhr.timeout = 5000; // 5 seconds
```

**All requests** (GET, POST) timeout after **5 seconds**.

### POST Verification Delay (line 173)

```javascript
setTimeout(loadSettings, 2000); // Wait 2 seconds after POST
```

**CRITICAL**: After POST `/setup/?action=set`, device takes **up to 2 seconds** to persist changes to flash memory.

**Recommended Verification Workflow**:
```
1. POST /setup/?action=set (new config)
2. Wait 200 OK response
3. **Wait 2 seconds** (device persists)
4. GET /setup/?action=get (verify config)
5. Compare applied vs expected
```

**Why 2 seconds?**:
- Device JavaScript uses `setTimeout(loadSettings, 2000)` (line 173)
- This is the device firmware's own behavior
- Waiting less than 2 seconds may read stale config (race condition)

---

## Examples

### Complete GET Status Workflow

```bash
# 1. Ping device (optional)
curl -v http://192.168.4.1/

# 2. Fetch device status
curl -s http://192.168.4.1/?action=get | jq .

# Output:
# {
#   "wifiVersion": "0.2.41-SkyEcho",
#   "ssid": "SkyEcho_3155",
#   "clientCount": 1,
#   "adsbVersion": "2.6.13",
#   "serialNumber": "0655339053",
#   "coredump": false
# }
```

### Complete GET Configuration Workflow

```bash
# Fetch current configuration
curl -s http://192.168.4.1/setup/?action=get | jq .

# Output:
# {
#   "setup": {
#     "icaoAddress": 8177049,
#     "callsign": "S9954",
#     "emitterCategory": 1,
#     "adsbInCapability": 1,
#     "aircraftLengthWidth": 1,
#     "gpsAntennaOffset": 128,
#     "SIL": 1,
#     "SDA": 1,
#     "stallSpeed": 23148,
#     "vfrSquawk": 1200,
#     "control": 1
#   },
#   "ownshipFilter": {
#     "icaoAddress": 8177049,
#     "flarmId": null
#   }
# }
```

### Complete POST Configuration Workflow

```bash
# 1. Fetch current config
CURRENT=$(curl -s http://192.168.4.1/setup/?action=get)

# 2. Modify vfrSquawk (1200 → 7000)
MODIFIED=$(echo $CURRENT | jq '.setup.vfrSquawk = 7000')

# 3. POST modified config
curl -X POST \
  -H "Content-Type: application/json" \
  -d "$MODIFIED" \
  http://192.168.4.1/setup/?action=set

# Output: OK

# 4. Wait 2 seconds (CRITICAL!)
sleep 2

# 5. Verify change
curl -s http://192.168.4.1/setup/?action=get | jq '.setup.vfrSquawk'

# Output: 7000
```

### Factory Reset Workflow

```bash
# Send factory reset payload
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"loadDefaults": true}' \
  http://192.168.4.1/setup/?action=set

# Output: OK

# Wait 2 seconds for reset
sleep 2

# Verify reset (should show default config)
curl -s http://192.168.4.1/setup/?action=get | jq .
```

### Transformation Examples

#### ICAO Address (Hex → Int)

```bash
# User input: "7CC599"
# Transform: parseInt("7CC599", 16) = 8177049

# Verify
node -e "console.log(parseInt('7CC599', 16))"
# Output: 8177049

# Reverse: 8177049 → "7CC599"
node -e "console.log((8177049).toString(16).toUpperCase().padStart(6, '0'))"
# Output: 7CC599
```

#### Callsign (Uppercase)

```bash
# User input: "test123"
# Transform: "test123".toUpperCase() = "TEST123"

node -e "console.log('test123'.toUpperCase())"
# Output: TEST123
```

#### Stall Speed (Knots → Device Units)

```bash
# User input: 50 knots
# Transform: ceil(50 × 514.4) = ceil(25720) = 25720

node -e "console.log(Math.ceil(50 * 514.4))"
# Output: 25720

# Reverse: 25720 → 50 knots
node -e "console.log(Math.ceil(25720 / 514.4))"
# Output: 50
```

#### Aircraft Length/Width (Bit-Packing)

```bash
# User input: length=3, width=1
# Transform: (3 << 1) | 1 = 6 | 1 = 7

node -e "console.log((3 << 1) | 1)"
# Output: 7

# Reverse: 7 → length=3, width=1
node -e "console.log('length=' + (7 >> 1) + ', width=' + (7 & 0x01))"
# Output: length=3, width=1
```

#### GPS Antenna Offset (Complex Bit-Packing)

```bash
# User input: lateral=4 (center), longitudinal=10 meters
# Transform: (4 << 5) | ((10/2)+1) = 128 | 6 = 134

node -e "console.log((4 << 5) | ((10/2)+1))"
# Output: 134

# Reverse: 134 → lateral=4, longitudinal=10
node -e "const val=134; const lat=val>>5; const lon=(val&0x1F)?2*((val&0x1F)-1):0; console.log('lat=' + lat + ', lon=' + lon)"
# Output: lat=4, lon=10
```

#### Control Field (Bitmask)

```bash
# User input: UAT mode + 1090ES transmit enabled
# Transform: 0x01 (UAT) | 0x02 (TX) = 0x03

node -e "console.log(0x01 | 0x02)"
# Output: 3

# Reverse: Unpack 3
node -e "const c=3; console.log('UAT=' + ((c&0x01)?'yes':'no') + ', TX=' + ((c&0x02)?'yes':'no'))"
# Output: UAT=yes, TX=yes
```

---

## Summary

### Key Takeaways

1. **JSON API is undocumented** - JavaScript source IS the specification
2. **Always send SIL=1** - Hardcoded, safety-critical
3. **2-second POST delay** - Device needs time to persist changes
4. **Validate ICAO blacklist** - 000000/FFFFFF are invalid
5. **VFR squawk is octal** - Digits 0-7 only (no 8 or 9)
6. **GPS longitude even only** - Odd values get truncated
7. **Callsign auto-uppercase** - Device expects uppercase
8. **Ownship filter uses null** - Not 0 or omitted field
9. **FLARM mode = 0x41** - Bit 0 + bit 6, check FLARM first when unpacking
10. **5-second timeout** - All requests

### Critical Discoveries

- SIL hardcoded to 1 (line 159)
- ICAO/FLARM blacklist (lines 307, 315)
- VFR squawk octal (line 353)
- Callsign uppercase (line 126)
- GPS lon offset even-only (line 410)
- 2-second POST wait (line 173)
- 5-second timeout (lines 116, 248)
- FLARM receiver mode = 0x41 (lines 299, 0x40 | 0x01)
- Factory reset undocumented (lines 254-271)
- Emitter category gaps (lines 330-349)

### Reference Files

- **Transformation formulas**: `../tasks/phase-5-json-api-setup-configuration/transformation-formulas.md`
- **Validation rules**: `../tasks/phase-5-json-api-setup-configuration/validation-specification.md`
- **Critical findings**: `../tasks/phase-5-json-api-setup-configuration/CRITICAL-FINDINGS-SUMMARY.md`
- **Device JavaScript**: `../../packages/skyecho/test/fixtures/setup_page_with_javascript.html`

---

**Document End**

For implementation details, see Phase 5 tasks and alignment brief in `docs/plans/001-dart-repo-foundation-with-mocking/tasks/phase-5-json-api-setup-configuration/`.
