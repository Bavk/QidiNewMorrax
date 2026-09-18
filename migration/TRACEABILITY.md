# Traceability ledger — OrcaSlicer engine cutover

## Current validated checkpoint

Functional code `cbc806db7ecf00c87b6730c4167fa3d3f622223a` is green in Flutter CI run `35401167437` (#752), job `105781146290`: analyzer clean, **134/134 tests passed**.

The same functional HEAD is green in OrcaSlicer smoke run `35401167530` (#180), job `105781147329`: pinned AppImage digest verified, the two-plate QIDI fixture sliced successfully, progress reached 100%, both plate G-code entries remained printable, and each plate reported **1167 s** prediction and **1.335 m** filament.

## Production slicing path

| Behavior | Production implementation | Evidence/status |
|---|---|---|
| polygon/offset/boolean geometry | pinned OrcaSlicer v2.4.2 | real engine smoke verified |
| Classic/Arachne walls | pinned OrcaSlicer v2.4.2 | real engine smoke verified through complete slice |
| infill/support/seam/bridge/travel | pinned OrcaSlicer v2.4.2 | engine-owned; complete fixture slice verified |
| G-code generation | pinned OrcaSlicer v2.4.2 | sliced 3MF + 385515-byte plate G-code verified |
| QIDI profile selection/inheritance | Dart `ProfileRepository` + `OrcaProfileMaterializer` | Dart tests + real X-Plus 4 Orca fixture |
| Prepare/project handoff | Dart `WorkspaceEditableProject` + `ThreeMfProjectWriter` + lossless `ThreeMfWriter` | generated multi-plate/object editor tests + split-model tests + real two-plate Orca `--slice 0` smoke |
| project settings | Dart `OrcaProjectSettingsBuilder` | resolved QIDI config embedded before BBS/Orca import |
| plate coordinate mapping | Dart `OrcaBedCoordinateMapper` + writer virtual-bed offsets | unit tests + real two-plate Orca smoke |
| engine invocation | Dart `OrcaSlicerEngine` managed `Process.start` boundary | CLI contract tests + real pinned executable CI |
| slicing progress | Linux Orca `--pipe` FIFO -> `OrcaSlicerProgress` | real pinned AppImage progress JSON smoke |
| cancellation | active Orca process termination + `OrcaSlicerCancelledException` | process lifecycle unit test; packaged-platform process tree validation still pending |
| sliced result extraction | Dart `OrcaSlicerEngine.extractPlateGcodes` | ZIP tests + two plate G-code entries verified |
| sliced result metadata | Dart `OrcaSliceMetadata` | `slice_info.config` tests + real two-plate Orca smoke; missing/zero fields filled only from Orca G-code statistics |
| Preview | Dart `GCodeParser` + selected `OrcaPlateMetadata` | generated Orca G-code plus estimates/warnings/support/material usage routed automatically |
| printer upload/start | Dart `DeviceController` + `MoonrakerClient` | implementation complete; printer-backed validation pending |
| generated Prepare multi-plate/object editing | Dart `WorkspaceEditableProject` + `PreparePage` + `WorkspaceController` | add/rename/lock/remove plates; add/remove/reassign/transform objects; object overrides serialized into production 3MF; Flutter #752 + Orca smoke #180 |

## Engine provenance

- upstream: `OrcaSlicer/OrcaSlicer`
- release: `v2.4.2`
- source commit: `8500fcdccaa10b5099ac20d252af3a7c560046f1`
- Ubuntu 24.04 AppImage SHA-256: `d12fb8c8eac1aecd2dfb6377acd48f994f8fa439ed5292fa532dd82880f029fd`
- license: GNU AGPL-3.0

## Retired implementation

The former `lib/core/slicer` source-shaped Dart implementation, custom Clipper subsets, Clipper2 compatibility layer and custom G-code generation path were deleted during the Orca cutover. Earlier #493–#647 Clipper/Arachne oracle work remains useful historical research but is no longer a production runtime dependency or acceptance gate.

## First unfinished integration boundary

The STL boundary is retired, Linux Orca `--pipe` progress/cancellation is integrated, per-plate estimates/warnings/material usage are consumed, and generated multi-plate/object Prepare editing now feeds the real production 3MF. The first unfinished application boundary is deeper Prepare editing: modifier/support volume creation, facet paint, real multi-filament selection/assignment and wider per-object/per-volume overrides. Imported vendor 3MF structural editing must preserve the existing lossless package contract. Sliced thumbnails and additional vendor payload metadata remain secondary Preview/Device work.
