# Monorepo Setup Guide

This document explains how to work with the SkyEcho Controller App monorepo structure and how to create new packages that depend on the core library.

## Monorepo Structure

This repository uses a **monorepo architecture** with multiple Dart packages:

```
skyecho-controller-app/             # Repository root (NOT a Dart package)
├── packages/                       # All Dart packages live here
│   ├── skyecho/                   # Core library (pure Dart, publishable)
│   │   ├── lib/
│   │   ├── test/
│   │   ├── example/
│   │   └── pubspec.yaml
│   └── skyecho_flutter_app/       # (Future) Flutter app using the library
│       ├── lib/
│       ├── test/
│       └── pubspec.yaml           # Depends on skyecho via path
├── docs/                          # Shared documentation (root level)
├── justfile                       # Build commands (root level)
└── .gitignore                     # Root gitignore (monorepo-aware)
```

## Key Concepts

### Pure Dart Library (`packages/skyecho/`)

- **Location**: `packages/skyecho/`
- **Purpose**: Platform-agnostic Dart library with no Flutter dependencies
- **Publishable**: Can be published to pub.dev independently
- **Lock file**: `pubspec.lock` is **excluded** from git (library convention)

### Flutter App (`packages/skyecho_flutter_app/`)

- **Location**: `packages/skyecho_flutter_app/` *(to be created)*
- **Purpose**: Flutter UI application that uses the core library
- **Dependency**: Uses **path dependency** to reference the library
- **Lock file**: `pubspec.lock` **should be committed** (app convention)

## Creating the Flutter App Package

When you're ready to create the Flutter app package:

### Step 1: Create Package Directory

```bash
cd packages
flutter create skyecho_flutter_app
```

### Step 2: Configure Path Dependency

Edit `packages/skyecho_flutter_app/pubspec.yaml`:

```yaml
name: skyecho_flutter_app
description: Flutter UI for SkyEcho 2 device control
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # ✅ CORRECT: Use path dependency for local monorepo packages
  skyecho:
    path: ../skyecho        # Relative to THIS package (skyecho_flutter_app)

dev_dependencies:
  flutter_test:
    sdk: flutter
```

**❌ WRONG paths:**
- `path: ../../packages/skyecho` (too many levels up)
- `path: /Users/you/github/skyecho-controller-app/packages/skyecho` (absolute paths break portability)

**✅ CORRECT path:**
- `path: ../skyecho` (relative from `packages/skyecho_flutter_app/` to `packages/skyecho/`)

### Step 3: Run `flutter pub get`

```bash
cd packages/skyecho_flutter_app
flutter pub get
```

This resolves the path dependency and links the packages.

### Step 4: Import and Use the Library

In your Flutter app code:

```dart
import 'package:skyecho/skyecho.dart';  // Import works as if published

Future<void> fetchDeviceStatus() async {
  final client = SkyEchoClient('http://192.168.4.1');
  final status = await client.fetchStatus();
  print('GPS Fix: ${status.hasGpsFix}');
}
```

## Common Gotchas

### Gotcha 1: IDE Not Recognizing Imports

**Problem**: After adding the path dependency, your IDE shows `package:skyecho/skyecho.dart` as unresolved.

**Solution**:
1. Run `flutter pub get` in the app package
2. Restart your IDE or run "Dart: Restart Analysis Server" (VS Code)
3. Ensure the library package path is correct (should be `../skyecho`)

### Gotcha 2: Changes to Library Not Reflected in App

**Problem**: You modify code in `packages/skyecho/` but the Flutter app doesn't pick up the changes.

**Solution**:
- Path dependencies use the **live code**, so changes should be immediate
- If not working, run `flutter pub get` again in the app package
- Hot reload has limitations with path dependencies; try **hot restart** instead

### Gotcha 3: Build Errors After Library Changes

**Problem**: After changing library code, the Flutter app fails to build.

**Solution**:
1. Run `cd packages/skyecho && dart analyze` to check for library errors first
2. Fix any breaking changes in the library
3. Update app code to match new library API
4. Clean and rebuild: `cd packages/skyecho_flutter_app && flutter clean && flutter pub get`

### Gotcha 4: pubspec.lock Confusion

**Problem**: Unsure whether to commit `pubspec.lock` in the Flutter app.

**Solution**:
- **Library** (`packages/skyecho/`): **DON'T commit** `pubspec.lock` (already in `.gitignore`)
- **Flutter App** (`packages/skyecho_flutter_app/`): **DO commit** `pubspec.lock` (ensures reproducible builds)

## Development Workflow with Path Dependencies

### Making Changes to the Library

1. **Edit library code** in `packages/skyecho/lib/skyecho.dart`
2. **Run library tests**: `cd packages/skyecho && dart test`
3. **Verify library analysis**: `cd packages/skyecho && dart analyze`
4. **Test in app**: Run the Flutter app (changes are live via path dependency)

### Testing Library Changes Before Committing

1. Make changes to library
2. Run `just test` from repo root (runs library unit tests)
3. Test manually in Flutter app if available
4. Commit library changes once validated

### Adding New Dependencies to Library

If you add a new dependency to `packages/skyecho/pubspec.yaml`:

1. Run `cd packages/skyecho && dart pub get`
2. **Important**: Also run `cd packages/skyecho_flutter_app && flutter pub get`
   - This updates the app's dependency resolution to include transitive deps
3. Restart IDE if imports aren't recognized

## Justfile Commands for Monorepo

The root `justfile` provides commands that work from the repository root:

```bash
# Library commands
just lib-install      # cd packages/skyecho && dart pub get
just lib-test         # Run all library tests
just lib-analyze      # Run library analysis

# Convenience aliases (default to library)
just install          # Same as lib-install
just test             # Same as lib-test
just analyze          # Same as lib-analyze
```

When you add the Flutter app, add these recipes to the justfile:

```just
# Flutter app commands (example for future)
app-install:
    cd packages/skyecho_flutter_app && flutter pub get

app-test:
    cd packages/skyecho_flutter_app && flutter test

app-run:
    cd packages/skyecho_flutter_app && flutter run
```

## Directory Conventions

### Shared Documentation

Documentation that applies to **multiple packages** or the **overall project** goes in `docs/` at the repository root:

```
docs/
├── how/
│   ├── monorepo-setup.md          # This file (monorepo guide)
│   ├── skyecho-library/           # Library-specific deep guides
│   └── skyecho-app/               # (Future) App-specific guides
└── rules-idioms-architecture/      # Project-wide standards
```

### Package-Specific Documentation

Documentation specific to **one package** can go in that package's directory:

```
packages/skyecho/
├── README.md                       # Library quick-start (package-specific)
├── CHANGELOG.md                    # Library version history
└── example/                        # Usage examples for the library
```

## Further Reading

- [Dart Package Layout Conventions](https://dart.dev/tools/pub/package-layout)
- [Flutter Monorepo Best Practices](https://flutter.dev/docs/development/packages-and-plugins/developing-packages#federated-plugins)
- [Path Dependencies in pub.dev](https://dart.dev/tools/pub/dependencies#path-packages)

## Quick Reference

| Scenario | Command | Notes |
|----------|---------|-------|
| Install library deps | `just install` or `cd packages/skyecho && dart pub get` | From repo root or library dir |
| Install app deps | `cd packages/skyecho_flutter_app && flutter pub get` | From app package dir |
| Run library tests | `just test` | From repo root |
| Run library analysis | `just analyze` | From repo root |
| Create Flutter app | `cd packages && flutter create skyecho_flutter_app` | Creates new package |
| Add path dependency | Edit `pubspec.yaml`: `skyecho: {path: ../skyecho}` | Relative from app to library |
| Fix IDE imports | `flutter pub get` + restart IDE | After adding path dep |
| Commit lock files | **Library**: NO, **App**: YES | Different conventions |

---

**Next Steps**: When you create the Flutter app, update this guide with any additional gotchas or workflow refinements you discover.
