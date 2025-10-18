# Phase 7: Integration Test Framework - Tasks & Alignment Brief

**Plan**: [dart-repo-foundation-with-mocking-plan.md](../../dart-repo-foundation-with-mocking-plan.md)
**Spec**: [dart-repo-foundation-with-mocking-spec.md](../../dart-repo-foundation-with-mocking-spec.md)
**Phase**: Phase 7 - Integration Test Framework
**Status**: PENDING
**Created**: 2025-10-18

---

## Tasks

### Task Status Legend
- `[ ]` = Pending (not started)
- `[~]` = In Progress
- `[x]` = Complete

| Status | ID | Task | Type | Dependencies | Absolute Path(s) | Validation | Notes |
|--------|----|----|------|--------------|------------------|------------|-------|
| [ ] | T001 | Review existing integration test files to understand current patterns | Setup | – | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/integration/device_status_integration_test.dart, /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/integration/setup_config_integration_test.dart | Both files reviewed, device detection patterns documented | Serial (analysis before refactor) |
| [ ] | T002 | Create test/integration/helpers.dart with canReachDevice() function | Core | T001 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/integration/helpers.dart | Function accepts URL string, returns Future&lt;bool&gt;, handles exceptions with 5s timeout | [P] eligible (new file) |
| [ ] | T003 | Add deviceSetupMessage() helper for consistent skip messages | Core | T002 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/integration/helpers.dart | Returns String with WiFi network setup instructions | Serial (same file as T002) |
| [ ] | T004 | Add printDeviceInfo() helper for consistent debug output | Core | T002 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/integration/helpers.dart | Accepts DeviceStatus or SetupConfig, prints formatted info | Serial (same file as T002) |
| [ ] | T005 | Refactor device_status_integration_test.dart to use helpers | Core | T002 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/integration/device_status_integration_test.dart | Import helpers, use canReachDevice() instead of inline ping(), use deviceSetupMessage() | [P] eligible (independent from T006) |
| [ ] | T006 | Refactor setup_config_integration_test.dart to use helpers | Core | T002 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/integration/setup_config_integration_test.dart | Add device detection with canReachDevice(), all tests skip gracefully if unavailable | [P] eligible (independent from T005) |
| [ ] | T006a | Add safety assertion to setup_config_integration_test.dart roundtrip test | Core | T006 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/integration/setup_config_integration_test.dart | After applySetup() roundtrip, assert es1090TransmitEnabled remains false (SAFETY CRITICAL) | Serial (same file as T006) - SAFETY CRITICAL |
| [ ] | T007 | Verify test-integration recipe exists in justfile | Setup | – | /Users/jordanknight/github/skyecho-controller-app/justfile | Recipe test-integration runs dart test test/integration/ | Already complete from Phase 1 (lines 33, 59) |
| [ ] | T008 | Test graceful skip behavior without device | Integration | T002, T005, T006 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/integration/ | Run `just test-integration` with device disconnected, verify skip messages appear, no test failures | Manual verification required |
| [ ] | T009 | Test integration tests with device available | Integration | T002, T005, T006 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/integration/ | Run `just test-integration` with device connected, all tests pass | Manual verification with physical device |
| [ ] | T010 | Verify all integration tests have complete Test Doc blocks | Integration | T005, T006 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/integration/*.dart | All promoted integration tests include 5-field Test Doc comment (Why, Contract, Usage Notes, Quality Contribution, Worked Example) | Manual review of all test files |
| [ ] | T011 | Document integration test patterns in execution log | Doc | T010 | /Users/jordanknight/github/skyecho-controller-app/docs/plans/001-dart-repo-foundation-with-mocking/tasks/phase-7-integration-test-framework/execution.log.md | Execution log captures device detection pattern, skip pattern, helper usage | Completed when execution log finalized |

**Total Tasks**: 11 (2 Setup, 6 Core including 1 SAFETY CRITICAL, 0 Test, 1 Doc, 2 Integration)

**Estimated Complexity**: LOW-MEDIUM (mostly refactoring existing tests + documentation)

---

## Alignment Brief

### Objective Recap

**Primary Goal**: Formalize integration test infrastructure that gracefully detects device availability and skips tests when the physical SkyEcho device is not accessible.

**Behavior Checklist** (from plan acceptance criteria):
- [ ] Integration test helper detects device availability with 5-second timeout
- [ ] Existing integration tests from Phases 4-5 refactored to use shared helpers (5 total tests: 2 in device_status + 3 in setup_config)
- [ ] Tests skip gracefully with clear message when device unavailable
- [ ] ~~README documents integration test setup~~ → **DEFERRED to Phase 9** (decision from didyouknow session)
- [ ] justfile has test-integration recipe (already complete from Phase 1)
- [ ] All integration tests pass when device available

**Success Criteria**:
1. Shared `helpers.dart` provides reusable device detection
2. All integration tests use consistent device detection pattern
3. Clear, actionable skip messages guide users to connect to device
4. ~~README documents integration test workflow~~ → **DEFERRED to Phase 9**
5. Zero test failures when device unavailable (graceful skips only)
6. All tests pass when device is available

---

### Non-Goals (Scope Boundaries)

❌ **NOT doing in this phase:**
- Performance optimization of integration tests (defer to Phase 10)
- Mocking integration tests (integration tests MUST use real device)
- CI/CD configuration for integration tests (out of scope per plan)
- Automated device provisioning or reset between tests (manual setup acceptable)
- Testing with multiple firmware versions (single version sufficient per plan)
- Advanced test orchestration (parallel test execution, test ordering)
- Integration test coverage metrics (unit test coverage targets only)
- Web-based integration tests (device URL requires CORS proxy, out of scope)
- **Creating new integration test cases** (existing tests from Phases 4-5 provide sufficient coverage - decision from didyouknow session)
- Refactoring unit tests (only integration tests in scope)
- **Testing ADS-B transmission (1090ES transmit)** - SAFETY CRITICAL: Integration tests MUST NOT enable ADS-B output as this would transmit false aircraft position data visible to other aircraft and ATC

---

### Critical Findings Affecting This Phase

**Relevant Critical Discoveries from Plan § 3:**

1. **🚨 Critical Discovery 02: MockClient HTTP Response Handling**
   - **Constraint**: Integration tests MUST use real `http.Client`, not `MockClient`
   - **Tasks addressing**: T002 (canReachDevice uses real HTTP client), T015/T016 (validation with real device)
   - **Impact**: Ensures integration tests catch real device communication issues that mocks would hide

2. **🚨 Critical Discovery 04: Cookie Jar Without Sessions Library**
   - **Constraint**: Integration tests rely on `SkyEchoClient`'s internal `_CookieJar` for session management
   - **Tasks addressing**: T008, T009, T010 (smoke tests use real client with cookie management)
   - **Impact**: Integration tests validate cookie persistence across multiple requests (e.g., POST → GET verification)

**Note**: Most critical discoveries (01, 03, 05) relate to HTML parsing and are not applicable to Phase 7 integration test infrastructure.

---

### Invariants & Guardrails

**Performance Budget**:
- Device detection timeout: **5 seconds** (matches SkyEchoClient default, proven in Phases 4-5, tolerates network latency)
- Integration test suite total time: **No strict limit** (device I/O inherently slower than unit tests)
- Per-test timeout: **10-20 seconds** (allows for network latency + device processing)

**Memory Budget**:
- No in-memory caching of responses (each test makes fresh HTTP calls)
- Small test fixture sizes (JSON responses ~1-15KB)

**Security**:
- Device URL hardcoded to `http://192.168.4.1` (private network, no auth)
- No sensitive data in test outputs (device status is non-sensitive)
- Document security implications in README (anyone on WiFi network can control device)

**SAFETY CRITICAL - ADS-B Transmission**:
- ⚠️ **ABSOLUTE PROHIBITION**: Integration tests MUST NEVER enable 1090ES transmit (`es1090TransmitEnabled` field in SetupConfig)
- **Rationale**: Enabling ADS-B transmission would broadcast false aircraft position data on 1090MHz, visible to other aircraft TCAS systems and ATC radar, creating serious safety hazard
- **Enforcement**:
  - All `applySetup()` calls in integration tests MUST NOT set `es1090TransmitEnabled` field (omit it, defaults to false)
  - T006a adds explicit assertion in roundtrip test: `expect(result.verifiedConfig!.es1090TransmitEnabled, isFalse)`
  - Tests that modify other transmit-related settings (receiverMode, uatEnabled, es1090Enabled) MUST verify `es1090TransmitEnabled` remains false
  - Document WARNING in README integration test section (T012)
- **In-Flight Testing**: ADS-B transmission testing deferred to manual in-flight validation by pilot (out of scope for automated tests)

---

### Inputs to Read

**Existing Code** (absolute paths):
- `/Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/integration/device_status_integration_test.dart` - Current device detection pattern using `ping()`
- `/Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/integration/setup_config_integration_test.dart` - No device detection, needs refactor
- `/Users/jordanknight/github/skyecho-controller-app/packages/skyecho/lib/skyecho.dart` - SkyEchoClient with ping(), fetchStatus(), fetchSetupConfig()
- `/Users/jordanknight/github/skyecho-controller-app/justfile` - Existing test-integration recipe (lines 33, 59)

**Plan Documents**:
- `../../dart-repo-foundation-with-mocking-plan.md` - Phase 7 section (lines 887-977)
- `../../dart-repo-foundation-with-mocking-spec.md` - Testing philosophy, integration test requirements

**Reference Materials**:
- `docs/rules-idioms-architecture/constitution.md` - Guiding principles
- `docs/rules-idioms-architecture/rules.md` - MUST/SHOULD standards
- `CLAUDE.md` - Integration test workflow, TAD philosophy

---

### Visual Alignment Aids

#### Integration Test Flow Diagram (System States)

```mermaid
stateDiagram-v2
    [*] --> TestStart
    TestStart --> DeviceDetection: setUpAll()

    DeviceDetection --> DeviceAvailable: canReachDevice() = true
    DeviceDetection --> DeviceUnavailable: canReachDevice() = false (timeout 2s)

    DeviceAvailable --> RunTests: Execute test body
    DeviceUnavailable --> SkipTests: markTestSkipped()

    RunTests --> DeviceAPICall: client.ping() / fetchStatus() / fetchSetupConfig()

    DeviceAPICall --> AssertResults: HTTP 200, JSON parsed
    DeviceAPICall --> TestFailure: Network error, parse error, assertion failure

    AssertResults --> PrintDebugInfo: Print device status/config
    PrintDebugInfo --> TestSuccess

    SkipTests --> PrintSkipMessage: deviceSetupMessage()
    PrintSkipMessage --> TestSkipped

    TestSuccess --> [*]
    TestFailure --> [*]
    TestSkipped --> [*]
```

#### Integration Test Sequence Diagram (Actor/Interaction Order)

```mermaid
sequenceDiagram
    participant TestRunner as Dart Test Runner
    participant TestFile as Integration Test
    participant Helper as helpers.dart
    participant Client as SkyEchoClient
    participant Device as SkyEcho Device (192.168.4.1)

    Note over TestRunner,Device: Test Suite Initialization (setUpAll)

    TestRunner->>TestFile: Execute setUpAll()
    TestFile->>Helper: canReachDevice('http://192.168.4.1')
    Helper->>Client: Create temp client, call ping()
    Client->>Device: GET / (timeout 2s)

    alt Device Available
        Device-->>Client: HTTP 200 OK
        Client-->>Helper: true
        Helper-->>TestFile: deviceAvailable = true
        TestFile-->>TestRunner: setUpAll complete

        Note over TestRunner,Device: Test Execution

        TestRunner->>TestFile: Execute test case
        TestFile->>Client: fetchStatus() / fetchSetupConfig() / ping()
        Client->>Device: GET /?action=get (with cookies)
        Device-->>Client: HTTP 200 + JSON body
        Client-->>TestFile: Parsed DeviceStatus/SetupConfig
        TestFile->>TestFile: Assert expectations
        TestFile->>Helper: printDeviceInfo(status)
        Helper-->>TestRunner: Print debug output
        TestFile-->>TestRunner: Test PASS
    else Device Unavailable
        Device--xClient: Timeout (2s)
        Client-->>Helper: Exception caught
        Helper-->>TestFile: false
        TestFile-->>TestRunner: deviceAvailable = false
        TestFile->>Helper: deviceSetupMessage()
        Helper-->>TestFile: "⚠️  Connect to SkyEcho WiFi..."
        TestFile-->>TestRunner: Print skip message

        Note over TestRunner,Device: Test Skipping

        TestRunner->>TestFile: Execute test case
        TestFile->>TestFile: if (!deviceAvailable) markTestSkipped()
        TestFile-->>TestRunner: Test SKIPPED
    end
```

---

### Test Plan

**Testing Approach**: Lightweight (per spec) - Focus on manual verification and smoke tests, not exhaustive integration test coverage.

**Test Categories**:

1. **Smoke Tests** (device_smoke_test.dart):
   - `test_ping_smoke` - Verify ping() returns true with real device
   - `test_fetch_status_smoke` - Verify fetchStatus() returns non-null status
   - `test_fetch_setup_config_smoke` - Verify fetchSetupConfig() returns non-null config

2. **Existing Integration Tests** (refactored to use helpers):
   - device_status_integration_test.dart (2 tests from Phase 4)
   - setup_config_integration_test.dart (3 tests from Phase 5, 1 skipped)

3. **Manual Validation Tests**:
   - Run with device connected → all tests pass
   - Run without device → all tests skip with clear message
   - Verify timeout behavior (2s max for device detection)

**Test Fixtures**:
- No new fixtures needed (use real device responses)
- Existing JSON fixtures from Phases 4-5 used in unit tests, not integration tests

**Expected Outputs**:
- **Device available**: 5 integration tests pass, debug output shows real device data
- **Device unavailable**: 5 integration tests skipped, skip message shows WiFi setup instructions

**Test Doc Requirements**:
- All integration tests MUST include complete Test Doc blocks (5 fields)
- Test names follow Given-When-Then pattern
- Arrange-Act-Assert structure in test bodies

---

### Step-by-Step Implementation Outline

**Phase 1: Create Shared Helper Infrastructure** (T001-T004)
1. Review existing integration test patterns (T001)
2. Create `test/integration/helpers.dart` (T002)
   - `canReachDevice(String url)` - Attempts ping with 5s timeout, returns bool
   - `deviceSetupMessage()` - Returns formatted skip message string
   - `printDeviceInfo(dynamic)` - Prints status/config for debugging
3. Write dartdoc comments for all helper functions
4. Validate: Run `dart analyze` on helpers.dart

**Phase 2: Refactor Existing Integration Tests** (T005-T006a)
1. Update device_status_integration_test.dart (T005)
   - Import helpers
   - Replace inline ping() detection with canReachDevice()
   - Use deviceSetupMessage() for skip warning
   - Validate: Run test without device, verify skip
2. Update setup_config_integration_test.dart (T006)
   - Add setUpAll with canReachDevice()
   - Add device detection to all tests
   - Use deviceSetupMessage() for skip warning
   - Validate: Run test without device, verify skip
3. **SAFETY CRITICAL**: Add ADS-B transmission safety assertion (T006a)
   - In "applies setup configuration and verifies roundtrip" test (line 43)
   - **Known baseline state approach**: Test already fetches original config at start, establishing known state
   - After `result.verifiedConfig!.callsign` assertion (line 72), add:
     ```dart
     expect(result.verifiedConfig!.es1090TransmitEnabled, isFalse,
         reason: 'SAFETY: 1090ES transmit must remain disabled in integration tests');
     ```
   - This prevents accidental enabling of ADS-B broadcast during automated testing
   - Validates device did not silently enable transmit during config update
   - Note: This test serves as **early warning** - if config updates don't work, fail fast

**Phase 3: Validation** (T007-T011)
1. Verify justfile recipe (T007) - Already complete
2. Test without device (T008) - Manual verification
3. Test with device (T009) - Manual verification with physical device
4. Review Test Doc completeness (T010)
5. Document patterns in execution log (T011)

**Checkpoints**:
- After Phase 1: helpers.dart analyzed clean
- After Phase 2: Existing tests skip gracefully without device, safety assertion added
- After Phase 3: All acceptance criteria met (README deferred to Phase 9)

---

### Commands to Run

**Development Workflow**:
```bash
# Navigate to library package
cd packages/skyecho

# Create helpers.dart
# (manual file creation)

# Run analyzer on helpers
dart analyze test/integration/helpers.dart

# Run integration tests (device required)
just test-integration

# Run integration tests (device unavailable - test skip behavior)
# Disconnect from SkyEcho WiFi, then:
just test-integration

# Run specific integration test file
dart test test/integration/device_smoke_test.dart

# Run specific test by name
dart test --name "ping_smoke"

# Run with verbose output
dart test test/integration/ -r expanded
```

**Validation Commands**:
```bash
# Full test suite (unit + integration)
just test

# Verify analyzer clean
just analyze

# Format all code
just format

# Full validation
just validate
```

**Manual Testing Checklist**:
- [ ] Connect to SkyEcho WiFi network (SSID: SkyEcho_XXXX)
- [ ] Run `just test-integration` → all tests pass
- [ ] Disconnect from SkyEcho WiFi
- [ ] Run `just test-integration` → all tests skipped with clear message
- [ ] Verify timeout is ~5 seconds (not hanging indefinitely, but tolerates network latency)
- [ ] Check skip message includes WiFi setup instructions

---

### Risks/Unknowns

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| **⚠️ SAFETY CRITICAL: ADS-B transmission accidentally enabled** | **CRITICAL** | **LOW** | **T006a adds explicit assertion that enable1090ESTransmit remains false after all config updates; README WARNING; code review required** |
| **Device not always available during development** | LOW | HIGH | Graceful skip is core feature; tests MUST skip cleanly |
| **Network configuration varies (WiFi SSID changes)** | LOW | MEDIUM | Document WiFi setup clearly in README; use standard device URL |
| **Timeout too short (false negatives)** | LOW | LOW | Use 5-second timeout (matches SkyEchoClient default, proven in Phases 4-5); tolerates network latency |
| **Timeout too long (slow test feedback)** | LOW | LOW | 5-second timeout only affects device unavailable scenario (once per test run) |
| **Integration tests flaky due to device state** | MEDIUM | MEDIUM | Use defensive assertions (isNotNull vs exact values); document in Test Docs |
| **Destructive tests (factory reset) run accidentally** | HIGH | LOW | Use `skip: true` on destructive tests; document WARNING in Test Doc |
| **Multiple developers sharing same device** | LOW | LOW | Document sequential test execution; no parallel support needed |
| **README becomes stale as API evolves** | MEDIUM | MEDIUM | Phase 9 documentation update will refresh; keep examples minimal |

---

### Ready Check

**Prerequisites** (must be true before implementation):
- [ ] Phases 1-5 complete (project structure, error hierarchy, JSON API, setup config)
- [ ] Phase 6 confirmed skipped/obsolete (HTML parsing unnecessary)
- [ ] Integration tests from Phases 4-5 exist and passing with device
- [ ] justfile test-integration recipe exists (from Phase 1)
- [ ] Physical SkyEcho device available for validation

**Pre-Implementation Checklist**:
- [ ] Plan Phase 7 acceptance criteria reviewed and understood
- [ ] Existing integration test files reviewed (T001)
- [ ] Device detection patterns documented
- [ ] Mermaid diagrams reviewed and approved
- [ ] Critical findings understood (Discovery 02, 04)

**GO/NO-GO Decision Points**:
1. **After T004 (helpers created)**: Do helper functions cover all needed patterns? → GO if yes
2. **After T006 (refactor complete)**: Do existing tests skip gracefully? → GO if yes
3. **After T010 (smoke tests created)**: Do smoke tests pass with device? → GO if yes
4. **After T013 (README written)**: Is integration test workflow clear? → GO if yes
5. **After T017 (validation complete)**: All acceptance criteria met? → GO to Phase 8 if yes

**Explicit User Approval Required**:
- ⚠️ **Before T016 (test with device)**: Confirm physical device available and accessible
- ⚠️ **Before marking phase complete**: Review execution log and README documentation

---

## Phase Footnote Stubs

**Note**: This section will be populated during `/plan-6-implement-phase` execution. Footnote tags (e.g., `[^14]`, `[^15]`) will be added to plan.md's Change Footnotes Ledger with implementation details.

Placeholder for future footnotes:
- Helpers implementation details (canReachDevice, deviceSetupMessage, printDeviceInfo)
- Integration test refactoring (device_status, setup_config)
- Smoke test creation (device_smoke_test.dart)
- README documentation updates
- Validation results (skip behavior, device availability tests)

---

## Evidence Artifacts

**Execution Log**: `/Users/jordanknight/github/skyecho-controller-app/docs/plans/001-dart-repo-foundation-with-mocking/tasks/phase-7-integration-test-framework/execution.log.md`

**Created by `/plan-6-implement-phase`**, this log will capture:
- Task-by-task implementation progress
- Code snippets for helpers.dart
- Refactoring diffs for existing integration tests
- Manual validation results (skip behavior screenshots/output)
- Test execution output (with/without device)
- README content additions
- Any implementation discoveries or deviations from plan

**Supporting Files** (created during Phase 7):
- `packages/skyecho/test/integration/helpers.dart` - Shared helper functions

**Note**: README.md creation deferred to Phase 9 per didyouknow session decision

**Validation Evidence**:
- Test output with device available (all pass)
- Test output with device unavailable (all skip with message)
- dart analyze output (zero issues)
- README peer review feedback

---

## Directory Layout

```
docs/plans/001-dart-repo-foundation-with-mocking/
├── dart-repo-foundation-with-mocking-plan.md
├── dart-repo-foundation-with-mocking-spec.md
└── tasks/
    ├── phase-1-project-foundation/
    │   ├── tasks.md
    │   └── execution.log.md
    ├── phase-2-capture-real-device-html-fixtures/
    │   ├── tasks.md
    │   └── execution.log.md
    ├── phase-3-error-hierarchy-http-infrastructure/
    │   ├── tasks.md
    │   └── execution.log.md
    ├── phase-4-html-parsing-devicestatus/
    │   ├── tasks.md
    │   └── execution.log.md
    ├── phase-5-json-api-setup-configuration/
    │   ├── tasks.md
    │   └── execution.log.md
    ├── phase-6-configuration-update-logic/
    │   └── tasks.md (OBSOLETE)
    └── phase-7-integration-test-framework/   ← THIS PHASE
        ├── tasks.md                           ← Current file
        └── execution.log.md                   ← Created by /plan-6

packages/skyecho/
└── test/
    └── integration/
        ├── helpers.dart                       ← NEW: Shared helpers
        ├── device_status_integration_test.dart ← REFACTORED (use helpers)
        └── setup_config_integration_test.dart  ← REFACTORED (use helpers + safety assertion)
```

---

## Implementation Notes

**Key Patterns to Follow**:
1. **Device Detection**: Always use `canReachDevice()` in setUpAll, never inline
2. **Skip Messages**: Always use `deviceSetupMessage()` for consistency
3. **Test Doc Blocks**: All integration tests require complete 5-field Test Doc
4. **Timeout Annotations**: Use `timeout: Timeout(Duration(seconds: N))` for tests with device I/O
5. **Debug Output**: Use `printDeviceInfo()` helper for consistent formatting

**TAD Philosophy for Integration Tests**:
- Integration tests are **documentation** of real device behavior
- Test Docs explain WHY integration (not unit) test is needed
- Usage Notes document device requirements (WiFi network, URL)
- Worked Examples show real device responses

**Phase 7 Success Definition**:
- Zero test failures when device unavailable (graceful skips)
- All tests pass when device available
- ~~Clear, actionable documentation in README~~ → **DEFERRED to Phase 9**
- Reusable helper infrastructure for future integration tests

---

**STOP**: Do **not** edit code. Wait for human **GO** signal.

**Next Step**: Run `/plan-6-implement-phase --phase "Phase 7: Integration Test Framework" --plan "/Users/jordanknight/github/skyecho-controller-app/docs/plans/001-dart-repo-foundation-with-mocking/dart-repo-foundation-with-mocking-plan.md"` after approval.

---

## Critical Insights Discussion

**Session**: 2025-10-18
**Context**: Phase 7 Integration Test Framework - Tasks & Alignment Brief
**Analyst**: AI Clarity Agent
**Reviewer**: Development Team
**Format**: Water Cooler Conversation (5 Critical Insights)

### Insight 1: Incomplete ADS-B Safety Coverage

**Did you know**: While we're protecting against accidental `es1090TransmitEnabled` activation, there are multiple other fields in SetupConfig that could enable ADS-B transmission, and we're not currently guarding against them.

**Implications**:
- T006a adds assertion for `es1090TransmitEnabled` only
- Device might have auto-enable logic based on other fields (receiverMode, es1090Enabled, UAT fields)
- Future developers could accidentally set transmit-enabling values in other fields
- Safety assertion gives false confidence about complete safety

**Options Considered**:
- Option A: Comprehensive Transmit State Assertion - Check ALL transmit-related fields
- Option B: Read-Only Integration Tests - Remove config update tests entirely
- Option C: Explicit Transmit-Disabled Config Baseline - Verify baseline before/after updates
- Option D: Current Plan + Documentation Warning - Keep single-field assertion, document limitation

**AI Recommendation**: Option A (Comprehensive Transmit State Assertion)
- Reasoning: Matches CRITICAL severity; prevents silent failures; self-documenting

**Discussion Summary**:
User clarified that device has NO auto-enable transmit logic. Only `es1090TransmitEnabled` field controls transmission. Other fields (receiverMode, es1090Enabled) do not trigger auto-enable.

**Decision**: Keep current single-field assertion for `es1090TransmitEnabled`

**Action Items**: None - T006a as currently specified is adequate

**Affects**: No changes to tasks.md (confirmed current approach is correct)

---

### Insight 2: Device Detection Timeout Creates False Negatives

**Did you know**: A 2-second timeout might be too aggressive for real-world WiFi networks, and we could end up skipping tests even when the device IS actually available - just experiencing normal network latency.

**Implications**:
- Network latency >2s (but device functional) → timeout → tests skip
- Developers on slow WiFi get spurious skips
- "Works on my machine" syndrome (fast vs slow WiFi)
- False sense of security from skipped tests

**Options Considered**:
- Option A: Increase Timeout to 5 Seconds - Matches SkyEchoClient default
- Option B: Retry Logic (2 attempts × 2 seconds) - Fast success, tolerates transients
- Option C: Progressive Timeout (2s → 5s fallback) - Fast path + patient fallback
- Option D: Keep 2 Seconds + Verbose Logging - Make false negatives visible

**AI Recommendation**: Option A (Increase to 5 Seconds)
- Reasoning: Consistency with proven 5s default; simplicity; low cost (only at test startup)

**Discussion Summary**:
User agreed with Option A - aligning with proven 5-second timeout makes sense.

**Decision**: Increase `canReachDevice()` timeout to 5 seconds

**Action Items**:
- [x] Update T002 validation to specify 5s timeout (completed)
- [x] Update Invariants & Guardrails section to reflect 5s timeout (completed)
- [x] Update implementation outline Phase 1 to show 5s timeout (completed)
- [x] Update risks table timeout risks (completed)
- [x] Update manual testing checklist (completed)

**Affects**: T002, Invariants & Guardrails, Implementation Outline, Risks table, Manual Testing Checklist

---

### Insight 3: Smoke Tests Don't Actually Test Core Functionality

**Did you know**: Our planned "smoke tests" in `device_smoke_test.dart` are actually just duplicates of existing integration tests from Phases 4-5, and they don't add any new validation or smoke test value.

**Implications**:
- T007-T010 create 3 "new" smoke tests with zero additional coverage
- Test duplication makes maintenance harder
- Smoke tests don't validate actual workflow (just individual API calls)
- True smoke test should be end-to-end: Connect → Read → Write → Verify

**Options Considered**:
- Option A: Replace with True End-to-End Smoke Test - Single comprehensive workflow test
- Option B: Eliminate Smoke Test File Entirely - Rely on existing tests from Phases 4-5
- Option C: Keep Smoke Tests as Quick Subset - Tag-based separation (smoke vs comprehensive)
- Option D: Current Plan (Keep Duplicate Tests) - Accept duplication for "consolidated location"

**AI Recommendation**: Option B (Eliminate Smoke Test File)
- Reasoning: Already have coverage; avoid duplication; existing tests ARE smoke tests; simplicity

**Discussion Summary**:
User agreed with Option B - keeping it simple and avoiding duplication.

**Decision**: Eliminate smoke test file entirely (device_smoke_test.dart)

**Action Items**:
- [x] Remove tasks T007-T010 from task table (completed)
- [x] Renumber remaining tasks (completed)
- [x] Update task count: 11 tasks (was 14) (completed)
- [x] Update behavior checklist to reference existing 5 tests (completed)
- [x] Update Non-Goals section (completed)
- [x] Update implementation phases - remove Phase 3 smoke tests (completed)
- [x] Update checkpoints (completed)
- [x] Update directory layout (completed)
- [x] Update supporting files list (completed)

**Affects**: Tasks table, task count, acceptance criteria, implementation outline, success criteria, directory layout

---

### Insight 4: Missing Cleanup Strategy for Test Config Changes

**Did you know**: When the roundtrip test updates the device config, if the test fails or crashes mid-execution, the device is left in a modified state with no automatic cleanup.

**Implications**:
- Test updates callsign → test crashes → cleanup never runs → device polluted
- After multiple failed runs: callsign = "N9954TTTTT" (keeps appending)
- Manual device reconfiguration required
- Tests no longer idempotent

**Options Considered**:
- Option A: Dart setUp/tearDown with State Snapshot - Automatic cleanup via tearDown()
- Option B: Accept Dirty State + Document Manual Reset - Current approach + docs
- Option C: Defensive Test Design (Read-Only Baseline) - Don't test config updates
- Option D: Smart Cleanup (Best Effort Restore) - addTearDown() + documentation

**AI Recommendation**: Option D (Smart Cleanup with Documentation)
- Reasoning: Practical balance; acknowledges hard crashes need manual intervention; preserves coverage

**Discussion Summary**:
User pointed out excellent alternative: Get device in known state at START of test, not cleanup at end. Roundtrip test is early warning - if it fails, other tests won't work anyway.

**Decision**: Establish known baseline state at test start (setUp/setUpAll)

**Action Items**:
- [x] Add note to T006a about known baseline state approach (completed)
- [x] Document that roundtrip test serves as early warning (completed)

**Affects**: T006a validation criteria, Phase 2 implementation outline

---

### Insight 5: README Documentation Scope Mismatch

**Did you know**: We're planning to create a full project README in Phase 7, but the plan document says README documentation should happen in Phase 9: Documentation (Hybrid) - creating potential duplication and confusion.

**Implications**:
- Phase 7 creates README (T007-T009)
- Phase 9 will "update README.md with quick-start"
- Risk of conflicts if Phase 9 rewrites Phase 7 content
- Unclear ownership of README content
- Writing integration test docs twice (Phase 7 draft + Phase 9 final)

**Options Considered**:
- Option A: Defer README to Phase 9 Entirely - Single source of truth, follows plan order
- Option B: Minimal README Stub in Phase 7 - Placeholder with "See docs/plans for now"
- Option C: Current Plan (Phase 7 Creates, Phase 9 Updates) - Incremental documentation
- Option D: README Owned by Phase 7, Phase 9 Adds docs/how/ - Expand Phase 7 scope

**AI Recommendation**: Option A (Defer README to Phase 9)
- Reasoning: Follows original plan; avoids duplication; better timing (all features implemented); developers can use CLAUDE.md + Test Docs until then

**Discussion Summary**:
User agreed with Option A - keeping documentation focused in Phase 9 where it belongs.

**Decision**: Defer README creation to Phase 9 entirely

**Action Items**:
- [x] Remove tasks T007-T009 (README creation) (completed)
- [x] Renumber remaining tasks (completed)
- [x] Update task count: 11 tasks (was 14) (completed)
- [x] Update behavior checklist - mark README as deferred to Phase 9 (completed)
- [x] Update success criteria - mark README as deferred (completed)
- [x] Remove Phase 3 Documentation from implementation outline (completed)
- [x] Renumber Phase 4 Validation → Phase 3 Validation (completed)
- [x] Update checkpoints (completed)
- [x] Update supporting files (completed)
- [x] Update directory layout (completed)

**Affects**: Tasks table, task count, acceptance criteria, implementation outline, checkpoints, supporting files, directory layout

---

## Session Summary

**Insights Surfaced**: 5 critical insights identified and discussed
**Decisions Made**: 5 decisions reached through collaborative discussion
**Action Items Created**: 0 follow-up tasks (all updates applied immediately during session)
**Areas Requiring Updates**:
- ✅ Task table updated (removed 8 tasks, renumbered remaining)
- ✅ Task count updated (19 → 14 → 11)
- ✅ Acceptance criteria updated (README deferred)
- ✅ Implementation outline updated (removed smoke tests + documentation phases)
- ✅ All 5 decisions documented with rationale

**Shared Understanding Achieved**: ✓

**Confidence Level**: High - How confident are we about proceeding?

**Next Steps**:
Proceed with Phase 7 implementation using `/plan-6-implement-phase` with the refined 11-task plan.

**Notes**:
- Safety-critical ADS-B protection confirmed as adequate (single-field check sufficient)
- Timeout increased to 5s for better real-world reliability
- Avoided test duplication by eliminating smoke test file
- Simplified cleanup strategy using known baseline at start
- Documentation deferred to Phase 9 to avoid duplication and follow original plan structure
- Final phase is leaner (11 tasks vs original 19) and more focused on core integration test infrastructure
