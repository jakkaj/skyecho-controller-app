# Dart Repository Foundation with Mocking & Testing - Implementation Plan

**Plan Version**: 1.0.0
**Created**: 2025-10-16
**Spec**: [dart-repo-foundation-with-mocking-spec.md](./dart-repo-foundation-with-mocking-spec.md)
**Status**: READY

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Technical Context](#technical-context)
3. [Critical Research Findings](#critical-research-findings)
4. [Testing Philosophy](#testing-philosophy)
5. [Implementation Phases](#implementation-phases)
   - [Phase 1: Project Foundation & Structure](#phase-1-project-foundation--structure)
   - [Phase 2: Capture Real Device HTML Fixtures](#phase-2-capture-real-device-html-fixtures)
   - [Phase 3: Error Hierarchy & HTTP Infrastructure (TAD)](#phase-3-error-hierarchy--http-infrastructure-tad)
   - [Phase 4: HTML Parsing - DeviceStatus (TAD)](#phase-4-html-parsing---devicestatus-tad)
   - [Phase 5: HTML Parsing - SetupForm (TAD)](#phase-5-html-parsing---setupform-tad)
   - [Phase 6: Configuration Update Logic (TAD)](#phase-6-configuration-update-logic-tad)
   - [Phase 7: Integration Test Framework](#phase-7-integration-test-framework)
   - [Phase 8: Example CLI Application](#phase-8-example-cli-application)
   - [Phase 9: Documentation (Hybrid)](#phase-9-documentation-hybrid)
   - [Phase 10: Final Polish & Validation](#phase-10-final-polish--validation)
6. [Cross-Cutting Concerns](#cross-cutting-concerns)
7. [Progress Tracking](#progress-tracking)
8. [Change Footnotes Ledger](#change-footnotes-ledger)

---

## Executive Summary

**Problem**: Developers need a robust Dart library to control uAvionix SkyEcho 2 ADS-B devices programmatically, but the device only provides an HTML web interface (no REST API). Development requires the ability to test without physical hardware access.

**Solution**:
- Implement screen-scraping library with defensive HTML parsing
- Create comprehensive mock infrastructure using `http.MockClient`
- Capture realistic HTML fixtures from real device early in development
- Use TAD (Test-Assisted Development) with Test Doc blocks for maintainability
- Provide dual testing modes (unit tests offline, integration tests with hardware)

**Expected Outcomes**:
- ~600 line single-file Dart library (`lib/skyecho.dart`)
- Complete test coverage (90% core, 100% parsing)
- Hardware-independent development workflow
- Example CLI app demonstrating usage
- Comprehensive documentation (README + docs/how/)

**Success Metrics**:
- All acceptance criteria from spec met
- `dart analyze` runs clean
- Unit test suite executes in < 5 seconds
- Integration tests skip gracefully when hardware unavailable
- Real device HTML captured and used in fixtures

---

## Technical Context

### Current System State
- **Repository**: Empty except for documentation and planning files
- **No existing code**: Greenfield Dart project
- **Hardware available**: Physical SkyEcho device accessible for integration testing and HTML capture
- **Target device**: uAvionix SkyEcho 2 at `http://192.168.4.1`

### Integration Requirements
- HTTP communication with device (no HTTPS)
- Cookie-based session management
- HTML parsing with `html` package (DOM manipulation)
- Form data submission (application/x-www-form-urlencoded)
- Timeout handling (5 second default)

### Constraints and Limitations
- No REST API available (HTML screen-scraping only)
- HTML structure may vary across firmware versions
- Web platform requires CORS proxy (out of scope)
- GDL90 stream implementation deferred (placeholder types only)
- No CI configuration in this phase (justfile for local commands)

### Assumptions
- Single firmware version sample data sufficient initially
- Fuzzy label matching will handle minor HTML variations
- `http.MockClient` adequate for testing needs
- Physical device accessible for integration tests when needed
- Standard Dart package structure appropriate

---

## Critical Research Findings

### 🚨 Critical Discovery 01: Dart HTML Package Parsing Behavior

**Problem**: The `html` package in Dart does not execute JavaScript, so dynamic content or JS-based form submissions won't work.

**Root Cause**: The package is a pure HTML parser, not a browser engine. It parses static HTML into a DOM tree.

**Solution**: Design parsers to work with server-rendered HTML only. Document this limitation for users.

**Example**:
```dart
// ❌ WRONG - Trying to trigger JS events
final button = doc.querySelector('button[onclick]');
button?.click(); // No-op, JS doesn't execute

// ✅ CORRECT - Parse form structure directly
final form = doc.querySelector('form');
final fields = form?.querySelectorAll('input, select');
```

**Impact**: SetupForm parsing must find the form by "Apply" button presence, not by simulating button clicks.

---

### 🚨 Critical Discovery 02: MockClient HTTP Response Handling

**Problem**: `MockClient` requires explicit handling of all request paths; unhandled requests throw exceptions.

**Root Cause**: `MockClient` is designed for explicit test control, not automatic fallback behavior.

**Solution**: Provide comprehensive mock responses for all expected endpoints in test setup.

**Example**:
```dart
// ❌ WRONG - Missing /setup endpoint
final mock = MockClient((req) async {
  if (req.url.path == '/') return http.Response(landingHtml, 200);
  // Throws for /setup
});

// ✅ CORRECT - Handle all endpoints
final mock = MockClient((req) async {
  if (req.url.path == '/') return http.Response(landingHtml, 200);
  if (req.url.path == '/setup') return http.Response(setupHtml, 200);
  return http.Response('Not Found', 404);
});
```

**Impact**: Test fixtures must be comprehensive; TAD scratch tests help discover needed endpoints.

---

### 🚨 Critical Discovery 03: Fuzzy Label Matching Strategy

**Problem**: HTML label attributes and `<td>` text formatting varies (extra whitespace, case differences).

**Root Cause**: Device firmware may use inconsistent formatting in HTML generation.

**Solution**: Normalize all labels (lowercase, collapse whitespace) before matching. Support both exact and contains matching.

**Example**:
```dart
// ❌ WRONG - Exact string match fails on whitespace
if (label == 'ICAO Address') { ... }

// ✅ CORRECT - Normalized fuzzy matching
String _normLabel(String? s) =>
  (s ?? '').replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

if (_normLabel(label).contains(_normLabel('icao address'))) { ... }
```

**Impact**: SetupUpdate field mapping uses `_normLabel` utility throughout; documented in idioms.md.

---

### 🚨 Critical Discovery 04: Cookie Jar Without Sessions Library

**Problem**: Dart's `http` package doesn't persist cookies across requests automatically.

**Root Cause**: No built-in session management; each `http.Client` instance is stateless.

**Solution**: Implement simple `_CookieJar` class to parse `Set-Cookie` headers and add `Cookie` header to requests.

**Example**:
```dart
// ❌ WRONG - Cookies not persisted
await http.get(Uri.parse('http://192.168.4.1/'));
await http.post(Uri.parse('http://192.168.4.1/setup'), body: data);
// Session lost between requests

// ✅ CORRECT - Manual cookie jar
class _CookieJar {
  final Map<String, String> _cookies = {};

  void ingest(http.Response r) {
    final sc = r.headers['set-cookie'];
    // Parse and store
  }

  Map<String, String> toHeader() =>
    _cookies.isEmpty ? {} : {'cookie': _cookies.entries.map(...).join('; ')};
}
```

**Impact**: `SkyEchoClient` must maintain `_CookieJar` instance and apply cookies to all requests.

---

### 🚨 Critical Discovery 05: Form Field Cloning Pattern

**Problem**: Modifying form fields directly mutates original parsed form, breaking immutability.

**Root Cause**: Dart classes are reference types; assigning a field to a variable doesn't create a copy.

**Solution**: Implement `copy()` method on all `FormField` subclasses for deep cloning before updates.

**Example**:
```dart
// ❌ WRONG - Mutates original form
final form = await client.fetchSetupForm();
form.fields.first.value = 'new value'; // Original changed!

// ✅ CORRECT - Clone before mutation
abstract class FormField {
  FormField copy();
}

class TextField extends FormField {
  TextField copy() => TextField(name: name, label: label, value: value, inputType: inputType);
}

final cloned = fields.map((f) => f.copy()).toList();
```

**Impact**: `SetupForm.updatedWith()` clones all fields before applying `SetupUpdate` changes.

---

## Testing Philosophy

### Testing Approach: TAD (Test-Assisted Development)

**Selected Approach**: Test-Assisted Development (TAD)

**Rationale** (from spec): Tests serve as executable documentation to guide development, especially valuable for the HTML parsing logic where edge cases and field mappings need clear documentation for future maintainers.

**Focus Areas**:
- **HTML parsing logic** (DeviceStatus, SetupForm) - 100% coverage required
- **Fuzzy label matching** - Document all matching strategies and edge cases
- **Error handling** - All error paths with actionable hint validation
- **HTTP client abstraction** - Cookie management, timeout behavior
- **Form field types** - All variations (text, checkbox, radio, select) with Test Docs

**Excluded from Extensive Testing**:
- Trivial getters/setters
- Simple utility functions (normalization helpers)
- Example code (manual verification sufficient)

---

### Test-Assisted Development (TAD) Workflow

Tests are **executable documentation** optimized for developer comprehension, not just verification.

#### Scratch → Promote Workflow

1. **Write probe tests in `packages/skyecho/test/scratch/`** to explore and iterate (fast, excluded from CI)
2. **Implement code iteratively**, refining behavior with scratch probes
3. **When behavior stabilizes**, promote valuable tests to `packages/skyecho/test/unit/` or `packages/skyecho/test/integration/`
4. **Add Test Doc comment block** to each promoted test (5 required fields below)
5. **Delete scratch probes** that don't add durable value; keep learning notes in execution log

**Promotion Heuristic**: Keep if **Critical path**, **Opaque behavior**, **Regression-prone**, or **Edge case**

#### Test Naming Format

Use **Given-When-Then** pattern:
- `test_given_iso_date_when_parsing_then_returns_normalized_cents`
- `test_given_missing_gps_fix_when_checking_status_then_returns_false`

#### Test Doc Comment Block (Required for Promoted Tests)

Every promoted test **MUST** include this comment block:

```dart
test('given_valid_html_when_parsing_status_then_extracts_all_fields', () {
  /*
  Test Doc:
  - Why: Validates core parsing logic for landing page status table
  - Contract: DeviceStatus.fromDocument returns non-null status with populated fields
  - Usage Notes: Pass complete HTML document; parser is resilient to missing optional fields
  - Quality Contribution: Catches HTML structure changes; documents expected field mappings
  - Worked Example: Sample HTML with "Wi-Fi Version: 0.2.41" → wifiVersion="0.2.41"
  */

  // Arrange
  final html = loadFixture('landing_page_sample.html');
  final doc = htmlParser.parse(html);

  // Act
  final status = DeviceStatus.fromDocument(doc);

  // Assert
  expect(status.wifiVersion, equals('0.2.41-SkyEcho'));
  expect(status.current['icao address'], equals('ABC123'));
});
```

#### CI Requirements

- **Exclude `packages/skyecho/test/scratch/` from CI**: Ensure `.gitignore` or test runner config excludes scratch directory
- **Promoted tests must be deterministic**: No network calls, no sleep, no flaky behavior
- **Performance**: Test suite must run in < 5 seconds (per constitution)

---

### Mock Usage: Targeted Mocks

**Mock Policy**: Targeted mocks only (from spec clarification)

**Rationale**: Prefer real fixtures (captured HTML) to catch parser edge cases; use `MockClient` only for HTTP layer to enable offline testing. Document WHY when introducing mocks.

**Allowed Mock Targets**:
- HTTP client (`http.MockClient`) for network isolation
- Time/date functions if needed for deterministic tests
- External system dependencies (if added later)

**Prefer Real Data For**:
- HTML parsing (use `packages/skyecho/test/fixtures/` with real device captures)
- Form field extraction and mapping
- Error message formatting
- Status computations

---

### Test Documentation

Every test **MUST** explain its value through the Test Doc block (5 required fields as shown above).

---

## Implementation Phases

### Phase 1: Project Foundation & Structure

**Objective**: Establish Dart project structure, configuration files, and build tooling.

**Deliverables**:
- `packages/skyecho/pubspec.yaml` with dependencies (http ^1.2.1, html ^0.15.4)
- `packages/skyecho/analysis_options.yaml` with strict linting
- `justfile` at root with common tasks
- Complete monorepo directory structure
- `.gitignore` configured

**Dependencies**: None (foundational phase)

**Risks**:
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Dependency version conflicts | Low | Medium | Use compatible ranges (^) |
| Incorrect directory structure | Low | Low | Follow Dart package conventions |

#### Tasks (Lightweight Approach)

| #   | Status | Task | Success Criteria | Log | Notes |
|-----|--------|------|------------------|-----|-------|
| 1.1 | [ ] | Create `packages/skyecho/pubspec.yaml` with project metadata | File exists with name, description, SDK constraints | - | packages/skyecho/pubspec.yaml |
| 1.2 | [ ] | Add dependencies with compatible ranges | `http: ^1.2.1`, `html: ^0.15.4` with dev dependency `test: ^1.24.0` | - | Use `^` per spec |
| 1.3 | [ ] | Create `packages/skyecho/analysis_options.yaml` | Strict mode enabled, common lints configured | - | Reference Effective Dart lints |
| 1.4 | [ ] | Create monorepo directory structure | packages/skyecho/lib/, packages/skyecho/test/unit/, packages/skyecho/test/integration/, packages/skyecho/test/fixtures/, packages/skyecho/test/scratch/, packages/skyecho/example/, docs/how/ exist | - | Use absolute paths |
| 1.5 | [ ] | Create `justfile` at root with recipes | Recipes: install, analyze, format, test, test-unit, test-integration, test-all (use cd packages/skyecho &&) | - | Document in README how to use |
| 1.6 | [ ] | Update `.gitignore` | Exclude: .dart_tool/, build/, **/scratch/ (project convention), packages/skyecho/pubspec.lock (library only), .packages | - | **/scratch/ = project-wide convention |
| 1.7 | [ ] | Run `cd packages/skyecho && dart pub get` to verify setup | Dependencies resolve without errors | - | |
| 1.8 | [ ] | Run `cd packages/skyecho && dart analyze` on empty project | Passes with no errors (no code yet) | - | |

#### Acceptance Criteria
- [ ] `cd packages/skyecho && dart pub get` succeeds
- [ ] `cd packages/skyecho && dart analyze` passes
- [ ] Monorepo directory structure created correctly
- [ ] `justfile` recipes execute without error
- [ ] `.gitignore` excludes **/scratch/ (project-wide convention)

---

### Phase 2: Capture Real Device HTML Fixtures

**Objective**: Capture realistic HTML samples from physical SkyEcho device for use in test fixtures.

**Deliverables**:
- `packages/skyecho/test/fixtures/landing_page_sample.html` (captured from device)
- `packages/skyecho/test/fixtures/setup_form_sample.html` (captured from device)
- `packages/skyecho/test/fixtures/README.md` documenting firmware version and capture date

**Dependencies**: Physical SkyEcho device accessible at http://192.168.4.1

**Risks**:
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Device not accessible | Low | High | Clear setup instructions; defer if unavailable |
| HTML structure differs from spec | Medium | High | Document actual structure; adjust plan if needed |

#### Tasks (Manual)

| #   | Status | Task | Success Criteria | Log | Notes |
|-----|--------|------|------------------|-----|-------|
| 2.1 | [ ] | Connect to SkyEcho WiFi network | Computer connected to SkyEcho_XXXX network | - | Document SSID and password |
| 2.2 | [ ] | Verify device reachable | `curl http://192.168.4.1/` returns HTML | - | Use browser or curl |
| 2.3 | [ ] | Capture landing page HTML | Save HTML source to packages/skyecho/test/fixtures/landing_page_sample.html | - | View source or curl -o |
| 2.4 | [ ] | Capture setup page HTML | Save HTML source to packages/skyecho/test/fixtures/setup_form_sample.html | - | Navigate to /setup first |
| 2.5 | [ ] | Document firmware version | Create packages/skyecho/test/fixtures/README.md with Wi-Fi version, ADS-B version, capture date | - | Extract from HTML or device display |
| 2.6 | [ ] | Verify HTML includes all field types | Setup form has: text, checkbox, radio, select elements | - | Manual inspection |
| 2.7 | [ ] | Verify HTML includes status table | Landing page has "Current Status" table with key/value pairs | - | Manual inspection |

#### Acceptance Criteria
- [ ] Both fixture files captured and committed
- [ ] Firmware version documented in fixtures/README.md
- [ ] HTML samples represent actual device structure
- [ ] All expected form field types present in setup form
- [ ] Status table present in landing page

---

### Phase 3: Error Hierarchy & HTTP Infrastructure (TAD)

**Objective**: Implement error types and HTTP client infrastructure using TAD approach.

**Deliverables**:
- `SkyEchoError` base class and 4 subclasses
- `_CookieJar` internal class
- `_Response` wrapper class
- `SkyEchoClient` skeleton with ping method
- Test Doc blocks for all promoted tests

**Dependencies**: Phase 1 complete (project structure), Phase 2 complete (fixtures available)

**Risks**:
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Cookie parsing edge cases | Medium | Medium | Test with captured Set-Cookie headers |
| Timeout behavior unclear | Low | Medium | Document timeout in Test Docs |

#### Tasks (TAD Approach)

| #   | Status | Task | Success Criteria | Log | Notes |
|-----|--------|------|------------------|-----|-------|
| 3.1 | [ ] | Create packages/skyecho/test/scratch/ directory | Directory exists, excluded from .gitignore | - | Verify git status doesn't show it |
| 3.2 | [ ] | Write scratch probe for SkyEchoError hierarchy | 3-5 probe tests exploring error construction, toString, hints | - | Fast iteration, no Test Doc needed |
| 3.3 | [ ] | Implement error classes in packages/skyecho/lib/skyecho.dart | SkyEchoError (base), SkyEchoNetworkError, SkyEchoHttpError, SkyEchoParseError, SkyEchoFieldError | - | See initial-details.md for structure |
| 3.4 | [ ] | Write scratch probes for _CookieJar | 5-10 probes testing cookie parsing, storage, header generation | - | Per Critical Discovery 04 |
| 3.5 | [ ] | Implement _CookieJar class | Class with ingest() and toHeader() methods per Discovery 04 | - | Private class (leading underscore) |
| 3.6 | [ ] | Write scratch probes for _Response wrapper | Probes testing checkOk(), statusCode, body access | - | Wrapper for http.Response |
| 3.7 | [ ] | Implement _Response class | Wraps http.Response, adds checkOk() helper | - | Per initial-details.md |
| 3.8 | [ ] | Write scratch probes for SkyEchoClient.ping | Probes for success, timeout, connection failure cases | - | Use MockClient |
| 3.9 | [ ] | Implement SkyEchoClient skeleton + ping() | Constructor with baseUrl, timeout; ping() returns bool | - | Per spec and Discovery 02 |
| 3.10 | [ ] | Promote valuable error tests to packages/skyecho/test/unit/errors_test.dart | 2-3 tests with Test Doc blocks (Why/Contract/Usage/Quality/Example) | - | Heuristic: Critical path, Opaque behavior |
| 3.11 | [ ] | Promote valuable _CookieJar tests to packages/skyecho/test/unit/http_test.dart | 2-3 tests with Test Doc blocks covering parsing edge cases | - | Edge cases are promotion-worthy |
| 3.12 | [ ] | Promote valuable ping tests to packages/skyecho/test/unit/skyecho_client_test.dart | 2-3 tests with Test Doc blocks (success, timeout, error) | - | Critical path for client |
| 3.13 | [ ] | Delete non-valuable scratch tests | Only promoted tests remain in unit/ | - | Keep learning notes in log |
| 3.14 | [ ] | Verify packages/skyecho/test/scratch/ excluded from test runner | Running `just test` doesn't execute scratch tests | - | |

#### Test Examples (Promoted Tests)

```dart
// packages/skyecho/test/unit/errors_test.dart
import 'package:test/test.dart';
import 'package:skyecho/skyecho.dart';

void main() {
  group('SkyEchoError hierarchy', () {
    test('given_parse_error_with_hint_when_toString_then_includes_both', () {
      /*
      Test Doc:
      - Why: Ensures error messages are actionable for debugging HTML parsing failures
      - Contract: SkyEchoParseError.toString() returns "message\nHint: hint" when hint provided
      - Usage Notes: Always provide hint when throwing parse errors to guide resolution
      - Quality Contribution: Catches missing hints; documents error formatting contract
      - Worked Example: SkyEchoParseError('Form not found', hint: 'Check /setup page') → "Form not found\nHint: Check /setup page"
      */

      // Arrange
      final error = SkyEchoParseError(
        'Could not find form',
        hint: 'Ensure device HTML structure matches expected format',
      );

      // Act
      final message = error.toString();

      // Assert
      expect(message, contains('Could not find form'));
      expect(message, contains('Hint:'));
      expect(message, contains('Ensure device HTML structure'));
    });
  });
}
```

#### Acceptance Criteria
- [ ] All error classes implemented with message and hint
- [ ] _CookieJar parses Set-Cookie and generates Cookie header correctly
- [ ] SkyEchoClient.ping() works with MockClient
- [ ] At least 6-8 promoted tests with complete Test Doc blocks
- [ ] packages/skyecho/test/scratch/ excluded from test runs
- [ ] All promoted tests pass

---

### Phase 4: HTML Parsing - DeviceStatus (TAD)

**Objective**: Implement DeviceStatus parsing from landing page HTML using TAD.

**Deliverables**:
- `DeviceStatus` class with all fields
- `DeviceStatus.fromDocument()` static method
- Promoted tests with Test Doc blocks
- 100% coverage of parsing logic

**Dependencies**: Phase 3 complete (error types available), Phase 2 complete (fixtures)

**Risks**:
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Missing status table in HTML | Low | High | Graceful degradation (return empty map) |
| Label normalization fails | Medium | Medium | Extensive scratch testing of edge cases |

#### Tasks (TAD Approach)

| #   | Status | Task | Success Criteria | Log | Notes |
|-----|--------|------|------------------|-----|-------|
| 4.1 | [ ] | Write scratch probes for header parsing | 5-10 probes testing version, SSID, clients extraction from fixture HTML | - | Per Discovery 03 (normalization) |
| 4.2 | [ ] | Write scratch probes for status table parsing | 10-15 probes testing table finding, row extraction, label normalization | - | Critical: fuzzy matching edge cases |
| 4.3 | [ ] | Write scratch probes for computed properties | 5-8 probes for hasGpsFix, isSendingData heuristics with various inputs | - | Opaque behavior = promotion-worthy |
| 4.4 | [ ] | Implement DeviceStatus class structure | Constructor, all fields (wifiVersion, adsbVersion, ssid, clientsConnected, current map) | - | Per initial-details.md lines 187-209 |
| 4.5 | [ ] | Implement header parsing in fromDocument() | Parses colon-separated key/values from body text | - | Per initial-details.md lines 236-253 |
| 4.6 | [ ] | Implement status table parsing in fromDocument() | Finds "Current Status" heading, parses adjacent table into map | - | Per initial-details.md lines 255-292 |
| 4.7 | [ ] | Implement computed properties (hasGpsFix, isSendingData, getters) | Use heuristics per initial-details.md lines 211-233 | - | Document heuristic logic in Test Docs |
| 4.8 | [ ] | Implement _normLabel utility | Normalize labels (lowercase, collapse whitespace) per Discovery 03 | - | packages/skyecho/lib/skyecho.dart |
| 4.9 | [ ] | Promote table parsing tests to packages/skyecho/test/unit/device_status_test.dart | 3-4 tests with Test Docs covering happy path, missing table, malformed HTML | - | 100% coverage required |
| 4.10 | [ ] | Promote computed property tests to packages/skyecho/test/unit/device_status_test.dart | 2-3 tests with Test Docs for hasGpsFix and isSendingData edge cases | - | Opaque behavior justifies promotion |
| 4.11 | [ ] | Promote label normalization tests | 2-3 tests with Test Docs for whitespace, case, special chars | - | Regression-prone edge cases |
| 4.12 | [ ] | Delete non-valuable scratch tests | Clean up packages/skyecho/test/scratch/ | - | |
| 4.13 | [ ] | Verify 100% coverage on DeviceStatus parsing | Run coverage tool, document any uncovered branches | - | Constitution requirement |

#### Test Examples (Promoted Tests)

```dart
// packages/skyecho/test/unit/device_status_test.dart
import 'dart:io';
import 'package:test/test.dart';
import 'package:html/parser.dart' as html;
import 'package:skyecho/skyecho.dart';

void main() {
  group('DeviceStatus.fromDocument', () {
    test('given_landing_page_fixture_when_parsing_then_extracts_all_header_fields', () {
      /*
      Test Doc:
      - Why: Validates header parsing logic for Wi-Fi version, ADS-B version, SSID, clients
      - Contract: DeviceStatus.fromDocument extracts header fields from colon-separated text
      - Usage Notes: Pass complete HTML document; parser tolerates missing fields (returns null)
      - Quality Contribution: Catches header parsing regressions; documents expected HTML structure
      - Worked Example: "Wi-Fi Version: 0.2.41-SkyEcho\nSSID: SkyEcho_3155" → wifiVersion="0.2.41-SkyEcho", ssid="SkyEcho_3155"
      */

      // Arrange
      final fixture = File('packages/skyecho/test/fixtures/landing_page_sample.html').readAsStringSync();
      final doc = html.parse(fixture);

      // Act
      final status = DeviceStatus.fromDocument(doc);

      // Assert
      expect(status.wifiVersion, isNotNull);
      expect(status.wifiVersion, matches(RegExp(r'\d+\.\d+\.\d+')));
      expect(status.ssid, isNotNull);
      expect(status.ssid, startsWith('SkyEcho'));
    });

    test('given_gps_fix_none_when_checking_hasGpsFix_then_returns_false', () {
      /*
      Test Doc:
      - Why: Ensures GPS fix heuristic correctly identifies "no fix" states
      - Contract: hasGpsFix returns false when status table has "GPS Fix" = "none", "0", or "no" (case-insensitive)
      - Usage Notes: Heuristic is defensive; any non-empty value other than known negatives = true
      - Quality Contribution: Prevents false positives in GPS status detection
      - Worked Example: current['gps fix'] = 'None' → hasGpsFix = false; current['gps fix'] = '2D' → hasGpsFix = true
      */

      // Arrange
      final status = DeviceStatus(
        wifiVersion: '1.0',
        adsbVersion: '2.0',
        ssid: 'Test',
        clientsConnected: 1,
        current: {'gps fix': 'None'},
      );

      // Act
      final result = status.hasGpsFix;

      // Assert
      expect(result, isFalse);
    });
  });
}
```

#### Acceptance Criteria
- [ ] DeviceStatus parses header fields from fixture
- [ ] DeviceStatus parses "Current Status" table into map
- [ ] Computed properties (hasGpsFix, isSendingData) work correctly
- [ ] Label normalization handles whitespace, case, special chars
- [ ] At least 7-10 promoted tests with Test Doc blocks
- [ ] 100% coverage on parsing logic
- [ ] All promoted tests pass

---

### Phase 5: HTML Parsing - SetupForm (TAD)

**Objective**: Implement SetupForm parsing from setup page HTML using TAD.

**Deliverables**:
- `SetupForm` class and factory constructor
- `FormField` abstract class and 4 subclasses (TextField, CheckboxField, RadioGroupField, SelectField)
- `SetupForm.parse()` static method
- Field cloning methods (per Discovery 05)
- Promoted tests with Test Doc blocks
- 100% coverage of parsing logic

**Dependencies**: Phase 4 complete (parsing utilities available), Phase 2 complete (fixtures)

**Risks**:
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Missing form field types | Medium | High | Verify fixture has all types before implementing |
| Radio button grouping fails | Medium | Medium | Scratch test edge cases (multiple groups, unchecked radios) |

#### Tasks (TAD Approach)

| #   | Status | Task | Success Criteria | Log | Notes |
|-----|--------|------|------------------|-----|-------|
| 5.1 | [ ] | Write scratch probes for FormField classes | 10-15 probes testing encode(), copy() for all 4 field types | - | Per Discovery 05 (cloning) |
| 5.2 | [ ] | Write scratch probes for form identification | 5-8 probes finding form by "Apply" button presence | - | Per Discovery 01 (no JS) |
| 5.3 | [ ] | Write scratch probes for input extraction | 10-15 probes for text, checkbox inputs | - | Test name extraction, value parsing |
| 5.4 | [ ] | Write scratch probes for radio grouping | 8-10 probes for multiple radio groups, selected detection | - | Regression-prone edge case |
| 5.5 | [ ] | Write scratch probes for select extraction | 5-8 probes for option parsing, selected detection | - | Test value vs text handling |
| 5.6 | [ ] | Write scratch probes for label inference | 10-12 probes for `<label for>` and `<td>` sibling strategies | - | Critical for fuzzy matching |
| 5.7 | [ ] | Implement FormField abstract class | Abstract with name, label; abstract methods encode(), copy() | - | Per initial-details.md lines 581-588 |
| 5.8 | [ ] | Implement TextField subclass | With value, inputType; encode() and copy() methods | - | Per initial-details.md lines 590-606 |
| 5.9 | [ ] | Implement CheckboxField subclass | With bool value, rawValue; encode() returns empty map if false | - | Per initial-details.md lines 608-627 |
| 5.10 | [ ] | Implement RadioGroupField subclass | With selected, options list; encode() with null handling | - | Per initial-details.md lines 629-650 |
| 5.11 | [ ] | Implement SelectField subclass | With selected, options list; encode() returns selected value | - | Per initial-details.md lines 658-679 |
| 5.12 | [ ] | Implement SetupForm class structure | With method, action, fields, fieldsByName map, formElement, base | - | Per initial-details.md lines 305-334 |
| 5.13 | [ ] | Implement SetupForm.parse() - form finding | Find form by querying for "Apply" submit button | - | Per initial-details.md lines 337-343 |
| 5.14 | [ ] | Implement SetupForm.parse() - input extraction | Extract all input elements, create field objects by type | - | Per initial-details.md lines 352-399 |
| 5.15 | [ ] | Implement SetupForm.parse() - select extraction | Extract all select elements, parse options | - | Per initial-details.md lines 401-422 |
| 5.16 | [ ] | Implement label inference helpers (_labelForInput, _labelFromRow) | Per initial-details.md lines 838-849, 851-860 | - | Critical for robustness |
| 5.17 | [ ] | Promote form finding tests to packages/skyecho/test/unit/setup_form_test.dart | 2-3 tests with Test Docs (form found, form not found, multiple forms) | - | Critical path |
| 5.18 | [ ] | Promote field extraction tests to packages/skyecho/test/unit/setup_form_test.dart | 4-5 tests with Test Docs covering all field types | - | 100% coverage required |
| 5.19 | [ ] | Promote radio grouping tests to packages/skyecho/test/unit/setup_form_test.dart | 2-3 tests with Test Docs for edge cases | - | Regression-prone |
| 5.20 | [ ] | Promote label inference tests to packages/skyecho/test/unit/setup_form_test.dart | 2-3 tests with Test Docs for both strategies | - | Opaque behavior |
| 5.21 | [ ] | Delete non-valuable scratch tests | Clean up packages/skyecho/test/scratch/ | - | |
| 5.22 | [ ] | Verify 100% coverage on SetupForm parsing | Run coverage tool | - | Constitution requirement |

#### Test Examples (Promoted Tests)

```dart
// packages/skyecho/test/unit/setup_form_test.dart
import 'dart:io';
import 'package:test/test.dart';
import 'package:html/parser.dart' as html;
import 'package:skyecho/skyecho.dart';

void main() {
  group('SetupForm.parse', () {
    test('given_setup_page_fixture_when_parsing_then_finds_form_by_apply_button', () {
      /*
      Test Doc:
      - Why: Validates form identification strategy (per Critical Discovery 01: no JS execution)
      - Contract: SetupForm.parse returns non-null when form contains input/button with "Apply" value
      - Usage Notes: Parser looks for submit button with value containing "apply" (case-insensitive)
      - Quality Contribution: Catches changes to form structure or button labels
      - Worked Example: <form><input type="submit" value="Apply"></form> → SetupForm (found); <form><button>Save</button></form> → null
      */

      // Arrange
      final fixture = File('packages/skyecho/test/fixtures/setup_form_sample.html').readAsStringSync();
      final doc = html.parse(fixture);
      final base = Uri.parse('http://192.168.4.1/');

      // Act
      final form = SetupForm.parse(doc, base);

      // Assert
      expect(form, isNotNull);
      expect(form!.action.toString(), contains('/setup'));
    });

    test('given_radio_inputs_same_name_when_parsing_then_groups_into_single_field', () {
      /*
      Test Doc:
      - Why: Ensures radio button grouping logic handles multiple options correctly (regression guard)
      - Contract: SetupForm.parse creates single RadioGroupField per unique name attribute with all options
      - Usage Notes: Radio buttons with same name= are collated; selected= detected from checked attribute
      - Quality Contribution: Prevents duplicate fields for radio groups; documents grouping behavior
      - Worked Example: <input type="radio" name="mode" value="A" checked><input type="radio" name="mode" value="B"> → RadioGroupField(name="mode", options=[A,B], selected="A")
      */

      // Arrange
      final html = '''<form>
        <input type="radio" name="receiver_mode" value="UAT" />
        <input type="radio" name="receiver_mode" value="1090ES" checked />
        <input type="submit" value="Apply" />
      </form>''';
      final doc = html.parse(html);
      final base = Uri.parse('http://192.168.4.1/');

      // Act
      final form = SetupForm.parse(doc, base)!;
      final radioField = form.fields.whereType<RadioGroupField>().first;

      // Assert
      expect(radioField.name, equals('receiver_mode'));
      expect(radioField.options.length, equals(2));
      expect(radioField.selected, equals('1090ES'));
    });
  });
}
```

#### Acceptance Criteria
- [ ] All 4 FormField subclasses implemented with encode() and copy()
- [ ] SetupForm.parse() finds form by "Apply" button
- [ ] SetupForm.parse() extracts all field types from fixture
- [ ] Radio button grouping works correctly
- [ ] Label inference uses both `<label for>` and `<td>` strategies
- [ ] At least 10-15 promoted tests with Test Doc blocks
- [ ] 100% coverage on parsing logic
- [ ] All promoted tests pass

---

### Phase 6: Configuration Update Logic (TAD)

**Objective**: Implement SetupUpdate builder pattern and fuzzy field matching using TAD.

**Deliverables**:
- `SetupUpdate` class with all typed fields
- `SetupForm.updatedWith()` method
- `SetupForm.asPost()` method
- `FormPost` class
- Fuzzy label matching helper
- `SkyEchoClient.applySetup()` and `clickApply()` methods
- Promoted tests with Test Doc blocks

**Dependencies**: Phase 5 complete (SetupForm available), Phase 3 complete (client skeleton)

**Risks**:
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Fuzzy matching too permissive | Medium | Medium | Test with similar labels, document matching rules |
| Field mapping fails for new fields | Low | Medium | Provide rawByFieldName escape hatch |

#### Tasks (TAD Approach)

| #   | Status | Task | Success Criteria | Log | Notes |
|-----|--------|------|------------------|-----|-------|
| 6.1 | [ ] | Write scratch probes for SetupUpdate builder pattern | 5-8 probes testing cascade operator syntax | - | Test fluent API ergonomics |
| 6.2 | [ ] | Write scratch probes for fuzzy label matching | 10-15 probes for exact, contains, normalized matching | - | Per Discovery 03 |
| 6.3 | [ ] | Write scratch probes for field cloning and update | 8-10 probes ensuring original form not mutated | - | Per Discovery 05 (immutability) |
| 6.4 | [ ] | Write scratch probes for _setFirst, _setNth helpers | 5-8 probes for index errors, type mismatches | - | Edge cases for helper methods |
| 6.5 | [ ] | Write scratch probes for _setSelect, _setRadio helpers | 8-10 probes for option validation, error messages | - | Test actionable hints |
| 6.6 | [ ] | Implement SetupUpdate class | All typed fields (icaoHex, callsign, etc.), rawByFieldName map | - | Per initial-details.md lines 704-734 |
| 6.7 | [ ] | Implement ReceiverMode enum | With display and wireValue fields per initial-details.md lines 737-745 | - | Example of domain enum |
| 6.8 | [ ] | Implement FormPost class | Simple data class with target and data fields | - | Per initial-details.md lines 688-692 |
| 6.9 | [ ] | Implement SetupForm.asPost() | Returns FormPost with current field values encoded | - | Per initial-details.md lines 429-435 |
| 6.10 | [ ] | Implement SetupForm.updatedWith() - cloning | Clone all fields using copy() method | - | Per initial-details.md lines 438-440 |
| 6.11 | [ ] | Implement SetupForm.updatedWith() - label indexing | Build byLabel map using _normLabel for fuzzy matching | - | Per initial-details.md lines 442-459 |
| 6.12 | [ ] | Implement SetupForm.updatedWith() - field updates | Apply all typed field updates per initial-details.md lines 461-493 | - | Use helper methods |
| 6.13 | [ ] | Implement SetupForm.updatedWith() - raw overrides | Apply rawByFieldName overrides per initial-details.md lines 495-513 | - | Escape hatch |
| 6.14 | [ ] | Implement _setFirst, _setNth, _setSelect, _setRadio helpers | Per initial-details.md lines 519-574 with SkyEchoFieldError on failure | - | Include actionable hints |
| 6.15 | [ ] | Implement SkyEchoClient.fetchSetupForm() | GET /setup, parse, throw SkyEchoParseError if null | - | Per initial-details.md lines 72-85 |
| 6.16 | [ ] | Implement SkyEchoClient.applySetup() | Fetch form, apply update, submit POST | - | Per initial-details.md lines 87-113 |
| 6.17 | [ ] | Implement SkyEchoClient.clickApply() | Fetch form, submit as-is | - | Per initial-details.md lines 115-128 |
| 6.18 | [ ] | Implement ApplyResult class | Simple success wrapper | - | Per initial-details.md lines 695-698 |
| 6.19 | [ ] | Promote fuzzy matching tests to packages/skyecho/test/unit/setup_update_test.dart | 3-4 tests with Test Docs for normalization, contains matching | - | Critical for robustness |
| 6.20 | [ ] | Promote field update tests to packages/skyecho/test/unit/setup_update_test.dart | 5-6 tests with Test Docs covering all update types | - | Critical path |
| 6.21 | [ ] | Promote error handling tests to packages/skyecho/test/unit/setup_update_test.dart | 3-4 tests with Test Docs for field not found, bad values | - | Verify actionable hints |
| 6.22 | [ ] | Promote integration tests to packages/skyecho/test/unit/skyecho_client_test.dart | 2-3 tests with Test Docs for applySetup() with MockClient | - | End-to-end unit test |
| 6.23 | [ ] | Delete non-valuable scratch tests | Clean up packages/skyecho/test/scratch/ | - | |

#### Test Examples (Promoted Tests)

```dart
// packages/skyecho/test/unit/setup_update_test.dart
import 'package:test/test.dart';
import 'package:html/parser.dart' as html;
import 'package:skyecho/skyecho.dart';

void main() {
  group('SetupForm.updatedWith fuzzy matching', () {
    test('given_label_with_extra_whitespace_when_updating_then_matches_normalized', () {
      /*
      Test Doc:
      - Why: Ensures fuzzy label matching handles firmware HTML variations (per Critical Discovery 03)
      - Contract: SetupUpdate field names match form labels after normalization (lowercase, collapsed whitespace)
      - Usage Notes: Update uses friendly names like "ICAO Address"; parser matches to "  icao   address  " in HTML
      - Quality Contribution: Prevents false negatives when firmware changes whitespace
      - Worked Example: update.icaoHex on label "  ICAO  Address  " → matches after _normLabel normalization
      */

      // Arrange
      final htmlStr = '''<form>
        <table><tr>
          <td>  ICAO  Address  </td>
          <td><input type="text" name="icao" value="ABC123" /></td>
        </tr></table>
        <input type="submit" value="Apply" />
      </form>''';
      final doc = html.parse(htmlStr);
      final form = SetupForm.parse(doc, Uri.parse('http://test'))!;
      final update = SetupUpdate()..icaoHex = 'XYZ789';

      // Act
      final post = form.updatedWith(update);

      // Assert
      expect(post.data['icao'], equals('XYZ789'));
    });
  });
}
```

#### Acceptance Criteria
- [ ] SetupUpdate builder pattern works with cascade operator
- [ ] Fuzzy label matching handles whitespace, case differences
- [ ] Field cloning prevents original form mutation
- [ ] All helper methods throw SkyEchoFieldError with actionable hints
- [ ] SkyEchoClient.applySetup() works with MockClient
- [ ] At least 13-17 promoted tests with Test Doc blocks
- [ ] All promoted tests pass

---

### Phase 7: Integration Test Framework

**Objective**: Create integration test infrastructure that gracefully skips when hardware unavailable.

**Deliverables**:
- Integration test helper for device detection
- Smoke test for ping
- Integration test for fetchStatus
- Documentation in README for running integration tests

**Dependencies**: Phase 6 complete (all client methods implemented)

**Risks**:
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Device not always available | High | Low | Skip gracefully with clear message |
| Network configuration varies | Medium | Low | Document required network setup |

#### Tasks (Lightweight with Integration Tests)

| #   | Status | Task | Success Criteria | Log | Notes |
|-----|--------|------|------------------|-----|-------|
| 7.1 | [ ] | Create packages/skyecho/test/integration/helpers.dart | canReachDevice() function with timeout | - | Returns bool, catches exceptions |
| 7.2 | [ ] | Write integration smoke test for ping | Test in packages/skyecho/test/integration/device_smoke_test.dart | - | Skip if !canReachDevice() |
| 7.3 | [ ] | Write integration test for fetchStatus | Verify real device returns valid DeviceStatus | - | Skip if device unavailable |
| 7.4 | [ ] | Write integration test for fetchSetupForm | Verify real device returns valid SetupForm | - | Skip if device unavailable |
| 7.5 | [ ] | Document integration test setup in README | Network connection steps, URL, skip behavior | - | README.md at root |
| 7.6 | [ ] | Update justfile with test-integration recipe | Runs packages/skyecho/test/integration/ directory only | - | just test-integration |
| 7.7 | [ ] | Verify tests skip gracefully without device | Run with device disconnected, see skip messages | - | Manual verification |

#### Test Examples (Integration Tests)

```dart
// packages/skyecho/test/integration/device_smoke_test.dart
import 'package:test/test.dart';
import 'package:skyecho/skyecho.dart';
import 'helpers.dart';

void main() {
  group('SkyEcho device integration', () {
    late bool deviceAvailable;

    setUpAll(() async {
      deviceAvailable = await canReachDevice('http://192.168.4.1');
      if (!deviceAvailable) {
        print('⚠️  SkyEcho device not reachable at http://192.168.4.1');
        print('   Connect to SkyEcho WiFi network to run integration tests.');
      }
    });

    test('ping real device', skip: !deviceAvailable, () async {
      final client = SkyEchoClient('http://192.168.4.1');
      final result = await client.ping();
      expect(result, isTrue);
    });

    test('fetchStatus from real device', skip: !deviceAvailable, () async {
      final client = SkyEchoClient('http://192.168.4.1');
      final status = await client.fetchStatus();

      expect(status.ssid, isNotNull);
      expect(status.ssid, startsWith('SkyEcho'));
      expect(status.current.isNotEmpty, isTrue);
    });
  });
}

// packages/skyecho/test/integration/helpers.dart
import 'dart:async';
import 'package:http/http.dart' as http;

Future<bool> canReachDevice(String url) async {
  try {
    final response = await http
        .get(Uri.parse(url))
        .timeout(Duration(seconds: 2));
    return response.statusCode == 200;
  } catch (_) {
    return false;
  }
}
```

#### Acceptance Criteria
- [ ] Integration test helper detects device availability
- [ ] At least 3 integration tests written (ping, fetchStatus, fetchSetupForm)
- [ ] Tests skip gracefully with clear message when device unavailable
- [ ] README documents integration test setup
- [ ] justfile has test-integration recipe
- [ ] All integration tests pass when device available

---

### Phase 8: Example CLI Application

**Objective**: Create example CLI app demonstrating library usage with basic commands.

**Deliverables**:
- `example/main.dart` with CLI app
- Commands: ping, status, configure
- `--url` flag for device URL
- Help text and error handling

**Dependencies**: Phase 6 complete (all client methods available)

**Risks**:
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Complex CLI parsing needed | Low | Low | Keep simple; use if/else for commands |
| Example becomes stale | Medium | Low | Include in acceptance testing |

#### Tasks (Lightweight)

| #   | Status | Task | Success Criteria | Log | Notes |
|-----|--------|------|------------------|-----|-------|
| 8.1 | [ ] | Create packages/skyecho/example/main.dart skeleton | Main function with args parsing | - | packages/skyecho/example/main.dart |
| 8.2 | [ ] | Implement --url flag parsing | Defaults to http://192.168.4.1, accepts override | - | Use args package or manual parsing |
| 8.3 | [ ] | Implement help command/flag | Prints usage, available commands, examples | - | --help or help command |
| 8.4 | [ ] | Implement ping command | Calls client.ping(), prints result | - | example: cd packages/skyecho && dart run example/main.dart ping |
| 8.5 | [ ] | Implement status command | Calls client.fetchStatus(), prints formatted output | - | Show SSID, GPS fix, key status fields |
| 8.6 | [ ] | Implement configure command (basic) | Demonstrates applySetup() with hardcoded example | - | Example: set ICAO to 7CC599 |
| 8.7 | [ ] | Add error handling for all commands | Catch SkyEchoError, print actionable messages | - | Show hints from errors |
| 8.8 | [ ] | Test example app manually with device | Verify all commands work against real device | - | Manual verification |
| 8.9 | [ ] | Test example app manually without device | Verify graceful error handling | - | Manual verification |
| 8.10 | [ ] | Document example usage in README | Quick example commands in README | - | README.md at root |

#### Example Code Structure

```dart
// packages/skyecho/example/main.dart
import 'package:skyecho/skyecho.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.contains('--help')) {
    printHelp();
    return;
  }

  final url = _parseUrl(args);
  final command = args.first;
  final client = SkyEchoClient(url);

  try {
    switch (command) {
      case 'ping':
        await cmdPing(client);
        break;
      case 'status':
        await cmdStatus(client);
        break;
      case 'configure':
        await cmdConfigure(client);
        break;
      default:
        print('Unknown command: $command');
        printHelp();
    }
  } on SkyEchoError catch (e) {
    print('❌ Error: $e');
  }
}

Future<void> cmdPing(SkyEchoClient client) async {
  print('Pinging device...');
  final result = await client.ping();
  print(result ? '✅ Device reachable' : '❌ Device not reachable');
}

// ... other command implementations
```

#### Acceptance Criteria
- [ ] Example app has ping, status, configure commands
- [ ] --url flag works to override default device URL
- [ ] Help text shows usage and examples
- [ ] Error handling catches and displays SkyEchoError with hints
- [ ] Manually tested with real device (all commands work)
- [ ] Manually tested without device (graceful error messages)
- [ ] README includes example usage section

---

### Phase 9: Documentation (Hybrid)

**Objective**: Create comprehensive documentation following hybrid approach (README quick-start + docs/how/ deep guides).

**Deliverables**:
- Updated README.md with quick-start
- docs/how/skyecho-library/ directory with numbered guides
- All public APIs documented with dartdoc

**Dependencies**: All implementation phases complete

**Risks**:
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Documentation becomes stale | Medium | Medium | Include doc validation in acceptance criteria |
| Unclear explanations | Low | Medium | Use real code examples from implementation |

#### Discovery & Placement Decision

**Existing docs/how/ structure**: None (new repository)

**Decision**: Create new `docs/how/skyecho-library/` directory

**File strategy**: Create numbered files:
- 1-overview.md (Introduction, motivation, architecture)
- 2-usage.md (Step-by-step usage guide)
- 3-testing.md (TAD workflow, running tests)
- 4-integration.md (Device communication, capturing fixtures)
- 5-extending.md (Adding fields, handling firmware variations)

#### Tasks (Lightweight)

| #   | Status | Task | Success Criteria | Log | Notes |
|-----|--------|------|------------------|-----|-------|
| 9.1 | [ ] | Survey existing docs/how/ | Confirmed no existing feature directories | - | Discovery step |
| 9.2 | [ ] | Create docs/how/skyecho-library/ directory | Directory exists | - | docs/how/skyecho-library/ (at root) |
| 9.3 | [ ] | Update README.md with quick-start | Installation, basic usage, link to docs/how/ | - | README.md (at root) |
| 9.4 | [ ] | Create 1-overview.md | Introduction, motivation, architecture diagram, key concepts | - | Reference architecture.md |
| 9.5 | [ ] | Create 2-usage.md | Step-by-step guide with code examples (from packages/skyecho/example/main.dart) | - | Include ping, fetchStatus, applySetup examples |
| 9.6 | [ ] | Create 3-testing.md | TAD workflow, Test Doc format, running unit/integration tests | - | Reference constitution.md and spec |
| 9.7 | [ ] | Create 4-integration.md | Device communication details, capturing HTML fixtures, firmware versions | - | Document integration test setup |
| 9.8 | [ ] | Create 5-extending.md | Adding new fields, handling firmware variations, using rawByFieldName | - | Document extensibility |
| 9.9 | [ ] | Add dartdoc comments to all public classes | SkyEchoClient, DeviceStatus, SetupForm, SetupUpdate, errors | - | Per constitution requirement |
| 9.10 | [ ] | Add dartdoc comments to all public methods | Include usage examples in dartdoc where helpful | - | |
| 9.11 | [ ] | Review all docs for broken links | Check all internal links work | - | Manual review |
| 9.12 | [ ] | Peer review documentation | Have someone follow guides, provide feedback | - | Manual step |

#### Content Outlines

**README.md** (Hybrid: quick-start only):
```markdown
# SkyEcho Controller Library

A Dart library for programmatic control of uAvionix SkyEcho 2 ADS-B devices.

## Installation
\`\`\`yaml
dependencies:
  skyecho: ^1.0.0  # (future pub.dev)
\`\`\`

For now: Add lib/skyecho.dart to your project

## Quick Start
\`\`\`dart
import 'package:skyecho/skyecho.dart';

final client = SkyEchoClient('http://192.168.4.1');
final status = await client.fetchStatus();
print('GPS Fix: ${status.hasGpsFix}');
\`\`\`

## Commands
- `just install` - Install dependencies
- `just test` - Run all tests
- `just test-unit` - Run unit tests only
- `just test-integration` - Run integration tests

## Documentation
See [docs/how/skyecho-library/](docs/how/skyecho-library/) for detailed guides.
```

**docs/how/skyecho-library/1-overview.md**:
- What is SkyEcho Controller Library
- Why screen-scraping (no REST API)
- Architecture diagram (Client → Parser → HTTP → Device)
- Key concepts (DeviceStatus, SetupForm, SetupUpdate)
- When to use this library

**docs/how/skyecho-library/2-usage.md**:
- Installation and setup
- Connecting to device (WiFi network)
- Basic operations (ping, fetchStatus, fetchSetupForm, applySetup)
- Code examples (tested, from packages/skyecho/example/main.dart)
- Error handling (catching SkyEchoError, interpreting hints)

**docs/how/skyecho-library/3-testing.md**:
- TAD philosophy overview
- Test Doc format (5 required fields)
- Scratch → Promote workflow
- Running unit tests (`just test-unit`)
- Running integration tests (`just test-integration`)
- Writing new tests (when to promote, when to delete)

**docs/how/skyecho-library/4-integration.md**:
- Device communication protocol (HTTP, cookies, timeouts)
- Integration test setup (WiFi connection, device URL)
- Capturing HTML fixtures from real device
- Updating fixtures when firmware changes
- Documenting firmware versions

**docs/how/skyecho-library/5-extending.md**:
- Adding new SetupUpdate fields
- Handling firmware variations (multiple fixtures)
- Using rawByFieldName escape hatch
- Custom parsing for firmware-specific features
- Contributing guidelines

#### Acceptance Criteria
- [ ] README.md has quick-start section with installation, basic usage, commands
- [ ] All 5 docs/how/skyecho-library/ guides created
- [ ] Code examples tested and working
- [ ] No broken links in documentation
- [ ] All public APIs have dartdoc comments
- [ ] Peer review completed
- [ ] Numbered file structure follows convention

---

### Phase 10: Final Polish & Validation

**Objective**: Final validation, cleanup, and readiness check before marking plan complete.

**Deliverables**:
- All acceptance criteria met
- test/scratch/ cleaned up
- CLAUDE.md updated
- Final test coverage report
- Plan marked COMPLETE

**Dependencies**: All previous phases complete

**Risks**:
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Acceptance criteria missed | Low | High | Systematic checklist review |
| Coverage gaps discovered | Medium | Medium | Address or document with rationale |

#### Tasks (Validation)

| #   | Status | Task | Success Criteria | Log | Notes |
|-----|--------|------|------------------|-----|-------|
| 10.1 | [ ] | Run full test suite | `just test-all` passes (unit + integration if device available) | - | All tests pass |
| 10.2 | [ ] | Run `dart analyze` | Zero warnings, zero errors (cd packages/skyecho && dart analyze) | - | Clean analysis |
| 10.3 | [ ] | Run `dart format .` | All files formatted (cd packages/skyecho && dart format .) | - | Consistent formatting |
| 10.4 | [ ] | Generate coverage report | Run coverage tool, verify 90% core / 100% parsing | - | Document any uncovered branches |
| 10.5 | [ ] | Verify packages/skyecho/test/scratch/ excluded from git | `git status` doesn't show packages/skyecho/test/scratch/ | - | Check .gitignore |
| 10.6 | [ ] | Clean up packages/skyecho/test/scratch/ directory | Remove all scratch tests (not needed anymore) | - | Learning captured in docs/logs |
| 10.7 | [ ] | Review all spec acceptance criteria | Systematically check each criterion from spec | - | Use spec as checklist |
| 10.8 | [ ] | Update CLAUDE.md if needed | Reflect any implementation discoveries | - | CLAUDE.md (at root) |
| 10.9 | [ ] | Verify justfile recipes all work | Run each recipe (install, analyze, format, test-*) | - | Manual verification |
| 10.10 | [ ] | Verify example app works | Run example commands against mock and real device | - | Manual verification |
| 10.11 | [ ] | Create final coverage report | Document coverage percentages in execution log | - | For posterity |
| 10.12 | [ ] | Mark plan status as COMPLETE | Update header in this file | - | |

#### Acceptance Criteria
- [ ] All spec acceptance criteria met (reviewed systematically)
- [ ] All tests pass (unit + integration if device available)
- [ ] `dart analyze` clean
- [ ] Test coverage meets targets (90% core / 100% parsing)
- [ ] packages/skyecho/test/scratch/ cleaned up and excluded from git
- [ ] All justfile recipes work
- [ ] Example app verified
- [ ] CLAUDE.md updated
- [ ] Plan marked COMPLETE

---

## Cross-Cutting Concerns

### Security Considerations

**Input Validation**:
- All user-provided URLs validated (baseUrl in constructor)
- No SQL injection risk (no database)
- No code injection risk (HTML parsing, no eval)

**Data Handling**:
- No sensitive data stored (library is stateless)
- Cookies managed in-memory only (not persisted)
- HTTPS not used (device limitation, private network only)

**Authentication/Authorization**:
- None required (device has no auth on local WiFi)
- Document security implications in README (anyone on WiFi network can control)

### Observability

**Logging Strategy**:
- No logging in library code (library users control logging)
- Error messages include actionable hints for debugging
- Test Doc blocks document expected behavior

**Metrics**:
- Not applicable for library (no telemetry)
- Users can add their own instrumentation

**Error Tracking**:
- All errors extend `SkyEchoError` for easy catching
- Exception types categorized (Network, HTTP, Parse, Field)
- Stack traces preserved from underlying exceptions

### Documentation

**Location**: Hybrid (per Documentation Strategy from spec)

**README.md contains**:
- Project purpose and overview
- Installation (`dart pub get`)
- Build and test commands (`dart analyze`, `dart test`)
- Quick-start code example (ping, fetch status, apply config)
- Link to detailed guides in docs/how/

**docs/how/skyecho-library/ contains**:
- 1-overview.md: How the system works (screen-scraping, architecture)
- 2-usage.md: Usage guide with examples
- 3-testing.md: TAD workflow, Test Doc format
- 4-integration.md: Device communication, integration tests
- 5-extending.md: Extending library, handling firmware variations

**Target Audience**:
- README: Library users who want to control SkyEcho devices
- docs/how/: Developers integrating, testing, or contributing to the library

**Maintenance**:
- Update README for API changes
- Update docs/how/ when architecture, patterns, or device communication details change
- Keep Test Doc blocks current (they are documentation!)

---

## Progress Tracking

### Phase Completion Checklist

- [ ] Phase 1: Project Foundation & Structure - PENDING
- [ ] Phase 2: Capture Real Device HTML Fixtures - PENDING
- [ ] Phase 3: Error Hierarchy & HTTP Infrastructure (TAD) - PENDING
- [ ] Phase 4: HTML Parsing - DeviceStatus (TAD) - PENDING
- [ ] Phase 5: HTML Parsing - SetupForm (TAD) - PENDING
- [ ] Phase 6: Configuration Update Logic (TAD) - PENDING
- [ ] Phase 7: Integration Test Framework - PENDING
- [ ] Phase 8: Example CLI Application - PENDING
- [ ] Phase 9: Documentation (Hybrid) - PENDING
- [ ] Phase 10: Final Polish & Validation - PENDING

### STOP Rule

**IMPORTANT**: This plan must be validated before creating tasks.

**Next steps**:
1. Run `/plan-4-complete-the-plan` to validate plan readiness
2. Only proceed to `/plan-5-phase-tasks-and-brief` after validation passes

---

## Change Footnotes Ledger

**NOTE**: This section will be populated during implementation by `/plan-6-implement-phase`.

During implementation, footnote tags from task Notes will be added here with details:

<!-- Footnotes will be added during implementation -->
