import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../framer.dart';
import '../models/gdl90_event.dart';
import '../parser.dart';

/// Function signature for binding UDP sockets.
///
/// Matches the signature of [RawDatagramSocket.bind] including default
/// parameters. This allows tests to inject a mock binder that returns a fake
/// socket without calling the real network bind operation.
typedef UdpBinder = Future<RawDatagramSocket> Function(
  dynamic host,
  int port, {
  bool reuseAddress,
  bool reusePort,
  int ttl,
});

/// GDL90 UDP stream receiver that integrates framing and parsing into a Dart
/// Stream API.
///
/// Provides lifecycle management (start/stop/dispose), backpressure support, and
/// error resilience for receiving GDL90 messages over UDP.
///
/// **Lifecycle**:
/// ```dart
/// final stream = Gdl90Stream(host: '192.168.4.1', port: 4000);
/// await stream.start();
///
/// stream.events.listen((event) {
///   if (event is Gdl90DataEvent) {
///     print('Received message: ${event.message.messageType}');
///   }
/// });
///
/// await stream.stop();   // Pause streaming (can restart)
/// await stream.dispose(); // Final cleanup (cannot restart)
/// ```
///
/// **Thread Safety**: Not thread-safe. Use from single isolate only.
class Gdl90Stream {
  final String _host;
  final int _port;
  final UdpBinder _binder;
  late final StreamController<Gdl90Event> _controller;
  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _subscription;
  final Gdl90Framer _framer = Gdl90Framer();

  // State flags
  bool _isRunning = false;
  bool _startInProgress = false; // Async lock for concurrent start()
  bool _isDisposed = false; // Prevents use-after-dispose

  /// Creates a GDL90 stream receiver for the specified host and port.
  ///
  /// **Parameters**:
  /// - [host]: Local interface to bind to. Use '0.0.0.0' for any interface,
  ///   or a specific IP like '192.168.4.100' to bind to one interface.
  ///   Default: '0.0.0.0' (any interface)
  /// - [port]: UDP port (typically 4000 for GDL90)
  /// - [binder]: Optional UDP socket binder (defaults to
  ///   [RawDatagramSocket.bind]). Inject a custom binder in tests to avoid
  ///   real network I/O.
  Gdl90Stream({
    String host = '0.0.0.0',
    required int port,
    UdpBinder? binder,
  })  : _host = host,
        _port = port,
        _binder = binder ?? RawDatagramSocket.bind {
    _initController();
  }

  /// Test constructor - injectable socket for unit testing.
  ///
  /// **WARNING**: This constructor is for testing only. Do not use in
  /// production.
  ///
  /// **Parameters**:
  /// - [socket]: Pre-constructed socket (typically a mock/fake for testing)
  /// - [binder]: Optional binder that throws if called (diagnostic guard).
  ///   If not provided, defaults to a guard that throws [StateError]
  ///   if invoked.
  Gdl90Stream.withSocket(RawDatagramSocket socket, {UdpBinder? binder})
      : _host = 'test',
        _port = 0,
        _socket = socket,
        _binder = binder ??
            ((_, __, {reuseAddress = true, reusePort = false, ttl = 1}) async {
              throw StateError('Binder must not be called when socket is '
                  'injected via withSocket()');
            }) {
    // CRITICAL: Must call _initController() to initialize StreamController
    // Without this, accessing .events will throw LateInitializationError
    _initController();
  }

  /// Initializes StreamController with re-entrancy safety and lifecycle
  /// callbacks. Shared between main and test constructors to avoid duplication.
  void _initController() {
    // CRITICAL: sync: false prevents re-entrancy into Gdl90Framer
    // Framer throws StateError if addBytes() called re-entrantly
    // (framer.dart:51-54). Async delivery ensures listener callbacks never
    // execute in same call stack
    _controller = StreamController<Gdl90Event>(
      sync: false, // Explicit async delivery for re-entrancy safety
      onPause: _handlePause,
      onResume: _handleResume,
      // No onCancel - explicit lifecycle management via dispose()
    );
  }

  /// Stream of GDL90 events (data, errors, or ignored messages).
  ///
  /// Events are delivered asynchronously (`sync: false`) to prevent framer
  /// re-entrancy.
  Stream<Gdl90Event> get events => _controller.stream;

  /// Returns true if the stream is actively receiving UDP datagrams.
  bool get isRunning => _isRunning;

  /// Starts receiving GDL90 UDP datagrams from the configured host/port.
  ///
  /// **Idempotent**: Safe to call multiple times (returns early if already
  /// running).
  ///
  /// **Throws**: [StateError] if called after [dispose()].
  Future<void> start() async {
    // Idempotent guard - safe to call multiple times sequentially
    if (_isRunning) return;

    // Disposed guard - prevent use-after-dispose
    if (_isDisposed) {
      throw StateError('Cannot start() after dispose(). '
          'Create a new Gdl90Stream instance.');
    }

    // Async lock - prevent concurrent start() calls
    if (_startInProgress) return; // Second call returns early

    try {
      _startInProgress = true;

      // Use injected binder to create socket if not already set
      _socket ??= await _binder(
        _host,
        _port,
        reuseAddress: true,
        reusePort: false,
        ttl: 1,
      );
      // CRITICAL: Store subscription for pause/resume and proper cleanup
      _subscription = _socket!.listen(_handleDatagram);
      _isRunning = true;
    } finally {
      _startInProgress = false; // Always clear lock, even on exception
    }
  }

  /// Stops receiving UDP datagrams and closes the socket.
  ///
  /// **Keep-Alive Pattern**: StreamController remains open for restart.
  /// Call [dispose()] for final cleanup.
  ///
  /// **Idempotent**: Safe to call multiple times.
  Future<void> stop() async {
    if (!_isRunning && _socket == null)
      return; // Only skip if truly nothing to clean up

    try {
      await _subscription?.cancel();
    } finally {
      _socket?.close();
      _socket = null;
      _subscription = null;
      _isRunning = false;
    }
  }

  /// Performs final cleanup and closes the StreamController.
  ///
  /// **WARNING**: After calling dispose(), the stream cannot be restarted.
  /// Create a new Gdl90Stream instance if needed.
  ///
  /// **Idempotent**: Safe to call multiple times.
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;
    await stop();
    // Close the controller but don't wait for completion.
    // For controllers with no listeners, close() may never complete in test
    // environments. The controller will be GC'd when the instance is released.
    unawaited(_controller.close());
  }

  void _handleDatagram(RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      final datagram = _socket!.receive();
      if (datagram != null) {
        _framer.addBytes(datagram.data, _handleFrame);
      }
    }
  }

  void _handleFrame(Uint8List frame) {
    final event = Gdl90Parser.parse(frame);
    _controller.add(event);
  }

  void _handlePause() {
    // Pause socket subscription to stop receiving UDP events
    _subscription?.pause();
  }

  void _handleResume() {
    // Resume socket subscription to restart UDP event flow
    _subscription?.resume();
  }
}
