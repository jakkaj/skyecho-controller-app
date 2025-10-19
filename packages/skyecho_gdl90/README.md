# skyecho_gdl90

Pure-Dart library for receiving and parsing GDL90 aviation data streams from SkyEcho and other ADS-B devices.

**Status**: Work in progress (Phase 1 - project setup)

## Installation

Coming soon.

## Usage

Coming soon.

## Package Structure

```
skyecho_gdl90/
├── lib/
│   ├── skyecho_gdl90.dart      # Main library export
│   └── src/                    # Internal implementation (private)
├── test/
│   ├── unit/                   # Unit tests (fast, offline)
│   ├── integration/            # Integration tests (may require device)
│   └── fixtures/               # Binary test fixtures
├── example/                    # Example code (Phase 10)
├── tool/                       # Utilities (Phase 9-10)
├── pubspec.yaml                # Package metadata
├── analysis_options.yaml       # Linting rules
├── .gitignore                  # Git exclusions
├── README.md                   # This file
└── CHANGELOG.md                # Version history
```

## Development

### Scratch Testing Convention

**Temporary experiments** should use either:
1. `test/scratch/` directory (gitignored), OR
2. `scratch_*.dart` filename prefix (gitignored)

**Promote to** `test/unit/` when test adds durable value.

`.gitignore` patterns ensure scratch code never commits accidentally.

## Documentation

See [docs/how/skyecho-gdl90/](../../docs/how/skyecho-gdl90/) (to be created in Phase 11).
