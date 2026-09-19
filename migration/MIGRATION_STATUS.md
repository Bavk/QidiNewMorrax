# Migration status — OrcaSlicer engine architecture

## Architecture cutover

The previous pure-Dart slicer/Clipper migration has been retired from production. QidiNewMorrax now uses a pinned OrcaSlicer engine for slicing/G-code and keeps application/editor/device behavior in Flutter/Dart.

Pinned engine:

- OrcaSlicer v2.4.2
- commit `8500fcdccaa10b5099ac20d252af3a7c560046f1`
- Ubuntu 24.04 AppImage SHA-256 `d12fb8c8eac1aecd2dfb6377acd48f994f8fa439ed5292fa532dd82880f029fd`
- license: GNU AGPL-3.0

## Validated checkpoint — 2026-09-19

- functional code `c8d0f9c703d98ac5ed25d2719390e71bcfc0e1ea`;
- Flutter CI `35459879595` (#793), job `105941708672`;
- analyzer: **No issues found**;
- tests: **142/142 passed**;
- Orca smoke `35459879618` (#221), job `105941708762`, conclusion **success**;
- real QIDI X-Plus 4 two-plate slice remains green; Linux packaged release smoke `35459879592` (#14), job `105941708711`, succeeds with embedded legal notices plus exact QidiNewMorrax/Orca source archives in one release-materials artifact.

## Implemented in this cutover

- Orca CLI bridge in `lib/core/orca/orca_slicer_engine.dart`;
- QIDI preset materialization for machine/process/filament JSON;
- Orca/Bambu-compatible split-model project 3MF handoff with embedded resolved QIDI settings;
- imported vendor 3MF packages are preserved losslessly while owned build transforms are updated;
- object/volume settings, modifier/support volume types, painted facet metadata, extruder assignment and plate membership serialization;
- Orca virtual-bed offsets for multi-plate projects;
- generated Prepare projects now have editable multi-plate/object state plus explicit child volumes (`normal_part`, `modifier`, `support_enforcer`, `support_blocker`), volume-scoped settings and normal-part support/seam/fuzzy-skin facet annotations routed into the production 3MF;
- `Slice plate` routes through Orca instead of a Dart slicer;
- extraction of every sliced 3MF `Metadata/plate_N.gcode` entry;
- sliced `Metadata/slice_info.config` parsing with source-shaped G-code statistics fallback for fields Orca CLI leaves empty/zero;
- selected-plate estimates, warnings, support/material data in Preview and Device without fabricating unavailable mass;
- Linux Orca `--pipe` JSON progress streaming and managed-process cancellation;
- live progress/cancel control in the Flutter workspace;
- automatic handoff of generated G-code to Dart Preview;
- latest sliced G-code can be uploaded from Device through Moonraker and started;
- real pinned Orca binary is exercised in CI with SHA-256 verification and a QIDI profile/model fixture;
- Linux x64 release CI builds the real Flutter desktop bundle, embeds the pinned Orca AppImage plus provenance manifest, verifies runtime discovery and re-hashes the bundled engine before artifact upload;
- release packaging embeds AGPL/legal notices, exact source manifest/checksums, generates application + pinned Orca corresponding-source archives and attaches all three release files together;
- complete removal of the old `lib/core/slicer` tree, Dart Clipper compatibility layer, and custom Dart G-code generator;
- removal of the `clipper2` dependency.

## Status

| Area | Status | Next work |
|---|---|---|
| Orca engine process boundary | `integration_verified` | Linux bundled runtime verified; Windows/macOS packaging can follow after v0.1 |
| Prepare/project -> Orca 3MF handoff | `integration_verified` | generated multi-plate/object/volume/facet editor feeds production state; extend real multi-filament and broader per-volume editing |
| sliced G-code + estimates/warnings/material -> Dart Preview | `integration_verified` including multi-plate metadata fallback | thumbnails / additional vendor payload metadata remain |
| QIDI profile materialization | `integration_verified` for X-Plus 4 fixture | widen representative QIDI preset matrix |
| latest slice -> Moonraker upload/start | `implemented_unverified` | printer-backed integration fixture |
| multi-plate / modifiers / paint / per-object settings | `port_started` with generated facet paint verified | viewport paint brush, real multi-filament/MMU color and wider per-volume overrides remain |
| slicing progress / cancellation | `integration_verified` on Linux / process cancellation unit-tested | add native progress transport validation for macOS/Windows packaging |
| engine packaging / updater / exact version verification | `integration_verified` for Linux-first portable bundle | Windows/macOS packaging/updater remain post-v0.1 |
| AGPL notices / corresponding source delivery | `integration_verified` engineering path on Linux | final public-release legal review remains |
| Flutter editor/project/Preview/Device/calibration | `port_started` | continue application integration |

## Immediate priority

1. Continue the verified Prepare model with real multi-filament selection/materialization/assignment; couple MMU `paint_color` to those real slots, then widen per-object/per-volume overrides.
2. For v0.1 first launch, Linux engine packaging and automated AGPL/source delivery are closed engineering gates. Real QIDI Moonraker validation still needs hardware; while unavailable, prioritize the packaged offline end-to-end smoke.
3. Improve facet-paint UX with viewport hit-testing/brushes while preserving the verified source-shaped facet state.
4. Consume remaining sliced-package thumbnails/additional vendor payload metadata and continue broader Device/calibration/UI work.

## v0.1 first-launch gates

A first-launch build is intentionally narrower than full QIDI/Orca editor parity. The minimum release target is a single-material installable desktop build that opens a model, edits basic project state, slices through the pinned Orca engine, shows Preview, and uploads/starts on one representative QIDI printer.

Closed engineering gates:

- Linux-first bundled/discovered pinned Orca executable with packaged version/hash verification;
- AGPL notices + exact corresponding-source generation/delivery automation — **verified** by release smoke #14.

Open hard gates:

- real-printer Moonraker upload/start validation;
- packaged offline end-to-end smoke from app launch through open/import, slice and Preview.

Final legal review remains a release-owner responsibility.

True multi-filament/MMU authoring, viewport paint brushes, imported-vendor structural editing, thumbnails and all-platform packaging remain important parity work but are not required for that deliberately narrow v0.1 unless the release target is widened.

