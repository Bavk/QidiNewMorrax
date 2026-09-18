# Migration status — OrcaSlicer engine architecture

## Architecture cutover

The previous pure-Dart slicer/Clipper migration has been retired from production. QidiNewMorrax now uses a pinned OrcaSlicer engine for slicing/G-code and keeps application/editor/device behavior in Flutter/Dart.

Pinned engine: OrcaSlicer v2.4.2, commit `8500fcdccaa10b5099ac20d252af3a7c560046f1`, AGPL-3.0.

## Implemented in this cutover

- Orca CLI bridge in `lib/core/orca/orca_slicer_engine.dart`;
- QIDI preset materialization for machine/process/filament JSON;
- current transformed Prepare mesh -> temporary STL handoff;
- `Slice plate` routes through Orca instead of a Dart slicer;
- sliced 3MF `Metadata/plate_N.gcode` extraction;
- automatic handoff of generated G-code to the existing Dart Preview;
- complete removal of the old `lib/core/slicer` tree, Dart Clipper compatibility layer, and custom Dart G-code generator;
- removal of the `clipper2` dependency.

## Status

| Area | Status | Next work |
|---|---|---|
| Orca engine process boundary | `implemented_unverified` | execute pinned Orca in CI/release environment |
| single active mesh + one machine/process/filament handoff | `implemented_unverified` | end-to-end Orca fixture |
| G-code extraction -> Dart Preview | `implemented_unverified` | end-to-end sliced bundle fixture |
| QIDI profile materialization | `implemented_unverified` | validate representative presets against Orca |
| multi-plate / modifiers / paint / per-object settings | `pending` | use project/3MF handoff instead of flattened STL |
| slicing progress / cancellation | `pending` | Orca `--pipe` integration |
| engine packaging / updater / exact version verification | `pending` | desktop packaging |
| AGPL notices / corresponding source delivery | `pending` release gate | package license/source information |
| Flutter editor/project/Preview/Device/calibration | `port_started` | continue application integration |

## Immediate priority

1. Make the pinned OrcaSlicer executable available in CI and execute an end-to-end QIDI slice.
2. Replace flattened STL handoff with full 3MF/project handoff so plate/object/modifier/paint metadata survives.
3. Add progress and cancellation using Orca's CLI progress pipe.
4. Consume sliced 3MF metadata for richer Preview/statistics and printer delivery.
5. Package the pinned engine for Windows/macOS/Linux with exact version checks and AGPL compliance.
6. Continue Flutter editor/project/Device/calibration/UI work around the stable engine boundary.
