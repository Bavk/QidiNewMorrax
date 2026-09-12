# Migration status — strict 1:1 parity

The authoritative acceptance contract is [`PARITY_CONTRACT.md`](PARITY_CONTRACT.md). “Feature parity”, “similar behavior” and “identical-enough” are **not** completion criteria. The goal is the same Qidi Flow 2.07.02.60 Pass28 application, fully reimplemented in Flutter + Dart without losing any relevant function, implementation behavior, data contract or edge case.

## Source audit

- Archive files inventoried: see `original_file_manifest.json`.
- Runtime data copied in the audited local workspace: profiles, printers, models, calibration data, fonts, images, shaders, certificates, i18n and PO catalogs.
- Legacy WebView JS/TS and native helpers are **not** executed by the Flutter application. Their behavior remains pending until replaced in Flutter/Dart.
- Source tests and fixtures are specification material and must be translated or used for differential comparison before executable modules become `parity_verified`.

## Required status semantics

- `pending` — no real Dart replacement yet.
- `port_started` — only part of the source behavior is implemented.
- `implemented_unverified` — intended replacement exists but source-reference parity has not been executed/proven.
- `parity_verified` — required source behavior and edge cases are covered by passing reference/differential tests.
- `runtime_asset_verified` — asset/data preservation is verified byte-for-byte or by an explicitly documented canonical transformation.

A similarly named Dart class or a visually similar screen never upgrades a source item by itself.

## Parity gates before calling the rewrite complete

1. **Formats/project persistence — 1:1:** every supported format, metadata extension, warning/repair path and project round-trip behavior; no silent metadata loss.
2. **Scene/editor — 1:1:** selection, hierarchy, move/scale/rotate, cut, split, repair, combine/boolean, text/emboss, painting, supports/seams, modifiers, multi-plate, undo/redo, shortcuts and interaction rules.
3. **Slicer/toolpath — 1:1:** source geometry semantics, classic/Arachne perimeters, thin walls/gap fill, surfaces, all required infills, bridges, supports, overhangs, seams, ironing, brim/skirt/raft, purge/prime structures, multi-material, adaptive layers, travel/retraction/wipe, flow/speed/acceleration/cooling, timelapse, templates, post-processing and estimates.
4. **Preview — 1:1:** layer/tool/color/feature views, G-code classifications, statistics, time/material estimates and interactions.
5. **Profiles/presets — 1:1:** machine/filament/process inheritance, expressions, defaults, compatibility, validation, user presets and import/export.
6. **Device/cloud — 1:1:** discovery, Moonraker/local control, account/cloud/P2P, printer selection/state, QIDI Box/AMS, files, timelapses, camera, HMS/diagnostics, firmware/capability gating, reconnect and restoration behavior.
7. **Calibration — 1:1:** every source wizard, validation flow and generated calibration artifact/toolpath.
8. **Desktop integration/release — 1:1:** supported platform behavior including associations, drag/drop, single instance, updater/package behavior and shell integrations used by the source.
9. **UI/localization/accessibility — 1:1:** complete screens/dialogs/actions/states, enable/disable/hide logic, keyboard/mouse workflows, shipped text/resources and localization behavior.
10. **Tests — 1:1 specification coverage:** applicable original tests translated plus differential/golden fixtures for observable behavior that original tests do not capture.

No gate above is currently closed.

## Current executable coverage

Existing Flutter/Dart foundations include model I/O, profiles/localization, local device integration, G-code parsing, triangle-plane slicing, line infill and a basic toolpath/G-code pipeline. They are foundations only and do not close their corresponding top-level gates.

### Geometry / Clipper status

- `ExPolygon2` model: **port_started**.
- Clipper/ClipperUtils-compatible Dart API for union/difference/intersection/xor, offsets, `offset2`, opening and closing: **implemented_unverified**.
- Source coordinate scaling is preserved: `SCALING_FACTOR = 0.00001` (100000 integer units/mm).
- Source default miter limit `3.0` is preserved in the compatibility layer.
- Initial fixtures from `test_clipper_offset.cpp` and `test_clipper_utils.cpp` have been translated to Dart but **not executed in this environment**.
- The current implementation uses the pure-Dart `clipper2` package. The supplied source also relies on Clipper 6.x/ClipperUtils semantics; if translated source fixtures reveal any semantic mismatch, the compatibility layer must be corrected or replaced with a direct Dart port. It must not be called parity-verified merely because common cases work.

### Classic perimeter status

A first subset of `PerimeterGenerator::process_classic()` is **port_started**, including source formulas/constants for:

- `INSET_OVERLAP_TOLERANCE = 0.4`;
- QIDI smaller external inset overlap tolerance `0.22`;
- narrow-loop threshold `10`;
- first external centerline inset;
- precise outer-wall external→internal spacing branch;
- `alternate_extra_wall` odd-layer behavior;
- spiral-vase largest-island selection;
- internal `offset2` formula including the source one-coordinate-unit safety adjustment (`0.00001 mm`).

The source `detect_thin_wall` medial-axis branch is intentionally **not approximated**; the current Dart implementation throws `UnsupportedError` for that branch until the source medial-axis/thick-polyline behavior is ported. Gap fill, thin-wall extraction and the rest of classic/Arachne perimeter generation remain pending.

## Validation truth

The current environment still cannot execute Flutter/Dart tooling. New tests and source code therefore remain `implemented_unverified`/`port_started` until `flutter analyze` and the translated/reference test suite run successfully. See `VALIDATION.md`.

## Immediate next source work

1. establish executable Flutter/Dart CI truth and run all currently translated tests;
2. expand translation of the original Clipper/ClipperUtils regression suite and fix every discrepancy;
3. complete missing ClipperUtils operations used by the slicer/editor;
4. port source medial-axis/thick-polyline logic needed by `detect_thin_wall` and gap fill;
5. continue `PerimeterGenerator::process_classic()` line-by-line, then Arachne and surface generation;
6. update symbol-level traceability as each source function becomes implemented and verified.
