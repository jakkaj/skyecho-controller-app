# Phase 4 Fix Tasks: JSON API - Device Status

**Review**: [review.phase-4-json-api-device-status.md](./review.phase-4-json-api-device-status.md)
**Status**: REQUEST_CHANGES
**Priority**: HIGH (2 blocking issues)

---

## Blocking Issues (HIGH Priority)

### Task 1: Delete Scratch Tests (F001)

**Severity**: HIGH
**Finding ID**: F001
**Acceptance Criterion**: T015 - Delete scratch tests, verify gitignore

**Issue**: Scratch file exists at `test/scratch/device_status_scratch.dart` (518 lines, ~30 tests) but should have been deleted per T015.

**Root Cause**: T001-T002 deleted HTML code from `lib/skyecho.dart`, but did not delete old HTML scratch tests from `test/scratch/`.

**Steps to Fix**:

1. Delete scratch file:
   ```bash
   cd /Users/jordanknight/github/skyecho-controller-app/packages/skyecho
   rm test/scratch/device_status_scratch.dart
   ```

2. Remove empty directory (if empty):
   ```bash
   rmdir test/scratch
   ```

3. Verify deletion:
   ```bash
   ls test/scratch/  # Should show: No such file or directory
   git status | grep scratch  # Should show: (no output)
   ```

4. Verify analysis clean:
   ```bash
   dart analyze
   # Should show fewer issues (no scratch-related warnings)
   ```

5. Update execution.log.md:
   ```markdown
   ### T015: Delete Scratch Tests ✅ COMPLETE

   **Timestamp**: [Current timestamp]

   **Actions**:
   - Deleted test/scratch/device_status_scratch.dart (518 lines)
   - Removed empty scratch directory
   - Verified gitignore exclusion working

   **Rationale**: Execution log (lines 540-568) documented decision to skip
   scratch phase for JSON implementation. Old HTML scratch tests were not
   deleted during T001-T002 cleanup. Fixed by removing file.

   **Validation**:
   - `ls test/scratch/` → No such file or directory ✅
   - `git status | grep scratch` → (no output) ✅
   - `dart analyze` → 0 scratch-related warnings ✅
   ```

**Validation**:
- [ ] File deleted: `test/scratch/device_status_scratch.dart` does not exist
- [ ] Directory cleaned: `test/scratch/` is empty or removed
- [ ] Git status clean: No scratch files shown in `git status`
- [ ] Analysis clean: `dart analyze` shows no scratch-related issues
- [ ] Execution log updated

**Estimated Time**: 5 minutes

---

### Task 2: Create Integration Test (F002)

**Severity**: HIGH
**Finding ID**: F002
**Acceptance Criterion**: T018 - Create integration test with real device

**Issue**: No integration test exists at `test/integration/device_status_integration_test.dart` per T018 requirement.

**Root Cause**: Execution log shows T018 was listed but not completed. Integration test is required acceptance criterion.

**Steps to Fix**:

1. Create integration directory (if needed):
   ```bash
   cd /Users/jordanknight/github/skyecho-controller-app/packages/skyecho
   mkdir -p test/integration
   ```

2. Create integration test file:

   **File**: `/Users/jordanknight/github/skyecho-controller-app/packages/skyecho/test/integration/device_status_integration_test.dart`

   **Content**:
   ```dart
   import 'package:test/test.dart';
   import 'package:skyecho/skyecho.dart';

   void main() {
     group('DeviceStatus JSON API - Real Device Integration', () {
       late bool deviceAvailable;

       setUpAll(() async {
         try {
           final client = SkyEchoClient('http://192.168.4.1');
           await client.ping();
           deviceAvailable = true;
         } catch (_) {
           deviceAvailable = false;
           print('⚠️  SkyEcho device not reachable at http://192.168.4.1');
           print('   Connect to SkyEcho WiFi network to run integration tests.');
         }
       });

       test('fetchStatus returns valid DeviceStatus from real device',
           skip: !deviceAvailable, () async {
         /*
         Integration Test:
         - Tests real device JSON API endpoint GET /?action=get
         - Validates DeviceStatus fields from actual device response
         - Skips gracefully if device not available
         */

         // Arrange
         final client = SkyEchoClient('http://192.168.4.1');

         // Act
         final status = await client.fetchStatus();

         // Assert
         expect(status.ssid, isNotNull,
             reason: 'SSID should be present from real device');
         expect(status.ssid, startsWith('SkyEcho'),
             reason: 'SSID should start with "SkyEcho"');
         expect(status.wifiVersion, isNotNull,
             reason: 'WiFi version should be present');
         expect(status.adsbVersion, isNotNull,
             reason: 'ADS-B version should be present');
         expect(status.coredump, isA<bool>(),
             reason: 'Coredump should be boolean');
         expect(status.isHealthy, isA<bool>(),
             reason: 'isHealthy should be computed');

         print('✅ Real device test passed:');
         print('   SSID: ${status.ssid}');
         print('   WiFi: ${status.wifiVersion}');
         print('   ADS-B: ${status.adsbVersion}');
         print('   Healthy: ${status.isHealthy}');
       });

       test('fetchStatus handles network errors gracefully',
           skip: deviceAvailable, () async {
         /*
         Integration Test:
         - Tests error handling when device unreachable
         - Only runs if device is NOT available (opposite skip condition)
         */

         // Arrange
         final client = SkyEchoClient('http://192.168.4.1');

         // Act & Assert
         await expectLater(
           client.fetchStatus(),
           throwsA(isA<SkyEchoError>()),
         );
       });
     });
   }
   ```

3. Test integration test (with device):
   ```bash
   # If device available:
   dart test test/integration/device_status_integration_test.dart
   # Should see: 1 test passed, 1 skipped

   # If device unavailable:
   dart test test/integration/device_status_integration_test.dart
   # Should see: Warning message, 1 skipped, 1 passed (error test)
   ```

4. Update execution.log.md:
   ```markdown
   ### T018: Create Integration Test with Real Device ✅ COMPLETE

   **Timestamp**: [Current timestamp]

   **Created**: test/integration/device_status_integration_test.dart

   **Tests**:
   1. fetchStatus with real device (skips if unavailable)
   2. Network error handling (runs when device unavailable)

   **Validation**:
   - With device: Both tests run, fetchStatus test passes, error test skips
   - Without device: Warning displayed, fetchStatus skips, error test passes
   - Graceful skip behavior confirmed ✅

   **Integration Test Results** (with device connected):
   ```
   00:00 +1: Real device test passed:
      SSID: SkyEcho_3155
      WiFi: 0.2.41-SkyEcho
      ADS-B: 2.6.13
      Healthy: true
   00:00 +1 -1: 1 test passed, 1 skipped
   ```
   ```

5. Verify in git status:
   ```bash
   git status | grep integration
   # Should show: test/integration/device_status_integration_test.dart
   ```

**Validation**:
- [ ] File created: `test/integration/device_status_integration_test.dart` exists
- [ ] Test runs with device: `dart test test/integration/...` passes
- [ ] Test skips without device: Warning message displayed, graceful skip
- [ ] Execution log updated with test results
- [ ] File shows in git status (untracked, ready to stage)

**Estimated Time**: 15 minutes

---

## Non-Blocking Issues (MEDIUM Priority)

### Task 3: Generate Coverage Report (F003)

**Severity**: MEDIUM
**Finding ID**: F003
**Acceptance Criterion**: T016 - Verify 90%+ coverage on DeviceStatus

**Issue**: Coverage report not generated per T016 validation requirement.

**Steps to Fix**:

1. Generate coverage:
   ```bash
   cd /Users/jordanknight/github/skyecho-controller-app/packages/skyecho
   dart test --coverage=coverage
   ```

2. Activate coverage tool (if not installed):
   ```bash
   dart pub global activate coverage
   ```

3. Format coverage:
   ```bash
   dart pub global run coverage:format_coverage \
     --lcov \
     --in=coverage \
     --out=coverage/lcov.info \
     --report-on=lib
   ```

4. Generate HTML report (optional):
   ```bash
   genhtml coverage/lcov.info -o coverage/html
   # Open coverage/html/index.html in browser
   ```

5. Verify DeviceStatus coverage:
   - Open `coverage/html/index.html`
   - Find `lib/skyecho.dart`
   - Check DeviceStatus class coverage
   - Verify fromJson() method >= 90%

6. Update execution.log.md:
   ```markdown
   ### T016: Verify Coverage ✅ COMPLETE

   **Timestamp**: [Current timestamp]

   **Coverage Results**:
   - DeviceStatus.fromJson(): XX% (>= 90% required) ✅
   - DeviceStatus computed properties: XX%
   - Overall DeviceStatus class: XX%

   **Lines covered**:
   - fromJson() parsing: XX/XX lines
   - Error handling: XX/XX lines
   - Computed properties: XX/XX lines

   **Uncovered branches** (if any):
   - [List any uncovered branches with justification]

   **Validation**: Coverage exceeds 90% requirement per constitution ✅
   ```

**Validation**:
- [ ] Coverage generated: `coverage/lcov.info` exists
- [ ] DeviceStatus.fromJson() >= 90% coverage
- [ ] Coverage percentage documented in execution log
- [ ] HTML report generated (optional but recommended)

**Estimated Time**: 10 minutes

---

### Task 4: Clarify HTML Package Removal (F004)

**Severity**: MEDIUM
**Finding ID**: F004
**Acceptance Criterion**: T016 - Remove html package dependency

**Issue**: Tasks.md T016 says "Remove html package... Phase 5 confirmed to use JSON API", but Phase 5 directory name is "phase-5-html-parsing-setupform", suggesting HTML may still be needed.

**Investigation Required**:

1. Check Phase 5 specification:
   ```bash
   cd /Users/jordanknight/github/skyecho-controller-app
   cat docs/plans/001-dart-repo-foundation-with-mocking/tasks/phase-5-html-parsing-setupform/tasks.md | head -50
   ```

2. Determine if Phase 5 uses HTML or JSON API for setup forms

3. **If Phase 5 uses JSON API**:
   - Remove `html` from `pubspec.yaml` dependencies
   - Remove `import 'package:html/...'` from `lib/skyecho.dart` (line 6 is dart:convert only)
   - Run `dart pub get`
   - Verify `dart analyze` clean
   - Update execution.log.md:
     ```markdown
     ### T016: Remove HTML Package Dependency ✅ COMPLETE

     **Timestamp**: [Current timestamp]

     **Rationale**: Phase 5 confirmed to use JSON API for setup forms. HTML
     package no longer needed for DeviceStatus (Phase 4) or SetupConfig (Phase 5).

     **Changes**:
     - Removed `html: ^0.15.4` from pubspec.yaml dependencies
     - No imports to remove (lib/skyecho.dart already JSON-only)
     - Ran `dart pub get` successfully

     **Validation**: `dart analyze` clean, no HTML references remain ✅
     ```

4. **If Phase 5 uses HTML parsing**:
   - Keep `html` package in dependencies
   - Update execution.log.md:
     ```markdown
     ### T016: HTML Package Retention Decision

     **Timestamp**: [Current timestamp]

     **Decision**: RETAIN html package for Phase 5 setup form parsing

     **Rationale**: Phase 5 tasks directory indicates HTML parsing for setup
     forms. While DeviceStatus uses JSON API, SetupForm may require HTML
     parsing until Phase 5 investigation confirms JSON API availability.

     **Action**: Defer html package removal until Phase 5 implementation
     confirms JSON API for setup forms.

     **Status**: T016 reinterpreted as "evaluate HTML dependency" rather
     than "remove immediately". Will remove in Phase 5 if JSON API confirmed.
     ```

**Validation**:
- [ ] Phase 5 spec reviewed
- [ ] Decision documented in execution log
- [ ] If removing: `dart pub get` successful, `dart analyze` clean
- [ ] If retaining: Rationale documented, defer to Phase 5

**Estimated Time**: 5-10 minutes

---

## Completion Checklist

After completing all tasks above:

- [ ] **Task 1 (HIGH)**: Scratch tests deleted
- [ ] **Task 2 (HIGH)**: Integration test created
- [ ] **Task 3 (MEDIUM)**: Coverage report generated
- [ ] **Task 4 (MEDIUM)**: HTML package decision documented

**Final Validation**:

```bash
cd /Users/jordanknight/github/skyecho-controller-app/packages/skyecho

# 1. Verify scratch gone
ls test/scratch/  # Should fail or show empty
git status | grep scratch  # Should show no output

# 2. Verify integration test exists
ls test/integration/device_status_integration_test.dart  # Should exist

# 3. Verify tests pass
dart test  # All unit + integration tests pass (integration skips if no device)

# 4. Verify analysis clean
dart analyze  # Should show fewer issues than before

# 5. Verify coverage exists
ls coverage/lcov.info  # Should exist

# 6. Check execution log updated
grep -A 5 "T015:" docs/plans/.../execution.log.md  # Should show ✅ COMPLETE
grep -A 5 "T018:" docs/plans/.../execution.log.md  # Should show ✅ COMPLETE
grep -A 5 "T016:" docs/plans/.../execution.log.md  # Should show ✅ COMPLETE
```

**After validation passes**:

1. Stage Phase 4 changes for commit
2. Request re-review or mark phase COMPLETE
3. Proceed to Phase 5

---

## Summary

**Total Tasks**: 4 (2 HIGH, 2 MEDIUM)
**Estimated Total Time**: 35-45 minutes
**Blocking Issues**: 2 (Tasks 1-2 must be completed before phase approval)

**Quick Wins** (can be done in any order):
- Task 1: Delete file (5 min)
- Task 3: Run coverage (10 min)
- Task 4: Document decision (5 min)

**Requires More Effort**:
- Task 2: Write integration test (15 min)

**After completion**: All 13 acceptance criteria met, phase can be marked COMPLETE.
