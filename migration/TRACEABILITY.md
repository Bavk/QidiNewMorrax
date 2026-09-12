# Traceability ledger — strict 1:1 Flutter/Dart rewrite

Acceptance authority: [`PARITY_CONTRACT.md`](PARITY_CONTRACT.md). This ledger records only implemented Dart scope and evidence attached to that exact scope. A scoped `parity_verified` entry never completes its containing subsystem.

## Current validation checkpoint

- code: `ae218afee234afa92f7ef2967d61db8485a82d5a`;
- workflow: `.github/workflows/flutter-parity.yml` run `34694164752` (#260);
- Flutter `3.47.2`, Dart `3.13.2`;
- analyzer: **No issues found**;
- tests: **351/351 passed**;
- conclusion: **success**.

Milestone chain for the current classic fill slice:

- #252 / `9ba4f919...`: final represented fill boundary, 333/333;
- #254 / `5a4d8b65...`: standalone `TopOneWallType::Alltop` producer, 340/340;
- #258 / `7e51f78e...`: top-one-wall source-order shell integration, 346/346;
- #260 / `ae218afe...`: shell + Alltop + gap-fill mutation + final fill-boundary composition, 351/351.

Earlier Arachne/fuzzy checkpoint #249 remains fully re-executed by this suite.

## Core geometry / Boost / Clipper

| Source scope | Dart replacement | Evidence | Status | Remaining |
|---|---|---|---|---|
| libslic3r integer coordinate domain / Point / Line / represented Polygon APIs | `Slic3rUnits`, `SourcePoint2`, `SourceLine2`, `SourcePolygon2` | source-formula and translated geometry fixtures in #260 | `parity_verified` | Broader Polygon/ExPolygon APIs remain open. |
| Polyline / ArcFitter / Circle represented subset | `SourcePolyline2`, fitting/circle/arc helpers | regression/oracle fixtures in #260 | `parity_verified` | Later consumers may expose more source branches. |
| ThickPolyline / MedialAxis represented subset | `ThickPolyline2`, source MedialAxis ports | direct + end-to-end thin-wall/gap fixtures | `parity_verified` | Other consumers remain open. |
| Boost.Polygon 1.83 robust predicates/Fortune/Voronoi represented subset | direct Dart Boost/Voronoi port | C++ oracle and regression fixtures | `parity_verified` | Broader source input matrix remains open. |
| Clipper/ClipperUtils represented boolean/offset/open-subject subset | Dart Clipper2 adapters + source compatibility shims | translated and source-coordinate fixtures | `parity_verified` | Full QIDI/Clipper regression space remains `port_started`. |
| `clip_clipper_polygons_with_subject_bbox()` represented helper | literal source side-mask pruning in `SourceClassicTopFillAllTop2` | far-upper-polygon pruning fixture in #260 | `parity_verified` (scoped) | Other callers/input topologies open. |
| LineSegmentation Polyline/Polygon/Arachne subset | `SourceLineSegmentation2` with direct source ZAttributes | stripe/gap/full-cover/point-lerp/width-lerp/Arachne fixtures in #260 | `parity_verified` (scoped) | Broader overlap/hole/degenerate topology remains open. |

## Slicer semantic model

| Source scope | Dart replacement | Evidence | Status | Remaining |
|---|---|---|---|---|
| Flow | `Flow` | translated/source-formula tests | `parity_verified` | Full config integration open. |
| Extruder/QIDI config represented subset | Dart state/resolver | state/math tests | `parity_verified` | Full native print-state integration open. |
| Surface represented subset | `Surface2` | classification/copy/assignment tests | `parity_verified` | `process_no_bridge`, ordering and circle-compensation consumers still open. |
| ExtrusionEntity represented subset | Dart entity model | role/path/multipath/loop/collection tests | `parity_verified` | Remaining operations/consumers open. |
| variable-width + covered-width represented subset | `SourceVariableWidth2`, covered geometry helpers | translated/end-to-end fixtures | `parity_verified` | Later consumers open. |
| Arachne fuzzy data subset | source Arachne junction/line types | metadata + fuzzy/segmentation consumers | `parity_verified` (scoped) | Full Arachne wall-toolpath model remains open. |

## Classic perimeter / fill / fuzzy

| Source behavior | Dart replacement | Evidence | Status | Remaining |
|---|---|---|---|---|
| onion-shell / QIDI smaller external / source `last = offsets` | `ClassicPerimeterShellGenerator` | source-formula fixtures | `parity_verified` (scoped) | Surface preprocessing before shell remains open. |
| pre-shell top-one-wall gate | `SourceClassicTopOneWallContext2` + shell integration | null-vs-empty upper slices, first-layer fixtures in #258/#260 | `parity_verified` (scoped) | Higher-level config binding open. |
| source final-wall stop / optional gap-discovery iteration | `sparseInfillDensityPercent` stop in shell | zero-density fixture in #258/#260 | `parity_verified` (scoped) | Full config binding open. |
| `TopOneWallType::Alltop` in-loop producer | `SourceClassicTopFillAllTop2` invoked after first `last=offsets` | scalar C++ oracle, bbox prune, all-top, bridge/gap-fill, shell-order fixtures | `parity_verified` (scoped) | Broader pathological topologies open. |
| thin wall / gap fill represented path | Clipper → MedialAxis → variable width | end-to-end fixtures | `parity_verified` | More pathological inputs may expand coverage. |
| final `process_classic()` fill boundary | `SourceClassicFillBoundary2` | zero/one/multi-wall, absolute/percent overlap, top-fill, no-overlap and coord truncation fixtures | `parity_verified` (scoped) | Later fill generation open. |
| represented shell→fill source-order composition | `SourceClassicPerimeterFillProcess2` | two-wall, topmost, Alltop, 7999 percent quirk, zero-wall fixtures in #260 | `parity_verified` (scoped) | Starts from already prepared island geometry; source preprocessing remains open. |
| nesting / shortest-path chain / recursive traversal / wall sequence | source-shaped traversal helpers | ordering/winding/reversal fixtures | `parity_verified` | Integration with new surface preprocessing still open. |
| lower support series / overhang grading | represented overhang helpers/pipelines | source mapping/smoothing/role/flow fixtures | `parity_verified` | Other process stages remain open. |
| `process_no_bridge(all_surfaces, ...)` | not ported | source function identified | `pending` | Immediate next classic priority. |
| conditional surface simplification + `chain_expolygons` order | not integrated | source formulas/order identified | `port_started` | Port exact preprocessing. |
| per-surface extra perimeters + circle compensation metadata | `Surface2` fields exist, process consumer missing | data-model tests only | `port_started` | Feed into per-island process; centroid epsilon=1000 and split-disable logic. |
| fuzzy policy + Classic/structured geometry + painted regions | source-shaped fuzzy modules | MT19937/libnoise/LineSegmentation/pipeline fixtures | `parity_verified` (scoped) | Full wall-engine integration open. |
| Arachne `fuzzy_extrusion_line()` + region-aware fuzzy | source Arachne fuzzy helpers | seeded C++ goldens + region fixtures | `parity_verified` (scoped) | Full Arachne wall generator integration open. |

## G-code / formats / device / UI

The represented source G-code formatter/extrusion-path emitter subset remains scoped `parity_verified`; the full native G-code state machine is `port_started`. STL/OBJ/AMF/3MF foundations are `port_started`; STEP, complete source-enabled formats and full project/preset round trips remain open. Device LAN/Moonraker/QIDI Box, profiles, localization and Flutter UI areas have foundations only and remain `port_started`; cloud/P2P/account/HMS/firmware, full calibration, desktop integration and full source UI/state/visual parity remain open.

## Runtime assets

An earlier local audit recorded 3,657/3,657 copied runtime entries matching source SHA-256, but the complete real runtime asset set is not yet published and reverified from GitHub/release inputs. `.gitkeep` files are not parity evidence. Remote/release asset gate remains `pending`.

## Mandatory update rule

Every meaningful migration batch must keep [`MIGRATION_STATUS.md`](MIGRATION_STATUS.md), [`VALIDATION.md`](VALIDATION.md), [`../docs/HANDOFF.md`](../docs/HANDOFF.md), and this ledger consistent with the actual code and executed CI evidence.
