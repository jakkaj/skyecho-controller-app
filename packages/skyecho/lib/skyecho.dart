/// SkyEcho Controller Library
///
/// A Dart library for programmatic control of uAvionix SkyEcho 2 ADS-B devices.
library;

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
}
