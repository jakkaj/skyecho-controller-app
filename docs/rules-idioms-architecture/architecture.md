# SkyEcho Controller Library - Architecture

**Version:** 1.0.0 (synced with [Constitution](constitution.md) v1.0.0)
**Last Updated:** 2025-10-16

This document describes the system's high-level structure, component boundaries, interaction contracts, and architectural decisions for the SkyEcho controller library.

---

## System Overview

The SkyEcho Controller Library is a **single-package Dart library** that enables programmatic control of uAvionix SkyEcho 2 devices through their built-in web interface. The library uses screen-scraping techniques (HTML parsing) to extract status information and submit configuration changes, since the device does not provide a REST API.

**Key Characteristics:**
- **Platform-agnostic**: Pure Dart code, no Flutter dependencies
- **Offline-testable**: Mock-friendly design for development without hardware
- **Defensive parsing**: Tolerates minor HTML variations with actionable errors
- **Type-safe API**: Leverages Dart's type system to prevent misuse

---

## Component Architecture

### Layer Diagram

```
┌────────────────────────────────────────────────────────┐
│            Client Application Layer                    │
│         (Flutter UI, CLI tools, scripts)              │
└────────────────────────────────────────────────────────┘
                        │
                        │ uses
                        ▼
┌────────────────────────────────────────────────────────┐
│          Public API Layer (lib/skyecho.dart)          │
│                                                        │
│  • SkyEchoClient (main entry point)                   │
│  • DeviceStatus (status model)                        │
│  • SetupUpdate (builder pattern)                      │
│  • Error types (exception hierarchy)                  │
└────────────────────────────────────────────────────────┘
                        │
                        │ coordinates
                        ▼
┌────────────────────────────────────────────────────────┐
│              Core Logic Layer                          │
│                                                        │
│  ┌─────────────────┐  ┌────────────────────────┐     │
│  │  HTTP Client    │  │   HTML Parser          │     │
│  │  • GET/POST     │  │   • DeviceStatus       │     │
│  │  • Cookie jar   │  │   • SetupForm          │     │
│  │  • Timeouts     │  │   • Field extraction   │     │
│  └─────────────────┘  └────────────────────────┘     │
└────────────────────────────────────────────────────────┘
                        │
                        │ depends on
                        ▼
┌────────────────────────────────────────────────────────┐
│          External Dependencies                         │
│                                                        │
│  • http package (HTTP client)                         │
│  • html package (DOM parsing)                         │
└────────────────────────────────────────────────────────┘
                        │
                        │ communicates with
                        ▼
┌────────────────────────────────────────────────────────┐
│        SkyEcho 2 Device (Hardware)                    │
│                                                        │
│  HTTP Server: http://192.168.4.1                      │
│  • GET  /       → Landing page with status            │
│  • GET  /setup  → Setup form with configuration       │
│  • POST /setup  → Apply configuration changes         │
└────────────────────────────────────────────────────────┘
```

### Component Responsibilities

#### 1. **SkyEchoClient** (Entry Point)
**Responsibility:** Orchestrate HTTP requests, manage session state (cookies), and expose high-level operations.

**Public Methods:**
- `ping()` - Quick availability check
- `fetchStatus()` - Retrieve device status
- `fetchSetupForm()` - Get current configuration form
- `applySetup(builder)` - Update configuration
- `clickApply()` - Re-submit current form

**Dependencies:**
- `http.Client` (configurable, defaults to standard client)
- `_CookieJar` (internal session management)
- Parser classes (`DeviceStatus`, `SetupForm`)

**Boundaries:**
- MUST NOT leak HTTP details to callers
- MUST convert HTTP/network errors to `SkyEchoError` types
- MAY inject custom `http.Client` for testing

#### 2. **DeviceStatus** (Status Model)
**Responsibility:** Parse and model the device's landing page status information.

**Structure:**
- Header fields: `wifiVersion`, `adsbVersion`, `ssid`, `clientsConnected`
- Status table: `Map<String, String>` of normalized key-value pairs
- Computed properties: `hasGpsFix`, `isSendingData`, `icao`, `callsign`, `gpsFix`

**Parsing Contract:**
- `static DeviceStatus fromDocument(dom.Document doc)` parses HTML
- Normalizes labels (lowercase, trim whitespace)
- Tolerates missing fields (returns nulls for header, empty map for table)
- Heuristic-based status detection (GPS fix, sending data)

**Boundaries:**
- MUST NOT make network calls
- SHOULD degrade gracefully on missing HTML elements
- MUST normalize field names consistently

#### 3. **SetupForm** (Configuration Form Model)
**Responsibility:** Parse the setup page form and model all interactive fields.

**Structure:**
- Form metadata: `method`, `action` (URL), `formElement`
- Field collection: `List<FormField>` (polymorphic)
- Field index: `Map<String, FormField>` for lookup

**Field Types:**
- `TextField` - Text/number inputs
- `CheckboxField` - Boolean checkboxes
- `RadioGroupField` - Radio button groups
- `SelectField` - Dropdown selects

**Parsing Contract:**
- `static SetupForm? parse(dom.Document doc, Uri base)` returns form or null
- Identifies form by presence of "Apply" submit button
- Infers labels from `<label for="...">` or previous `<td>` sibling
- Groups radio buttons by `name` attribute

**Boundaries:**
- MUST NOT execute JavaScript
- SHOULD support fuzzy label matching (contains, case-insensitive)
- MAY return null if form not found (caller handles error)

#### 4. **SetupUpdate** (Builder Pattern)
**Responsibility:** Provide type-safe, user-friendly API for configuration updates.

**Structure:**
- Typed fields: `icaoHex`, `callsign`, `enable1090ESTransmit`, `receiverMode`, etc.
- Escape hatch: `rawByFieldName` for unmapped fields

**Update Contract:**
- All fields optional (only set values are updated)
- Builder function pattern: `(u) => u..field = value`
- Maps high-level names to form fields via fuzzy label matching

**Boundaries:**
- MUST map to `FormField` instances for submission
- SHOULD throw `SkyEchoFieldError` if field not found or incompatible
- MAY support enums (`ReceiverMode`) and domain types

#### 5. **Error Hierarchy**
**Responsibility:** Provide actionable, domain-specific exceptions.

**Types:**
- `SkyEchoError` (base) - abstract with `message` and `hint`
- `SkyEchoNetworkError` - connection, timeout issues
- `SkyEchoHttpError` - HTTP status errors (4xx, 5xx)
- `SkyEchoParseError` - HTML parsing failures
- `SkyEchoFieldError` - form field mapping errors

**Contract:**
- All errors include actionable `hint` when possible
- Errors provide context (URLs, field names, expected values)
- Stack traces preserved from underlying exceptions

---

## Data Flow

### 1. Fetch Status Flow

```
User Code
   │
   │ await client.fetchStatus()
   ▼
SkyEchoClient
   │
   │ _get('/')
   ▼
HTTP Client
   │
   │ GET http://192.168.4.1/
   ▼
SkyEcho Device ──────► HTML Response
   │
   ▼
_Response.checkOk()
   │
   ▼
html.parse(utf8.decode(...))
   │
   ▼
DeviceStatus.fromDocument(doc)
   │
   │ • Parse header (versions, SSID)
   │ • Parse "Current Status" table
   │ • Compute derived properties
   ▼
DeviceStatus ────────► User Code
```

### 2. Apply Configuration Flow

```
User Code
   │
   │ await client.applySetup((u) => u..icaoHex = '7CC599')
   ▼
SkyEchoClient.applySetup(builder)
   │
   │ fetchSetupForm()
   ▼
SetupForm.parse(doc, base)
   │
   │ • Find form with "Apply" button
   │ • Extract all fields (text, checkbox, radio, select)
   │ • Build field index by label
   ▼
SetupForm
   │
   │ builder(update) → user callback
   ▼
SetupUpdate (mutated)
   │
   │ form.updatedWith(update)
   ▼
Field Mapping
   │
   │ • Fuzzy match labels to fields
   │ • Clone fields, apply updates
   │ • Encode to POST data
   ▼
FormPost (URL + data)
   │
   │ _submitForm(post)
   ▼
HTTP Client
   │
   │ POST http://192.168.4.1/setup
   ▼
SkyEcho Device ──────► 200 OK (or error)
   │
   ▼
ApplyResult ─────────► User Code
```

---

## Boundaries and Contracts

### External Boundaries

**Inbound:**
- User code calls public API (`SkyEchoClient` methods)
- Test code injects `MockClient` via constructor
- Integration tests target real device URL

**Outbound:**
- HTTP calls to SkyEcho device (port 80, no HTTPS)
- No database, no file I/O (except test fixtures)
- No external services or cloud APIs

### Internal Contracts

**SkyEchoClient → HTTP:**
- Client MUST manage cookies across requests
- Client MUST apply timeout to all requests
- Client MUST convert HTTP errors to `SkyEchoError`

**SkyEchoClient → Parsers:**
- Client provides complete HTML document
- Parsers return typed models or throw `SkyEchoParseError`
- Parsers MUST NOT retain references to DOM elements

**SetupForm → FormFields:**
- Form owns field lifecycle (create, clone, encode)
- Fields are cloned for updates (original immutable)
- Encoded fields produce `Map<String, String>` for POST

**Error Hierarchy:**
- All errors extend `SkyEchoError`
- Errors include `hint` for actionability
- Lower-level exceptions wrapped with context

### Testing Contracts

**Unit Tests:**
- HTTP layer mocked via `MockClient`
- Parsers tested with HTML fixtures
- No network I/O, no external dependencies
- Must run in < 5 seconds

**Integration Tests:**
- Real HTTP calls to device
- Gracefully skip if device unavailable
- Capture real HTML for updating fixtures
- Update sample data periodically

---

## Deployment Topology

### Library Packaging

```
skyecho-controller-app/
├── lib/
│   └── skyecho.dart          # Single library file (~600 lines)
├── test/
│   ├── fixtures/             # HTML sample data
│   ├── unit/                 # Offline tests
│   └── integration/          # Hardware tests
├── example/
│   └── main.dart             # Usage demonstration
└── pubspec.yaml              # Package metadata
```

**Deployment Targets:**
- Dart VM (command-line tools, scripts)
- Flutter (iOS, Android, macOS, Windows, Linux, Web)
- Web (requires CORS proxy for `http://192.168.4.1`)

**Platform Constraints:**
- Web platform cannot directly access `http://192.168.4.1` (CORS)
  - Requires proxy server or platform channel
  - Out of scope for initial release
- All other platforms supported natively

---

## Integration Points

### Device Communication

**Protocol:** HTTP/1.1 over TCP (no HTTPS)

**Endpoints:**
- `GET /` - Landing page with status (HTML)
- `GET /setup` - Setup form (HTML)
- `POST /setup` - Apply configuration (form-urlencoded)

**Session Management:**
- Cookies (Set-Cookie header) managed by `_CookieJar`
- No authentication required (local WiFi network only)

**Error Handling:**
- Timeouts (default 5s, configurable)
- Connection failures → `SkyEchoNetworkError`
- HTTP errors (4xx/5xx) → `SkyEchoHttpError`
- Malformed HTML → `SkyEchoParseError`

### Future GDL90 Integration (Placeholder)

**Not Implemented:**
- UDP/TCP socket for GDL90 stream
- Frame parsing and validation
- Traffic and weather message decoding

**Placeholder Types:**
- `Gdl90EndpointConfig` (host, port, transport)
- `Gdl90Transport` enum (udp, tcp)
- `Gdl90Stream` interface (start, stop, isRunning)

**Integration Contract (future):**
- Separate from HTTP control layer
- User code manages lifecycle
- Callback-based frame delivery

---

## Technology-Agnostic Design

### Core Abstractions

The library maintains technology-agnostic design through:

**1. Interface-based HTTP Client:**
```dart
// Accepts any http.Client implementation
SkyEchoClient(String baseUrl, {http.Client? httpClient})
```

**2. DOM-based Parsing:**
```dart
// Works with any dom.Document (testable with html package parser)
DeviceStatus.fromDocument(dom.Document doc)
```

**3. Pure Functions:**
```dart
// No side effects, easy to test
String _normLabel(String? s) => ...
bool _asBool(dynamic v) => ...
```

### Technology-Specific Notes

**Dart/Flutter Specifics:**
- Null safety (`String?`, `required`, `late`)
- Named constructors (`DeviceStatus.fromDocument`)
- Builder pattern with function callbacks
- Extension methods (`_FirstOrNull`)

**These patterns could be adapted to other languages:**
- TypeScript: Interfaces, optional properties, union types
- Python: Dataclasses, optional types, context managers
- C#: POCO classes, LINQ, nullable reference types

---

## Anti-Patterns and Reviewer Checklist

### Architectural Anti-Patterns to Avoid

**❌ Direct DOM Manipulation in Business Logic**
- Parsers should create immutable models, not retain DOM references

**❌ Stateful HTTP Client**
- Don't cache responses in SkyEchoClient (stateless request/response)
- Cookie management is OK (session state, not response caching)

**❌ Tight Coupling to HTML Structure**
- Use fuzzy label matching, not exact XPath queries
- Provide fallback strategies for finding elements

**❌ Synchronous Blocking Operations**
- All I/O must be async (`Future<T>` return types)

**❌ Global State**
- No static mutable state
- Each `SkyEchoClient` instance is independent

### Code Review Checklist

When reviewing changes to architecture:

**Boundary Violations:**
- [ ] Does a parser make HTTP calls? (should be SkyEchoClient's job)
- [ ] Does SkyEchoClient expose `http.Response`? (should return domain models)
- [ ] Do errors leak implementation details? (wrap in SkyEchoError)

**Contract Violations:**
- [ ] Does a public API change break backward compatibility?
- [ ] Are new exception types properly documented?
- [ ] Are new fields properly typed (`String?` vs `String`)?

**Testing Impact:**
- [ ] Can this be tested with MockClient?
- [ ] Does this require real hardware? (should be integration test)
- [ ] Are test fixtures updated if HTML structure changed?

**Documentation:**
- [ ] Are dartdoc comments updated for API changes?
- [ ] Is architecture.md updated if boundaries changed?
- [ ] Are examples updated if public API changed?

---

## Evolution and Extension

### Anticipated Changes

**Near-term:**
- Additional firmware version support (new HTML fixtures)
- More robust error recovery (retry logic, circuit breakers)
- Enhanced logging/diagnostics

**Medium-term:**
- GDL90 stream implementation
- Configuration profiles (save/load multiple setups)
- Firmware update support (if device supports)

**Long-term:**
- Multi-device management (fleet control)
- Cloud sync (configuration backup)
- Web platform support (with CORS proxy)

### Extension Points

**1. Custom HTTP Client:**
```dart
// For proxy, retry logic, or custom transports
final client = SkyEchoClient(
  'http://192.168.4.1',
  httpClient: MyCustomHttpClient(),
);
```

**2. Custom Parsing:**
```dart
// Subclass or wrap parsers for custom firmware
class CustomDeviceStatus extends DeviceStatus {
  static CustomDeviceStatus fromDocument(dom.Document doc) {
    // Custom parsing logic
  }
}
```

**3. Middleware Pattern (Future):**
```dart
// For logging, metrics, retry logic
final client = SkyEchoClient(url)
  ..addMiddleware(LoggingMiddleware())
  ..addMiddleware(RetryMiddleware(maxAttempts: 3));
```

### Deprecation Strategy

When evolving APIs:

1. Mark old API with `@Deprecated('Use newApi() instead')`
2. Keep old API functional for 1 major version
3. Document migration path in deprecation message
4. Remove in next major version (2.0.0)

---

**Related Documents:**
- [Constitution](constitution.md) - Guiding principles
- [Rules](rules.md) - Enforceable MUST/SHOULD standards
- [Idioms](idioms.md) - Dart patterns and conventions
