# Flutter Tactical Radar App

## Summary

A Flutter application that provides pilots with a tactical radar display of ADS-B traffic and device configuration capabilities. The app integrates the existing `skyecho` device control library and `skyecho_gdl90` GDL90 parsing library to create an interface for interacting with uAvionix SkyEcho 2 ADS-B receivers.

**Development Strategy**: Initial development targets macOS desktop for rapid iteration and testing, with subsequent deployment to iOS (iPhone and iPad) as the production target platform.

**User Value**: Pilots gain a portable tactical awareness tool that displays nearby aircraft traffic in real-time and allows configuration of their SkyEcho device without requiring external apps or web browsers.

## Goals

- **Cross-Platform Foundation**: Provide a Flutter app that runs on macOS desktop (development) and iOS (production) with consistent functionality
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

[NEEDS CLARIFICATION: Should the initial version support any state persistence, or can device settings and UI preferences be ephemeral?]

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
- Devices (macOS desktop during development, iOS in production) will connect to SkyEcho via WiFi (192.168.4.1)
- Both `skyecho` and `skyecho_gdl90` packages work correctly in Flutter context (not just Dart VM)
- macOS desktop provides sufficient development environment to validate all functionality before iOS deployment
- iOS deployment will target iPhone and iPad form factors

**Risks:**
- **Performance Risk**: Flutter UI updates from high-frequency GDL90 messages may cause dropped frames or lag
  - *Mitigation*: Implement message throttling/batching before UI updates
- **WiFi Connectivity Risk**: iOS WiFi handling (auto-switching to cellular, background disconnects) may disrupt SkyEcho connection; less of an issue on macOS desktop
  - *Mitigation*: Implement connection monitoring and auto-reconnect logic; validate behavior on both platforms
- **State Management Complexity**: Coordinating device state, stream state, and UI state across views may require careful architecture
  - *Mitigation*: Use established Flutter state management pattern (Riverpod, Bloc, etc.) from start
- **Testing Without Hardware**: Development/testing requires either physical SkyEcho device or comprehensive mocking
  - *Mitigation*: Leverage existing mock infrastructure from `skyecho` and `skyecho_gdl90` packages

## Open Questions

1. **Platform Priority**: ~~Which mobile platform should be targeted first - iOS, Android, or both simultaneously?~~ **RESOLVED**: macOS desktop for development, then iOS (iPhone/iPad) for production.

2. **Minimum OS Versions**: What are the minimum supported OS versions? (iOS 15+? iOS 16+? macOS 12+?) [NEEDS CLARIFICATION]

3. **Background Operation**: Should the app continue receiving GDL90 data when backgrounded, or suspend the stream? [NEEDS CLARIFICATION]

4. **State Persistence**: Should device connection settings, zoom level, and other UI preferences be persisted between app sessions? [NEEDS CLARIFICATION]

5. **Ownship Position Source**: How is ownship (user's aircraft) position determined? From GDL90 ownship messages only, or also device GPS if available? [NEEDS CLARIFICATION]

6. **Traffic Filtering**: Should the radar view have any traffic filtering options (altitude range, distance cutoff) in Phase 1, or display all received traffic? [NEEDS CLARIFICATION]

7. **Orientation Handling**: Should the radar display support device rotation/orientation changes, or lock to a single orientation? [NEEDS CLARIFICATION]

8. **Network Permissions**: Are there specific privacy/permission requirements for WiFi network access on iOS? (macOS has fewer restrictions for local network access) [NEEDS CLARIFICATION]

9. **Desktop UI Considerations**: Should the macOS desktop version have any platform-specific UI adaptations (keyboard shortcuts, menu bar), or maintain exact parity with iOS touch interface? [NEEDS CLARIFICATION]

---

**Next Step**: Run `/plan-2-clarify` to resolve high-impact open questions before architecture phase.
