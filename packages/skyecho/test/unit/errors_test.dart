// Unit tests for SkyEcho error hierarchy
// Promoted from scratch tests with Test Doc blocks

import 'package:skyecho/skyecho.dart';
import 'package:test/test.dart';

void main() {
  group('SkyEchoError hierarchy', () {
    test('given_error_with_hint_when_formatting_then_includes_hint_line', () {
      /*
      Test Doc:
      - Why: Validates core error formatting behavior with actionable hints
      - Contract: toString() returns "message\nHint: hint" when hint is non-empty
      - Usage Notes: All SkyEchoError subclasses support optional hint parameter
      - Quality Contribution: Catches regressions in error message formatting; ensures hints are visible to users
      - Worked Example: SkyEchoNetworkError('timeout', hint: 'check connection') → "timeout\nHint: check connection"
      */

      // Arrange
      final err =
          SkyEchoNetworkError('Connection failed', hint: 'Check WiFi settings');

      // Act
      final str = err.toString();

      // Assert
      expect(str, contains('Connection failed'));
      expect(str, contains('Hint:'));
      expect(str, contains('Check WiFi settings'));
    });

    test('given_error_without_hint_when_formatting_then_omits_hint_line', () {
      /*
      Test Doc:
      - Why: Ensures clean error messages when no hint is provided
      - Contract: toString() returns just message when hint is null
      - Usage Notes: Hint parameter is optional; omit when no actionable guidance available
      - Quality Contribution: Prevents confusing "Hint: " prefix when no hint exists
      - Worked Example: SkyEchoHttpError('404 Not Found') → "404 Not Found" (no Hint line)
      */

      // Arrange
      final err = SkyEchoHttpError('404 Not Found');

      // Act
      final str = err.toString();

      // Assert
      expect(str, contains('404 Not Found'));
      expect(str, isNot(contains('Hint:')));
    });

    test('given_empty_hint_when_formatting_then_behaves_like_null', () {
      /*
      Test Doc:
      - Why: Edge case - empty string hints should not display "Hint: " prefix
      - Contract: Empty string hint is treated as null (no Hint line in output)
      - Usage Notes: Avoid passing empty strings as hints; use null instead
      - Quality Contribution: Prevents UI clutter from empty hint strings
      - Worked Example: SkyEchoParseError('malformed', hint: '') → "malformed" (no Hint line)
      */

      // Arrange
      final err = SkyEchoParseError('Malformed HTML', hint: '');

      // Act
      final str = err.toString();

      // Assert
      expect(str, isNot(contains('Hint:')));
    });

    test('given_network_error_when_catching_then_is_skyecho_error', () {
      /*
      Test Doc:
      - Why: Validates polymorphic error handling works correctly
      - Contract: All error subclasses are catchable as SkyEchoError base type
      - Usage Notes: Use "on SkyEchoError catch (e)" to handle all library errors
      - Quality Contribution: Ensures type hierarchy allows unified error handling
      - Worked Example: try { throw SkyEchoNetworkError(...); } on SkyEchoError catch (e) { ... } succeeds
      */

      // Arrange & Act & Assert
      expect(() {
        try {
          throw SkyEchoNetworkError('Connection timeout');
        } on SkyEchoError catch (e) {
          expect(e.message, 'Connection timeout');
          return; // Success
        }
        // ignore: dead_code
        fail('Should have caught SkyEchoNetworkError as SkyEchoError');
      }, returnsNormally);
    });

    test('given_all_error_types_when_constructing_then_accept_hints', () {
      /*
      Test Doc:
      - Why: Regression test - ensures all subclasses support hint parameter
      - Contract: All 4 error subclasses accept optional hint in constructor
      - Usage Notes: NetworkError, HttpError, ParseError, FieldError all support hints
      - Quality Contribution: Catches if new error types omit hint support
      - Worked Example: Each of 4 error types constructed with hint → toString() contains "Hint:"
      */

      // Arrange
      final errors = [
        SkyEchoNetworkError('net', hint: 'check connection'),
        SkyEchoHttpError('http', hint: 'check status'),
        SkyEchoParseError('parse', hint: 'check HTML'),
        SkyEchoFieldError('field', hint: 'check form'),
      ];

      // Act & Assert
      for (final err in errors) {
        expect(err.toString(), contains('Hint:'));
      }
    });
  });
}
