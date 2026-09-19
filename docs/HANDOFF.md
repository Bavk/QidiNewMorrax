# Handoff — OrcaSlicer engine cutover

## Architecture decision

QidiNewMorrax no longer reimplements the slicer or Clipper in Dart. Production slicing and G-code generation are delegated to a pinned OrcaSlicer engine; Flutter/Dart owns the surrounding QIDI application, editor/project state, profile selection, Preview, Device integration and calibration.

Pinned engine:

- OrcaSlicer v2.4.2
- commit `8500fcdccaa10b5099ac20d252af3a7c560046f1`
- Ubuntu 24.04 AppImage SHA-256 `d12fb8c8eac1aecd2dfb6377acd48f994f8fa439ed5292fa532dd82880f029fd`
- GNU AGPL-3.0

Read [ORCASLICER_ENGINE.md](ORCASLICER_ENGINE.md) and [../migration/PARITY_CONTRACT.md](../migration/PARITY_CONTRACT.md) before continuing. Generated-project editing now follows the explicit `plate -> object -> volumes` contract in `PARITY_CONTRACT.md`; do not collapse modifier/support volumes into a single object mesh when extending Prepare.

## Current production path

The cutover now routes the application through:

1. Prepare model/project state and QIDI machine/process/filament selection in Dart.
2. Generated state -> Orca/Bambu split-model project 3MF with embedded resolved `project_settings.config`; imported QIDI/Bambu/Orca 3MF is repacked losslessly and keeps vendor entries.
3. `OrcaSlicerEngine` -> pinned Orca headless CLI.
4. Orca sliced `.gcode.3mf` -> all available `Metadata/plate_N.gcode` entries plus `Metadata/slice_info.config`.
5. Selected plate G-code + authoritative Orca estimates/warnings/material usage -> Dart Preview.
6. Latest selected G-code + selected-plate estimate -> Dart Device -> Moonraker `/server/files/upload` -> optional print start.

The old `lib/core/slicer` tree, its test suite, the Dart Clipper compatibility layer, custom G-code writer/emitter/extruder implementation, and `clipper2` dependency are removed from production.

## Validated checkpoint — 2026-09-19

Functional code checkpoint:

- code: `cbc806db7ecf00c87b6730c4167fa3d3f622223a`;
- Flutter parity run `35401167437` (#752), job `105781146290`;
- `flutter analyze` — **No issues found!**;
- `flutter test --reporter expanded` — **134/134 passed**;
- conclusion — **success**.

Real engine checkpoint on the same functional HEAD:

- Orca smoke run `35401167530` (#180), job `105781147329`;
- downloaded Orca v2.4.2 Ubuntu 24.04 AppImage passed the pinned SHA-256 check;
- QIDI X-Plus 4 machine/process/PLA profiles were loaded by the real engine;
- the real QIDI X-Plus 4 two-plate project fixture sliced successfully;
- both `Metadata/plate_1.gcode` and `Metadata/plate_2.gcode` were present with printable G0/G1 moves;
- progress reached **100%**, and each plate retained the verified **1167 s** prediction / **1.335 m** filament metadata fallback;
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

## Editable Prepare project checkpoint — 2026-09-19

PR #14 wires the verified project serializer into real generated-project editing instead of keeping multi-plate state as a handoff-only capability:

- new immutable `WorkspaceEditableProject` domain state owns generated plates and objects;
- Prepare can add multiple source models, create/rename/lock/remove plates, select/move/remove objects between plates, and render the active plate as a merged viewport;
- Move/Rotate/Scale/Center operate on the selected generated object and the same edited state is handed to `WorkspaceController`;
- object name, plate assignment, wall-loop and sparse-infill overrides are serialized into the existing Orca/Bambu `model_settings.config`;
- the editor currently keeps the production filament slot at extruder 1 because runtime profile materialization still loads one selected filament;
- a single imported vendor 3MF intentionally stays on the existing lossless read/repack path; structural editing of imported package internals is not promoted by this batch.

Functional HEAD `cbc806db7ecf00c87b6730c4167fa3d3f622223a` is green in Flutter run `35401167437` (#752), job `105781146290`: analyzer clean, **134/134 tests passed**. Orca smoke `35401167530` (#180), job `105781147329`, is also green on the same HEAD with the pinned AppImage and verified two-plate QIDI fixture.

## First unfinished priority

The next application boundary is richer editing of the already verified project model. Continue in this order:

1. Continue the richer Prepare editor beyond the now-wired generated multi-plate/object path: create/edit modifier, support-enforcer and support-blocker volumes; add facet paint editing; add real multi-filament selection/assignment; widen per-object/per-volume overrides; then decide how much structured editing imported vendor 3MF can support without violating lossless preservation.
2. Consume remaining sliced-package presentation data such as thumbnails and additional vendor printer-payload metadata where useful.
3. Verify Moonraker upload/start against representative QIDI hardware.
4. Package and verify the exact Orca engine for Windows/macOS/Linux, including updater/version checks and platform progress behavior.
5. Complete AGPL notices/corresponding-source delivery for distributed builds.
6. Continue Dart/Flutter Device/calibration/UI integration around the stable engine boundary.

Do not reintroduce a parallel custom production slicer or Clipper in Dart.
