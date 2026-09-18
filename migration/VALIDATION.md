# Validation record — OrcaSlicer engine architecture

## Engine provenance

- upstream: `OrcaSlicer/OrcaSlicer`
- release: `v2.4.2`
- commit: `8500fcdccaa10b5099ac20d252af3a7c560046f1`
- license: GNU AGPL-3.0
- supported CLI surface used by the Dart bridge: `--load-settings`, `--load-filaments`, `--arrange`, `--orient`, `--ensure-on-bed`, `--slice`, `--export-3mf`, `--outputdir`.

## Flutter/Dart cutover checkpoint — 2026-09-18

GitHub Actions run `35389777844` (#655), job `105745161355`, executed code `099b08ffe1e8e4c3aef61b03a27613d8422b8ab4`:

- `flutter pub get` — success;
- `flutter analyze` — **No issues found!**;
- `flutter test --reporter expanded` — **114/114 passed**;
- conclusion — **success**.

The lower test count is intentional: the retired custom slicer/Clipper/Arachne test suites were deleted together with that production implementation and replaced by tests at the Orca engine boundary.

## Cutover validation scope

The new Dart tests validate without needing an Orca executable:

- exact CLI argument construction;
- sliced 3MF `Metadata/plate_N.gcode` extraction and missing-plate failure;
- selected QIDI profile JSON materialization;
- transformed mesh -> STL interchange serialization.

Flutter analyzer/test results for the cutover are recorded only after the branch CI runs.

## Not yet executed

A real OrcaSlicer v2.4.2 binary has not yet been executed by this repository's CI as part of the cutover. Therefore end-to-end slicing, QIDI profile acceptance by Orca, sliced 3MF production, and release packaging remain `implemented_unverified`/pending rather than verified.

## Historical evidence

Earlier Bambu/QIDI Clipper/Arachne source oracles established detailed parity for the retired custom Dart slicer path. That evidence is retained in git history but is no longer a production acceptance requirement after the OrcaSlicer architecture decision.
