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

## Editable modifier/support volume checkpoint — 2026-09-19

Functional code `3aa01f3fd65c618c22d9eeffa1c9056e00e0689c`:

- Flutter run `35456145423` (#761), job `105931646159` — analyzer **No issues found**, **136/136 tests passed**;
- Orca smoke `35456145434` (#189), job `105931646222` — **success**;
- generated objects now own explicit child volumes instead of a single flattened mesh;
- Dart coverage locks add/update/remove behavior and exact serialization of `normal_part`, `modifier`, `support_enforcer` and `support_blocker` subtypes plus volume-scoped settings;
- the pinned Orca fixture itself now contains all three non-normal subtype classes and slices both plates successfully, proving the real engine accepts the produced project structure.

This checkpoint does not claim facet-paint authoring or true multi-filament runtime assignment; those remain the next Prepare boundaries.

## Facet paint checkpoint — 2026-09-19

Functional code `c54cbacf31346049e7dd342759e12f5795e95a8b`:

- Flutter run `35457718002` (#770), job `105935857211` — analyzer **No issues found**, **138/138 tests passed**;
- Orca smoke `35457717977` (#198), job `105935857104` — **success**;
- Dart state edits support, seam and fuzzy-skin facet channels independently and preserves sibling channels on the same triangle;
- source-shaped whole-triangle codes are locked to pinned Orca `TriangleSelector`: ENFORCER `4`, BLOCKER `8`;
- facet paint is rejected on non-`normal_part` volumes, matching Orca painter behavior;
- the real pinned Orca fixture contains `paint_supports="4"`, `paint_seam="8"` and `paint_fuzzy_skin="4"` and still slices both plates successfully;
- Prepare exposes an initial range-based authoring UI (`0,2-8,15` / `all`); viewport brush/hit-testing remains a presentation enhancement over the same verified facet state.

MMU/material color paint is not promoted by this checkpoint. It remains coupled to real runtime multi-filament slot materialization.

## Linux packaged engine checkpoint — 2026-09-19

Functional/release code `6e51c7e8c571a4158a43317ae5f6ca022cb1a195`:

- Flutter run `35459351874` (#783), job `105940282076` — analyzer **No issues found**, **141/141 tests passed**;
- Orca smoke `35459351908` (#211), job `105940282185` — **success**;
- Linux packaged release smoke `35459351920` (#4), job `105940282171` — **success**;
- pinned Flutter 3.47.2 generated the Linux desktop scaffold and built `build/linux/x64/release/bundle/qidi_flow_flutter`;
- the exact OrcaSlicer v2.4.2 Ubuntu 24.04 AppImage was placed at `bundle/orca/OrcaSlicer.AppImage`, its upstream SHA-256 matched the pin, and the canonical `orca-engine.json` manifest was copied beside it;
- `tool/verify_packaged_orca.dart` resolved the bundled engine through the same Dart runtime discovery code and re-validated manifest version/commit/platform plus the actual AppImage SHA-256;
- the portable archive contained both the AppImage and provenance manifest and was uploaded as workflow artifact `qidi-new-morrax-linux-x64` (artifact id `10588977100`, **147,540,938 bytes**).

This closes the bundled-engine/version/hash gate for the Linux-first v0.1 target. The artifact is still a CI portable bundle rather than a claim of AGPL-complete public distribution.

## Packaged offline application checkpoint — 2026-09-19

Functional/release code `9a2701a879138f1dce113c9b9a8255d07192f8cf`:

- Flutter run `35462902220` (#806), job `105949847037` — analyzer **No issues found**, **142/142 tests passed**;
- Orca smoke `35462902163` (#234), job `105949846774` — **success**;
- Linux packaged release smoke `35462902353` (#27), job `105949847400` — **success**;
- the release workflow generated **1547** QIDI profiles from the exact pinned Orca source tree and compiled them into `assets/generated/profile_catalog.json` before Flutter build;
- the packaged release executable was launched under Xvfb with no `ORCA_SLICER_BIN` override, so the app discovered and verified its sibling bundled AppImage;
- the production path loaded a four-triangle STL, resolved the packaged X-Plus 4 machine/process/PLA profiles, materialized the project and presets, sliced through bundled Orca, parsed sliced metadata and parsed Preview G-code;
- smoke output: **5005 moves**, **1988 extrusion moves**, **537 s** prediction, **0.35 m** filament, selected plate 1, `packaged_engine_verified=true`, `preview_ready=true`;
- release-material artifact `qidi-new-morrax-linux-x64-release` id `10590381363` uploaded successfully.

This closes the automated packaged offline open/import -> slice -> Preview-input gate. The smoke is intentionally non-interactive; a visual desktop sanity pass remains release QA, while printer-backed upload/start remains the only hard v0.1 integration gate.


## Dart boundary tests

The Flutter suite additionally covers:

- exact Orca CLI argument construction, including Orca's `--outputdir`, relative `--export-3mf` and optional `--pipe` semantics;
- packaged Linux engine discovery precedence, provenance manifest validation and tampered-AppImage SHA-256 rejection;
- Orca progress JSON parsing for messages/warnings and overall/plate percentages;
- managed-process cancellation without waiting for inherited stdout/stderr descriptors;
- sliced 3MF `Metadata/plate_N.gcode` extraction and missing-plate failure;
- `Metadata/slice_info.config` headers, per-plate estimates/flags/objects/filaments/warnings;
- Orca G-code time/gram/millimeter fallback, including the real length-only case where mass stays unknown;
- selected QIDI profile JSON materialization;
- packaged profile-catalog generation from pinned Orca source plus real packaged-binary profile resolution/slice/Preview-input smoke;
- editable generated multi-plate workspace state, object reassignment/transforms/settings and production 3MF serialization;
- editable child-volume subtype/settings behavior and real Orca acceptance of modifier/support-enforcer/support-blocker project structure;
- source-shaped support/seam/fuzzy-skin facet annotations, normal-part scope enforcement and real Orca paint-attribute acceptance;
- project 3MF serialization, lossless vendor repack and virtual-bed coordinate mapping.

## Device integration

The latest generated Orca G-code and selected-plate estimate are routed into the Dart Device surface. `MoonrakerClient` uploads G-code through `/server/files/upload`, and `DeviceController.uploadAndStart()` can start the returned remote filename. This path is analyzer/test clean but still requires printer-backed validation before it is marked integration-verified.

## Remaining validation gates

First-launch hard gates:

- Linux packaged-engine discovery/version/hash verification — **closed**;
- pinned QIDI runtime profile catalog in the packaged app — **closed**;
- AGPL notice/corresponding-source engineering delivery — **closed**;
- packaged offline model open/import -> slice -> Preview-input path — **closed** by release smoke #27;
- Moonraker upload/start on representative QIDI hardware — **open** and cannot be replaced by another mock.

Post-v0.1 or widened-target gates:

- true multi-filament/MMU authoring and `paint_color` with materialized slots;
- viewport paint brush/hit-testing UX;
- sliced thumbnails and additional vendor printer-payload metadata where useful;
- packaged macOS/Windows progress behavior and process-tree cancellation validation;
- all-platform packaged engine artifacts if v0.1 is released on more than the first target.

## Historical evidence

Earlier Bambu/QIDI Clipper/Arachne source oracles established detailed parity for the retired custom Dart slicer path. That evidence remains in git history but is no longer a production acceptance requirement after the OrcaSlicer architecture decision.
