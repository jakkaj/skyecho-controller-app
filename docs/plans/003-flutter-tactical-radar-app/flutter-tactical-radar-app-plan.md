# Flutter Tactical Radar App Implementation Plan

**Plan Version**: 1.0.0
**Created**: 2025-10-27
**Spec**: [flutter-tactical-radar-app-spec.md](/Users/jordanknight/github/skyecho-controller-app/docs/plans/003-flutter-tactical-radar-app/flutter-tactical-radar-app-spec.md)
**Status**: DRAFT

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Technical Context](#technical-context)
3. [Critical Research Findings](#critical-research-findings)
4. [Testing Philosophy](#testing-philosophy)
5. [Implementation Phases](#implementation-phases)
   - [Phase 1: Project Setup & Architecture Foundation](#phase-1-project-setup--architecture-foundation)
   - [Phase 2: Device Integration Service Layer](#phase-2-device-integration-service-layer)
   - [Phase 3: GDL90 Stream Service Layer](#phase-3-gdl90-stream-service-layer)
   - [Phase 4: State Management Foundation](#phase-4-state-management-foundation)
   - [Phase 5: Config View UI](#phase-5-config-view-ui)
   - [Phase 6: Radar Display Engine](#phase-6-radar-display-engine)
   - [Phase 7: Radar View UI](#phase-7-radar-view-ui)
   - [Phase 8: Navigation & Lifecycle Management](#phase-8-navigation--lifecycle-management)
   - [Phase 9: State Persistence](#phase-9-state-persistence)
   - [Phase 10: Error Handling & User Feedback](#phase-10-error-handling--user-feedback)
   - [Phase 11: iOS Deployment & Permissions](#phase-11-ios-deployment--permissions)
   - [Phase 12: Documentation](#phase-12-documentation)
6. [Cross-Cutting Concerns](#cross-cutting-concerns)
7. [Complexity Tracking](#complexity-tracking)
8. [Progress Tracking](#progress-tracking)
9. [Change Footnotes Ledger](#change-footnotes-ledger)

---

## Executive Summary

### Problem Statement

Pilots using uAvionix SkyEcho 2 ADS-B receivers need a native mobile application to visualize nearby aircraft traffic in real-time and configure device settings without requiring external tools or web browsers.

### Solution Approach

Develop a Flutter application targeting iOS (iPhone and iPad universal app) that:

1. **Integrates two existing Dart packages**: `skyecho` (HTTP device control) and `skyecho_gdl90` (GDL90 UDP stream parsing)
2. **Provides dual-view interface**: Configuration view for device management, Radar view for traffic visualization
3. **Handles real-time data**: Processes 30-100 GDL90 messages/second with batched UI updates to maintain 60fps performance
4. **Manages application lifecycle**: Suspends GDL90 stream when backgrounded (iOS battery optimization), resumes on foreground
5. **Persists user preferences**: Device URL, zoom level, and UI settings across app sessions
6. **Development Environment**: iPad app runs natively on Apple Silicon Macs via "Designed for iPad" mode, eliminating need for separate macOS desktop build

### Expected Outcomes

- **For Pilots**: Portable tactical awareness tool with basic radar-style traffic display
- **For Developers**: Reference implementation of high-frequency data visualization in Flutter
- **For Project**: Validated architecture for integrating pure Dart packages into Flutter applications

### Success Metrics

- **Performance**: Maintain 60fps with 100 aircraft on radar display
- **Reliability**: Zero crashes during 30-minute flight test with real SkyEcho device
- **Test Coverage**: 90% coverage on state management and service layers
- **Platform**: Full functionality on iOS (iPhone and iPad)

---

## Technical Context

### Current System State

**Existing Infrastructure:**
- `packages/skyecho/` - Pure Dart library for SkyEcho HTTP control (screen-scraping web interface)
  - Public API: `SkyEchoClient`, `DeviceStatus`, `SetupForm`, `SetupUpdate`
  - Error hierarchy: `SkyEchoError` (base), `SkyEchoNetworkError`, `SkyEchoHttpError`, `SkyEchoParseError`, `SkyEchoFieldError`
  - Dependencies: `http`, `html` packages

- `packages/skyecho_gdl90/` - Pure Dart library for GDL90 protocol parsing
  - Public API: `Gdl90Stream`, `Gdl90Message`, `Gdl90Event` (sealed class: DataEvent, ErrorEvent, IgnoredEvent)
  - UDP transport layer with lifecycle management (start/stop/dispose)
  - Zero external dependencies except `args` for examples

**Target Environment:**
- Development: iOS app running on Apple Silicon Mac via "Designed for iPad" mode
- Production: iOS 16+ (iPhone and iPad universal app)
- Network: WiFi connection to SkyEcho device at `http://192.168.4.1`
- Data Rate: 30-100 GDL90 messages/second under high traffic conditions

### Integration Requirements

**Package Integration:**
- Flutter app references both packages via `pubspec.yaml` path dependencies
- Must handle dual error patterns:
  - `skyecho` throws exceptions (catch/rethrow pattern)
  - `skyecho_gdl90` returns events (pattern matching with switch)

**Platform Considerations:**
- **iOS Requirements**:
  - `NSLocalNetworkUsageDescription` in Info.plist for WiFi access to 192.168.4.1
  - `NSBonjourServices` in Info.plist to trigger permission dialog
  - App lifecycle management (suspend stream on background)
  - Deployment target: iOS 16.0+

### Constraints and Limitations

**Performance Constraints:**
- 60fps UI refresh rate = 16ms budget per frame
- GDL90 stream delivers 30-100 msg/sec = one message every 10-33ms
- Must batch UI updates to prevent dropped frames (target: 10fps radar updates)

**Network Constraints:**
- UDP packets >1350 bytes may be silently dropped (MTU limitation)
- iOS UDP socket instability requires separate send/receive sockets
- No guaranteed delivery (UDP is lossy by design)

**Platform Constraints:**
- iOS local network permission dialog may not appear (known bug in iOS 17.4+, 18.x)
- Face ID/Touch ID triggers false `paused` events (debounce lifecycle changes)
- "Designed for iPad" mode on Mac may have limitations compared to native macOS (acceptable for development)

### Assumptions

1. **Flutter Framework**: Adequate for real-time GDL90 processing with proper batching
2. **Package Compatibility**: Both `skyecho` and `skyecho_gdl90` work correctly in Flutter context
3. **Development Workflow**: iPad app running on Apple Silicon Mac via "Designed for iPad" mode sufficient to validate all functionality
4. **State Management**: Riverpod provides best performance/architecture balance for high-frequency updates
5. **Coordinate Transforms**: Equirectangular projection adequate for <50nm radar ranges
6. **Permission Workflow**: Users can manually enable Local Network permission if dialog fails
7. **Device Availability**: Physical SkyEcho device available for integration testing

---

## Critical Research Findings

This section presents 32 discoveries from comprehensive research across codebase patterns, technical constraints, spec ambiguities, and architectural dependencies.

### 🚨 Critical Discoveries (Impact: Critical)

#### Discovery 01: Error Hierarchy Pattern with Message + Hint (S1-01)
**Sources**: [S1-01] (Codebase Pattern Analyst)
**Category**: Pattern | Convention
**Impact**: Critical

**Problem**: Flutter app must integrate with two packages using different error-handling philosophies:
- `skyecho`: Throws typed exceptions with `message` + `hint` fields
- `skyecho_gdl90`: Returns sealed class events (never throws from parser/stream)

**Root Cause**: `skyecho` follows "fail fast with actionable errors" (Constitution P2: Graceful Degradation). `skyecho_gdl90` follows "error as data" to prevent stream breakage in lossy UDP environment.

**Solution**: Flutter app must implement dual error handling:

```dart
// ❌ WRONG - Treats both packages the same
try {
  final status = await client.fetchStatus();
  final event = await stream.events.first;
} catch (e) {
  showError(e.toString()); // Misses GDL90 errors entirely!
}

// ✅ CORRECT - Package-specific error handling
// SkyEcho: try/catch with typed exceptions
try {
  final status = await deviceService.fetchStatus();
  _updateDeviceState(status);
} on SkyEchoNetworkError catch (e) {
  _showError('Network error: ${e.message}\nHint: ${e.hint}');
} on SkyEchoError catch (e) {
  _showError('Device error: ${e.message}');
}

// GDL90: pattern matching with sealed events
stream.events.listen((event) {
  switch (event) {
    case Gdl90DataEvent(:final message):
      _updateRadar(message);
    case Gdl90ErrorEvent(:final reason, :final hint):
      _logWarning('GDL90 parse error: $reason. Hint: $hint');
    case Gdl90IgnoredEvent():
      return; // No-op
  }
});
```

**Action Required**: Create service layer wrappers that convert both error patterns into unified app-level error state.

**Affects Phases**: Phase 2 (Device Service), Phase 3 (Stream Service), Phase 10 (Error Handling)

---

#### Discovery 02: iOS Local Network Permission Dialog Not Triggering (S2-01)
**Sources**: [S2-01] (Technical Investigator)
**Category**: API Limit | Platform Constraint
**Impact**: Critical

**Problem**: iOS 14+ local network permission dialog (`NSLocalNetworkUsageDescription`) often fails to appear, especially in TestFlight builds. Without this permission, UDP sockets cannot bind to 0.0.0.0:4000 for GDL90 reception. Permission toggle may not appear in Settings → Privacy → Local Network.

**Root Cause**: iOS requires **both** `NSLocalNetworkUsageDescription` AND `NSBonjourServices` keys in Info.plist. Dialog only appears when actual network activity occurs (not at app launch). iOS 17.4+ and 18.x have bugs where prompt never shows.

**Solution**: Add both Info.plist keys and provide manual permission instructions:

```xml
<!-- ✅ CORRECT - Both keys required for permission dialog -->
<key>NSLocalNetworkUsageDescription</key>
<string>Connect to ADS-B receiver at 192.168.4.1 for real-time aircraft traffic data and device configuration.</string>
<key>NSBonjourServices</key>
<array>
    <string>_dartobservatory._tcp</string>
</array>
```

**Workaround**: If dialog doesn't appear after GDL90 stream start:
1. Show in-app alert: "Permission required - Go to Settings → Privacy → Local Network → Tactical Radar → Enable"
2. Provide deep link to Settings if possible (iOS 15+)
3. Document manual permission enablement in README

**Action Required**:
- Add Info.plist keys in Phase 11 (iOS Deployment)
- Implement permission detection and user guidance in Phase 10 (Error Handling)
- Test on physical iOS 16+ devices (simulator may not trigger dialog)

**Affects Phases**: Phase 3 (GDL90 Stream), Phase 10 (Error Handling), Phase 11 (iOS Deployment)

**References**:
- https://github.com/flutter/flutter/issues/166333
- https://developer.apple.com/forums/thread/723742

---

#### Discovery 03: UDP Socket Instability on iOS (S2-02)
**Sources**: [S2-02] (Technical Investigator)
**Category**: Framework Gotcha | Platform Constraint
**Impact**: Critical

**Problem**: `RawDatagramSocket` on iOS exhibits severe instability:
- Sockets close unexpectedly with `RawSocketEvent.readClosed`
- `SocketException: No route to host (errno = 65)` even on localhost
- UDP packet loss when send rate exceeds ~10 packets/second
- Send buffer fills quickly, `send()` returns 0 bytes written

**Root Cause**: Dart UDP implementation regression since Flutter 2.2.1 (Dart 2.13+). Default receive buffer (~64KB) too small for 30-100 msg/sec burst traffic. Using same socket for send/receive causes resource conflicts.

**Solution**: Increase receive buffer and use separate sockets:

```dart
// ❌ WRONG - Default buffer, bidirectional socket
final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 4000);
socket.listen((event) { /* receive */ });
socket.send(data, dest, port); // Causes conflicts!

// ✅ CORRECT - Increased buffer, receive-only socket
final receiveSocket = await RawDatagramSocket.bind(
  InternetAddress.anyIPv4,
  4000,
);

// Increase receive buffer to 256KB
receiveSocket.setRawOption(RawSocketOption(
  RawSocketOption.levelSocket,
  RawSocketOption.IPv4MulticastInterface,
  Uint8List(4)..buffer.asByteData().setInt32(0, 262144),
));

receiveSocket.listen((RawSocketEvent event) {
  if (event == RawSocketEvent.read) {
    final datagram = receiveSocket.receive();
    if (datagram != null) {
      _handleGdl90Packet(datagram.data);
    }
  }
});
```

**Action Required**:
- Wrap `Gdl90Stream` in service layer with buffer configuration
- Test extensively on physical iOS devices (not simulator)
- Implement connection health monitoring (detect `readClosed` events)

**Affects Phases**: Phase 3 (GDL90 Stream Service), Phase 10 (Error Handling)

**References**:
- https://github.com/dart-lang/sdk/issues/45824

---

#### Discovery 04: Four-Layer Architecture with Clear Boundaries (S4-03)
**Sources**: [S4-03] (Dependency Mapper)
**Category**: Boundary | Architecture
**Impact**: Critical

**Problem**: Flutter app requires strict layer separation to maintain testability and comply with Constitution P4 (Type Safety & Clean APIs).

**Architectural Context**: Four mandatory layers with unidirectional data flow:

1. **UI Layer** (Widgets): Config view, Radar view, navigation components
2. **State Management Layer**: Device state, stream state, traffic coordination (Riverpod providers)
3. **Service Layer**: Wraps `SkyEchoClient` and `Gdl90Stream` for lifecycle management
4. **Data Layer**: Immutable models from packages (`DeviceStatus`, `Gdl90Message`)

**Design Constraint**:
- **UI Layer**: MUST NOT call package APIs directly. Only observes state and dispatches events.
- **State Management**: MUST coordinate device + stream state. Single source of truth.
- **Service Layer**: MUST handle lifecycle (start/stop/dispose), error conversion, batching.
- **Data Layer**: MUST use package models as-is. No UI-specific fields in domain models.

**Example**:
```dart
// ❌ VIOLATES BOUNDARY - UI calls package API directly
class ConfigView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final client = SkyEchoClient('http://192.168.4.1');
    return FutureBuilder(
      future: client.fetchStatus(), // UI → Package (BAD!)
      builder: (ctx, snap) => Text(snap.data?.wifiVersion ?? ''),
    );
  }
}

// ✅ RESPECTS BOUNDARY - Proper layer separation
// Service Layer (Phase 2)
class DeviceService {
  final SkyEchoClient _client;
  Future<DeviceStatus> fetchStatus() => _client.fetchStatus();
}

// State Management Layer (Phase 4)
final deviceStatusProvider = FutureProvider<DeviceStatus>((ref) {
  final service = ref.watch(deviceServiceProvider);
  return service.fetchStatus();
});

// UI Layer (Phase 5)
class ConfigView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(deviceStatusProvider);
    return statusAsync.when(
      data: (status) => Text('WiFi: ${status.wifiVersion}'),
      loading: () => CircularProgressIndicator(),
      error: (e, s) => ErrorWidget(e),
    );
  }
}
```

**Action Required**: Enforce layer boundaries in code reviews. Create service layer before UI layer.

**Affects Phases**: All phases. Architecture foundation in Phase 1.

**Reference**: architecture.md §Component Architecture, constitution.md P4

---

### ⚠️ High-Impact Discoveries (Impact: High)

#### Discovery 05: State Management Performance with High-Frequency Updates (S2-03)
**Sources**: [S2-03] (Technical Investigator)
**Category**: Performance | Framework Gotcha
**Impact**: High

**Problem**: At 30-100 updates/second (GDL90 rate), traditional state management causes excessive rebuilds. Provider triggers O(N) tree walks. Even `setState()` drops frames with complex UI. Performance comparison for 1000 widgets at 60fps:
- GetX: 10ms rebuild (best performance, poor architecture)
- Riverpod: 14ms rebuild, 44MB memory ✅ **Recommended**
- Provider: 16ms rebuild (exceeds 16ms budget)
- BLoC: 12ms rebuild + 300KB app size (high boilerplate)

**Root Cause**: Most state management wasn't designed for real-time streams. Each update triggers full widget tree walk. At 60fps (16ms budget), 14ms rebuild leaves only 2ms for rendering.

**Solution**: Use Riverpod with selective watching and batching:

```dart
// ❌ WRONG - Full tree rebuilds on every message
class RadarWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final aircraft = Provider.of<AircraftList>(context);
    return CustomPaint(painter: RadarPainter(aircraft)); // Rebuilds 100x/sec!
  }
}

// ✅ CORRECT - Riverpod with selective updates + batching
@riverpod
class TrafficNotifier extends _$TrafficNotifier {
  Timer? _batchTimer;
  final Map<String, Aircraft> _pending = {};

  @override
  Map<String, Aircraft> build() => {};

  void handleGdl90Message(Gdl90Message msg) {
    if (msg.messageType == Gdl90MessageType.traffic) {
      _pending[msg.icaoAddress!.toString()] = Aircraft.fromMessage(msg);

      // Batch updates: notify UI max 10x/sec (100ms intervals)
      _batchTimer?.cancel();
      _batchTimer = Timer(Duration(milliseconds: 100), () {
        state = {...state, ..._pending};
        _pending.clear();
      });
    }
  }
}

class RadarWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(trafficNotifierProvider
      .select((traffic) => traffic.length)); // Only rebuild on count change

    return RepaintBoundary( // Isolate repaints
      child: CustomPaint(painter: RadarPainter(ref)),
    );
  }
}
```

**Action Required**:
- Use Riverpod for state management (not Provider or BLoC)
- Implement 100ms batching in state management layer (Phase 4)
- Wrap `CustomPaint` in `RepaintBoundary` (Phase 6)

**Affects Phases**: Phase 4 (State Management), Phase 6 (Radar Engine), Phase 7 (Radar UI)

**References**: https://www.rootstrap.com/blog/state-management-in-flutter-riverpod-bloc-getx

---

*[Continued with remaining 27 discoveries in actual plan file...]*

---

## Testing Philosophy

### Test-Assisted Development (TAD) Approach

This project employs **Test-Assisted Development (TAD)** as specified in the feature spec and inherited from both `skyecho` and `skyecho_gdl90` packages.

**Rationale**: Flutter UI development with real-time data integration benefits from executable documentation that validates behavior while explaining architecture patterns. TAD provides:
- **Comprehension Value**: Tests explain why they exist and how to use APIs
- **Iterative Refinement**: Scratch tests enable fast exploration before committing to patterns
- **Quality Focus**: Only tests that "pay rent" are promoted to the main suite
- **Documentation**: Test Doc blocks serve as inline architectural documentation

### Scratch → Promote Workflow

**Three-Stage Testing Process**:

1. **Scratch Phase** (`test/scratch/`):
   - Write exploratory probe tests to understand behavior
   - Fast iteration, no documentation requirements
   - Gitignored, excluded from CI
   - Deleted when no longer valuable

2. **Implementation Phase**:
   - Interleave code and scratch test updates
   - Refine behavior based on scratch test feedback
   - No commit to test suite yet

3. **Promotion Phase** (`test/unit/` or `test/integration/`):
   - Identify valuable tests using heuristic:
     - **Critical path**: Core functionality users depend on
     - **Opaque behavior**: Non-obvious patterns needing explanation
     - **Regression-prone**: Bugs that occurred or are likely
     - **Edge case**: Boundary conditions not obvious from code
   - Add complete 5-field Test Doc comment block
   - Move test to appropriate directory
   - Delete scratch test

### Test Doc Comment Block (Required)

Every promoted test MUST include this comment block:

```dart
test('given_<context>_when_<action>_then_<outcome>', () {
  /*
  Test Doc:
  - Why: [Business reason, regression guard (issue #), or contract verification]
  - Contract: [Invariants this test asserts in plain English]
  - Usage Notes: [How to call API, parameter meanings, gotchas]
  - Quality Contribution: [Specific failures this test catches]
  - Worked Example: [Summary of inputs → outputs]
  */

  // Arrange
  // Act
  // Assert
});
```

**Example** (from `packages/skyecho/test/unit/skyecho_test.dart`):

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
  expect(status.current['icao address'], isNotEmpty);
});
```

### Mock Usage Policy: Targeted Mocks

**From Spec Clarifications**: "Allow targeted mocks - limited to external systems (SkyEcho device HTTP/UDP) or slow dependencies"

**Permitted Mocks**:
- ✅ HTTP Client (`http.MockClient` for `SkyEchoClient` HTTP responses)
- ✅ UDP socket (fake `RawDatagramSocket` for `Gdl90Stream`)
- ✅ Time-dependent code (fake `DateTime.now()` for deterministic tests)
- ✅ Platform channels (mock iOS/macOS native APIs via `MethodChannel`)

**NOT Permitted**:
- ❌ Package classes (`SkyEchoClient`, `Gdl90Stream`) - inject mocked HTTP/UDP instead
- ❌ State management logic (use real Riverpod providers in tests)
- ❌ Coordinate transforms (use real math, verify with known inputs)
- ❌ UI widget composition (use real widgets with mocked data sources)

**Rationale**: Mock external I/O boundaries (HTTP, UDP, platform), not domain logic. Use `http.MockClient` per `idioms.md` §Mock Client Pattern, not mockito-style mocks.

**Mock Pattern (from idioms.md)**:
```dart
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

final mockHttpClient = MockClient((request) async {
  if (request.url.path == '/') {
    return http.Response(landingPageFixture, 200);
  }
  return http.Response('Not Found', 404);
});

final client = SkyEchoClient('http://test', httpClient: mockHttpClient);
```

### Coverage Targets

**Project Philosophy**: Coverage metrics are not a primary concern for this project. The focus is on validating that the system works correctly with real hardware and real data, not achieving arbitrary percentage thresholds.

**Validation Approach**:
- Smoke tests prove packages import and integrate correctly
- Integration tests with physical SkyEcho device validate real-world behavior
- Manual testing in actual flight conditions is the ultimate validation
- Promote tests from scratch/ only when they provide genuine value (regression prevention, documenting tricky behavior)

**Coverage Expectations** (guidelines, not gates):
- **Phase 1**: No coverage measurement (setup/scaffolding only)
- **Phase 2+**: Coverage measured but not enforced
- **Service Layer**: Test critical integration points that are regression-prone
- **State Management Layer**: Test complex coordination logic that's hard to reason about
- **UI Layer**: Test user interactions that could break silently
- **Utility Functions**: Test coordinate transforms and parsers where errors are subtle

**What Success Looks Like**:
- Radar displays traffic from real SkyEcho device during flight ✓
- Config view successfully modifies device settings ✓
- App doesn't crash under normal usage ✓
- Tests document behavior we need to preserve ✓

Coverage percentages are secondary to system validation.

### Testing by Layer

#### UI Layer (Widget Tests)

```dart
testWidgets('given_traffic_data_when_rendering_radar_then_displays_callsigns',
           (tester) async {
  /*
  Test Doc:
  - Why: Validates radar visualization contract for traffic display
  - Contract: RadarView renders traffic targets with callsign labels from state
  - Usage Notes: Override trafficProvider with mock data; pump widget tree
  - Quality Contribution: Catches UI rendering bugs when traffic state updates
  - Worked Example: Mock traffic "N12345" at 2nm/090° → Radar shows label "N12345"
  */

  // Arrange
  final container = ProviderContainer(
    overrides: [
      trafficProvider.overrideWith((ref) => mockTrafficState),
    ],
  );

  // Act
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: RadarView()),
    ),
  );
  await tester.pumpAndSettle();

  // Assert
  expect(find.text('N12345'), findsOneWidget);
});
```

#### State Management Layer (Unit Tests)

```dart
test('given_high_frequency_updates_when_batching_then_notifies_max_10hz', () {
  /*
  Test Doc:
  - Why: Performance regression guard - ensures UI batching prevents dropped frames
  - Contract: TrafficNotifier batches updates, notifies UI max 10x/sec (100ms intervals)
  - Usage Notes: Send 100 updates rapidly; verify notifications <= 10 in 1 second
  - Quality Contribution: Catches batching regressions that cause 60fps jank
  - Worked Example: 100 rapid updates → 10 state notifications (not 100)
  */

  // Arrange
  final container = ProviderContainer();
  final notifier = container.read(trafficNotifierProvider.notifier);
  var notificationCount = 0;

  container.listen(
    trafficNotifierProvider,
    (prev, next) => notificationCount++,
  );

  // Act - Send 100 updates in rapid succession
  for (var i = 0; i < 100; i++) {
    notifier.handleGdl90Message(mockTrafficMessage(i));
  }

  await Future.delayed(Duration(seconds: 1));

  // Assert - Batched to max 10 notifications
  expect(notificationCount, lessThanOrEqualTo(10));
});
```

#### State Management Layer (Riverpod Providers - No Service Layer)

```dart
test('given_network_error_when_fetching_status_then_provider_returns_error', () async {
  /*
  Test Doc:
  - Why: Error handling contract - Riverpod provider exposes SkyEchoError to UI layer
  - Contract: deviceStatusProvider catches SkyEchoNetworkError, AsyncValue.error contains it
  - Usage Notes: Override skyEchoClientProvider with mocked HTTP client; watch deviceStatusProvider
  - Quality Contribution: Ensures error propagation through state management without wrapping
  - Worked Example: MockClient returns 500 → AsyncValue.error(SkyEchoHttpError) → UI shows error
  */

  // Arrange
  final mockHttpClient = MockClient((request) async {
    return http.Response('Internal Server Error', 500);
  });

  final container = ProviderContainer(
    overrides: [
      skyEchoClientProvider.overrideWithValue(
        SkyEchoClient('http://test', httpClient: mockHttpClient),
      ),
    ],
  );

  // Act
  final statusAsync = container.read(deviceStatusProvider);

  // Assert
  await expectLater(
    statusAsync.future,
    throwsA(isA<SkyEchoHttpError>()),
  );
});
```

### Test Organization

```
apps/tactical_radar/
├── test/
│   ├── scratch/              # Gitignored, excluded from CI
│   │   ├── explore_gdl90.dart
│   │   └── radar_coordinate_probes.dart
│   ├── unit/                 # Fast, offline tests with Test Docs
│   │   ├── services/
│   │   │   ├── device_service_test.dart
│   │   │   └── stream_service_test.dart
│   │   ├── state/
│   │   │   ├── device_state_test.dart
│   │   │   └── traffic_state_test.dart
│   │   └── utils/
│   │       └── coordinate_transform_test.dart
│   ├── widget/               # Widget tests (UI layer)
│   │   ├── config_view_test.dart
│   │   └── radar_view_test.dart
│   ├── integration/          # Real package integration
│   │   ├── device_integration_test.dart
│   │   └── stream_integration_test.dart
│   └── fixtures/             # Mock HTML, GDL90 bytes
│       ├── device_status.html
│       └── gdl90_traffic_messages.bin
└── .gitignore                # Must include test/scratch/
```

---

## Implementation Phases

*[Phases 1-12 would continue here with detailed task tables, test examples, and acceptance criteria - this is a partial plan due to length constraints]*

### Phase 1: Project Setup & Architecture Foundation

**Objective**: Establish Flutter app project structure, configure dependencies, and validate package integration.

**Deliverables**:
- Flutter project created at `apps/tactical_radar/`
- Dependencies configured (`skyecho`, `skyecho_gdl90`, `riverpod`, `shared_preferences`)
- Directory structure matches TAD conventions
- Integration smoke tests pass (can import both packages)

**Dependencies**: None (foundational phase)

**Risks**:

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Package path dependency resolution fails | Low | High | Test with `flutter pub get` immediately |
| iOS-specific build errors | Medium | Medium | Validate build immediately after setup |
| Analysis options conflict with existing packages | Low | Low | Inherit from packages, add app-specific rules |

### Tasks (TAD Approach)

| #   | Status | Task | Success Criteria | Log | Notes |
|-----|--------|------|------------------|-----|-------|
| 1.0 | [ ] | Write smoke test for app launch | Test renders MaterialApp, shows app title | - | Test-first: write before scaffolding |
| 1.1 | [ ] | Create Flutter project with iOS support | `flutter create --platforms=ios apps/tactical_radar` succeeds | - | Use org ID: com.skyecho.tacticalradar |
| 1.2 | [ ] | Configure pubspec.yaml with package dependencies | Both packages imported successfully via path; flutter_fgbg: ^0.3.0 added | - | Add skyecho, skyecho_gdl90, riverpod, shared_preferences, flutter_fgbg, http (testing) |
| 1.3 | [ ] | Set up directory structure (test/scratch, test/unit, test/widget) | All directories exist, scratch/ in .gitignore | - | Mirror structure from packages; add test/scratch/ to .gitignore |
| 1.4 | [ ] | Copy analysis_options.yaml from skyecho package | `dart analyze` runs clean | - | Add app-specific lint rules if needed |
| 1.5 | [ ] | Create smoke test importing both packages | Test compiles and runs | - | Verify SkyEchoClient and Gdl90Stream constructors |
| 1.6 | [ ] | Configure iOS Info.plist with network permissions | Both NSLocalNetworkUsageDescription and NSBonjourServices present | - | See Discovery S2-01 |
| 1.7 | [ ] | Set iOS minimum deployment target | iOS 16.0+ configured in Xcode | - | Match spec requirements |
| 1.8 | [ ] | Add flutter_fgbg package for lifecycle management | Package added to pubspec.yaml | - | See Discovery S2-05 |
| 1.9 | [ ] | Verify iOS build succeeds | `flutter run -d iphone` or iOS simulator build works | - | No package import errors |

### Acceptance Criteria

- [ ] All tasks passing (9/9 tasks)
- [ ] `flutter pub get` completes without errors
- [ ] `dart analyze` runs clean (zero warnings/errors)
- [ ] Smoke test demonstrates package imports:
  ```dart
  import 'package:skyecho/skyecho.dart';
  import 'package:skyecho_gdl90/skyecho_gdl90.dart';

  void main() {
    final client = SkyEchoClient('http://192.168.4.1');
    final stream = Gdl90Stream(port: 4000);
    print('Smoke test passed: Packages imported successfully');
  }
  ```
- [ ] iOS simulator build succeeds
- [ ] iOS app runs on Apple Silicon Mac via "Designed for iPad" mode
- [ ] Info.plist contains both required keys (NSLocalNetworkUsageDescription, NSBonjourServices)
- [ ] iOS deployment target set to 16.0

---

### Phase 2: Device State Management (Riverpod Providers)

**Objective**: Create Riverpod providers for `SkyEchoClient` integration without service layer wrapper.

**Deliverables**:
- `skyEchoClientProvider` returning configured `SkyEchoClient`
- `deviceStatusProvider` using `SkyEchoClient` to fetch status
- `deviceUrlProvider` for persisted device URL configuration
- Unit tests with Test Doc blocks for all providers
- Integration test with real device (skip if unavailable)

**Dependencies**: Phase 1 complete

**Risks**:

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| SkyEchoError leaks to UI layer | Low | Medium | Document that UI must handle SkyEchoError in AsyncValue.error |
| Provider lifecycle issues | Medium | Medium | Use autoDispose for providers that shouldn't cache |

### Tasks (TAD Approach)

| #   | Status | Task | Success Criteria | Log | Notes |
|-----|--------|------|------------------|-----|-------|
| 2.0 | [ ] | Write test for skyEchoClientProvider configuration | Provider returns client with correct URL | - | Test provider override pattern |
| 2.1 | [ ] | Create Riverpod providers file | lib/providers/device_providers.dart exists | - | All device-related providers in one file |
| 2.2 | [ ] | Implement skyEchoClientProvider | Returns SkyEchoClient(deviceUrl) | - | Watches deviceUrlProvider |
| 2.3 | [ ] | Write test for deviceStatusProvider success case | AsyncValue.data contains DeviceStatus | - | Use MockClient for HTTP |
| 2.4 | [ ] | Write test for deviceStatusProvider error case | AsyncValue.error contains SkyEchoError | - | MockClient returns 500 |
| 2.5 | [ ] | Implement deviceStatusProvider as FutureProvider | Calls client.fetchStatus(), returns AsyncValue | - | AutoDispose to avoid stale cache |
| 2.6 | [ ] | Write test for deviceUrlProvider persistence | URL persists across ProviderContainer instances | - | Mock SharedPreferences |
| 2.7 | [ ] | Implement deviceUrlProvider with persistence | Reads/writes to SharedPreferences | - | Default: http://192.168.4.1 |
| 2.8 | [ ] | Promote valuable tests to test/unit/providers/ | 4-6 tests with Test Doc blocks | - | Apply promotion heuristic |
| 2.9 | [ ] | Create integration test with device availability check | Test skips gracefully if device unavailable | - | Inline canReachDevice() check |

### Test Examples (Write During Scratch Phase)

```dart
// test/unit/providers/device_providers_test.dart (promoted with Test Doc)
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

void main() {
  group('deviceStatusProvider', () {
    test('given_200_response_when_fetching_status_then_returns_device_status', () async {
      /*
      Test Doc:
      - Why: Core provider contract - deviceStatusProvider fetches and parses device status
      - Contract: Provider returns AsyncValue.data(DeviceStatus) on successful HTTP 200
      - Usage Notes: Override skyEchoClientProvider with MockClient; read deviceStatusProvider
      - Quality Contribution: Ensures provider correctly integrates SkyEchoClient; documents Riverpod override pattern
      - Worked Example: MockClient returns landing page HTML → DeviceStatus with wifiVersion="0.2.41"
      */

      // Arrange
      final landingPageHtml = '''
        <html><body>
          Wi-Fi Version: 0.2.41-SkyEcho
          <h3>Current Status</h3>
          <table>
            <tr><td>ICAO Address</td><td>ABC123</td></tr>
          </table>
        </body></html>
      ''';

      final mockHttpClient = MockClient((request) async {
        if (request.url.path == '/') {
          return http.Response(landingPageHtml, 200);
        }
        return http.Response('Not Found', 404);
      });

      final container = ProviderContainer(
        overrides: [
          skyEchoClientProvider.overrideWithValue(
            SkyEchoClient('http://test', httpClient: mockHttpClient),
          ),
        ],
      );

      // Act
      final statusAsync = await container.read(deviceStatusProvider.future);

      // Assert
      expect(statusAsync.wifiVersion, equals('0.2.41-SkyEcho'));
      expect(statusAsync.current['icao address'], equals('ABC123'));
    });

    test('given_500_error_when_fetching_status_then_returns_async_error', () async {
      /*
      Test Doc:
      - Why: Error handling contract - provider exposes SkyEchoError without wrapping
      - Contract: deviceStatusProvider returns AsyncValue.error(SkyEchoHttpError) on HTTP errors
      - Usage Notes: MockClient returns non-200; verify AsyncValue.error contains SkyEchoError
      - Quality Contribution: Documents error propagation pattern; UI handles SkyEchoError directly
      - Worked Example: MockClient returns 500 → AsyncValue.error(SkyEchoHttpError("HTTP 500"))
      */

      // Arrange
      final mockHttpClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final container = ProviderContainer(
        overrides: [
          skyEchoClientProvider.overrideWithValue(
            SkyEchoClient('http://test', httpClient: mockHttpClient),
          ),
        ],
      );

      // Act & Assert
      await expectLater(
        () => container.read(deviceStatusProvider.future),
        throwsA(isA<SkyEchoHttpError>()),
      );
    });
  });
}
```

### Acceptance Criteria

- [ ] All tasks passing (10/10 tasks - includes 2.0 test-first task)
- [ ] Riverpod providers file created: `lib/providers/device_providers.dart`
- [ ] 4-6 unit tests promoted with complete Test Doc blocks
- [ ] Test coverage >90% on provider functions
- [ ] Integration test runs against real device (or skips gracefully)
- [ ] UI can handle SkyEchoError directly via AsyncValue.error pattern
- [ ] `dart analyze` clean
- [ ] Commands to run:
  ```bash
  cd apps/tactical_radar
  flutter test test/unit/providers/device_providers_test.dart
  flutter test test/integration/ --dart-define=DEVICE_URL=http://192.168.4.1
  dart analyze
  ```

---

**Note on Incomplete Phases**: Phases 3-12 are intentionally summarized. Full implementation plans for these phases will be generated using `/plan-5-phase-tasks-and-brief` when Phase 2 is complete. This iterative approach allows architecture refinement based on learnings from earlier phases.

**Phase 3-12 Summary** (to be expanded):
- Phase 3: GDL90 Stream State Management (Riverpod providers for stream lifecycle)
- Phase 4: Config View UI (device settings, connection management)
- Phase 5: Radar Coordinate System & Transforms (equirectangular projection, range rings)
- Phase 6: Radar CustomPainter (traffic rendering, batched updates)
- Phase 7: Radar View UI (zoom controls, traffic display)
- Phase 8: Navigation (bottom nav bar, view state coordination)
- Phase 9: Lifecycle Management (flutter_fgbg integration, stream suspend/resume)
- Phase 10: State Persistence (shared_preferences, device URL, zoom level)
- Phase 11: Error Handling UI (toast/banner for errors, retry logic)
- Phase 12: iOS Deployment (Info.plist, permissions, TestFlight testing)

---

## Cross-Cutting Concerns

### Error Logging Strategy
**Priority**: HIGH

**Approach**: Use `logger` package for structured logging across all layers.

**Severity Levels**:
- **ERROR**: Unhandled exceptions, critical failures (device unreachable, stream crashes)
- **WARNING**: Handled errors, GDL90 parse failures, missing data
- **INFO**: State transitions (stream started/stopped, view navigation)
- **DEBUG**: Provider state changes, network requests (development only)

**Implementation**:
```dart
// lib/utils/logger.dart
import 'package:logger/logger.dart';

final appLogger = Logger(
  printer: PrettyPrinter(methodCount: 0, colors: true),
  level: Level.debug, // Change to Level.info for production
);

// Usage in providers
appLogger.i('DeviceStatusProvider: Fetching status from ${client.baseUrl}');
appLogger.e('GDL90 stream error', error: e, stackTrace: stackTrace);
```

**Constraints**:
- Packages (skyecho, skyecho_gdl90) do NOT log - they return errors as data
- App layer logs package errors with context
- No PII (personally identifiable information) in logs
- Production builds use Level.info or Level.warning

---

### Performance Monitoring
**Priority**: MEDIUM

**Metrics to Track**:
- GDL90 message processing rate (msg/sec)
- UI frame rate (target: 60fps)
- Radar repaint frequency (target: 10fps with batching)
- Memory usage (watch for leaks in long-running streams)

**Implementation** (development only):
```dart
// Use PerformanceOverlay widget in debug builds
MaterialApp(
  showPerformanceOverlay: kDebugMode,
  home: MainScaffold(),
);

// Track message rate
var messageCount = 0;
Timer.periodic(Duration(seconds: 1), (_) {
  appLogger.d('GDL90 message rate: $messageCount msg/sec');
  messageCount = 0;
});
```

**Tools**:
- Flutter DevTools (timeline, memory profiler)
- CustomPaint repaint rainbow (visualize unnecessary repaints)
- `flutter run --profile` for realistic performance testing

---

### Security Considerations
**Priority**: HIGH

**Network Security**:
- HTTP-only connection to 192.168.4.1 (local network, no HTTPS available)
- No credentials required (device has no authentication)
- WiFi network is device-created (SkyEcho_XXXX SSID)

**Data Privacy**:
- No user data collected or transmitted
- No analytics, no crash reporting (Phase 1)
- ADS-B traffic data is public broadcast information (not private)

**Input Validation**:
- Device URL must match `http://192.168.x.x` pattern (reject external URLs)
- ICAO hex codes validated (6-character hex)
- GDL90 messages validated by parser (CRC checks)

**Risks**:
- Man-in-the-middle: Low (local WiFi network only)
- Code injection: None (no dynamic code execution)
- Data exfiltration: None (no network egress except to device)

---

### Accessibility (Future)
**Priority**: LOW (defer to Phase 12+)

**Minimum Requirements** (not implemented in Phase 1-11):
- VoiceOver support for Config view (settings navigation)
- Semantic labels for radar display (traffic count, ownship status)
- Sufficient color contrast (4.5:1 minimum)

**Radar View Challenges**:
- Visual radar display inherently difficult for screen readers
- Consider audio alerts for nearby traffic in future phases

---

### Code Quality & Standards
**Priority**: HIGH

**Enforced via**:
- `analysis_options.yaml` (inherited from skyecho package)
- `dart analyze` must pass with zero warnings/errors
- `dart format` enforced in pre-commit hook (future)
- Code reviews check TAD compliance (Test Doc blocks present)

**Standards**:
- All public APIs have dartdoc comments (`///`)
- No `// ignore` comments without justification
- Prefer composition over inheritance
- Use const constructors where possible

---

## Change Footnotes Ledger

[^1]: [To be added during implementation via plan-6a]
[^2]: [To be added during implementation via plan-6a]

---

## Subtasks Registry

Mid-implementation detours requiring structured tracking.

| ID | Created | Phase | Parent Task | Reason | Status | Dossier |
|----|---------|-------|-------------|--------|--------|---------|
| 001-subtask-poc-config-screen-ios26-workaround | 2025-10-30 | Phase 1: Project Setup & Architecture Foundation | T1.2, T1.6, T1.9 | iOS 26 compatibility issues required POC config screen and deployment workaround investigation | [x] Complete | [Link](tasks/phase-1-project-setup-architecture-foundation/001-subtask-poc-config-screen-ios26-workaround.md) |

---

**Next Steps**: Run `/plan-4-complete-the-plan` to validate plan readiness before proceeding to task generation.
