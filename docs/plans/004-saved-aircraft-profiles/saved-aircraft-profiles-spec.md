# Saved Aircraft Profiles

## Summary

Allow pilots to maintain a pre-saved list of aircraft profiles (callsign + ICAO hex pairs) that can be quickly selected from a dropdown on the home screen, eliminating manual re-entry when switching between aircraft. A dedicated management screen ("Planes") enables adding, editing, and removing profiles, with automatic synchronization between the local list and the currently configured device.

## Goals

- **Reduce cognitive load**: Eliminate manual typing of callsign and hex codes during pre-flight when switching aircraft
- **Support multi-aircraft operations**: Enable pilots who fly multiple aircraft to maintain a persistent library of their fleet
- **Maintain device sync**: Auto-select the profile matching the device's current configuration (by hex) to provide immediate context
- **Prioritize local data**: When saving, local profile data takes precedence over device configuration if hex matches but callsign differs
- **Provide simple management**: Offer a dedicated UI for adding, editing, and removing aircraft profiles

## Non-Goals

- Cloud sync or multi-device profile sharing (local device storage only)
- Importing profiles from external sources (ForeFlight, CSV, etc.)
- Aircraft metadata beyond callsign and hex (registration, type, photo, etc.)
- Profile validation against FAA/ICAO databases
- Profile-specific device configurations (mode, squawk, etc.) – profiles only store callsign + hex
- Automatic device reconfiguration on profile selection (user must explicitly tap "save" or "apply")

## Complexity

**Score**: CS-3 (medium)

**Breakdown**:
- **S (Surface Area)**: 2 – Touches home screen (dropdown widget, selection logic), new Planes management screen, navigation layer, state management, persistence layer, and device sync coordinator
- **I (Integration)**: 1 – Requires local storage dependency (e.g., `shared_preferences`, `sqflite`, or `hive`) + existing `skyecho` library integration
- **D (Data/State)**: 1 – Minor schema for aircraft profiles (id, callsign, hex, created/modified timestamps); no migrations unless storage backend changes
- **N (Novelty)**: 1 – Requirements are mostly clear; some ambiguity around edge cases (duplicate hex handling, selection persistence, conflict resolution UX)
- **F (Non-Functional)**: 0 – Standard mobile app requirements; no special performance, security, or compliance constraints
- **T (Testing/Rollout)**: 1 – Requires unit tests (profile CRUD, sync logic), widget tests (dropdown, management screen), and integration tests (device sync round-trip)

**Total**: 2 + 1 + 1 + 1 + 0 + 1 = **6** → CS-3 (medium)

**Confidence**: 0.75

**Assumptions**:
- App is Flutter-based (tactical_radar project) using the `skyecho` Dart library
- Local-only storage is acceptable (no cloud backend)
- User manually triggers device configuration updates (no auto-apply on selection)
- Device fetches (`fetchStatus`) are already implemented and return current hex/callsign

**Dependencies**:
- Existing `skyecho` library API (`fetchStatus`, `applySetup`)
- Local storage plugin decision (to be made in architecture phase)
- State management solution (if not already present in app)

**Risks**:
- Persistence layer choice may constrain future multi-device sync if added later
- Sync logic complexity if device state polling is slow or unreliable
- UX friction if auto-selection fails silently (needs clear feedback)

**Phases**:
1. **Phase 1: Data Model & Persistence** – Define profile schema, implement CRUD operations with local storage
2. **Phase 2: Management UI** – Build Planes screen with add/edit/delete functionality
3. **Phase 3: Home Screen Integration** – Add dropdown widget, wire up selection state
4. **Phase 4: Device Sync Logic** – Implement auto-selection based on device hex, conflict resolution on save

## Testing Strategy

**Approach**: Lightweight Testing

**Rationale**: This is primarily a CRUD feature with straightforward UI interactions. Focus testing effort on core functionality (profile persistence, device sync matching) while avoiding exhaustive edge case coverage.

**Focus Areas**:
- Profile CRUD operations (create, read, update, delete) work correctly
- Device hex matching auto-selects correct profile
- Local override behavior when hex matches but callsign differs
- Persistence across app restarts

**Excluded**:
- Exhaustive edge case testing (unusual characters, extreme lengths)
- Performance testing with large profile counts (assume <20 profiles)
- Complex concurrency scenarios
- Detailed UI interaction testing beyond happy path

**Mock Usage**: Avoid mocks entirely

**Rationale**: Use real storage implementation and captured device response fixtures. This ensures tests reflect actual runtime behavior and catches integration issues early. Only mock when absolutely necessary (e.g., unavailable external services).

## Documentation Strategy

**Location**: README.md only

**Rationale**: This is a user-facing feature that pilots need to discover and use quickly. A concise section in the main README provides immediate visibility and quick-start guidance.

**Content**:
- Brief feature overview (what it does, why it's useful)
- How to access Planes management screen
- How to add/edit/delete profiles
- How dropdown auto-selection works
- Screenshots showing key UI elements (Planes screen, dropdown)

**Target Audience**: Pilots using the app for multiple aircraft

**Maintenance**: Update README when UI changes significantly or new profile-related features are added

## Acceptance Criteria

1. **Profile Creation**: User can navigate to Planes screen and create a new aircraft profile by entering callsign and ICAO hex; profile is persisted and appears in the list immediately.

2. **Profile Editing**: User can select an existing profile in Planes screen, modify callsign or hex, and changes are saved; updated profile appears in home screen dropdown.

3. **Profile Deletion**: User can delete a profile from Planes screen; profile is removed from local storage and no longer appears in home screen dropdown.

4. **Dropdown Display**: Home screen displays a dropdown (or similar picker widget) showing all saved profiles with clear labels (e.g., "N12345 (7C1234)").

5. **Auto-Selection on Launch**: When app launches and fetches device status:
   - If device's current hex matches a saved profile, that profile is auto-selected in the dropdown (even if callsign differs)
   - If device hex is new (not in local profiles), automatically create a new profile with device's hex and callsign, save it to local storage, and auto-select it in the dropdown
   - Previous manual selections are not persisted across sessions (device is source of truth)

6. **Manual Selection**: User can manually select any profile from the dropdown; selected profile's callsign and hex populate the corresponding input fields (or are staged for next save).

7. **Local Override on Save**: When user saves configuration and local profile hex matches device hex but callsign differs, local profile's callsign is written to device without confirmation prompt (local wins silently).

8. **Empty State Handling**: If no profiles exist, home screen shows appropriate empty state (e.g., "No saved aircraft – tap Planes to add one").

9. **Navigation**: User can navigate to Planes screen via a permanent bottom navigation tab labeled "Planes" (or "Aircraft"); navigation is smooth and state is preserved on return.

10. **Persistence Across Sessions**: Saved profiles persist across app restarts; user sees the same list when relaunching the app.

11. **Hex Uniqueness Enforcement**: When user attempts to save a profile with an ICAO hex that already exists in another profile, show validation error and prevent save; prompt user to edit existing profile or use different hex.

12. **Input Validation**: Callsign and hex fields require non-empty values with reasonable length (<50 characters); no strict format enforcement (trust pilot to enter correct values).

## Risks & Assumptions

**Risks**:
- **Device Sync Latency**: If `fetchStatus` is slow, auto-selection may lag or timeout → Need to design for async loading state
- **Invalid Input Acceptance**: Minimal validation may allow incorrectly formatted values; device will reject on apply (surface error clearly to user)
- **Storage Migration**: Changing storage backend later (e.g., SQLite → Hive) may require migration logic → Choose initial storage carefully
- **Hex Edit Complexity**: If user needs to change an aircraft's hex code, they must delete and recreate the profile (no in-place hex editing if uniqueness constraint active)

**Assumptions**:
- User has physical access to aircraft documentation (knows correct hex/callsign pairs)
- App has network access to device when sync is needed (no offline editing of device config)
- Home screen already has infrastructure for device status fetching (reuse existing flow)
- Users typically manage <20 aircraft (no pagination needed in Planes list)

## Open Questions

1. **Profile Ordering**: Should profiles be sorted (alphabetically by callsign? by creation date?) or user-sortable (drag-to-reorder)?

2. **Profile Limits**: Is there a practical upper limit on number of profiles (e.g., 50), or should app support unbounded lists?

## ADR Seeds (Optional)

### Decision Drivers
- **Local-first storage**: Must work offline; no cloud dependency in initial release
- **Simple CRUD**: Profile model is minimal (2 fields + metadata); complex relational DB overkill
- **Fast read access**: Dropdown population should be instantaneous (<50ms)
- **Future extensibility**: May add profile metadata (aircraft type, photo) later

### Candidate Alternatives
**A. shared_preferences** – Key-value store (JSON-serialized list)
  - Pros: Minimal dependency, fast for small datasets, no schema
  - Cons: No indexing, difficult to query, size limits (~10MB)

**B. sqflite** – SQLite database
  - Pros: Mature, supports complex queries, no size limits, indexing
  - Cons: Overkill for 2-field model, requires schema migrations

**C. hive** – NoSQL box storage
  - Pros: Fast, type-safe, no SQL, good for simple models
  - Cons: Less mature than SQLite, smaller ecosystem

**D. drift (moor)** – Type-safe SQL wrapper
  - Pros: Compile-time safety, migrations built-in, powerful queries
  - Cons: Heavyweight for simple CRUD, learning curve

### Stakeholders
- **Primary user**: Pilot using app to manage multiple aircraft configurations
- **Maintainer**: Developer balancing simplicity vs. future extensibility

## Clarifications

### Session 2025-11-12

**Q1: Testing Strategy**
- **Answer**: Lightweight Testing
- **Impact**: Focus on core CRUD and sync functionality; skip exhaustive edge case coverage
- **Updated Sections**: Added "## Testing Strategy" section

**Q2: Mock Usage Policy**
- **Answer**: Avoid mocks entirely
- **Impact**: Use real storage + captured device fixtures; ensures tests match runtime behavior
- **Updated Sections**: "## Testing Strategy" → Mock Usage field

**Q3: Documentation Strategy**
- **Answer**: README.md only
- **Impact**: User-facing docs in main README for quick discovery; include screenshots and usage guide
- **Updated Sections**: Added "## Documentation Strategy" section

**Q4: Duplicate Hex Handling**
- **Answer**: Prevent duplicates entirely
- **Impact**: Enforce hex uniqueness at save time; eliminates auto-selection ambiguity
- **Updated Sections**: Added AC #11 (Hex Uniqueness Enforcement), updated "## Risks & Assumptions", removed Open Question #1

**Q5: Input Validation Rules**
- **Answer**: Minimal validation (non-empty, <50 chars)
- **Impact**: Trust pilot expertise; device will reject invalid values on apply
- **Updated Sections**: Added AC #12 (Input Validation), updated "## Risks & Assumptions", removed Open Questions #1-2 (validation)

**Q6: Conflict Resolution UX**
- **Answer**: Silent local override
- **Impact**: No confirmation prompt when local callsign differs from device; fast save flow
- **Updated Sections**: Updated AC #7 (Local Override on Save), removed Open Question #2 (conflict UX)

**Q7: Navigation Pattern**
- **Answer**: Bottom navigation tab
- **Impact**: Planes management is a first-class feature with permanent tab; high discoverability
- **Updated Sections**: Updated AC #9 (Navigation), removed Open Question #4 (navigation pattern)

**Q8: Selection Persistence**
- **Answer**: Always sync with device (device is source of truth)
- **Impact**: No manual selection persistence; always match device hex on launch
- **Updated Sections**: Updated AC #5 (Auto-Selection on Launch), removed Open Question #1 (selection persistence)

**User Clarification (during Q8)**
- **Request**: If device hex is new (not in local DB), automatically create profile from device data
- **Impact**: App learns new aircraft automatically; seamless onboarding for first-time connections
- **Updated Sections**: Updated AC #5 to include auto-creation of new profiles from device data
