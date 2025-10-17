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
