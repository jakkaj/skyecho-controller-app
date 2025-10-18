# Style and Conventions
- Follow Effective Dart plus project rules in `docs/rules-idioms-architecture/` (const constructors, prefer final, meaningful names).
- Public APIs require concise dartdoc comments; document usage examples for complex APIs.
- Tests must include Test Doc comment blocks covering Why, Contract, Usage Notes, Quality Contribution, Worked Example.
- Error handling uses domain-specific exceptions (`SkyEchoError` hierarchy) with actionable hints and wrapped lower-level errors.
- Keep `lib/skyecho.dart` as main export; mirror library structure in tests; store fixtures under `test/fixtures/`.