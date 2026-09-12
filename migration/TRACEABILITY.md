# Traceability ledger — strict 1:1 Flutter/Dart rewrite

Acceptance authority: [`PARITY_CONTRACT.md`](PARITY_CONTRACT.md). This ledger records only implemented Dart scope and evidence attached to that exact scope. A scoped `parity_verified` entry never completes its containing subsystem.

## Current validation checkpoint

- code: `2a33afd97b4f987a7edf4b482eebf8d34da7f9c0`;
- workflow: `.github/workflows/flutter-parity.yml` run `34697866558` (#276);
- Flutter `3.47.2`, Dart `3.13.2`;
- analyzer: **No issues found**;
- tests: **387/387 passed**;
- conclusion: **success**.

Milestone chain for the current classic source path:

- #260 / `ae218afe...`: represented per-island shell + Alltop + gap-fill + final fill boundary, 351/351;
- #264 / `1b2f5f4a...`: source `BridgeDetector` + translated upstream bridge fixtures, 359/359;
- #268 / `d9ad4a55...`: `process_no_bridge()` gates and active branches, 365/365;
- #273 / `0a9fa815...`: surface preprocessing/order + per-island fill source-order composition, 377/377;
- #276 / `2a33afd...`: ordered-island classic extrusion traversal + QIDI outwall/loop-node metadata, 387/387.

Earlier Arachne/fuzzy checkpoints remain fully re-executed by this suite.

## Core geometry / Boost / Clipper

| Source scope | Dart replacement | Evidence | Status | Remaining |
|---|---|---|---|---|
| libslic3r integer coordinate domain / Point / Line / represented Polygon APIs | `Slic3rUnits`, `SourcePoint2`, `SourceLine2`, `SourcePolygon2` | source-formula and translated geometry fixtures in #276 | `parity_verified` | Broader Polygon/ExPolygon APIs remain open. |
| Polyline / ArcFitter / Circle represented subset | `SourcePolyline2`, fitting/circle/arc helpers | regression/oracle fixtures in #276 | `parity_verified` | Later consumers may expose more source branches. |
| ThickPolyline / MedialAxis represented subset | `ThickPolyline2`, source MedialAxis ports | direct + end-to-end thin-wall/gap fixtures | `parity_verified` | Other consumers remain open. |
| Boost.Polygon 1.83 robust predicates/Fortune/Voronoi represented subset | direct Dart Boost/Voronoi port | C++ oracle and regression fixtures | `parity_verified` | Broader source input matrix remains open. |
| Clipper/ClipperUtils represented boolean/offset/open-subject subset | Dart Clipper2 adapters + source compatibility shims | translated and source-coordinate fixtures | `parity_verified` | Full QIDI/Clipper regression space remains `port_started`. |
| `BridgeDetector::detect_angle()` / `coverage()` represented source path | `SourceBridgeDetector2` | translated pinned `t/bridges.t` O/rotated-O/two-sided/C/L fixtures + airborne negative case | `parity_verified` (scoped) | Arbitrary/pathological bridge geometry remains open. |
| `Point::is_in_lines(const Points&)` used by QIDI loop nodes | `SourceLoopNodeGeometry2.pointIsInLines` | endpoint/axis-aligned and strict diagonal `SCALED_EPSILON` fixtures in #276 | `parity_verified` (scoped) | Other Point consumers not implied. |
| LineSegmentation Polyline/Polygon/Arachne subset | `SourceLineSegmentation2` with direct source ZAttributes | stripe/gap/full-cover/point-lerp/width-lerp/Arachne fixtures in #276 | `parity_verified` (scoped) | Broader overlap/hole/degenerate topology remains open. |

## Slicer semantic model

| Source scope | Dart replacement | Evidence | Status | Remaining |
|---|---|---|---|---|
| Flow | `Flow` | translated/source-formula tests | `parity_verified` | Full config integration open. |
| Extruder/QIDI config represented subset | Dart state/resolver | state/math tests | `parity_verified` | Full native print-state integration open. |
| Surface represented subset + copy/centroid preprocessing semantics | `Surface2`, `SourceClassicSurfacePrepare2` | classification/copy/assignment, lrint centroid, split-disable and high-level copy-reset fixtures | `parity_verified` (scoped) | Later consumers and broader source lifecycle remain open. |
| ExtrusionEntity represented subset | Dart entity model incl. mutable `loopNodeRange` | role/path/multipath/loop/collection plus ordered-island metadata fixtures | `parity_verified` (scoped) | Remaining operations/consumers open. |
| QIDI `NodeContour` / `LoopNode` classic producer subset | `SourceNodeContour2`, `SourceLoopNode2`, `SourceLoopNodeBounds2` | bbox/range/matching/global-ID fixtures in #276 | `parity_verified` (scoped) | Downstream inter-layer consumer remains open. |
| variable-width + covered-width represented subset | `SourceVariableWidth2`, covered geometry helpers | translated/end-to-end fixtures | `parity_verified` | Later consumers open. |
| Arachne fuzzy data subset | source Arachne junction/line types | metadata + fuzzy/segmentation consumers | `parity_verified` (scoped) | Full Arachne wall-toolpath model remains open. |

## Classic perimeter / fill / fuzzy

| Source behavior | Dart replacement | Evidence | Status | Remaining |
|---|---|---|---|---|
| `process_no_bridge(all_surfaces, ...)` + counterbore enum/gates | `SourceClassicNoBridge2` | None/null/empty gates, `chbBridges`, `chbFilled`, forced angle and source-copy fixtures | `parity_verified` (scoped) | More pathological counterbore topologies remain open. |
| source `BridgeDetector` dependency used by `process_no_bridge` | `SourceBridgeDetector2` | translated upstream bridge-angle/coverage fixtures | `parity_verified` (scoped) | Broader geometry matrix open. |
| conditional `surface_simplify_resolution` + `chain_expolygons` | `SourceClassicSurfacePrepare2` | arc/fuzzy resolution, EPSILON clamp, bbox-center order fixtures | `parity_verified` (scoped) | Broader simplify topology open. |
| per-surface `extra_perimeters` / alternate wall accounting | `SourceClassicSurfacePrepare2` → `SourceClassicPerimeterIslandProcess2` | wall-count and actual shell-count composition fixtures | `parity_verified` (scoped) | Higher-level config binding open. |
| QIDI compensation centroid / split-disable semantics | `SourceClassicPreparedSurface2` | lrint centroid, eps=1000, split-disable tests; high-level copy-reset test | `parity_verified` (scoped) | Pinned `Surface` copy resets these fields before actual high-level consumer; preserve this quirk. |
| ordered source surface preprocessing → per-island fill | `SourceClassicPerimeterIslandProcess2` | chain order, counterbore-fill order, resolution separation, extra-perimeter, topmost and copy-quirk fixtures | `parity_verified` (scoped) | Broader pathological topology open. |
| onion-shell / QIDI smaller external / source `last = offsets` | `ClassicPerimeterShellGenerator` | source-formula fixtures | `parity_verified` (scoped) | Higher-level config breadth open. |
| pre-shell top-one-wall / Alltop / final fill path | existing classic shell/fill helpers | null-vs-empty, Alltop, gap-fill, final-boundary and 7999 overlap fixtures | `parity_verified` (scoped) | Later fill generation open. |
| nesting / recursive fuzzy-overhang traversal / wall sequence | `SourceClassicPerimeterPipeline2`, `SourceClassicFuzzyPerimeterPipeline2` | ordering/winding/reversal/overhang/fuzzy fixtures | `parity_verified` (scoped) | Broader source branches open. |
| ordered islands → per-island traversal → nested global loops | `SourceClassicPerimeterOrderedPipeline2` | 3-island chain order, per-island `OuterInner`, non-null-empty lower-slice and shared RNG fixtures in #276 | `parity_verified` (scoped) | Later consumers after classic loop production remain open. |
| QIDI classic `outwall_paths` / `loop_nodes` / `loop_node_range` producer | `SourceClassicPerimeterOrderedPipeline2` + `source_loop_node.dart` | single/multiple outwall matching, contour+hole order, preexisting global IDs and bbox fixtures in #276 | `parity_verified` (scoped) | Inter-layer relationship/speed consumer remains open. |
| lower support series / overhang grading | represented overhang helpers/pipelines | source mapping/smoothing/role/flow fixtures and ordered-island use in #276 | `parity_verified` (scoped) | Other process stages remain open. |
| fuzzy policy + Classic/structured geometry + painted regions | source-shaped fuzzy modules | MT19937/libnoise/LineSegmentation/pipeline fixtures and shared ordered-island RNG in #276 | `parity_verified` (scoped) | Full wall-engine breadth open. |
| Arachne `fuzzy_extrusion_line()` + region-aware fuzzy | source Arachne fuzzy helpers | seeded C++ goldens + region fixtures | `parity_verified` (scoped) | Full Arachne wall generator integration open. |
| `Arachne::WallToolPaths` / `process_arachne()` wall generation | only downstream `ExtrusionLine` consumers exist | pinned source audited; no generator evidence yet | `port_started` | Immediate next wall-generation dependency. |

## G-code / formats / device / UI

The represented source G-code formatter/extrusion-path emitter subset remains scoped `parity_verified`; the full native G-code state machine is `port_started`. STL/OBJ/AMF/3MF foundations are `port_started`; STEP, complete source-enabled formats and full project/preset round trips remain open. Device LAN/Moonraker/QIDI Box, profiles, localization and Flutter UI areas have foundations only and remain `port_started`; cloud/P2P/account/HMS/firmware, full calibration, desktop integration and full source UI/state/visual parity remain open.

## Runtime assets

An earlier local audit recorded 3,657/3,657 copied runtime entries matching source SHA-256, but the complete real runtime asset set is not yet published and reverified from GitHub/release inputs. `.gitkeep` files are not parity evidence. Remote/release asset gate remains `pending`.

## Mandatory update rule

Every meaningful migration batch must keep [`MIGRATION_STATUS.md`](MIGRATION_STATUS.md), [`VALIDATION.md`](VALIDATION.md), [`../docs/HANDOFF.md`](../docs/HANDOFF.md), and this ledger consistent with the actual code and executed CI evidence.
