# Flutter Tactical Radar App

## Summary

A Flutter application that provides pilots with a tactical radar display of ADS-B traffic and device configuration capabilities. The app integrates the existing `skyecho` device control library and `skyecho_gdl90` GDL90 parsing library to create an interface for interacting with uAvionix SkyEcho 2 ADS-B receivers.

**Development Strategy**: iOS-only (iPad and iPhone universal app). The iPad version can run directly on Apple Silicon Macs via "Designed for iPad" mode, providing a native development environment without requiring a separate macOS desktop build.

**User Value**: Pilots gain a portable tactical awareness tool that displays nearby aircraft traffic in real-time and allows configuration of their SkyEcho device without requiring external apps or web browsers.

## Platform Discovery: "Designed for iPad" Mode

During initial planning, we discovered that iPad apps can run natively on Apple Silicon Macs through Apple's "Designed for iPad" compatibility layer. This eliminates the need for a separate macOS desktop build for development purposes.

**Benefits:**
- Single codebase targeting iOS (iPhone and iPad)
- Developers can test on Mac hardware without maintaining macOS-specific code
- Simplified platform configuration (no macOS-specific Info.plist, entitlements, or build settings)
- Faster iteration without requiring physical iOS device for basic development

**Considerations:**
- "Designed for iPad" apps run in a scaled iOS environment on Mac
- Some Mac-specific features (keyboard shortcuts, menu bar) not available
- Full iOS permissions model applies (including local network permission)
- Final testing should still occur on physical iOS devices

## Goals

- **iOS Universal App**: Provide a Flutter app for iOS (iPhone and iPad) with consistent functionality across form factors
- **Dual-View Interface**: Create two primary views - Configuration for device management and Radar for traffic visualization
- **Library Integration Foundation**: Establish the architectural patterns for integrating both `skyecho` (device control) and `skyecho_gdl90` (data parsing) packages into a Flutter UI
- **Basic Radar Visualization**: Display traffic on a simple radar-style interface with zoomable range rings and relative positioning
- **Real-Time Data Flow**: Receive and parse GDL90 messages in real-time, updating the UI as new traffic data arrives

## Non-Goals

**Phase 1 explicitly excludes:**
- Advanced tactical features (conflict alerting, terrain awareness, weather overlay)
- Full-featured moving map with chart integration
- Offline maps or sectional chart overlays
- Multi-device support (connecting to multiple SkyEcho units)
- Cloud synchronization or flight data logging
- Background operation or notifications
- Detailed traffic symbology beyond basic position markers
- Audio alerts or voice callouts
- Integration with third-party apps (ForeFlight link, etc.)
- Android support (iOS-first, Android may come later)
- iPad-specific UI optimizations (universal iOS app with consistent interface)

## Acceptance Criteria

The following scenarios must be observable and testable to consider Phase 1 complete:

1. **App Launches Successfully**: User opens app on mobile device and sees navigation UI with Config and Radar view options

2. **Device Discovery & Connection**: User navigates to Config view, enters or confirms SkyEcho device URL (http://192.168.4.1), and app successfully retrieves device status (firmware version, GPS lock, etc.)

3. **Device Configuration**: User can view current SkyEcho settings (ICAO hex, callsign, receiver mode) and modify at least one setting successfully via the app

4. **GDL90 Stream Activation**: User can start/stop the GDL90 UDP stream receiver from within the app, with visual feedback indicating stream status (connected/disconnected)

5. **Radar View Displays**: User navigates to Radar view and sees:
   - Concentric range rings (e.g., 1nm, 2nm, 5nm increments)
   - Ownship indicator at center
   - Zoom controls to adjust range ring scale

6. **Traffic Visualization**: When GDL90 traffic messages are received:
   - Traffic targets appear on radar display at relative positions
   - At minimum, callsign/tail number and altitude are displayed per target
   - Traffic positions update as new messages arrive (≤1 second latency)

7. **Error Handling Visible**: If device connection fails or GDL90 stream errors occur, user sees actionable error messages (not just crashes or blank screens)

## Risks & Assumptions

**Assumptions:**
- Flutter framework is suitable for real-time GDL90 message processing (30-100 msg/sec under high traffic)
- iOS devices (iPhone and iPad) will connect to SkyEcho via WiFi (192.168.4.1)
- Both `skyecho` and `skyecho_gdl90` packages work correctly in Flutter context (not just Dart VM)
- iPad app running on Apple Silicon Macs via "Designed for iPad" provides sufficient development environment to validate all functionality
- iOS 16+ minimum version provides adequate device coverage and modern API access
- State persistence via `shared_preferences` (or similar) is sufficient for user preferences and device settings
- App lifecycle management can cleanly suspend/resume GDL90 stream without data loss

**Risks:**
- **Performance Risk**: Flutter UI updates from high-frequency GDL90 messages may cause dropped frames or lag
  - *Mitigation*: Implement message throttling/batching before UI updates
- **WiFi Connectivity Risk**: iOS WiFi handling (auto-switching to cellular, background disconnects) may disrupt SkyEcho connection
  - *Mitigation*: Implement connection monitoring and auto-reconnect logic
- **State Management Complexity**: Coordinating device state, stream state, and UI state across views may require careful architecture
  - *Mitigation*: Use established Flutter state management pattern (Riverpod, Bloc, etc.) from start
- **Testing Without Hardware**: Development/testing requires either physical SkyEcho device or comprehensive mocking
  - *Mitigation*: Leverage existing mock infrastructure from `skyecho` and `skyecho_gdl90` packages

## Open Questions

### Resolved

1. **Platform Priority**: ~~Which mobile platform should be targeted first - iOS, Android, or both simultaneously?~~ **RESOLVED**: iOS-only (iPhone/iPad). iPad app runs natively on Apple Silicon Macs via "Designed for iPad" mode, eliminating need for separate macOS desktop build.

2. **Minimum OS Versions**: ~~What are the minimum supported OS versions?~~ **RESOLVED**: iOS 16+ for modern API access and reasonable device coverage.

3. **Background Operation**: ~~Should the app continue receiving GDL90 data when backgrounded, or suspend the stream?~~ **RESOLVED**: Suspend stream when backgrounded, resume when foregrounded (battery-friendly, simpler).

4. **State Persistence**: ~~Should device connection settings, zoom level, and other UI preferences be persisted between app sessions?~~ **RESOLVED**: Yes, persist all (device URL, zoom level, preferences) for better UX.

### Deferred (Implementation Details)

5. **Ownship Position Source**: How is ownship (user's aircraft) position determined? From GDL90 ownship messages only, or also device GPS if available? → *Can decide during Radar view implementation*

6. **Traffic Filtering**: Should the radar view have any traffic filtering options (altitude range, distance cutoff) in Phase 1, or display all received traffic? → *Start with no filtering (simpler); add if needed*

7. **Orientation Handling**: Should the radar display support device rotation/orientation changes, or lock to a single orientation? → *Can decide during UI implementation; likely lock to landscape initially*

8. **Network Permissions**: Are there specific privacy/permission requirements for WiFi network access on iOS? → *Research during iOS deployment phase; add Info.plist entries as needed*

## Testing Strategy

**Approach**: TAD (Test-Assisted Development)

**Rationale**: Flutter UI development with real-time data integration benefits from executable documentation that validates behavior while explaining architecture patterns. The existing `skyecho` and `skyecho_gdl90` packages already use TAD successfully.

**Focus Areas**:
- State management integration (device state, stream state, UI state coordination)
- Real-time GDL90 message processing and UI update batching
- Library integration patterns (`skyecho` and `skyecho_gdl90` in Flutter context)
- Radar visualization coordinate transforms and traffic positioning
- Connection lifecycle management (start/stop/reconnect)

**Excluded**:
- Basic Flutter widget composition (use standard patterns)
- Simple UI layout (Config/Radar navigation)
- Platform boilerplate (generated Flutter project structure)

**Mock Usage**: Allow targeted mocks - limited to external systems (SkyEcho device HTTP/UDP) or slow dependencies

**TAD-Specific Requirements**:
- **Scratch→Promote Workflow**: Exploratory tests in `test/scratch/` (gitignored), promote to `test/unit/` only if they provide durable value (Critical path, Opaque behavior, Regression-prone, Edge case)
- **Test Doc Blocks**: All promoted tests MUST include 5-field Test Doc comment block:
  - Why: Validates core parsing logic for landing page status table
  - Contract: DeviceStatus.fromDocument returns non-null status with populated fields
  - Usage Notes: Pass complete HTML document; parser is resilient to missing optional fields
  - Quality Contribution: Catches HTML structure changes; documents expected field mappings
  - Worked Example: Sample HTML with "Wi-Fi Version: 0.2.41" → wifiVersion="0.2.41"
- **Coverage Targets**: Core business logic 90%, UI state management 90%, error handling 90%

## Documentation Strategy

**Location**: Hybrid (README.md + docs/how/)

**Rationale**: Flutter app needs quick-start for users (README) plus detailed architecture/integration docs for developers (docs/how/)

**Content Split**:
- **README.md**: Quick-start essentials - `flutter run`, basic usage, connecting to SkyEcho, navigating views
- **docs/how/**: Architecture details, state management patterns, library integration (`skyecho` + `skyecho_gdl90`), radar visualization internals

**Target Audience**:
- README: End users (pilots) and developers doing initial setup
- docs/how/: Developers extending features, maintainers, contributors

**Maintenance**: Update README for user-facing changes; update docs/how/ for architectural changes or library integration patterns

## Clarifications

### Session 2025-10-27

**Q1: Testing Strategy**
**A**: TAD (Test-Assisted Development)
**Impact**: Tests serve as executable documentation; scratch→promote workflow; Test Doc blocks required

**Q2: Mock Usage**
**A**: Allow targeted mocks (external systems, slow dependencies only)
**Impact**: Mock SkyEcho device HTTP/UDP, but use real state management and library integrations

**Q3: Documentation Strategy**
**A**: Hybrid (README + docs/how/)
**Split**: README has quick-start (`flutter run`, basic usage); docs/how/ has architecture, state management, library integration
**Impact**: Documentation planning in architecture phase must include both locations

**Q4: State Persistence**
**A**: Yes, persist all (device URL, zoom level, preferences)
**Impact**: Requires state persistence layer (shared_preferences or similar); affects state management architecture

**Q5: Background Operation (iOS)**
**A**: Suspend stream when backgrounded, resume on foreground
**Impact**: Implement app lifecycle listeners; cleaner battery usage; no iOS background capabilities needed

**Q6: Minimum OS Versions**
**A**: iOS 16+
**Impact**: Access to modern Flutter APIs; reasonable device coverage; can use iOS 16 features

### Clarification Summary

| Category | Status | Decision | Impact |
|----------|--------|----------|--------|
| **Testing Strategy** | ✅ Resolved | TAD (Test-Assisted Development) | Scratch→promote workflow; Test Doc blocks required; 90% coverage targets |
| **Mock Usage** | ✅ Resolved | Targeted mocks only | Mock SkyEcho device HTTP/UDP; real state management |
| **Documentation** | ✅ Resolved | Hybrid (README + docs/how/) | Quick-start in README; architecture in docs/how/ |
| **State Persistence** | ✅ Resolved | Persist all settings | Requires shared_preferences; better UX |
| **Background Behavior** | ✅ Resolved | Suspend stream when backgrounded | App lifecycle management; no iOS background capabilities |
| **Minimum OS** | ✅ Resolved | iOS 16+ | Modern APIs; reasonable device coverage |
| **Ownship Source** | ⏸ Deferred | TBD during implementation | Decide in Radar view phase |
| **Traffic Filtering** | ⏸ Deferred | Start with none | Simpler initial implementation |
| **Orientation** | ⏸ Deferred | TBD during UI work | Likely lock landscape initially |
| **Network Permissions** | ⏸ Deferred | Research during iOS phase | Add Info.plist entries as needed |

**Resolved**: 6 high-impact questions answered
**Deferred**: 4 implementation details postponed to relevant phases
**Outstanding**: 0 blocking ambiguities remain

---

**Next Step**: Run `/plan-3-architect` to generate the phase-based plan.
