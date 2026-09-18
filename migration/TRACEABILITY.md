# Traceability ledger — OrcaSlicer engine cutover

## Current Dart checkpoint

`099b08ffe1e8e4c3aef61b03a27613d8422b8ab4` is green in Flutter CI run `35389777844` (#655), job `105745161355`: analyzer clean, **114/114 tests passed**.

## Production slicing path

| Behavior | Production implementation | Evidence/status |
|---|---|---|
| polygon/offset/boolean geometry | pinned OrcaSlicer engine | external engine; runtime integration pending E2E verification |
| Classic/Arachne walls | pinned OrcaSlicer engine | external engine; runtime integration pending E2E verification |
| infill/support/seam/bridge/travel | pinned OrcaSlicer engine | external engine; runtime integration pending E2E verification |
| G-code generation | pinned OrcaSlicer engine | external engine; runtime integration pending E2E verification |
| QIDI profile selection/inheritance | Dart `ProfileRepository` + `OrcaProfileMaterializer` | bridge tests + E2E preset validation pending |
| current Prepare geometry handoff | Dart `MeshStlWriter` | unit test; full project semantics pending |
| engine invocation | Dart `OrcaSlicerEngine` | CLI argument contract test; executable CI pending |
| sliced result extraction | Dart `OrcaSlicerEngine.extractPlateGcode` | ZIP contract tests |
| Preview | Dart `GCodeParser` + Flutter Preview | existing parser/UI coverage; Orca E2E pending |
| printer delivery | Dart Device/Moonraker foundations | still incomplete |

## Retired implementation

The former `lib/core/slicer` source-shaped Dart implementation, custom Clipper subsets, Clipper2 compatibility layer and custom G-code generation path were deleted during the Orca cutover. Earlier #493–#647 Clipper/Arachne oracle work remains useful historical research but is no longer a production runtime dependency or acceptance gate.

## First unfinished integration boundary

Run the pinned OrcaSlicer v2.4.2 binary in CI against a representative QIDI profile/model fixture, verify the sliced 3MF and extracted G-code, then move the handoff from flattened STL to full project/3MF semantics.
