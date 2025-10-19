# Fix Tasks · Phase 6 (Full TDD / Targeted Mocks)

Follow items in order; keep RED→GREEN discipline where tests change.

## 1. Remove out-of-scope change (HIGH)
- **File**: CLAUDE.md
- **Issue**: Phase 6 diff includes workflow prose lacking plan coverage.
- **Action**: Revert this file to pre-phase state or land it via a separate, footnoted task outside Phase 6.
- **Validation**: `git diff CLAUDE.md` should be empty after rerun; phase dossier remains unchanged.

## 2. Restore dossier ↔ execution log links (HIGH)
- **Files**: docs/plans/002-gdl90-receiver-parser/tasks/phase-6-position-messages/tasks.md, execution.log.md, plan table §6
- **Action**:
  1. Add the required metadata block under each execution log heading (`**Dossier Task**: Txxx`, `**Plan Task**: 6.y`, `[📋]` link).
  2. Update Notes column (and plan task table) to point to the actual anchors (GitHub slug form or explicit `<a id="…">`).
- **Validation**: Clicking every `[📋]` and Notes link navigates to the correct heading; graph validators report 0 broken edges.

## 3. Align Evidence Artifacts (MEDIUM)
- **Files**: docs/plans/002-gdl90-receiver-parser/tasks/phase-6-position-messages/tasks.md, phase directory contents
- **Action**: Either commit the referenced `coverage/lcov.info` (and optional HTML) under the phase directory or update the Evidence list to match what exists.
- **Validation**: Evidence checklist entries map to real artefacts; rerun plan-6 review shows no discrepancy.

## Testing Guidance (Full TDD)
- Doc-only fixes: no new code tests required, but rerun `/plan-6-implement-phase` to regenerate execution log links.
- After completing the steps, rerun `dart test` (sanity) and regenerate coverage if artefacts are added.
