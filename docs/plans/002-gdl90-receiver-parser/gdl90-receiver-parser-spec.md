# GDL90 Receiver & Parser

## Summary

Enable real-time reception and parsing of GDL90 aviation data streams from SkyEcho and other ADS-B devices. GDL90 is a standardized aviation protocol (FAA Public ICD) used to transmit traffic, ownship position, weather uplinks, and other situational awareness data over UDP.

**What**: Create a standalone pure-Dart library (`skyecho_gdl90`) for receiving and parsing GDL90 binary protocol streams, independent of the SkyEcho HTTP control library.

**Why**: The SkyEcho device continuously streams GDL90 data on its local WiFi network (UDP port 4000), providing real-time aviation data that complements the HTTP-based configuration API. Parsing this stream unlocks access to live traffic information, GPS status, height above terrain, and other critical flight data that cannot be obtained through the web interface alone. A separate package enables use with any GDL90-compatible device, supports hardware-independent development via binary fixtures, and prepares for future Flutter app integration using established monorepo path dependency patterns.

## Goals

1. **Receive GDL90 Data Stream** - Users can open a UDP socket on port 4000 and receive raw GDL90 bytes from the SkyEcho device without configuration (device is already transmitting).

2. **Parse Standard GDL90 Messages** - Users can decode all FAA-standard message types into strongly-typed Dart objects:
   - Heartbeat (ID 0) - GPS status, UTC time, message counts
   - Traffic Report (ID 20) - Nearby aircraft position, velocity, callsign
   - Ownship (ID 10) - Own aircraft position and status
   - Ownship Geometric Altitude (ID 11) - Precise altitude data
   - Height Above Terrain (ID 9) - Terrain clearance
   - Uplink Data (ID 7) - Weather and FIS-B messages
   - Initialization (ID 2) - Device initialization messages
   - Pass-Through Basic/Long (ID 30/31) - UAT reports

3. **iOS Platform Support** - UDP receiver works on iOS with proper permissions and network entitlements, enabling Flutter/iOS app integration.

4. **Separation of Concerns** - Transport layer (UDP listener) and parsing logic (GDL90 decoder) are separate, composable components:
   - Transport feeds raw bytes to parser
   - Parser is transport-agnostic (works with UDP, serial, file playback)
   - Clean dependency boundaries for testing

5. **Testable with Real Data** - Developers can capture sample GDL90 data from a live device and replay it in unit tests without requiring physical hardware:
   - Capture utility records real UDP stream to file
   - Test fixtures use authentic device data
   - Playback mechanism feeds captured data to parser

6. **Robust Parsing** - Parser handles real-world data variations gracefully:
   - CRC validation (CRC-16-CCITT per spec)
   - Byte framing/escaping (0x7E flags, 0x7D escape)
   - Tolerance for malformed frames (skip and continue)
   - Support for optional fields across firmware versions

## Non-Goals

1. **Flutter UI Implementation** - This is a pure-Dart library package (`packages/skyecho_gdl90/`) with no Flutter dependencies. UI development happens in a separate Flutter app package following the monorepo pattern.

2. **Integration with `skyecho` HTTP Control Package** - The GDL90 parser is independent and generic (works with any GDL90-compatible device). No direct dependency on `packages/skyecho/`. Future integration can be provided via an optional third package if needed.

3. **GDL90 Encoding/Transmission** - This feature only receives and parses GDL90 data; it does not generate or transmit GDL90 messages back to the device.

4. **Multi-Device Reception** - Support for multiple devices streaming simultaneously is out of scope. Single-device focus aligns with typical usage (one device per aircraft).

5. **Web Platform Support** - Initial implementation targets Dart VM and native platforms (iOS/Android/Desktop via Flutter). Web platform support requires WebSocket proxy (similar to HTTP CORS limitations) and is deferred.

6. **Historical Data Storage** - No persistent storage or database for GDL90 messages beyond in-memory buffering and test fixtures. Applications can implement their own storage layer.

7. **ForeFlight Extensions** - ForeFlight AHRS messages (ID 0x65) are not implemented. SkyEcho has no AHRS hardware and won't transmit these messages. Can be added later if needed for other devices (e.g., Stratux).

8. **FIS-B Weather Decoding** - Uplink Data (ID 7) is parsed to extract the 432-byte UAT payload, but full FIS-B APDU decoding (text weather, NOTAMs, etc.) is deferred to a future enhancement.

9. **UDP Discovery/Autoconfiguration** - Users must know the device IP (192.168.4.1) and port (4000). No Bonjour/mDNS discovery is implemented initially.

## Acceptance Criteria

### AC1: UDP Receiver Opens Port and Receives Data
**Given** a SkyEcho device is powered on and broadcasting GDL90 on 192.168.4.1:4000,
**When** the user creates a UDP receiver instance and starts listening,
**Then** raw UDP datagrams are received and available for processing.

**Observable**: Integration test connects to real device, receives at least one datagram within 5 seconds, datagram contains GDL90 framing byte (0x7E).

---

### AC2: Parser Decodes Heartbeat Messages
**Given** a raw GDL90 heartbeat frame (ID 0) from the device,
**When** the frame is passed to the parser,
**Then** a strongly-typed `Heartbeat` object is returned with GPS status, UTC validity, time-of-day seconds, and message counts accurately extracted.

**Observable**: Unit test using captured heartbeat fixture validates all fields match known values (e.g., `gpsPosValid=true`, `timeOfDaySeconds=43200`).

---

### AC3: Parser Decodes Traffic and Ownship Reports
**Given** a Traffic Report (ID 20) or Ownship (ID 10) frame,
**When** parsed,
**Then** position (lat/lon degrees), altitude (feet), velocity (knots), track (degrees), callsign, and emitter category are correctly decoded.

**Observable**: Unit test verifies Traffic Report with ICAO address 0x7CC599, lat=37.5, lon=-122.3, alt=2500ft, velocity=120kt, callsign="N12345" parses without error and all fields match.

---

### AC4: Parser Handles CRC and Framing
**Given** a byte stream containing multiple GDL90 frames with escaping (0x7D) and CRC-16,
**When** fed to the framer,
**Then** frames are correctly de-escaped, CRC-validated, and invalid frames are silently discarded.

**Observable**: Unit test with intentionally corrupted CRC frame confirms frame is skipped; subsequent valid frame is parsed successfully.

---

### AC5: iOS Platform Compatibility
**Given** a Flutter iOS app integrating the UDP receiver,
**When** built and run on a physical iOS device connected to SkyEcho WiFi,
**Then** the app receives GDL90 data without crashes, and `NSLocalNetworkUsageDescription` permission is requested.

**Observable**: Integration test or manual test on iOS device shows UDP socket binds to port 4000, receives data, and Info.plist contains required network usage description.

---

### AC6: Transport and Parser Are Separate
**Given** the library architecture,
**When** examining the code structure,
**Then** UDP receiver (transport) and GDL90 parser (decoder/framer) are in separate modules with no circular dependencies.

**Observable**: Code review confirms transport layer (`lib/src/stream.dart`) has no dependency on parser internals; parser (`lib/src/parser.dart`) can be imported and used standalone with file/serial data sources. Package has zero dependencies on `skyecho` HTTP control package.

---

### AC7: Sample Data Capture and Playback
**Given** a live SkyEcho device streaming GDL90,
**When** a developer runs the sample data capture utility for 60 seconds,
**Then** raw UDP datagrams are saved to a fixture file (e.g., `test/fixtures/gdl90_sample.bin`).

**And when** unit tests replay the fixture through the parser,
**Then** all message types present in the capture are successfully decoded without errors.

**Observable**: Capture script creates `gdl90_sample.bin` ≥100KB. Test fixture loads file, feeds bytes to framer/decoder, and asserts ≥50 valid messages parsed (Heartbeat, Traffic, Ownship, etc.).

---

### AC8: Parser Tolerates Malformed Data
**Given** a GDL90 stream with occasional incomplete frames, unknown message IDs, or length mismatches,
**When** parsed,
**Then** the parser logs or skips invalid frames and continues processing subsequent valid messages without throwing exceptions.

**Observable**: Unit test with mixed valid/invalid frames (truncated, bad CRC, unknown ID 0xFF) confirms parser returns `null` or skips for invalid frames and successfully decodes valid ones in the same stream.

---

### AC9: All Standard Message Types Supported
**Given** the FAA GDL90 Public ICD message catalog,
**When** the parser is tested against all message types,
**Then** Heartbeat (0), Initialization (2), Uplink (7), HAT (9), Ownship (10), Ownship Geo Altitude (11), Traffic (20), Basic (30), and Long (31) are all decoded.

**Observable**: Unit test suite includes at least one test per message type with real or synthetic fixtures, all passing. ForeFlight extensions (0x65) are out of scope.

---

### AC10: Package Structure Follows Monorepo Conventions
**Given** the established monorepo structure from Plan 001,
**When** examining the package layout,
**Then** the GDL90 package follows the same patterns:
- Located at `packages/skyecho_gdl90/`
- Includes `test/unit/`, `test/integration/`, `test/fixtures/` directories
- Uses Test-Assisted Development (TAD) with 5-field Test Doc blocks
- Binary fixtures captured from real device streams
- Hybrid documentation (README + `docs/how/skyecho-gdl90/`)

**Observable**: Directory structure matches `packages/skyecho/` conventions. All tests include Test Doc blocks. Integration instructions in `docs/how/monorepo-setup.md` cover GDL90 package.

---

### AC11: Documentation and Examples
**Given** a developer new to the library,
**When** they read the README and example code,
**Then** they understand how to open a UDP listener, feed bytes to the parser, and handle decoded messages.

**Observable**: `packages/skyecho_gdl90/example/receive_gdl90.dart` demonstrates complete workflow: open UDP socket, create framer/decoder, process messages, print traffic reports. Package README includes "Quick Start" section with code snippet.

## Package Architecture

### Monorepo Integration
This feature creates a new package: **`packages/skyecho_gdl90/`**

**Rationale for Separate Package:**
1. **Separation of Concerns**: HTTP control (screen-scraping) vs. UDP streaming (binary protocol)
2. **Independent Versioning**: GDL90 spec is stable (FAA standard) vs. evolving SkyEcho firmware
3. **Optional Dependency**: Configuration-only users don't need parser overhead
4. **Generic Reusability**: Works with any GDL90-compatible device, not SkyEcho-specific

**Flutter Readiness:**
- Pure Dart library (no Flutter dependencies)
- Follows path dependency pattern documented in `docs/how/monorepo-setup.md`
- Native platform support (iOS/Android/Desktop) via `dart:io`
- Web platform deferred (requires WebSocket proxy, similar to HTTP CORS issue)

**Alignment with Plan 001:**
- Same directory structure: `lib/`, `test/unit/`, `test/integration/`, `test/fixtures/`, `example/`
- Same testing philosophy: TAD with 5-field Test Doc blocks, 100% coverage on parsing logic
- Same documentation pattern: Hybrid (package README + `docs/how/skyecho-gdl90/`)
- Same quality gates: `dart analyze` clean, `dart format`, no flaky tests

## Risks & Assumptions

### Assumptions
1. **Device is Already Streaming** - SkyEcho device broadcasts GDL90 data continuously on UDP port 4000 without requiring HTTP API commands to enable it. (User confirmed: "device we are connected to is already sending it so it will work straight away").

2. **Standard GDL90 Protocol** - SkyEcho adheres to the FAA GDL90 Public ICD Rev A specification with no undocumented proprietary extensions beyond optional ForeFlight messages.

3. **iOS Network Permissions** - iOS allows local network UDP reception with `NSLocalNetworkUsageDescription` entitlement; no additional MDM/enterprise restrictions.

4. **Single WiFi Network** - SkyEcho creates an isolated WiFi network (192.168.4.x); no routing, firewall, or NAT issues complicate UDP reception.

5. **Dart UDP Support** - `dart:io` RawDatagramSocket works reliably on iOS (via Flutter) for local network UDP unicast/broadcast.

6. **Monorepo Path Dependencies** - Future Flutter app will use path dependencies (`path: ../skyecho_gdl90`) as documented in `docs/how/monorepo-setup.md`.

### Risks
1. **iOS Background Reception Limits** - iOS may throttle or terminate UDP sockets when app backgrounds. Mitigation: Document foreground-only limitation initially; investigate background modes if needed.

2. **Sample Data Representativeness** - Captured GDL90 samples may not cover all edge cases (e.g., emergency codes, invalid positions, firmware variations). Mitigation: Capture from multiple flight scenarios; supplement with synthetic test data per TAD workflow.

3. **UDP Reliability** - UDP is lossy; dropped packets are expected. Risk: Users may expect 100% message delivery. Mitigation: Document UDP limitations; consider adding metrics for dropped frame count.

4. **Parser Performance on High Traffic** - In dense airspace, GDL90 stream may contain 10+ traffic targets at 1 Hz each. Risk: Parser CPU overhead impacts UI responsiveness. Mitigation: Profile parser with high-traffic fixtures; optimize if needed.

5. **CRC Implementation Correctness** - GDL90 CRC-16-CCITT has specific polynomial/init/byte-order requirements. Risk: Incorrect implementation silently discards valid frames. Mitigation: Validate against FAA example frames from ICD Appendix C; require 100% test coverage on CRC logic.

6. **iOS Entitlement Rejections** - Apple may reject apps requesting local network access without clear user-facing justification. Mitigation: Include detailed usage description ("Receive real-time aviation traffic data from SkyEcho ADS-B device").

7. **Binary Fixture Git LFS** - Binary test fixtures may grow large (>100KB per scenario). Risk: Repo size bloat. Mitigation: Use Git LFS if fixtures exceed 1MB total; document capture/regeneration process in `test/fixtures/README.md`.

8. **Package Dependency Confusion** - Users may expect `skyecho` package to include GDL90 parsing. Risk: Discoverability issues. Mitigation: Clear documentation in both package READMEs explaining separation; consider optional integration package for convenience.

## Open Questions

### Q1: Background Reception Requirement? ✅ RESOLVED
**Resolution**: Defer all iOS-specific features to future phase
- **MVP Focus**: CLI tooling + macOS desktop compatibility
- **iOS integration**: Later when Flutter app is ready
- Background modes, permissions, power management all deferred

---

### Q2: Error Handling Strategy for Malformed Frames? ✅ RESOLVED
**Resolution**: Wrapper pattern with optional error events
- Stream emits `Gdl90Event` wrapper objects containing data OR error
- No exceptions thrown for malformed frames
- Caller receives diagnostic info (bad CRC, unknown ID, raw bytes)
- Enables monitoring and restart logic at application level

---

### Q3: Sample Data Capture Scope? ✅ RESOLVED
**Resolution**: Smart capture with validation criteria
- **Session 1 (indoor/no GPS)**: Record until heartbeat + ownship without GPS captured
- **Session 2 (outdoor/with GPS)**: Record until GPS acquired + 2-3 aircraft traffic received
- **Workflow**: Raw captures → parse → extract gold copies for test fixtures
- **Files**: Multiple scenario-specific fixtures (heartbeat_no_gps.bin, traffic_multiple_aircraft.bin, etc.)

---

### Q4: Multiple Concurrent Listeners Support? ⏸️ DEFERRED
**Resolution**: Single listener sufficient for MVP
- Can be added later if needed (doesn't affect core architecture)
- Use `reusePort: false` initially for simplicity

---

### Q5: Message Buffering and Flow Control? ✅ RESOLVED
**Resolution**: Dart Streams provide built-in backpressure
- Streams API choice (Q3) handles buffering naturally
- No additional queuing layer needed
- Streams support pause/resume for flow control

---

### Q6: ForeFlight Extensions Priority? ✅ RESOLVED
**Resolution**: Skip entirely (out of scope)
- SkyEcho has no AHRS hardware
- ForeFlight AHRS messages (ID 0x65) won't be transmitted
- Focus on core FAA GDL90 standard messages only
- Can be added in future if needed for other devices

---

### Q7: API Style - Callbacks vs Streams? ✅ RESOLVED
**Resolution**: Streams only (Dart Stream API)
- Idiomatic Dart/Flutter
- Async/await support
- Backpressure handling
- Natural StreamBuilder integration

---

### Q8: Research Document Implementation Approach? ✅ RESOLVED
**Resolution**: Hybrid approach
- **Copy directly**: CRC-16-CCITT algorithm (pre-validated), bit manipulation helpers
- **TDD from scratch**: Message parsers, framer, stream layer, public APIs
- **Use as validation**: Research code serves as "answer key" for TDD implementation

## Testing Strategy

**Approach**: Full TDD (Test-Driven Development)

**Rationale**: Binary protocol parsing with known FAA test vectors is ideal for TDD. Write tests first using ICD examples, then implement to pass. This ensures correctness from the start and leverages the stable, well-documented GDL90 specification.

**Focus Areas** (100% coverage required):
- **CRC-16-CCITT validation** - Critical for frame integrity; validate against ICD Appendix C test vectors
- **Byte framing and escaping** - 0x7E flags, 0x7D escape sequences
- **Message ID routing** - Correct dispatching to type-specific parsers
- **Binary field extraction** - Lat/lon semicircles, altitude offsets, bit-packed fields
- **All message types** - Heartbeat (0), Traffic (20), Ownship (10), HAT (9), Uplink (7), etc.
- **Error conditions** - Bad CRC, unknown message IDs, truncated frames, invalid field values

**Moderate Coverage** (90% minimum):
- **UDP/TCP transport layer** - Socket management, datagram handling
- **Stream lifecycle** - Start, stop, error callbacks
- **Integration paths** - End-to-end message flow from socket to parsed objects

**Excluded from Extensive Testing**:
- **Example CLI** - Manual verification sufficient
- **Documentation code snippets** - Covered by integration tests

**Mock Usage**: Targeted mocks only
- **Mock sockets** for unit tests (avoid actual network I/O)
- **Real binary fixtures** from captured device data (preferred over hand-crafted mocks)
- **No mocking** of parser internals (pure functions, easily testable)

**Test Development Workflow**:
1. **Red**: Write failing test with FAA test vector or captured fixture
2. **Green**: Implement minimal code to pass
3. **Refactor**: Clean up while maintaining green tests
4. **Document**: Add inline comments explaining bit manipulation and field mappings

## Documentation Strategy

**Location**: Hybrid (README.md + docs/how/)

**Rationale**: Package needs quick-start for immediate use, plus deep guides for binary protocol complexity and integration patterns.

**Content Split**:
- **Package README** (`packages/skyecho_gdl90/README.md`):
  - Installation (`dart pub add skyecho_gdl90` or path dependency)
  - 30-second quick start example
  - Basic usage (open UDP, parse messages, print traffic)
  - Link to detailed guides

- **Detailed Guides** (`docs/how/skyecho-gdl90/`):
  - Protocol details (GDL90 spec overview, message types)
  - Architecture (framer, decoder, transport separation)
  - Advanced usage (custom transports, error handling, performance)
  - Troubleshooting (CRC errors, network issues, fixture capture)
  - Testing guide (TDD workflow, binary fixtures, test vectors)

**Target Audience**:
- **README**: Dart/Flutter developers integrating GDL90 parsing (immediate value)
- **docs/how/**: Aviation developers, maintainers, contributors (deep understanding)

**Maintenance**: Update README for API changes; update docs/how/ for architecture changes, new message types, or troubleshooting patterns.

## Clarifications Summary

### Coverage Status

| Area | Status | Decision |
|------|--------|----------|
| **Testing Strategy** | ✅ Resolved | Full TDD with FAA test vectors |
| **Documentation** | ✅ Resolved | Hybrid (README + docs/how/) |
| **API Style** | ✅ Resolved | Dart Streams only |
| **Research Code** | ✅ Resolved | Hybrid (copy CRC, TDD rest) |
| **ForeFlight Extensions** | ✅ Resolved | Skip entirely (no AHRS) |
| **Sample Data Capture** | ✅ Resolved | Smart capture with timestamps |
| **Error Handling** | ✅ Resolved | Wrapper pattern with events |
| **Data Model** | ✅ Resolved | Single unified Gdl90Message |
| **iOS Features** | ✅ Resolved | Defer to future phase |
| **Platform Priority** | ✅ Resolved | CLI + macOS desktop first |
| **Multi-Listener** | ⏸️ Deferred | Single listener for MVP |
| **Flow Control** | ✅ Resolved | Streams built-in backpressure |

### Outstanding Items
None - all critical ambiguities resolved.

### Deferred to Future Phases
- iOS-specific features (background modes, permissions, power management)
- Multiple concurrent UDP listeners
- ForeFlight AHRS extensions (ID 0x65)

---

## Clarifications

### Session 2025-10-18

**Q1: Testing Strategy**
- **Answer**: A (Full TDD)
- **Rationale**: Binary protocol parser with known test vectors from FAA ICD is ideal for TDD. Write tests first using specification examples, then implement to pass.

**Q2: Documentation Strategy**
- **Answer**: C (Hybrid)
- **Content Split**:
  - README: Installation, 30-second quick start, basic usage example
  - docs/how/: Protocol details, architecture, advanced usage, troubleshooting

**Q3: API Style - Callbacks vs Streams**
- **Answer**: B (Streams only)
- **Rationale**: Streams are idiomatic Dart/Flutter, support async/await, provide backpressure handling, and integrate naturally with StreamBuilder widgets for UI.

**Q4: Research Document Implementation Approach**
- **Answer**: C (Hybrid)
- **Strategy**:
  - **Copy directly**: CRC-16-CCITT algorithm (validated against FAA spec), bit manipulation helpers
  - **TDD from scratch**: Message parsers, framer, stream layer, all public APIs
  - **Use research as validation**: Compare TDD implementation against research "answer key"

**Q5: ForeFlight Extensions Priority**
- **Answer**: Skip entirely (out of scope)
- **Rationale**: SkyEcho has no AHRS hardware, so ForeFlight AHRS messages (ID 0x65) won't be transmitted. Focus on core FAA GDL90 standard messages only.

**Q6: Sample Data Capture Scope**
- **Answer**: Smart capture with validation criteria (multiple recording sessions)
- **Criteria**:
  - Capture session 1 (indoor/no GPS): Record ground state without GPS fix
  - Capture session 2 (outdoor/with GPS): Record until GPS acquired + 2-3 aircraft received
  - Stop when validation criteria met (not time-based)
- **File Organization**: Two-stage workflow
  1. **Raw captures with timestamps** (named by user):
     - Format: Each datagram stored with microsecond timestamp
     - Files: `raw_indoor_2025-10-18.bin`, `raw_outdoor_flight.bin`, etc.
     - Enables accurate playback with original timing
  2. **Parsed & extracted gold copies**: Parse raw captures, extract relevant frames, save as test fixtures
     - `test/fixtures/heartbeat_no_gps.bin` - Extracted from raw indoor capture
     - `test/fixtures/ownship_with_gps.bin` - Extracted from raw outdoor capture
     - `test/fixtures/traffic_multiple_aircraft.bin` - Extracted traffic frames
     - Gold copies include timestamps for replay testing
     - Additional targeted fixtures for specific message types
- **Rationale**: Multiple recording sessions needed (indoor vs outdoor). Timestamps enable realistic playback for integration tests. Parse raw captures to create focused test fixtures with known-good message types. Raw captures can be discarded or archived after extraction.

**Q7: Error Handling Strategy & Data Model**
- **Answer**: B (Optional logging with wrapper pattern)
- **Implementation**:
  - Stream emits wrapper objects (e.g., `Gdl90Event`) containing either:
    - **Data**: Single unified `Gdl90Message` object (not multiple types)
    - **Error**: Diagnostic info (bad CRC, unknown ID, truncated frame, raw bytes)
  - Parser never throws exceptions for malformed frames
  - Caller receives all events and can choose to log/ignore/alert on errors
  - Enables monitoring: caller detects missing heartbeats and handles restart logic
- **Data Model**: Single `Gdl90Message` class
  - All possible fields present (heartbeat, traffic, ownship, uplink, etc.)
  - `messageType` field indicates which fields are populated
  - Nullable fields for optional data (e.g., `latitude?`, `callsign?`, `gpsStatus?`)
  - Larger object but simpler API - no type casting or pattern matching needed
- **Rationale**: Wrapper pattern encapsulates data + errors for transport. Single message type simplifies caller code and Flutter UI binding. Caller gets full visibility for debugging (development) while maintaining robustness (production). Aligns with Streams API choice.

**Q8: iOS Background Reception & Platform Priority**
- **Answer**: Defer iOS-specific features to future phase
- **MVP Focus**:
  - CLI tooling (capture utility, playback testing)
  - macOS desktop app compatibility
  - Pure Dart library (platform-agnostic core)
- **iOS Considerations Deferred**:
  - Background mode entitlements
  - Network permission handling
  - Power management optimizations
  - Platform-specific testing
- **Rationale**: Focus on core parser functionality and desktop tooling first. iOS integration happens later when Flutter app is ready. Parser library remains platform-agnostic.
