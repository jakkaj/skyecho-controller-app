// Unit tests for SkyEchoClient
// Promoted from scratch tests with Test Doc blocks

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skyecho/skyecho.dart';
import 'package:test/test.dart';

void main() {
  group('SkyEchoClient', () {
    test('given_200_response_when_pinging_then_succeeds', () async {
      /*
      Test Doc:
      - Why: Critical path - validates successful connectivity check
      - Contract: ping() completes without throwing when device returns 200 OK
      - Usage Notes: ping() is the first method called to verify device availability
      - Quality Contribution: Ensures basic happy path works; catches HTTP handling regressions
      - Worked Example: MockClient returns 200 → ping() completes normally
      */

      // Arrange
      final mockClient = MockClient((request) async {
        return http.Response('OK', 200);
      });
      final client = SkyEchoClient('http://test', httpClient: mockClient);

      // Act & Assert
      await expectLater(client.ping(), completes);
    });

    test('given_404_response_when_pinging_then_throws_http_error', () async {
      /*
      Test Doc:
      - Why: Error handling - validates non-200 status codes are caught
      - Contract: ping() throws SkyEchoHttpError when response status is not 200
      - Usage Notes: HTTP errors include status code and actionable hint
      - Quality Contribution: Ensures error handling for device firmware issues or wrong URLs
      - Worked Example: MockClient returns 404 → throws SkyEchoHttpError with status code
      */

      // Arrange
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });
      final client = SkyEchoClient('http://test', httpClient: mockClient);

      // Act & Assert
      await expectLater(
        client.ping(),
        throwsA(isA<SkyEchoHttpError>()),
      );
    });

    test('given_network_failure_when_pinging_then_throws_network_error',
        () async {
      /*
      Test Doc:
      - Why: Error handling - validates network-level failures are wrapped properly
      - Contract: ping() throws SkyEchoNetworkError on ClientException (timeout, DNS, connection refused)
      - Usage Notes: Network errors include actionable hints about WiFi/IP configuration
      - Quality Contribution: Ensures network exceptions are translated to library errors
      - Worked Example: MockClient throws ClientException → throws SkyEchoNetworkError with hint
      */

      // Arrange
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });
      final client = SkyEchoClient('http://test', httpClient: mockClient);

      // Act & Assert
      await expectLater(
        client.ping(),
        throwsA(isA<SkyEchoNetworkError>()),
      );
    });

    test('given_set_cookie_in_response_when_pinging_then_stores_cookie',
        () async {
      /*
      Test Doc:
      - Why: Critical path - validates session cookie persistence across requests
      - Contract: Cookies from Set-Cookie header are stored and sent in subsequent requests
      - Usage Notes: SkyEcho requires session cookies for state; client manages them automatically
      - Quality Contribution: Ensures multi-request workflows work (setup forms require sessions)
      - Worked Example: First ping() gets Set-Cookie: sess=abc → second ping() sends Cookie: sess=abc
      */

      // Arrange
      var requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          // First request: set cookie
          return http.Response('OK', 200,
              headers: {'set-cookie': 'sess=abc123'});
        }
        // Second request: verify cookie sent
        expect(request.headers['cookie'], 'sess=abc123');
        return http.Response('OK', 200);
      });
      final client = SkyEchoClient('http://test', httpClient: mockClient);

      // Act
      await client.ping(); // Sets cookie
      await client.ping(); // Should send cookie

      // Assert
      expect(requestCount, 2);
    });

    test('given_custom_timeout_when_constructing_then_uses_timeout', () {
      /*
      Test Doc:
      - Why: Opaque behavior - documents timeout configuration
      - Contract: SkyEchoClient accepts custom timeout via constructor
      - Usage Notes: Default is 5 seconds; increase for slow networks
      - Quality Contribution: Documents timeout configuration; prevents breaking changes to API
      - Worked Example: SkyEchoClient('url', timeout: Duration(seconds: 10)) → client.timeout == 10s
      */

      // Arrange & Act
      final client =
          SkyEchoClient('http://test', timeout: const Duration(seconds: 10));

      // Assert
      expect(client.timeout, const Duration(seconds: 10));
    });

    test('F1: applySetup detects mismatches between POST and verification GET',
        () async {
      /*
      Test Doc:
      - Why: Critical safety - validates POST verification detects silent device rejections
      - Contract: applySetup() compares newConfig vs verifiedConfig, sets verified=false on mismatch
      - Usage Notes: Device may silently truncate callsign "N12345" → "N1234" or reject other fields
      - Quality Contribution: Prevents silent data corruption; surfaces config rejection to caller
      - Worked Example: POST callsign="TOOLONG" → GET returns callsign="TOOLON" → verified=false, mismatches={'callsign': ['TOOLONG', 'TOOLON']}
      */

      // Arrange - Sample config JSON
      final sampleConfigJson = {
        'setup': {
          'icaoAddress': 8177049,
          'callsign': 'TEST',
          'emitterCategory': 1,
          'adsbInCapability': 1,
          'aircraftLengthWidth': 1,
          'gpsAntennaOffset': 128,
          'SIL': 1,
          'SDA': 1,
          'stallSpeed': 23148,
          'vfrSquawk': 1200,
          'control': 1,
        },
        'ownshipFilter': {'icaoAddress': 8177049, 'flarmId': null},
      };

      final mockClient = MockClient((request) async {
        if (request.method == 'GET' && request.url.path.contains('get')) {
          // First GET: return original config
          return http.Response(
            json.encode(sampleConfigJson),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.method == 'POST') {
          // POST: accept the update
          return http.Response('OK', 200);
        } else if (request.method == 'GET') {
          // Verification GET: return modified config (device truncated callsign)
          final modifiedJson = Map<String, dynamic>.from(sampleConfigJson);
          modifiedJson['setup'] = Map<String, dynamic>.from(
              modifiedJson['setup'] as Map<String, dynamic>)
            ..['callsign'] = 'TOOLON'; // Truncated!
          return http.Response(
            json.encode(modifiedJson),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = SkyEchoClient('http://test', httpClient: mockClient);

      // Act - Try to set callsign to "TOOLONG"
      final result = await client.applySetup((u) => u..callsign = 'TOOLONG');

      // Assert
      expect(result.success, isTrue); // POST succeeded
      expect(result.verified, isFalse); // But verification detected mismatch
      expect(result.mismatches, isNotEmpty);
      expect(result.mismatches, containsPair('callsign', ['TOOLONG', 'TOOLON']));
      expect(result.message, contains('mismatch'));
    });
  });
}
