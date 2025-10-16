<!--
Sync Impact Report:
- Version: 1.0.0 (MAJOR - Initial constitution establishment)
- Ratification: 2025-10-16
- Sections Created: Guiding Principles, Quality & Verification Strategy, Delivery Practices, Governance
- Supporting Docs Updated: rules.md, idioms.md, architecture.md (all created)
- Outstanding TODOs: None - all placeholders resolved
- Next Review: After first implementation phase completion
-->

# SkyEcho Controller Library - Project Constitution

**Version:** 1.0.0
**Ratified:** 2025-10-16
**Last Amended:** 2025-10-16
**Status:** Active

## Guiding Principles

### P1: Hardware-Independent Development
**MUST** enable developers to build, test, and debug the complete library without physical hardware access. All core functionality shall be testable using mocks and realistic sample data.

*Rationale:* Reduces development cycle time, eliminates hardware bottlenecks, and enables parallel development by multiple contributors.

### P2: Graceful Degradation & Actionable Errors
**MUST** provide clear, actionable error messages when parsing fails. **SHOULD** tolerate minor HTML variations without breaking. All errors shall include hints pointing to resolution steps.

*Rationale:* The library depends on screen-scraping HTML that may vary across firmware versions. Graceful failures with diagnostic information preserve usability and reduce support burden.

### P3: Tests as Documentation (TAD)
**MUST** write tests that explain *why* they exist, *what contract* they verify, and *how* to use the API. Tests are executable documentation that must pay rent through comprehension value, not just coverage metrics.

*Rationale:* Tests serve dual purposes: verification and teaching. Quality tests reduce onboarding time and prevent regressions while documenting actual usage patterns.

### P4: Type Safety & Clean APIs
**MUST** leverage Dart's type system to prevent misuse at compile time. **SHOULD** use builder patterns and immutable models where appropriate. Public APIs shall be intuitive and self-documenting.

*Rationale:* Type safety catches errors early. Clean APIs reduce cognitive load and make the library pleasant to use.

### P5: Realistic Testing Over Perfect Mocking
**SHOULD** prefer realistic sample data (captured HTML, real device responses) over hand-crafted minimal mocks. Integration tests against real hardware remain the gold standard.

*Rationale:* Realistic test data catches parser edge cases that minimal mocks miss. Real hardware integration tests provide confidence that mocks haven't drifted.

### P6: Incremental Value Delivery
**MUST** deliver working, tested functionality in small increments. **SHOULD** prioritize core happy paths before edge cases. Each increment shall be independently valuable.

*Rationale:* Small batches reduce risk, enable faster feedback, and maintain momentum. Users benefit from early access to core features.

## Quality & Verification Strategy

### Testing Approach
This project employs **Test-Assisted Development (TAD)** with dual testing modes:

1. **Unit Tests** (primary, fast, offline)
   - Run against mocked HTTP responses
   - Execute in < 5 seconds total
   - Provide 90%+ coverage on core logic, 100% on parsing logic
   - Required for all public APIs

2. **Integration Tests** (secondary, real hardware)
   - Run against actual SkyEcho device when available
   - Skipped gracefully in CI when hardware unavailable
   - Validate end-to-end workflows
   - Capture real HTML for updating sample data

### Test Quality Standards
Every test MUST include Test Doc comments explaining:
- **Why**: Business reason, regression guard, or contract verification
- **Contract**: What invariants the test asserts
- **Usage Notes**: How to call the API, gotchas, parameter meanings
- **Quality Contribution**: What failures this test catches
- **Worked Example**: Summary of inputs → outputs

### Tools & Automation
- **Language**: Dart (Flutter SDK)
- **Dependencies**: `http` package for HTTP, `html` package for parsing
- **Mocking**: `http` package's `MockClient` for unit tests
- **Linting**: `dart analyze` must run clean (zero warnings/errors)
- **Formatting**: Standard Dart formatting conventions
- **Documentation**: Dartdoc comments on all public APIs

### Coverage Targets
- Core business logic: **90% minimum**
- Parsing logic (HTML, forms): **100% required**
- Error handling paths: **90% minimum**
- Integration tests: Smoke tests for critical paths

### Manual Verification
- Sample data captured from real device periodically reviewed
- Integration test runs against physical hardware before releases
- Documentation reviewed for clarity and completeness

## Delivery Practices

### Planning Cadence
- Features specified before implementation (see `docs/plans/`)
- High-impact questions clarified before coding begins
- Architecture documented for multi-phase features

### Documentation Expectations
- **README**: Setup, usage examples, test execution
- **API Docs**: Dartdoc comments on all public classes/methods
- **Test Docs**: Inline test documentation per TAD standards
- **Specs**: Feature specifications in `docs/plans/` following canonical structure

### Definition of Done
A feature is complete when:
1. Code implements spec acceptance criteria
2. Unit tests pass with required coverage
3. Integration test framework updated (if applicable)
4. API documentation added/updated
5. Example code demonstrates usage (if public API changed)
6. `dart analyze` runs clean
7. Sample data updated if HTML structure changed

### Code Review Standards
- All changes reviewed by at least one person
- Reviewers verify alignment with guiding principles
- Tests reviewed for TAD compliance (Test Doc blocks present)
- Error messages reviewed for actionability

### Version Control
- Meaningful commit messages
- Feature branches for non-trivial work
- Main branch always buildable and tested

## Governance

### Amendment Procedure
1. Constitution changes require explicit rationale
2. Version bumps follow semantic versioning:
   - **MAJOR**: Breaking changes to principles or governance
   - **MINOR**: New principles or materially expanded guidance
   - **PATCH**: Clarifications or formatting adjustments
3. Supporting docs (rules.md, idioms.md, architecture.md) updated in sync
4. Amendment date recorded in header

### Review Cadence
- **Initial review**: After first implementation phase completion
- **Routine review**: Quarterly or when friction detected
- **Triggered review**: When principle conflicts emerge

### Compliance Tracking
- Code reviews check adherence to rules.md
- Test quality audits verify TAD compliance
- Retrospectives surface doctrine gaps or conflicts

### Escalation Path
When doctrine is unclear or principles conflict:
1. Document the ambiguity in an issue
2. Discuss in code review or team sync
3. Update constitution and supporting docs to clarify
4. Increment version appropriately

---

**Canonical supporting documents**:
- Rules: `rules.md` (same directory)
- Idioms: `idioms.md` (same directory)
- Architecture: `architecture.md` (same directory)
