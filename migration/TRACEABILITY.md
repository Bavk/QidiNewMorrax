# Traceability ledger — strict 1:1 Flutter/Dart rewrite

Acceptance authority: [`PARITY_CONTRACT.md`](PARITY_CONTRACT.md). This ledger records only implemented Dart scope and evidence attached to that exact scope. A scoped `parity_verified` entry never completes its containing subsystem.

## Current validation checkpoint

- code: `3be152aa74f3c555423a39d1b2ab36b63f959343`;
- workflow: `.github/workflows/flutter-parity.yml` run `34897876786` (#552), job `104156397361`;
- Flutter `3.47.2`, Dart `3.13.2`;
- analyzer: **No issues found**;
- tests: **832/832 passed**;
- conclusion: **success**.

Recent milestone chain:

- #390: represented per-surface `process_arachne()` wall/order/traversal/fill-tail composition;
- #394–#402: first exact pinned compiled BambuStudio CLI process fixtures for normal/one-wall, overhang, partial `Alltop` and through-hole behavior;
- later retained compiled-oracle fixtures add speed overhang, QIDI LoopNode, circle-copy metadata, final fill boundaries and narrow-wedge coverage;
- #488 / `3f22e86...`: exact Clipper1 partial/T/point rectangle-contact final unions, 751/751;
- #493 / `d718ff2...`: exact two-positive strict-convex proper-crossing final union, 760/760;
- #501 / `34f3ef8...`: first non-rectangular contact fixtures, 768/768;
- #510 / `d1731f1...`: bounded triangle-contact correction plus exact represented partial-collinear triangle joins, 781/781;
- #518 / `fc088335...`: guarded non-horizontal host-end/staggered partial-collinear triangle joins, 786/786;
- #525 / `d528f8f...`: remaining non-fixup decreasing-Y host-end triangle joins, 792/792;
- #532 / `7ad184aa...`: all non-horizontal staggered non-fixup triangle joins, 802/802;
- #539 / `c95cdaad...`: equal-bottom point-contact triangle ordering, 809/809;
- #542 / `1299cb59...`: decreasing-Y strict-contained triangle contacts, 816/816;
- #549 / `7c5e6ea5...`: endpoint-aligned host-end one-point fixup joins, 824/824;
- **#552 / `3be152aa...`: symmetric host-start one-point fixup joins, 832/832.**

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
| older represented two-triangle zero-area contacts | `SourceClipper1TwoConvexContactUnion2` | standalone starts 1100/1100, full shared-edge starts 1000/1000, older predicates 4600/4600 | `parity_verified` (scoped) | Newer special states live in separate helpers; wider-convex/fixup state not implied. |
| equal-bottom two-triangle point contact | `SourceClipper1TwoConvexEqualBottomContactUnion2` | #539 raw matrices: **41400/41400** exact raw paths, all cyclic rotations/input orders | `parity_verified` (scoped) | Wider-convex/non-point tie state not implied. |
| decreasing-Y strict-contained two-triangle contact | `SourceClipper1TwoConvexDecreasingStrictContainedUnion2` | #542 raw matrices: **30600/30600** exact full raw paths, all cyclic rotations/input orders | `parity_verified` (scoped) | Wider-convex/fixup state not implied. |
| represented endpoint/horizontal/guarded partial-collinear triangle contact | `SourceClipper1TwoConvexPartialCollinearUnion2` | #510 **4392/4392** + #518 **36000/36000** exact raw paths | `parity_verified` (scoped) | Other fixup and mixed crossing/contact are separate. |
| remaining non-fixup decreasing-Y host-end partial collinear contact | `SourceClipper1TwoConvexDecreasingHostEndUnion2` | #525 **23400/23400** exact raw paths | `parity_verified` (scoped) | Fixup/wider-convex state is separate. |
| non-horizontal staggered collinear triangle contact | `SourceClipper1TwoConvexNonHorizontalStaggeredUnion2` | #532 **145800/145800** exact raw paths across positive/negative/vertical support lines | `parity_verified` (scoped) | Other fixup and mixed crossing/contact not implied. |
| endpoint-aligned host-end join where exactly one shared endpoint is removed by `FixupOutPolygon()` | `SourceClipper1TwoConvexHostEndFixupUnion2` | #549 **145800/145800** exact full raw paths across Y directions, vertical, horizontal, shears, rotations/orders; eight tests | `parity_verified` (scoped) | Non-endpoint/full-edge/staggered/wider-convex fixup states remain open. |
| symmetric endpoint-aligned host-start one-point fixup join | `SourceClipper1TwoConvexHostStartFixupUnion2` via fixup gateway | #552 **145800/145800** exact full raw paths across same direction/shear/rotation/order families; eight tests | `parity_verified` (scoped) | Other fixup states remain open. |
| Arachne exact offset/final-union routing | `SourceArachneWallToolPathsPrepareExact2` | direct helper tests + route tests through #552 | `parity_verified` for represented branches | Other fixup/mixed cases, interacting holes, >2 paths and generic boolean cases still fall back. |
| BridgeDetector / LineSegmentation / QIDI loop-node geometry represented subsets | source-shaped Dart helpers | translated/source-shaped fixtures | `parity_verified` (scoped) | Broader consumers/topologies remain open. |

The prior contact helper was deliberately narrowed in `bf3610af5327a82e43469d31d4fd825128635c23`: a direct wider-convex audit showed **0/40** random full-shared-edge quadrilateral cases matched the old raw-start heuristic. Triangle exactness must not be extrapolated to wider convex paths.

The #539 tied-bottom helper preserves standalone triangle starts but reverses input/AddPath contour order on equal bottom scanlines; direct broad/shared/sheared matrices matched **41400/41400** raw paths.

The #542 decreasing-Y strict-contained helper uses source-state start selection from guest-third Y relative to the overlap endpoint nearer host start; broad plus targeted matrices matched **30600/30600** full raw paths.

The #549/#552 endpoint-fixup pair closes only the source state where an endpoint-aligned partial join creates one shared host endpoint collinear between the two third vertices and `FixupOutPolygon()` removes that single point. Host-end and host-start matrices each matched **145800/145800**, for **291600/291600 combined**. The gateway keeps their raw-state predicates separate; this evidence does not generalize to other fixup mutations.

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

1. **other non-endpoint fixup-mutated contact/partial joins**, then mixed proper-crossing + touch/collinear degeneracies; widen contact routing beyond triangles only with direct raw-state evidence;
2. interacting holes and surviving hole hierarchy;
3. more than two interacting paths;
4. generic final union and broader per-path `Execute()` topology;
5. remove remaining Clipper2 compatibility seams only after independent pinned evidence.

## Mandatory update rule

Every meaningful migration batch must keep [`MIGRATION_STATUS.md`](MIGRATION_STATUS.md), [`VALIDATION.md`](VALIDATION.md), [`../docs/HANDOFF.md`](../docs/HANDOFF.md), and this ledger consistent with the actual code and executed CI evidence.
