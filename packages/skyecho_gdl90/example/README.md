# SkyEcho GDL90 Examples

This directory contains example code demonstrating how to use the `skyecho_gdl90` library.

## Real Device Integration Test

**File**: `real_device_test.dart`

A simple CLI tool to connect to a real SkyEcho device and receive live GDL90 data over UDP.

### Prerequisites

1. **SkyEcho Device**: Must be powered on and accessible on your network
2. **WiFi Connection**: Your computer must be connected to the SkyEcho's WiFi network
3. **Default Configuration**: SkyEcho broadcasts GDL90 data on UDP port 4000 by default

### Quick Start

```bash
# Run with defaults (192.168.4.1:4000, 30 seconds)
dart run example/real_device_test.dart

# Run for 60 seconds
dart run example/real_device_test.dart --duration 60

# Custom host/port
dart run example/real_device_test.dart --host 192.168.4.2 --port 4001
```

### Command-Line Options

| Option | Default | Description |
|--------|---------|-------------|
| `--host` | `192.168.4.1` | SkyEcho device IP address |
| `--port` | `4000` | GDL90 UDP port |
| `--duration`, `-d` | `30` | Duration in seconds |
| `--help`, `-h` | - | Show help message |

### What You'll See

The tool will display real-time GDL90 messages as they arrive:

```
╔════════════════════════════════════════════════════════════════╗
║  SkyEcho GDL90 Real Device Test                               ║
╚════════════════════════════════════════════════════════════════╝

Connecting to: 192.168.4.1:4000 (UDP)
Duration: 30s
Press Ctrl+C to stop early

✅ Connected! Listening for GDL90 messages...

💓 Heartbeat #1 - GPS: ✅, Timestamps: ✅
💓 Heartbeat #2 - GPS: ✅, Timestamps: ✅
✈️  Traffic #1 - ICAO: A12345, Lat: 37.12345, Lon: -122.45678, Alt: 3500ft
🛩️  Ownship #1 - Lat: 37.12340, Lon: -122.45670, Alt: 3200ft
💓 Heartbeat #3 - GPS: ✅, Timestamps: ✅
...

╔════════════════════════════════════════════════════════════════╗
║  Summary                                                       ║
╚════════════════════════════════════════════════════════════════╝
Heartbeats:           45
Traffic Reports:      12
Ownship Reports:      8
Other Messages:       3
Unknown Messages:     0
Errors:               0
Total Events:         68
```

### Message Types

The tool displays these GDL90 message types:

| Icon | Message Type | Description |
|------|-------------|-------------|
| 💓 | Heartbeat | Device status (GPS, timestamp availability) |
| ✈️  | Traffic Report | Nearby aircraft position |
| 🛩️  | Ownship Report | Your aircraft position |
| 🔧 | Initialization | Device configuration |
| 📡 | Uplink Data | ADS-B uplink data |
| 📏 | Height Above Terrain | Terrain clearance |
| 📐 | Geometric Altitude | Ownship geometric altitude |
| 🔄 | Pass-Through | Pass-through data |
| ❓ | Unknown | Unrecognized message ID |
| ⚠️  | Error | Parsing or framing error |

### Stopping Early

Press **Ctrl+C** at any time to stop the capture and see the summary.

### Troubleshooting

**No messages received**:
- Verify you're connected to the SkyEcho WiFi network
- Check the device is powered on
- Confirm the IP address (default is 192.168.4.1)
- Verify GDL90 streaming is enabled on the device

**"Address already in use" error**:
- Another program may be using UDP port 4000
- Try specifying a different port if your SkyEcho supports it

**GPS not valid**:
- The device may not have GPS lock yet
- Try moving outside or near a window
- Wait a few minutes for GPS acquisition

### Next Steps

Once you've verified connectivity with this example:

1. **Capture Data**: Use the planned Phase 9 capture utility to save timestamped raw data
2. **Build Applications**: Integrate `Gdl90Stream` into your own Dart/Flutter apps
3. **Process Messages**: Use the parsed events to build traffic displays, logging, or analysis tools

## Code Example

Here's a minimal example of using `Gdl90Stream` in your own code:

```dart
import 'package:skyecho_gdl90/skyecho_gdl90.dart';

Future<void> main() async {
  final stream = Gdl90Stream(host: '192.168.4.1', port: 4000);

  await stream.start();

  stream.events.listen((event) {
    if (event is TrafficReport) {
      print('Traffic detected: ${event.address}');
    }
  });

  // Keep running...
  await Future<void>.delayed(Duration(minutes: 5));
  await stream.dispose();
}
```

## Reference

- [GDL90 Specification](https://www.faa.gov/air_traffic/technology/adsb/archival/media/GDL90_Public_ICD_RevA.PDF)
- [SkyEcho Documentation](https://uavionix.com/products/skyecho/)
