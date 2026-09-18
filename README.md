# QidiNewMorrax

QidiNewMorrax is a Flutter/Dart desktop application for QIDI printing workflows. The application UI, projects, profiles, Preview, Device integration, calibration and desktop workflow are implemented in Dart/Flutter, while production slicing and G-code generation are delegated to a pinned OrcaSlicer engine.

## Architecture

The project deliberately no longer contains its own Dart Clipper/slicer stack.

- **Flutter/Dart:** application state, Prepare/editor, profile selection, project I/O, Preview, Device/cloud, calibration, localization and desktop UI.
- **OrcaSlicer v2.4.2:** polygon/offset operations, walls/Arachne, surfaces, infill, supports, seams, travel, flow/cooling and final G-code generation.
- **Boundary:** model/project data and QIDI presets are materialized for Orca's headless CLI; sliced 3MF/G-code returns to Dart for Preview and printer delivery.

See [docs/ORCASLICER_ENGINE.md](docs/ORCASLICER_ENGINE.md).

## Engine setup

Set `ORCA_SLICER_BIN` to the OrcaSlicer executable when it is not available at the platform default location.

The current bridge pins:

- OrcaSlicer `v2.4.2`
- commit `8500fcdccaa10b5099ac20d252af3a7c560046f1`
- GNU AGPL-3.0

Release bundling of the engine is still pending; development builds currently expect an installed/configured executable.

## Current application foundations

Implemented foundations include Flutter desktop navigation, Prepare model loading/transforms, QIDI profile loading/inheritance, lossless 3MF import/repack, Orca-compatible multi-plate project 3MF serialization, live Linux slicing progress, cancellation, G-code parsing/Preview, Moonraker/QIDI device foundations and calibration resources.

The Orca boundary now preserves/encodes project objects, plates, modifiers/paint metadata, settings and filament assignment and returns all sliced plate G-code entries. Richer Prepare editing, sliced-metadata consumption, cross-platform native progress transport and release packaging remain open.

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

For slicing during development, configure OrcaSlicer:

```bash
ORCA_SLICER_BIN=/path/to/orca-slicer flutter run -d linux
```

## License

This project is AGPL-derived, and OrcaSlicer itself is licensed under GNU AGPL-3.0. Distribution must preserve all applicable licensing, attribution and source-availability obligations.
