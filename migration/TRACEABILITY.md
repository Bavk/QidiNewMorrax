# Traceability ledger — OrcaSlicer engine cutover

## Current validated checkpoint

Functional code `70e6919eaad04199738c09b682f8bdad5ec0d67f` is green in Flutter CI run `35392468990` (#670), job `105753727204`: analyzer clean, **114/114 tests passed**.

The same functional HEAD is green in OrcaSlicer smoke run `35392469054` (#27), job `105753727522`: pinned AppImage digest verified, QIDI X-Plus 4 fixture sliced successfully, `Metadata/plate_1.gcode` extracted and printable moves verified.

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
| Preview | Dart `GCodeParser` + Flutter Preview | generated Orca G-code routed automatically |
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

The STL boundary is retired and Linux Orca `--pipe` progress/cancellation is integrated. The next engine boundary is richer sliced-3MF metadata consumption for estimates, warnings, thumbnails and printer payloads. The project serializer already preserves/encodes multi-plate, modifiers, painted facets, object/volume settings, filament assignment and vendor metadata; richer Prepare UI still needs to expose creation/editing of that state.
