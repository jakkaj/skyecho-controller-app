/// Capture raw 0x65 (ForeFlight extension) messages for analysis
///
/// This tool captures the raw bytes of message ID 0x65 to help
/// implement ForeFlight extension support.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:skyecho_gdl90/skyecho_gdl90.dart';

Future<void> main() async {
  print('╔════════════════════════════════════════════════════════════════╗');
  print('║  ForeFlight 0x65 Message Capture Tool                        ║');
  print('╚════════════════════════════════════════════════════════════════╝');
  print('');
  print('Listening on: 0.0.0.0:4000 (UDP)');
  print('Capturing message ID 0x65 samples...');
  print('Press Ctrl+C to stop\n');

  final stream = Gdl90Stream(port: 4000);
  final capturedMessages = <Uint8List>[];
  var messageCount = 0;
  var errorCount = 0;

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
    await stream.start();
    print('✅ Connected! Waiting for 0x65 messages...\n');

    final streamSub = stream.events.listen(
      (event) {
        if (event case Gdl90ErrorEvent(:final reason, :final rawBytes)) {
          // Check if this is an unknown message ID 0x65
          if (reason.contains('0x65') && rawBytes != null) {
            errorCount++;
            messageCount++;
            print('📦 Captured 0x65 message #$messageCount '
                '(${rawBytes.length} bytes)');

            // Display hex dump
            final hex = rawBytes
                .map((b) => b.toRadixString(16).padLeft(2, '0'))
                .join(' ');
            print('   Hex: $hex');

            // Check sub-ID (byte 1, after message ID)
            if (rawBytes.isNotEmpty) {
              final subId = rawBytes[0];
              print('   Sub-ID: 0x${subId.toRadixString(16).padLeft(2, '0')} '
                  '(${subId == 0 ? "Device ID" : subId == 1 ? "AHRS" : "Unknown"})');
            }

            capturedMessages.add(Uint8List.fromList(rawBytes));
            print('');

            // Auto-stop after capturing 5 samples
            if (messageCount >= 5) {
              print('Captured 5 samples, stopping...');
              shutdown();
            }
          }
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

    // Wait for manual shutdown or 60 second timeout
    await Future.any([
      Future<void>.delayed(Duration(seconds: 60)),
      completer.future,
    ]);

    await streamSub.cancel();
    await stream.dispose();
    await sigintSub.cancel();
  } catch (e, stack) {
    print('\n❌ Error: $e');
    print('Stack trace:\n$stack');
    exit(1);
  }

  // Save captured messages
  if (capturedMessages.isNotEmpty) {
    print(
        '\n╔════════════════════════════════════════════════════════════════╗');
    print('║  Saving Samples                                                ║');
    print('╚════════════════════════════════════════════════════════════════╝');

    final fixturesDir = Directory('test/fixtures');
    if (!await fixturesDir.exists()) {
      await fixturesDir.create(recursive: true);
    }

    // Save first ID message (sub-ID 0)
    final idMessages =
        capturedMessages.where((m) => m.isNotEmpty && m[0] == 0).toList();
    if (idMessages.isNotEmpty) {
      final file = File('test/fixtures/foreflight_id_message.bin');
      await file.writeAsBytes(idMessages.first);
      print('✅ Saved Device ID message: ${file.path}');
      print('   ${idMessages.first.length} bytes');
    }

    // Save first AHRS message (sub-ID 1) if present
    final ahrsMessages =
        capturedMessages.where((m) => m.isNotEmpty && m[0] == 1).toList();
    if (ahrsMessages.isNotEmpty) {
      final file = File('test/fixtures/foreflight_ahrs_message.bin');
      await file.writeAsBytes(ahrsMessages.first);
      print('✅ Saved AHRS message: ${file.path}');
      print('   ${ahrsMessages.first.length} bytes');
    }

    print('');
  }

  // Summary
  print('╔════════════════════════════════════════════════════════════════╗');
  print('║  Summary                                                       ║');
  print('╚════════════════════════════════════════════════════════════════╝');
  print('Total 0x65 messages captured: $messageCount');
  print('Samples saved to: test/fixtures/');
  print('');
  print('Next steps:');
  print('1. Review the captured hex dumps above');
  print('2. Implement parser for ForeFlight extensions');
  print('3. Use fixtures for unit tests');
  print('');
}
