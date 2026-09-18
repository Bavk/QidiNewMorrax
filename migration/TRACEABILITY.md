# Traceability ledger — OrcaSlicer engine cutover

## Current validated checkpoint

Functional code `a69646d98fbc07de7004cda6b62ad78757a8d61a` is green in Flutter CI run `35400170625` (#746), job `105778026686`: analyzer clean, **131/131 tests passed**.

The same functional HEAD is green in OrcaSlicer smoke run `35400170623` (#173), job `105778021824`: pinned AppImage digest verified, the two-plate QIDI fixture sliced successfully, progress reached 100%, and real sliced metadata/G-code statistics were validated. Each plate reported **1167 s** prediction and **1.335 m** filament.

## Production slicing path

| Behavior | Production implementation | Evidence/status |
|---|---|---|
| polygon/offset/boolean geometry | pinned OrcaSlicer v2.4.2 | real engine smoke verified |
| Classic/Arachne walls | pinned OrcaSlicer v2.4.2 | real engine smoke verified through complete slice |
| infill/support/seam/bridge/travel | pinned OrcaSlicer v2.4.2 | engine-owned; complete fixture slice verified |
| G-code generation | pinned OrcaSlicer v2.4.2 | sliced 3MF + 385515-byte plate G-code verified |
| QIDI profile selection/inheritance | Dart `ProfileRepository` + `OrcaProfileMaterializer` | Dart tests + real X-Plus 4 Orca fixture |
| Prepare/project handoff | Dart `ThreeMfProjectWriter` + lossless `ThreeMfWriter` | split-model/unit tests + real two-plate Orca `--slice 0` smoke |
| project settings | Dart `OrcaProjectSettingsBuilder` | resolved QIDI config embedded before BBS/Orca import |
| plate coordinate mapping | Dart `OrcaBedCoordinateMapper` + writer virtual-bed offsets | unit tests + real two-plate Orca smoke |
| engine invocation | Dart `OrcaSlicerEngine` managed `Process.start` boundary | CLI contract tests + real pinned executable CI |
| slicing progress | Linux Orca `--pipe` FIFO -> `OrcaSlicerProgress` | real pinned AppImage progress JSON smoke |
| cancellation | active Orca process termination + `OrcaSlicerCancelledException` | process lifecycle unit test; packaged-platform process tree validation still pending |
| sliced result extraction | Dart `OrcaSlicerEngine.extractPlateGcodes` | ZIP tests + two plate G-code entries verified |
| sliced result metadata | Dart `OrcaSliceMetadata` | `slice_info.config` tests + real two-plate Orca smoke; missing/zero fields filled only from Orca G-code statistics |
| Preview | Dart `GCodeParser` + selected `OrcaPlateMetadata` | generated Orca G-code plus estimates/warnings/support/material usage routed automatically |
| printer upload/start | Dart `DeviceController` + `MoonrakerClient` | implementation complete; printer-backed validation pending |

## Engine provenance

- upstream: `OrcaSlicer/OrcaSlicer`
- release: `v2.4.2`
- source commit: `8500fcdccaa10b5099ac20d252af3a7c560046f1`
- Ubuntu 24.04 AppImage SHA-256: `d12fb8c8eac1aecd2dfb6377acd48f994f8fa439ed5292fa532dd82880f029fd`
- license: GNU AGPL-3.0

## Retired implementation

The former `lib/core/slicer` source-shaped Dart implementation, custom Clipper subsets, Clipper2 compatibility layer and custom G-code generation path were deleted during the Orca cutover. Earlier #493–#647 Clipper/Arachne oracle work remains useful historical research but is no longer a production runtime dependency or acceptance gate.

## First unfinished integration boundary

The STL boundary is retired, Linux Orca `--pipe` progress/cancellation is integrated, and per-plate estimates/warnings/material usage are consumed from the sliced package. The first unfinished application boundary is richer Prepare editing of the project model that already preserves/encodes multi-plate state, modifiers, painted facets, object/volume settings, filament assignment and vendor metadata. Sliced thumbnails and additional vendor payload metadata remain secondary Preview/Device work.
