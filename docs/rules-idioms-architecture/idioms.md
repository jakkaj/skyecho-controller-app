# SkyEcho Controller Library - Idioms

**Version:** 1.0.0 (synced with [Constitution](constitution.md) v1.0.0)
**Last Updated:** 2025-10-16

This document captures recurring patterns, conventions, and Dart-specific idioms used throughout the SkyEcho library. These are illustrative examples and recommended practices that complement the enforceable rules.

---

## Dart Language Idioms

### Constructor Patterns

**Named constructors for parsing:**
```dart
class DeviceStatus {
  DeviceStatus({
    required this.wifiVersion,
    required this.adsbVersion,
    // ... fields
  });

  // Named constructor for parsing
  static DeviceStatus fromDocument(dom.Document doc) {
    // Parsing logic here
  }
}
```

**Private constructors with factory pattern:**
```dart
class SetupForm {
  SetupForm._({
    required this.method,
    required this.action,
    required this.fields,
  });

  // Public factory that does validation
  factory SetupForm.parse(dom.Document doc, Uri base) {
    // Parsing and validation
    return SetupForm._(method: m, action: a, fields: f);
  }
}
```

### Immutability Patterns

**Use `final` for immutable fields:**
```dart
class DeviceStatus {
  final String? wifiVersion;
  final String? adsbVersion;
  final Map<String, String> current;
}
```

**Mutable builder pattern for updates:**
```dart
class SetupUpdate {
  String? icaoHex;
  String? callsign;
  bool? enable1090ESTransmit;
  // ... mutable fields for building
}

// Usage:
await client.applySetup((u) => u
  ..icaoHex = '7CC599'
  ..callsign = '9954');
```

### Null Safety Patterns

**Nullable return types with `?`:**
```dart
String? get icao => current['icao address'];
```

**Null-aware operators:**
```dart
final gpsFix = current['gps fix']?.toLowerCase() ?? '';
bool get hasGpsFix => gpsFix.isNotEmpty && gpsFix != 'none';
```

**Late initialization when guaranteed:**
```dart
// Only when you know it will be initialized before use
late final Uri _base;
```

### Extension Methods

**Custom utility extensions (when needed):**
```dart
extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;

  E? firstWhereOrNull(bool Function(E) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
```

---

## Error Handling Idioms

### Custom Exception Hierarchy

**Base exception with hints:**
```dart
abstract class SkyEchoError implements Exception {
  SkyEchoError(this.message, {this.hint});

  final String message;
  final String? hint;

  @override
  String toString() => hint == null ? message : '$message\nHint: $hint';
}
```

**Specific exception types:**
```dart
class SkyEchoParseError extends SkyEchoError {
  SkyEchoParseError(super.message, {super.hint});
}

class SkyEchoFieldError extends SkyEchoError {
  SkyEchoFieldError(super.message, {super.hint});
}
```

**Throwing with actionable hints:**
```dart
if (form == null) {
  throw SkyEchoParseError(
    'Could not find the Setup <form> with an "Apply" submit button.',
    hint: 'Ensure you are on the /setup page. If the device HTML changed, '
          'inspect the page and adjust [SetupForm.parseQuery] mappings.',
  );
}
```

### Wrapping Lower-Level Exceptions

**Catch and re-throw with context:**
```dart
try {
  final response = await _http.get(url);
} on SocketException catch (e) {
  throw SkyEchoNetworkError(
    'Failed to connect to SkyEcho at $url',
    hint: 'Ensure device is powered on and you are connected to its WiFi network.',
  );
} on TimeoutException {
  throw SkyEchoNetworkError('Request to $url timed out after $_timeout');
}
```

---

## HTTP & Networking Idioms

### Cookie Jar Pattern

**Simple cookie persistence:**
```dart
class _CookieJar {
  final Map<String, String> _cookies = {};

  void ingest(http.Response r) {
    final sc = r.headers['set-cookie'];
    if (sc == null) return;
    // Parse and store cookies
  }

  Map<String, String> toHeader() =>
      _cookies.isEmpty ? {} : {'cookie': _cookies.entries.map(...).join('; ')};
}
```

### Response Wrapper

**Extension methods on responses:**
```dart
class _Response {
  _Response(this.inner);
  final http.Response inner;

  int get statusCode => inner.statusCode;

  void checkOk() {
    if (statusCode != 200) {
      throw SkyEchoHttpError('HTTP $statusCode from ${inner.request?.url}.');
    }
  }
}
```

### Timeout Handling

**Future timeout with custom error:**
```dart
final response = await _http
    .get(url, headers: headers)
    .timeout(_timeout, onTimeout: () {
      throw SkyEchoNetworkError('GET $url timed out.');
    });
```

---

## HTML Parsing Idioms

### Defensive Parsing

**Try multiple strategies:**
```dart
dom.Element? table;
if (anchor != null) {
  table = anchor.nextElementSibling;
  if (table?.localName != 'table') {
    // Walk forward to find table
    var n = anchor;
    for (int i = 0; i < 4 && n != null; i++) {
      n = n.nextElementSibling;
      if (n?.localName == 'table') {
        table = n;
        break;
      }
    }
  }
}
table ??= doc.querySelector('table'); // Fallback
```

### Label Normalization

**Consistent label matching:**
```dart
String _normLabel(String? s) =>
    (s ?? '').replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
```

**Fuzzy matching:**
```dart
List<FormField> find(String human) {
  final key = _normLabel(human);
  if (byLabel.containsKey(key)) return byLabel[key]!;

  // Fuzzy: contains match
  for (final entry in byLabel.entries) {
    if (entry.key.contains(key)) return entry.value;
  }
  return [];
}
```

### Form Field Extraction

**Collecting form fields:**
```dart
final fields = <FormField>[];

for (final e in form.querySelectorAll('input')) {
  final type = (e.attributes['type'] ?? 'text').toLowerCase();
  final name = e.attributes['name'] ?? '';
  if (name.isEmpty) continue;

  switch (type) {
    case 'checkbox':
      fields.add(CheckboxField(...));
      break;
    case 'radio':
      // Handle radio groups
      break;
    default:
      fields.add(TextField(...));
  }
}
```

---

## Testing Idioms

### Test Doc Comment Block Format

**Standard format for Dart tests:**
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
  final html = '''
    <html><body>
      Wi-Fi Version: 0.2.41-SkyEcho
      <h3>Current Status</h3>
      <table>
        <tr><td>ICAO Address</td><td>ABC123</td></tr>
      </table>
    </body></html>
  ''';
  final doc = htmlParser.parse(html);

  // Act
  final status = DeviceStatus.fromDocument(doc);

  // Assert
  expect(status.wifiVersion, equals('0.2.41-SkyEcho'));
  expect(status.current['icao address'], equals('ABC123'));
});
```

### Arrange-Act-Assert Pattern

**Clear test phases:**
```dart
test('description', () {
  // Arrange - Setup test data
  final client = SkyEchoClient('http://test');
  final mockResponse = MockResponse(statusCode: 200, body: htmlFixture);

  // Act - Execute the code under test
  final result = await client.fetchStatus();

  // Assert - Verify expectations
  expect(result.ssid, equals('SkyEcho_3155'));
  expect(result.hasGpsFix, isTrue);
});
```

### Fixture Loading Pattern

**Load test data from files:**
```dart
String loadFixture(String filename) {
  final file = File('test/fixtures/$filename');
  return file.readAsStringSync();
}

// Usage:
final landingPageHtml = loadFixture('landing_page_sample.html');
final setupFormHtml = loadFixture('setup_form_sample.html');
```

### Mock Client Pattern

**Testing HTTP without network:**
```dart
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

final mockClient = MockClient((request) async {
  if (request.url.path == '/') {
    return http.Response(landingPageHtml, 200);
  }
  if (request.url.path == '/setup') {
    return http.Response(setupFormHtml, 200);
  }
  return http.Response('Not Found', 404);
});

final client = SkyEchoClient('http://test', httpClient: mockClient);
```

### Integration Test Skip Pattern

**Graceful skip when hardware unavailable:**
```dart
Future<bool> canReachDevice(String url) async {
  try {
    final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 2));
    return response.statusCode == 200;
  } catch (_) {
    return false;
  }
}

void main() {
  test('ping real device', skip: !await canReachDevice('http://192.168.4.1'), () async {
    // Integration test code
  });
}
```

---

## Builder Pattern Idioms

### Cascade Operator for Fluent Updates

**Using `..` for multiple assignments:**
```dart
await client.applySetup((u) => u
  ..icaoHex = '7CC599'
  ..callsign = '9954'
  ..enable1090ESTransmit = true
  ..receiverMode = ReceiverMode.es1090
  ..vfrSquawk = 1200);
```

**Builder pattern implementation:**
```dart
Future<ApplyResult> applySetup(void Function(SetupUpdate u) build) async {
  final form = await fetchSetupForm();
  final update = SetupUpdate();
  build(update);  // Let caller configure update via cascades
  final post = form.updatedWith(update);
  return await _submitForm(post);
}
```

---

## Enum Patterns

### Enums with Wire Values

**Mapping display to protocol values:**
```dart
enum ReceiverMode {
  uat('UAT', wireValue: 'UAT'),
  flarmEu('FLARM (EU ONLY)', wireValue: 'FLARM'),
  es1090('1090ES', wireValue: '1090ES');

  const ReceiverMode(this.display, {required this.wireValue});
  final String display;
  final String wireValue;
}

// Usage:
if (u.receiverMode != null) {
  _setRadio(find('receiver mode'), u.receiverMode!.wireValue);
}
```

---

## File Organization Patterns

### Directory Structure

```
skyecho-controller-app/
├── lib/
│   └── skyecho.dart          # Main library export
├── test/
│   ├── fixtures/             # Sample HTML, responses
│   │   ├── landing_page_sample.html
│   │   └── setup_form_sample.html
│   ├── unit/                 # Unit tests with Test Docs
│   │   └── skyecho_test.dart
│   ├── integration/          # Hardware-dependent tests
│   │   └── device_smoke_test.dart
│   └── scratch/              # Temp probes (gitignored)
├── example/
│   └── main.dart             # Usage example
├── docs/
│   ├── plans/                # Feature specs
│   └── rules-idioms-architecture/
├── memory/
│   └── constitution.md
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
```

### Import Organization

**Group imports by type:**
```dart
// Dart SDK imports
import 'dart:async';
import 'dart:convert';

// Package imports
import 'package:http/http.dart' as http;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

// Relative imports (if splitting library into files)
import 'src/models.dart';
```

---

## Documentation Idioms

### Dartdoc Comments

**Public API documentation:**
```dart
/// Top-level client to control a SkyEcho via its non-REST HTML web UI.
///
/// Example:
/// ```dart
/// final client = SkyEchoClient('http://192.168.4.1');
/// if (await client.ping()) {
///   final status = await client.fetchStatus();
///   print('GPS Fix: ${status.gpsFix}');
/// }
/// ```
class SkyEchoClient {
  /// Creates a client targeting [baseUrl] (e.g., 'http://192.168.4.1').
  ///
  /// Optionally accepts a custom [httpClient] for testing and [timeout]
  /// for request duration limits.
  SkyEchoClient(String baseUrl, {http.Client? httpClient, Duration timeout});
}
```

**Parameter and return documentation:**
```dart
/// Fetch and parse the Setup page form.
///
/// Returns a [SetupForm] containing all parsed form fields.
///
/// Throws [SkyEchoHttpError] if the request fails.
/// Throws [SkyEchoParseError] if the form cannot be found.
Future<SetupForm> fetchSetupForm() async { ... }
```

---

## Deprecation and Evolution

### Marking Deprecated APIs

**Using `@Deprecated` annotation:**
```dart
@Deprecated('Use fetchStatus() instead. Will be removed in v2.0.0')
Future<DeviceStatus> getStatus() => fetchStatus();
```

### Future Placeholders

**Documenting unimplemented features:**
```dart
/// Placeholder for a potential "Reset to defaults".
///
/// Many units implement reset via JS (not a simple POST). We expose the
/// method so your app UI can offer it; if the device has a submit control
/// for it, add a small selector in [SetupForm.parse] to capture it.
Future<void> resetToDefaults() async {
  throw UnimplementedError(
    'Reset to defaults is not wired because most SkyEcho firmwares do it '
    'via JavaScript, not a form POST.',
  );
}
```

---

## Common Anti-Patterns to Avoid

### ❌ Ignoring Null Safety

```dart
// Bad: Non-null assertion without validation
String icao = current['icao address']!;

// Good: Nullable type with safe access
String? icao = current['icao address'];
```

### ❌ Mutable Public Collections

```dart
// Bad: Mutable map can be modified externally
final Map<String, String> current;

// Better: Use UnmodifiableMapView if truly immutable needed
final Map<String, String> current = UnmodifiableMapView(_internalMap);

// Acceptable: Document that map is mutable
final Map<String, String> current; // Note: modifiable
```

### ❌ Catching Generic Exceptions

```dart
// Bad: Swallows all errors
try {
  await client.ping();
} catch (e) {
  return false;
}

// Good: Catch specific exceptions, let unexpected ones propagate
try {
  await client.ping();
} on SkyEchoNetworkError {
  return false;
} on SkyEchoHttpError {
  return false;
}
```

### ❌ Hardcoded Paths/URLs

```dart
// Bad: Hardcoded device URL
final client = SkyEchoClient('http://192.168.4.1');

// Good: Accept as parameter or config
final client = SkyEchoClient(config.deviceUrl);
```

---

**Related Documents:**
- [Constitution](constitution.md) - Guiding principles
- [Rules](rules.md) - Enforceable MUST/SHOULD standards
- [Architecture](architecture.md) - System structure and boundaries
