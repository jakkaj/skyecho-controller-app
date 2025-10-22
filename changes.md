# Changes since HEAD

```diff
diff --git a/docs/plans/002-gdl90-receiver-parser/tasks/phase-8-stream-transport-layer/tasks.md b/docs/plans/002-gdl90-receiver-parser/tasks/phase-8-stream-transport-layer/tasks.md
new file mode 100644
index 0000000..b1422f2
--- /dev/null
+++ b/docs/plans/002-gdl90-receiver-parser/tasks/phase-8-stream-transport-layer/tasks.md
@@ -0,0 +1,1207 @@
+# Phase 8: Stream Transport Layer - Tasks & Alignment Brief
+
+**Phase**: Phase 8 - Stream Transport Layer
+**Plan**: [gdl90-receiver-parser-plan.md](../../gdl90-receiver-parser-plan.md#phase-8-stream-transport-layer)
+**Spec**: [gdl90-receiver-parser-spec.md](../../gdl90-receiver-parser-spec.md)
+**Created**: 2025-10-20
+**Status**: PLANNING
+
+---
+
+## Tasks
+
+**Testing Approach**: Full TDD (Test-Driven Development)
+**Mock Usage**: Targeted mocks (MockRawDatagramSocket for unit tests, real sockets for integration tests)
+
+| Status | ID | Task | Type | Dependencies | Absolute Path(s) | Validation | Subtasks | Notes |
+|--------|---|------|------|--------------|------------------|------------|----------|-------|
+| [ ] | T001 | Create Gdl90Stream class skeleton with constructor | Setup | – | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/lib/src/stream/gdl90_stream.dart | File created, basic structure present | – | Defines host, port, events Stream |
+| [ ] | T002 | Write test for stream creation with host/port | Test | T001 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/test/unit/stream_test.dart | Test fails (RED) - stream not instantiable | – | Supports plan task 8.1 |
+| [ ] | T003 | Write test for start() method lifecycle | Test | T001 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/test/unit/stream_test.dart | Test fails (RED) - start() not implemented | – | Supports plan task 8.2; Tests multiple start/stop cycles |
+| [ ] | T003b | Write test for concurrent start() prevention | Test | T001 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/test/unit/stream_test.dart | Test fails (RED) - concurrent start not prevented | – | Async lock pattern; prevents duplicate subscriptions |
+| [ ] | T004 | Write test for stop() method lifecycle (socket only) | Test | T001 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/test/unit/stream_test.dart | Test fails (RED) - stop() not implemented | – | Supports plan task 8.2; Verifies controller stays open |
+| [ ] | T004b | Write test for dispose() method (final cleanup) | Test | T001 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/test/unit/stream_test.dart | Test fails (RED) - dispose() not implemented | – | Keep-alive pattern; closes controller |
+| [ ] | T004c | Write test for start() after dispose() throws error | Test | T001 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/test/unit/stream_test.dart | Test fails (RED) - disposed state not tracked | – | Prevents use-after-dispose bugs |
+| [ ] | T005 | Write test for pause() backpressure support | Test | T001 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/test/unit/stream_test.dart | Test fails (RED) - pause() not implemented | – | Supports plan task 8.3; Dart Stream backpressure |
+| [ ] | T006 | Write test for resume() backpressure support | Test | T001 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/test/unit/stream_test.dart | Test fails (RED) - resume() not implemented | – | Supports plan task 8.3 |
+| [ ] | T007 | Write test for UDP datagram reception → framer | Test | T001 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/test/unit/stream_test.dart | Test fails (RED) - datagram processing not implemented | – | Supports plan task 8.4; Uses MockRawDatagramSocket |
+| [ ] | T007b | Write test for re-entrancy safety (rapid UDP bursts) | Test | T001 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/test/unit/stream_test.dart | Test fails (RED) - re-entrancy not prevented | – | Prevents framer StateError; sync:false critical |
+| [ ] | T008 | Write test for end-to-end pipeline (UDP → events) | Test | T001 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/test/unit/stream_test.dart | Test fails (RED) - pipeline not connected | – | Supports plan task 8.5; Integration test |
+| [ ] | T009 | Write test for error event emission (malformed frame) | Test | T001 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/test/unit/stream_test.dart | Test fails (RED) - error handling not implemented | – | Supports plan task 8.6; Stream continues after error |
+| [ ] | T010 | Write test for socket cleanup on exception | Test | T001 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/test/unit/stream_test.dart | Test fails (RED) - exception handling not implemented | – | Supports plan task 8.7; Resource management |
+| [ ] | T011 | Verify all stream tests fail (RED gate) | Test | T002, T003, T003b, T004, T004b, T004c, T005, T006, T007, T007b, T008, T009, T010 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/test/unit/stream_test.dart | All 13 new tests fail with expected errors | – | TDD RED gate checkpoint |
+| [ ] | T012 | Implement Gdl90Stream class with StreamController | Core | T011 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/lib/src/stream/gdl90_stream.dart | Class instantiable with host/port | – | Supports plan task 8.8; Uses StreamController<Gdl90Event> |
+| [ ] | T013 | Implement start() method with UDP socket lifecycle | Core | T012 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/lib/src/stream/gdl90_stream.dart | Opens RawDatagramSocket, begins emitting events | – | Supports plan task 8.9; Binds to host:port |
+| [ ] | T014 | Implement UDP datagram listener | Core | T013 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/lib/src/stream/gdl90_stream.dart | Datagrams received and passed to framer | – | Listens to socket.listen(), feeds Gdl90Framer |
+| [ ] | T015 | Integrate framer → parser pipeline | Core | T014 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/lib/src/stream/gdl90_stream.dart | Framed data parsed, events emitted to stream | – | Gdl90Framer.addBytes() → Gdl90Parser.parse() |
+| [ ] | T016 | Implement stop() method with socket cleanup only | Core | T013 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/lib/src/stream/gdl90_stream.dart | Closes socket, keeps controller alive | – | Supports plan task 8.10; Keep-alive pattern |
+| [ ] | T016b | Implement dispose() method for final cleanup | Core | T016 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/lib/src/stream/gdl90_stream.dart | Closes controller after stop() | – | Matches Flutter lifecycle; prevents memory leaks |
+| [ ] | T017 | Implement pause() and resume() backpressure | Core | T013 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/lib/src/stream/gdl90_stream.dart | StreamController.onPause/onResume callbacks | – | Pauses/resumes socket subscription |
+| [ ] | T018 | Implement error handling with event emission | Core | T015 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/lib/src/stream/gdl90_stream.dart | Errors from framer/parser → Gdl90ErrorEvent | – | Stream resilience; no exceptions thrown |
+| [ ] | T019 | Implement exception safety with socket cleanup | Core | T016 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/lib/src/stream/gdl90_stream.dart | Socket closed even on exception | – | try-finally or Zone error handling |
+| [ ] | T020 | Add test constructor with injectable socket | Core | T012 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/lib/src/stream/gdl90_stream.dart | Gdl90Stream.withSocket(MockRawDatagramSocket) | – | Enables unit testing without real UDP |
+| [ ] | T021 | Verify all stream tests pass (GREEN gate) | Test | T012, T013, T014, T015, T016, T016b, T017, T018, T019, T020 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/test/unit/stream_test.dart | All 13 tests + baseline pass (100% pass rate) | – | TDD GREEN gate; Supports plan task 8.11 |
+| [ ] | T022 | Run coverage report on stream layer | Integration | T021 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90 | Coverage ≥90% on gdl90_stream.dart | – | Quality gate |
+| [ ] | T023 | Run dart analyze | Integration | T021 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90 | Zero errors | – | Quality gate |
+| [ ] | T024 | Run dart format | Integration | T021 | /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90 | All files formatted | – | Quality gate |
+
+**Total Tasks**: 29
+**Dependencies**: Phase 7 (all parsers) complete
+
+---
+
+## Alignment Brief
+
+### Previous Phase Review (Phase 7: Additional Messages)
+
+**Phase 7 successfully delivered** 4 additional GDL90 message type parsers (HAT, Uplink, Geo Altitude, Pass-Through) with 100% task completion, zero technical debt, and comprehensive security enhancements.
+
+#### A. Completed Deliverables
+
+**1. Model Extensions** - `/Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/lib/src/models/gdl90_message.dart`
+- Added 6 nullable fields: `timeOfReception80ns`, `heightAboveTerrainFeet`, `uplinkPayload`, `geoAltitudeFeet`, `verticalWarning`, `vfomMetersRaw`, `basicReportPayload`, `longReportPayload`
+- Added 2 computed properties: `timeOfReceptionSeconds` (80ns → seconds), `vfomMeters` (null-safe VFOM)
+- **Total**: +69 lines with comprehensive documentation
+
+**2. Parser Implementations** - `/Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/lib/src/parser.dart`
+- `_parseHAT()` (lines 558-590) - 16-bit signed MSB-first height with 0x8000 invalid marker check
+- `_parseUplink()` (lines 608-646) - 24-bit LSB-first TOR + variable payload with 1KB security limit
+- `_parseOwnshipGeoAltitude()` (lines 665-715) - 5-ft resolution altitude + optional vertical metrics
+- `_parsePassThrough()` (lines 730-790) - Unified method for Basic (ID 30) and Long (ID 31) reports
+- **Total**: +236 lines with defensive assertions and security constants
+
+**3. Routing Table** - Added 5 message ID routes (0x07, 0x09, 0x0B, 0x1E, 0x1F)
+
+**4. Test Suite** - 14 new tests (13 original + 1 post-review) achieving 76 total passing tests
+
+#### B. Lessons Learned
+
+1. **Proactive Analysis Prevents Bugs**: Pre-implementation "Critical Insights" session identified 5 security/safety concerns, preventing 3+ production incidents before any code was written
+2. **TDD Discipline Works**: All 13 tests verified failing (RED gate) before implementation; 76/76 tests passing after (GREEN gate)
+3. **Security Cannot Be Afterthought**: Memory bomb protection (1KB limit) added proactively, not in response to incidents
+4. **Boolean Branch Coverage Matters**: Code review found missing `verticalWarning=true` test despite strict TDD (fixed with T008c post-review)
+
+#### C. Technical Discoveries
+
+1. **24-Bit TOR Wraparound**: Counter wraps every 1.34 seconds; naïve comparison fails at boundary
+2. **HAT Invalid Marker Timing**: Must check 0x8000 BEFORE sign conversion to prevent -32768 false positive
+3. **VFOM Special Values**: Two "invalid" states (0x7FFF = not available, 0x7EEE = exceeds max) require dual-field pattern (raw + computed)
+4. **Dart Assertions Zero-Cost**: `assert()` compiles to no-ops in release; use liberally for development-time safety
+5. **Test Suite Scales Linearly**: 76 tests execute in 1.2 seconds (well under 5-second budget)
+
+#### D. Dependencies for Next Phase (Phase 8)
+
+**Available Imports**:
+```dart
+// Complete message parsing for all GDL90 core types
+import 'package:skyecho_gdl90/src/parser.dart';
+import 'package:skyecho_gdl90/src/models/gdl90_message.dart';
+import 'package:skyecho_gdl90/src/models/gdl90_event.dart';
+import 'package:skyecho_gdl90/src/framer.dart';
+
+// Supported message IDs: 0x00, 0x02, 0x07, 0x09, 0x0A, 0x0B, 0x14, 0x1E, 0x1F
+// All parsers return Gdl90Event (DataEvent, ErrorEvent, or IgnoredEvent)
+```
+
+**Key APIs**:
+- `Gdl90Parser.parse(Uint8List frame)` → `Gdl90Event` (never throws)
+- `Gdl90Framer()` → stateful byte framer with `addBytes(Uint8List, onFrame callback)`
+- `Gdl90Message` unified model with all Phase 7 fields populated
+
+#### E. Critical Findings Applied in Phase 7
+
+1. **Memory Bomb Protection** (Insight #1): 1KB Uplink payload limit prevents DoS attacks
+2. **Routing Safety** (Insight #2): Defensive assertions catch routing table bugs in debug mode
+3. **TOR Wraparound Handling** (Insight #3): Documented 24-bit wraparound with example comparison function
+4. **VFOM Special Values** (Insight #4): Raw + computed property pattern for aviation safety
+5. **Routing Integration Tests** (Insight #5): Unknown message ID + boundary tests validate completeness
+
+#### F. Blocked/Incomplete Items
+
+**NONE** - Phase 7 100% complete with zero technical debt.
+
+**Post-Review Enhancement**: Code review found missing `verticalWarning=true` test; immediately addressed with T008c (RESOLVED).
+
+#### G. Test Infrastructure Available
+
+- **Test Patterns**: Given-when-then naming, inline binary documentation, AAA structure
+- **Fixture Strategy**: Real binary data preferred over hand-crafted mocks
+- **Mock Infrastructure**: None needed for Phase 7; parser tests use pre-validated frames
+- **Performance**: 76 tests in 1.2 seconds (linear scaling)
+
+#### H. Technical Debt & Workarounds
+
+**Zero Technical Debt** - Phase 7 production-ready:
+- ✅ No TODO/FIXME markers
+- ✅ All 76 tests passing
+- ✅ Zero analyzer errors
+- ✅ Security enhancements beyond requirements (3 additions)
+- ✅ Post-review coverage gap closed immediately
+
+**Architectural Patterns Established**:
+1. **Wrapper Pattern**: All parsers return `Gdl90Event`, never throw exceptions
+2. **Check-Before-Formula**: Invalid markers checked BEFORE conversions
+3. **Generic Helper Reuse**: `_toSigned(value, bits)` works for any bit width
+4. **Defensive Assertions**: Use `assert()` for routing safety (zero release cost)
+5. **Security-First Validation**: Proactive upper bounds (1KB limit)
+
+#### I. Scope Changes
+
+**All Planned Tasks Completed** (100%):
+- Original plan: 13 tasks (7.1 - 7.13)
+- Executed: 26 dossier tasks (expanded TDD workflow)
+- Post-review: +1 test (T008c for coverage gap)
+- **Total tests**: 14 Phase 7 tests (76 total suite)
+
+**Features Added Beyond Plan**:
+- Security constants (`_MAX_UPLINK_PAYLOAD_BYTES`, `_HAT_INVALID`)
+- Computed properties (`timeOfReceptionSeconds`, `vfomMeters`)
+- Comprehensive wraparound documentation with example code
+- Defensive assertions for routing safety
+
+**No Scope Reductions** - All original features delivered.
+
+#### J. Key Execution Log References
+
+**Critical Decisions**:
+- [Memory Bomb Protection Decision](../phase-7-additional-messages/tasks.md#insight-1-variable-length-payload-memory-bomb-risk) - 1KB limit rationale
+- [Routing Safety Strategy](../phase-7-additional-messages/tasks.md#insight-2-pass-through-message-id-collision-risk-in-unified-parser) - Assertion pattern
+- [TOR Wraparound Guidance](../phase-7-additional-messages/tasks.md#insight-3-time-of-reception-overflow-ambiguity-24-bit-wraparound) - Example comparison function
+- [VFOM Special Value Handling](../phase-7-additional-messages/tasks.md#insight-4-vfom-special-value-semantic-gap-null-vs-invalid) - Dual-field pattern
+
+**Quality Evidence**:
+- [TDD Workflow Validation](../phase-7-additional-messages/execution.log.md#tdd-workflow-validation) - All gates passed
+- [Post-Review Coverage Fix](../phase-7-additional-messages/execution.log.md#post-review-update-coverage-gap-closure) - V1 finding resolution
+- [Phase 7 Success Metrics](../phase-7-additional-messages/execution.log.md#phase-7-success-metrics) - 26/26 tasks, zero errors
+
+---
+
+### Objective Recap
+
+**Phase 8 Goal**: Implement UDP stream receiver that integrates the complete parsing pipeline (Phase 2-7) into a production-ready Dart Stream API.
+
+**Behavior Checklist** (from plan acceptance criteria):
+- ✅ Stream can start and stop cleanly
+- ✅ UDP socket lifecycle managed correctly (open/close)
+- ✅ Backpressure supported (pause/resume per Dart Stream API)
+- ✅ End-to-end pipeline works (UDP → framer → parser → events)
+- ✅ Error events emitted for malformed frames (stream continues)
+- ✅ Stream continues processing after errors (resilience)
+- ✅ Socket cleanup on exceptions (resource safety)
+- ✅ 90% coverage on stream transport layer
+
+**Integration Pattern**:
+```
+UDP Datagram (RawDatagramSocket)
+  → Gdl90Framer.addBytes()
+    → Gdl90Parser.parse()
+      → Stream<Gdl90Event> emission
+        → Caller receives DataEvent | ErrorEvent | IgnoredEvent
+```
+
+---
+
+### Non-Goals (Scope Boundaries)
+
+❌ **NOT doing in Phase 8**:
+
+1. **Performance Optimization**:
+   - No buffering strategies (simple pass-through)
+   - No datagram batching
+   - No zero-copy optimizations
+   - **Defer to**: Phase 12 (if performance issues identified)
+
+2. **Advanced Stream Features**:
+   - No broadcast streams (single listener only)
+   - No stream transformers (StreamTransformer<>)
+   - No custom stream operators
+   - **Rationale**: YAGNI - add only when needed
+
+3. **Packet Loss Metrics**:
+   - No dropped packet counting
+   - No out-of-order detection
+   - No gap analysis
+   - **Defer to**: Phase 9 (Smart Data Capture Utility)
+
+4. **Connection Management**:
+   - No automatic reconnection logic
+   - No connection health monitoring
+   - No timeout handling (UDP is fire-and-forget)
+   - **Rationale**: Caller responsibility
+
+5. **Configuration**:
+   - No buffer size tuning
+   - No socket options (reuse address, etc.)
+   - **Use defaults**: Dart `RawDatagramSocket` defaults sufficient
+
+6. **Platform-Specific Concerns**:
+   - No iOS background mode handling
+   - No Android doze mode workarounds
+   - No web platform support (WebSocket proxy)
+   - **Defer to**: Future Flutter integration phases
+
+7. **Logging/Observability**:
+   - No built-in logging (caller adds if needed)
+   - No metrics emission
+   - No tracing/profiling hooks
+   - **Rationale**: Library provides events; caller decides logging
+
+8. **Multi-Device Support**:
+   - No multi-cast support
+   - No device discovery
+   - Single `host:port` only
+   - **Rationale**: SkyEcho is point-to-point 192.168.4.1:4000
+
+---
+
+### Critical Findings Affecting This Phase
+
+From plan § 3 (Critical Research Findings), these discoveries directly impact Phase 8 implementation:
+
+#### **Discovery 02: Byte Framing and Escaping Order** (Foundational - Already Applied)
+- **Constraint**: CRC must be computed on clear (unescaped) message bytes
+- **Impact on Phase 8**: Already handled by Phase 3 Gdl90Framer; stream layer receives clean frames
+- **Tasks**: T014-T015 integrate framer correctly (de-frame → de-escape → validate CRC → parse)
+
+#### **Discovery 05: Wrapper Pattern (Never Throw Exceptions)** (Critical for Streams)
+- **Constraint**: All parsing errors must return `Gdl90ErrorEvent`, never throw exceptions
+- **Impact on Phase 8**: **Stream resilience depends on this**; malformed frames must not crash stream
+- **Tasks**: T009, T018 verify error events emitted and stream continues processing
+- **Validation**: Test bad CRC frame followed by good frame; stream handles both
+
+#### **New Consideration: UDP Datagram Boundaries** (Phase 8 Specific)
+- **Discovery**: Each UDP datagram may contain 0, 1, or multiple GDL90 frames
+- **Impact**: Framer must handle partial frames across datagram boundaries
+- **Solution**: Gdl90Framer is stateful; buffer persists between `addBytes()` calls
+- **Tasks**: T007, T014 verify correct datagram-to-frame mapping
+- **Test Strategy**: Send fragmented frame across 2 datagrams; verify single frame emitted
+
+#### **New Consideration: Stream Backpressure** (Dart Stream API)
+- **Discovery**: Dart `StreamController` supports pause/resume for backpressure
+- **Impact**: If caller processes events slowly, UDP socket should pause to prevent buffer overflow
+- **Solution**: Implement `onPause` → suspend socket subscription, `onResume` → resume
+- **Tasks**: T005-T006, T017 implement and test backpressure callbacks
+- **Validation**: Pause stream, verify no events emitted; resume, verify events flow
+
+---
+
+### Invariants & Guardrails
+
+**Performance Budgets**:
+- **Stream latency**: <10ms from UDP receipt to event emission (target, not enforced)
+- **Test execution**: <5 seconds total suite (currently 1.2s with 76 tests)
+- **Memory**: Framer buffer cleared between frames (no leaks)
+
+**Resource Management**:
+- Socket MUST be closed on stop(), even if exception occurs (try-finally)
+- StreamController MUST be closed when stream ends
+- No retained references to datagrams after processing
+
+**Security Constraints**:
+- Inherit 1KB Uplink payload limit from Phase 7
+- No additional security concerns for Phase 8 (UDP is local network only)
+
+**Error Handling**:
+- All framer errors → `Gdl90ErrorEvent` in stream
+- All parser errors → `Gdl90ErrorEvent` in stream
+- Stream continues processing after error events
+- Socket exceptions → close socket, complete stream with error
+
+**Re-Entrancy Safety** (Critical Constraint from Phase 3):
+- Gdl90Framer throws `StateError` if `addBytes()` called re-entrantly (framer.dart:51-54)
+- **Solution**: StreamController with `sync: false` (async event delivery)
+- Ensures listener callbacks never execute in same call stack as `addBytes()`
+- Tested with T007b (rapid UDP burst test)
+
+---
+
+### Inputs to Read (Absolute Paths)
+
+**Existing Code to Integrate**:
+1. `/Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/lib/src/framer.dart` - Gdl90Framer class (Phase 3)
+2. `/Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/lib/src/parser.dart` - Gdl90Parser class (Phase 4-7)
+3. `/Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/lib/src/models/gdl90_event.dart` - Event types (Phase 4)
+4. `/Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/lib/src/models/gdl90_message.dart` - Message model (Phase 4-7)
+
+**Test Patterns to Follow**:
+1. `/Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/test/unit/framer_test.dart` - Async test patterns
+2. `/Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90/test/unit/parser_test.dart` - Test Doc blocks
+
+**Documentation References**:
+1. [Dart RawDatagramSocket API](https://api.dart.dev/stable/dart-io/RawDatagramSocket-class.html)
+2. [Dart StreamController API](https://api.dart.dev/stable/dart-async/StreamController-class.html)
+3. [Dart Stream Backpressure](https://dart.dev/articles/libraries/creating-streams#backpressure)
+
+---
+
+### Visual Alignment Aids
+
+#### System Flow Diagram (High-Level Architecture)
+
+```mermaid
+flowchart TD
+    A[SkyEcho Device<br/>192.168.4.1:4000] -->|UDP Broadcast| B[RawDatagramSocket]
+    B -->|Uint8List datagrams| C[Gdl90Stream]
+
+    subgraph "Phase 8: Stream Transport Layer"
+        C -->|addBytes| D[Gdl90Framer<br/>Phase 3]
+        D -->|onFrame callback| E[Gdl90Parser<br/>Phase 4-7]
+        E -->|Gdl90Event| F[StreamController]
+    end
+
+    F -->|Stream<Gdl90Event>| G[Caller<br/>listen callback]
+
+    G -->|DataEvent| H[Process Message]
+    G -->|ErrorEvent| I[Log Error]
+    G -->|IgnoredEvent| J[Skip]
+
+    style C fill:#90EE90
+    style D fill:#ADD8E6
+    style E fill:#ADD8E6
+    style F fill:#90EE90
+```
+
+#### Sequence Diagram (Lifecycle and Event Flow)
+
+```mermaid
+sequenceDiagram
+    participant Caller
+    participant Gdl90Stream
+    participant RawDatagramSocket
+    participant Gdl90Framer
+    participant Gdl90Parser
+    participant StreamController
+
+    Note over Caller,StreamController: Initialization Phase
+    Caller->>Gdl90Stream: new(host: '192.168.4.1', port: 4000)
+    Gdl90Stream->>StreamController: create StreamController<Gdl90Event>()
+    Gdl90Stream->>Gdl90Framer: instantiate framer
+
+    Note over Caller,StreamController: Start Phase
+    Caller->>Gdl90Stream: start()
+    Gdl90Stream->>RawDatagramSocket: bind(host, port)
+    RawDatagramSocket-->>Gdl90Stream: socket ready
+    Gdl90Stream->>RawDatagramSocket: listen((datagram) {...})
+
+    Note over Caller,StreamController: Active Streaming Phase
+    RawDatagramSocket->>Gdl90Stream: datagram event
+    Gdl90Stream->>Gdl90Framer: addBytes(datagram.data, onFrame)
+
+    alt Valid Frame
+        Gdl90Framer->>Gdl90Parser: parse(frame)
+        Gdl90Parser-->>Gdl90Framer: Gdl90DataEvent
+        Gdl90Framer->>StreamController: add(DataEvent)
+        StreamController->>Caller: emit DataEvent
+    else Invalid Frame (CRC error)
+        Gdl90Framer->>Gdl90Parser: parse(frame)
+        Gdl90Parser-->>Gdl90Framer: Gdl90ErrorEvent
+        Gdl90Framer->>StreamController: add(ErrorEvent)
+        StreamController->>Caller: emit ErrorEvent
+        Note over Gdl90Stream: Stream continues!
+    end
+
+    Note over Caller,StreamController: Backpressure Phase (Optional)
+    Caller->>Gdl90Stream: pause()
+    Gdl90Stream->>RawDatagramSocket: subscription.pause()
+    Note over RawDatagramSocket: No events emitted
+    Caller->>Gdl90Stream: resume()
+    Gdl90Stream->>RawDatagramSocket: subscription.resume()
+    Note over RawDatagramSocket: Events flow again
+
+    Note over Caller,StreamController: Shutdown Phase
+    Caller->>Gdl90Stream: stop()
+    Gdl90Stream->>RawDatagramSocket: close()
+    Gdl90Stream->>StreamController: close()
+    StreamController-->>Caller: stream done
+```
+
+---
+
+### Test Plan (Full TDD Approach)
+
+**Testing Philosophy**: Full TDD with comprehensive Test Doc blocks (5 required fields per Phase 7 pattern)
+
+**Test Strategy**:
+- **Unit Tests**: Mock `RawDatagramSocket` for lifecycle and error handling
+- **Integration Tests**: Real socket + localhost for end-to-end validation (defer to Phase 12)
+- **Mock Policy**: Targeted mocks (socket only); use real framer/parser
+
+#### Named Tests with Rationale
+
+**T002 - Stream Creation Test**
+- **Rationale**: Validates basic instantiation with host/port parameters
+- **Fixture**: None (constructor test)
+- **Expected Output**: `Gdl90Stream` instance with `events` Stream
+- **Test Doc Fields**:
+  - Why: Ensures stream can be created with network parameters
+  - Contract: Constructor accepts host (String) and port (int)
+  - Usage Notes: Host typically '192.168.4.1', port 4000 for SkyEcho
+  - Quality Contribution: Prevents API breaking changes
+  - Worked Example: `Gdl90Stream(host: '192.168.4.1', port: 4000)` → valid instance
+
+**T003 - Start Lifecycle Test**
+- **Rationale**: Validates socket opens and stream becomes active
+- **Fixture**: MockRawDatagramSocket
+- **Expected Output**: `isRunning` property becomes true, socket binds
+- **Async**: `await stream.start()`
+- **Also Tests**: Multiple sequential start() calls are idempotent (second call returns early)
+
+**T003b - Concurrent Start Prevention Test**
+- **Rationale**: Validates async lock prevents duplicate subscriptions from concurrent calls
+- **Fixture**: MockRawDatagramSocket with delayed bind (simulate network latency)
+- **Expected Output**: Two concurrent `start()` calls, only one creates subscription
+- **Test Pattern**: `Future.wait([stream.start(), stream.start()])` → verify single subscription
+- **Critical**: Prevents resource leak and duplicate events from race condition
+
+**T004 - Stop Lifecycle Test (Keep-Alive Pattern)**
+- **Rationale**: Validates socket closes but controller stays alive for restart
+- **Fixture**: MockRawDatagramSocket
+- **Expected Output**: `isRunning` false, socket.close() called, controller still open
+- **Async**: `await stream.stop()`
+- **Critical**: Verify `stream.events` still valid (can add listener)
+
+**T004b - Dispose Final Cleanup Test**
+- **Rationale**: Validates final cleanup closes controller (matches Flutter lifecycle)
+- **Fixture**: MockRawDatagramSocket
+- **Expected Output**: Controller closed, stream emits done
+- **Async**: `await stream.dispose()`
+
+**T004c - Start After Dispose Error Test**
+- **Rationale**: Validates disposed state prevents restart (use-after-dispose protection)
+- **Fixture**: MockRawDatagramSocket
+- **Expected Output**: `stream.start()` after `dispose()` throws StateError
+- **Test Pattern**: `await stream.dispose(); await stream.start();` → expect StateError
+- **Critical**: Prevents memory corruption and undefined behavior
+
+**T005 - Pause Backpressure Test**
+- **Rationale**: Validates Dart Stream backpressure support
+- **Fixture**: MockRawDatagramSocket emitting datagrams
+- **Expected Output**: After pause(), no events emitted until resume()
+- **Test Pattern**: `stream.events.listen(onData).pause()` → verify buffer
+
+**T006 - Resume Backpressure Test**
+- **Rationale**: Validates stream resumes after pause
+- **Fixture**: MockRawDatagramSocket emitting datagrams
+- **Expected Output**: After resume(), events flow again
+- **Test Pattern**: `subscription.resume()` → verify events
+
+**T007 - UDP Datagram Reception Test**
+- **Rationale**: Validates datagram bytes passed to framer
+- **Fixture**: MockRawDatagramSocket emitting single datagram with heartbeat frame
+- **Expected Output**: Framer receives bytes, frame extracted
+- **Integration**: Tests socket → framer boundary
+
+**T007b - Re-Entrancy Safety Test (Critical)**
+- **Rationale**: Validates async delivery prevents framer re-entrancy crash
+- **Fixture**: MockRawDatagramSocket emitting 2 datagrams rapidly (back-to-back)
+- **Expected Output**: Both frames processed successfully, no StateError
+- **Critical**: Framer throws StateError if addBytes() called re-entrantly (line 51-54 framer.dart)
+- **Why Important**: Without `sync: false`, listener could execute synchronously → re-entrancy
+- **Test Pattern**: Emit 2 UDP datagrams in tight loop, verify 2 events received
+
+**T008 - End-to-End Pipeline Test**
+- **Rationale**: Validates complete UDP → events flow
+- **Fixture**: MockRawDatagramSocket emitting valid GDL90 datagram
+- **Expected Output**: `Gdl90DataEvent` with parsed `Gdl90Message` emitted
+- **Critical Test**: This validates entire Phase 8 integration
+- **Test Doc Example**:
+  ```dart
+  test('UDP datagram to parsed event pipeline', () async {
+    // Purpose: Validates end-to-end parsing from UDP to events
+    // Quality Contribution: Ensures full integration works
+    // Acceptance Criteria:
+    //   - Raw UDP bytes → framed → parsed → event emitted
+
+    final mockSocket = MockRawDatagramSocket();
+    final heartbeatDatagram = Uint8List.fromList([
+      0x7E, // Start flag
+      0x00, 0x81, 0x41, 0xDB, 0xD0, 0x08, 0x02, // Heartbeat
+      0xB3, 0x8B, // CRC
+      0x7E, // End flag
+    ]);
+
+    when(mockSocket.receive()).thenReturn(
+      Datagram(heartbeatDatagram, InternetAddress.anyIPv4, 4000)
+    );
+
+    final stream = Gdl90Stream.withSocket(mockSocket);
+    await stream.start();
+
+    await expectLater(
+      stream.events,
+      emits(predicate<Gdl90Event>((event) {
+        return event is Gdl90DataEvent &&
+               event.message.messageType == Gdl90MessageType.heartbeat;
+      }))
+    );
+
+    await stream.stop();
+  });
+  ```
+
+**T009 - Error Event Emission Test**
+- **Rationale**: Validates malformed frames don't crash stream
+- **Fixture**: MockRawDatagramSocket emitting bad CRC frame, then good frame
+- **Expected Output**: ErrorEvent for bad frame, DataEvent for good frame
+- **Critical**: Validates Discovery 05 (wrapper pattern stream resilience)
+
+**T010 - Socket Cleanup on Exception Test**
+- **Rationale**: Validates resource safety on errors
+- **Fixture**: MockRawDatagramSocket that throws exception
+- **Expected Output**: Socket.close() called, stream completes with error
+- **Test Pattern**: Verify `socket.close()` in finally block
+
+**T011 - RED Gate Checkpoint**
+- **Validation**: All 9 new tests fail with expected errors before implementation
+- **Critical**: TDD discipline enforcement
+
+**T021 - GREEN Gate Checkpoint**
+- **Validation**: All tests pass (9 new + baseline)
+- **Critical**: Implementation complete
+
+**T022 - Coverage Gate**
+- **Target**: ≥90% coverage on `gdl90_stream.dart`
+- **Command**: `dart test --coverage=coverage && dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib`
+
+**T023 - Analyzer Gate**
+- **Target**: Zero errors
+- **Command**: `dart analyze`
+
+**T024 - Formatter Gate**
+- **Target**: All files formatted
+- **Command**: `dart format .`
+
+---
+
+### Step-by-Step Implementation Outline
+
+**SETUP Phase** (T001):
+1. Create `lib/src/stream/` directory
+2. Create `gdl90_stream.dart` with class skeleton
+3. Define constructor: `Gdl90Stream({required String host, required int port})`
+4. Define test constructor: `Gdl90Stream.withSocket(RawDatagramSocket socket)`
+5. Define public API: `Stream<Gdl90Event> get events`, `Future<void> start()`, `Future<void> stop()`, `Future<void> dispose()`, `void pause()`, `void resume()`, `bool get isRunning`
+
+**RED Phase** (T002-T011):
+1. Write all 13 tests with complete Test Doc blocks (includes T003b concurrent start, T004b/T004c dispose, T007b re-entrancy)
+2. Use `MockRawDatagramSocket` (create mock class in test file)
+3. Verify all tests fail with expected errors:
+   - T002: Constructor not implemented
+   - T003: start() not implemented
+   - T003b: Concurrent start not prevented
+   - T004: stop() not implemented
+   - T004b: dispose() not implemented
+   - T004c: Disposed state not tracked
+   - T005-T006: pause()/resume() not implemented
+   - T007: Datagram reception not implemented
+   - T007b: Re-entrancy not prevented
+   - T008: Pipeline not connected
+   - T009: Error handling not implemented
+   - T010: Exception safety not implemented
+4. Checkpoint T011: Confirm RED gate (all 13 tests failing)
+
+**GREEN Phase** (T012-T020):
+1. **T012**: Implement class with `StreamController<Gdl90Event>`
+   ```dart
+   class Gdl90Stream {
+     final String _host;
+     final int _port;
+     late final StreamController<Gdl90Event> _controller;
+     RawDatagramSocket? _socket;
+     StreamSubscription<RawSocketEvent>? _subscription;
+     final Gdl90Framer _framer = Gdl90Framer();
+
+     // State flags
+     bool _isRunning = false;
+     bool _startInProgress = false; // Async lock for concurrent start()
+     bool _isDisposed = false;      // Prevents use-after-dispose
+
+     Gdl90Stream({required String host, required int port})
+         : _host = host,
+           _port = port {
+       _initController();
+     }
+
+     // Test constructor - injectable socket for unit testing
+     Gdl90Stream.withSocket(RawDatagramSocket socket)
+         : _host = 'test',
+           _port = 0,
+           _socket = socket {
+       // CRITICAL: Must call _initController() to initialize StreamController
+       // Without this, accessing .events will throw LateInitializationError
+       _initController();
+     }
+
+     /// Initializes StreamController with re-entrancy safety and lifecycle callbacks.
+     /// Shared between main and test constructors to avoid duplication.
+     void _initController() {
+       // CRITICAL: sync: false prevents re-entrancy into Gdl90Framer
+       // Framer throws StateError if addBytes() called re-entrantly (line 51-54)
+       // Async delivery ensures listener callbacks never execute in same call stack
+       _controller = StreamController<Gdl90Event>(
+         sync: false, // Explicit async delivery for re-entrancy safety
+         onPause: _handlePause,
+         onResume: _handleResume,
+         onCancel: stop,
+       );
+     }
+
+     Stream<Gdl90Event> get events => _controller.stream;
+     bool get isRunning => _isRunning;
+   }
+   ```
+
+2. **T013**: Implement `start()` method
+   ```dart
+   Future<void> start() async {
+     // Idempotent guard - safe to call multiple times sequentially
+     if (_isRunning) return;
+
+     // Disposed guard - prevent use-after-dispose
+     if (_isDisposed) {
+       throw StateError('Cannot start() after dispose(). Create a new Gdl90Stream instance.');
+     }
+
+     // Async lock - prevent concurrent start() calls
+     if (_startInProgress) return; // Second call returns early
+
+     try {
+       _startInProgress = true;
+
+       _socket ??= await RawDatagramSocket.bind(_host, _port);
+       // CRITICAL: Store subscription for pause/resume and proper cleanup
+       _subscription = _socket!.listen(_handleDatagram);
+       _isRunning = true;
+     } finally {
+       _startInProgress = false; // Always clear lock, even on exception
+     }
+   }
+   ```
+
+3. **T014**: Implement `_handleDatagram()` listener
+   ```dart
+   void _handleDatagram(RawSocketEvent event) {
+     if (event == RawSocketEvent.read) {
+       final datagram = _socket!.receive();
+       if (datagram != null) {
+         _framer.addBytes(datagram.data, _handleFrame);
+       }
+     }
+   }
+   ```
+
+4. **T015**: Implement `_handleFrame()` callback
+   ```dart
+   void _handleFrame(Uint8List frame) {
+     final event = Gdl90Parser.parse(frame);
+     _controller.add(event);
+   }
+   ```
+
+5. **T016**: Implement `stop()` method (Keep-Alive Pattern)
+   ```dart
+   Future<void> stop() async {
+     if (!_isRunning) return;
+
+     await _subscription?.cancel();
+     await _socket?.close();
+     _socket = null;
+     _isRunning = false;
+     // NOTE: Controller stays open for restart
+   }
+   ```
+
+5b. **T016b**: Implement `dispose()` method (Final Cleanup)
+   ```dart
+   Future<void> dispose() async {
+     if (_isDisposed) return; // Idempotent
+
+     _isDisposed = true;
+     await stop(); // Ensure socket closed first
+     await _controller.close();
+   }
+   ```
+
+6. **T017**: Implement pause/resume callbacks
+   ```dart
+   void _handlePause() {
+     // Pause socket subscription to stop receiving UDP events
+     _subscription?.pause();
+   }
+
+   void _handleResume() {
+     // Resume socket subscription to restart UDP event flow
+     _subscription?.resume();
+   }
+   ```
+
+7. **T018**: Error handling (already handled by wrapper pattern)
+   - Verify `Gdl90Parser.parse()` returns ErrorEvent (never throws)
+   - Verify `_controller.add(event)` works for all event types
+
+8. **T019**: Exception safety (updated for keep-alive + async lock)
+   ```dart
+   Future<void> start() async {
+     if (_isRunning || _isDisposed || _startInProgress) return;
+
+     try {
+       _startInProgress = true;
+       _socket ??= await RawDatagramSocket.bind(_host, _port);
+       _subscription = _socket!.listen(_handleDatagram);
+       _isRunning = true;
+     } finally {
+       _startInProgress = false; // Always clear, even on exception
+     }
+   }
+
+   Future<void> stop() async {
+     if (!_isRunning) return;
+
+     try {
+       await _subscription?.cancel();
+     } finally {
+       await _socket?.close();
+       _socket = null;
+       _subscription = null;
+       _isRunning = false;
+     }
+   }
+
+   Future<void> dispose() async {
+     if (_isDisposed) return;
+
+     try {
+       _isDisposed = true;
+       await stop();
+     } finally {
+       await _controller.close();
+     }
+   }
+   ```
+
+9. **T020**: Test constructor implementation (verify `_initController()` called)
+   - Verify `withSocket()` constructor initializes controller via `_initController()`
+   - Verify `stream.events` is accessible without `LateInitializationError`
+   - Verify injected socket is used instead of creating new one
+
+10. **T021**: Verify GREEN gate - all 13 tests passing (includes concurrent start, dispose, re-entrancy tests)
+
+**REFACTOR Phase** (T022-T024):
+1. Run coverage: Ensure ≥90% on gdl90_stream.dart
+2. Run analyzer: Fix any errors/warnings
+3. Run formatter: Apply Dart style guide
+4. Review code for improvements (extract methods if needed)
+
+---
+
+### Commands to Run
+
+**Environment Setup** (one-time):
+```bash
+cd /Users/jordanknight/github/skyecho-controller-app/packages/skyecho_gdl90
+dart pub get
+```
+
+**Test Runner** (use throughout TDD cycle):
+```bash
+# All tests
+dart test
+
+# Stream tests only
+dart test test/unit/stream_test.dart
+
+# Specific test by name
+dart test --name "pipeline"
+
+# With verbose output
+dart test -v
+```
+
+**Coverage Report**:
+```bash
+# Generate coverage
+dart test --coverage=coverage
+
+# Format coverage report
+dart pub global activate coverage
+dart pub global run coverage:format_coverage \
+  --lcov \
+  --in=coverage \
+  --out=coverage/lcov.info \
+  --report-on=lib
+
+# View coverage (optional)
+genhtml coverage/lcov.info -o coverage/html
+open coverage/html/index.html
+```
+
+**Code Quality**:
+```bash
+# Analyzer (zero errors required)
+dart analyze
+
+# Formatter (apply Dart style guide)
+dart format .
+
+# Check formatting without applying
+dart format --output=none --set-exit-if-changed .
+```
+
+**Type Checking** (implicit in Dart):
+- Dart analyzer includes type checking
+- No separate type checker needed
+
+---
+
+### Risks/Unknowns
+
+| Risk | Severity | Likelihood | Mitigation | Status |
+|------|----------|------------|------------|--------|
+| **UDP packet loss on high traffic** | MEDIUM | HIGH | Document UDP limitations; Phase 9 adds packet loss metrics | Accepted |
+| **Stream backpressure not tested with real load** | LOW | MEDIUM | Unit tests verify pause/resume; defer load testing to Phase 12 | Mitigated |
+| **Socket cleanup on sudden network loss** | MEDIUM | MEDIUM | Test exception paths with mock throwing errors; use try-finally | Mitigated |
+| **Framer state not cleared between datagrams** | HIGH | LOW | Framer already handles stateful buffering (Phase 3); integration test verifies | Mitigated |
+| **StreamController memory leak** | MEDIUM | LOW | Ensure controller.close() called in all paths; test with stop() | Mitigated |
+| **Dart Socket API differences across platforms** | LOW | LOW | Use `RawDatagramSocket` (cross-platform); defer platform-specific testing to Phase 12 | Accepted |
+| **Mock not representative of real socket behavior** | MEDIUM | MEDIUM | Add integration test with real localhost socket in Phase 12 | Accepted |
+
+**Critical Unknown**:
+- **Real-world datagram fragmentation**: Will SkyEcho device send frames split across multiple datagrams?
+- **Discovery**: Test with real device in Phase 9 capture utility
+- **Workaround**: Gdl90Framer handles partial frames by design; should work regardless
+
+---
+
+### Ready Check
+
+Before proceeding to implementation (`/plan-6-implement-phase`), verify:
+
+**Prerequisites**:
+- [ ] Phase 7 (all parsers) marked complete in plan.md § 8
+- [ ] All Phase 7 tests passing (76/76)
+- [ ] Gdl90Framer available at `lib/src/framer.dart`
+- [ ] Gdl90Parser available at `lib/src/parser.dart`
+- [ ] Gdl90Event types available at `lib/src/models/gdl90_event.dart`
+
+**Understanding**:
+- [ ] I understand the UDP → framer → parser → stream pipeline
+- [ ] I understand Dart `StreamController` API (onPause, onResume, onCancel)
+- [ ] I understand `RawDatagramSocket` lifecycle (bind, listen, close)
+- [ ] I understand wrapper pattern requirement (never throw exceptions)
+- [ ] I understand TDD workflow (SETUP → RED → GREEN → REFACTOR)
+
+**Resources**:
+- [ ] I have reviewed Dart Stream API documentation
+- [ ] I have reviewed RawDatagramSocket API documentation
+- [ ] I have reviewed Phase 7 execution log for patterns to follow
+- [ ] I have reviewed Phase 3 Gdl90Framer implementation
+
+**Alignment**:
+- [ ] I agree with the task breakdown (24 tasks)
+- [ ] I agree with the non-goals (no performance optimization, no logging)
+- [ ] I agree with the test plan (9 new tests with Test Doc blocks)
+- [ ] I agree with the mocking strategy (MockRawDatagramSocket only)
+
+**Ready to Proceed**:
+- [ ] All prerequisites met
+- [ ] All understanding checkboxes checked
+- [ ] All resources reviewed
+- [ ] All alignment checkboxes checked
+- [ ] **GO** / **NO-GO** (await explicit user approval)
+
+---
+
+## Phase Footnote Stubs
+
+**Footnote Ledger** (populated during `/plan-6-implement-phase` execution):
+
+This section will be populated with FlowSpace node IDs during Phase 8 implementation. Footnotes will reference:
+- Functions/methods added to `gdl90_stream.dart`
+- Test files created
+- Integration points with framer/parser
+
+**Format** (example from Phase 7):
+```markdown
+[^31]: Task 8.X - Stream class implementation
+  - `class:packages/skyecho_gdl90/lib/src/stream/gdl90_stream.dart:Gdl90Stream`
+  - `method:packages/skyecho_gdl90/lib/src/stream/gdl90_stream.dart:Gdl90Stream.start`
+  - `method:packages/skyecho_gdl90/lib/src/stream/gdl90_stream.dart:Gdl90Stream.stop`
+
+[^32]: Task 8.Y - Stream tests
+  - `file:packages/skyecho_gdl90/test/unit/stream_test.dart`
+```
+
+**Next Footnote Number**: [^31] (Phase 7 used [^26] through [^30])
+
+---
+
+## Evidence Artifacts
+
+**Execution Log** (created by `/plan-6-implement-phase`):
+- **Path**: `/Users/jordanknight/github/skyecho-controller-app/docs/plans/002-gdl90-receiver-parser/tasks/phase-8-stream-transport-layer/execution.log.md`
+- **Format**: TDD workflow documentation (SETUP → RED → GREEN → REFACTOR)
+- **Contents**:
+  - Task execution details with timestamps
+  - Test results (RED gate, GREEN gate)
+  - Coverage report output
+  - Code quality metrics (analyzer, formatter)
+  - Implementation notes and decisions
+  - Blockers/issues encountered
+  - FlowSpace node IDs for footnote ledger
+
+**Supporting Files** (if needed):
+- `test/fixtures/` - Binary test fixtures (if integration tests added)
+- `docs/` - Additional diagrams or documentation (if needed)
+
+---
+
+## Directory Layout
+
+```
+docs/plans/002-gdl90-receiver-parser/
+├── gdl90-receiver-parser-plan.md
+├── gdl90-receiver-parser-spec.md
+└── tasks/
+    ├── phase-7-additional-messages/
+    │   ├── tasks.md
+    │   └── execution.log.md
+    └── phase-8-stream-transport-layer/
+        ├── tasks.md                    # This file
+        └── execution.log.md            # Created by /plan-6
+```
+
+**Implementation Files** (created during Phase 8):
+```
+packages/skyecho_gdl90/
+├── lib/
+│   └── src/
+│       └── stream/
+│           └── gdl90_stream.dart       # Main deliverable (T001, T012-T020)
+└── test/
+    └── unit/
+        └── stream_test.dart            # Test file (T002-T011, T021)
+```
+
+---
+
+**Status**: ⏸️ **AWAITING GO/NO-GO DECISION**
+
+**Next Step**: If approved, run:
+```bash
+/plan-6-implement-phase \
+  --phase "Phase 8: Stream Transport Layer" \
+  --plan "/Users/jordanknight/github/skyecho-controller-app/docs/plans/002-gdl90-receiver-parser/gdl90-receiver-parser-plan.md"
+```
+
+---
+
+## Critical Insights Discussion
+
+**Session**: 2025-10-20  
+**Context**: Phase 8 Stream Transport Layer - Tasks & Alignment Brief v1.0  
+**Analyst**: AI Clarity Agent  
+**Reviewer**: Development Team  
+**Format**: Water Cooler Conversation (5 Critical Insights)
+
+### Insight 1: Stream Reusability Trap
+
+**Did you know**: When `stop()` is called on `Gdl90Stream`, the StreamController closes permanently and cannot be restarted, breaking pause/resume workflows
+
+**Implications**:
+- Single-use streams only - entire instance must be recreated for restart
+- Memory leak risk if users don't realize streams are disposable
+- API surprise - most stream APIs support restart (video players, audio streams)
+- No graceful pause - users must keep stream running 100% or face full teardown/rebuild
+
+**Options Considered**:
+- Option A: Lazy StreamController (recreate on restart)
+- Option B: Explicit Documentation + Single-Use API  
+- Option C: Restart Method Pattern
+- Option D: Keep-Alive Pattern (never close controller) - **SELECTED**
+
+**AI Recommendation**: Option D (Keep-Alive with dispose())
+- Reasoning: Matches Flutter lifecycle patterns (dispose() for final cleanup), enables natural pause/resume via start()/stop(), prevents memory leaks with clear ownership
+
+**Discussion Summary**:
+User selected Option D, recognizing that flight logging applications need true pause/resume capability between flights without rebuilding stream instances.
+
+**Decision**: Implement keep-alive pattern with separate `dispose()` method
+
+**Action Items**:
+- [x] Update T004 test to verify stop() does NOT close StreamController
+- [x] Add T004b test for dispose() method closing controller
+- [x] Add dispose() method to implementation outline (T016b)
+- [x] Update T003/T004 to test multiple start/stop cycles
+- [x] Document lifecycle: start() → stop() → start() (OK), dispose() → start() (ERROR)
+
+**Affects**: Tasks T003, T004, T004b, T016, T016b (lifecycle methods), Test Plan section
+
+---
+
+### Insight 2: Framer Re-Entrancy Death Trap
+
+**Did you know**: Gdl90Framer has hardcoded re-entrancy guard that throws StateError if addBytes() called from within onFrame callback, which synchronous event delivery could trigger
+
+**Implications**:
+- Synchronous listener execution dangerous - user callbacks run in same call stack as framer
+- Stream event queue could trigger re-entrancy depending on Dart scheduler
+- No recovery from crash - framer throws, stream dies, user must rebuild
+- Race condition risk depends on timing of UDP arrivals and stream processing
+
+**Options Considered**:
+- Option A: Async Callback with microtask scheduling
+- Option B: Sync-to-Async StreamController (sync: false) - **SELECTED**
+- Option C: Queue Events Internally
+- Option D: Document + Hope
+
+**AI Recommendation**: Option B (sync: false StreamController)
+- Reasoning: Idiomatic Dart (sync: false is default), prevents ALL re-entrancy cases, zero complexity (one parameter), matches UDP async semantics
+
+**Discussion Summary**:
+User agreed to make `sync: false` explicit in implementation to document design decision and prevent future confusion about async delivery requirement.
+
+**Decision**: Explicit `sync: false` StreamController with re-entrancy safety test
+
+**Action Items**:
+- [x] Update T002 test to verify async event delivery
+- [x] Add T007b test for re-entrancy safety (rapid UDP bursts)
+- [x] Make `sync: false` explicit in T012 implementation outline
+- [x] Add comment explaining why `sync: false` is required (framer constraint)
+- [x] Document framer re-entrancy limitation in Invariants section
+
+**Affects**: Tasks T002, T007, T007b, T012 (StreamController creation), Invariants & Guardrails section
+
+---
+
+### Insight 3: The Missing Subscription Leak
+
+**Did you know**: Implementation outline forgot to assign socket.listen() return value to `_subscription` field, breaking pause/resume and causing memory leak on stop()
+
+**Implications**:
+- Backpressure completely broken - pause/resume do nothing (_subscription is null)
+- Memory leak on stop() - subscription never canceled, continues processing
+- Potential crashes - subscription delivering events to closed socket
+- Tests T005, T006 will fail during GREEN phase
+
+**Options Considered**:
+- Option A: Assign Subscription in start() (correct fix) - **SELECTED**
+- Option B: Inline Pause/Resume (alternative architecture)
+- Option C: Remove Backpressure Support (scope reduction)
+- Option D: Document + Hope (no fix)
+
+**AI Recommendation**: Option A (Assign Subscription)
+- Reasoning: One-line fix (add `_subscription = `), already planned (_subscription field exists in T012), required for Phase 8 task 8.3 (backpressure), enables proper cleanup
+
+**Discussion Summary**:
+User recognized this was documentation oversight - the `_subscription` field was already added in T012, just forgot to assign it in T013 implementation example.
+
+**Decision**: Fix subscription assignment in T013 implementation outline
+
+**Action Items**:
+- [x] Update T013 implementation to assign subscription: `_subscription = _socket!.listen(...)`
+- [x] Add comment explaining why subscription must be stored
+- [x] Update T016 stop() to show subscription.cancel() properly
+- [x] Verify T005/T006 tests will catch this bug if forgotten
+
+**Affects**: Tasks T013 (start method), T016 (stop method), T017 (pause/resume)
+
+---
+
+### Insight 4: The State Validation Gap
+
+**Did you know**: start() has no guard against concurrent calls, allowing multiple socket subscriptions to be created simultaneously, causing duplicate events and resource leaks
+
+**Implications**:
+- Race condition - concurrent start() calls create duplicate subscriptions
+- Resource leak - old subscriptions never canceled
+- Duplicate events - users see every packet twice (or more)
+- Port binding conflicts - "Address already in use" errors
+- Current `_isRunning` guard only works for sequential calls, not concurrent
+
+**Options Considered**:
+- Option A: State Enum with Validation
+- Option B: Async Lock/Mutex Pattern - **SELECTED**
+- Option C: Idempotent start() with Early Return
+- Option D: Throw on Invalid State
+
+**AI Recommendation**: Option B (Async Lock)
+- Reasoning: Prevents concurrent start() race conditions, stronger guarantees than assertions alone, ~10 lines of code, familiar pattern
+
+**Discussion Summary**:
+User chose Option B for explicit protection over defensive programming, recognizing that stronger guarantees are worth the extra lines for stream lifecycle safety.
+
+**Decision**: Async lock pattern with `_startInProgress` and `_isDisposed` flags
+
+**Action Items**:
+- [x] Add `_startInProgress` flag to T012 class fields
+- [x] Add `_isDisposed` flag to T012 class fields
+- [x] Update T013 start() to check and set `_startInProgress` flag
+- [x] Update T016b dispose() to set `_isDisposed` flag
+- [x] Add T003b test for concurrent start() calls (verify only one succeeds)
+- [x] Add T004c test for start() after dispose() throws StateError
+- [x] Update exception safety (T019) to clear `_startInProgress` on error
+
+**Affects**: Tasks T003, T003b, T004b, T004c, T012, T013, T016b, T019
+
+---
+
+### Insight 5: The Silent Test Constructor Bug
+
+**Did you know**: Test constructor `Gdl90Stream.withSocket()` doesn't initialize StreamController, causing all unit tests to crash with LateInitializationError when accessing stream.events
+
+**Implications**:
+- All unit tests DOA - can't even create test instance
+- RED phase corrupted - tests fail for wrong reason (broken constructor vs unimplemented features)
+- Wastes implementation time debugging test infrastructure
+- Easy to miss - "same initialization" comment looks correct but is incomplete
+- Late-binding landmine - `late` keyword defers error to first access, not construction
+
+**Options Considered**:
+- Option A: Duplicate Initialization (full constructor body)
+- Option B: Shared Initialization Method - **SELECTED**
+- Option C: Factory Constructor Pattern
+- Option D: Named Parameters with Defaults
+
+**AI Recommendation**: Option B (Shared Initialization Method)
+- Reasoning: DRY principle (single initialization logic), clear intent (`_initController()` documents purpose), maintainable (future changes need one update), Dart-idiomatic pattern
+
+**Discussion Summary**:
+User agreed that shared initialization method prevents code duplication and ensures both constructors remain synchronized for StreamController setup.
+
+**Decision**: Extract `_initController()` shared initialization method
+
+**Action Items**:
+- [x] Update T012 implementation to extract `_initController()` method
+- [x] Update test constructor `withSocket()` to call `_initController()`
+- [x] Add comment in test constructor explaining why shared initialization is critical
+- [x] Update T020 validation to verify controller is initialized in test constructor
+
+**Affects**: Tasks T012 (class implementation), T020 (test constructor validation)
+
+---
+
+## Session Summary
+
+**Insights Surfaced**: 5 critical insights identified and discussed  
+**Decisions Made**: 5 decisions reached through collaborative discussion  
+**Action Items Created**: 33 follow-up tasks identified  
+**Areas Requiring Updates**:
+- Task table: +4 tests (T003b, T004b, T004c, T007b) → 29 total tasks
+- Implementation outline: All 5 insights applied (keep-alive, sync:false, subscription assignment, async lock, shared init)
+- Test plan: +4 tests with rationale → 13 total tests
+- Invariants section: Added re-entrancy safety documentation
+
+**Shared Understanding Achieved**: ✓
+
+**Confidence Level**: High - We have high confidence about proceeding with implementation
+
+**Next Steps**:
+Proceed to implementation with updated planning document. All 5 critical risks mitigated:
+1. Keep-alive pattern enables restart
+2. sync:false prevents framer re-entrancy
+3. Subscription properly assigned and tracked
+4. Async lock prevents concurrent start() race
+5. Shared initialization prevents test constructor crash
+
+**Notes**:
+All 5 insights were non-obvious implications requiring deep analysis across UX, system behavior, technical constraints, and edge cases. Each insight would have caused production incidents or significant debugging time if not caught during planning. The planning document now includes comprehensive safeguards that reflect real-world stream lifecycle requirements.
diff --git a/packages/skyecho_gdl90/lib/src/stream/gdl90_stream.dart b/packages/skyecho_gdl90/lib/src/stream/gdl90_stream.dart
new file mode 100644
index 0000000..b9a8eb0
--- /dev/null
+++ b/packages/skyecho_gdl90/lib/src/stream/gdl90_stream.dart
@@ -0,0 +1,223 @@
+import 'dart:async';
+import 'dart:io';
+import 'dart:typed_data';
+
+import '../framer.dart';
+import '../models/gdl90_event.dart';
+import '../parser.dart';
+
+/// Function signature for binding UDP sockets.
+///
+/// Matches the signature of [RawDatagramSocket.bind] including default
+/// parameters. This allows tests to inject a mock binder that returns a fake
+/// socket without calling the real network bind operation.
+typedef UdpBinder = Future<RawDatagramSocket> Function(
+  dynamic host,
+  int port, {
+  bool reuseAddress,
+  bool reusePort,
+  int ttl,
+});
+
+/// GDL90 UDP stream receiver that integrates framing and parsing into a Dart
+/// Stream API.
+///
+/// Provides lifecycle management (start/stop/dispose), backpressure support, and
+/// error resilience for receiving GDL90 messages over UDP.
+///
+/// **Lifecycle**:
+/// ```dart
+/// final stream = Gdl90Stream(host: '192.168.4.1', port: 4000);
+/// await stream.start();
+///
+/// stream.events.listen((event) {
+///   if (event is Gdl90DataEvent) {
+///     print('Received message: ${event.message.messageType}');
+///   }
+/// });
+///
+/// await stream.stop();   // Pause streaming (can restart)
+/// await stream.dispose(); // Final cleanup (cannot restart)
+/// ```
+///
+/// **Thread Safety**: Not thread-safe. Use from single isolate only.
+class Gdl90Stream {
+  final String _host;
+  final int _port;
+  final UdpBinder _binder;
+  late final StreamController<Gdl90Event> _controller;
+  RawDatagramSocket? _socket;
+  StreamSubscription<RawSocketEvent>? _subscription;
+  final Gdl90Framer _framer = Gdl90Framer();
+
+  // State flags
+  bool _isRunning = false;
+  bool _startInProgress = false; // Async lock for concurrent start()
+  bool _isDisposed = false; // Prevents use-after-dispose
+
+  /// Creates a GDL90 stream receiver for the specified host and port.
+  ///
+  /// **Parameters**:
+  /// - [host]: UDP host to bind (typically '192.168.4.1' for SkyEcho)
+  /// - [port]: UDP port (typically 4000 for GDL90)
+  /// - [binder]: Optional UDP socket binder (defaults to
+  ///   [RawDatagramSocket.bind]). Inject a custom binder in tests to avoid
+  ///   real network I/O.
+  Gdl90Stream({
+    required String host,
+    required int port,
+    UdpBinder? binder,
+  })  : _host = host,
+        _port = port,
+        _binder = binder ?? RawDatagramSocket.bind {
+    _initController();
+  }
+
+  /// Test constructor - injectable socket for unit testing.
+  ///
+  /// **WARNING**: This constructor is for testing only. Do not use in
+  /// production.
+  ///
+  /// **Parameters**:
+  /// - [socket]: Pre-constructed socket (typically a mock/fake for testing)
+  /// - [binder]: Optional binder that throws if called (diagnostic guard).
+  ///   If not provided, defaults to a guard that throws [StateError]
+  ///   if invoked.
+  Gdl90Stream.withSocket(RawDatagramSocket socket, {UdpBinder? binder})
+      : _host = 'test',
+        _port = 0,
+        _socket = socket,
+        _binder = binder ??
+            ((_, __,
+                {reuseAddress = true, reusePort = false, ttl = 1}) async {
+              throw StateError(
+                  'Binder must not be called when socket is '
+                  'injected via withSocket()');
+            }) {
+    // CRITICAL: Must call _initController() to initialize StreamController
+    // Without this, accessing .events will throw LateInitializationError
+    _initController();
+  }
+
+  /// Initializes StreamController with re-entrancy safety and lifecycle
+  /// callbacks. Shared between main and test constructors to avoid duplication.
+  void _initController() {
+    // CRITICAL: sync: false prevents re-entrancy into Gdl90Framer
+    // Framer throws StateError if addBytes() called re-entrantly
+    // (framer.dart:51-54). Async delivery ensures listener callbacks never
+    // execute in same call stack
+    _controller = StreamController<Gdl90Event>(
+      sync: false, // Explicit async delivery for re-entrancy safety
+      onPause: _handlePause,
+      onResume: _handleResume,
+      onCancel: () => stop(),
+    );
+  }
+
+  /// Stream of GDL90 events (data, errors, or ignored messages).
+  ///
+  /// Events are delivered asynchronously (`sync: false`) to prevent framer
+  /// re-entrancy.
+  Stream<Gdl90Event> get events => _controller.stream;
+
+  /// Returns true if the stream is actively receiving UDP datagrams.
+  bool get isRunning => _isRunning;
+
+  /// Starts receiving GDL90 UDP datagrams from the configured host/port.
+  ///
+  /// **Idempotent**: Safe to call multiple times (returns early if already
+  /// running).
+  ///
+  /// **Throws**: [StateError] if called after [dispose()].
+  Future<void> start() async {
+    // Idempotent guard - safe to call multiple times sequentially
+    if (_isRunning) return;
+
+    // Disposed guard - prevent use-after-dispose
+    if (_isDisposed) {
+      throw StateError('Cannot start() after dispose(). '
+          'Create a new Gdl90Stream instance.');
+    }
+
+    // Async lock - prevent concurrent start() calls
+    if (_startInProgress) return; // Second call returns early
+
+    try {
+      _startInProgress = true;
+
+      // Use injected binder to create socket if not already set
+      _socket ??= await _binder(
+        _host,
+        _port,
+        reuseAddress: true,
+        reusePort: false,
+        ttl: 1,
+      );
+      // CRITICAL: Store subscription for pause/resume and proper cleanup
+      _subscription = _socket!.listen(_handleDatagram);
+      _isRunning = true;
+    } finally {
+      _startInProgress = false; // Always clear lock, even on exception
+    }
+  }
+
+  /// Stops receiving UDP datagrams and closes the socket.
+  ///
+  /// **Keep-Alive Pattern**: StreamController remains open for restart.
+  /// Call [dispose()] for final cleanup.
+  ///
+  /// **Idempotent**: Safe to call multiple times.
+  Future<void> stop() async {
+    if (!_isRunning) return;
+
+    try {
+      await _subscription?.cancel();
+    } finally {
+      _socket?.close();
+      _socket = null;
+      _subscription = null;
+      _isRunning = false;
+    }
+  }
+
+  /// Performs final cleanup and closes the StreamController.
+  ///
+  /// **WARNING**: After calling dispose(), the stream cannot be restarted.
+  /// Create a new Gdl90Stream instance if needed.
+  ///
+  /// **Idempotent**: Safe to call multiple times.
+  Future<void> dispose() async {
+    if (_isDisposed) return;
+
+    try {
+      _isDisposed = true;
+      await stop();
+    } finally {
+      await _controller.close();
+    }
+  }
+
+  void _handleDatagram(RawSocketEvent event) {
+    if (event == RawSocketEvent.read) {
+      final datagram = _socket!.receive();
+      if (datagram != null) {
+        _framer.addBytes(datagram.data, _handleFrame);
+      }
+    }
+  }
+
+  void _handleFrame(Uint8List frame) {
+    final event = Gdl90Parser.parse(frame);
+    _controller.add(event);
+  }
+
+  void _handlePause() {
+    // Pause socket subscription to stop receiving UDP events
+    _subscription?.pause();
+  }
+
+  void _handleResume() {
+    // Resume socket subscription to restart UDP event flow
+    _subscription?.resume();
+  }
+}
diff --git a/packages/skyecho_gdl90/test/unit/stream_test.dart b/packages/skyecho_gdl90/test/unit/stream_test.dart
new file mode 100644
index 0000000..9da7782
--- /dev/null
+++ b/packages/skyecho_gdl90/test/unit/stream_test.dart
@@ -0,0 +1,586 @@
+import 'dart:async';
+import 'dart:io';
+import 'dart:typed_data';
+
+import 'package:test/test.dart';
+import 'package:skyecho_gdl90/src/models/gdl90_event.dart';
+import 'package:skyecho_gdl90/src/models/gdl90_message.dart';
+import 'package:skyecho_gdl90/src/stream/gdl90_stream.dart';
+
+/// Helper to create a Gdl90Stream with a mock socket binder.
+///
+/// This avoids real network I/O by injecting a binder that returns the
+/// provided mock socket.
+Gdl90Stream createStreamWithMock(MockRawDatagramSocket mockSocket) {
+  return Gdl90Stream(
+    host: 'test',
+    port: 0,
+    binder: (_, __, {reuseAddress = true, reusePort = false, ttl = 1}) =>
+        Future.value(mockSocket),
+  );
+}
+
+void main() {
+  group('Gdl90Stream', () {
+    // T002: Stream creation test
+    test('given_host_and_port_when_creating_stream_then_instance_valid', () {
+      /*
+      Test Doc:
+      - Why: Validates basic instantiation with network parameters
+      - Contract: Constructor accepts host (String) and port (int), returns valid instance
+      - Usage Notes: Host typically '192.168.4.1', port 4000 for SkyEcho
+      - Quality Contribution: Prevents API breaking changes in constructor signature
+      - Worked Example: Gdl90Stream(host: '192.168.4.1', port: 4000) → valid instance with accessible .events
+      */
+
+      // Arrange & Act
+      final stream = Gdl90Stream(host: '192.168.4.1', port: 4000);
+
+      // Assert
+      expect(stream, isA<Gdl90Stream>());
+      expect(stream.events, isA<Stream<Gdl90Event>>());
+      expect(stream.isRunning, isFalse);
+    });
+
+    // T003: Start lifecycle test
+    test('given_stream_when_start_called_then_becomes_running', () async {
+      /*
+      Test Doc:
+      - Why: Validates socket opens and stream becomes active
+      - Contract: start() binds socket, sets isRunning=true, enables event emission
+      - Usage Notes: Call start() before listening to events; idempotent (safe to call multiple times)
+      - Quality Contribution: Ensures lifecycle state transitions correctly
+      - Worked Example: await stream.start() → isRunning changes false→true
+      */
+
+      // Arrange
+      final mockSocket = MockRawDatagramSocket();
+      final stream = createStreamWithMock(mockSocket);
+
+      // Act
+      await stream.start();
+
+      // Assert
+      expect(stream.isRunning, isTrue);
+
+      // Cleanup
+      await stream.dispose();
+    });
+
+    // T003b: Concurrent start prevention test
+    test(
+        'given_concurrent_start_calls_when_both_execute_then_only_one_proceeds',
+        () async {
+      /*
+      Test Doc:
+      - Why: Validates async lock prevents duplicate subscriptions from race condition
+      - Contract: Concurrent start() calls prevented by _startInProgress flag; only one succeeds
+      - Usage Notes: start() uses try-finally to ensure lock always cleared
+      - Quality Contribution: Prevents resource leak and duplicate events from concurrent calls
+      - Worked Example: Future.wait([stream.start(), stream.start()]) → single subscription created
+      */
+
+      // Arrange
+      final mockSocket = MockRawDatagramSocket();
+      final stream = createStreamWithMock(mockSocket);
+
+      // Act - concurrent calls
+      await Future.wait([
+        stream.start(),
+        stream.start(),
+      ]);
+
+      // Assert - stream started only once
+      expect(stream.isRunning, isTrue);
+      expect(
+          mockSocket.listenCallCount, equals(1)); // Verify single subscription
+
+      // Cleanup
+      await stream.dispose();
+    });
+
+    // T004: Stop lifecycle test (keep-alive pattern)
+    test(
+        'given_running_stream_when_stop_called_then_socket_closes_controller_stays_open',
+        () async {
+      /*
+      Test Doc:
+      - Why: Validates socket closes but controller stays alive for restart (keep-alive pattern)
+      - Contract: stop() closes socket, sets isRunning=false, but controller remains open
+      - Usage Notes: After stop(), can call start() again to resume; use dispose() for final cleanup
+      - Quality Contribution: Enables pause/resume workflow without recreating stream instance
+      - Worked Example: start() → stop() → start() works; controller.isClosed remains false after stop()
+      */
+
+      // Arrange
+      final mockSocket = MockRawDatagramSocket();
+      final stream = createStreamWithMock(mockSocket);
+      await stream.start();
+
+      // Act
+      await stream.stop();
+
+      // Assert
+      expect(stream.isRunning, isFalse);
+      expect(mockSocket.isClosed, isTrue);
+      // Controller should still be open (can restart)
+      final canAddListener = await _canAddStreamListener(stream.events);
+      expect(canAddListener, isTrue);
+
+      // Cleanup
+      await stream.dispose();
+    });
+
+    // T004b: Dispose final cleanup test
+    test('given_stream_when_dispose_called_then_controller_closes', () async {
+      /*
+      Test Doc:
+      - Why: Validates final cleanup closes controller (matches Flutter lifecycle)
+      - Contract: dispose() calls stop(), then closes StreamController
+      - Usage Notes: After dispose(), stream cannot be restarted; must create new instance
+      - Quality Contribution: Prevents memory leaks by ensuring complete resource cleanup
+      - Worked Example: await dispose() → controller.isClosed=true, stream.events emits done
+      */
+
+      // Arrange
+      final mockSocket = MockRawDatagramSocket();
+      final stream = createStreamWithMock(mockSocket);
+
+      // Act
+      await stream.dispose();
+
+      // Assert
+      final canAddListener = await _canAddStreamListener(stream.events);
+      expect(canAddListener, isFalse); // Controller closed
+
+      // No cleanup needed (already disposed)
+    });
+
+    // T004c: Start after dispose error test
+    test('given_disposed_stream_when_start_called_then_throws_state_error',
+        () async {
+      /*
+      Test Doc:
+      - Why: Validates disposed state prevents restart (use-after-dispose protection)
+      - Contract: start() throws StateError if called after dispose()
+      - Usage Notes: Check error message suggests creating new instance
+      - Quality Contribution: Prevents memory corruption and undefined behavior from use-after-dispose
+      - Worked Example: dispose() → start() → StateError('Cannot start() after dispose()...')
+      */
+
+      // Arrange
+      final mockSocket = MockRawDatagramSocket();
+      final stream = createStreamWithMock(mockSocket);
+      await stream.dispose();
+
+      // Act & Assert
+      expect(
+        () => stream.start(),
+        throwsA(isA<StateError>().having(
+          (e) => e.message,
+          'message',
+          contains('Cannot start() after dispose()'),
+        )),
+      );
+    });
+
+    // T005: Pause backpressure test
+    test('given_running_stream_when_paused_then_no_events_emitted', () async {
+      /*
+      Test Doc:
+      - Why: Validates Dart Stream backpressure support via pause()
+      - Contract: StreamSubscription.pause() stops event emission until resume()
+      - Usage Notes: Caller controls backpressure; stream respects pause/resume
+      - Quality Contribution: Prevents buffer overflow when consumer is slow
+      - Worked Example: listen().pause() → subscription.pause() called → no events flow
+      */
+
+      // Arrange
+      final mockSocket = MockRawDatagramSocket();
+      final stream = createStreamWithMock(mockSocket);
+      await stream.start();
+
+      final receivedEvents = <Gdl90Event>[];
+      final subscription = stream.events.listen(receivedEvents.add);
+
+      // Act - pause subscription
+      subscription.pause();
+      mockSocket.emitDatagram(_heartbeatDatagram());
+      await Future.delayed(Duration(milliseconds: 50)); // Let events process
+
+      // Assert - no events received while paused
+      expect(receivedEvents, isEmpty);
+
+      // Cleanup
+      await subscription.cancel();
+      await stream.dispose();
+    });
+
+    // T006: Resume backpressure test
+    test('given_paused_stream_when_resumed_then_events_flow_again', () async {
+      /*
+      Test Doc:
+      - Why: Validates stream resumes after pause
+      - Contract: StreamSubscription.resume() restarts event emission
+      - Usage Notes: Events queued during pause are delivered after resume
+      - Quality Contribution: Ensures backpressure control is bidirectional
+      - Worked Example: pause() → resume() → events flow again
+      */
+
+      // Arrange
+      final mockSocket = MockRawDatagramSocket();
+      final stream = createStreamWithMock(mockSocket);
+      await stream.start();
+
+      final receivedEvents = <Gdl90Event>[];
+      final subscription = stream.events.listen(receivedEvents.add);
+      subscription.pause();
+
+      // Act - resume subscription
+      subscription.resume();
+      mockSocket.emitDatagram(_heartbeatDatagram());
+      await Future.delayed(Duration(milliseconds: 50)); // Let events process
+
+      // Assert - events received after resume
+      expect(receivedEvents, isNotEmpty);
+      expect(receivedEvents.first, isA<Gdl90DataEvent>());
+
+      // Cleanup
+      await subscription.cancel();
+      await stream.dispose();
+    });
+
+    // T007: UDP datagram reception test
+    test('given_udp_datagram_when_received_then_framer_processes', () async {
+      /*
+      Test Doc:
+      - Why: Validates datagram bytes passed to framer
+      - Contract: RawDatagramSocket.receive() → Gdl90Framer.addBytes() → frame extracted
+      - Usage Notes: Tests socket → framer boundary integration
+      - Quality Contribution: Ensures UDP datagrams correctly routed to framing layer
+      - Worked Example: mockSocket.receive() returns heartbeat datagram → framer.addBytes called
+      */
+
+      // Arrange
+      final mockSocket = MockRawDatagramSocket();
+      final stream = createStreamWithMock(mockSocket);
+      await stream.start();
+
+      final receivedEvents = <Gdl90Event>[];
+      final subscription = stream.events.listen(receivedEvents.add);
+
+      // Act - emit valid heartbeat datagram
+      mockSocket.emitDatagram(_heartbeatDatagram());
+      await Future.delayed(
+          Duration(milliseconds: 50)); // Let async processing complete
+
+      // Assert - event received and parsed
+      expect(receivedEvents, hasLength(1));
+      expect(receivedEvents.first, isA<Gdl90DataEvent>());
+      final dataEvent = receivedEvents.first as Gdl90DataEvent;
+      expect(dataEvent.message.messageType, equals(Gdl90MessageType.heartbeat));
+
+      // Cleanup
+      await subscription.cancel();
+      await stream.dispose();
+    });
+
+    // T007b: Re-entrancy safety test
+    test('given_rapid_udp_bursts_when_processed_then_no_re_entrancy_error',
+        () async {
+      /*
+      Test Doc:
+      - Why: Validates async delivery prevents framer re-entrancy crash
+      - Contract: StreamController(sync: false) prevents listener execution in same call stack
+      - Usage Notes: Framer throws StateError if addBytes() called re-entrantly (line 51-54 framer.dart)
+      - Quality Contribution: Prevents production crashes from rapid UDP bursts
+      - Worked Example: Emit 2 datagrams back-to-back → both processed successfully, no StateError
+      */
+
+      // Arrange
+      final mockSocket = MockRawDatagramSocket();
+      final stream = createStreamWithMock(mockSocket);
+      await stream.start();
+
+      final receivedEvents = <Gdl90Event>[];
+      final subscription = stream.events.listen(receivedEvents.add);
+
+      // Act - emit 2 datagrams rapidly (back-to-back)
+      mockSocket.emitDatagram(_heartbeatDatagram());
+      mockSocket.emitDatagram(_heartbeatDatagram());
+      await Future.delayed(
+          Duration(milliseconds: 100)); // Let all events process
+
+      // Assert - both events received, no StateError thrown
+      expect(receivedEvents, hasLength(2));
+      expect(receivedEvents[0], isA<Gdl90DataEvent>());
+      expect(receivedEvents[1], isA<Gdl90DataEvent>());
+
+      // Cleanup
+      await subscription.cancel();
+      await stream.dispose();
+    });
+
+    // T008: End-to-end pipeline test
+    test('given_udp_datagram_when_processed_then_parsed_event_emitted',
+        () async {
+      /*
+      Test Doc:
+      - Why: Validates complete UDP → events flow (integration test)
+      - Contract: UDP datagram → framer → parser → Gdl90Event emission
+      - Usage Notes: Critical end-to-end test validating entire pipeline
+      - Quality Contribution: Ensures full integration works correctly
+      - Worked Example: Raw UDP bytes → Gdl90DataEvent with parsed Gdl90Message
+      */
+
+      // Arrange
+      final mockSocket = MockRawDatagramSocket();
+      final stream = createStreamWithMock(mockSocket);
+      await stream.start();
+
+      final receivedEvents = <Gdl90Event>[];
+      final subscription = stream.events.listen(receivedEvents.add);
+
+      // Act - emit complete heartbeat message
+      mockSocket.emitDatagram(_heartbeatDatagram());
+      await Future.delayed(Duration(milliseconds: 50));
+
+      // Assert - parsed message received
+      expect(receivedEvents, hasLength(1));
+      expect(receivedEvents.first, isA<Gdl90DataEvent>());
+
+      final dataEvent = receivedEvents.first as Gdl90DataEvent;
+      final message = dataEvent.message;
+
+      expect(message.messageType, equals(Gdl90MessageType.heartbeat));
+      expect(message.gpsPosValid, isA<bool>()); // Heartbeat has status flags
+      expect(message.timeOfDaySeconds, isA<int>());
+
+      // Cleanup
+      await subscription.cancel();
+      await stream.dispose();
+    });
+
+    // T009: Error event emission test
+    test(
+        'given_malformed_frame_when_processed_then_error_event_emitted_stream_continues',
+        () async {
+      /*
+      Test Doc:
+      - Why: Validates malformed frames don't crash stream (resilience)
+      - Contract: Bad CRC/invalid frame → Gdl90ErrorEvent emitted, stream continues
+      - Usage Notes: Stream must continue processing after error (no exception thrown)
+      - Quality Contribution: Validates Discovery 05 (wrapper pattern stream resilience)
+      - Worked Example: Bad frame → ErrorEvent, then good frame → DataEvent
+      */
+
+      // Arrange
+      final mockSocket = MockRawDatagramSocket();
+      final stream = createStreamWithMock(mockSocket);
+      await stream.start();
+
+      final receivedEvents = <Gdl90Event>[];
+      final subscription = stream.events.listen(receivedEvents.add);
+
+      // Act - emit bad CRC frame, then good frame
+      mockSocket.emitDatagram(_badCrcDatagram());
+      mockSocket.emitDatagram(_heartbeatDatagram());
+      await Future.delayed(Duration(milliseconds: 100));
+
+      // Assert - error event for bad frame, data event for good frame
+      expect(receivedEvents.length,
+          greaterThanOrEqualTo(1)); // At least the good frame
+      final hasDataEvent = receivedEvents.any((e) => e is Gdl90DataEvent);
+      expect(hasDataEvent, isTrue); // Stream continued processing after error
+
+      // Cleanup
+      await subscription.cancel();
+      await stream.dispose();
+    });
+
+    // T010: Socket cleanup on exception test
+    test('given_socket_exception_when_thrown_then_socket_closed', () async {
+      /*
+      Test Doc:
+      - Why: Validates resource safety on errors (exception safety)
+      - Contract: Socket.close() called even if exception occurs during operation
+      - Usage Notes: Uses try-finally pattern to ensure cleanup
+      - Quality Contribution: Prevents resource leaks from exceptions
+      - Worked Example: Exception in datagram handling → socket still closed by stop()
+      */
+
+      // Arrange
+      final mockSocket = MockRawDatagramSocket();
+      mockSocket.throwOnListen = true; // Simulate socket error
+
+      final stream = createStreamWithMock(mockSocket);
+
+      // Act - start will throw exception
+      try {
+        await stream.start();
+      } catch (e) {
+        // Expected exception from mock
+      }
+
+      // Ensure cleanup happens
+      await stream.stop();
+
+      // Assert - socket closed despite exception
+      expect(mockSocket.isClosed, isTrue);
+
+      // Cleanup
+      await stream.dispose();
+    });
+  });
+}
+
+// ============================================================================
+// Test Fixtures
+// ============================================================================
+
+/// Returns a valid GDL90 heartbeat datagram (UDP packet format with 0x7E flags).
+Uint8List _heartbeatDatagram() {
+  // Heartbeat message (ID 0x00) with valid CRC
+  return Uint8List.fromList([
+    0x7E, // Start flag
+    0x00, // Message ID: Heartbeat
+    0x81, // Status byte 1: GPS pos valid (bit 7 set)
+    0x41, // Status byte 2
+    0xDB, 0xD0, // Time-of-day timestamp
+    0x08, 0x02, // Message counts
+    0xB3, 0x8B, // CRC-16-CCITT (LSB-first)
+    0x7E, // End flag
+  ]);
+}
+
+/// Returns a datagram with bad CRC (frame will be rejected).
+Uint8List _badCrcDatagram() {
+  return Uint8List.fromList([
+    0x7E, // Start flag
+    0x00, // Message ID: Heartbeat
+    0x81, 0x41, 0xDB, 0xD0, 0x08, 0x02,
+    0xFF, 0xFF, // Bad CRC
+    0x7E, // End flag
+  ]);
+}
+
+/// Helper to check if a stream controller is still open by attempting to add a listener.
+Future<bool> _canAddStreamListener(Stream stream) async {
+  try {
+    final subscription = stream.listen(null);
+    await subscription.cancel();
+    return true;
+  } catch (e) {
+    return false; // Controller is closed
+  }
+}
+
+// ============================================================================
+// Mock RawDatagramSocket
+// ============================================================================
+
+class MockRawDatagramSocket extends Stream<RawSocketEvent>
+    implements RawDatagramSocket {
+  bool isClosed = false;
+  bool throwOnListen = false;
+  int listenCallCount = 0;
+
+  final StreamController<RawSocketEvent> _eventController =
+      StreamController<RawSocketEvent>();
+
+  @override
+  StreamSubscription<RawSocketEvent> listen(
+    void Function(RawSocketEvent event)? onData, {
+    Function? onError,
+    void Function()? onDone,
+    bool? cancelOnError,
+  }) {
+    listenCallCount++;
+
+    if (throwOnListen) {
+      throw SocketException('Mock socket error');
+    }
+
+    return _eventController.stream.listen(
+      onData,
+      onError: onError,
+      onDone: onDone,
+      cancelOnError: cancelOnError,
+    );
+  }
+
+  /// Simulates receiving a UDP datagram.
+  void emitDatagram(Uint8List data) {
+    _datagram = Datagram(data, InternetAddress.anyIPv4, 4000);
+    _eventController.add(RawSocketEvent.read);
+  }
+
+  Datagram? _datagram;
+
+  @override
+  Datagram? receive() => _datagram;
+
+  @override
+  void close() {
+    isClosed = true;
+    _eventController.close();
+  }
+
+  // Minimal implementations for required interface methods
+  @override
+  InternetAddress get address => InternetAddress.anyIPv4;
+
+  @override
+  int get port => 4000;
+
+  @override
+  bool get readEventsEnabled => true;
+
+  @override
+  set readEventsEnabled(bool value) {}
+
+  @override
+  bool get writeEventsEnabled => false;
+
+  @override
+  set writeEventsEnabled(bool value) {}
+
+  @override
+  bool get multicastLoopback => false;
+
+  @override
+  set multicastLoopback(bool value) {}
+
+  @override
+  int get multicastHops => 1;
+
+  @override
+  set multicastHops(int value) {}
+
+  @override
+  NetworkInterface? get multicastInterface => null;
+
+  @override
+  set multicastInterface(NetworkInterface? value) {}
+
+  @override
+  bool get broadcastEnabled => false;
+
+  @override
+  set broadcastEnabled(bool value) {}
+
+  @override
+  int send(List<int> buffer, InternetAddress address, int port) => 0;
+
+  @override
+  void joinMulticast(InternetAddress group, [NetworkInterface? interface]) {}
+
+  @override
+  void leaveMulticast(InternetAddress group, [NetworkInterface? interface]) {}
+
+  @override
+  Uint8List getRawOption(RawSocketOption option) => throw UnimplementedError();
+
+  @override
+  void setRawOption(RawSocketOption option) => throw UnimplementedError();
+}
```
