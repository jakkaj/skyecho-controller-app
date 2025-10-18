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

## Safety Notes

⚠️ **ADS-B Transmit**: The library includes runtime safety checks to prevent accidental activation of ADS-B transmit functionality. The example CLI application enforces these checks. Always verify transmit flags are disabled before applying configuration updates.

## License

See LICENSE file for details.

## Contributing

This project follows Test-Assisted Development (TAD) methodology. See `docs/rules-idioms-architecture/` for coding standards and contribution guidelines.
