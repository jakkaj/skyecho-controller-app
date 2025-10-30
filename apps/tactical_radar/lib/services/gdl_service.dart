import 'dart:async';

import 'package:skyecho_gdl90/skyecho_gdl90.dart';

import 'gdl_service_interface.dart';

/// Concrete implementation of GDL90 service layer.
///
/// Wraps Gdl90Stream from skyecho_gdl90 package and provides:
/// - Clean broadcast streams for UI consumption
/// - Connection health monitoring (10s stale data detection)
/// - Traffic target management with 30s expiry
/// - Sealed class event pattern matching (Discovery 01)
class GdlService implements GdlServiceInterface {
  /// Host to bind UDP socket (default: any interface).
  final String host;

  /// Port to listen for GDL90 data (default: 4000).
  final int port;

  // Internal state
  Gdl90Stream? _stream;
  StreamSubscription<Gdl90Event>? _subscription;

  // Stream controllers for exposing data
  final _messagesController = StreamController<Gdl90Message>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  // State tracking
  bool _isConnected = false;
  Gdl90Message? _lastOwnshipReport;
  final Map<int, Gdl90Message> _trafficTargets = {};
  Timer? _healthTimer;
  DateTime? _lastMessageTime;
  int _errorCount = 0;

  GdlService({
    this.host = '0.0.0.0',
    this.port = 4000,
  });

  @override
  Stream<Gdl90Message> get messages => _messagesController.stream;

  @override
  Stream<bool> get connectionStatus => _connectionController.stream;

  @override
  Stream<String> get errors => _errorController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  Gdl90Message? get lastOwnshipReport => _lastOwnshipReport;

  @override
  Map<int, Gdl90Message> get activeTrafficTargets =>
      Map.unmodifiable(_trafficTargets);

  @override
  Future<void> connect() async {
    if (_isConnected) return;

    try {
      _stream = Gdl90Stream(host: host, port: port);
      await _stream!.start();

      _subscription = _stream!.events.listen(
        _handleEvent,
        onError: _handleStreamError,
        onDone: _handleStreamClosed,
      );

      _isConnected = true;
      _connectionController.add(true);

      // Start health monitoring
      _startHealthMonitoring();
    } catch (e) {
      _errorController.add('Connection failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _healthTimer?.cancel();
    await _subscription?.cancel();
    await _stream?.stop();

    _isConnected = false;
    _connectionController.add(false);
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    _subscription?.cancel();
    _stream?.dispose();

    _messagesController.close();
    _connectionController.close();
    _errorController.close();

    _stream = null;
    _subscription = null;
  }

  /// Handle incoming GDL90 events using sealed class pattern matching.
  ///
  /// Discovery 01: skyecho_gdl90 never throws from parser - all errors are events.
  void _handleEvent(Gdl90Event event) {
    switch (event) {
      case Gdl90DataEvent(:final message):
        _lastMessageTime = DateTime.now();
        _errorCount = 0; // Reset error count on successful message

        // Update internal state based on message type
        if (message.messageType == Gdl90MessageType.ownship) {
          _lastOwnshipReport = message;
        } else if (message.messageType == Gdl90MessageType.traffic) {
          final icao = message.icaoAddress;
          if (icao != null) {
            _trafficTargets[icao] = message;
            _scheduleTrafficExpiry(icao);
          }
        }

        // Emit to stream for UI consumption
        _messagesController.add(message);

      case Gdl90ErrorEvent(:final reason, :final hint):
        _errorCount++;
        _errorController.add('Parse error: $reason. ${hint ?? ''}');

        // Disconnect after too many errors (possible data corruption)
        if (_errorCount > 100) {
          _handleFatalError('Too many parse errors');
        }

      case Gdl90IgnoredEvent():
        // Silently ignore unknown message types
        break;
    }
  }

  /// Handle stream errors (socket closed, network unreachable, etc).
  void _handleStreamError(Object error) {
    _isConnected = false;
    _connectionController.add(false);
    _errorController.add('Stream error: $error');
  }

  /// Handle stream closed event.
  void _handleStreamClosed() {
    _isConnected = false;
    _connectionController.add(false);
  }

  /// Handle fatal errors that require disconnection.
  void _handleFatalError(String reason) {
    _errorController.add('Fatal error: $reason');
    disconnect();
  }

  /// Start monitoring connection health (detect stale data).
  ///
  /// Marks connection as stale if no messages received for 10 seconds.
  void _startHealthMonitoring() {
    _healthTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_lastMessageTime != null) {
        final elapsed = DateTime.now().difference(_lastMessageTime!);

        if (elapsed > const Duration(seconds: 10)) {
          _isConnected = false;
          _connectionController.add(false);
          _errorController
              .add('No data received for ${elapsed.inSeconds} seconds');
        }
      }
    });
  }

  /// Schedule traffic target expiry after 30 seconds without update.
  void _scheduleTrafficExpiry(int icao) {
    Future.delayed(const Duration(seconds: 30), () {
      final target = _trafficTargets[icao];
      if (target != null && _lastMessageTime != null) {
        // Only expire if no update in last 30 seconds
        final age = DateTime.now().difference(_lastMessageTime!);
        if (age > const Duration(seconds: 30)) {
          _trafficTargets.remove(icao);
        }
      }
    });
  }
}
