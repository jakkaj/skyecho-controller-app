import 'package:flutter/material.dart';
import 'screens/config_screen.dart';

void main() {
  runApp(const TacticalRadarApp());
}

/// Root application widget for Tactical Radar.
class TacticalRadarApp extends StatelessWidget {
  /// Creates the root application widget.
  const TacticalRadarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tactical Radar',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ConfigScreen(),
    );
  }
}
