# Validation record — OrcaSlicer engine architecture

## Engine provenance

- upstream: `OrcaSlicer/OrcaSlicer`
- release: `v2.4.2`
- commit: `8500fcdccaa10b5099ac20d252af3a7c560046f1`
- Ubuntu 24.04 AppImage SHA-256: `d12fb8c8eac1aecd2dfb6377acd48f994f8fa439ed5292fa532dd82880f029fd`
- license: GNU AGPL-3.0
- CLI surface used by the Dart bridge: `--load-settings`, `--load-filaments`, `--arrange`, `--orient`, `--ensure-on-bed`, `--slice`, `--export-3mf`, `--outputdir`.

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

## Dart boundary tests

The Flutter suite additionally covers:

- exact Orca CLI argument construction, including Orca's `--outputdir` + relative `--export-3mf` semantics;
- sliced 3MF `Metadata/plate_N.gcode` extraction and missing-plate failure;
- selected QIDI profile JSON materialization;
- transformed mesh -> STL interchange serialization.

## Device integration

The latest generated Orca G-code is routed into the Dart Device surface. `MoonrakerClient` now uploads it through `/server/files/upload`, and `DeviceController.uploadAndStart()` can start the returned remote filename. This path is analyzer/test clean but still requires printer-backed validation before it is marked integration-verified.

## Remaining validation gates

- full 3MF/project handoff preserving multiple plates, modifiers, paint, per-object settings and vendor metadata;
- Orca `--pipe` progress and cancellation;
- richer sliced 3MF metadata/estimate/warning consumption;
- Moonraker upload/start on representative QIDI hardware;
- packaged Windows/macOS/Linux engine artifacts and exact-version verification;
- AGPL notice/corresponding-source delivery in release packaging.

## Historical evidence

Earlier Bambu/QIDI Clipper/Arachne source oracles established detailed parity for the retired custom Dart slicer path. That evidence remains in git history but is no longer a production acceptance requirement after the OrcaSlicer architecture decision.
