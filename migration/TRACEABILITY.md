# Traceability ledger — strict 1:1 Flutter/Dart rewrite

Acceptance authority: [`PARITY_CONTRACT.md`](PARITY_CONTRACT.md). This ledger records only implemented Dart scope and evidence attached to that exact scope. A scoped `parity_verified` entry never completes its containing subsystem.

## Current validation checkpoint

- code: `d1731f14121c80af883e78204fdcd6bc3b41116d`;
- workflow: `.github/workflows/flutter-parity.yml` run `34848910683` (#510), job `103991577409`;
- Flutter `3.47.2`, Dart `3.13.2`;
- analyzer: **No issues found**;
- tests: **781/781 passed**;
- conclusion: **success**.

Recent milestone chain:

- #390: represented per-surface `process_arachne()` wall/order/traversal/fill-tail composition;
- #394–#402: first exact pinned compiled BambuStudio CLI process fixtures for normal/one-wall, overhang, partial `Alltop` and through-hole behavior;
- later retained compiled-oracle fixtures add speed overhang, QIDI LoopNode, circle-copy metadata, final fill boundaries and narrow-wedge coverage;
- #488 / `3f22e86...`: exact Clipper1 partial/T/point rectangle-contact final unions, 751/751;
- #493 / `d718ff2...`: exact two-positive strict-convex proper-crossing final union, 760/760;
- #501 / `34f3ef8...`: first non-rectangular contact fixtures, 768/768;
- #510 / `d1731f1...`: bounded triangle-contact correction plus exact represented partial-collinear triangle joins, 781/781.

All earlier Classic, Arachne fuzzy, geometry, Boost/Voronoi and process fixtures are re-executed by the current suite.

## Core geometry / Boost / Clipper

| Source scope | Dart replacement | Evidence | Status | Remaining |
|---|---|---|---|---|
| libslic3r integer coordinate domain / Point / Line / represented Polygon APIs | `Slic3rUnits`, `SourcePoint2`, `SourceLine2`, `SourcePolygon2` | source-formula and translated geometry fixtures in current suite | `parity_verified` | Broader Polygon/ExPolygon APIs remain open. |
| Polyline / ArcFitter / Circle / ThickPolyline / MedialAxis represented subsets | source-shaped Dart geometry ports | translated/regression/oracle fixtures | `parity_verified` (scoped) | Other consumers/pathologies remain open. |
| Boost.Polygon 1.83 robust predicates/Fortune/Voronoi represented subset | direct Dart Boost/Voronoi port | C++ oracle and regression fixtures | `parity_verified` (scoped) | Broader/pathological topology coverage remains open. |
| modified Clipper1 offset input/arithmetic and represented per-path `Execute()` subsets | `SourceClipper1MiterOffset2`, orthogonal/positive-concave/negative-concave executors | source formulas and direct pinned ELF oracles | `parity_verified` (scoped) | Multi-reflex/non-local cleanup, general negative cleanup and hole-producing non-orthogonal results remain open. |
| Clipper1 final `ctUnion` + `pftNonZero`, noninteracting paths | `SourceClipper1NonInteractingUnion2` | direct pinned ELF ordering/winding oracles | `parity_verified` (scoped) | Interacting topology handled by separate subsets below. |
| Clipper1 final union, two positive axis-aligned rectangles | `SourceClipper1TwoRectangleUnion2` | pinned ELF same-span/diagonal/partial/T/point-contact oracles through #488 | `parity_verified` (scoped) | Non-rectangular cases not implied. |
| Clipper1 final union, two positive strict-convex paths with only proper crossings | `SourceClipper1TwoConvexUnion2` | 7 hand-selected + 32 deterministic random direct pinned ELF pairs; exact 39/39, committed regression tests, #493 | `parity_verified` (scoped) | Touch/collinear and rounded degeneracies are separate. |
| Clipper1 final union, two positive strict-convex triangles with represented zero-area contact | `SourceClipper1TwoConvexContactUnion2` | raw pinned ELF triangle-start/contact audits; standalone starts 1100/1100, full shared-edge starts 1000/1000, supported source-list/start/order predicates 4600/4600; #510 | `parity_verified` (scoped) | Wider convex state, equal-bottom ties, decreasing-Y strict-contained and fixup states remain open. |
| Clipper1 final union, two positive strict-convex triangles with represented partial collinear contact | `SourceClipper1TwoConvexPartialCollinearUnion2` | endpoint-at-host-start, horizontal host-end and horizontal staggered raw ELF matrix; 4392/4392 exact paths after rejecting fixup-degenerate cases; committed tests; #510 | `parity_verified` (scoped) | Non-horizontal host-end/staggered, fixup collinearity and mixed crossing/contact remain open. |
| Arachne exact offset/final-union routing | `SourceArachneWallToolPathsPrepareExact2` | direct helper tests + #493/#510 route tests | `parity_verified` for represented branches | Interacting holes, >2 interacting paths and other generic boolean cases still fall back. |
| BridgeDetector / LineSegmentation / QIDI loop-node geometry represented subsets | source-shaped Dart helpers | translated/source-shaped fixtures | `parity_verified` (scoped) | Broader consumers/topologies remain open. |

The prior contact helper was deliberately narrowed in `bf3610af5327a82e43469d31d4fd825128635c23`: a direct wider-convex audit showed **0/40** random full-shared-edge quadrilateral cases matched the old raw-start heuristic. The current `parity_verified` contact row therefore applies only to the explicitly proven triangle states and does not inherit the earlier overbroad type predicate.

## Slicer semantic model / Arachne dependencies

| Source scope | Dart replacement | Evidence | Status | Remaining |
|---|---|---|---|---|
| Flow / Surface / represented ExtrusionEntity / variable-width semantics | Dart source-shaped model | translated/source-formula tests | `parity_verified` (scoped) | Full config/entity breadth remains open. |
| Arachne fuzzy data / `fuzzy_extrusion_line()` | source Arachne junction/line + fuzzy helpers | seeded C++ goldens, metadata and region fixtures | `parity_verified` (scoped) | Broader wall-engine inputs remain open. |
| `WallToolPaths` params, preparation, beading strategies and source casts | source prepare/beading modules | float32/config/scaled-truncation and geometry fixtures | `parity_verified` (scoped) | Pathological geometry matrix open. |
| polygon segments → Boost Voronoi → skeletal graph → `generateSegments()` / `generateToolpaths()` | source Arachne graph/generation modules | direct graph/Voronoi fixtures and composed toolpath tests | `parity_verified` (scoped) | Broader production topology open. |
| `Arachne::WallToolPaths::generate()` | source WallToolPaths facade/generator | prepared outline → graph → skeletal → stitch/postprocess fixtures | `parity_verified` (scoped) | Full production/pathological matrix open. |
| Arachne planning/order/traversal/overhang/QIDI LoopNode/fill-tail represented dependencies | `SourceArachneProcess*`, ordering/traversal/infill helpers | source-shaped tests plus exact compiled process fixtures | `parity_verified` (scoped dependencies) | Whole process boundary remains below. |

## `PerimeterGenerator::process_arachne()` boundary

| Source scope | Dart replacement | Evidence | Status | Remaining |
|---|---|---|---|---|
| represented per-surface wall generation → ordering → traversal → loops → fill boundaries | `SourceArachneProcessPipeline2` + dependencies | composed source-order tests and multiple exact pinned compiled process fixtures | `implemented_unverified` (whole boundary) | Wider production/pathological geometry and remaining general Clipper1 seams. |
| normal/one-wall/Alltop/hole/overhang/fill/LoopNode/circle-copy/wedge fixture scopes | same pipeline | exact compiled BambuStudio artifact at pinned source SHA | `parity_verified` (exact fixture scopes) | Do not extrapolate beyond asserted outputs. |

Pinned compiled oracle provenance is recorded in [`VALIDATION.md`](VALIDATION.md): upstream run `34298498452`, artifact `10085378329`, artifact SHA-256 `912517d86774f4705c28a9e649f3fc91f96fe1623bdf070cb5f14f02ba3827f8`, AppImage SHA-256 `ad90fda9a4537222a679b5d2ad12712a86652858106dce00f69fac24c3af8b46`.

## Classic perimeter / later product areas

The represented Classic perimeter surface path remains scoped `parity_verified` for covered preprocessing, shell/fill, fuzzy/overhang, ordering and QIDI LoopNode behavior. The full slicer/toolpath product remains `port_started`; later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft and the complete native G-code state machine remain open. STL/OBJ/AMF/3MF foundations, profiles, scene/Preview, Device/cloud, calibration, desktop integration and Flutter UI foundations remain incomplete.

## Runtime assets

An earlier local audit recorded 3,657/3,657 copied runtime entries matching source SHA-256, but the complete real runtime asset set is not yet published and reverified from GitHub/release inputs. `.gitkeep` files are not parity evidence. Remote/release asset gate remains `pending`.

## Immediate open Clipper1 trace

1. non-horizontal host-end/staggered collinear joins, equal-bottom/fixup contact states and mixed crossing/contact degeneracies; widen contact routing beyond triangles only with direct raw-state evidence;
2. interacting holes and surviving hole hierarchy;
3. more than two interacting paths;
4. generic final union and broader per-path `Execute()` topology;
5. remove remaining Clipper2 compatibility seams only after independent pinned evidence.

## Mandatory update rule

Every meaningful migration batch must keep [`MIGRATION_STATUS.md`](MIGRATION_STATUS.md), [`VALIDATION.md`](VALIDATION.md), [`../docs/HANDOFF.md`](../docs/HANDOFF.md), and this ledger consistent with the actual code and executed CI evidence.
