/// SkyEcho Controller CLI Example
///
/// This demonstrates using the SkyEcho library to control devices.
///
/// When using skyecho as a dependency in your own project:
///   import 'package:skyecho/skyecho.dart';
///
/// For this monorepo example, we use a relative import:
library;

import 'dart:io' show exit;

import 'package:args/args.dart';

// ignore: avoid_relative_lib_imports
import '../lib/skyecho.dart';

Future<void> main(List<String> args) async {
  // Create argument parser
  final parser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show this help message')
    ..addOption('url',
        defaultsTo: 'http://192.168.4.1',
        help: 'Device URL (default: http://192.168.4.1)');

  // Parse arguments
  ArgResults argResults;
  try {
    argResults = parser.parse(args);
  } on FormatException catch (e) {
    print('Error: ${e.message}');
    print('');
    printHelp(parser);
    exit(1);
  }

  // Extract command and URL
  final url = argResults['url'] as String;
  final command = argResults.rest.isNotEmpty ? argResults.rest.first : '';

  // Handle help
  if (command.isEmpty ||
      command == 'help' ||
      (argResults['help'] as bool? ?? false)) {
    printHelp(parser);
    return;
  }

  // Create client
  final client = SkyEchoClient(url);

  // Execute command with error handling
  try {
    switch (command) {
      case 'ping':
        await cmdPing(client);
      case 'status':
        await cmdStatus(client);
      case 'config':
        await cmdConfig(client);
      case 'configure':
        await cmdConfigure(client);
      default:
        print('Unknown command: $command');
        print('');
        printHelp(parser);
        exit(1);
    }
  } on SkyEchoError catch (e) {
    print('❌ Error: $e'); // toString() includes hint
    exit(1);
  }
}

void printHelp(ArgParser parser) {
  print('SkyEcho Controller CLI');
  print('');
  print('Usage: dart run example/main.dart [options] <command>');
  print('');
  print(parser.usage);
  print('');
  print('Commands:');
  print('  ping       Check device connectivity');
  print('  status     Display device status');
  print('  config     Show current device configuration');
  print('  configure  Demonstrate configuration update');
  print('  help       Show this help message');
  print('');
  print('Examples:');
  print('  dart run example/main.dart ping');
  print('  dart run example/main.dart status');
  print('  dart run example/main.dart config');
  print('  dart run example/main.dart configure');
  print('  dart run example/main.dart --url http://192.168.4.2 ping');
}

Future<void> cmdPing(SkyEchoClient client) async {
  print('Pinging device...');
  await client.ping();
  print('✅ Device reachable');
}

Future<void> cmdStatus(SkyEchoClient client) async {
  print('Fetching device status...');
  final status = await client.fetchStatus();

  print('');
  print('Device Status:');
  print('  SSID:            ${status.ssid ?? "N/A"}');
  print('  WiFi Version:    ${status.wifiVersion ?? "N/A"}');
  print('  ADS-B Version:   ${status.adsbVersion ?? "N/A"}');
  print('  Clients:         ${status.clientsConnected ?? 0}');
  print('  Serial Number:   ${status.serialNumber ?? "N/A"}');
  print(
      '  Health:          ${status.isHealthy ? "✅ Healthy" : "⚠️  Unhealthy"}');
  print('  Coredump:        ${status.hasCoredump ? "⚠️  Yes" : "✅ No"}');
  print('');
}

Future<void> cmdConfig(SkyEchoClient client) async {
  print('Fetching device configuration...');
  final config = await client.fetchSetupConfig();

  print('');
  print('Device Configuration:');
  print('  ICAO Address:        ${config.icaoAddress}');
  print('  Callsign:            ${config.callsign}');
  print('  Emitter Category:    ${config.emitterCategory}');
  print('  VFR Squawk:          ${config.vfrSquawk}');
  print('  Stall Speed:         ${config.stallSpeedKnots} knots');
  print('');
  print('Receiver Settings:');
  print('  Receiver Mode:       ${config.receiverMode}');
  print('  UAT Enabled:         ${config.uatEnabled}');
  print('  1090ES Enabled:      ${config.es1090Enabled}');
  print(
      '  1090ES Transmit:     ${config.es1090TransmitEnabled ? "⚠️  ENABLED" : "✅ Disabled"}');
  print('');
  print('Aircraft Dimensions:');
  print('  Length:              ${config.aircraftLength}');
  print('  Width:               ${config.aircraftWidth}');
  print('');
  print('GPS Antenna Offset:');
  print('  Latitude Offset:     ${config.gpsLatOffset}');
  print('  Longitude Offset:    ${config.gpsLonOffsetMeters}m');
  print('');
  print('Quality Indicators:');
  print('  SIL:                 ${config.sil}');
  print('  SDA:                 ${config.sda}');
  print('');
  if (config.ownshipFilterIcao.isNotEmpty ||
      config.ownshipFilterFlarmId != null) {
    print('Ownship Filter:');
    if (config.ownshipFilterIcao.isNotEmpty) {
      print('  ICAO Address:        ${config.ownshipFilterIcao}');
    }
    if (config.ownshipFilterFlarmId != null) {
      print('  FLARM ID:            ${config.ownshipFilterFlarmId}');
    }
    print('');
  }
}

Future<void> cmdConfigure(SkyEchoClient client) async {
  // SAFETY: This example demonstrates applySetup() with real device modification.
  // Runtime assertion prevents accidental ADS-B transmit activation.
  print('Demonstrating configuration update...');
  print('');

  // Define the update (safe values only)
  final update = SetupUpdate()
    ..callsign = 'DEMO' // Safe demonstration callsign
    ..vfrSquawk = 1200; // Standard VFR squawk code

  // CRITICAL SAFETY CHECK: Verify no transmit flags are being enabled
  // This prevents accidental ADS-B broadcast on aviation frequencies
  if (update.es1090TransmitEnabled == true) {
    throw Exception(
        'SAFETY VIOLATION: Example code must never enable ADS-B transmit!');
  }

  print('Applying configuration:');
  print('  callsign  → DEMO');
  print('  vfrSquawk → 1200');
  print('');

  final result = await client.applySetup((u) => update);

  print('Configuration ${result.verified ? "verified ✅" : "not verified ⚠️"}');
  if (result.success) {
    print('POST request succeeded');
  } else {
    print('POST request failed');
  }
  if (result.message != null) {
    print('Message: ${result.message}');
  }
  print('');
}
