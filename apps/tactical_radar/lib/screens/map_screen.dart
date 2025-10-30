import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:skyecho/skyecho.dart';
import 'package:skyecho_gdl90/skyecho_gdl90.dart';

import '../models/ownship_state.dart';
import '../models/traffic_target.dart';
import '../services/gdl_service_factory.dart';
import '../services/gdl_service_interface.dart';

/// Map screen displaying ownship and traffic on Google Maps with rotated arrows.
///
/// Features:
/// - Google Maps with rotated arrow markers for ownship and traffic
/// - Ownship fallback: GDL90 → phone GPS (yellow marker if fallback)
/// - Traffic markers with altitude differentials and color coding
/// - Native marker rotation using Marker.rotation property
/// - App bar indicator: green (receiving GDL90), grey (disconnected)
/// - UI batching at 10 FPS (100ms intervals) per Discovery 05
/// - Debug logging enabled
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Services
  late GdlServiceInterface _gdlService;
  late SkyEchoClient _skyEchoClient;
  final Location _location = Location();

  // Subscriptions
  StreamSubscription<Gdl90Message>? _messagesSub;

  // UI state
  OwnshipState? _ownshipState;
  int? _ownshipBaroAltitude;
  final Map<int, TrafficTarget> _trafficTargets = {};
  DateTime? _lastOwnshipTime;
  DateTime? _lastHeartbeatTime;
  bool _usingGpsFallback = false;
  bool _gpsRequestInProgress = false;

  // SkyEcho device state (for ADS-B OUT status)
  bool _deviceTransmitting = false;
  bool _deviceConnected = false;
  Timer? _devicePollTimer;

  // Batching state (Discovery 05: 10 FPS UI updates)
  Timer? _uiUpdateTimer;
  final List<Gdl90Message> _pendingMessages = [];

  // Map controller
  GoogleMapController? _mapController;

  // Cached arrow icons (generated from widgets)
  BitmapDescriptor? _ownshipIcon;
  BitmapDescriptor? _trafficIcon;

  @override
  void initState() {
    super.initState();
    _skyEchoClient = SkyEchoClient('http://192.168.4.1');
    _loadMarkerIcons();
    _initializeGdl();
    _checkLocationPermission();
    _startDevicePolling();
  }

  /// Create marker icons from Flutter widgets.
  Future<void> _loadMarkerIcons() async {
    _ownshipIcon = await _createArrowMarker(Colors.green, 48);
    _trafficIcon = await _createArrowMarker(Colors.red, 40);
    if (mounted) setState(() {});
  }

  /// Create an arrow marker from a widget.
  Future<BitmapDescriptor> _createArrowMarker(
    Color color,
    double size,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw circle background
    final circlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2,
      circlePaint,
    );

    // Draw arrow pointing up (will be rotated by marker.rotation)
    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final center = size / 2;
    final arrowSize = size * 0.6;

    // Arrow pointing up
    path.moveTo(center, center - arrowSize / 2); // Top point
    path.lineTo(center - arrowSize / 4, center + arrowSize / 4); // Bottom left
    path.lineTo(center, center); // Center
    path.lineTo(center + arrowSize / 4, center + arrowSize / 4); // Bottom right
    path.close();

    canvas.drawPath(path, arrowPaint);

    // Convert to image
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _uiUpdateTimer?.cancel();
    _devicePollTimer?.cancel();
    _gdlService.disconnect();
    _gdlService.dispose();
    super.dispose();
  }

  Future<void> _initializeGdl() async {
    // Use factory to create appropriate service (mock or real)
    _gdlService = GdlServiceFactory.create();

    try {
      // Subscribe to message stream
      _messagesSub = _gdlService.messages
          .cast<Gdl90Message>()
          .listen(_handleGdlMessage);

      // Connect to GDL90 stream
      await _gdlService.connect();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect to GDL90: $e')),
        );
      }
    }
  }

  Future<void> _checkLocationPermission() async {
    print('[PERMISSION] Starting location permission check...');

    try {
      print('[PERMISSION] Checking if location service is enabled...');
      final serviceEnabled = await _location.serviceEnabled();
      print('[PERMISSION] Service enabled: $serviceEnabled');

      if (!serviceEnabled) {
        print('[PERMISSION] Requesting location service...');
        final requested = await _location.requestService();
        print('[PERMISSION] Service request result: $requested');
        if (!requested) {
          print('[PERMISSION] Location service not enabled, aborting');
          return;
        }
      }

      print('[PERMISSION] Checking current permission status...');
      var permissionGranted = await _location.hasPermission();
      print('[PERMISSION] Current permission: $permissionGranted');

      if (permissionGranted == PermissionStatus.denied) {
        print('[PERMISSION] Permission denied, requesting permission...');
        permissionGranted = await _location.requestPermission();
        print('[PERMISSION] Permission request result: $permissionGranted');

        if (permissionGranted != PermissionStatus.granted) {
          print('[PERMISSION] Permission not granted, aborting');
          return;
        }
      }

      print('[PERMISSION] Location permission check complete - granted');
    } catch (e) {
      print('[PERMISSION] ERROR during permission check: $e');
    }
  }

  /// Start polling SkyEcho device for ADS-B OUT status.
  void _startDevicePolling() {
    // Poll every 5 seconds (same as Config screen)
    _devicePollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _pollDevice();
    });

    // Initial poll
    _pollDevice();
  }

  /// Poll device for ADS-B OUT transmit status.
  Future<void> _pollDevice() async {
    try {
      final config = await _skyEchoClient.fetchSetupConfig();

      if (mounted) {
        setState(() {
          _deviceConnected = true;
          _deviceTransmitting = config.es1090TransmitEnabled;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _deviceConnected = false;
          _deviceTransmitting = false;
        });
      }
    }
  }

  /// Handle incoming GDL90 messages with batching.
  ///
  /// Collects messages and updates UI at max 10 FPS (100ms intervals)
  /// to prevent frame drops per Discovery 05.
  void _handleGdlMessage(Gdl90Message message) {
    _pendingMessages.add(message);

    // Start timer if not already running
    _uiUpdateTimer ??= Timer(
      const Duration(milliseconds: 100),
      _flushPendingUpdates,
    );
  }

  /// Flush batched messages and update UI.
  void _flushPendingUpdates() {
    if (_pendingMessages.isEmpty || !mounted) {
      _uiUpdateTimer = null;
      return;
    }

    setState(() {
      for (final message in _pendingMessages) {
        _processMessageForUI(message);
      }
      _pendingMessages.clear();
    });

    _uiUpdateTimer = null;
  }

  /// Process individual message for UI state updates.
  void _processMessageForUI(Gdl90Message message) {
    // Debug logging
    print('[GDL90] ${message.messageType}: ${message.toString()}');

    switch (message.messageType) {
      case Gdl90MessageType.ownship:
        _handleOwnshipUpdate(message);
      case Gdl90MessageType.traffic:
        _handleTrafficUpdate(message);
      case Gdl90MessageType.heartbeat:
        _handleHeartbeat(message);
      default:
        break;
    }
  }

  void _handleOwnshipUpdate(Gdl90Message message) {
    final newState = OwnshipState.fromGdl90Message(message);
    _ownshipBaroAltitude = message.altitudeFeet;

    print('[OWNSHIP] lat=${message.latitude}, lon=${message.longitude}, '
        'alt=${message.altitudeFeet}, position=${newState.position}');

    // Only update ownship state if we have a valid position
    // This preserves last known position if GPS is temporarily lost
    if (newState.position != null) {
      _ownshipState = newState;
      _lastOwnshipTime = DateTime.now();
      _usingGpsFallback = false;
      print('[OWNSHIP] Updated to valid GDL90 position');

      // Center map on ownship if first valid position
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(_ownshipState!.position!),
        );
      }
    } else {
      // No valid position from GDL90, trigger GPS fallback check
      // but keep showing last known position
      print('[OWNSHIP] No valid GDL90 position (keeping last known), checking GPS fallback');
      _checkGpsFallback();
    }
  }

  void _handleTrafficUpdate(Gdl90Message message) {
    final icao = message.icaoAddress;
    if (icao == null) return;

    try {
      final target = TrafficTarget.fromGdl90Message(
        message: message,
        ownshipAltitude: _ownshipBaroAltitude,
      );
      _trafficTargets[icao] = target;
      print('[TRAFFIC] ICAO: ${icao.toRadixString(16).toUpperCase()}, '
          'Callsign: ${target.callsign}, '
          'Alt: ${target.altitude}ft, '
          'RelAlt: ${target.relativeAltitude}');
    } catch (e) {
      // Skip traffic with invalid data
      print('[TRAFFIC] Error parsing ICAO $icao: $e');
    }
  }

  void _handleHeartbeat(Gdl90Message message) {
    _lastHeartbeatTime = DateTime.now();

    // Update GPS status if needed
    final hasGps = message.gpsPosValid ?? false;
    if (!hasGps && _ownshipState?.position == null) {
      // No GDL90 GPS, check for phone GPS fallback
      _checkGpsFallback();
    }
  }

  /// Check if GPS fallback is needed (no ownship for 5s).
  Future<void> _checkGpsFallback() async {
    // Prevent concurrent GPS requests
    if (_gpsRequestInProgress) {
      print('[GPS] GPS request already in progress, skipping');
      return;
    }

    print('[GPS] Checking fallback...');
    print('[GPS] _lastOwnshipTime: $_lastOwnshipTime');
    print('[GPS] Current time: ${DateTime.now()}');

    if (_lastOwnshipTime == null ||
        DateTime.now().difference(_lastOwnshipTime!) >
            const Duration(seconds: 5)) {
      _gpsRequestInProgress = true;
      print('[GPS] Fallback triggered, getting phone location');

      try {
        print('[GPS] About to call _location.getLocation()...');

        // Use simpler location request with timeout
        final locationData = await _location.getLocation().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('[GPS] getLocation() TIMED OUT after 5 seconds');
            throw TimeoutException('Location request timed out');
          },
        );

        print('[GPS] getLocation() returned successfully');
        print('[GPS] Got location: lat=${locationData.latitude}, '
            'lon=${locationData.longitude}, '
            'alt=${locationData.altitude}, '
            'heading=${locationData.heading}');

        if (locationData.latitude != null && locationData.longitude != null) {
          if (mounted) {
            setState(() {
              _ownshipState = OwnshipState.fromPhoneGPS(
                latitude: locationData.latitude!,
                longitude: locationData.longitude!,
                altitude: locationData.altitude,
                heading: locationData.heading,
              );
              _usingGpsFallback = true;
            });
            print('[GPS] Ownship set from GPS: ${_ownshipState?.position}');
          }
        } else {
          print('[GPS] Location data missing lat/lon');
        }
      } catch (e, stackTrace) {
        print('[GPS] ERROR getting location: $e');
        print('[GPS] Stack trace: $stackTrace');

        // In debug mode, fallback to Heck Field (YHEC) if GPS fails
        // This handles iOS simulator where location services don't work
        if (mounted) {
          const bool isDebug = !bool.fromEnvironment('dart.vm.product');
          if (isDebug) {
            print('[GPS] Debug mode: Using Heck Field (YHEC) as fallback');
            setState(() {
              _ownshipState = OwnshipState.fromPhoneGPS(
                latitude: -27.7667,
                longitude: 153.3372,
                altitude: 500.0, // Approximate field elevation
                heading: null,
              );
              _usingGpsFallback = true;
            });
            print('[GPS] Ownship set to Heck Field: ${_ownshipState?.position}');
          }
        }
      } finally {
        _gpsRequestInProgress = false;
      }
    } else {
      print('[GPS] Not triggering fallback yet (last ownship was recent)');
    }
  }

  @override
  Widget build(BuildContext context) {
    // App bar is green when device is transmitting, gray otherwise
    // (matches Config screen design)
    final appBarColor = !_deviceConnected
        ? Colors.grey.shade700
        : _deviceTransmitting
            ? Colors.green.shade600
            : Colors.grey.shade700;

    final statusText = !_deviceConnected
        ? 'SkyEcho - DISCONNECTED'
        : _deviceTransmitting
            ? 'SkyEcho - TRANSMITTING'
            : 'SkyEcho - STANDBY';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          statusText,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: appBarColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          _buildMap(),
          _buildHeartbeatIndicator(),
        ],
      ),
    );
  }

  Widget _buildHeartbeatIndicator() {
    // Check if heartbeat is stale (>5 seconds since last)
    final now = DateTime.now();
    final isStale = _lastHeartbeatTime == null ||
        now.difference(_lastHeartbeatTime!) > const Duration(seconds: 5);

    // Show green circle (white outline) if heartbeat OK, red if stale
    final fillColor = isStale ? Colors.red : Colors.green;

    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fillColor,
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildMap() {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(-27.7667, 153.3372), // Heck Field (YHEC) default
        zoom: 10,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
      },
      markers: _buildMarkers(),
      mapType: MapType.normal,
      rotateGesturesEnabled: true,
      myLocationEnabled: false, // We'll draw our own ownship marker
      myLocationButtonEnabled: false,
    );
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    final now = DateTime.now();

    // Remove stale traffic (>15 seconds old)
    _trafficTargets.removeWhere((icao, target) {
      final isStale = now.difference(target.lastUpdate).inSeconds > 15;
      if (isStale) {
        print('[TRAFFIC] Removed stale target: $icao');
      }
      return isStale;
    });

    // Add ownship marker (always show, whether from GDL90 or GPS fallback)
    if (_ownshipState != null) {
      final ownshipPos = _ownshipState!.position;

      if (ownshipPos != null) {
        final heading = _ownshipState!.heading ?? 0;

        // Use pre-loaded ownship icon if available
        if (_ownshipIcon != null) {
          markers.add(
            Marker(
              markerId: const MarkerId('ownship'),
              position: ownshipPos,
              icon: _ownshipIcon!,
              rotation: heading.toDouble(),
              flat: true,
              anchor: const Offset(0.5, 0.5),
              zIndexInt: 1000,
              infoWindow: InfoWindow(
                title: _usingGpsFallback ? 'Ownship (GPS)' : 'Ownship',
                snippet: _usingGpsFallback
                    ? 'GPS: ${_ownshipState!.altitude ?? 0}ft, hdg: $heading°'
                    : 'GDL90: ${_ownshipState!.altitude ?? 0}ft, hdg: $heading°',
              ),
            ),
          );
        }
      }
    }

    // Add traffic markers
    for (final target in _trafficTargets.values) {
      // Use pre-loaded traffic icon if available
      if (_trafficIcon != null) {
        markers.add(
          Marker(
            markerId: MarkerId('traffic-${target.icao}'),
            position: target.position,
            icon: _trafficIcon!,
            rotation: target.heading.toDouble(),
            flat: true,
            anchor: const Offset(0.5, 0.5),
            zIndexInt: 0,
            infoWindow: InfoWindow(
              title: target.callsign,
              snippet:
                  '${target.altitude}ft (${target.relativeAltitude}), hdg: ${target.heading}°',
            ),
          ),
        );
      }
    }

    return markers;
  }
}
