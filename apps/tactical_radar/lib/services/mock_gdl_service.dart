import 'dart:async';

import 'package:skyecho_gdl90/skyecho_gdl90.dart';

import 'gdl_service_interface.dart';

/// Mock implementation of GDL90 service for debug/testing without physical device.
///
/// Generates realistic ownship and traffic data at Heck Field (YHEC), Australia.
/// - Ownship: Fixed at 1000ft, Heck Field coordinates
/// - Traffic: 3 aircraft within 10nm at various altitudes and headings
///
/// Useful for:
/// - iOS Simulator testing (no UDP multicast support)
/// - Offline development without SkyEcho hardware
/// - UI testing with controlled scenarios
class MockGdlService implements GdlServiceInterface {
  final _messagesController = StreamController<Gdl90Message>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  bool _isConnected = false;
  Gdl90Message? _lastOwnshipReport;
  final Map<int, Gdl90Message> _trafficTargets = {};

  Timer? _dataGeneratorTimer;
  Timer? _heartbeatTimer;

  // Mock data configuration - Heck Field (YHEC), Australia
  static const double _ownshipLat = -27.7667;
  static const double _ownshipLon = 153.3372;
  static const int _ownshipAlt = 1000; // 1000ft MSL

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

    // Simulate connection delay
    await Future<void>.delayed(const Duration(milliseconds: 100));

    _isConnected = true;
    _connectionController.add(true);

    // Start generating mock data
    _startDataGeneration();
  }

  @override
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _dataGeneratorTimer?.cancel();

    _isConnected = false;
    _connectionController.add(false);
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _dataGeneratorTimer?.cancel();

    _messagesController.close();
    _connectionController.close();
    _errorController.close();
  }

  /// Start generating mock GDL90 messages at realistic rates.
  void _startDataGeneration() {
    // Heartbeat every 1 second (per GDL90 spec)
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _generateHeartbeat();
    });

    // Ownship and traffic updates at ~5Hz (200ms)
    _dataGeneratorTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _generateOwnship();
      _generateTraffic();
    });
  }

  void _generateHeartbeat() {
    final heartbeat = Gdl90Message(
      messageType: Gdl90MessageType.heartbeat,
      messageId: 0x00,
      gpsPosValid: true,
      utcOk: true,
      batteryLow: false,
      uatInitialized: true,
    );
    _messagesController.add(heartbeat);
  }

  void _generateOwnship() {
    final ownship = Gdl90Message(
      messageType: Gdl90MessageType.ownship,
      messageId: 0x0A,
      latitude: _ownshipLat,
      longitude: _ownshipLon,
      altitudeFeet: _ownshipAlt,
      trackDegrees: 90, // Heading east
      verticalVelocityFpm: 0,
      callsign: 'MOCK001',
      airborne: true,
    );

    _lastOwnshipReport = ownship;
    _messagesController.add(ownship);
  }

  void _generateTraffic() {
    // Generate 3 traffic targets within 10nm at various altitudes and headings
    // 1nm ≈ 0.01667 degrees lat/lon at this latitude

    final trafficConfigs = [
      {
        'icao': 0xABC123,
        'callsign': 'QFA456',
        'heading': 45,
        'altitude': 1500, // +500ft above ownship
        'latOffset': 0.05, // ~3nm north
        'lonOffset': 0.05, // ~3nm east
        'speed': 120,
      },
      {
        'icao': 0xDEF789,
        'callsign': 'VOZ234',
        'heading': 270,
        'altitude': 700, // -300ft below ownship
        'latOffset': -0.03, // ~2nm south
        'lonOffset': 0.08, // ~5nm east
        'speed': 110,
      },
      {
        'icao': 0x123456,
        'callsign': 'JST567',
        'heading': 180,
        'altitude': 1000, // Same altitude
        'latOffset': 0.08, // ~5nm north
        'lonOffset': -0.04, // ~2.5nm west
        'speed': 95,
      },
    ];

    for (final config in trafficConfigs) {
      final icao = config['icao'] as int;
      final callsign = config['callsign'] as String;
      final heading = config['heading'] as int;
      final altitude = config['altitude'] as int;
      final latOffset = config['latOffset'] as double;
      final lonOffset = config['lonOffset'] as double;

      final traffic = Gdl90Message(
        messageType: Gdl90MessageType.traffic,
        messageId: 0x14,
        icaoAddress: icao,
        latitude: _ownshipLat + latOffset,
        longitude: _ownshipLon + lonOffset,
        altitudeFeet: altitude,
        trackDegrees: heading,
        callsign: callsign,
        airborne: true,
      );

      _trafficTargets[icao] = traffic;
      _messagesController.add(traffic);
    }
  }
}
