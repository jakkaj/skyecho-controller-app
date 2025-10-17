// Unit tests for SkyEchoClient
// Promoted from scratch tests with Test Doc blocks

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
  });
}
