# Traceability ledger — OrcaSlicer engine cutover

## Current validated checkpoint

Functional code `9a2701a879138f1dce113c9b9a8255d07192f8cf` is green in Flutter CI run `35462902220` (#806), job `105949847037`: analyzer clean, **142/142 tests passed**.

The same functional HEAD is green in OrcaSlicer smoke run `35462902163` (#234), job `105949846774`. Linux packaged release smoke `35462902353` (#27), job `105949847400`, builds the real Flutter bundle, generates **1547** QIDI profiles from pinned Orca source, verifies bundled engine provenance/hash and runs the packaged binary through model import -> profile resolution -> WorkspaceController -> bundled Orca -> sliced metadata/GCodeParser. The smoke result is Preview-ready with **5005** moves, **1988** extrusion moves, **537 s** prediction and **0.35 m** filament.

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
| generated Prepare volume editing | Dart `WorkspaceEditableVolume` + `PreparePage` + `ThreeMfProjectWriter` | normal/modifier/support-enforcer/support-blocker child volumes, volume overrides and object-wide transforms; Flutter #761 + real Orca subtype smoke #189 |
| generated Prepare facet paint | Dart `WorkspaceEditableProject.paintFacets` + `PreparePage` + `ThreeMfProjectWriter` | support/seam/fuzzy-skin whole-facet annotations, source codes `4`/`8`, normal-part-only enforcement; Flutter #770 + real Orca paint smoke #198 |
| Linux packaged Orca | Dart `OrcaSlicerEngine` + `packaging/orca/linux/orca-engine.json` + `linux-release-smoke.yml` | release bundle discovery, manifest pin validation, actual AppImage SHA-256 verification and portable artifact upload; packaged smoke #4 |
| packaged QIDI profiles + offline app E2E | pinned Orca `resources/profiles/Qidi` -> generated Flutter catalog + `PackagedOfflineSmoke` | 1547 profiles compiled before build; packaged binary resolves X-Plus 4 profiles and completes STL -> slice -> Preview-input; release smoke #27 |

## Engine provenance

- upstream: `OrcaSlicer/OrcaSlicer`
- release: `v2.4.2`
- source commit: `8500fcdccaa10b5099ac20d252af3a7c560046f1`
- Ubuntu 24.04 AppImage SHA-256: `d12fb8c8eac1aecd2dfb6377acd48f994f8fa439ed5292fa532dd82880f029fd`
- license: GNU AGPL-3.0

## Retired implementation

The former `lib/core/slicer` source-shaped Dart implementation, custom Clipper subsets, Clipper2 compatibility layer and custom G-code generation path were deleted during the Orca cutover. Earlier #493–#647 Clipper/Arachne oracle work remains useful historical research but is no longer a production runtime dependency or acceptance gate.

## First unfinished integration boundary

The STL boundary is retired, Linux Orca `--pipe` progress/cancellation is integrated, per-plate estimates/warnings/material usage are consumed, generated multi-plate/object/volume/facet Prepare editing feeds the real production 3MF, and the Linux-first release bundle now contains a fail-closed verified pinned Orca engine plus a pinned QIDI profile catalog. The packaged application offline path is integration-verified through Preview-ready G-code. The first unfinished parity boundary is real multi-filament selection/materialization/assignment (with MMU `paint_color` tied to those slots), followed by wider per-object/per-volume overrides and viewport paint UX. The only remaining hard v0.1 gate is real-printer Moonraker upload/start validation; imported vendor 3MF structural editing must preserve the existing lossless package contract.
