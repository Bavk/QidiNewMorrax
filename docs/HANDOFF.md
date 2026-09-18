# Handoff — OrcaSlicer engine cutover

## Architecture decision

The project no longer attempts to reimplement the slicer or Clipper in Dart. Production slicing/G-code is delegated to OrcaSlicer; Flutter/Dart owns the surrounding QIDI application.

Pinned engine:

- OrcaSlicer v2.4.2
- commit `8500fcdccaa10b5099ac20d252af3a7c560046f1`
- GNU AGPL-3.0

Read [ORCASLICER_ENGINE.md](ORCASLICER_ENGINE.md) and [../migration/PARITY_CONTRACT.md](../migration/PARITY_CONTRACT.md) before continuing.

## Current cutover

The branch replaces the old custom slicer path with:

- `OrcaSlicerEngine` subprocess/CLI adapter;
- resolved QIDI profile materialization;
- Prepare mesh -> STL engine handoff;
- sliced 3MF -> `Metadata/plate_N.gcode` extraction;
- generated G-code -> Dart Preview;
- functional Slice button in the main workspace.

The entire old `lib/core/slicer` tree, its tests, the Dart Clipper compatibility layer, custom G-code writer/emitter/extruder implementation, and `clipper2` dependency are removed.

## Validated Dart checkpoint

- code: `099b08ffe1e8e4c3aef61b03a27613d8422b8ab4`;
- Flutter parity run `35389777844` (#655), job `105745161355`;
- `flutter analyze` — **No issues found!**;
- `flutter test --reporter expanded` — **114/114 passed**;
- conclusion — **success**.

## Important truth

This is an architecture cutover, not a claim that integration is finished. The Dart bridge has unit/contract coverage, but the pinned Orca executable still needs to run in CI on representative QIDI presets/models. Release bundling and AGPL source/notice delivery are also pending.

## First unfinished priority

1. Add pinned OrcaSlicer v2.4.2 to CI and execute a real end-to-end QIDI slice.
2. Replace flattened STL handoff with full 3MF/project state for multiple plates, modifiers, paint and per-object settings.
3. Add slicing progress/cancellation with Orca's `--pipe`.
4. Consume sliced 3MF metadata for richer Preview, estimates and printer payloads.
5. Bundle and verify the exact engine in desktop releases with AGPL compliance.
6. Continue Dart/Flutter project/editor/Device/calibration/UI integration.
