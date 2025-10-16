# SkyEcho 2 Device HTML Fixtures

**Capture Date**: 2025-10-17
**Device Model**: uAvionix SkyEcho 2

## Tested Firmware Versions
- **Wi-Fi Version**: 0.2.41-SkyEcho
- **ADS-B Version**: 2.6.13

**Note**: This library is tested against the firmware versions listed above. Other versions may work but are not guaranteed. Report compatibility issues via GitHub.

## Capture Method
- Landing page: `curl http://192.168.4.1/`
- Setup form: `curl http://192.168.4.1/setup`

## Device State During Capture
- GPS Fix: Unknown (indoor capture, device uses WebSocket for dynamic updates)
- Clients Connected: 1
- SSID: SkyEcho_3155
- Capture Conditions: Indoor development environment, server-rendered HTML captured before JavaScript execution

## Edge Cases and State Variations
**Note**: Initial capture targets server-rendered HTML structure (GPS 3D fix, normal operation, populated status values).
Edge case states will be documented as discovered during Phases 4-6 development:
- **Indoor No-GPS**: Common during development; status shows "N/A" or "Searching..." for position fields
- **2D Fix**: Fewer satellites, altitude unavailable
- **Multiple Clients**: May affect WiFi performance or displayed client count
- **Firmware Updates/Errors**: Avoid capturing during these states; recapture if needed

Document any edge cases encountered during development here for future reference.

## Notes
- Captured HTML represents server-rendered output (no JavaScript execution)
- Device uses WebSocket (`ws://192.168.4.1`) for dynamic status updates
- Static HTML contains table structure with placeholder values populated by JavaScript
- All form field types present in setup form: text, checkbox, radio, select
- Status table present with key/value pairs structure
