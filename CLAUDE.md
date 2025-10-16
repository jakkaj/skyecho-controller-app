# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**SkyEcho Controller Library** - A Dart library for programmatic control of uAvionix SkyEcho 2 ADS-B devices via screen-scraping their web interface (HTTP, no REST API). The library provides hardware-independent development through comprehensive mocking and realistic test data.

**Key Context:**
- Device URL: `http://192.168.4.1` (local WiFi network)
- Single-file library: `lib/skyecho.dart` (~600 lines)
- Screen-scraping approach with defensive HTML parsing
- Platform-agnostic Dart (no Flutter dependencies)

## Commands

### Development Workflow

```bash
# Install dependencies
dart pub get

# Run linter (must be clean)
dart analyze

# Format code
dart format .

# Run unit tests (fast, offline, <5 seconds)
dart test test/unit/

# Run integration tests (requires physical SkyEcho device at 192.168.4.1)
dart test test/integration/

# Run all tests
dart test
```

### Testing Commands

```bash
# Run a single test file
dart test test/unit/skyecho_test.dart

# Run a specific test by name pattern
dart test --name "given_valid_html"

# Run with coverage
dart test --coverage=coverage
dart pub global activate coverage
dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib
```

## Architecture & Testing Philosophy

### Test-Assisted Development (TAD)

This project uses TAD, not traditional TDD. **Every test MUST include a Test Doc comment block** with these 5 required fields:

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

  // Arrange-Act-Assert with clear phases
});
```

### Scratch → Promote Workflow

- **Scratch tests** go in `test/scratch/` (gitignored, excluded from CI)
- **Promote to `test/unit/`** only if test adds durable value:
  - Critical path, Opaque behavior, Regression-prone, or Edge case
- **Delete** scratch tests that don't meet promotion criteria

### Coverage Targets

- Core business logic: **90% minimum**
- Parsing logic (HTML, forms): **100% required**
- Error handling paths: **90% minimum**

### Mock Policy: TARGETED

- Prefer real fixtures (captured HTML) over hand-crafted mocks
- Use `MockClient` from `http` package for unit tests
- Integration tests use real device when available
- Document WHY mocking when introducing new mocks

## Component Architecture

### Core Components

**SkyEchoClient** (entry point)
- Methods: `ping()`, `fetchStatus()`, `fetchSetupForm()`, `applySetup()`, `clickApply()`
- Manages HTTP, cookies, timeouts
- Converts all errors to `SkyEchoError` hierarchy

**DeviceStatus** (status model)
- Parses landing page HTML (`GET /`)
- Properties: `wifiVersion`, `adsbVersion`, `ssid`, `clientsConnected`, `current` (status table)
- Computed: `hasGpsFix`, `isSendingData`

**SetupForm** (configuration form model)
- Parses setup page HTML (`GET /setup`)
- Identifies form by "Apply" submit button
- Extracts: TextField, CheckboxField, RadioGroupField, SelectField
- Fuzzy label matching for robustness

**SetupUpdate** (builder pattern)
- Type-safe configuration updates
- Example: `client.applySetup((u) => u..icaoHex = '7CC599'..callsign = '9954')`
- Maps friendly names → form fields via fuzzy matching

**Error Hierarchy**
- `SkyEchoError` (base with `message` and `hint`)
- `SkyEchoNetworkError`, `SkyEchoHttpError`, `SkyEchoParseError`, `SkyEchoFieldError`
- All errors include actionable hints

### Data Flow

**Fetch Status:** User → `SkyEchoClient` → HTTP GET `/` → Parse HTML → `DeviceStatus`

**Apply Config:** User → `applySetup(builder)` → Fetch form → Parse → Fuzzy match labels → Clone fields → POST `/setup` → `ApplyResult`

### Fuzzy Label Matching

Critical to resilience across firmware versions:

```dart
// Labels normalized: lowercase, trim, collapse whitespace
_normLabel("Receiver Mode") == _normLabel("receiver  mode")

// Matching strategies:
1. Exact match on normalized label
2. Contains match (fuzzy)
3. Raw field name override via update.rawByFieldName
```

## File Structure (Planned)

```
skyecho-controller-app/
├── lib/
│   └── skyecho.dart              # ~600 line single-file library
├── test/
│   ├── fixtures/                 # Captured HTML from real device
│   │   ├── landing_page_sample.html
│   │   └── setup_form_sample.html
│   ├── unit/                     # Fast offline tests with Test Docs
│   │   └── skyecho_test.dart
│   ├── integration/              # Real hardware tests (skip if unavailable)
│   │   └── device_smoke_test.dart
│   └── scratch/                  # Temp probes (gitignored, excluded from CI)
├── example/
│   └── main.dart                 # Usage demonstration
├── docs/
│   ├── plans/                    # Feature specifications
│   ├── rules-idioms-architecture/ # Project doctrine
│   │   ├── constitution.md       # Guiding principles
│   │   ├── rules.md              # MUST/SHOULD standards
│   │   ├── idioms.md             # Dart patterns
│   │   └── architecture.md       # System structure
│   └── initial-details.md        # Original library specification
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
```

## Critical Rules

### Code Standards

- **MUST** run `dart analyze` clean before committing
- **MUST** format with `dart format .`
- **MUST** follow Effective Dart guidelines
- **MUST** use dartdoc (`///`) comments on all public APIs
- **MUST** handle errors with `SkyEchoError` hierarchy + actionable hints

### Testing Standards

- **MUST** include Test Doc blocks (5 fields) in all promoted tests
- **MUST** use Arrange-Act-Assert (AAA) pattern
- **MUST NOT** use network calls in unit tests (use `MockClient`)
- **MUST NOT** use `sleep()` or timers (use time mocking if needed)
- **MUST** ensure tests are deterministic (no flaky tests)
- **MUST** keep unit test suite under 5 seconds total

### Parsing Standards

- **MUST** tolerate missing HTML elements gracefully
- **MUST** provide actionable hints in `SkyEchoParseError`
- **SHOULD** use fuzzy label matching, not exact XPath queries
- **SHOULD** fallback to multiple strategies when finding elements

### Error Handling

All exceptions **MUST**:
1. Extend `SkyEchoError`
2. Include descriptive `message`
3. Provide actionable `hint` when possible
4. Include context (URLs, field names, available options)

Example:
```dart
throw SkyEchoFieldError(
  'Select option not found: "$desiredValue"',
  hint: 'Available: ${options.map((o) => o.text).join(", ")}',
);
```

## Device Communication

**Protocol:** HTTP/1.1 (no HTTPS)
**Base URL:** `http://192.168.4.1`

**Endpoints:**
- `GET /` → Landing page with status
- `GET /setup` → Setup form
- `POST /setup` → Apply configuration (application/x-www-form-urlencoded)

**Session:** Cookie-based (managed by `_CookieJar`)
**Timeout:** 5 seconds default (configurable)

## Platform Notes

- **Dart VM, Flutter (mobile/desktop):** Full support
- **Web:** Requires CORS proxy (out of initial scope)
- **GDL90 Stream:** Placeholder types only, no implementation

## Planning Workflow

This project uses structured planning phases:

1. **/plan-0-constitution** - Establish principles (done)
2. **/plan-1-specify** - Feature specification
3. **/plan-2-clarify** - Resolve ambiguities
4. **/plan-3-architect** - Phase-based plan
5. **/plan-6-implement-phase** - Execute one phase

See `docs/plans/001-dart-repo-foundation-with-mocking/` for current feature spec.

## Guiding Principles

**P1: Hardware-Independent Development** - All features testable without physical device

**P2: Graceful Degradation** - Actionable errors, HTML variation tolerance

**P3: Tests as Documentation (TAD)** - Tests must explain why/what/how with comprehension value

**P4: Type Safety & Clean APIs** - Leverage Dart type system, builder patterns

**P5: Realistic Testing** - Real sample data > minimal mocks

**P6: Incremental Value** - Small batches, working software

## Common Patterns

### Builder Pattern for Updates
```dart
await client.applySetup((u) => u
  ..icaoHex = '7CC599'
  ..callsign = '9954'
  ..enable1090ESTransmit = true
  ..receiverMode = ReceiverMode.es1090);
```

### Named Constructors for Parsing
```dart
final status = DeviceStatus.fromDocument(doc);
final form = SetupForm.parse(doc, baseUri);
```

### Defensive HTML Parsing
```dart
// Try multiple strategies
dom.Element? table = anchor.nextElementSibling;
if (table?.localName != 'table') {
  // Walk forward to find table
  for (var i = 0; i < 4 && n != null; i++) {
    n = n.nextElementSibling;
    if (n?.localName == 'table') { table = n; break; }
  }
}
table ??= doc.querySelector('table'); // Fallback
```

### Mock Client Testing
```dart
final mockClient = MockClient((request) async {
  if (request.url.path == '/') {
    return http.Response(landingPageHtml, 200);
  }
  return http.Response('Not Found', 404);
});

final client = SkyEchoClient('http://test', httpClient: mockClient);
```

## Anti-Patterns to Avoid

❌ **Stateful HTTP Client** - Don't cache responses (cookie management OK)
❌ **Direct DOM retention** - Create immutable models, don't hold references
❌ **Tight HTML coupling** - Use fuzzy matching, provide fallbacks
❌ **Synchronous I/O** - All I/O must be async (`Future<T>`)
❌ **Global mutable state** - Each `SkyEchoClient` is independent
❌ **Tests without Test Docs** - Every promoted test needs 5-field comment block

## References

- Constitution: `docs/rules-idioms-architecture/constitution.md`
- Rules (MUST/SHOULD): `docs/rules-idioms-architecture/rules.md`
- Dart Idioms: `docs/rules-idioms-architecture/idioms.md`
- Architecture: `docs/rules-idioms-architecture/architecture.md`
- Library Spec: `docs/initial-details.md`
