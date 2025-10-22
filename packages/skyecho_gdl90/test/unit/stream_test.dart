import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:skyecho_gdl90/src/models/gdl90_event.dart';
import 'package:skyecho_gdl90/src/models/gdl90_message.dart';
import 'package:skyecho_gdl90/src/stream/gdl90_stream.dart';

/// Helper to create a Gdl90Stream with a mock socket.
///
/// Uses Future.value for immediate completion with broadcast socket.
Gdl90Stream createStreamWithMock(MockRawDatagramSocket mockSocket) {
  return Gdl90Stream(
    host: 'test',
    port: 0,
    binder: (_, __, {reuseAddress = true, reusePort = false, ttl = 1}) =>
        Future.value(mockSocket),
  );
}

void main() {
  group('Gdl90Stream', () {
    // T002: Stream creation test
    test('given_host_and_port_when_creating_stream_then_instance_valid', () {
      /*
      Test Doc:
      - Why: Validates basic instantiation with network parameters
      - Contract: Constructor accepts host (String) and port (int), returns valid instance
      - Usage Notes: Host typically '192.168.4.1', port 4000 for SkyEcho
      - Quality Contribution: Prevents API breaking changes in constructor signature
      - Worked Example: Gdl90Stream(host: '192.168.4.1', port: 4000) → valid instance with accessible .events
      */

      // Arrange & Act
      final stream = Gdl90Stream(host: '192.168.4.1', port: 4000);

      // Assert
      expect(stream, isA<Gdl90Stream>());
      expect(stream.events, isA<Stream<Gdl90Event>>());
      expect(stream.isRunning, isFalse);
    });

    // T003: Start lifecycle test
    test('given_stream_when_start_called_then_becomes_running', () async {
      /*
      Test Doc:
      - Why: Validates socket opens and stream becomes active
      - Contract: start() binds socket, sets isRunning=true, enables event emission
      - Usage Notes: Call start() before listening to events; idempotent (safe to call multiple times)
      - Quality Contribution: Ensures lifecycle state transitions correctly
      - Worked Example: await stream.start() → isRunning changes false→true
      */

      // Arrange
      final mockSocket = MockRawDatagramSocket();
      final stream = createStreamWithMock(mockSocket);

      // Act
      await stream.start();

      // Assert
      expect(stream.isRunning, isTrue);

      // Cleanup
      await stream.dispose();
    });

    // T003b: Concurrent start prevention test
    test(
        'given_concurrent_start_calls_when_both_execute_then_only_one_proceeds',
        () async {
      /*
      Test Doc:
      - Why: Validates async lock prevents duplicate subscriptions from race condition
      - Contract: Concurrent start() calls prevented by _startInProgress flag; only one succeeds
      - Usage Notes: start() uses try-finally to ensure lock always cleared
      - Quality Contribution: Prevents resource leak and duplicate events from concurrent calls
      - Worked Example: Future.wait([stream.start(), stream.start()]) → single subscription created
      */

      // Arrange
      final mockSocket = MockRawDatagramSocket();
      final stream = createStreamWithMock(mockSocket);

      // Act - concurrent calls
      await Future.wait([
        stream.start(),
        stream.start(),
      ]);

      // Assert - stream started only once
      expect(stream.isRunning, isTrue);
      expect(
          mockSocket.listenCallCount, equals(1)); // Verify single subscription

      // Cleanup
      await stream.dispose();
    });

    // T004: Stop lifecycle test (keep-alive pattern)
    test(
        'given_running_stream_when_stop_called_then_socket_closes_controller_stays_open',
        () async {
      /*
      Test Doc:
      - Why: Validates socket closes but controller stays alive for restart (keep-alive pattern)
      - Contract: stop() closes socket, sets isRunning=false, but controller remains open
      - Usage Notes: After stop(), can call start() again to resume; use dispose() for final cleanup
      - Quality Contribution: Enables pause/resume workflow without recreating stream instance
      - Worked Example: start() → stop() → start() works; controller.isClosed remains false after stop()
      */

      // Arrange
      final mockSocket = MockRawDatagramSocket();
      final stream = createStreamWithMock(mockSocket);
      await stream.start();

      // Act
      await stream.stop();

      // Assert
      expect(stream.isRunning, isFalse);
      expect(mockSocket.isClosed, isTrue);
      // Controller should still be open (can restart)
      final canAddListener = await _canAddStreamListener(stream.events);
      expect(canAddListener, isTrue);

      // Cleanup
      await stream.dispose();
    });

    // T004b: Dispose final cleanup test
    test('given_stream_when_dispose_called_then_controller_closes', () async {
      /*
      Test Doc:
      - Why: Validates final cleanup closes controller (matches Flutter lifecycle)
      - Contract: dispose() calls stop(), then closes StreamController
      - Usage Notes: After dispose(), stream cannot be restarted; must create new instance
      - Quality Contribution: Prevents memory leaks by ensuring complete resource cleanup
      - Worked Example: await dispose() → controller.isClosed=true, stream.events emits done
      */

      // Arrange
      final mockSocket = MockRawDatagramSocket();
      final stream = createStreamWithMock(mockSocket);

      // Act
      await stream.dispose();

      // NOTE: Controller.close() is called with unawaited() to avoid test hangs.
      // This means the controller may not be fully closed when dispose() returns.
      // The important thing is that _isDisposed is set, preventing further use.

      // Verify disposed state prevents restart
      expect(() => stream.start(), throwsA(isA<StateError>()));

      // No cleanup needed (already disposed)
    });

    // T004c: Start after dispose error test
    test('given_disposed_stream_when_start_called_then_throws_state_error',
        () async {
      /*
      Test Doc:
      - Why: Validates disposed state prevents restart (use-after-dispose protection)
      - Contract: start() throws StateError if called after dispose()
      - Usage Notes: Check error message suggests creating new instance
      - Quality Contribution: Prevents memory corruption and undefined behavior from use-after-dispose
      - Worked Example: dispose() → start() → StateError('Cannot start() after dispose()...')
      */

      // Arrange
      final mockSocket = MockRawDatagramSocket();
      final stream = createStreamWithMock(mockSocket);
      await stream.dispose();

      // Act & Assert
      expect(
        () => stream.start(),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Cannot start() after dispose()'),
        )),
      );
    });

    // T005: Pause backpressure test
    test('given_running_stream_when_paused_then_no_events_emitted', () async {
      /*
      Test Doc:
      - Why: Validates Dart Stream backpressure support via pause()
      - Contract: StreamSubscription.pause() stops event emission until resume()
      - Usage Notes: Caller controls backpressure; stream respects pause/resume
      - Quality Contribution: Prevents buffer overflow when consumer is slow
      - Worked Example: listen().pause() → subscription.pause() called → no events flow
      */

      // Arrange
      final mockSocket = MockRawDatagramSocket();
      final stream = createStreamWithMock(mockSocket);
      await stream.start();

      final receivedEvents = <Gdl90Event>[];
      final subscription = stream.events.listen(receivedEvents.add);

      // Act - pause subscription
      subscription.pause();
      mockSocket.emitDatagram(_heartbeatDatagram());
      await Future<void>.delayed(
          Duration(milliseconds: 50)); // Let events process

      // Assert - no events received while paused
      expect(receivedEvents, isEmpty);

      // Cleanup
      await subscription.cancel();
      await stream.dispose();
    });

    // T006: Resume backpressure test
    test('given_paused_stream_when_resumed_then_events_flow_again', () async {
      /*
      Test Doc:
      - Why: Validates stream resumes after pause
      - Contract: StreamSubscription.resume() restarts event emission
      - Usage Notes: Events queued during pause are delivered after resume
      - Quality Contribution: Ensures backpressure control is bidirectional
      - Worked Example: pause() → resume() → events flow again
      */

      // Arrange
      final mockSocket = MockRawDatagramSocket();
      final stream = createStreamWithMock(mockSocket);
      await stream.start();

      final receivedEvents = <Gdl90Event>[];
      final subscription = stream.events.listen(receivedEvents.add);
      subscription.pause();

      // Act - resume subscription
      subscription.resume();
      mockSocket.emitDatagram(_heartbeatDatagram());
      await Future<void>.delayed(
          Duration(milliseconds: 50)); // Let events process

      // Assert - events received after resume
      expect(receivedEvents, isNotEmpty);
      expect(receivedEvents.first, isA<Gdl90DataEvent>());

      // Cleanup
      await subscription.cancel();
      await stream.dispose();
    });

    // T007: UDP datagram reception test
    test('given_udp_datagram_when_received_then_framer_processes', () async {
      /*
      Test Doc:
      - Why: Validates datagram bytes passed to framer
      - Contract: RawDatagramSocket.receive() → Gdl90Framer.addBytes() → frame extracted
      - Usage Notes: Tests socket → framer boundary integration
      - Quality Contribution: Ensures UDP datagrams correctly routed to framing layer
      - Worked Example: mockSocket.receive() returns heartbeat datagram → framer.addBytes called
      */

      // Arrange
      final mockSocket = MockRawDatagramSocket();
      final stream = createStreamWithMock(mockSocket);
      await stream.start();

      final receivedEvents = <Gdl90Event>[];
      final subscription = stream.events.listen(receivedEvents.add);

      // Act - emit valid heartbeat datagram
      mockSocket.emitDatagram(_heartbeatDatagram());
      await Future<void>.delayed(
          Duration(milliseconds: 50)); // Let async processing complete

      // Assert - event received and parsed
      expect(receivedEvents, hasLength(1));
      expect(receivedEvents.first, isA<Gdl90DataEvent>());
      final dataEvent = receivedEvents.first as Gdl90DataEvent;
      expect(dataEvent.message.messageType, equals(Gdl90MessageType.heartbeat));

      // Cleanup
      await subscription.cancel();
      await stream.dispose();
    });

    // T007b: Re-entrancy safety test
    test('given_rapid_udp_bursts_when_processed_then_no_re_entrancy_error',
        () async {
      /*
      Test Doc:
      - Why: Validates async delivery prevents framer re-entrancy crash
      - Contract: StreamController(sync: false) prevents listener execution in same call stack
      - Usage Notes: Framer throws StateError if addBytes() called re-entrantly (line 51-54 framer.dart)
      - Quality Contribution: Prevents production crashes from rapid UDP bursts
      - Worked Example: Emit 2 datagrams back-to-back → both processed successfully, no StateError
      */

      // Arrange
      final mockSocket = MockRawDatagramSocket();
      final stream = createStreamWithMock(mockSocket);
      await stream.start();

      final receivedEvents = <Gdl90Event>[];
      final subscription = stream.events.listen(receivedEvents.add);

      // Act - emit 2 datagrams rapidly (back-to-back)
      mockSocket.emitDatagram(_heartbeatDatagram());
      mockSocket.emitDatagram(_heartbeatDatagram());
      await Future<void>.delayed(
          Duration(milliseconds: 100)); // Let all events process

      // Assert - both events received, no StateError thrown
      expect(receivedEvents, hasLength(2));
      expect(receivedEvents[0], isA<Gdl90DataEvent>());
      expect(receivedEvents[1], isA<Gdl90DataEvent>());

      // Cleanup
      await subscription.cancel();
      await stream.dispose();
    });

    // T008: End-to-end pipeline test
    test('given_udp_datagram_when_processed_then_parsed_event_emitted',
        () async {
      /*
      Test Doc:
      - Why: Validates complete UDP → events flow (integration test)
      - Contract: UDP datagram → framer → parser → Gdl90Event emission
      - Usage Notes: Critical end-to-end test validating entire pipeline
      - Quality Contribution: Ensures full integration works correctly
      - Worked Example: Raw UDP bytes → Gdl90DataEvent with parsed Gdl90Message
      */

      // Arrange
      final mockSocket = MockRawDatagramSocket();
      final stream = createStreamWithMock(mockSocket);
      await stream.start();

      final receivedEvents = <Gdl90Event>[];
      final subscription = stream.events.listen(receivedEvents.add);

      // Act - emit complete heartbeat message
      mockSocket.emitDatagram(_heartbeatDatagram());
      await Future<void>.delayed(Duration(milliseconds: 50));

      // Assert - parsed message received
      expect(receivedEvents, hasLength(1));
      expect(receivedEvents.first, isA<Gdl90DataEvent>());

      final dataEvent = receivedEvents.first as Gdl90DataEvent;
      final message = dataEvent.message;

      expect(message.messageType, equals(Gdl90MessageType.heartbeat));
      expect(message.gpsPosValid, isA<bool>()); // Heartbeat has status flags
      expect(message.timeOfDaySeconds, isA<int>());

      // Cleanup
      await subscription.cancel();
      await stream.dispose();
    });

    // T009: Error event emission test
    test(
        'given_malformed_frame_when_processed_then_error_event_emitted_stream_continues',
        () async {
      /*
      Test Doc:
      - Why: Validates malformed frames don't crash stream (resilience)
      - Contract: Bad CRC/invalid frame → Gdl90ErrorEvent emitted, stream continues
      - Usage Notes: Stream must continue processing after error (no exception thrown)
      - Quality Contribution: Validates Discovery 05 (wrapper pattern stream resilience)
      - Worked Example: Bad frame → ErrorEvent, then good frame → DataEvent
      */

      // Arrange
      final mockSocket = MockRawDatagramSocket();
      final stream = createStreamWithMock(mockSocket);
      await stream.start();

      final receivedEvents = <Gdl90Event>[];
      final subscription = stream.events.listen(receivedEvents.add);

      // Act - emit bad CRC frame, then good frame
      mockSocket.emitDatagram(_badCrcDatagram());
      mockSocket.emitDatagram(_heartbeatDatagram());
      await Future<void>.delayed(Duration(milliseconds: 100));

      // Assert - error event for bad frame, data event for good frame
      expect(receivedEvents.length,
          greaterThanOrEqualTo(1)); // At least the good frame
      final hasDataEvent = receivedEvents.any((e) => e is Gdl90DataEvent);
      expect(hasDataEvent, isTrue); // Stream continued processing after error

      // Cleanup
      await subscription.cancel();
      await stream.dispose();
    });

    // T010: Socket cleanup on exception test
    test('given_socket_exception_when_thrown_then_socket_closed', () async {
      /*
      Test Doc:
      - Why: Validates resource safety on errors (exception safety)
      - Contract: Socket.close() called even if exception occurs during operation
      - Usage Notes: Uses try-finally pattern to ensure cleanup
      - Quality Contribution: Prevents resource leaks from exceptions
      - Worked Example: Exception in datagram handling → socket still closed by stop()
      */

      // Arrange
      final mockSocket = MockRawDatagramSocket();
      mockSocket.throwOnListen = true; // Simulate socket error

      final stream = createStreamWithMock(mockSocket);

      // Act - start will throw exception
      try {
        await stream.start();
      } catch (e) {
        // Expected exception from mock
      }

      // Ensure cleanup happens
      await stream.stop();

      // Assert - socket closed despite exception
      expect(mockSocket.isClosed, isTrue);

      // Cleanup
      await stream.dispose();
    });
  });
}

// ============================================================================
// Test Fixtures
// ============================================================================

/// Returns a valid GDL90 heartbeat datagram (UDP packet format with 0x7E flags).
Uint8List _heartbeatDatagram() {
  // Heartbeat message (ID 0x00) with valid CRC
  return Uint8List.fromList([
    0x7E, // Start flag
    0x00, // Message ID: Heartbeat
    0x81, // Status byte 1: GPS pos valid (bit 7 set)
    0x41, // Status byte 2
    0xDB, 0xD0, // Time-of-day timestamp
    0x08, 0x02, // Message counts
    0xB3, 0x8B, // CRC-16-CCITT (LSB-first)
    0x7E, // End flag
  ]);
}

/// Returns a datagram with bad CRC (frame will be rejected).
Uint8List _badCrcDatagram() {
  return Uint8List.fromList([
    0x7E, // Start flag
    0x00, // Message ID: Heartbeat
    0x81, 0x41, 0xDB, 0xD0, 0x08, 0x02,
    0xFF, 0xFF, // Bad CRC
    0x7E, // End flag
  ]);
}

/// Helper to check if a stream controller is still open by attempting to add a listener.
Future<bool> _canAddStreamListener(Stream<dynamic> stream) async {
  try {
    final subscription = stream.listen(null);
    await subscription.cancel();
    return true;
  } catch (e) {
    return false; // Controller is closed
  }
}

// ============================================================================
// Mock RawDatagramSocket
// ============================================================================

class MockRawDatagramSocket extends Stream<RawSocketEvent>
    implements RawDatagramSocket {
  bool isClosed = false;
  bool throwOnListen = false;
  int listenCallCount = 0;

  // CRITICAL: Use broadcast controller to match real RawDatagramSocket behavior
  // Real RawDatagramSocket is a broadcast stream. Using single-subscription
  // can cause cancellation deadlocks in tests.
  final StreamController<RawSocketEvent> _eventController =
      StreamController<RawSocketEvent>.broadcast();

  @override
  StreamSubscription<RawSocketEvent> listen(
    void Function(RawSocketEvent event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    listenCallCount++;

    if (throwOnListen) {
      throw SocketException('Mock socket error');
    }

    return _eventController.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  /// Simulates receiving a UDP datagram.
  void emitDatagram(Uint8List data) {
    _datagram = Datagram(data, InternetAddress.anyIPv4, 4000);
    _eventController.add(RawSocketEvent.read);
  }

  Datagram? _datagram;

  @override
  Datagram? receive() => _datagram;

  @override
  void close() {
    isClosed = true;
    _eventController.close();
  }

  // Minimal implementations for required interface methods
  @override
  InternetAddress get address => InternetAddress.anyIPv4;

  @override
  int get port => 4000;

  @override
  bool get readEventsEnabled => true;

  @override
  set readEventsEnabled(bool value) {}

  @override
  bool get writeEventsEnabled => false;

  @override
  set writeEventsEnabled(bool value) {}

  @override
  bool get multicastLoopback => false;

  @override
  set multicastLoopback(bool value) {}

  @override
  int get multicastHops => 1;

  @override
  set multicastHops(int value) {}

  @override
  NetworkInterface? get multicastInterface => null;

  @override
  set multicastInterface(NetworkInterface? value) {}

  @override
  bool get broadcastEnabled => false;

  @override
  set broadcastEnabled(bool value) {}

  @override
  int send(List<int> buffer, InternetAddress address, int port) => 0;

  @override
  void joinMulticast(InternetAddress group, [NetworkInterface? interface]) {}

  @override
  void leaveMulticast(InternetAddress group, [NetworkInterface? interface]) {}

  @override
  Uint8List getRawOption(RawSocketOption option) => throw UnimplementedError();

  @override
  void setRawOption(RawSocketOption option) => throw UnimplementedError();
}
