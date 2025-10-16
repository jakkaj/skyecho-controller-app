# SkyEcho Controller Library - Rules

**Version:** 1.0.0 (synced with [Constitution](constitution.md) v1.0.0)
**Last Updated:** 2025-10-16

This document contains enforceable rules (MUST/SHOULD/MAY) derived from the project constitution. All contributors and reviewers shall follow these standards.

---

## Source Control & Branching

### Git Hygiene

**MUST** write meaningful commit messages that explain *why*, not just *what*.

**MUST** keep the `main` branch in a buildable, tested state at all times.

**SHOULD** use feature branches for non-trivial work (more than a single small commit).

**SHOULD** squash commits or clean up history before merging to main if the branch contains work-in-progress commits.

**MUST NOT** commit secrets, credentials, or environment-specific configuration to version control.

### Branch Naming

**SHOULD** use descriptive branch names: `feature/setup-form-parsing`, `fix/cookie-jar-edge-case`, `docs/update-readme`.

---

## Coding Standards

### Dart Language Conventions

**MUST** follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines.

**MUST** run `dart format .` before committing (standard Dart formatting, no custom rules).

**MUST** resolve all `dart analyze` warnings and errors. Zero tolerance for analyzer issues.

**SHOULD** use `const` constructors where possible for immutability and performance.

**SHOULD** prefer `final` over `var` for local variables that won't be reassigned.

### Naming Conventions

**MUST** use `UpperCamelCase` for class names (e.g., `SkyEchoClient`, `DeviceStatus`).

**MUST** use `lowerCamelCase` for method names, variables, and parameters (e.g., `fetchStatus`, `icaoHex`).

**MUST** use `SCREAMING_SNAKE_CASE` for compile-time constants only.

**SHOULD** use descriptive names; avoid abbreviations unless universally understood (e.g., `http` is OK, `i` for index in obvious loops is OK).

### Code Organization

**MUST** place library code in `lib/` directory.

**MUST** place tests in `test/` directory mirroring `lib/` structure.

**MUST** place sample/fixture data in `test/fixtures/`.

**MUST** keep `lib/skyecho.dart` as the main library export file.

**SHOULD** split large classes into separate files when exceeding ~500 lines.

### Error Handling

**MUST** use custom exception types from the library hierarchy (`SkyEchoError` and subclasses).

**MUST** include actionable `hint` messages in exceptions explaining how to resolve or diagnose the issue.

**MUST** catch and wrap lower-level exceptions (network, parsing) in domain-specific exceptions with context.

**SHOULD** include relevant context in error messages (URLs, field names, expected vs actual values).

### Documentation

**MUST** document all public classes, methods, and fields with dartdoc comments (`///`).

**MUST** include usage examples in dartdoc for complex or non-obvious APIs.

**SHOULD** document parameter meanings, return values, and exceptions thrown.

**MUST** keep dartdoc concise; defer detailed examples to README or separate example files.

---

## Testing & Verification

> This section implements **Test-Assisted Development (TAD)** principles from [Constitution P3](constitution.md).

### Testing Philosophy

**MUST** treat tests as executable documentation that explain *why* they exist and *how* to use the API.

**MUST** ensure every test "pays rent" by providing comprehension value, not just coverage metrics.

**SHOULD** apply test-first development (TDD) for complex logic, algorithms, and critical paths.

**MAY** skip test-first approach for simple operations, configuration changes, or trivial wrappers.

**MUST NOT** write tests purely to hit coverage targets without providing actual value.

### Test Quality Standards

Every test **MUST** include a Test Doc comment block with these five required fields:

1. **Why**: The business reason, regression guard reference (issue #), or contract being verified
2. **Contract**: The invariants this test asserts in plain English
3. **Usage Notes**: How to call the API, parameter meanings, gotchas to avoid
4. **Quality Contribution**: What specific failures this test catches
5. **Worked Example**: Summary of inputs → outputs for concrete understanding

**Example (Dart):**

```dart
test('given_iso_date_when_parsing_invoice_then_returns_normalized_cents', () {
  /*
  Test Doc:
  - Why: Regression guard for AUD rounding bug (#482) that truncated cents
  - Contract: parseInvoice returns {totalCents:int, date:DateTime} with exact cent accuracy
  - Usage Notes: Supply currency code; parser defaults to strict mode (throws on unknown fields)
  - Quality Contribution: Catches rounding/locale drift and date-TZ bugs; documents required fields
  - Worked Example: "1,234.56 AUD" → totalCents=123456; "2025-10-11+10:00" → DateTime(UTC+10)
  */

  // Arrange
  final invoice = '1,234.56 AUD\n2025-10-11+10:00';

  // Act
  final result = parseInvoice(invoice, currency: 'AUD');

  // Assert
  expect(result.totalCents, equals(123456));
  expect(result.date.year, equals(2025));
});
```

**MUST** use clear test naming following behavioral format:
- Pattern: `given_<context>_when_<action>_then_<expected_outcome>`
- Alternative: Descriptive sentence format acceptable if equally clear

**SHOULD** structure tests with clear Arrange-Act-Assert (AAA) phases.

**MUST NOT** write ambiguous tests that leave reviewers guessing what's being verified.

### Scratch → Promote Workflow (TAD Approach)

**MAY** write exploratory "probe tests" in `test/scratch/` for fast iteration and learning.

**MUST** exclude `test/scratch/` from CI execution (via `.gitignore` or CI configuration).

**MUST** exclude `test/scratch/` from version control (add to `.gitignore`).

**Promotion Heuristic** - A scratch test **MUST** be promoted (moved to `test/unit/` or `test/integration/`) **only if** it meets one or more criteria:
- **Critical path**: Covers core functionality users depend on
- **Opaque behavior**: Documents non-obvious behavior that would confuse future maintainers
- **Regression-prone**: Guards against bugs that have occurred or are likely
- **Edge case**: Validates boundary conditions not obvious from reading code

**MUST** delete scratch tests that don't meet promotion criteria. Keep learning notes in PR descriptions or commit messages.

**MUST** add complete Test Doc comment blocks when promoting tests from scratch.

### Test-Driven Development (TDD) Guidance

**SHOULD** use test-first (TDD) approach for:
- Complex business logic and algorithms
- Public API contracts
- Critical paths (authentication, data persistence, money calculations)
- Parsing logic with multiple edge cases

**MAY** skip test-first for:
- Simple getters/setters
- Configuration changes
- Trivial wrappers or pass-through code
- Exploratory spikes (use scratch tests instead)

**MUST** follow RED-GREEN-REFACTOR cycle when using TDD:
1. Write failing test (RED)
2. Make it pass with minimal code (GREEN)
3. Refactor for clarity and performance (REFACTOR)

**MUST NOT** apply TDD dogmatically; use judgment based on value added to design process.

### Test Reliability & Quality

**MUST NOT** use actual network calls in unit tests; use `MockClient` or fixtures.

**MUST NOT** use `sleep()`, `Future.delayed()`, or timers in tests unless absolutely necessary (prefer time mocking).

**MUST** ensure tests are deterministic; flaky tests **MUST** be fixed or deleted immediately.

**SHOULD** keep unit tests reasonably fast (<5 seconds total suite execution).

**MUST** document performance requirements in test specs when timing/resource constraints are critical.

### Test Organization

**Directory structure:**
- `test/scratch/` - Exploratory probes, **excluded from CI and git**
- `test/unit/` - Isolated component tests with Test Doc blocks
- `test/integration/` - Multi-component or hardware-dependent tests
- `test/fixtures/` - Shared test data (HTML samples, JSON responses)

**MUST** mirror `lib/` structure in `test/unit/` (e.g., `lib/skyecho.dart` → `test/unit/skyecho_test.dart`).

**SHOULD** group related tests using `group()` blocks with descriptive names.

**MUST** place realistic sample data (HTML responses, device output) in `test/fixtures/`.

### Mock Usage Policy

**Mock Policy for this project: TARGETED**

**SHOULD** prefer real data and fixtures over mocks when practical.

**MAY** use mocks for:
- External HTTP calls (via `MockClient`)
- Time-dependent code (date/time mocking)
- Hardware dependencies that can't run in CI

**MUST** document *why* a real dependency isn't used when introducing a mock.

**SHOULD** keep mocks behavior-focused, not implementation-focused.

**MUST NOT** create complex mock hierarchies that are harder to understand than the real code.

### Coverage Targets

**MUST** achieve minimum coverage thresholds:
- Core business logic: **90% line coverage**
- Parsing logic (HTML, forms): **100% line coverage**
- Error handling paths: **90% branch coverage**

**MUST** document any uncovered branches with rationale (e.g., defensive impossible cases).

**SHOULD** use coverage reports to find untested code, not as a goal in itself.

### Integration Testing

**MUST** design integration tests to gracefully skip when hardware is unavailable.

**Example pattern:**
```dart
// integration_test/device_smoke_test.dart
void main() {
  final deviceAvailable = await canReachDevice('http://192.168.4.1');

  test('ping real SkyEcho device', skip: !deviceAvailable, () async {
    final client = SkyEchoClient('http://192.168.4.1');
    expect(await client.ping(), isTrue);
  });
}
```

**SHOULD** run integration tests against real hardware before releases.

**SHOULD** capture real device HTML responses periodically to update `test/fixtures/`.

---

## Tooling & Automation

### Required Tools

**MUST** use Dart SDK (stable channel) for development.

**MUST** run `dart pub get` to install dependencies before building/testing.

**MUST** run `dart analyze` and fix all issues before committing.

**SHOULD** run `dart test` locally before pushing.

### Continuous Integration (Future)

**SHOULD** configure CI to run:
1. `dart pub get`
2. `dart analyze` (must pass with zero issues)
3. `dart test` (excluding integration tests by default)
4. Coverage report generation

**MUST** exclude integration tests from CI by default (hardware unavailable).

**MAY** add CI flag to enable integration tests when mock/fake device endpoint available.

### Linting Configuration

**MUST** use `analysis_options.yaml` in repo root for consistent linting.

**SHOULD** enable strict analysis options:
```yaml
analyzer:
  strong-mode:
    implicit-casts: false
    implicit-dynamic: false
  errors:
    missing_required_param: error
    missing_return: error
```

---

## Code Review Standards

### Review Checklist

Reviewers **MUST** verify:

- [ ] Code aligns with [Guiding Principles](../../memory/constitution.md) (especially P2: Graceful Degradation, P3: TAD, P4: Type Safety)
- [ ] Tests include complete Test Doc blocks (5 required fields)
- [ ] Error messages are actionable with helpful hints
- [ ] Public APIs have dartdoc comments
- [ ] `dart analyze` runs clean
- [ ] No hardcoded secrets or environment-specific config
- [ ] Test coverage meets thresholds (90% core, 100% parsing)

**SHOULD** verify:
- [ ] Commit messages are clear and meaningful
- [ ] Code follows Effective Dart guidelines
- [ ] Naming is descriptive and consistent
- [ ] Complex logic is commented
- [ ] Sample data is realistic (if updated)

### Review Etiquette

**MUST** be respectful and constructive in review comments.

**SHOULD** distinguish between blocking issues (MUST fix) and suggestions (nice-to-have).

**SHOULD** explain *why* a change is requested, linking to principles or rules when applicable.

**MAY** approve with minor nits if core functionality is solid.

---

## Dependency Management

### Version Constraints

**MUST** use compatible version ranges (`^`) for published packages in `pubspec.yaml`:
```yaml
dependencies:
  http: ^1.2.1
  html: ^0.15.4
```

**SHOULD** allow patch and minor updates automatically (via `^` syntax).

**MUST** test against dependency updates periodically (run `dart pub upgrade`).

**MUST NOT** commit `pubspec.lock` for library packages (only for applications).

### Adding Dependencies

**SHOULD** minimize dependencies; prefer standard library when possible.

**MUST** justify new dependencies in PR description (what problem it solves, why custom code insufficient).

**SHOULD** prefer well-maintained packages with active communities.

---

## Release & Versioning (Future)

When publishing to pub.dev (future milestone):

**MUST** follow semantic versioning:
- **MAJOR**: Breaking API changes
- **MINOR**: New features, backward-compatible
- **PATCH**: Bug fixes, no API changes

**MUST** update `CHANGELOG.md` with release notes.

**MUST** tag releases in git: `v1.2.3`.

**SHOULD** run full integration test suite against real hardware before releasing.

---

**Related Documents:**
- [Constitution](constitution.md) - Guiding principles
- [Idioms](idioms.md) - Dart patterns and conventions
- [Architecture](architecture.md) - System structure and boundaries
