# ForeFlight GDL90 Extension Messages (0x65)

**Date**: 2025-10-23
**Source**: Real SkyEcho device captures + ForeFlight specification
**Purpose**: Document ForeFlight extension message format for parser implementation

---

## Overview

ForeFlight GDL90 Extensions are industry-standard messages (message ID 0x65) used by ADS-B devices to transmit device identification and AHRS (Attitude Heading Reference System) data beyond the FAA GDL90 Public ICD specification.

**Official Specification**: https://www.foreflight.com/connect/spec/

---

## Message Structure

### Top-Level Format

```
Byte 0:    0x65 (Message ID - ForeFlight Extension)
Byte 1:    Sub-ID (0=Device ID, 1=AHRS, 2+=Reserved)
Bytes 2+:  Sub-message payload (format depends on Sub-ID)
```

### Sub-ID Values

| Sub-ID | Name | Purpose | SkyEcho Support |
|--------|------|---------|-----------------|
| 0x00 | Device ID | Device identification and capabilities | ✅ Yes |
| 0x01 | AHRS | Attitude/Heading Reference System data | ❌ Not observed |
| 0x02+ | Reserved | Future extensions | ❌ Unknown |

---

## Device ID Message (Sub-ID 0x00)

### Format

**Total Payload**: 39 bytes (after message ID and sub-ID)

```
Offset  Length  Field                    Type           Notes
------  ------  -----------------------  -------------  ---------------------------
0       1       Sub-ID                   uint8          Always 0x00
1       1       Version                  uint8          Must be 0x01
2       8       Serial Number            uint64 BE      0xFFFFFFFFFFFFFFFF = invalid
10      8       Device Name              UTF-8 string   Null-terminated, padded
18      16      Device Long Name         UTF-8 string   Null-terminated, padded
34      4       Capabilities Mask        uint32 BE      Bitmask (see below)

Total: 38 bytes (0-37)
```

**Note**: BE = Big-Endian (most significant byte first)

### Capabilities Mask Bits

```
Bit  Description
---  ------------------------------------------------------------------
0    Geometric Altitude Datum (0=MSL, 1=WGS84)
1-2  Internet Policy (reserved, usually 0)
3-31 Reserved (set to 0)
```

---

## Captured Samples from SkyEcho

### Sample 1-5 (Identical Messages)

**Captured**: 2025-10-23 from SkyEcho device at 192.168.4.1
**Frequency**: ~1 Hz (every second)
**Count**: 5 identical samples

**Raw Hex Dump** (41 bytes including trailing CRC):
```
65 00 01 00 00 00 00 27 0f ae 2d 53 6b 79 45 63
68 6f 00 53 6b 79 45 63 68 6f 00 00 00 00 00 00
00 00 00 00 00 00 00 2d f0
```

**Byte-by-Byte Analysis**:

```
Offset  Hex        Dec         Field                  Interpretation
------  ---------  ----------  ---------------------  ---------------------------------
0       65         101         Message ID             0x65 (ForeFlight Extension)
1       00         0           Sub-ID                 0x00 (Device ID)
2       01         1           Version                v1 (valid)
3-10    00000000   655740461   Serial Number (BE)     SkyEcho S/N: 655740461
        270FAE2D
11-18   536B7945   "SkyEcho"   Device Name            8-byte UTF-8 string
        63686F00                                      Null-terminated at byte 18
19-34   536B7945   "SkyEcho"   Device Long Name       16-byte UTF-8 string
        63686F00                                      Null-terminated, rest zero-padded
        00000000
        00000000
        00000000
35-38   00000000   0           Capabilities Mask      No special capabilities
39-40   2DF0       11760       CRC-16 (LSB-first)     Trailing CRC bytes
```

### Serial Number Verification

**Calculated from bytes 3-10** (big-endian):
```
0x00000000270FAE2D = 655,740,461 (decimal)
```

**Verification Source**: SkyEcho web interface at `http://192.168.4.1` displays serial "655740461"

**Result**: ✅ Big-endian byte order confirmed correct

### Device Name Extraction

**Bytes 11-18** (device name):
```
Hex:  53 6B 79 45 63 68 6F 00
Char: 'S' 'k' 'y' 'E' 'c' 'h' 'o' '\0'
```

**Extraction Logic**:
1. Read 8 bytes starting at offset 11
2. Find first null byte (0x00) - located at offset 18
3. Decode bytes 11-17 as UTF-8: "SkyEcho"
4. Handle null termination gracefully

**Bytes 19-34** (device long name):
```
Hex:  53 6B 79 45 63 68 6F 00 00 00 00 00 00 00 00 00
Char: 'S' 'k' 'y' 'E' 'c' 'h' 'o' '\0' '\0' ... (zero padding)
```

Same extraction logic for 16-byte field.

---

## CRC Trailing Bytes Analysis

### Observation

Captured samples include **41 bytes total**:
- 2 bytes: Message ID (0x65) + Sub-ID (0x00)
- 37 bytes: Device ID payload (version through capabilities)
- **2 bytes: Trailing CRC (0x2D 0xF0)**

### Question

ForeFlight specification shows Device ID message as 39 bytes (after message ID), but captured samples are 41 bytes. The extra 2 bytes (0x2D 0xF0) appear to be CRC-16 in LSB-first format.

### Hypothesis

GDL90 framing adds CRC-16 to **all** messages before transmission. The framer may or may not strip this CRC before passing clear message bytes to the parser.

### Resolution Required

**ST001b Task**: Investigate `lib/src/framer.dart` to determine if:
- **Scenario A**: Framer strips CRC → Parser receives 39 bytes (2 header + 37 payload)
- **Scenario B**: Framer keeps CRC → Parser receives 41 bytes (2 header + 37 payload + 2 CRC)

This affects parser length validation logic in ST013.

---

## AHRS Message (Sub-ID 0x01)

### Status

**Not observed** from SkyEcho device during 5-minute capture session.

### Interpretation

SkyEcho does not appear to send AHRS data (attitude, heading, slip/skid). This aligns with device capabilities - SkyEcho is a GPS/ADS-B receiver, not an attitude sensor.

### Parser Strategy

Implement AHRS parsing conditionally:
1. Add model fields (ST004)
2. Write tests (ST009) - may skip if no fixtures available
3. Implement parser (ST014) - graceful handling of unknown sub-IDs covers future AHRS support
4. Emit error event for sub-ID 0x01 until confirmed device support

---

## Implementation Notes

### Critical Findings

1. **Big-Endian Fields**: Serial number (8 bytes) and capabilities (4 bytes) use big-endian byte order
   - **Unusual** for GDL90 which typically uses little-endian or bit-packed fields
   - Must implement explicit big-endian conversion

2. **UTF-8 String Handling**: Device names are null-terminated UTF-8 strings
   - Find null terminator (0x00) to determine actual string length
   - Decode only up to null terminator, ignore padding
   - **Exception Safety**: Wrap `utf8.decode()` in try-catch to maintain "never throw" pattern

3. **Message Rate**: Broadcasts every ~1 second
   - Same cadence as heartbeat messages
   - Example tools should display device info once, not flood console

4. **CRC Uncertainty**: See ST001b investigation task
   - Must determine if parser receives 39 or 41 bytes
   - Critical for length validation

### Error Handling Requirements

Per Phase 8 "never throw" architectural pattern:

```dart
// ✅ CORRECT - Maintain "never throw" pattern
try {
  deviceName = utf8.decode(nameBytes.sublist(0, endIndex));
} catch (e) {
  return _error('Invalid UTF-8 in ForeFlight device name: $e');
}

// ❌ WRONG - Throws FormatException
deviceName = utf8.decode(nameBytes); // Can throw!
```

### Parser Integration Points

1. **Routing Table** (lib/src/parser.dart):
   ```dart
   case 0x65:
     return _parseForeFlight(payload);
   ```

2. **Sub-ID Dispatcher**:
   ```dart
   Gdl90Event _parseForeFlight(Uint8List payload) {
     final subId = payload[0];
     switch (subId) {
       case 0x00: return _parseForeFlight Id(payload);
       case 0x01: return _parseForeFlight Ahrs(payload);
       default: return _error('Unknown ForeFlight sub-ID: 0x${subId.toRadixString(16)}');
     }
   }
   ```

3. **Model Extensions** (lib/src/models/gdl90_message.dart):
   - Add nullable fields: `serialNumber`, `deviceName`, `deviceLongName`, `capabilitiesMask`
   - Add enum value: `Gdl90MessageType.foreFlightId`

---

## Test Strategy

### Fixture

Captured binary saved to: `test/fixtures/foreflight_id_message.bin` (41 bytes)

### Test Coverage

| Test ID | Purpose | Fixture |
|---------|---------|---------|
| ST005 | Full Device ID parsing | foreflight_id_message.bin |
| ST005b | Routing integration (0x65 → parser) | foreflight_id_message.bin |
| ST006 | UTF-8 string decoding | foreflight_id_message.bin |
| ST006b | Invalid UTF-8 error handling | Hand-crafted: `[0xFF, 0xFF, ...]` |
| ST007 | Big-endian integer conversion | foreflight_id_message.bin |
| ST008 | Capabilities bitmask parsing | foreflight_id_message.bin |
| ST010 | Unknown sub-ID graceful handling | Hand-crafted: sub-ID 0x99 |

### Expected Test Results (RED Phase)

Before implementation (ST011 RED gate):
- All tests should **FAIL** with messages like:
  - "Unknown message ID: 0x65"
  - "No such method: foreFlightId"
  - "Expected Gdl90DataEvent, got Gdl90ErrorEvent"

After implementation (ST016 GREEN gate):
- All tests should **PASS** with:
  - Device name: "SkyEcho"
  - Serial: 655740461
  - Capabilities: 0
  - Message type: Gdl90MessageType.foreFlightId

---

## References

- **ForeFlight Specification**: https://www.foreflight.com/connect/spec/
- **Capture Tool**: `packages/skyecho_gdl90/example/capture_0x65.dart`
- **Fixture Location**: `packages/skyecho_gdl90/test/fixtures/foreflight_id_message.bin`
- **Subtask Dossier**: `docs/plans/002-gdl90-receiver-parser/tasks/phase-8-stream-transport-layer/001-subtask-foreflight-extension-messages-0x65-support.md`

---

## Next Steps

1. ✅ **ST001 Complete** - Documentation created
2. 🔄 **ST001b** - Investigate framer CRC behavior
3. ⏳ **ST002-ST004** - Add model extensions
4. ⏳ **ST005-ST010** - Write TDD tests (RED phase)
5. ⏳ **ST012-ST015** - Implement parsers (GREEN phase)
