import 'package:flutter/material.dart';

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
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Tactical Radar'),
        ),
        body: const Center(
          child: Text('App Setup Complete'),
        ),
      ),
    );
  }
}
