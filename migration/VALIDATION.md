# Validation record — OrcaSlicer engine architecture

## Engine provenance

- upstream: `OrcaSlicer/OrcaSlicer`
- release: `v2.4.2`
- commit: `8500fcdccaa10b5099ac20d252af3a7c560046f1`
- Ubuntu 24.04 AppImage SHA-256: `d12fb8c8eac1aecd2dfb6377acd48f994f8fa439ed5292fa532dd82880f029fd`
- license: GNU AGPL-3.0
- CLI surface used by the Dart bridge: `--load-settings`, `--load-filaments`, `--arrange`, `--orient`, `--ensure-on-bed`, `--slice`, `--export-3mf`, `--outputdir`, plus Linux `--pipe` progress.

## Flutter/Dart cutover checkpoint — 2026-09-18

GitHub Actions run `35392468990` (#670), job `105753727204`, executed functional code `70e6919eaad04199738c09b682f8bdad5ec0d67f`:

- `flutter pub get` — success;
- `flutter analyze` — **No issues found!**;
- `flutter test --reporter expanded` — **114/114 passed**;
- conclusion — **success**.

The lower test count versus the former migration is intentional: the retired custom slicer/Clipper/Arachne suites were removed together with that production implementation and replaced by engine-boundary tests.

## Real OrcaSlicer smoke — 2026-09-18

GitHub Actions run `35392469054` (#27), job `105753727522`, executed the same functional HEAD:

- downloaded OrcaSlicer v2.4.2 Ubuntu 24.04 AppImage;
- SHA-256 verification — **OK**;
- loaded upstream QIDI X-Plus 4 machine/process/Generic PLA fixtures;
- sliced a closed 20 mm cube through the actual headless Orca engine;
- generated `cube.gcode.3mf`;
- bundle contained `Metadata/plate_1.gcode` with size **385515 bytes**;
- extraction succeeded and G0/G1 printable moves were present;
- conclusion — **success**.

This verifies the production engine process boundary, QIDI preset acceptance for the fixture, sliced 3MF production and G-code extraction used by Preview.

## Sliced metadata checkpoint — 2026-09-19

Functional code `a69646d98fbc07de7004cda6b62ad78757a8d61a`:

- Flutter run `35400170625` (#746), job `105778026686` — analyzer **No issues found**, **131/131 tests passed**;
- Orca smoke `35400170623` (#173), job `105778021824` — **success**;
- the pinned two-plate QIDI fixture produced two `plate_N.gcode` entries and `Metadata/slice_info.config`;
- each plate exposed **1167 s** prediction;
- Orca CLI left gram-based mass at zero for this fixture, while its own G-code statistics reported **1.335 m** filament per plate;
- validation therefore locks the production rule: use positive XML values first, then fill only missing/zero fields from Orca-authored G-code statistics, and do not synthesize mass from length/density.

## Editable Prepare project checkpoint — 2026-09-19

Functional code `cbc806db7ecf00c87b6730c4167fa3d3f622223a`:

- Flutter run `35401167437` (#752), job `105781146290` — analyzer **No issues found**, **134/134 tests passed**;
- Orca smoke `35401167530` (#180), job `105781147329` — **success**;
- generated Prepare state is represented by immutable `WorkspaceEditableProject` plates/objects and is passed through `WorkspaceController` into the existing production `ThreeMfProjectWriter`;
- unit coverage locks plate creation/removal/reassignment, per-object transforms/settings and serialized multi-plate production 3MF;
- the real pinned Orca smoke remains green with both `plate_1.gcode` and `plate_2.gcode`, printable G0/G1 moves, **100%** progress and the previously verified **1167 s / 1.335 m** metadata per plate.

This checkpoint verifies the generated multi-plate/object editing boundary only. Modifier/support volumes, facet paint authoring, true multi-filament runtime selection and wider per-volume overrides remain open. Imported vendor 3MF continues through the lossless read/repack path rather than being structurally rewritten by the editor.

## Dart boundary tests

The Flutter suite additionally covers:

- exact Orca CLI argument construction, including Orca's `--outputdir`, relative `--export-3mf` and optional `--pipe` semantics;
- Orca progress JSON parsing for messages/warnings and overall/plate percentages;
- managed-process cancellation without waiting for inherited stdout/stderr descriptors;
- sliced 3MF `Metadata/plate_N.gcode` extraction and missing-plate failure;
- `Metadata/slice_info.config` headers, per-plate estimates/flags/objects/filaments/warnings;
- Orca G-code time/gram/millimeter fallback, including the real length-only case where mass stays unknown;
- selected QIDI profile JSON materialization;
- editable generated multi-plate workspace state, object reassignment/transforms/settings and production 3MF serialization;
- project 3MF serialization, lossless vendor repack and virtual-bed coordinate mapping.

## Device integration

The latest generated Orca G-code and selected-plate estimate are routed into the Dart Device surface. `MoonrakerClient` uploads G-code through `/server/files/upload`, and `DeviceController.uploadAndStart()` can start the returned remote filename. This path is analyzer/test clean but still requires printer-backed validation before it is marked integration-verified.

## Remaining validation gates

- sliced thumbnails and additional vendor printer-payload metadata where useful;
- packaged macOS/Windows progress behavior and process-tree cancellation validation;
- Moonraker upload/start on representative QIDI hardware;
- packaged Windows/macOS/Linux engine artifacts and exact-version verification;
- AGPL notice/corresponding-source delivery in release packaging.

## Historical evidence

Earlier Bambu/QIDI Clipper/Arachne source oracles established detailed parity for the retired custom Dart slicer path. That evidence remains in git history but is no longer a production acceptance requirement after the OrcaSlicer architecture decision.
