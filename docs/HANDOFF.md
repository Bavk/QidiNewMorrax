# Handoff — OrcaSlicer engine cutover

## Architecture decision

QidiNewMorrax no longer reimplements the slicer or Clipper in Dart. Production slicing and G-code generation are delegated to a pinned OrcaSlicer engine; Flutter/Dart owns the surrounding QIDI application, editor/project state, profile selection, Preview, Device integration and calibration.

Pinned engine:

- OrcaSlicer v2.4.2
- commit `8500fcdccaa10b5099ac20d252af3a7c560046f1`
- Ubuntu 24.04 AppImage SHA-256 `d12fb8c8eac1aecd2dfb6377acd48f994f8fa439ed5292fa532dd82880f029fd`
- GNU AGPL-3.0

Read [ORCASLICER_ENGINE.md](ORCASLICER_ENGINE.md) and [../migration/PARITY_CONTRACT.md](../migration/PARITY_CONTRACT.md) before continuing.

## Current production path

The cutover now routes the application through:

1. Prepare model and QIDI machine/process/filament selection in Dart.
2. Current transformed mesh -> temporary STL and resolved preset JSON.
3. `OrcaSlicerEngine` -> Orca headless CLI.
4. Orca sliced `.gcode.3mf` -> `Metadata/plate_N.gcode` extraction.
5. Generated G-code -> Dart Preview.
6. Latest generated G-code -> Dart Device -> Moonraker `/server/files/upload` -> optional print start.

The old `lib/core/slicer` tree, its test suite, the Dart Clipper compatibility layer, custom G-code writer/emitter/extruder implementation, and `clipper2` dependency are removed from production.

## Validated checkpoint — 2026-09-18

Functional code checkpoint:

- code: `70e6919eaad04199738c09b682f8bdad5ec0d67f`;
- Flutter parity run `35392468990` (#670), job `105753727204`;
- `flutter analyze` — **No issues found!**;
- `flutter test --reporter expanded` — **114/114 passed**;
- conclusion — **success**.

Real engine checkpoint on the same functional HEAD:

- Orca smoke run `35392469054` (#27), job `105753727522`;
- downloaded Orca v2.4.2 Ubuntu 24.04 AppImage passed the pinned SHA-256 check;
- QIDI X-Plus 4 machine/process/PLA profiles were loaded by the real engine;
- a 20 mm cube was sliced successfully;
- produced `cube.gcode.3mf` contained `Metadata/plate_1.gcode` (**385515 bytes**);
- extracted G-code contained printable G0/G1 moves;
- conclusion — **success**.

## First unfinished priority

The engine boundary itself is now proven. Continue integration in this order:

1. Replace flattened STL handoff with full 3MF/project handoff so multiple plates, modifiers, paint, per-object settings, filament assignments and project metadata survive into Orca.
2. Add slicing progress and cancellation using Orca's `--pipe` integration.
3. Consume sliced 3MF metadata for richer Preview, estimates, warnings and printer payloads.
4. Package and verify the exact Orca engine for Windows/macOS/Linux, including updater/version checks.
5. Complete AGPL notices/corresponding-source delivery for distributed builds.
6. Continue Dart/Flutter project/editor/Device/calibration/UI integration around the stable engine boundary.

Do not reintroduce a parallel custom production slicer or Clipper in Dart.
