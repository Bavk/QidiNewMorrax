# Migration status — OrcaSlicer engine architecture

## Architecture cutover

The previous pure-Dart slicer/Clipper migration has been retired from production. QidiNewMorrax now uses a pinned OrcaSlicer engine for slicing/G-code and keeps application/editor/device behavior in Flutter/Dart.

Pinned engine:

- OrcaSlicer v2.4.2
- commit `8500fcdccaa10b5099ac20d252af3a7c560046f1`
- Ubuntu 24.04 AppImage SHA-256 `d12fb8c8eac1aecd2dfb6377acd48f994f8fa439ed5292fa532dd82880f029fd`
- license: GNU AGPL-3.0

## Validated checkpoint — 2026-09-19

- functional code `cbc806db7ecf00c87b6730c4167fa3d3f622223a`;
- Flutter CI `35401167437` (#752), job `105781146290`;
- analyzer: **No issues found**;
- tests: **134/134 passed**;
- Orca smoke `35401167530` (#180), job `105781147329`, conclusion **success**;
- real QIDI X-Plus 4 two-plate slice remains green: both plate G-code entries are printable, progress reaches **100%**, and each plate validates **1167 s** prediction and **1.335 m** filament.

## Implemented in this cutover

- Orca CLI bridge in `lib/core/orca/orca_slicer_engine.dart`;
- QIDI preset materialization for machine/process/filament JSON;
- Orca/Bambu-compatible split-model project 3MF handoff with embedded resolved QIDI settings;
- imported vendor 3MF packages are preserved losslessly while owned build transforms are updated;
- object/volume settings, modifier/support volume types, painted facet metadata, extruder assignment and plate membership serialization;
- Orca virtual-bed offsets for multi-plate projects;
- generated Prepare projects now have editable multi-plate/object state with add/rename/lock/remove plate actions, object reassignment/removal/transforms and per-object overrides routed into the production 3MF;
- `Slice plate` routes through Orca instead of a Dart slicer;
- extraction of every sliced 3MF `Metadata/plate_N.gcode` entry;
- sliced `Metadata/slice_info.config` parsing with source-shaped G-code statistics fallback for fields Orca CLI leaves empty/zero;
- selected-plate estimates, warnings, support/material data in Preview and Device without fabricating unavailable mass;
- Linux Orca `--pipe` JSON progress streaming and managed-process cancellation;
- live progress/cancel control in the Flutter workspace;
- automatic handoff of generated G-code to Dart Preview;
- latest sliced G-code can be uploaded from Device through Moonraker and started;
- real pinned Orca binary is exercised in CI with SHA-256 verification and a QIDI profile/model fixture;
- complete removal of the old `lib/core/slicer` tree, Dart Clipper compatibility layer, and custom Dart G-code generator;
- removal of the `clipper2` dependency.

## Status

| Area | Status | Next work |
|---|---|---|
| Orca engine process boundary | `integration_verified` | package same pinned engine on all desktop targets |
| Prepare/project -> Orca 3MF handoff | `integration_verified` | generated multi-plate/object editor now feeds production state; extend modifier/paint/multi-filament/per-volume editing |
| sliced G-code + estimates/warnings/material -> Dart Preview | `integration_verified` including multi-plate metadata fallback | thumbnails / additional vendor payload metadata remain |
| QIDI profile materialization | `integration_verified` for X-Plus 4 fixture | widen representative QIDI preset matrix |
| latest slice -> Moonraker upload/start | `implemented_unverified` | printer-backed integration fixture |
| multi-plate / modifiers / paint / per-object settings | `port_started` with generated multi-plate/object editing verified | modifiers/support volumes, facet paint, real multi-filament and wider per-volume overrides remain |
| slicing progress / cancellation | `integration_verified` on Linux / process cancellation unit-tested | add native progress transport validation for macOS/Windows packaging |
| engine packaging / updater / exact version verification | `pending` | Windows/macOS/Linux packaging |
| AGPL notices / corresponding source delivery | `pending` release gate | package license/source information |
| Flutter editor/project/Preview/Device/calibration | `port_started` | continue application integration |

## Immediate priority

1. Continue the verified generated Prepare editor with modifier/support-enforcer/support-blocker volume creation, facet paint, real multi-filament selection/assignment and wider per-object/per-volume settings; keep imported vendor 3MF structural edits lossless.
2. Consume remaining sliced-package thumbnails and additional vendor printer-payload metadata where useful.
3. Verify Moonraker upload/start against a real QIDI printer.
4. Package the pinned engine for Windows/macOS/Linux with exact artifact/version checks, native progress behavior and AGPL compliance.
5. Continue Flutter Device/calibration/UI work around the stable engine boundary.
