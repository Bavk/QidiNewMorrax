# Migration status — OrcaSlicer engine architecture

## Architecture cutover

The previous pure-Dart slicer/Clipper migration has been retired from production. QidiNewMorrax now uses a pinned OrcaSlicer engine for slicing/G-code and keeps application/editor/device behavior in Flutter/Dart.

Pinned engine:

- OrcaSlicer v2.4.2
- commit `8500fcdccaa10b5099ac20d252af3a7c560046f1`
- Ubuntu 24.04 AppImage SHA-256 `d12fb8c8eac1aecd2dfb6377acd48f994f8fa439ed5292fa532dd82880f029fd`
- license: GNU AGPL-3.0

## Validated checkpoint — 2026-09-18

- functional code `70e6919eaad04199738c09b682f8bdad5ec0d67f`;
- Flutter CI `35392468990` (#670), job `105753727204`;
- analyzer: **No issues found**;
- tests: **114/114 passed**;
- Orca smoke `35392469054` (#27), job `105753727522`, conclusion **success**;
- real QIDI X-Plus 4 cube slice produced a sliced 3MF with `Metadata/plate_1.gcode` (**385515 bytes**) and printable G0/G1 moves.

## Implemented in this cutover

- Orca CLI bridge in `lib/core/orca/orca_slicer_engine.dart`;
- QIDI preset materialization for machine/process/filament JSON;
- current transformed Prepare mesh -> temporary STL handoff;
- `Slice plate` routes through Orca instead of a Dart slicer;
- sliced 3MF `Metadata/plate_N.gcode` extraction;
- automatic handoff of generated G-code to Dart Preview;
- latest sliced G-code can be uploaded from Device through Moonraker and started;
- real pinned Orca binary is exercised in CI with SHA-256 verification and a QIDI profile/model fixture;
- complete removal of the old `lib/core/slicer` tree, Dart Clipper compatibility layer, and custom Dart G-code generator;
- removal of the `clipper2` dependency.

## Status

| Area | Status | Next work |
|---|---|---|
| Orca engine process boundary | `integration_verified` | package same pinned engine on all desktop targets |
| single active mesh + one machine/process/filament handoff | `integration_verified` | replace flattened STL with project/3MF semantics |
| sliced G-code extraction -> Dart Preview | `integration_verified` | consume richer sliced metadata |
| QIDI profile materialization | `integration_verified` for X-Plus 4 fixture | widen representative QIDI preset matrix |
| latest slice -> Moonraker upload/start | `implemented_unverified` | printer-backed integration fixture |
| multi-plate / modifiers / paint / per-object settings | `pending` | full project/3MF handoff |
| slicing progress / cancellation | `pending` | Orca `--pipe` integration |
| engine packaging / updater / exact version verification | `pending` | Windows/macOS/Linux packaging |
| AGPL notices / corresponding source delivery | `pending` release gate | package license/source information |
| Flutter editor/project/Preview/Device/calibration | `port_started` | continue application integration |

## Immediate priority

1. Replace flattened STL handoff with full 3MF/project state so plates, modifiers, paint, per-object settings, filament assignments and metadata reach Orca intact.
2. Add progress and cancellation using Orca's CLI progress pipe.
3. Consume sliced 3MF metadata for Preview estimates/warnings and printer delivery.
4. Verify Moonraker upload/start against a real QIDI printer.
5. Package the pinned engine for Windows/macOS/Linux with exact artifact/version checks and AGPL compliance.
6. Continue Flutter editor/project/Device/calibration/UI work around the stable engine boundary.
