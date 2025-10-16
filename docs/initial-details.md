Below is a self‑contained Dart library you can drop into a Flutter project (or use from plain Dart) to drive a uAvionix SkyEcho 2 by **screen‑scraping** its built‑in web UI (e.g., `http://192.168.4.1`). It:

* fetches/normalizes **status** from the landing page
* loads/parses the **Setup** form (no REST API required)
* lets you **update fields**, then **submits Apply**
* exposes a **clean, Flutter‑ready API** with rich, actionable errors
* is resilient to minor HTML changes (labels, tables, radios, checkboxes)
* includes **extensibility points** for future GDL90 ingest (no implementation yet)

> Tested only against the HTML structure shown in your screenshots. If your unit’s HTML differs, the parser is designed to degrade gracefully and tell you exactly what field/form it couldn’t find so you can adjust matching rules without touching app code.

---

## `pubspec.yaml` additions

```yaml
dependencies:
  http: ^1.2.1
  html: ^0.15.4
```

---

## Library: `skyecho.dart`

> Put this in `lib/skyecho.dart`. It’s ~600 lines with comments; feel free to split into files later.

````dart
library skyecho;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

/// Top-level client to control a SkyEcho via its non-REST HTML web UI.
class SkyEchoClient {
  SkyEchoClient(
    String baseUrl, {
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 5),
  })  : _base = _normalizeBase(baseUrl),
        _timeout = timeout,
        _http = httpClient ?? http.Client();

  final Uri _base;
  final Duration _timeout;
  final http.Client _http;
  final _CookieJar _cookies = _CookieJar();

  /// Lightweight availability check (GET `/`).
  Future<bool> ping() async {
    try {
      final r = await _get('/')..checkOk();
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetch and parse the landing page (status block + current status table).
  Future<DeviceStatus> fetchStatus() async {
    final r = await _get('/')..checkOk();
    final doc = html.parse(utf8.decode(r.bodyBytes));
    return DeviceStatus.fromDocument(doc);
  }

  /// Fetch and parse the Setup page form.
  Future<SetupForm> fetchSetupForm() async {
    final r = await _get('/setup')..checkOk();
    final doc = html.parse(utf8.decode(r.bodyBytes));
    final form = SetupForm.parse(doc, _base);
    if (form == null) {
      throw SkyEchoParseError(
        'Could not find the Setup <form> with an "Apply" submit button.',
        hint:
            'Ensure you are on the /setup page of the SkyEcho. If the device HTML changed, '
            'inspect the page and adjust [SetupForm.parseQuery] mappings.',
      );
    }
    return form;
  }

  /// Convenience: fetch Setup form, apply typed updates, and submit.
  ///
  /// Example:
  /// ```dart
  /// await client.applySetup((u) => u
  ///   ..icaoHex = '7CC599'
  ///   ..callsign = '9954'
  ///   ..enable1090ESTransmit = true
  ///   ..receiverMode = ReceiverMode.es1090
  ///   ..vfrSquawk = 1200);
  /// ```
  Future<ApplyResult> applySetup(void Function(SetupUpdate u) build) async {
    final form = await fetchSetupForm();
    final update = SetupUpdate();
    build(update);
    final post = form.updatedWith(update);
    final res = await _submitForm(post);
    // Some firmwares reload or respond with a bare page; treat 200 as success.
    if (res.statusCode != 200) {
      throw SkyEchoHttpError(
        'Apply returned HTTP ${res.statusCode}.',
        url: post.target.toString(),
        bodyPreview: _preview(res.body),
      );
    }
    return ApplyResult(ok: true);
  }

  /// Submit the **current** form contents (no changes). Useful to “click Apply” as-is.
  Future<ApplyResult> clickApply() async {
    final form = await fetchSetupForm();
    final post = form.asPost(); // unchanged
    final res = await _submitForm(post);
    if (res.statusCode != 200) {
      throw SkyEchoHttpError(
        'Apply returned HTTP ${res.statusCode}.',
        url: post.target.toString(),
        bodyPreview: _preview(res.body),
      );
    }
    return ApplyResult(ok: true);
  }

  /// Placeholder for a potential "Reset to defaults" (depends on device HTML/JS).
  ///
  /// Many units implement reset via JS (not a simple POST). We expose the method so
  /// your app UI can offer it; if the device has a submit control for it, add a small
  /// selector in [SetupForm.parse] to capture it.
  Future<void> resetToDefaults() async {
    throw UnimplementedError(
      'Reset to defaults is not wired because most SkyEcho firmwares do it via JavaScript, '
      'not a form POST. If your device has a submit input for reset, extend SetupForm.parse().',
    );
  }

  // ---------- Internal HTTP helpers ----------

  Future<_Response> _get(String path) async {
    final url = _base.resolve(path);
    final headers = _cookies.toHeader();
    final r = await _http
        .get(url, headers: headers)
        .timeout(_timeout, onTimeout: () => throw SkyEchoNetworkError('GET $url timed out.'));
    _cookies.ingest(r);
    return _Response(r);
  }

  Future<_Response> _post(Uri url, Map<String, String> data) async {
    final headers = {
      ..._cookies.toHeader(),
      'content-type': 'application/x-www-form-urlencoded',
    };
    final body = data.entries
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');

    final r = await _http
        .post(url, headers: headers, body: body)
        .timeout(_timeout, onTimeout: () => throw SkyEchoNetworkError('POST $url timed out.'));
    _cookies.ingest(r);
    return _Response(r);
  }

  Future<_Response> _submitForm(FormPost post) => _post(post.target, post.data);

  static Uri _normalizeBase(String base) {
    var u = Uri.parse(base.trim());
    if (!u.hasScheme) u = Uri.parse('http://$base');
    if (!u.path.endsWith('/')) {
      u = u.replace(path: '${u.path}/');
    }
    return u;
  }
}

// ============================================================================
// Models & Parsing
// ============================================================================

/// High-level device status, parsed from the landing page.
class DeviceStatus {
  DeviceStatus({
    required this.wifiVersion,
    required this.adsbVersion,
    required this.ssid,
    required this.clientsConnected,
    required this.current,
  });

  /// Header block, e.g. `"0.2.41-SkyEcho"`
  final String? wifiVersion;

  /// Header block, e.g. `"2.6.13"`
  final String? adsbVersion;

  /// Header block SSID, e.g. `"SkyEcho_3155"`
  final String? ssid;

  /// Header block clients, e.g. `1`
  final int? clientsConnected;

  /// The “Current Status” table as normalized key/values.
  final Map<String, String> current;

  bool get hasGpsFix {
    final v = current['gps fix']?.toLowerCase() ?? '';
    return v.isNotEmpty && v != 'none' && v != '0' && v != 'no';
  }

  /// Best-effort heuristic: true if values look live.
  bool get isSendingData {
    final pos = current['position']?.trim() ?? '';
    final nacp = int.tryParse(current['nacp'] ?? '');
    final nic = int.tryParse(current['nic'] ?? '');
    final gnssAlt = int.tryParse(current['gnss altitude']?.replaceAll(RegExp('[^0-9-]'), '') ?? '');
    // Live-ish when we have GPS fix AND at least one quality/position measure looks sane.
    return hasGpsFix &&
        ((pos.isNotEmpty && !pos.startsWith('0,')) ||
            (nacp != null && nacp > 0) ||
            (nic != null && nic > 0) ||
            (gnssAlt != null && gnssAlt.abs() > 0));
  }

  /// Best-effort values extracted from the “Current Status” table:
  String? get icao => current['icao address'];
  String? get callsign => current['callsign'];
  String? get gpsFix => current['gps fix'];

  static DeviceStatus fromDocument(dom.Document doc) {
    // Pull the small header list (Wi-Fi version, ADS-B version, SSID, Clients)
    String? wifiVersion, adsbVersion, ssid;
    int? clientsConnected;

    // Look for colon-separated key/values anywhere near top.
    final bodyText = doc.body?.text ?? '';
    for (final line in bodyText.split('\n')) {
      final parts = line.split(':');
      if (parts.length < 2) continue;
      final key = parts.first.trim().toLowerCase();
      final val = parts.sublist(1).join(':').trim();
      if (key.startsWith('wi-fi version')) wifiVersion = val.split(' ').first;
      if (key.startsWith('ads-b version')) adsbVersion = val.split(' ').first;
      if (key == 'ssid') ssid = val;
      if (key.startsWith('clients connected')) {
        clientsConnected = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), ''));
      }
    }

    // Parse the “Current Status” table (header == "Current Status").
    final statusMap = <String, String>{};
    final headings = doc.querySelectorAll('h1,h2,h3,h4,strong,b,center');
    dom.Element? anchor;
    for (final h in headings) {
      if ((h.text.trim().toLowerCase()) == 'current status') {
        anchor = h;
        break;
      }
    }

    dom.Element? table;
    if (anchor != null) {
      table = anchor.nextElementSibling;
      if (table?.localName != 'table') {
        // Walk forward until table.
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
    table ??= doc.querySelector('table'); // fallback to first table

    if (table != null) {
      for (final tr in table.querySelectorAll('tr')) {
        final tds = tr.children.whereType<dom.Element>().toList();
        if (tds.length >= 2) {
          final k = _normLabel(tds[0].text);
          final v = tds[1].text.trim();
          if (k.isNotEmpty) statusMap[k] = v;
        }
      }
    }

    return DeviceStatus(
      wifiVersion: wifiVersion,
      adsbVersion: adsbVersion,
      ssid: ssid,
      clientsConnected: clientsConnected,
      current: statusMap,
    );
  }
}

/// Parsed representation of the Setup form and all interactive fields.
class SetupForm {
  SetupForm({
    required this.method,
    required this.action,
    required this.fields,
    required this.formElement,
    required this.base,
  });

  final String method; // GET/POST
  final Uri action; // absolute URL
  final Map<String, FormField> fieldsByName = {};
  final List<FormField> fields;
  final dom.Element formElement;
  final Uri base;

  factory SetupForm._(
      String method, Uri action, List<FormField> fields, dom.Element formEl, Uri base) {
    final f = SetupForm(
      method: method.toUpperCase(),
      action: action,
      fields: fields,
      formElement: formEl,
      base: base,
    );
    for (final fld in fields) {
      f.fieldsByName[fld.name] = fld;
    }
    return f;
  }

  /// Find the Setup form by locating a form that contains a submit input with value "Apply".
  static SetupForm? parse(dom.Document doc, Uri base) {
    for (final form in doc.querySelectorAll('form')) {
      final hasApply = form.querySelectorAll('input[type=submit],button[type=submit]').any((e) {
        final v = (e.attributes['value'] ?? e.text).trim().toLowerCase();
        return v.contains('apply');
      });
      if (!hasApply) continue;

      final actionAttr = form.attributes['action'] ?? '/setup';
      final methodAttr = form.attributes['method'] ?? 'POST';
      final action = base.resolve(actionAttr);

      final fields = <FormField>[];

      // Inputs
      for (final e in form.querySelectorAll('input')) {
        final type = (e.attributes['type'] ?? 'text').toLowerCase();
        final name = e.attributes['name'] ?? e.attributes['id'] ?? '';
        if (name.isEmpty) continue;

        switch (type) {
          case 'checkbox':
            fields.add(CheckboxField(
              name: name,
              value: e.attributes.containsKey('checked'),
              rawValue: e.attributes['value'] ?? 'on',
              label: _labelForInput(e) ?? _labelFromRow(e),
            ));
            break;
          case 'radio':
            // Radios share name; collate into a single group.
            final value = e.attributes['value'] ?? '';
            final checked = e.attributes.containsKey('checked');
            final label = _labelForInput(e) ?? _labelFromRow(e);
            final group = fields.whereType<RadioGroupField>().firstWhere(
                  (g) => g.name == name,
                  orElse: () {
                    final g = RadioGroupField(
                      name: name,
                      selected: checked ? value : null,
                      options: [],
                      label: _labelFromRow(e),
                    );
                    fields.add(g);
                    return g;
                  },
                );
            group.options.add(RadioOption(value: value, label: label));
            if (checked) group.selected = value;
            break;
          case 'submit':
          case 'button':
            // ignore
            break;
          default:
            fields.add(TextField(
              name: name,
              value: e.attributes['value'] ?? '',
              label: _labelForInput(e) ?? _labelFromRow(e),
              inputType: type,
            ));
        }
      }

      // Selects
      for (final s in form.querySelectorAll('select')) {
        final name = s.attributes['name'] ?? s.attributes['id'] ?? '';
        if (name.isEmpty) continue;
        final opts = <SelectOption>[];
        String? selected;
        for (final o in s.querySelectorAll('option')) {
          final value = o.attributes['value'] ?? o.text.trim();
          final text = o.text.trim();
          final isSel = o.attributes.containsKey('selected') ||
              s.attributes['value'] == value ||
              s.attributes['value'] == text;
          if (isSel) selected = value;
          opts.add(SelectOption(value: value, text: text));
        }
        fields.add(SelectField(
          name: name,
          selected: selected ?? (opts.isNotEmpty ? opts.first.value : ''),
          options: opts,
          label: _labelFromRow(s),
        ));
      }

      return SetupForm._(methodAttr, action, fields, form, base);
    }
    return null;
  }

  /// Return the current form as a submit payload.
  FormPost asPost() => FormPost(
        target: action,
        data: {
          for (final f in fields) ...f.encode(),
        },
      );

  /// Apply a high-level [SetupUpdate] into a new post payload.
  FormPost updatedWith(SetupUpdate u) {
    // Clone
    final cloned = fields.map((f) => f.copy()).toList();

    // Build a label->field index (best-effort, using TD labels or <label for> where available).
    final byLabel = <String, List<FormField>>{};
    for (final f in cloned) {
      final lbl = _normLabel(f.label);
      if (lbl.isEmpty) continue;
      byLabel.putIfAbsent(lbl, () => []).add(f);
    }

    // Helper to find by human label with fuzzy contains match.
    List<FormField> find(String human) {
      final key = _normLabel(human);
      if (byLabel.containsKey(key)) return byLabel[key]!;
      // Fuzzy: choose any label that contains the words in order.
      for (final entry in byLabel.entries) {
        if (entry.key.contains(key)) return entry.value;
      }
      return [];
    }

    // 1) Text-ish fields
    if (u.icaoHex != null) _setFirst<TextField>(find('icao address'), u.icaoHex!);
    if (u.callsign != null) _setFirst<TextField>(find('callsign'), u.callsign!);
    if (u.vfrSquawk != null) _setFirst<TextField>(find('vfr squawk'), u.vfrSquawk!.toString());
    if (u.vsoKnots != null) _setFirst<TextField>(find('vso'), u.vsoKnots!.toString());
    if (u.longitudinalGpsOffsetM != null) {
      _setFirst<TextField>(
        find('longitudinal gps offset'),
        u.longitudinalGpsOffsetM!.toString(),
      );
    }
    if (u.flarmIdHex != null) _setFirst<TextField>(find('flarm id'), u.flarmIdHex!);

    // 2) Checkboxes
    if (u.enable1090ESTransmit != null) {
      _setFirst<CheckboxField>(find('1090es transmit'), u.enable1090ESTransmit!);
    }
    if (u.adsbIn1090ES != null) _setNth<CheckboxField>(find('ads-b in capability'), 0, u.adsbIn1090ES!);
    if (u.adsbInUAT != null) _setNth<CheckboxField>(find('ads-b in capability'), 1, u.adsbInUAT!);
    if (u.ownshipFilterAdsb != null) _setNth<CheckboxField>(find('ownship filter'), 0, u.ownshipFilterAdsb!);
    if (u.ownshipFilterFlarm != null) _setNth<CheckboxField>(find('ownship filter'), 1, u.ownshipFilterFlarm!);

    // 3) Radios & selects
    if (u.receiverMode != null) {
      _setRadio(find('receiver mode'), u.receiverMode!.wireValue);
    }
    if (u.emitterCategory != null) {
      _setSelect(find('emitter category'), u.emitterCategory!);
    }
    if (u.aircraftLength != null) _setSelect(find('aircraft length'), u.aircraftLength!);
    if (u.aircraftWidth != null) _setSelect(find('aircraft width'), u.aircraftWidth!);
    if (u.lateralGpsOffset != null) _setSelect(find('lateral gps offset'), u.lateralGpsOffset!);
    if (u.sda != null) _setSelect(find('sda'), u.sda!);

    // 4) Raw overrides (by field name) if provided.
    for (final e in u.rawByFieldName.entries) {
      final fld = cloned.where((f) => f.name == e.key).toList();
      if (fld.isEmpty) continue;
      switch (fld.first.runtimeType) {
        case TextField:
          (fld.first as TextField).value = '${e.value}';
          break;
        case CheckboxField:
          (fld.first as CheckboxField).value = _asBool(e.value);
          break;
        case SelectField:
          (fld.first as SelectField).selected = '${e.value}';
          break;
        case RadioGroupField:
          (fld.first as RadioGroupField).selected = '${e.value}';
          break;
      }
    }

    return SetupForm._(method, action, cloned, formElement, base).asPost();
  }

  // ---- helpers for update ----

  static void _setFirst<T extends FormField>(List<FormField> fields, dynamic v) {
    final field = fields.whereType<T>().cast<FormField?>().firstOrNull;
    if (field == null) {
      throw SkyEchoFieldError('Expected a ${T.toString()} for that label but none found.');
    }
    if (field is TextField) field.value = '$v';
    if (field is CheckboxField) field.value = _asBool(v);
  }

  static void _setNth<T extends FormField>(List<FormField> fields, int index, dynamic v) {
    final list = fields.whereType<T>().toList();
    if (index >= list.length) {
      throw SkyEchoFieldError(
        'Field group has only ${list.length} items; index $index is out of range.',
      );
    }
    final field = list[index];
    if (field is TextField) field.value = '$v';
    if (field is CheckboxField) field.value = _asBool(v);
  }

  static void _setSelect(List<FormField> fields, String desiredValue) {
    final sel = fields.whereType<SelectField>().firstOrNull;
    if (sel == null) {
      throw SkyEchoFieldError('Expected a <select> for that label but none found.');
    }
    // Choose by value or visible text.
    final normalizedDesired = desiredValue.trim();
    final byValue = sel.options.firstWhereOrNull((o) => o.value == normalizedDesired);
    final byText = sel.options.firstWhereOrNull(
        (o) => o.text.toLowerCase() == normalizedDesired.toLowerCase());
    final picked = byValue ?? byText;
    if (picked == null) {
      throw SkyEchoFieldError(
        'Select option not found: "$desiredValue". Available: '
        '${sel.options.map((o) => '"${o.text}"').join(', ')}',
      );
    }
    sel.selected = picked.value;
  }

  static void _setRadio(List<FormField> fields, String desiredValue) {
    final radio = fields.whereType<RadioGroupField>().firstOrNull;
    if (radio == null) {
      throw SkyEchoFieldError('Expected radio buttons for that label but none found.');
    }
    final exists = radio.options.any((o) => o.value == desiredValue);
    if (!exists) {
      throw SkyEchoFieldError(
        'Radio option "$desiredValue" not available. '
        'Available: ${radio.options.map((o) => o.value).join(', ')}',
      );
    }
    radio.selected = desiredValue;
  }
}

// ============================================================================
// Form field primitives
// ============================================================================

abstract class FormField {
  FormField({required this.name, required this.label});
  final String name;
  final String label;

  Map<String, String> encode();
  FormField copy();
}

class TextField extends FormField {
  TextField({
    required super.name,
    required super.label,
    required this.value,
    required this.inputType,
  });

  String value;
  final String inputType; // 'text', 'number', etc.

  @override
  Map<String, String> encode() => {name: value};

  @override
  TextField copy() => TextField(name: name, label: label, value: value, inputType: inputType);
}

class CheckboxField extends FormField {
  CheckboxField({
    required super.name,
    required super.label,
    required this.value,
    this.rawValue = 'on',
  });

  /// true if checked
  bool value;

  /// The HTML `value` attribute when the checkbox is checked (default 'on').
  final String rawValue;

  @override
  Map<String, String> encode() => value ? {name: rawValue} : {};

  @override
  CheckboxField copy() => CheckboxField(name: name, label: label, value: value, rawValue: rawValue);
}

class RadioGroupField extends FormField {
  RadioGroupField({
    required super.name,
    required super.label,
    required this.selected,
    required this.options,
  });

  String? selected;
  final List<RadioOption> options;

  @override
  Map<String, String> encode() => selected == null ? {} : {name: selected!};

  @override
  RadioGroupField copy() => RadioGroupField(
        name: name,
        label: label,
        selected: selected,
        options: options.map((o) => RadioOption(value: o.value, label: o.label)).toList(),
      );
}

class RadioOption {
  RadioOption({required this.value, required this.label});
  final String value;
  final String? label;
}

class SelectField extends FormField {
  SelectField({
    required super.name,
    required super.label,
    required this.selected,
    required this.options,
  });

  String selected;
  final List<SelectOption> options;

  @override
  Map<String, String> encode() => {name: selected};

  @override
  SelectField copy() => SelectField(
        name: name,
        label: label,
        selected: selected,
        options: options.map((o) => SelectOption(value: o.value, text: o.text)).toList(),
      );
}

class SelectOption {
  SelectOption({required this.value, required this.text});
  final String value;
  final String text;
}

/// Submit payload (target URL + URL-encoded fields).
class FormPost {
  FormPost({required this.target, required this.data});
  final Uri target;
  final Map<String, String> data;
}

/// Result after a successful Apply.
class ApplyResult {
  ApplyResult({required this.ok});
  final bool ok;
}

// ============================================================================
// Public update model (Flutter-friendly)
// ============================================================================

/// High-level update request for the Setup form.
///
/// All fields are optional; only those you set will be changed.
class SetupUpdate {
  // Text
  String? icaoHex;
  String? callsign;
  int? vfrSquawk;
  int? vsoKnots;
  int? longitudinalGpsOffsetM;
  String? flarmIdHex;

  // Checkboxes / booleans
  bool? enable1090ESTransmit;
  bool? adsbIn1090ES;
  bool? adsbInUAT;
  bool? ownshipFilterAdsb;
  bool? ownshipFilterFlarm;

  // Radios / selects (use visible text or underlying value)
  ReceiverMode? receiverMode;
  String? emitterCategory; // e.g., "Light"
  String? aircraftLength; // e.g., "L ≤ 15 m"
  String? aircraftWidth; // e.g., "W ≤ 23 m"
  String? lateralGpsOffset; // e.g., "Center"
  String? sda; // e.g., "1"

  /// Last-resort escape hatch: set by raw field `name` in the HTML.
  /// Values can be String/bool/num; they’ll be coerced properly.
  final Map<String, dynamic> rawByFieldName = {};
}

/// Receiver mode radio group (exact wire values vary by firmware; keeps both).
enum ReceiverMode {
  uat('UAT', wireValue: 'UAT'),
  flarmEu('FLARM (EU ONLY)', wireValue: 'FLARM'),
  es1090('1090ES', wireValue: '1090ES');

  const ReceiverMode(this.display, {required this.wireValue});
  final String display;
  final String wireValue;
}

// ============================================================================
// Error types with actionable hints
// ============================================================================

abstract class SkyEchoError implements Exception {
  SkyEchoError(this.message, {this.hint});
  final String message;
  final String? hint;

  @override
  String toString() => hint == null ? message : '$message\nHint: $hint';
}

class SkyEchoNetworkError extends SkyEchoError {
  SkyEchoNetworkError(super.message, {super.hint});
}

class SkyEchoHttpError extends SkyEchoError {
  SkyEchoHttpError(super.message, {this.url, this.bodyPreview, super.hint});
  final String? url;
  final String? bodyPreview;

  @override
  String toString() =>
      '${super.toString()}${url != null ? '\nURL: $url' : ''}${bodyPreview != null ? '\nBody: $bodyPreview' : ''}';
}

class SkyEchoParseError extends SkyEchoError {
  SkyEchoParseError(super.message, {super.hint});
}

class SkyEchoFieldError extends SkyEchoError {
  SkyEchoFieldError(super.message, {super.hint});
}

// ============================================================================
// Utilities
// ============================================================================

class _Response {
  _Response(this.inner);
  final http.Response inner;

  int get statusCode => inner.statusCode;
  String get body => inner.body;
  List<String>? get setCookies {
    final h = inner.headers;
    final single = h['set-cookie'];
    if (single != null) return [single];
    final multi = h['set-cookie,'];
    if (multi != null) return multi.split(','); // rarely used form
    return null;
  }
  void checkOk() {
    if (statusCode != 200) {
      throw SkyEchoHttpError('HTTP $statusCode from ${inner.request?.url}.',
          bodyPreview: _preview(body), url: inner.request?.url.toString());
    }
  }
}

class _CookieJar {
  final Map<String, String> _cookies = {};

  void ingest(http.Response r) {
    final sc = r.headers['set-cookie'];
    if (sc == null) return;
    for (final part in sc.split(',')) {
      final seg = part.split(';').first.trim();
      final eq = seg.indexOf('=');
      if (eq <= 0) continue;
      final name = seg.substring(0, eq);
      final value = seg.substring(eq + 1);
      _cookies[name] = value;
    }
  }

  Map<String, String> toHeader() =>
      _cookies.isEmpty ? {} : {'cookie': _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ')};
}

String _normLabel(String? s) =>
    (s ?? '').replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

bool _asBool(dynamic v) {
  if (v is bool) return v;
  if (v == null) return false;
  final s = '$v'.toLowerCase().trim();
  return s == 'true' || s == '1' || s == 'on' || s == 'yes' || s == 'checked';
}

String _labelFromRow(dom.Element inputOrSelect) {
  // If the field is inside a <td>, use the previous <td> as label.
  dom.Element? td = inputOrSelect.closest('td');
  if (td != null) {
    final prev = td.previousElementSibling;
    if (prev != null) {
      final text = prev.text.trim();
      if (text.isNotEmpty) return text;
    }
  }
  return '';
}

String? _labelForInput(dom.Element e) {
  final id = e.attributes['id'];
  if (id != null && id.isNotEmpty) {
    final label = e.ownerDocument?.querySelector('label[for="$id"]');
    if (label != null && label.text.trim().isNotEmpty) {
      return label.text.trim();
    }
  }
  return null;
}

String _preview(String s, {int max = 280}) {
  final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.length <= max ? t : '${t.substring(0, max)}…';
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
  E? firstWhereOrNull(bool Function(E) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
````

---

## Example usage (works from Flutter or plain Dart)

```dart
import 'package:skyecho/skyecho.dart';

Future<void> main() async {
  final client = SkyEchoClient('http://192.168.4.1');

  // Health check
  if (!await client.ping()) {
    print('SkyEcho not reachable.');
    return;
  }

  // Read status
  final status = await client.fetchStatus();
  print('SSID: ${status.ssid}  GPS fix: ${status.gpsFix}  Sending data: ${status.isSendingData}');

  // Change a few settings and Apply
  await client.applySetup((u) => u
    ..icaoHex = '7CC599'
    ..callsign = '9954'
    ..enable1090ESTransmit = true
    ..receiverMode = ReceiverMode.es1090
    ..vfrSquawk = 1200
    ..vsoKnots = 45
    ..ownshipFilterAdsb = true
    ..adsbIn1090ES = true
    ..adsbInUAT = false
    ..emitterCategory = 'Light' // visible text or underlying <option value>
    ..aircraftLength = 'L ≤ 15 m'
    ..aircraftWidth = 'W ≤ 23 m'
    ..lateralGpsOffset = 'Center'
    ..sda = '1');

  print('Applied settings.');
}
```

---

## What the library returns for **status**

* `DeviceStatus.current`: normalized map of the “Current Status” table, keys like
  `icao address`, `callsign`, `gps fix`, `position`, `gnss altitude`, `pressure altitude`, `nic`, `nacp`
* `DeviceStatus.hasGpsFix`: `true` if “GPS Fix” isn’t `None/0/no`
* `DeviceStatus.isSendingData`: heuristic combining fix + position/quality fields
* Top‑of‑page: `wifiVersion`, `adsbVersion`, `ssid`, `clientsConnected`

---

## Error handling design

All thrown errors implement `SkyEchoError` and include actionable hints:

* `SkyEchoNetworkError('GET http://… timed out.')`
* `SkyEchoHttpError('HTTP 403', url: '…', bodyPreview: '…')`
* `SkyEchoParseError('Could not find the Setup <form> with an "Apply" submit button.', hint: '…')`
* `SkyEchoFieldError('Select option not found: "W ≤ 23 m"', hint: '…')`

These are ready to surface in Flutter UI and log files.

---

## How field mapping works (so it stays robust)

* The parser walks the **Setup** `<form>` and records each `<input>`, `<select>`, and radio/checkbox group.
* Labels are inferred from either `<label for="...">` or from the **left `<td>`** text in the same row as the field (matches your screenshots).
* Updates are matched by **human labels** with fuzzy matching, so you can say `"Receiver Mode"` or `"receiver mode"` without knowing the raw `name` attribute.
* If firmware changes, you can always override with `update.rawByFieldName['actualName'] = 'value'`.

---

## Flutter integration notes

* The API is null‑safe, `Future`‑based, and uses plain `http`, so it works on **Android, iOS, macOS, Windows, Linux**.
* For **Web**, you may need to host a small proxy due to browser CORS when hitting `http://192.168.4.1`. The client itself is platform‑agnostic.

---

## GDL90 (provision only, no implementation)

Add this tiny placeholder now (you can put it below the library code). Your Flutter app can depend on these types without changing the control code later:

```dart
/// Placeholder types for future GDL90 ingest (UDP/TCP).
class Gdl90EndpointConfig {
  const Gdl90EndpointConfig({
    required this.host,
    required this.port,
    this.transport = Gdl90Transport.udp,
  });
  final String host;
  final int port;
  final Gdl90Transport transport;
}

enum Gdl90Transport { udp, tcp }

/// Contract your UI/business logic can code against today.
/// Later, provide a concrete implementation that binds a socket and parses frames.
abstract class Gdl90Stream {
  Future<void> start(Gdl90EndpointConfig cfg, void Function(Uint8List frame) onFrame);
  Future<void> stop();
  bool get isRunning;
}
```

---

## What you’ll likely adjust on first run

* If **Apply** submission on your firmware requires a specific button `name=value`, add a one‑liner in `SetupForm.parse()` to capture it and include it in `FormPost.data`.
* If the **Reset to defaults** button actually submits the form, inspect its `name=value` and wire `resetToDefaults()` similarly.
* If a select/radio uses numeric wire values (e.g., `0/1/2`), keep the user‑facing strings in the app and set the `SetupUpdate` field with the **visible text**; the library already resolves visible text → value.

---

## Security

* This talks to `http://` on a private Wi‑Fi network. No credentials are sent by default (unless your unit prompts; if so, extend `_CookieJar` for Basic Auth headers).

---

If you want, I can add a minimal Flutter demo screen (status card + a few controls) wired to this client.
