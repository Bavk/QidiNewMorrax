# Traceability ledger — strict 1:1 Flutter/Dart rewrite

Acceptance authority: [`PARITY_CONTRACT.md`](PARITY_CONTRACT.md). This ledger records only implemented Dart scope and evidence attached to that exact scope. A scoped `parity_verified` entry never completes its containing subsystem.

## Current validation checkpoint

- code: `4a33e8d2592de1790ce0d63f01c0724a499ff356`;
- workflow: `.github/workflows/flutter-parity.yml` run `34726060018` (#402);
- Flutter `3.47.2`, Dart `3.13.2`;
- analyzer: **No issues found**;
- tests: **687/687 passed**;
- conclusion: **success**.

Milestone chain:

- #276 / `2a33afd...`: ordered-island classic extrusion traversal + QIDI outwall/loop-node metadata, 387/387;
- #278 / `6978000...`: first `Arachne::WallToolPaths` dependency slice, 395/395;
- #317 / `10f642e...`: post-construction skeletal `generateToolpaths()` composition, 551/551;
- #330 / `5c77305...`: real polygon → Boost Voronoi → skeletal graph → variable-width Arachne toolpaths, 584/584;
- #340 / `f23293e...`: represented `WallToolPaths::generate()` source-order path, 604/604;
- #353 / `90eec08...`: per-surface Arachne wall generation, 638/638;
- #371 / `b069eb1...`: non-overhang Arachne extrusion traversal, 669/669;
- #377 / `87c20a7...`: width-preserving binary Arachne overhang, 672/672;
- #383 / `86db415...`: speed-graded Arachne overhang, 675/675;
- #386 / `0d2131d...`: Arachne QIDI `LoopNode` producer/ranges, 677/677;
- #390 / `7eb43f3...`: represented per-surface `process_arachne()` wall/order/traversal/fill-tail composition, 681/681;
- #394 / `4bfb5b5...`: exact pinned compiled BambuStudio CLI normal/topmost/first-layer process oracles, 684/684;
- #398 / `425b64d...`: exact pinned compiled CLI non-speed overhang process oracle, 685/685;
- #400 / `e382302...`: exact pinned compiled CLI partial-`Alltop` process oracle, 686/686;
- #402 / `4a33e8d...`: exact pinned compiled CLI through-hole process oracle, 687/687.

Earlier Classic, Arachne fuzzy and geometry checkpoints remain fully re-executed by the current suite.

## Core geometry / Boost / Clipper

| Source scope | Dart replacement | Evidence | Status | Remaining |
|---|---|---|---|---|
| libslic3r integer coordinate domain / Point / Line / represented Polygon APIs | `Slic3rUnits`, `SourcePoint2`, `SourceLine2`, `SourcePolygon2` | source-formula and translated geometry fixtures in current suite | `parity_verified` | Broader Polygon/ExPolygon APIs remain open. |
| Polyline / ArcFitter / Circle represented subset | `SourcePolyline2`, fitting/circle/arc helpers | regression/oracle fixtures | `parity_verified` | Later consumers may expose more source branches. |
| ThickPolyline / MedialAxis represented subset | `ThickPolyline2`, source MedialAxis ports | direct + end-to-end thin-wall/gap fixtures | `parity_verified` | Other consumers remain open. |
| Boost.Polygon 1.83 robust predicates/Fortune/Voronoi represented subset | direct Dart Boost/Voronoi port | C++ oracle and regression fixtures | `parity_verified` | Broader/pathological topology coverage remains open. |
| Arachne polygon segments → Boost Voronoi → skeletal half-edge graph | `SourceArachneConstructFromPolygons2` and transfer/discretize helpers | direct square/identity/cleanup fixtures plus downstream WallToolPaths composition | `parity_verified` (scoped) | Arbitrary pathological polygon/cell configurations remain open. |
| Clipper/ClipperUtils represented boolean/offset/open-subject/Z-width subset | Dart Clipper2 adapters + source compatibility shims | translated/source-coordinate fixtures plus Arachne overhang process oracle | `parity_verified` (scoped) | Full QIDI/Clipper regression space remains `port_started`. |
| `BridgeDetector::detect_angle()` / `coverage()` represented source path | `SourceBridgeDetector2` | translated pinned bridge fixtures | `parity_verified` (scoped) | Arbitrary/pathological bridge geometry remains open. |
| `Point::is_in_lines(const Points&)` used by QIDI loop nodes | `SourceLoopNodeGeometry2.pointIsInLines` | endpoint/axis-aligned and strict diagonal epsilon fixtures | `parity_verified` (scoped) | Other Point consumers not implied. |
| LineSegmentation Polyline/Polygon/Arachne subset | `SourceLineSegmentation2` with direct source ZAttributes | stripe/gap/full-cover/lerp/Arachne fixtures | `parity_verified` (scoped) | Broader overlap/hole/degenerate topology remains open. |

## Slicer semantic model / Arachne dependencies

| Source scope | Dart replacement | Evidence | Status | Remaining |
|---|---|---|---|---|
| Flow | `Flow` | translated/source-formula tests | `parity_verified` | Full config integration open. |
| Extruder/QIDI config represented subset | Dart state/resolver | state/math tests | `parity_verified` | Full native print-state integration open. |
| Surface represented subset + copy/centroid preprocessing semantics | `Surface2`, classic/Arachne surface helpers | classification/copy/assignment/high-level fixtures | `parity_verified` (scoped) | Later consumers remain open. |
| ExtrusionEntity represented subset | Dart entity model incl. mutable `loopNodeRange` | entity + ordered metadata fixtures | `parity_verified` (scoped) | Remaining operations/consumers open. |
| variable-width + covered-width represented subset | `SourceVariableWidth2`, covered geometry helpers | translated/end-to-end fixtures | `parity_verified` | Later consumers open. |
| Arachne fuzzy data / `fuzzy_extrusion_line()` | source Arachne junction/line + fuzzy helpers | seeded C++ goldens, metadata and region fixtures | `parity_verified` (scoped) | Broader wall-engine inputs remain open. |
| `Arachne::WallToolPathsParams` / numeric state | `SourceArachneWallToolPathsParams2`, state/helpers | float32/config/scaled-truncation fixtures | `parity_verified` (scoped) | Broader config combinations remain open. |
| WallToolPaths prepared-outline / beading factory / source casts | prepare helpers + `SourceArachneBeadingStrategy2` family | cleanup/scalar/strategy/meta/factory fixtures | `parity_verified` (scoped) | Pathological geometry matrix open. |
| skeletal graph mutation/init + `constructFromPolygons()` | source graph model + direct Boost/Voronoi transfer | graph/topology/discretize/cleanup fixtures and downstream composition | `parity_verified` (scoped) | Broader topology oracle matrix open. |
| `SkeletalTrapezoidation::generateSegments()` | source Arachne segment modules + orchestrator | staged suites + composed fixtures | `parity_verified` (scoped) | Broader production geometry open. |
| `SkeletalTrapezoidation::generateToolpaths()` | `SourceArachneGenerateToolpaths2` | exact source-order composition + optional outer-central branch | `parity_verified` (scoped) | Broader production geometry open. |
| `Arachne::WallToolPaths::generate()` | source WallToolPaths facade/generator | prepared outline → graph → skeletal → stitch/postprocess composed fixtures | `parity_verified` (scoped) | Full production/pathological geometry matrix open. |
| Arachne per-surface normal/topmost/first-layer/`Alltop` wall generation | `SourceArachneProcessSurface2` | translated fixtures plus exact compiled CLI normal/one-wall/partial-Alltop differentials | `parity_verified` (scoped) | Additional geometry/config combinations open. |
| Arachne region/extrusion ordering | region/order helpers | source ordering/tie/wall-sequence fixtures | `parity_verified` (scoped) | Broader candidate graphs open. |
| Arachne non-overhang traversal | `SourceArachneExtrusionTraversal2` | fuzzy/width/loop/open/winding fixtures and process CLI fixtures | `parity_verified` (scoped) | Broader open-line/pathological cases open. |
| Arachne non-speed active overhang | Clipper-Z support/difference + traversal helpers | helper fixtures + exact compiled CLI stepped-model differential #398 | `parity_verified` (scoped) | More support topologies open. |
| Arachne speed-graded overhang | source 2mm sampling / signed distance / degree split / smoothing helpers | direct source-shaped tests, #383 | `parity_verified` (helper scope) | Independent process-level oracle still open. |
| Arachne QIDI raw external `LoopNode` producer | traversal LoopNode path | direct source-shaped ID/range/bbox tests, #386 | `parity_verified` (helper scope) | Independent external process oracle + downstream consumer open. |
| `add_infill_contour_for_arachne()` | `SourceArachneInfillContour2` | overlap/no-wall/mixed-spacing fixtures | `parity_verified` (helper scope) | Independent process-level fill-boundary oracle open. |

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

## `PerimeterGenerator::process_arachne()` surface boundary

| Source scope | Dart replacement | Evidence | Status | Remaining |
|---|---|---|---|---|
| represented per-surface wall generation → ordering → traversal → global loops → Arachne fill boundaries | `SourceArachneProcessPipeline2` + dependencies | composed source-order tests, #390 | `implemented_unverified` (whole boundary) | Remaining independent process oracles below. |
| normal two-wall square + topmost/first-layer one-wall | same pipeline | exact pinned compiled BambuStudio CLI, #394 | `parity_verified` (exact fixture scope) | Wider geometry/config matrix. |
| non-speed active-overhang stepped surface | same pipeline | exact pinned compiled CLI wall spans/role bands/support split, #398 | `parity_verified` (exact fixture scope) | More support topologies; speed branch separate. |
| partial `Alltop` surface | same pipeline | exact pinned compiled CLI first-wall/remainder dimensions and placement, #400 | `parity_verified` (exact fixture scope) | Additional Alltop shapes/thresholds. |
| 20×20mm frame with centered 10×10mm through-hole | same pipeline | exact pinned compiled CLI four-loop contour/hole spans, #402 | `parity_verified` (exact fixture scope) | QIDI circle-compensation metadata not implied. |
| speed-graded overhang at complete process boundary | represented in Dart | helper/source-shaped tests only | `implemented_unverified` | Independent degree/geometry oracle without downstream speed-policy conflation. |
| Arachne QIDI LoopNode/ranges at complete process boundary | represented in Dart | direct producer tests only | `implemented_unverified` | Need independent observable/instrumented source oracle. |
| final `fill_surfaces` / `fill_no_overlap`, no-wall/mixed-spacing | represented in Dart | composed/helper tests incl. 7999/7599 quirks | `implemented_unverified` | Need independent process-level source output. |
| QIDI circle compensation through process boundary | represented metadata/flags | translated/source-shaped tests | `implemented_unverified` | Need independent source output; ordinary hole CLI fixture does not prove it. |

Pinned compiled CLI oracle provenance for the exact fixture scopes above is recorded in [`VALIDATION.md`](VALIDATION.md): upstream run `34298498452`, artifact `10085378329`, artifact SHA-256 `912517d86774f4705c28a9e649f3fc91f96fe1623bdf070cb5f14f02ba3827f8`, AppImage SHA-256 `ad90fda9a4537222a679b5d2ad12712a86652858106dce00f69fac24c3af8b46`.

## G-code / formats / device / UI

The represented source G-code formatter/extrusion-path emitter subset remains scoped `parity_verified`; the full native G-code state machine is `port_started`. STL/OBJ/AMF/3MF foundations are `port_started`; STEP, complete source-enabled formats and full project/preset round trips remain open. Device LAN/Moonraker/QIDI Box, profiles, localization and Flutter UI areas have foundations only and remain `port_started`; cloud/P2P/account/HMS/firmware, full calibration, desktop integration and full source UI/state/visual parity remain open.

## Runtime assets

An earlier local audit recorded 3,657/3,657 copied runtime entries matching source SHA-256, but the complete real runtime asset set is not yet published and reverified from GitHub/release inputs. `.gitkeep` files are not parity evidence. Remote/release asset gate remains `pending`.

## Mandatory update rule

Every meaningful migration batch must keep [`MIGRATION_STATUS.md`](MIGRATION_STATUS.md), [`VALIDATION.md`](VALIDATION.md), [`../docs/HANDOFF.md`](../docs/HANDOFF.md), and this ledger consistent with the actual code and executed CI evidence.
