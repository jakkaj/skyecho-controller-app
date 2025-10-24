/// Real Device Integration Test
///
/// This example demonstrates connecting to a real SkyEcho device and
/// receiving live GDL90 data over UDP.
///
/// Usage:
///   dart run example/real_device_test.dart
///   dart run example/real_device_test.dart --duration 60
///   dart run example/real_device_test.dart --host 192.168.4.1 --port 4000
library;

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:skyecho_gdl90/skyecho_gdl90.dart';

Future<void> main(List<String> args) async {
  // Parse command-line arguments
  final parser = ArgParser()
    ..addOption('host',
        defaultsTo: '0.0.0.0',
        help: 'Local interface to bind (0.0.0.0 = any interface)')
    ..addOption('port', defaultsTo: '4000', help: 'GDL90 UDP port')
    ..addOption('duration',
        abbr: 'd', defaultsTo: '30', help: 'Duration in seconds')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help');

  ArgResults argResults;
  try {
    argResults = parser.parse(args);
  } on FormatException catch (e) {
    print('Error: ${e.message}\n');
    _printUsage(parser);
    exit(1);
  }

  if (argResults['help'] as bool) {
    _printUsage(parser);
    return;
  }

  final host = argResults['host'] as String;
  final port = int.parse(argResults['port'] as String);
  final duration = int.parse(argResults['duration'] as String);

  print('╔════════════════════════════════════════════════════════════════╗');
  print('║  SkyEcho GDL90 Real Device Test                               ║');
  print('╚════════════════════════════════════════════════════════════════╝');
  print('');
  print('Listening on: $host:$port (UDP)');
  print('Duration: ${duration}s');
  print('Press Ctrl+C to stop early\n');

  // Create stream and connect
  final stream = Gdl90Stream(port: port);

  // Statistics counters
  var heartbeatCount = 0;
  var trafficCount = 0;
  var ownshipCount = 0;
  var messageCount = 0;
  var errorCount = 0;
  var unknownCount = 0;
  var foreFlightIdCount = 0;

  // Device info (populated from ForeFlight ID message)
  String? deviceInfo;

  // Set up signal handling for graceful shutdown
  late StreamSubscription<ProcessSignal> sigintSub;
  final completer = Completer<void>();

  void shutdown() {
    if (!completer.isCompleted) {
      print('\n\nShutting down...');
      completer.complete();
    }
  }

  sigintSub = ProcessSignal.sigint.watch().listen((_) => shutdown());

  try {
    // Start the stream
    await stream.start();
    print('✅ Connected! Listening for GDL90 messages...\n');

    // Listen to events
    final streamSub = stream.events.listen(
      (event) {
        switch (event) {
          case Gdl90DataEvent(:final message):
            switch (message.messageType) {
              case Gdl90MessageType.heartbeat:
                heartbeatCount++;
                print('💓 Heartbeat #$heartbeatCount - '
                    'GPS: ${message.gpsPosValid == true ? "✅" : "❌"}, '
                    'UTC: ${message.utcOk == true ? "✅" : "❌"}');
              case Gdl90MessageType.traffic:
                trafficCount++;
                final lat = message.latitude?.toStringAsFixed(5) ?? 'N/A';
                final lon = message.longitude?.toStringAsFixed(5) ?? 'N/A';
                final alt = message.altitudeFeet ?? 0;
                final addr = message.icaoAddress ?? 0;
                final icao =
                    addr.toRadixString(16).toUpperCase().padLeft(6, '0');
                print('✈️  Traffic #$trafficCount - '
                    'ICAO: $icao, Lat: $lat, Lon: $lon, Alt: ${alt}ft');
              case Gdl90MessageType.ownship:
                ownshipCount++;
                final lat = message.latitude?.toStringAsFixed(5) ?? 'N/A';
                final lon = message.longitude?.toStringAsFixed(5) ?? 'N/A';
                final alt = message.altitudeFeet ?? 0;
                print('🛩️  Ownship #$ownshipCount - '
                    'Lat: $lat, Lon: $lon, Alt: ${alt}ft');
              case Gdl90MessageType.initialization:
                messageCount++;
                print('🔧 Initialization - '
                    'Audio Inhibit: ${message.audioInhibit ?? 0}');
              case Gdl90MessageType.uplinkData:
                messageCount++;
                final len = message.uplinkPayload?.length ?? 0;
                print('📡 Uplink Data - Length: $len bytes');
              case Gdl90MessageType.hat:
                messageCount++;
                final hat = message.heightAboveTerrainFeet ?? 0;
                print('📏 Height Above Terrain - HAT: ${hat}ft');
              case Gdl90MessageType.ownshipGeoAltitude:
                messageCount++;
                final alt = message.geoAltitudeFeet ?? 0;
                final vfom = message.vfomMeters ?? 0;
                print('📐 Ownship Geometric Altitude - '
                    'Alt: ${alt}ft, VFOM: ${vfom}m');
              case Gdl90MessageType.basicReport:
              case Gdl90MessageType.longReport:
                messageCount++;
                print('🔄 FIS-B Report - '
                    'Type: ${message.messageType}');
              case Gdl90MessageType.foreFlightId:
                foreFlightIdCount++;
                final device = message.deviceName ?? 'Unknown';
                final serial = message.serialNumber ?? 0;
                final version = message.foreFlightVersion ?? 0;
                final longName = message.deviceLongName ?? '';
                final caps = message.capabilitiesMask ?? 0;

                // Store device info for display
                if (deviceInfo == null) {
                  deviceInfo = '$device (S/N: $serial)';
                  print(
                      '\n╔════════════════════════════════════════════════════════════════╗');
                  print(
                      '║  Device Identification                                        ║');
                  print(
                      '╚════════════════════════════════════════════════════════════════╝');
                  print('📱 Device Name:       $device');
                  if (longName.isNotEmpty) {
                    print('   Long Name:         $longName');
                  }
                  print('   Serial Number:     $serial');
                  print('   ForeFlight Ver:    $version');
                  print(
                      '   Capabilities:      0x${caps.toRadixString(16).toUpperCase().padLeft(8, "0")}');
                  print('');
                } else {
                  print('📱 ForeFlight ID #$foreFlightIdCount - $deviceInfo');
                }
              case Gdl90MessageType.foreFlightAhrs:
                messageCount++;
                print('🔵 ForeFlight AHRS - '
                    'Roll: ${message.roll?.toStringAsFixed(1) ?? "N/A"}°');
            }
          case Gdl90ErrorEvent(:final reason):
            errorCount++;
            print('⚠️  Error - $reason');
          case Gdl90IgnoredEvent(:final messageId):
            unknownCount++;
            final id =
                messageId.toRadixString(16).toUpperCase().padLeft(2, '0');
            print('❓ Ignored Message - ID: 0x$id');
        }
      },
      onError: (Object error) {
        print('❌ Stream error: $error');
      },
      onDone: () {
        print('Stream closed');
        shutdown();
      },
    );

    // Wait for duration or manual shutdown
    await Future.any([
      Future<void>.delayed(Duration(seconds: duration)),
      completer.future,
    ]);

    // Cleanup
    await streamSub.cancel();
    await stream.dispose();
    await sigintSub.cancel();
  } catch (e, stack) {
    print('\n❌ Error: $e');
    print('Stack trace:\n$stack');
    exit(1);
  }

  // Print summary
  print('\n╔════════════════════════════════════════════════════════════════╗');
  print('║  Summary                                                       ║');
  print('╚════════════════════════════════════════════════════════════════╝');
  if (deviceInfo != null) {
    print('Connected Device:     $deviceInfo');
    print('');
  }
  print('Heartbeats:           $heartbeatCount');
  print('Traffic Reports:      $trafficCount');
  print('Ownship Reports:      $ownshipCount');
  print('ForeFlight ID Msgs:   $foreFlightIdCount');
  print('Other Messages:       $messageCount');
  print('Unknown Messages:     $unknownCount');
  print('Errors:               $errorCount');
  final total = heartbeatCount +
      trafficCount +
      ownshipCount +
      foreFlightIdCount +
      messageCount +
      unknownCount +
      errorCount;
  print('Total Events:         $total');
  print('');
}

void _printUsage(ArgParser parser) {
  print('SkyEcho GDL90 Real Device Test\n');
  print('Usage: dart run example/real_device_test.dart [options]\n');
  print(parser.usage);
  print('\nExamples:');
  print('  dart run example/real_device_test.dart');
  print('  dart run example/real_device_test.dart --duration 60');
  print(
      '  dart run example/real_device_test.dart --host 192.168.4.2 --port 4001');
}
