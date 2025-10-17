# Phase 5 Tasks + Alignment Brief: JSON API - Setup Configuration

**Phase**: Phase 5 - JSON API - Setup Configuration
**Plan**: [dart-repo-foundation-with-mocking-plan.md](../../dart-repo-foundation-with-mocking-plan.md)
**Spec**: [docs/initial-details.md](/Users/jordanknight/github/skyecho-controller-app/docs/initial-details.md)
**Date**: 2025-10-17

---

## Tasks

| Status | ID | Task | Type | Dependencies | Absolute Path(s) | Validation | Notes |
|--------|----|----|------|--------------|------------------|------------|-------|
| [ ] | T001 | Capture JSON fixture from real device | Setup | – | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/fixtures/setup_config_sample.json | JSON file exists with setup{} and ownshipFilter{} objects | `curl 'http://192.168.4.1/setup/?action=get' > setup_config_sample.json` |
| [ ] | T002 | Write scratch probes for JSON GET /setup/?action=get | Test | T001 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/scratch/setup_config_scratch.dart | 3-5 probes testing json.decode(), structure analysis | New file; verify nested objects |
| [ ] | T003 | Write scratch probes for SetupConfig.fromJson() | Test | T002 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/scratch/setup_config_scratch.dart | 8-10 probes testing all fields from JSON | Map JSON → Dart properties |
| [ ] | T004 | Write scratch probes for hex conversion (icaoAddress) | Test | T003 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/scratch/setup_config_scratch.dart | 5-8 probes for string → int conversion | Test FFFFFF, 000000, padding, 0x prefix |
| [ ] | T005 | Write scratch probes for bitmask operations | Test | T004 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/scratch/setup_config_scratch.dart | 10-15 probes for bit extraction/setting | Test all bit positions 0-7 |
| [ ] | T006 | Write scratch probes for bit-packing (adsbInCapability) | Test | T005 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/scratch/setup_config_scratch.dart | 8-10 probes for 8-bit field encoding | UAT, 1090ES, TCAS flags |
| [ ] | T007 | Write scratch probes for bit-packing (control field) | Test | T006 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/scratch/setup_config_scratch.dart | 8-10 probes for control byte encoding | Transmit enable, receiverMode bits |
| [ ] | T008 | Write scratch probes for unit conversions (stallSpeed) | Test | T007 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/scratch/setup_config_scratch.dart | 5-8 probes for knots → device units | Test rounding, edge cases |
| [ ] | T009 | Implement SetupConfig class structure | Core | T003 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/lib/skyecho.dart | Constructor with all fields matching JSON structure | Immutable class with final fields |
| [ ] | T010 | Implement SetupConfig.fromJson() | Core | T009 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/lib/skyecho.dart | Parse JSON map → SetupConfig with transformations | Hex decode, bit unpack |
| [ ] | T011 | Implement SetupConfig.toJson() | Core | T010 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/lib/skyecho.dart | SetupConfig → JSON map with transformations | Hex encode, bit pack |
| [ ] | T012 | Implement hex conversion helper (_hexToInt) | Core | T004 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/lib/skyecho.dart | String → int hex conversion | Handle 0x prefix, padding to 6 chars |
| [ ] | T013 | Implement hex conversion helper (_intToHex) | Core | T012 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/lib/skyecho.dart | Int → string hex conversion | Pad to 6 chars, uppercase |
| [ ] | T014 | Implement bitmask helper (_getBit) | Core | T005 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/lib/skyecho.dart | Extract single bit from int | bit position 0-7 |
| [ ] | T015 | Implement bitmask helper (_setBit) | Core | T014 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/lib/skyecho.dart | Set single bit in int | bit position 0-7, bool value |
| [ ] | T016 | Implement bit-packing helper (_packAdsbInCapability) | Core | T006, T015 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/lib/skyecho.dart | 8 bools → int (UAT, 1090ES, TCAS flags) | Per device encoding schema |
| [ ] | T017 | Implement bit-packing helper (_packControl) | Core | T007, T015 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/lib/skyecho.dart | Transmit, receiverMode → control int | Per device encoding schema |
| [ ] | T018 | Implement unit conversion helper (_knotsToDeviceUnits) | Core | T008 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/lib/skyecho.dart | stallSpeed knots → device encoding | Document formula, handle rounding |
| [ ] | T019 | Implement SetupUpdate class | Core | – | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/lib/skyecho.dart | Builder pattern with typed fields | icaoHex, callsign, transmit, etc. |
| [ ] | T020 | Implement SetupConfig.applyUpdate() | Core | T019 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/lib/skyecho.dart | Apply SetupUpdate changes to SetupConfig | Returns new immutable SetupConfig |
| [ ] | T021 | Implement SkyEchoClient.fetchSetupConfig() | Core | T010 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/lib/skyecho.dart | GET /setup/?action=get, parse JSON | HTTP + JSON integration |
| [ ] | T022 | Implement SkyEchoClient._postJson() helper | Core | – | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/lib/skyecho.dart | POST JSON body to URL | Content-Type: application/json |
| [ ] | T023 | Implement SkyEchoClient.applySetup() with verification | Core | T021, T022 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/lib/skyecho.dart | POST → wait → GET → compare values | Detect silent rejections |
| [ ] | T024 | Implement ApplyResult class | Core | T023 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/lib/skyecho.dart | Verification result with mismatches | verified flag, mismatches map |
| [ ] | T025 | Write scratch probes for roundtrip (apply + verify) | Test | T023 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/scratch/setup_config_scratch.dart | Test POST + GET verification flow | Real device testing |
| [ ] | T026 | Promote hex conversion tests to unit/setup_config_test.dart | Test | T012, T013 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/unit/setup_config_test.dart | 2-3 tests with Test Docs | Edge cases, padding, 0x prefix |
| [ ] | T027 | Promote bitmask tests | Test | T014, T015 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/unit/setup_config_test.dart | 2-3 tests with Test Docs | All bit positions 0-7 |
| [ ] | T028 | Promote bit-packing tests (adsbInCapability) | Test | T016 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/unit/setup_config_test.dart | 2-3 tests with Test Docs | All flag combinations |
| [ ] | T029 | Promote bit-packing tests (control) | Test | T017 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/unit/setup_config_test.dart | 2-3 tests with Test Docs | Transmit + receiverMode |
| [ ] | T030 | Promote unit conversion tests | Test | T018 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/unit/setup_config_test.dart | 2-3 tests with Test Docs | Rounding, edge values |
| [ ] | T031 | Promote SetupConfig.applyUpdate() tests | Test | T020 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/unit/setup_config_test.dart | 3-4 tests with Test Docs | Various field updates |
| [ ] | T032 | Promote verification tests | Test | T023 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/unit/setup_config_test.dart | 2-3 tests with Test Docs | POST + GET verification, silent rejection |
| [ ] | T033 | Promote fromJson/toJson roundtrip tests | Test | T010, T011 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/unit/setup_config_test.dart | 2-3 tests with Test Docs | JSON → SetupConfig → JSON |
| [ ] | T034 | Delete non-valuable scratch tests | Cleanup | T026-T033 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/scratch/setup_config_scratch.dart | Only promoted tests remain in unit/ | Capture learning in execution log |
| [ ] | T035 | Verify 90%+ coverage on transformation logic | Validation | T034 | Command: dart run coverage:test_with_coverage | Coverage tool confirms 90%+ on transformations | Constitution requirement |
| [ ] | T036 | Create integration test with real device | Test | T035 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/integration/setup_config_integration_test.dart | Test applySetup() roundtrip against live device | Verify JSON POST API works |

**Total**: 36 tasks

---

## Alignment Brief

### Objective

Implement **SetupConfig** parsing from JSON API endpoints instead of HTML form scraping. Use GET `/setup/?action=get` to fetch configuration, apply high-level SetupUpdate changes to JSON structure, POST to `/setup/?action=set`, and verify changes with GET. Handle bit-packing (adsbInCapability, control, etc.), hex conversion (icaoAddress), and unit conversion (stallSpeed).

**Behavior Checklist**:
- [x] SetupConfig parses JSON from /setup/?action=get
- [x] All transformation functions (bit-pack, hex, unit conversion) implemented
- [x] SetupUpdate → JSON mapping complete
- [x] POST /setup/?action=set with JSON body
- [x] Verification with GET after POST (device may silently reject)
- [x] 90% coverage on transformation logic
- [x] 15-20 promoted tests with Test Doc blocks
- [x] Real device integration test validates roundtrip

---

### Non-Goals (Scope Boundaries)

Phase 5 focuses on **JSON API - Setup Configuration**. The following are explicitly **NOT** in scope:

❌ **NOT doing in this phase**:
- **No HTML parsing** - JSON API makes HTML scraping obsolete
- **No FormField classes** - No TextField, CheckboxField, RadioGroupField, SelectField needed
- **No label inference** - JSON has fixed field names, no fuzzy matching
- **No radio grouping logic** - JSON uses int bitmasks instead
- **No form field cloning** - JSON is immutable by default
- **No GDL90 stream implementation** - Still deferred to future phase
- **No web CORS proxy** - Still out of scope
- **No integration with GDL90** - Placeholder types only

**Rationale**: JSON API is dramatically simpler than HTML parsing - no DOM traversal, no field extraction, no label matching. Focus on correct transformations (bit-packing, hex, units).

---

### Critical Findings Affecting This Phase

#### 🚨 Critical Discovery 06: JSON REST API Available

**What it changes**: Entire Phase 5 approach - JSON API replaces HTML form scraping

**Impact on Phase 5**:
- No HTML parsing needed for setup configuration
- Use GET /setup/?action=get for current config
- Use POST /setup/?action=set for updates
- Simple JSON mapping instead of DOM traversal
- Much simpler testing (mock JSON responses)

**Verified**: Real device tests confirm JSON API works

**Tasks addressing this**: All tasks (T001-T036) use JSON approach

---

#### 🚨 Critical Discovery 07: Device Silently Rejects Invalid Values

**What it requires**: Mandatory verification after POST

**Impact on Phase 5**:
- Device returns HTTP 200 "Update successful" even when rejecting values
- MUST GET /setup/?action=get after POST to verify changes
- Compare expected vs actual values
- Report mismatches in ApplyResult

**Example**: POST vfrSquawk=7000 → 200 OK, but GET returns vfrSquawk=1200 (rejected)

**Tasks addressing this**: T023 (applySetup with verification), T032 (verification tests)

---

### Ready Check

**Before proceeding to implementation** (`/plan-6-implement-phase`), verify:

- [ ] Phase 4 complete (JSON API for DeviceStatus)
- [ ] Real device accessible at 192.168.4.1
- [ ] JSON fixture captured: test/fixtures/setup_config_sample.json
- [ ] Test suite currently < 5 seconds
- [ ] Bit-packing formulas documented
- [ ] Verification strategy clear (POST → wait → GET → compare)

**GO/NO-GO Decision**:
- [ ] **GO**: All checkboxes above are checked; proceed with `/plan-6-implement-phase`
- [ ] **NO-GO**: Missing prerequisites; resolve blockers before implementation

---

**Phase 5 Status**: Ready for implementation with JSON API approach

**Next Step**: Run `/plan-6-implement-phase --phase "Phase 5: JSON API - Setup Configuration" --plan "/Users/jordanknight/github/skyecho-controller-app/docs/plans/001-dart-repo-foundation-with-mocking/dart-repo-foundation-with-mocking-plan.md"`
