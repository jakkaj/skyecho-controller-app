/// SkyEcho Controller Library
///
/// A Dart library for programmatic control of uAvionix SkyEcho 2 ADS-B devices.
library;

import 'dart:convert' show jsonDecode;

import 'package:http/http.dart' as http;

// ============================================================================
// Error Hierarchy
// ============================================================================

/// Base error class for all SkyEcho-related errors.
///
/// All errors thrown by this library extend [SkyEchoError]. Each error includes
/// a descriptive [message] and an optional [hint] providing actionable guidance.
abstract class SkyEchoError implements Exception {
  /// Creates a SkyEcho error with the given [message] and optional [hint].
  SkyEchoError(this.message, {this.hint});

  /// Descriptive error message explaining what went wrong.
  final String message;

  /// Optional actionable hint to help resolve the error.
  ///
  /// Examples: "Check network connection", "Ensure device is at 192.168.4.1"
  final String? hint;

  @override
  String toString() {
    if (hint == null || hint!.isEmpty) {
      return message;
    }
    return '$message\nHint: $hint';
  }
}

/// Network-level error (connection failed, timeout, DNS resolution, etc.).
///
/// Thrown when network operations fail before receiving an HTTP response.
class SkyEchoNetworkError extends SkyEchoError {
  /// Creates a network error with the given [message] and optional [hint].
  SkyEchoNetworkError(super.message, {super.hint});
}

/// HTTP-level error (4xx, 5xx status codes, unexpected status).
///
/// Thrown when HTTP request completes but returns an error status code.
class SkyEchoHttpError extends SkyEchoError {
  /// Creates an HTTP error with the given [message] and optional [hint].
  SkyEchoHttpError(super.message, {super.hint});
}

/// HTML parsing error (missing elements, unexpected structure).
///
/// Thrown when HTML response cannot be parsed or required elements are missing.
class SkyEchoParseError extends SkyEchoError {
  /// Creates a parse error with the given [message] and optional [hint].
  SkyEchoParseError(super.message, {super.hint});
}

/// Form field error (field not found, invalid value, type mismatch).
///
/// Thrown when working with setup form fields encounters issues.
class SkyEchoFieldError extends SkyEchoError {
  /// Creates a field error with the given [message] and optional [hint].
  SkyEchoFieldError(super.message, {super.hint});
}

// ============================================================================
// HTTP Infrastructure
// ============================================================================

/// Simple cookie jar for session management.
///
/// Stores cookies from Set-Cookie headers and generates Cookie headers for requests.
/// Implements minimal cookie handling without full RFC compliance (no expiry, domain, path).
class _CookieJar {
  final Map<String, String> _cookies = {};

  /// Ingests Set-Cookie headers from HTTP response.
  ///
  /// Parses "name=value; attributes..." format, ignoring all attributes.
  /// Duplicate cookie names are overwritten with the latest value.
  void ingest(List<String>? setCookieHeaders) {
    if (setCookieHeaders == null) return;

    for (final header in setCookieHeaders) {
      // Parse "name=value; attributes..."
      final parts = header.split(';');
      if (parts.isEmpty) continue;

      final nameValue = parts[0].trim();
      final eqIdx = nameValue.indexOf('=');
      if (eqIdx == -1) continue; // Malformed, skip

      final name = nameValue.substring(0, eqIdx);
      final value = nameValue.substring(eqIdx + 1);
      _cookies[name] = value;
    }
  }

  /// Generates Cookie header value for HTTP request.
  ///
  /// Returns null if no cookies are stored.
  /// Format: "name1=value1; name2=value2"
  String? toHeader() {
    if (_cookies.isEmpty) return null;
    return _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }
}

// ============================================================================
// SkyEcho Client
// ============================================================================

/// HTTP client for communicating with SkyEcho 2 device.
///
/// Manages session cookies, HTTP requests, and error handling.
/// All methods throw [SkyEchoError] subclasses on failure.
class SkyEchoClient {
  /// Creates a SkyEcho client for the given [baseUrl].
  ///
  /// [baseUrl] should be the device URL (typically `http://192.168.4.1`).
  /// [httpClient] can be provided for testing (e.g., MockClient).
  /// [timeout] defaults to 5 seconds.
  SkyEchoClient(
    this.baseUrl, {
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 5),
  }) : _httpClient = httpClient ?? http.Client();

  /// Base URL of the SkyEcho device (e.g., `http://192.168.4.1`).
  final String baseUrl;

  /// HTTP timeout for requests.
  final Duration timeout;

  final http.Client _httpClient;
  final _CookieJar _cookieJar = _CookieJar();

  /// Pings the device to verify connectivity.
  ///
  /// Sends GET request to `/` and verifies 200 OK response.
  /// Stores session cookies from Set-Cookie headers for subsequent requests.
  ///
  /// Throws [SkyEchoNetworkError] on network failures.
  /// Throws [SkyEchoHttpError] on non-200 status codes.
  Future<void> ping() async {
    try {
      final uri = Uri.parse('$baseUrl/');
      final headers = <String, String>{};

      // Add cookies if available
      final cookie = _cookieJar.toHeader();
      if (cookie != null) {
        headers['cookie'] = cookie;
      }

      final response =
          await _httpClient.get(uri, headers: headers).timeout(timeout);

      // Ingest cookies from response
      final setCookie = response.headers['set-cookie'];
      if (setCookie != null) {
        _cookieJar.ingest([setCookie]);
      }

      // Check status
      if (response.statusCode != 200) {
        throw SkyEchoHttpError(
          'HTTP ${response.statusCode}: ${response.reasonPhrase ?? "Unknown"}',
          hint: 'Ensure device is powered on and accessible at $baseUrl',
        );
      }
    } on http.ClientException catch (e) {
      throw SkyEchoNetworkError(
        'Network error: ${e.message}',
        hint: 'Check WiFi connection and device IP address',
      );
    } on SkyEchoError {
      rethrow;
    }
  }

  /// Fetches device status from JSON API endpoint.
  ///
  /// Sends GET request to `/?action=get` and parses JSON response.
  /// Returns [DeviceStatus] with all available fields.
  ///
  /// Throws [SkyEchoNetworkError] on network failures.
  /// Throws [SkyEchoHttpError] on non-200 status codes.
  /// Throws [SkyEchoParseError] on JSON parsing failures.
  Future<DeviceStatus> fetchStatus() async {
    try {
      final uri = Uri.parse('$baseUrl/?action=get');
      final headers = <String, String>{};

      // Add cookies if available
      final cookie = _cookieJar.toHeader();
      if (cookie != null) {
        headers['cookie'] = cookie;
      }

      final response =
          await _httpClient.get(uri, headers: headers).timeout(timeout);

      // Ingest cookies from response
      final setCookie = response.headers['set-cookie'];
      if (setCookie != null) {
        _cookieJar.ingest([setCookie]);
      }

      // Check status
      if (response.statusCode != 200) {
        throw SkyEchoHttpError(
          'HTTP ${response.statusCode}: ${response.reasonPhrase ?? "Unknown"}',
          hint: 'Ensure device is powered on and accessible at $baseUrl',
        );
      }

      // Parse JSON
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return DeviceStatus.fromJson(json);
    } on http.ClientException catch (e) {
      throw SkyEchoNetworkError(
        'Network error: ${e.message}',
        hint: 'Check WiFi connection and device IP address',
      );
    } on FormatException catch (e) {
      throw SkyEchoParseError(
        'Failed to parse JSON response: ${e.message}',
        hint: 'Device may have returned invalid JSON. Check device firmware.',
      );
    } on SkyEchoError {
      rethrow;
    }
  }
}

// ============================================================================
// Device Status Model
// ============================================================================

/// Device status parsed from JSON API endpoint.
///
/// Fetched from `GET /?action=get` endpoint which returns device info as JSON.
/// Contains 6 fields: wifiVersion, adsbVersion, ssid, clientsConnected,
/// serialNumber, and coredump.
class DeviceStatus {
  /// Creates a DeviceStatus with the given fields.
  ///
  /// All fields except [coredump] are nullable to handle missing values.
  DeviceStatus({
    required this.wifiVersion,
    required this.adsbVersion,
    required this.ssid,
    required this.clientsConnected,
    required this.serialNumber,
    required this.coredump,
  });

  /// Wi-Fi firmware version (e.g., "0.2.41-SkyEcho").
  ///
  /// Null if not present in JSON response.
  final String? wifiVersion;

  /// ADS-B firmware version (e.g., "2.6.13").
  ///
  /// Null if not present in JSON response.
  final String? adsbVersion;

  /// Device SSID (e.g., "SkyEcho_3155").
  ///
  /// Null if not present in JSON response.
  final String? ssid;

  /// Number of WiFi clients currently connected.
  ///
  /// Null if not present in JSON response.
  final int? clientsConnected;

  /// Device serial number (e.g., "0655339053").
  ///
  /// Null if not present in JSON response.
  final String? serialNumber;

  /// Whether device has a coredump (crash dump).
  ///
  /// Defaults to false if not present in JSON response.
  final bool coredump;

  /// Returns true if device has a coredump.
  ///
  /// Convenience getter for checking device health.
  bool get hasCoredump => coredump == true;

  /// Returns true if device appears healthy.
  ///
  /// Heuristic: device is healthy if no coredump AND has at least one client.
  /// This is a simple health check, not authoritative device state.
  bool get isHealthy =>
      coredump == false &&
      clientsConnected != null &&
      clientsConnected! > 0;

  /// Parses DeviceStatus from JSON map.
  ///
  /// Expects JSON structure from `GET /?action=get`:
  /// ```json
  /// {
  ///   "wifiVersion": "0.2.41-SkyEcho",
  ///   "ssid": "SkyEcho_3155",
  ///   "clientCount": 1,
  ///   "adsbVersion": "2.6.13",
  ///   "serialNumber": "0655339053",
  ///   "coredump": false
  /// }
  /// ```
  ///
  /// All fields are optional except coredump (defaults to false).
  /// Throws [SkyEchoParseError] if JSON structure is invalid.
  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    try {
      return DeviceStatus(
        wifiVersion: json['wifiVersion'] as String?,
        adsbVersion: json['adsbVersion'] as String?,
        ssid: json['ssid'] as String?,
        clientsConnected: json['clientCount'] as int?,
        serialNumber: json['serialNumber'] as String?,
        coredump: json['coredump'] as bool? ?? false,
      );
    } catch (e) {
      throw SkyEchoParseError(
        'Failed to parse DeviceStatus from JSON: $e',
        hint: 'Ensure JSON has expected structure from GET /?action=get',
      );
    }
  }
}
