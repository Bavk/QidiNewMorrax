# Traceability ledger — strict 1:1 Flutter/Dart rewrite

Acceptance authority: [`PARITY_CONTRACT.md`](PARITY_CONTRACT.md). This ledger records only implemented Dart scope and evidence attached to that exact scope. A scoped `parity_verified` entry never completes its containing subsystem.

## Current validation checkpoint

- code: `10f642e0d3952b61eefe4c8bdda2fcd909a4eba2`;
- workflow: `.github/workflows/flutter-parity.yml` run `34714922159` (#317);
- Flutter `3.47.2`, Dart `3.13.2`;
- analyzer: **No issues found**;
- tests: **551/551 passed**;
- conclusion: **success**.

Milestone chain:

- #276 / `2a33afd...`: ordered-island classic extrusion traversal + QIDI outwall/loop-node metadata, 387/387;
- #278 / `6978000...`: first `Arachne::WallToolPaths` dependency slice, 395/395;
- #308 / `f211b19...`: `generateSegments()` foundation, 521/521;
- #311 / `34eaac7...`: source beading propagation / shared-object semantics;
- #313 / `9b61d75...`: extrusion-junction generation and literal 5-micron boundary;
- #314 / `3d8bf3c...`: junction connection / variable-width path stitching;
- #315 / `09c6249...`: local-max single-bead generation;
- #316 / `0ede85b...`: complete represented `generateSegments()` composition;
- #317 / `10f642e...`: post-construction skeletal `generateToolpaths()` composition, 551/551.

Earlier Classic, Arachne fuzzy and geometry checkpoints remain fully re-executed by this suite.

## Core geometry / Boost / Clipper

| Source scope | Dart replacement | Evidence | Status | Remaining |
|---|---|---|---|---|
| libslic3r integer coordinate domain / Point / Line / represented Polygon APIs | `Slic3rUnits`, `SourcePoint2`, `SourceLine2`, `SourcePolygon2` | source-formula and translated geometry fixtures in #317 | `parity_verified` | Broader Polygon/ExPolygon APIs remain open. |
| Polyline / ArcFitter / Circle represented subset | `SourcePolyline2`, fitting/circle/arc helpers | regression/oracle fixtures in #317 | `parity_verified` | Later consumers may expose more source branches. |
| ThickPolyline / MedialAxis represented subset | `ThickPolyline2`, source MedialAxis ports | direct + end-to-end thin-wall/gap fixtures | `parity_verified` | Other consumers remain open. |
| Boost.Polygon 1.83 robust predicates/Fortune/Voronoi represented subset | direct Dart Boost/Voronoi port | C++ oracle and regression fixtures | `parity_verified` | Arachne Voronoi→half-edge transfer remains open. |
| Clipper/ClipperUtils represented boolean/offset/open-subject subset | Dart Clipper2 adapters + source compatibility shims | translated and source-coordinate fixtures | `parity_verified` | Full QIDI/Clipper regression space remains `port_started`. |
| `BridgeDetector::detect_angle()` / `coverage()` represented source path | `SourceBridgeDetector2` | translated pinned bridge fixtures | `parity_verified` (scoped) | Arbitrary/pathological bridge geometry remains open. |
| `Point::is_in_lines(const Points&)` used by QIDI loop nodes | `SourceLoopNodeGeometry2.pointIsInLines` | endpoint/axis-aligned and strict diagonal epsilon fixtures | `parity_verified` (scoped) | Other Point consumers not implied. |
| LineSegmentation Polyline/Polygon/Arachne subset | `SourceLineSegmentation2` with direct source ZAttributes | stripe/gap/full-cover/lerp/Arachne fixtures | `parity_verified` (scoped) | Broader overlap/hole/degenerate topology remains open. |

## Slicer semantic model

| Source scope | Dart replacement | Evidence | Status | Remaining |
|---|---|---|---|---|
| Flow | `Flow` | translated/source-formula tests | `parity_verified` | Full config integration open. |
| Extruder/QIDI config represented subset | Dart state/resolver | state/math tests | `parity_verified` | Full native print-state integration open. |
| Surface represented subset + copy/centroid preprocessing semantics | `Surface2`, `SourceClassicSurfacePrepare2` | classification/copy/assignment and high-level fixtures | `parity_verified` (scoped) | Later consumers remain open. |
| ExtrusionEntity represented subset | Dart entity model incl. mutable `loopNodeRange` | entity + ordered-island metadata fixtures | `parity_verified` (scoped) | Remaining operations/consumers open. |
| QIDI `NodeContour` / `LoopNode` classic producer subset | `SourceNodeContour2`, `SourceLoopNode2`, `SourceLoopNodeBounds2` | bbox/range/matching/global-ID fixtures | `parity_verified` (scoped) | Downstream inter-layer consumer remains open. |
| variable-width + covered-width represented subset | `SourceVariableWidth2`, covered geometry helpers | translated/end-to-end fixtures | `parity_verified` | Later consumers open. |
| Arachne fuzzy data subset | source Arachne junction/line types | metadata + fuzzy/segmentation consumers | `parity_verified` (scoped) | Full wall generator integration open. |
| `Arachne::WallToolPathsParams` + constructor numeric state | `SourceArachneWallToolPathsParams2`, `SourceArachneWallToolPathsState2` | float32/config/scaled-truncation fixtures | `parity_verified` (scoped) | Full generate path remains open. |
| represented `WallToolPaths` prepare chain / pre-beading inputs | `SourceArachneWallToolPathsPreprocess2` + pre-beading helpers | cleanup, scalar, threshold and source-cast fixtures re-run in #317 | `parity_verified` (scoped) | End-to-end wall output open. |
| Arachne beading strategies / factory | `SourceArachneBeadingStrategy2` family + factory | strategy/meta/factory fixtures re-run in #317 | `parity_verified` (scoped) | Real polygon→skeletal integration open. |
| source-shaped skeletal graph mutation/init subset | graph model, mutation/collapse/pointy-end helpers | direct topology/mutation fixtures | `parity_verified` (scoped) | Voronoi→graph construction open. |
| post-construction `SkeletalTrapezoidation::generateSegments()` | source Arachne segment modules + orchestrator | seven staged suites + composed two-quad fixture, #308–#316 | `parity_verified` (scoped) | Requires real constructed graph for full claim. |
| post-construction `SkeletalTrapezoidation::generateToolpaths()` | `SourceArachneGenerateToolpaths2` | exact source-order composition + optional outer-central branch, #317 | `parity_verified` (scoped) | `constructFromPolygons()` / full WallToolPaths integration open. |

## Classic perimeter / fill / fuzzy

| Source behavior | Dart replacement | Evidence | Status | Remaining |
|---|---|---|---|---|
| `process_no_bridge(all_surfaces, ...)` + counterbore enum/gates | `SourceClassicNoBridge2` | source branch fixtures | `parity_verified` (scoped) | Pathological topologies remain open. |
| source `BridgeDetector` dependency | `SourceBridgeDetector2` | translated upstream bridge fixtures | `parity_verified` (scoped) | Broader geometry matrix open. |
| conditional surface simplification + `chain_expolygons` | `SourceClassicSurfacePrepare2` | resolution/order fixtures | `parity_verified` (scoped) | Broader simplify topology open. |
| per-surface extra/alternate wall accounting | prepare → island process | shell-count composition fixtures | `parity_verified` (scoped) | Higher-level config binding open. |
| QIDI compensation centroid / split-disable semantics | `SourceClassicPreparedSurface2` | source cast/copy fixtures | `parity_verified` (scoped) | High-level copy intentionally resets source fields. |
| ordered source surface preprocessing → per-island fill | `SourceClassicPerimeterIslandProcess2` | source-order fixtures | `parity_verified` (scoped) | Broader topology open. |
| onion-shell / smaller external / source `last = offsets` | `ClassicPerimeterShellGenerator` | source-formula fixtures | `parity_verified` (scoped) | Higher-level config breadth open. |
| pre-shell top-one-wall / Alltop / final fill path | classic shell/fill helpers | null-vs-empty, gap-fill, overlap fixtures | `parity_verified` (scoped) | Later fill generation open. |
| nesting / recursive fuzzy-overhang traversal / wall sequence | classic source/fuzzy pipeline helpers | ordering/winding/reversal/overhang/fuzzy fixtures | `parity_verified` (scoped) | Broader branches open. |
| ordered islands → traversal → nested global loops | `SourceClassicPerimeterOrderedPipeline2` | chain/order/shared RNG fixtures | `parity_verified` (scoped) | Later consumers remain open. |
| QIDI classic outwall / loop-node producer | ordered pipeline + `source_loop_node.dart` | outwall matching and ID/bbox fixtures | `parity_verified` (scoped) | Inter-layer consumer remains open. |
| lower support series / overhang grading | represented overhang helpers | mapping/smoothing/role/flow fixtures | `parity_verified` (scoped) | Other process stages remain open. |
| fuzzy policy + Classic/structured geometry + painted regions | source-shaped fuzzy modules | MT19937/libnoise/LineSegmentation/pipeline fixtures | `parity_verified` (scoped) | Full wall-engine breadth open. |
| Arachne `fuzzy_extrusion_line()` + region-aware fuzzy | source Arachne fuzzy helpers | seeded C++ goldens + region fixtures | `parity_verified` (scoped) | Full wall generator integration open. |
| full `Arachne::WallToolPaths::generate()` / `process_arachne()` | dependencies through post-construction skeletal runtime | #317 proves runtime only after graph construction | `port_started` | Immediate missing seam: `constructFromPolygons()` Voronoi→half-edge transfer, then end-to-end integration. |

## G-code / formats / device / UI

The represented source G-code formatter/extrusion-path emitter subset remains scoped `parity_verified`; the full native G-code state machine is `port_started`. STL/OBJ/AMF/3MF foundations are `port_started`; STEP, complete source-enabled formats and full project/preset round trips remain open. Device LAN/Moonraker/QIDI Box, profiles, localization and Flutter UI areas have foundations only and remain `port_started`; cloud/P2P/account/HMS/firmware, full calibration, desktop integration and full source UI/state/visual parity remain open.

## Runtime assets

An earlier local audit recorded 3,657/3,657 copied runtime entries matching source SHA-256, but the complete real runtime asset set is not yet published and reverified from GitHub/release inputs. `.gitkeep` files are not parity evidence. Remote/release asset gate remains `pending`.

## Mandatory update rule

Every meaningful migration batch must keep [`MIGRATION_STATUS.md`](MIGRATION_STATUS.md), [`VALIDATION.md`](VALIDATION.md), [`../docs/HANDOFF.md`](../docs/HANDOFF.md), and this ledger consistent with the actual code and executed CI evidence.
