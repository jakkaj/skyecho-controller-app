import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('Generating arrow assets...');

  // Create green arrows for ownship
  await _createArrow('assets/markers/arrow_green.png', Colors.green, 40);
  await _createArrow('assets/markers/arrow_green@2x.png', Colors.green, 80);
  await _createArrow('assets/markers/arrow_green@3x.png', Colors.green, 120);

  // Create red arrows for traffic
  await _createArrow('assets/markers/arrow_red.png', Colors.red, 40);
  await _createArrow('assets/markers/arrow_red@2x.png', Colors.red, 80);
  await _createArrow('assets/markers/arrow_red@3x.png', Colors.red, 120);

  print('All arrow assets created successfully!');
}

Future<void> _createArrow(String filename, Color color, int size) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  // Draw arrow pointing up
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.fill;

  final outlinePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0;

  final centerX = size / 2;
  final tipY = size / 4;
  final baseY = size * 3 / 4;
  final baseWidth = size / 3;

  // Triangle pointing up
  final path = Path()
    ..moveTo(centerX, tipY) // Tip
    ..lineTo(centerX - baseWidth, baseY) // Bottom left
    ..lineTo(centerX + baseWidth, baseY) // Bottom right
    ..close();

  // Draw outline then fill
  canvas.drawPath(path, outlinePaint);
  canvas.drawPath(path, paint);

  // Convert to image
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

  // Write to file
  final file = File(filename);
  await file.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());

  print('Created $filename');
}
