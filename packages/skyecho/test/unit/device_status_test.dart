import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skyecho/skyecho.dart';
import 'package:test/test.dart';

void main() {
  group('DeviceStatus.fromJson - JSON parsing', () {
    test(
        'given_json_fixture_when_parsing_then_extracts_all_fields',
        () {
      /*
      Test Doc:
      - Why: Validates JSON parsing logic for device status (critical path)
      - Contract: DeviceStatus.fromJson extracts all 6 fields from JSON map;
        missing fields return null
      - Usage Notes: Pass JSON map from json.decode(); parser tolerates
        missing optional fields
      - Quality Contribution: Catches JSON structure changes; documents
        field mappings
      - Worked Example: {"wifiVersion": "0.2.41", "clientCount": 1} →
        DeviceStatus(wifiVersion="0.2.41", clientsConnected=1)
      */

      // Arrange
      final fixture =
          File('test/fixtures/device_status_sample.json').readAsStringSync();
      final json = jsonDecode(fixture) as Map<String, dynamic>;

      // Act
      final status = DeviceStatus.fromJson(json);

      // Assert
      expect(status.wifiVersion, isNotNull);
      expect(status.wifiVersion, equals('0.2.41-SkyEcho'));
      expect(status.ssid, isNotNull);
      expect(status.ssid, equals('SkyEcho_3155'));
      expect(status.adsbVersion, isNotNull);
      expect(status.adsbVersion, equals('2.6.13'));
      expect(status.serialNumber, isNotNull);
      expect(status.serialNumber, equals('0655339053'));
      expect(status.clientsConnected, isA<int>());
      expect(status.clientsConnected, equals(1));
      expect(status.coredump, isA<bool>());
      expect(status.coredump, isFalse);
    });

    test('given_missing_fields_when_parsing_then_returns_null', () {
      /*
      Test Doc:
      - Why: Validates defensive parsing with missing fields (edge case)
      - Contract: DeviceStatus.fromJson handles missing fields gracefully,
        returns null for nullable fields
      - Usage Notes: All fields except coredump are nullable; coredump
        defaults to false
      - Quality Contribution: Ensures parser doesn't crash on incomplete JSON
      - Worked Example: {"wifiVersion": "0.2.41"} → all other fields null
      */

      // Arrange
      final json = <String, dynamic>{'wifiVersion': '0.2.41'};

      // Act
      final status = DeviceStatus.fromJson(json);

      // Assert
      expect(status.wifiVersion, equals('0.2.41'));
      expect(status.adsbVersion, isNull);
      expect(status.ssid, isNull);
      expect(status.clientsConnected, isNull);
      expect(status.serialNumber, isNull);
      expect(status.coredump, isFalse); // Default
    });

    test('given_malformed_json_when_parsing_then_throws_parse_error', () {
      /*
      Test Doc:
      - Why: Validates error handling for invalid JSON structure (edge case)
      - Contract: DeviceStatus.fromJson throws SkyEchoParseError on type
        mismatch
      - Usage Notes: Parser validates types; wrong types trigger error
      - Quality Contribution: Prevents silent failures from malformed device
        responses
      - Worked Example: {"clientCount": "not-a-number"} → SkyEchoParseError
      */

      // Arrange
      final json = <String, dynamic>{
        'clientCount': 'not-a-number', // Should be int
      };

      // Act & Assert
      expect(
        () => DeviceStatus.fromJson(json),
        throwsA(isA<SkyEchoParseError>()),
      );
    });
  });

  group('DeviceStatus - Computed properties', () {
    test('given_coredump_true_when_checking_hasCoredump_then_returns_true', () {
      /*
      Test Doc:
      - Why: Validates hasCoredump getter (opaque behavior)
      - Contract: hasCoredump returns true when coredump field is true
      - Usage Notes: Convenience getter for health monitoring
      - Quality Contribution: Documents coredump flag usage
      - Worked Example: coredump=true → hasCoredump=true
      */

      // Arrange
      final json = <String, dynamic>{'coredump': true};

      // Act
      final status = DeviceStatus.fromJson(json);

      // Assert
      expect(status.hasCoredump, isTrue);
    });

    test(
        'given_coredump_true_when_checking_isHealthy_then_returns_false',
        () {
      /*
      Test Doc:
      - Why: Validates isHealthy heuristic rejects unhealthy state
        (opaque behavior)
      - Contract: isHealthy=false when coredump=true, even with clients
      - Usage Notes: Coredump overrides client count in health check
      - Quality Contribution: Ensures health check prioritizes crash detection
      - Worked Example: coredump=true, clientsConnected=1 → isHealthy=false
      */

      // Arrange
      final json = <String, dynamic>{'coredump': true, 'clientCount': 1};

      // Act
      final status = DeviceStatus.fromJson(json);

      // Assert
      expect(status.isHealthy, isFalse);
      expect(status.hasCoredump, isTrue);
    });

    test(
        'given_no_coredump_and_clients_when_checking_isHealthy_then_returns_true',
        () {
      /*
      Test Doc:
      - Why: Validates isHealthy heuristic positive case (opaque behavior)
      - Contract: isHealthy=true when no coredump AND clientsConnected > 0
      - Usage Notes: Simple health heuristic for monitoring
      - Quality Contribution: Documents healthy state criteria
      - Worked Example: coredump=false, clientsConnected=1 → isHealthy=true
      */

      // Arrange
      final json = <String, dynamic>{'coredump': false, 'clientCount': 1};

      // Act
      final status = DeviceStatus.fromJson(json);

      // Assert
      expect(status.isHealthy, isTrue);
    });

    test(
        'given_no_clients_when_checking_isHealthy_then_returns_false',
        () {
      /*
      Test Doc:
      - Why: Validates isHealthy requires clients (edge case)
      - Contract: isHealthy=false when clientsConnected is null or 0
      - Usage Notes: Device needs active clients to be considered healthy
      - Quality Contribution: Documents client count requirement for health
      - Worked Example: coredump=false, clientsConnected=0 → isHealthy=false
      */

      // Arrange
      final json = <String, dynamic>{'coredump': false, 'clientCount': 0};

      // Act
      final status = DeviceStatus.fromJson(json);

      // Assert
      expect(status.isHealthy, isFalse);
    });
  });

  group('SkyEchoClient.fetchStatus - JSON API integration', () {
    test(
        'given_valid_json_response_when_fetching_status_then_returns_device_status',
        () async {
      /*
      Test Doc:
      - Why: Validates end-to-end JSON API integration (critical path)
      - Contract: fetchStatus() sends GET /?action=get, parses JSON,
        returns DeviceStatus
      - Usage Notes: Use MockClient for unit tests; real device for
        integration tests
      - Quality Contribution: Ensures JSON endpoint integration works correctly
      - Worked Example: Mock GET /?action=get returns JSON →
        DeviceStatus with all fields
      */

      // Arrange
      final mockClient = MockClient((request) async {
        if (request.url.path == '/' &&
            request.url.queryParameters['action'] == 'get') {
          final json = {
            'wifiVersion': '0.2.41-SkyEcho',
            'ssid': 'SkyEcho_3155',
            'clientCount': 1,
            'adsbVersion': '2.6.13',
            'serialNumber': '0655339053',
            'coredump': false,
          };
          return http.Response(jsonEncode(json), 200);
        }
        return http.Response('Not Found', 404);
      });

      final client = SkyEchoClient('http://test', httpClient: mockClient);

      // Act
      final status = await client.fetchStatus();

      // Assert
      expect(status.wifiVersion, equals('0.2.41-SkyEcho'));
      expect(status.ssid, equals('SkyEcho_3155'));
      expect(status.clientsConnected, equals(1));
      expect(status.adsbVersion, equals('2.6.13'));
      expect(status.serialNumber, equals('0655339053'));
      expect(status.coredump, isFalse);
    });

    test(
        'given_http_error_when_fetching_status_then_throws_http_error',
        () async {
      /*
      Test Doc:
      - Why: Validates HTTP error handling (error path)
      - Contract: fetchStatus() throws SkyEchoHttpError on non-200 status
      - Usage Notes: Check device accessibility before calling fetchStatus
      - Quality Contribution: Ensures proper error propagation for HTTP issues
      - Worked Example: Mock returns 500 → SkyEchoHttpError with hint
      */

      // Arrange
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final client = SkyEchoClient('http://test', httpClient: mockClient);

      // Act & Assert
      await expectLater(
        client.fetchStatus(),
        throwsA(isA<SkyEchoHttpError>()),
      );
    });

    test(
        'given_malformed_json_when_fetching_status_then_throws_parse_error',
        () async {
      /*
      Test Doc:
      - Why: Validates JSON parsing error handling (error path)
      - Contract: fetchStatus() throws SkyEchoParseError on invalid JSON
      - Usage Notes: Device firmware issues may return invalid JSON
      - Quality Contribution: Ensures actionable errors for malformed responses
      - Worked Example: Mock returns "{invalid-json}" → SkyEchoParseError
      */

      // Arrange
      final mockClient = MockClient((request) async {
        return http.Response('{invalid-json}', 200);
      });

      final client = SkyEchoClient('http://test', httpClient: mockClient);

      // Act & Assert
      await expectLater(
        client.fetchStatus(),
        throwsA(isA<SkyEchoParseError>()),
      );
    });
  });
}
