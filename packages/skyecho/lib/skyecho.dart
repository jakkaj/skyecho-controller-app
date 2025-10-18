/// SkyEcho Controller Library
///
/// A Dart library for programmatic control of uAvionix SkyEcho 2 ADS-B devices.
library;

import 'dart:convert' show jsonDecode, jsonEncode;

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
  })  : _httpClient = httpClient ?? http.Client(),
        _externalClient = httpClient != null;

  /// Base URL of the SkyEcho device (e.g., `http://192.168.4.1`).
  final String baseUrl;

  /// HTTP timeout for requests.
  final Duration timeout;

  http.Client _httpClient;
  final _CookieJar _cookieJar = _CookieJar();

  /// Tracks if HTTP client was provided externally (for testing).
  final bool _externalClient;

  /// Resets HTTP connection to work around SkyEcho device keep-alive bug.
  ///
  /// The device firmware has a bug where it closes connections on ANY request
  /// made on a reused HTTP connection (keep-alive). This method closes and
  /// reopens the connection before each request.
  ///
  /// For external clients (tests with MockClient), this is a no-op.
  void _resetConnection() {
    if (!_externalClient) {
      _httpClient.close();
      _httpClient = http.Client();
    }
  }

  /// Pings the device to verify connectivity.
  ///
  /// Sends GET request to `/` and verifies 200 OK response.
  /// Stores session cookies from Set-Cookie headers for subsequent requests.
  ///
  /// Throws [SkyEchoNetworkError] on network failures.
  /// Throws [SkyEchoHttpError] on non-200 status codes.
  Future<void> ping() async {
    try {
      // WORKAROUND: Reset connection before request (device keep-alive bug)
      _resetConnection();

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
      // WORKAROUND: Reset connection before request (device keep-alive bug)
      _resetConnection();

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

  /// Fetches device setup configuration from JSON API endpoint.
  ///
  /// Sends GET request to `/setup/?action=get` and parses JSON response.
  /// Returns [SetupConfig] with all configuration fields and transformations.
  ///
  /// Throws [SkyEchoNetworkError] on network failures.
  /// Throws [SkyEchoHttpError] on non-200 status codes.
  /// Throws [SkyEchoParseError] on JSON parsing failures.
  Future<SetupConfig> fetchSetupConfig() async {
    try {
      // WORKAROUND: Reset connection before request (device keep-alive bug)
      _resetConnection();

      final uri = Uri.parse('$baseUrl/setup/?action=get');
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
      return SetupConfig.fromJson(json);
    } on http.ClientException catch (e) {
      throw SkyEchoNetworkError(
        'Network error: ${e.message}',
        hint: 'Check WiFi connection and device IP address',
      );
    } on FormatException catch (e) {
      throw SkyEchoParseError(
        'Failed to parse JSON response: ${e.message}',
        hint: 'Device may have returned invalid JSON. Check firmware.',
      );
    } on SkyEchoError {
      rethrow;
    }
  }

  /// Posts JSON payload to device endpoint.
  ///
  /// Internal helper for JSON POST requests with cookie management.
  /// Returns HTTP response.
  ///
  /// **Workaround:** Resets HTTP connection before POST to avoid device
  /// keep-alive bug (device closes connection on reused connections).
  ///
  /// Throws [SkyEchoNetworkError] on network failures.
  /// Throws [SkyEchoHttpError] on non-200 status codes.
  Future<http.Response> _postJson(String path, Map<String, dynamic> json) async {
    try {
      // WORKAROUND: Reset connection before request (device keep-alive bug)
      _resetConnection();

      final uri = Uri.parse('$baseUrl$path');
      final headers = <String, String>{
        'content-type': 'application/json',
      };

      // Add cookies if available
      final cookie = _cookieJar.toHeader();
      if (cookie != null) {
        headers['cookie'] = cookie;
      }

      final body = jsonEncode(json);
      final response =
          await _httpClient.post(uri, headers: headers, body: body).timeout(timeout);

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

      return response;
    } on http.ClientException catch (e) {
      throw SkyEchoNetworkError(
        'Network error: ${e.message}',
        hint: 'Check WiFi connection and device IP address',
      );
    } on SkyEchoError {
      rethrow;
    }
  }

  /// Applies setup configuration update to device with verification.
  ///
  /// Usage:
  /// ```dart
  /// final result = await client.applySetup((update) => update
  ///   ..icaoAddress = '7CC599'
  ///   ..callsign = 'TEST123'
  ///   ..stallSpeedKnots = 50.0);
  /// ```
  ///
  /// **Process:**
  /// 1. Fetches current config via GET /setup/?action=get
  /// 2. Applies updates via [SetupUpdate] builder
  /// 3. Validates all fields
  /// 4. POSTs to /setup/?action=set
  /// 5. Waits 2 seconds for device persistence (critical!)
  /// 6. GETs config again to verify changes applied
  ///
  /// Returns [ApplyResult] with success, verification status, config.
  ///
  /// Throws [SkyEchoFieldError] if validation fails.
  /// Throws [SkyEchoNetworkError] on network failures.
  /// Throws [SkyEchoHttpError] on non-200 status codes.
  /// Throws [SkyEchoParseError] on JSON parsing failures.
  Future<ApplyResult> applySetup(
    void Function(SetupUpdate update) buildUpdate,
  ) async {
    // Fetch current config
    final currentConfig = await fetchSetupConfig();

    // Build update
    final update = SetupUpdate();
    buildUpdate(update);

    // Apply update to create new config
    final newConfig = currentConfig.copyWith(
      icaoAddress: update.icaoAddress,
      callsign: update.callsign,
      emitterCategory: update.emitterCategory,
      uatEnabled: update.uatEnabled,
      es1090Enabled: update.es1090Enabled,
      es1090TransmitEnabled: update.es1090TransmitEnabled,
      receiverMode: update.receiverMode,
      aircraftLength: update.aircraftLength,
      aircraftWidth: update.aircraftWidth,
      gpsLatOffset: update.gpsLatOffset,
      gpsLonOffsetMeters: update.gpsLonOffsetMeters,
      sil: update.sil,
      sda: update.sda,
      stallSpeedKnots: update.stallSpeedKnots,
      vfrSquawk: update.vfrSquawk,
      ownshipFilterIcao: update.ownshipFilterIcao,
      ownshipFilterFlarmId: update.ownshipFilterFlarmId,
    );

    // Validate new config
    newConfig.validate();

    // POST config to device
    await _postJson('/setup/?action=set', newConfig.toJson());

    // CRITICAL: Wait 2 seconds for device to persist changes
    await Future<void>.delayed(SkyEchoConstants.postPersistenceDelay);

    // Verify changes via GET
    final verifiedConfig = await fetchSetupConfig();

    // Compare newConfig vs verifiedConfig to detect mismatches
    final mismatches = <String, List<dynamic>>{};

    if (newConfig.icaoAddress != verifiedConfig.icaoAddress) {
      mismatches['icaoAddress'] = [
        newConfig.icaoAddress,
        verifiedConfig.icaoAddress
      ];
    }
    if (newConfig.callsign != verifiedConfig.callsign) {
      mismatches['callsign'] = [newConfig.callsign, verifiedConfig.callsign];
    }
    if (newConfig.emitterCategory != verifiedConfig.emitterCategory) {
      mismatches['emitterCategory'] = [
        newConfig.emitterCategory,
        verifiedConfig.emitterCategory
      ];
    }
    if (newConfig.uatEnabled != verifiedConfig.uatEnabled) {
      mismatches['uatEnabled'] = [
        newConfig.uatEnabled,
        verifiedConfig.uatEnabled
      ];
    }
    if (newConfig.es1090Enabled != verifiedConfig.es1090Enabled) {
      mismatches['es1090Enabled'] = [
        newConfig.es1090Enabled,
        verifiedConfig.es1090Enabled
      ];
    }
    if (newConfig.es1090TransmitEnabled !=
        verifiedConfig.es1090TransmitEnabled) {
      mismatches['es1090TransmitEnabled'] = [
        newConfig.es1090TransmitEnabled,
        verifiedConfig.es1090TransmitEnabled
      ];
    }
    if (newConfig.receiverMode != verifiedConfig.receiverMode) {
      mismatches['receiverMode'] = [
        newConfig.receiverMode,
        verifiedConfig.receiverMode
      ];
    }
    if (newConfig.aircraftLength != verifiedConfig.aircraftLength) {
      mismatches['aircraftLength'] = [
        newConfig.aircraftLength,
        verifiedConfig.aircraftLength
      ];
    }
    if (newConfig.aircraftWidth != verifiedConfig.aircraftWidth) {
      mismatches['aircraftWidth'] = [
        newConfig.aircraftWidth,
        verifiedConfig.aircraftWidth
      ];
    }
    if (newConfig.gpsLatOffset != verifiedConfig.gpsLatOffset) {
      mismatches['gpsLatOffset'] = [
        newConfig.gpsLatOffset,
        verifiedConfig.gpsLatOffset
      ];
    }
    if (newConfig.gpsLonOffsetMeters != verifiedConfig.gpsLonOffsetMeters) {
      mismatches['gpsLonOffsetMeters'] = [
        newConfig.gpsLonOffsetMeters,
        verifiedConfig.gpsLonOffsetMeters
      ];
    }
    if (newConfig.sil != verifiedConfig.sil) {
      mismatches['sil'] = [newConfig.sil, verifiedConfig.sil];
    }
    if (newConfig.sda != verifiedConfig.sda) {
      mismatches['sda'] = [newConfig.sda, verifiedConfig.sda];
    }
    if (newConfig.stallSpeedKnots != verifiedConfig.stallSpeedKnots) {
      mismatches['stallSpeedKnots'] = [
        newConfig.stallSpeedKnots,
        verifiedConfig.stallSpeedKnots
      ];
    }
    if (newConfig.vfrSquawk != verifiedConfig.vfrSquawk) {
      mismatches['vfrSquawk'] = [
        newConfig.vfrSquawk,
        verifiedConfig.vfrSquawk
      ];
    }
    if (newConfig.ownshipFilterIcao != verifiedConfig.ownshipFilterIcao) {
      mismatches['ownshipFilterIcao'] = [
        newConfig.ownshipFilterIcao,
        verifiedConfig.ownshipFilterIcao
      ];
    }
    if (newConfig.ownshipFilterFlarmId != verifiedConfig.ownshipFilterFlarmId) {
      mismatches['ownshipFilterFlarmId'] = [
        newConfig.ownshipFilterFlarmId,
        verifiedConfig.ownshipFilterFlarmId
      ];
    }

    final verified = mismatches.isEmpty;
    final message = verified
        ? 'Configuration applied and verified successfully'
        : 'Configuration applied but verification detected ${mismatches.length} mismatch(es)';

    return ApplyResult(
      success: true,
      verified: verified,
      verifiedConfig: verifiedConfig,
      message: message,
      mismatches: mismatches,
    );
  }

  /// Resets device to factory defaults.
  ///
  /// Sends special payload `{"loadDefaults": true}` to trigger reset.
  /// Device will reboot and restore factory configuration.
  ///
  /// **Warning:** This erases all user configuration including ICAO address,
  /// callsign, and all other settings. Use with caution.
  ///
  /// Returns [ApplyResult] with success status.
  ///
  /// Throws [SkyEchoNetworkError] on network failures.
  /// Throws [SkyEchoHttpError] on non-200 status codes.
  Future<ApplyResult> factoryReset() async {
    await _postJson('/setup/?action=set', {'loadDefaults': true});

    return ApplyResult(
      success: true,
      verified: false,
      message: 'Factory reset initiated. Device will reboot.',
    );
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

// ============================================================================
// Transformation Helpers (Private)
// ============================================================================

/// Converts hex string to integer.
///
/// Accepts 6-character hex string (with optional "0x" prefix).
/// Returns integer value (0-16777215).
int _hexToInt(String hex) {
  final cleaned = hex.toLowerCase().replaceFirst('0x', '');
  return int.parse(cleaned, radix: 16);
}

/// Converts integer to 6-character hex string.
///
/// Accepts integer (0-16777215).
/// Returns uppercase hex string padded to 6 characters.
String _intToHex(int value) {
  return value.toRadixString(16).toUpperCase().padLeft(6, '0');
}

/// Extracts bit value from integer at given position.
///
/// [value] is the integer to extract from.
/// [position] is the bit position (0-based, 0 = LSB).
/// Returns true if bit is set, false otherwise.
bool _getBit(int value, int position) {
  return (value & (1 << position)) != 0;
}


/// Packs ADS-B In Capability bitmask from boolean flags.
///
/// Bit 0 = UAT enabled
/// Bit 1 = 1090ES enabled
/// Returns integer (0-3).
int _packAdsbInCapability({
  required bool uatEnabled,
  required bool es1090Enabled,
}) {
  int result = 0;
  if (uatEnabled) result |= 0x01;
  if (es1090Enabled) result |= 0x02;
  return result;
}

/// Unpacks ADS-B In Capability bitmask to boolean flags.
///
/// Bit 0 = UAT enabled
/// Bit 1 = 1090ES enabled
/// Returns map with 'uat' and 'es1090' keys.
Map<String, bool> _unpackAdsbInCapability(int value) {
  return {
    'uat': _getBit(value, 0),
    'es1090': _getBit(value, 1),
  };
}

/// Converts stall speed from knots to device integer format.
///
/// Formula: ceil(knots × 514.4)
/// Range: 0-65535
int _stallSpeedToDevice(double knots) {
  return (knots * 514.4).ceil();
}

/// Converts device stall speed integer to knots.
///
/// Formula: ceil(deviceValue / 514.4)
/// Returns double knots.
double _stallSpeedFromDevice(int deviceValue) {
  return (deviceValue / 514.4).ceilToDouble();
}

// ============================================================================
// Constants
// ============================================================================

/// Constants and limits for SkyEcho device configuration.
///
/// Extracted from device JavaScript and firmware specifications.
class SkyEchoConstants {
  /// Aviation safety integrity level (hardcoded by device).
  ///
  /// SIL is safety-critical and non-configurable per device firmware.
  static const int silHardcoded = 1;

  /// Stall speed conversion constant.
  ///
  /// Device formula: ceil(knots × 514.4)
  static const double stallSpeedMultiplier = 514.4;

  /// Device POST persistence delay (milliseconds).
  ///
  /// Device requires up to 2 seconds to persist changes to flash.
  static const Duration postPersistenceDelay = Duration(seconds: 2);

  /// ICAO address blacklist.
  ///
  /// Values 000000 and FFFFFF are reserved and invalid.
  static const Set<String> icaoBlacklist = {'000000', 'FFFFFF'};

  /// Receiver mode values (non-sequential).
  ///
  /// These are the raw device control field values for each mode:
  /// - UAT only: 0x01
  /// - 1090ES only: 0x00
  /// - FLARM only: 0x41 (bit 0 + bit 6)
  /// - UAT + 1090ES: 0x03
  /// - UAT + 1090ES transmit: 0x03
  static const Map<String, int> receiverModeValues = {
    'uat': 0x01,
    'es1090': 0x00,
    'flarm': 0x41,
  };

  /// Valid emitter category values.
  ///
  /// Gaps exist in valid range (no 8, 13, 16, 22+):
  /// Valid: 0-7, 9-12, 14-15, 17-21
  static const Set<int> validEmitterCategories = {
    0, 1, 2, 3, 4, 5, 6, 7, // 0-7
    9, 10, 11, 12, // 9-12 (skip 8)
    14, 15, // 14-15 (skip 13)
    17, 18, 19, 20, 21, // 17-21 (skip 16)
  };
}

// ============================================================================
// Validation Helpers
// ============================================================================

/// Validation helper functions for SkyEcho configuration fields.
///
/// Implements device JavaScript validation rules with actionable hints.
class SkyEchoValidation {
  /// Validates ICAO hex address.
  ///
  /// Rules:
  /// - Must be 6 hex characters (0-9, A-F)
  /// - MUST NOT be 000000 or FFFFFF (blacklisted)
  /// - Optional 0x prefix allowed
  ///
  /// Throws [SkyEchoFieldError] if invalid.
  static void validateIcaoHex(String hex) {
    final cleaned = hex.toLowerCase().replaceFirst('0x', '');

    // Check length
    if (cleaned.length != 6) {
      throw SkyEchoFieldError(
        'ICAO address must be exactly 6 hex characters, got: "$hex"',
        hint: 'Example: "7CC599" or "0x7CC599"',
      );
    }

    // Check hex format
    final hexPattern = RegExp(r'^[0-9a-fA-F]{6}$');
    if (!hexPattern.hasMatch(cleaned)) {
      throw SkyEchoFieldError(
        'ICAO address contains invalid characters: "$hex"',
        hint: 'Use only 0-9 and A-F',
      );
    }

    // Check blacklist
    final upper = cleaned.toUpperCase();
    if (SkyEchoConstants.icaoBlacklist.contains(upper)) {
      throw SkyEchoFieldError(
        'ICAO address $upper is reserved and invalid',
        hint: 'Use a valid ICAO address (not 000000 or FFFFFF)',
      );
    }
  }

  /// Validates callsign.
  ///
  /// Rules:
  /// - 1-8 alphanumeric characters
  /// - No special characters or spaces
  /// - Device auto-converts to uppercase
  ///
  /// Throws [SkyEchoFieldError] if invalid.
  static void validateCallsign(String callsign) {
    if (callsign.isEmpty) {
      throw SkyEchoFieldError(
        'Callsign cannot be empty',
        hint: 'Provide 1-8 alphanumeric characters',
      );
    }

    if (callsign.length > 8) {
      throw SkyEchoFieldError(
        'Callsign too long: ${callsign.length} characters (max 8)',
        hint: 'Shorten to 8 characters or less',
      );
    }

    final pattern = RegExp(r'^[A-Za-z0-9]{1,8}$');
    if (!pattern.hasMatch(callsign)) {
      throw SkyEchoFieldError(
        'Callsign contains invalid characters: "$callsign"',
        hint: 'Use only letters and numbers (no spaces or symbols)',
      );
    }
  }

  /// Validates VFR squawk code.
  ///
  /// Rules:
  /// - 4-digit octal number (0-7 only, no 8 or 9)
  /// - Range: 0000-7777
  /// - Common default: 1200
  ///
  /// Throws [SkyEchoFieldError] if invalid.
  static void validateVfrSquawk(int squawk) {
    if (squawk < 0 || squawk > 7777) {
      throw SkyEchoFieldError(
        'VFR squawk out of range: $squawk (must be 0000-7777)',
        hint: 'Use 4-digit octal code (0-7 digits only)',
      );
    }

    // Check octal (no digits 8 or 9)
    final squawkStr = squawk.toString().padLeft(4, '0');
    final octalPattern = RegExp(r'^[0-7]{4}$');
    if (!octalPattern.hasMatch(squawkStr)) {
      throw SkyEchoFieldError(
        'VFR squawk contains invalid digits: $squawkStr',
        hint: 'Each digit must be 0-7 (octal), no 8 or 9 allowed',
      );
    }
  }

  /// Validates emitter category.
  ///
  /// Valid values: 0-7, 9-12, 14-15, 17-21 (gaps at 8, 13, 16, 22+).
  ///
  /// Throws [SkyEchoFieldError] if invalid.
  static void validateEmitterCategory(int category) {
    if (!SkyEchoConstants.validEmitterCategories.contains(category)) {
      throw SkyEchoFieldError(
        'Invalid emitter category: $category',
        hint: 'Valid: 0-7, 9-12, 14-15, 17-21 (gaps at 8, 13, 16, 22+)',
      );
    }
  }

  /// Validates stall speed.
  ///
  /// Range: 0-127 knots (device max 65535 = ~127 knots).
  ///
  /// Throws [SkyEchoFieldError] if invalid.
  static void validateStallSpeed(double knots) {
    if (knots < 0 || knots > 127) {
      throw SkyEchoFieldError(
        'Stall speed out of range: $knots knots (must be 0-127)',
        hint: 'Device supports 0-127 knots',
      );
    }
  }

  /// Validates GPS antenna offset latitude.
  ///
  /// Range: 0-7 (3 bits).
  ///
  /// Throws [SkyEchoFieldError] if invalid.
  static void validateGpsLatOffset(int latOffset) {
    if (latOffset < 0 || latOffset > 7) {
      throw SkyEchoFieldError(
        'GPS lat offset out of range: $latOffset (must be 0-7)',
        hint: 'Use 3-bit value (0-7)',
      );
    }
  }

  /// Validates GPS antenna offset longitude.
  ///
  /// Range: 0-60 meters, MUST be even (odd values truncated by device).
  ///
  /// Throws [SkyEchoFieldError] if invalid.
  static void validateGpsLonOffset(int lonMeters) {
    if (lonMeters < 0 || lonMeters > 60) {
      throw SkyEchoFieldError(
        'GPS lon offset out of range: $lonMeters meters (0-60)',
        hint: 'Use value 0-60 meters',
      );
    }

    if (lonMeters % 2 != 0) {
      throw SkyEchoFieldError(
        'GPS lon offset must be even: $lonMeters meters',
        hint: 'Device truncates odd values. Use even (0, 2, 4, ...60)',
      );
    }
  }

  /// Validates aircraft length code.
  ///
  /// Range: 0-7 (3 bits), 0 = "no data".
  ///
  /// Throws [SkyEchoFieldError] if invalid.
  static void validateAircraftLength(int length) {
    if (length < 0 || length > 7) {
      throw SkyEchoFieldError(
        'Aircraft length out of range: $length (must be 0-7)',
        hint: 'Use 3-bit value (0-7), 0 = no data',
      );
    }
  }

  /// Validates aircraft width code.
  ///
  /// Range: 0-1 (1 bit).
  ///
  /// Throws [SkyEchoFieldError] if invalid.
  static void validateAircraftWidth(int width) {
    if (width < 0 || width > 1) {
      throw SkyEchoFieldError(
        'Aircraft width out of range: $width (must be 0 or 1)',
        hint: 'Use 1-bit value (0 or 1)',
      );
    }
  }
}

// ============================================================================
// Setup Configuration Model
// ============================================================================

/// Receiver mode enumeration.
///
/// Maps to device control field values with non-sequential encoding:
/// - UAT: 0x01
/// - 1090ES: 0x00
/// - FLARM: 0x41
enum ReceiverMode {
  /// UAT reception only (control = 0x01).
  uat,

  /// 1090ES reception only (control = 0x00).
  es1090,

  /// FLARM reception only (control = 0x41).
  flarm,
}

/// Device setup configuration from JSON API.
///
/// Fetched from `GET /setup/?action=get` and submitted via
/// `POST /setup/?action=set`. Contains all configurable device parameters
/// with transformations applied.
class SetupConfig {
  /// Creates SetupConfig with all required fields.
  SetupConfig({
    required this.icaoAddress,
    required this.callsign,
    required this.emitterCategory,
    required this.uatEnabled,
    required this.es1090Enabled,
    required this.es1090TransmitEnabled,
    required this.receiverMode,
    required this.aircraftLength,
    required this.aircraftWidth,
    required this.gpsLatOffset,
    required this.gpsLonOffsetMeters,
    required this.sil,
    required this.sda,
    required this.stallSpeedKnots,
    required this.vfrSquawk,
    required this.ownshipFilterIcao,
    this.ownshipFilterFlarmId,
  });

  // ========== Setup Fields ==========

  /// ICAO 24-bit address (hex string, e.g., "7CC599").
  ///
  /// Device stores as integer, library presents as hex.
  /// MUST NOT be 000000 or FFFFFF (blacklisted).
  final String icaoAddress;

  /// Aircraft callsign (1-8 alphanumeric, auto-uppercased).
  final String callsign;

  /// Emitter category code.
  ///
  /// Valid: 0-7, 9-12, 14-15, 17-21 (gaps at 8, 13, 16, 22+).
  final int emitterCategory;

  /// UAT reception enabled (unpacked from adsbInCapability bit 0).
  final bool uatEnabled;

  /// 1090ES reception enabled (unpacked from adsbInCapability bit 1).
  final bool es1090Enabled;

  /// 1090ES transmit enabled (unpacked from control bit 1).
  final bool es1090TransmitEnabled;

  /// Receiver mode (UAT, ES1090, FLARM).
  ///
  /// Unpacked from control field with custom logic.
  final ReceiverMode receiverMode;

  /// Aircraft length code (0-7, from aircraftLengthWidth upper 3 bits).
  ///
  /// 0 = no data, 1-7 = size categories.
  final int aircraftLength;

  /// Aircraft width code (0-1, from aircraftLengthWidth bit 0).
  final int aircraftWidth;

  /// GPS antenna latitude offset (0-7, from gpsAntennaOffset bits 5-7).
  final int gpsLatOffset;

  /// GPS antenna longitude offset in meters (0-60, even only).
  ///
  /// Unpacked from gpsAntennaOffset bits 0-4: (encoded - 1) × 2.
  final int gpsLonOffsetMeters;

  /// Source Integrity Level (hardcoded to 1 by device).
  final int sil;

  /// System Design Assurance (0-3).
  final int sda;

  /// Stall speed in knots (unpacked from device integer).
  final double stallSpeedKnots;

  /// VFR squawk code (0000-7777, octal).
  final int vfrSquawk;

  // ========== Ownship Filter Fields ==========

  /// Ownship filter ICAO (mirrors setup.icaoAddress if enabled).
  final String ownshipFilterIcao;

  /// Ownship filter FLARM ID (hex string, null if disabled).
  final String? ownshipFilterFlarmId;

  /// Parses SetupConfig from JSON response.
  ///
  /// Expects structure from `GET /setup/?action=get`:
  /// ```json
  /// {
  ///   "setup": { /* 11 fields */ },
  ///   "ownshipFilter": { "icaoAddress": ..., "flarmId": ... }
  /// }
  /// ```
  ///
  /// Performs all transformations (hex, bit unpacking, unit conversion).
  /// Throws [SkyEchoParseError] if structure is invalid.
  factory SetupConfig.fromJson(Map<String, dynamic> json) {
    try {
      final setup = json['setup'] as Map<String, dynamic>;
      final filter = json['ownshipFilter'] as Map<String, dynamic>;

      // Extract raw values
      final icaoInt = setup['icaoAddress'] as int;
      final callsign = setup['callsign'] as String;
      final emitterCategory = setup['emitterCategory'] as int;
      final adsbInCapability = setup['adsbInCapability'] as int;
      final aircraftLengthWidth = setup['aircraftLengthWidth'] as int;
      final gpsAntennaOffset = setup['gpsAntennaOffset'] as int;
      final sil = setup['SIL'] as int;
      final sda = setup['SDA'] as int;
      final stallSpeed = setup['stallSpeed'] as int;
      final vfrSquawk = setup['vfrSquawk'] as int;
      final control = setup['control'] as int;

      final filterIcaoInt = filter['icaoAddress'] as int?;
      final filterFlarmId = filter['flarmId'] as int?;

      // Transform ICAO addresses
      final icaoHex = _intToHex(icaoInt);
      final filterIcaoHex =
          filterIcaoInt != null ? _intToHex(filterIcaoInt) : '';

      // Unpack adsbInCapability
      final adsbIn = _unpackAdsbInCapability(adsbInCapability);
      final uatEnabled = adsbIn['uat']!;
      final es1090Enabled = adsbIn['es1090']!;

      // Unpack control field for receiver mode and ES transmit
      ReceiverMode receiverMode;
      bool es1090TransmitEnabled = false;

      // CRITICAL: Check FLARM (0x41) FIRST before UAT (0x01) due to overlap
      if (control == 0x41) {
        receiverMode = ReceiverMode.flarm;
      } else if (_getBit(control, 0)) {
        receiverMode = ReceiverMode.uat;
        es1090TransmitEnabled = _getBit(control, 1);
      } else {
        receiverMode = ReceiverMode.es1090;
        es1090TransmitEnabled = _getBit(control, 1);
      }

      // Unpack aircraftLengthWidth
      final aircraftLength = aircraftLengthWidth >> 1; // Upper 3 bits
      final aircraftWidth = aircraftLengthWidth & 0x01; // Bit 0

      // Unpack gpsAntennaOffset
      final gpsLatOffset = (gpsAntennaOffset >> 5) & 0x07; // Bits 5-7
      final gpsLonEncoded = gpsAntennaOffset & 0x1F; // Bits 0-4
      final gpsLonOffsetMeters = gpsLonEncoded == 0
          ? 0
          : (gpsLonEncoded - 1) * 2 < 0
              ? 0
              : (gpsLonEncoded - 1) * 2;

      // Convert stallSpeed
      final stallSpeedKnots = _stallSpeedFromDevice(stallSpeed);

      // Convert FLARM ID if present
      final flarmIdHex =
          filterFlarmId != null ? _intToHex(filterFlarmId) : null;

      return SetupConfig(
        icaoAddress: icaoHex,
        callsign: callsign,
        emitterCategory: emitterCategory,
        uatEnabled: uatEnabled,
        es1090Enabled: es1090Enabled,
        es1090TransmitEnabled: es1090TransmitEnabled,
        receiverMode: receiverMode,
        aircraftLength: aircraftLength,
        aircraftWidth: aircraftWidth,
        gpsLatOffset: gpsLatOffset,
        gpsLonOffsetMeters: gpsLonOffsetMeters,
        sil: sil,
        sda: sda,
        stallSpeedKnots: stallSpeedKnots,
        vfrSquawk: vfrSquawk,
        ownshipFilterIcao: filterIcaoHex,
        ownshipFilterFlarmId: flarmIdHex,
      );
    } catch (e) {
      throw SkyEchoParseError(
        'Failed to parse SetupConfig from JSON: $e',
        hint: 'Ensure JSON has structure from GET /setup/?action=get',
      );
    }
  }

  /// Converts SetupConfig to JSON for POST request.
  ///
  /// Performs all inverse transformations (hex → int, bit packing, units).
  /// Returns JSON for `POST /setup/?action=set`:
  /// ```json
  /// {
  ///   "setup": { /* 11 fields */ },
  ///   "ownshipFilter": { "icaoAddress": ..., "flarmId": ... }
  /// }
  /// ```
  Map<String, dynamic> toJson() {
    // Pack adsbInCapability
    final adsbInCapability = _packAdsbInCapability(
      uatEnabled: uatEnabled,
      es1090Enabled: es1090Enabled,
    );

    // Pack control field
    int control = 0;
    switch (receiverMode) {
      case ReceiverMode.flarm:
        control = 0x41;
        break;
      case ReceiverMode.uat:
        control = 0x01;
        if (es1090TransmitEnabled) control |= 0x02;
        break;
      case ReceiverMode.es1090:
        control = 0x00;
        if (es1090TransmitEnabled) control |= 0x02;
        break;
    }

    // Pack aircraftLengthWidth
    final aircraftLengthWidth = (aircraftLength << 1) | aircraftWidth;

    // Pack gpsAntennaOffset
    final gpsLonEncoded =
        gpsLonOffsetMeters == 0 ? 0 : (gpsLonOffsetMeters ~/ 2) + 1;
    final gpsAntennaOffset = (gpsLatOffset << 5) | gpsLonEncoded;

    // Convert stallSpeed
    final stallSpeed = _stallSpeedToDevice(stallSpeedKnots);

    // Convert ICAO addresses
    final icaoInt = _hexToInt(icaoAddress);
    final filterIcaoInt =
        ownshipFilterIcao.isNotEmpty ? _hexToInt(ownshipFilterIcao) : null;
    final filterFlarmIdInt = ownshipFilterFlarmId != null
        ? _hexToInt(ownshipFilterFlarmId!)
        : null;

    return {
      'setup': {
        'icaoAddress': icaoInt,
        'callsign': callsign.toUpperCase(),
        'emitterCategory': emitterCategory,
        'adsbInCapability': adsbInCapability,
        'aircraftLengthWidth': aircraftLengthWidth,
        'gpsAntennaOffset': gpsAntennaOffset,
        'SIL': sil,
        'SDA': sda,
        'stallSpeed': stallSpeed,
        'vfrSquawk': vfrSquawk,
        'control': control,
      },
      'ownshipFilter': {
        'icaoAddress': filterIcaoInt,
        'flarmId': filterFlarmIdInt,
      },
    };
  }

  /// Creates copy of SetupConfig with updated fields.
  ///
  /// Used by SetupUpdate builder to create modified configurations.
  SetupConfig copyWith({
    String? icaoAddress,
    String? callsign,
    int? emitterCategory,
    bool? uatEnabled,
    bool? es1090Enabled,
    bool? es1090TransmitEnabled,
    ReceiverMode? receiverMode,
    int? aircraftLength,
    int? aircraftWidth,
    int? gpsLatOffset,
    int? gpsLonOffsetMeters,
    int? sil,
    int? sda,
    double? stallSpeedKnots,
    int? vfrSquawk,
    String? ownshipFilterIcao,
    String? ownshipFilterFlarmId,
  }) {
    return SetupConfig(
      icaoAddress: icaoAddress ?? this.icaoAddress,
      callsign: callsign ?? this.callsign,
      emitterCategory: emitterCategory ?? this.emitterCategory,
      uatEnabled: uatEnabled ?? this.uatEnabled,
      es1090Enabled: es1090Enabled ?? this.es1090Enabled,
      es1090TransmitEnabled:
          es1090TransmitEnabled ?? this.es1090TransmitEnabled,
      receiverMode: receiverMode ?? this.receiverMode,
      aircraftLength: aircraftLength ?? this.aircraftLength,
      aircraftWidth: aircraftWidth ?? this.aircraftWidth,
      gpsLatOffset: gpsLatOffset ?? this.gpsLatOffset,
      gpsLonOffsetMeters: gpsLonOffsetMeters ?? this.gpsLonOffsetMeters,
      sil: sil ?? this.sil,
      sda: sda ?? this.sda,
      stallSpeedKnots: stallSpeedKnots ?? this.stallSpeedKnots,
      vfrSquawk: vfrSquawk ?? this.vfrSquawk,
      ownshipFilterIcao: ownshipFilterIcao ?? this.ownshipFilterIcao,
      ownshipFilterFlarmId:
          ownshipFilterFlarmId ?? this.ownshipFilterFlarmId,
    );
  }

  /// Applies validation to all fields.
  ///
  /// Throws [SkyEchoFieldError] if any field is invalid.
  void validate() {
    SkyEchoValidation.validateIcaoHex(icaoAddress);
    SkyEchoValidation.validateCallsign(callsign);
    SkyEchoValidation.validateEmitterCategory(emitterCategory);
    SkyEchoValidation.validateStallSpeed(stallSpeedKnots);
    SkyEchoValidation.validateVfrSquawk(vfrSquawk);
    SkyEchoValidation.validateGpsLatOffset(gpsLatOffset);
    SkyEchoValidation.validateGpsLonOffset(gpsLonOffsetMeters);
    SkyEchoValidation.validateAircraftLength(aircraftLength);
    SkyEchoValidation.validateAircraftWidth(aircraftWidth);
    SkyEchoValidation.validateIcaoHex(ownshipFilterIcao);
    if (ownshipFilterFlarmId != null) {
      SkyEchoValidation.validateIcaoHex(ownshipFilterFlarmId!);
    }
  }
}

/// Builder for creating SetupConfig updates.
///
/// Provides type-safe field updates with automatic validation.
/// Usage:
/// ```dart
/// final update = SetupUpdate()
///   ..icaoAddress = '7CC599'
///   ..callsign = 'TEST123'
///   ..stallSpeedKnots = 50.0;
/// ```
class SetupUpdate {
  /// ICAO address update (hex string).
  String? icaoAddress;

  /// Callsign update.
  String? callsign;

  /// Emitter category update.
  int? emitterCategory;

  /// UAT enabled update.
  bool? uatEnabled;

  /// 1090ES enabled update.
  bool? es1090Enabled;

  /// 1090ES transmit enabled update.
  bool? es1090TransmitEnabled;

  /// Receiver mode update.
  ReceiverMode? receiverMode;

  /// Aircraft length update.
  int? aircraftLength;

  /// Aircraft width update.
  int? aircraftWidth;

  /// GPS latitude offset update.
  int? gpsLatOffset;

  /// GPS longitude offset update.
  int? gpsLonOffsetMeters;

  /// SIL update.
  int? sil;

  /// SDA update.
  int? sda;

  /// Stall speed update (knots).
  double? stallSpeedKnots;

  /// VFR squawk update.
  int? vfrSquawk;

  /// Ownship filter ICAO update.
  String? ownshipFilterIcao;

  /// Ownship filter FLARM ID update.
  String? ownshipFilterFlarmId;
}

/// Result of applying setup configuration to device.
///
/// Indicates whether update succeeded and verification status.
class ApplyResult {
  /// Creates ApplyResult with given fields.
  ApplyResult({
    required this.success,
    required this.verified,
    this.verifiedConfig,
    this.message,
    this.mismatches = const {},
  });

  /// Whether POST request succeeded (200 OK).
  final bool success;

  /// Whether verification GET confirmed changes were applied.
  final bool verified;

  /// Configuration returned by verification GET (if performed).
  final SetupConfig? verifiedConfig;

  /// Optional message providing additional context.
  final String? message;

  /// Map of field mismatches (field name → [expected, actual]).
  ///
  /// Empty if verified is true, populated with discrepancies if false.
  final Map<String, List<dynamic>> mismatches;
}
