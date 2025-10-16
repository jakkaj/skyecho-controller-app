# Dart Repository Foundation with Mocking & Testing

## Summary

Establish the foundational Dart project structure for the SkyEcho controller library with comprehensive mocking infrastructure, realistic sample data, and dual testing modes. This enables developers to build and test the complete library without requiring access to physical SkyEcho hardware, while maintaining the ability to run integration tests against real devices when available.

The library provides a clean, type-safe API for controlling uAvionix SkyEcho 2 devices by screen-scraping their web interface, parsing HTML forms, and submitting configuration changes.

## Goals

1. **Enable hardware-independent development** - Developers can write, test, and debug the complete SkyEcho library without needing a physical device, reducing development cycle time and hardware dependencies.

2. **Provide realistic test data** - Sample HTML responses that accurately represent the SkyEcho's actual landing page, setup form structure, and status tables, ensuring tests validate against real-world scenarios.

3. **Support dual testing modes**:
   - Unit tests using mocked HTTP responses (fast, offline, CI-friendly)
   - Integration tests against real hardware (when device is available)

4. **Implement complete library specification** - All classes, methods, and functionality defined in `docs/initial-details.md`:
   - `SkyEchoClient` with ping, fetchStatus, fetchSetupForm, applySetup, clickApply
   - `DeviceStatus` parsing with GPS fix detection and status heuristics
   - `SetupForm` parsing with fuzzy label matching
   - `SetupUpdate` builder pattern for configuration changes
   - All form field types (TextField, CheckboxField, RadioGroupField, SelectField)
   - Complete error hierarchy with actionable hints

5. **Establish proper Dart project structure** - Standard Dart package layout with pubspec.yaml, lib/, test/, proper dependency management, linting configuration, and justfile for common tasks.

6. **Demonstrate library usage** - Working example code showing common operations (ping, fetch status, update configuration).

## Non-Goals

1. **Flutter UI implementation** - This specification covers only the core Dart library and testing infrastructure. UI components are a separate feature.

2. **GDL90 stream implementation** - Per the library specification, GDL90 ingest is explicitly a placeholder with type definitions only. No UDP/TCP parsing implementation is included.

3. **Production deployment configuration** - No publishing to pub.dev or production hardening (logging, metrics, etc.) in this phase.

4. **Multi-firmware version support** - Initial implementation targets a single reference firmware version matching the HTML structure from the specification screenshots. Additional firmware variants are future enhancements.

5. **Web platform CORS proxy** - The specification mentions web platforms may need a proxy; that's not included in this foundation work.

6. **Advanced mocking scenarios** - Focus on happy path and basic error cases. Exotic network conditions (partial responses, connection drops mid-stream) are not required initially.

## Acceptance Criteria

1. **Project builds successfully**
   - `dart pub get` resolves all dependencies without errors
   - `dart analyze` runs clean with no warnings or errors
   - Project follows standard Dart package conventions
   - Dependencies use compatible version ranges (`^`) per library best practices
   - `justfile` provides recipes for common tasks (build, test, analyze, format)

2. **Library implements all specified functionality**
   - `SkyEchoClient` class with all methods from specification
   - `DeviceStatus.fromDocument()` correctly parses landing page HTML
   - `SetupForm.parse()` correctly identifies and parses all form field types
   - `SetupUpdate` builder pattern works with fuzzy label matching
   - All error types (Network, HTTP, Parse, Field) are implemented with hints

3. **Mock HTTP infrastructure works**
   - Mock client can simulate successful device responses
   - Mock client can simulate error scenarios (timeout, HTTP errors, malformed HTML)
   - Tests can run completely offline without network access
   - Cookie jar behavior is testable

4. **Sample data is realistic and comprehensive**
   - Sample landing page HTML captured from real SkyEcho device
   - Sample setup form HTML captured from real SkyEcho device
   - Sample data includes status header (versions, SSID, clients) and "Current Status" table
   - Sample data includes all field types: text inputs, checkboxes, radio groups, selects
   - Single reference firmware version (captured early in implementation)
   - Basic error scenario mocks (404, timeout) for error path testing

5. **Unit tests provide coverage**
   - All public methods of `SkyEchoClient` have unit tests
   - `DeviceStatus` parsing tested with various status values (GPS fix yes/no, sending data detection)
   - `SetupForm` parsing tested with complete form structure
   - `SetupUpdate` tested with all update types (text, checkbox, radio, select)
   - Error handling tested for all error types
   - Tests run in < 5 seconds total

6. **Integration test framework exists**
   - Skeleton integration test that detects if device is reachable
   - Integration tests skipped gracefully when hardware unavailable
   - Clear instructions for running integration tests
   - At least one smoke test (ping) implemented for real hardware

7. **Example code demonstrates usage**
   - Example CLI app in `example/main.dart` with basic command options (ping, status, configure)
   - CLI can run against mock data or real device (via --url flag)
   - Example demonstrates: ping, fetch status, apply configuration update
   - Abbreviated code snippets in README for quick reference

8. **Documentation is complete**
   - README explains project purpose, setup, running tests
   - API documentation (dartdoc comments) on public classes/methods
   - Clear distinction between unit vs integration test execution

## Risks & Assumptions

### Assumptions

1. **HTML structure stability** - We assume the HTML structure in our sample data accurately represents actual SkyEcho firmware and is reasonably stable across minor firmware updates.

2. **Single firmware version sufficient** - Initial development can proceed with sample data from one firmware version; multi-version support can be added when needed.

3. **MockClient sufficiency** - The `http` package's `MockClient` provides adequate mocking capabilities for our testing needs without requiring more sophisticated tools.

4. **Label matching works** - The fuzzy label matching strategy (normalizing whitespace, case-insensitive, contains-matching) will successfully map user-friendly field names to actual form fields across firmware variations.

5. **Device network availability** - For integration testing, we assume the SkyEcho device is accessible at `http://192.168.4.1` when connected to its Wi-Fi network.

### Risks

1. **Real device HTML divergence** - **Risk**: Actual device HTML structure may differ from our sample data, causing parsers to fail.
   - *Mitigation*: Design parsers with graceful degradation; provide actionable error messages indicating which fields couldn't be found.

2. **Field label changes** - **Risk**: Firmware updates may change field labels, breaking label-based matching.
   - *Mitigation*: Support both label matching and raw field name override via `rawByFieldName`; document how to handle label changes.

3. **Incomplete test coverage** - **Risk**: Mocking might not catch real-world edge cases that only appear with actual device communication.
   - *Mitigation*: Maintain integration test suite; run against real hardware before releases.

4. **Mock drift** - **Risk**: Mock responses may become outdated as firmware evolves.
   - *Mitigation*: Capture real HTML responses during integration testing; update sample data periodically.

5. **Missing error scenarios** - **Risk**: Initial sample data may not cover all error cases (malformed responses, partial data).
   - *Mitigation*: Add error scenario samples as they're discovered; prioritize most common failure modes first.

## Open Questions

**Resolved during Session 2025-10-16:**

1. ✅ **Sample data versioning** - RESOLVED: Single reference dataset captured from real device early in implementation (Q8)

2. ✅ **CI integration test handling** - DEFERRED: No CI configuration in this phase; use justfile for local commands (Q7)

3. ✅ **Code coverage threshold** - DEFERRED: Use constitution defaults (90% core / 100% parsing / 90% error handling) (Q4)

4. **Error scenario sample data** - DEFERRED: Start with minimal mocks for error paths; add realistic samples if patterns emerge during integration testing

5. **Form submission verification** - DEFERRED: Mock validation checks POST data structure; integration tests verify end-to-end

6. ✅ **Dependency version constraints** - RESOLVED: Use compatible version ranges (`^`) per library best practices (Q6)

7. ✅ **Example placement** - RESOLVED: Example CLI app in `example/main.dart` with basic commands; abbreviated snippets in README (Q5)

---

## Clarifications

### Session 2025-10-16

**Q1: Testing Strategy**
- **Answer**: B (TAD - Test-Assisted Development)
- **Rationale**: Use tests to help development

**Q2: Mock Usage Policy**
- **Answer**: B (Allow targeted mocks)
- **Rationale**: Limited to external systems or slow dependencies

**Q3: Documentation Strategy**
- **Answer**: C (Hybrid - README + docs/how/)
- **README content**: Setup, build commands, basic usage
- **docs/how/ content**: How the system works, integration details, device communication patterns

**Q4: Code Coverage Threshold**
- **Answer**: Deferred - use constitution defaults (90% core / 100% parsing / 90% error handling)

**Q5: Example Code Placement**
- **Answer**: C (Both - example app + README snippets)
- **Rationale**: Create example app with basic CLI options to demonstrate usage; include abbreviated snippets in README

**Q6: Dependency Version Constraints**
- **Answer**: B (Compatible ranges with `^`)
- **Rationale**: Standard for libraries; allows users to resolve conflicts

**Q7: CI Integration Test Handling**
- **Answer**: Deferred - no CI configuration in this phase
- **Rationale**: Focus on local development; use justfile for build/test commands

**Q8: Sample Data Strategy**
- **Answer**: A (Single reference dataset)
- **Rationale**: Capture from real device early in implementation; add more versions as variations discovered

## Testing Strategy

**Approach**: TAD (Test-Assisted Development)

**Rationale**: Tests serve as executable documentation to guide development, especially valuable for the HTML parsing logic where edge cases and field mappings need clear documentation for future maintainers.

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

**TAD-Specific Requirements**:
- **Scratch → Promote workflow**: Exploratory tests in `test/scratch/` (gitignored), promote only if meeting criteria (Critical path, Opaque behavior, Regression-prone, Edge case)
- **Test Doc blocks required**: Every promoted test MUST include 5-field comment:
  - Why: Business reason / regression guard
  - Contract: What invariants are asserted
  - Usage Notes: How to call API, gotchas
  - Quality Contribution: What failures this catches
  - Worked Example: Input → output summary
- **Promotion heuristic**: Keep tests that are Critical, Opaque, Regression-prone, or Edge cases; delete others
- **Format**: Arrange-Act-Assert pattern with clear phases
- **Naming**: `given_<context>_when_<action>_then_<outcome>` or equivalent behavioral format

**Coverage Targets**:
- Core business logic: 90% minimum
- HTML parsing logic: 100% required
- Error handling: 90% minimum

**Mock Usage**: Targeted mocks only

**Mock Policy Rationale**: Prefer real fixtures (captured HTML) to catch parser edge cases; use `MockClient` only for HTTP layer to enable offline testing. Document WHY when introducing mocks.

**Allowed Mock Targets**:
- HTTP client (`http.MockClient`) for network isolation
- Time/date functions if needed for deterministic tests
- External system dependencies (if added later)

**Prefer Real Data For**:
- HTML parsing (use `test/fixtures/` with real device captures)
- Form field extraction and mapping
- Error message formatting
- Status computations

## Documentation Strategy

**Location**: Hybrid (README.md + docs/how/)

**Rationale**: New users need quick setup and basic examples (README), while developers integrating the library or contributing need deeper understanding of device communication, HTML parsing strategies, and testing approaches (docs/how/).

**Content Split**:

**README.md contains**:
- Project purpose and overview
- Installation (`dart pub get`)
- Build and test commands (`dart analyze`, `dart test`)
- Quick-start code example (ping, fetch status, apply config)
- Link to detailed guides in docs/how/

**docs/how/ contains**:
- How the system works (screen-scraping approach, component architecture)
- Device communication patterns (HTTP endpoints, cookie management, fuzzy label matching)
- Integration details (connecting to real device, capturing HTML fixtures)
- Testing guide (TAD workflow, Test Doc format, scratch → promote process)
- Extending the library (adding new fields, handling firmware variations)

**Target Audience**:
- README: Library users who want to control SkyEcho devices
- docs/how/: Developers integrating, testing, or contributing to the library

**Maintenance**: Update README for API changes; update docs/how/ when architecture, patterns, or device communication details change.

---

## Clarification Summary

**Session**: 2025-10-16
**Questions Asked**: 8 of 8 (cap reached)

### Coverage

| Category | Status | Count |
|----------|--------|-------|
| **Resolved** | ✅ Answered with decisions | 4 |
| **Deferred** | ⏸️ Use defaults or handle later | 4 |
| **Outstanding** | ⚠️ Still need decisions | 0 |

### Key Decisions Made

1. **Testing Strategy**: TAD (Test-Assisted Development) with 5-field Test Doc blocks
2. **Mock Policy**: Targeted mocks (HTTP client only); prefer real fixtures
3. **Documentation**: Hybrid (README for quick-start, docs/how/ for deep guides)
4. **Example Code**: CLI app in example/ with basic commands
5. **Dependencies**: Compatible ranges (`^`) per library standards
6. **Sample Data**: Single reference dataset from real device
7. **Build System**: justfile for common tasks (no CI this phase)

### Deferred Items

- Code coverage thresholds → Use constitution defaults
- CI configuration → Future phase
- Error scenario fixtures → Add as patterns emerge
- Form submission verification → Integration tests handle end-to-end

**Ready for**: `/plan-3-architect` to generate phase-based implementation plan

---

**Next steps**: Run `/plan-3-architect` to generate the phase-based implementation plan.
