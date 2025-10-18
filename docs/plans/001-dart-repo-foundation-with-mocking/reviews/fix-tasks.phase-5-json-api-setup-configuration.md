# Fix Tasks – Phase 5 (TAD)

1. **Guard POST verification**  
   - Add a promoted unit test (with full Test Doc block) that simulates a mismatch between the intended update and the follow-up GET response; assert `ApplyResult.verified` is `false` and mismatches are surfaced.  
   - Update `SkyEchoClient.applySetup` to diff `newConfig` vs `verifiedConfig`, populate mismatch details, and set `verified` accordingly.

2. **Handle nullable ownship filter fields**  
   - Add tests covering `SetupConfig.fromJson`/`toJson` when `ownshipFilter` values are `null` (filter disabled).  
   - Adjust `SetupConfig` (model, serializer, validator) to treat filter ICAO/FLARM IDs as nullable and keep serialization symmetric.

3. **Fix GPS longitude validation**  
   - Add tests for 60 m (even) and 31/33 m edge cases.  
   - Update `SkyEchoValidation.validateGpsLonOffset` to allow the full 0–60 m even range while rejecting odd inputs.

4. **Enforce SIL/SDA invariants**  
   - Add promoted tests that demonstrate `SetupConfig.validate()` rejecting SIL ≠ 1 and SDA outside {0,1}.  
   - Introduce dedicated validation helpers (e.g., `validateSil`, `validateSda`) and call them from `SetupConfig.validate()`.

5. **Align scope & ledger**  
   - Either relocate or remove the out-of-scope artifacts (`docs/how/skyecho-data.md`, `.gitignore`, coverage vm.json files) or secure explicit plan alignment.  
   - For any retained artifacts, add the corresponding footnote entries in the phase tasks and plan ledger.

6. **Rename promoted tests**  
   - Update `packages/skyecho/test/unit/setup_config_test.dart` to use Given-When-Then naming for all promoted tests, keeping Test Doc metadata in sync.
