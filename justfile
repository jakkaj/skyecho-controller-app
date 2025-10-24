# SkyEcho Controller Library - Build Automation
#
# This justfile provides commands for the monorepo structure.
# All library commands work from the repository root.

# Default recipe lists all available commands
default:
    @just --list

# === Library Package Commands (packages/skyecho/) ===

# Install dependencies for the library package
lib-install:
    cd packages/skyecho && dart pub get

# Run static analysis on the library package
lib-analyze:
    cd packages/skyecho && dart analyze

# Format code in the library package
lib-format:
    cd packages/skyecho && dart format .

# Run all tests (unit + integration) for the library package
lib-test:
    cd packages/skyecho && dart test

# Run only unit tests (fast, offline)
lib-test-unit:
    cd packages/skyecho && dart test test/unit/

# Run only integration tests (requires SkyEcho device at http://192.168.4.1)
lib-test-integration:
    cd packages/skyecho && dart test test/integration/

# Generate test coverage report
lib-coverage:
    cd packages/skyecho && dart test --coverage=coverage
    cd packages/skyecho && dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib

# === Convenience Aliases (default to library package) ===

# Install dependencies (alias for lib-install)
install: lib-install

# Run static analysis (alias for lib-analyze)
analyze: lib-analyze

# Format code (alias for lib-format)
format: lib-format

# Run all tests (alias for lib-test)
test: lib-test

# Run unit tests only (alias for lib-test-unit)
test-unit: lib-test-unit

# Run integration tests only (alias for lib-test-integration)
test-integration: lib-test-integration

# Generate coverage report (alias for lib-coverage)
coverage: lib-coverage

# === Development Workflow ===

# Format code and fix analyzer issues automatically
fix: format
    cd packages/skyecho && dart fix --apply

# Full validation: install deps, analyze, format, run tests
validate: install analyze test

# Clean build artifacts
clean:
    rm -rf packages/skyecho/.dart_tool
    rm -rf packages/skyecho/build
    rm -f packages/skyecho/pubspec.lock

# === Example CLI Commands ===

# Show CLI help
example-help:
    cd packages/skyecho && dart run example/main.dart --help

# Ping the device (check connectivity)
example-ping:
    cd packages/skyecho && dart run example/main.dart ping

# Get device status
example-status:
    cd packages/skyecho && dart run example/main.dart status

# Get device configuration (all settings)
example-config:
    cd packages/skyecho && dart run example/main.dart config

# Demonstrate configuration update (safe example)
example-configure:
    cd packages/skyecho && dart run example/main.dart configure

# Ping with custom URL
example-ping-url URL='http://192.168.4.1':
    cd packages/skyecho && dart run example/main.dart --url {{URL}} ping

# Run all example commands in sequence
example-all: example-ping example-status example-config example-configure

# === GDL90 Package Commands (packages/skyecho_gdl90/) ===

# Install dependencies for the GDL90 package
gdl90-install:
    cd packages/skyecho_gdl90 && dart pub get

# Run static analysis on the GDL90 package
gdl90-analyze:
    cd packages/skyecho_gdl90 && dart analyze

# Format code in the GDL90 package
gdl90-format:
    cd packages/skyecho_gdl90 && dart format .

# Run all tests for the GDL90 package
gdl90-test:
    cd packages/skyecho_gdl90 && dart test

# Run only unit tests for the GDL90 package
gdl90-test-unit:
    cd packages/skyecho_gdl90 && dart test test/unit/

# Test GDL90 stream with real SkyEcho device (default 30s)
gdl90-test-device DURATION='30':
    cd packages/skyecho_gdl90 && dart run example/real_device_test.dart --duration {{DURATION}}

# Capture raw 0x65 messages for ForeFlight extension development
gdl90-capture-0x65:
    cd packages/skyecho_gdl90 && dart run example/capture_0x65.dart

# Full GDL90 validation: install deps, analyze, format, run tests
gdl90-validate: gdl90-install gdl90-analyze gdl90-test
