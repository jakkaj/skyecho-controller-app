# SkyEcho Controller Library

A Dart library for programmatic control of uAvionix SkyEcho 2 ADS-B devices via their web interface.

## Features

- Device connectivity checking (ping)
- Device status retrieval (firmware versions, health, clients)
- Configuration management (callsign, squawk codes, receiver mode, etc.)
- Hardware-independent development through comprehensive mocking
- Integration tests with real device support

## Installation

This library is currently in development. To use it:

```yaml
# Add to your pubspec.yaml dependencies
dependencies:
  skyecho:
    path: packages/skyecho/
```

Then run:

```bash
dart pub get
```

## Quick Start

```dart
import 'package:skyecho/skyecho.dart';

Future<void> main() async {
  final client = SkyEchoClient('http://192.168.4.1');

  // Check device connectivity
  await client.ping();
  print('Device is reachable!');

  // Get device status
  final status = await client.fetchStatus();
  print('SSID: ${status.ssid}');
  print('WiFi Version: ${status.wifiVersion}');
  print('Health: ${status.isHealthy}');
}
```

## Example Usage

The library includes a CLI example demonstrating all major features. Navigate to the package directory and run:

```bash
cd packages/skyecho
```

### Help

```bash
dart run example/main.dart --help
```

Output:
```
SkyEcho Controller CLI

Usage: dart run example/main.dart [options] <command>

-h, --help    Show this help message
    --url     Device URL (default: http://192.168.4.1)
              (defaults to "http://192.168.4.1")

Commands:
  ping       Check device connectivity
  status     Display device status
  configure  Demonstrate configuration update
  help       Show this help message

Examples:
  dart run example/main.dart ping
  dart run example/main.dart --url http://192.168.4.2 status
  dart run example/main.dart configure
```

### Ping Command

Check if the device is reachable:

```bash
dart run example/main.dart ping
```

Output:
```
Pinging device...
✅ Device reachable
```

### Status Command

Get detailed device status:

```bash
dart run example/main.dart status
```

Output:
```
Fetching device status...

Device Status:
  SSID:            SkyEcho_3155
  WiFi Version:    0.2.41-SkyEcho
  ADS-B Version:   2.6.13
  Clients:         1
  Serial Number:   0655339053
  Health:          ✅ Healthy
  Coredump:        ✅ No
```

### Configure Command

Demonstrate configuration updates (uses safe example values):

```bash
dart run example/main.dart configure
```

Output:
```
Demonstrating configuration update...

Applying configuration:
  callsign  → DEMO
  vfrSquawk → 1200

Configuration verified ✅
POST request succeeded
```

### Custom URL

Override the default device URL:

```bash
dart run example/main.dart --url http://192.168.4.2 ping
```

## Development Commands

### Install Dependencies

```bash
cd packages/skyecho
dart pub get
```

### Run Tests

```bash
# All tests (unit + integration)
dart test

# Unit tests only (fast, offline)
dart test test/unit/

# Integration tests only (requires real device at 192.168.4.1)
dart test test/integration/
```

### Code Quality

```bash
# Run analyzer
dart analyze

# Format code
dart format .
```

### Using justfile (optional)

If you have [just](https://github.com/casey/just) installed, you can use convenience commands:

```bash
# Install dependencies
just install

# Run linter
just analyze

# Run all tests
just test

# Run unit tests only
just test-unit

# Run integration tests only
just test-integration
```

## Integration Tests

Integration tests require a physical SkyEcho device:

1. Connect to the SkyEcho WiFi network (SSID: `SkyEcho_XXXX`)
2. Verify device is accessible at `http://192.168.4.1`
3. Run: `dart test test/integration/`

Tests will skip gracefully if the device is not available.

## Documentation

- **Quick Start**: This README
- **Detailed Guides**: `docs/how/skyecho-library/`
  - [Getting Started](docs/how/skyecho-library/getting-started.md) - Installation, first script, basic usage
  - [Error Handling](docs/how/skyecho-library/error-handling.md) - Error types, recovery patterns, best practices
  - [Testing Guide](docs/how/skyecho-library/testing-guide.md) - How to write tests, TAD approach, mocking
  - [Device Setup](docs/how/skyecho-library/device-setup.md) - Physical device setup for integration tests
  - [Troubleshooting](docs/how/skyecho-library/troubleshooting.md) - Common issues, solutions, FAQ
- **API Reference**: Dartdoc comments in source code

## Project Structure

```
skyecho-controller-app/
├── packages/
│   └── skyecho/
│       ├── lib/
│       │   └── skyecho.dart          # Main library (single file)
│       ├── test/
│       │   ├── unit/                 # Fast offline tests
│       │   ├── integration/          # Real device tests
│       │   └── fixtures/             # Captured HTML/JSON samples
│       └── example/
│           └── main.dart             # CLI example app
├── docs/
│   ├── plans/                        # Feature specifications
│   └── rules-idioms-architecture/    # Project doctrine
└── README.md                         # This file
```

## Saved Aircraft Profiles

The Tactical Radar app includes a saved aircraft profiles feature that allows you to quickly switch between multiple aircraft without re-entering callsign and ICAO hex codes.

### What It Does

- **Save Aircraft**: Store callsign + ICAO hex pairs for all your aircraft
- **Quick Selection**: Choose from a dropdown on the home screen
- **Auto-Sync**: Automatically selects the profile matching your connected device
- **Auto-Creation**: Creates new profiles when connecting to unknown aircraft
- **Persistent Storage**: Profiles saved locally and persist across app restarts

### Getting Started

#### 1. Access the Planes Screen

Tap the **"Planes"** tab in the bottom navigation bar to manage your saved aircraft.

#### 2. Add Your First Aircraft

1. Tap the **+** button (floating action button)
2. Enter your aircraft's **callsign** (e.g., "N12345" or "VH-ABC")
3. Enter your aircraft's **ICAO hex code** (e.g., "7CC599")
   - You can enter in any format: `7cc599`, `0x7CC599`, or `ABC123`
   - The app automatically normalizes to uppercase 6-digit format
4. Tap **"Save"**

Your aircraft profile is now saved and will appear in the list.

#### 3. Edit or Delete Profiles

- **Edit**: Tap a profile in the list to modify callsign or hex code
- **Delete**: Tap the delete icon (🗑️) and confirm

#### 4. Quick Selection on Home Screen

On the **Config** tab, you'll see a dropdown labeled "Select aircraft" above the hex/callsign fields:

1. Tap the dropdown to see all your saved aircraft
2. Select an aircraft to instantly populate the fields
3. Tap **"Save"** to apply the configuration to your SkyEcho device

### Auto-Selection (Device Sync)

When you connect to a SkyEcho device:

- **Known Aircraft**: If the device's hex code matches a saved profile, that profile is automatically selected
- **New Aircraft**: If the device's hex code is unknown, the app creates a new profile and auto-selects it
- **Offline Mode**: If the device is offline, the app uses your last-used profile as a fallback

You'll see a notification when profiles are auto-created or when the device is offline.

### How Dropdown Auto-Selection Works

The dropdown shows your saved aircraft in alphabetical order by callsign, with your **last-used aircraft pinned to the top** for quick access.

**Example:**
```
VH-ABC (7CC599)  ← Last used (pinned to top)
─────────────────
N12345 (ABC123)  ← Alphabetical
N67890 (DEF456)
VH-XYZ (999ABC)
```

### Duplicate Prevention

The app prevents duplicate hex codes:

- If you try to save a profile with a hex that already exists, you'll see an error message: *"Aircraft with hex ABC123 already exists (N12345)"*
- **Solution**: Edit the existing profile or use a different hex code
- Hex matching is **case-insensitive**, so `7cc599` and `7CC599` are treated as duplicates

### Troubleshooting

**"Device offline – using last known profile"**
- The app couldn't connect to your SkyEcho device within 10 seconds
- Your last-used profile is loaded as a fallback
- Check that you're connected to the SkyEcho WiFi network and the device is powered on

**"New aircraft added with temporary callsign - please update"**
- The device had a hex code but no callsign configured
- A placeholder callsign like "Aircraft-7CC599" was auto-generated
- Tap the profile in the Planes screen to update it with the correct callsign

**Profile changes in Planes screen don't appear in Config dropdown**
- This should happen automatically via real-time sync
- If the dropdown doesn't update, try navigating away and back to the Config tab

**Can't delete the last profile**
- You can delete all profiles - the app will show an empty state with instructions

### Data Storage

- Profiles are stored **locally on your device** using SharedPreferences
- **No cloud sync** - profiles are device-specific
- Profiles persist across app restarts and updates
- Maximum recommended profiles: ~20 (no hard limit)

### Tips

✅ **Enter hex in any format** - The app accepts `0x7CC599`, `7cc599`, or `ABC123`

✅ **Trust the auto-creation** - When connecting to a new aircraft, the app will create a profile automatically

✅ **Use descriptive callsigns** - Makes it easier to identify aircraft in the dropdown

✅ **Verify before saving** - Always double-check the callsign and hex match your aircraft documentation

## Safety Notes

⚠️ **ADS-B Transmit**: The library includes runtime safety checks to prevent accidental activation of ADS-B transmit functionality. The example CLI application enforces these checks. Always verify transmit flags are disabled before applying configuration updates.

## License

See LICENSE file for details.

## Contributing

This project follows Test-Assisted Development (TAD) methodology. See `docs/rules-idioms-architecture/` for coding standards and contribution guidelines.
