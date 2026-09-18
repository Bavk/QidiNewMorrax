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

1. Prepare model/project state and QIDI machine/process/filament selection in Dart.
2. Generated state -> Orca/Bambu split-model project 3MF with embedded resolved `project_settings.config`; imported QIDI/Bambu/Orca 3MF is repacked losslessly and keeps vendor entries.
3. `OrcaSlicerEngine` -> pinned Orca headless CLI.
4. Orca sliced `.gcode.3mf` -> all available `Metadata/plate_N.gcode` entries plus `Metadata/slice_info.config`.
5. Selected plate G-code + authoritative Orca estimates/warnings/material usage -> Dart Preview.
6. Latest selected G-code + selected-plate estimate -> Dart Device -> Moonraker `/server/files/upload` -> optional print start.

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

## Project/3MF handoff checkpoint — 2026-09-18

PR #11 replaces the temporary STL bridge with an Orca-compatible project 3MF boundary:

- split production-extension 3MF (`3D/3dmodel.model` + `3D/Objects/*.model` + relationships);
- embedded resolved QIDI `Metadata/project_settings.config`;
- objects, multiple volumes, modifier/support volume types, facet paint metadata, per-object/per-volume settings and extruder assignment;
- explicit plate membership plus Orca virtual-bed offsets;
- lossless pass-through of imported vendor 3MF entries while applying build transforms;
- all sliced `plate_N.gcode` outputs exposed by the engine;
- old `MeshStlWriter` bridge removed;
- real Orca v2.4.2 smoke run `35397155859` (#104) slices both plates in one `--slice 0` invocation successfully.

## Progress/cancellation checkpoint — 2026-09-18

PR #12 moves Orca invocation to a managed process and wires Linux `--pipe` progress into the workspace UI. The pinned Orca smoke validates real FIFO JSON while slicing the two-plate project; cancellation has dedicated process-lifecycle unit coverage. Orca 2.4.2 compiles this pipe callback only on Linux, so equivalent native progress transport for packaged Windows/macOS builds remains open.

## Sliced metadata checkpoint — 2026-09-19

PR #13 consumes Orca's sliced-result metadata instead of inferring estimates in Dart:

- `OrcaSliceMetadata` parses `Metadata/slice_info.config` per plate: prediction, first-layer time, build-area/support flags, objects, filament records and structured warnings;
- XML values stay authoritative when Orca provides them;
- when Orca CLI leaves time/material fields empty or zero, Dart fills only those gaps from Orca-authored `plate_N.gcode` statistics comments (`estimated printing time`, `estimated first layer printing time`, `filament used [g]` / `[mm]`);
- Preview follows the selected plate and displays Orca estimates, support state, warnings and material usage;
- Device shows the selected Orca time/material estimate on the print action;
- manually opened G-code does not inherit stale workspace metadata;
- no mass is fabricated: the real QIDI CLI fixture reports zero grams, so Preview uses Orca's exact filament length instead.

Functional checkpoint `a69646d98fbc07de7004cda6b62ad78757a8d61a` is green in Flutter run `35400170625` (#746), job `105778026686`: analyzer clean, **131/131 tests passed**. Real Orca smoke `35400170623` (#173), job `105778021824`, is also green: both plates report **1167 s** prediction and **1.335 m** filament via the verified fallback path.

## First unfinished priority

The next application boundary is richer editing of the already verified project model. Continue in this order:

1. Wire the project model into richer Prepare editor UI for creating/editing multiple plates, modifiers, paint, filament assignment and per-object/per-volume settings instead of only preserving/serializing them.
2. Consume remaining sliced-package presentation data such as thumbnails and additional vendor printer-payload metadata where useful.
3. Verify Moonraker upload/start against representative QIDI hardware.
4. Package and verify the exact Orca engine for Windows/macOS/Linux, including updater/version checks and platform progress behavior.
5. Complete AGPL notices/corresponding-source delivery for distributed builds.
6. Continue Dart/Flutter Device/calibration/UI integration around the stable engine boundary.

Do not reintroduce a parallel custom production slicer or Clipper in Dart.
