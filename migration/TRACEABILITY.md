# Traceability ledger — strict 1:1 Flutter/Dart rewrite

## #628 translated AEL-outside rounded trace

`SourceClipper1TwoConvexMixedPointUnion2` now recognizes the two independently source-traced AEL-outside rounded strict-max families (retained-inner-vertex and retained-wedge) only when their point sets are exact integer translations of the canonical fixtures. Evidence: fixed 36/36 full raw paths (`35217212927` / `105188120437`), translation matrix **36000/36000** full raw paths (`35217607425` / `105189698086`), plus the explicit ×2 scaling counterexample (`35217503833` / `105189359905`) that keeps scaled and broader neighboring states outside this exact subset. Flutter checkpoint `00a49000cedaa85f21bd9fbfcf007e2512860bb6` is green in #628 (`35218255121` / `105191803438`) with **870/870** tests.


Acceptance authority: [`PARITY_CONTRACT.md`](PARITY_CONTRACT.md). This ledger records only implemented Dart scope and evidence attached to that exact scope. A scoped `parity_verified` entry never completes its containing subsystem.

## Current validation checkpoint

- code: `00a49000cedaa85f21bd9fbfcf007e2512860bb6`;
- workflow: `.github/workflows/flutter-parity.yml` run `35218255121` (#628), job `105191803438`;
- Flutter `3.47.2`, Dart `3.13.2`;
- analyzer: **No issues found**;
- tests: **870/870 passed**;
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
- #552 / `3be152aa...`: symmetric host-start one-point fixup joins, 832/832;
- #562 / `8f9b8f0f...`: full-shared-edge one-point fixup joins including removed-start pointer state, 840/840;
- #569 / `d238cc80...`: mixed proper-crossing + strict-minimum-Y point-touch triangle subset, 848/848;
- #575 / `a987f4ae...`: ordered strict-maximum mixed point-touch triangle extension, 854/854;
- #582 / `83665f5a...`: late strict-maximum single-crossing mixed point-touch extension, 860/860;
- #588 / `81beaaed...`: strict-maximum equal-Y mixed point-touch boundary and source-state rebase, 861/861;
- #601 / `82793869...` (functional `3a100f82...`): late strict-maximum multi-crossing mixed point-touch extension and separated-minimum source-state rebase, 862/862;
- #608 / `5bbdb555...`: late strict-maximum single-crossing separated-minimum boundary, 863/863.
- **#615 / `d3bc685a...`: rounded-to-touch AEL-contained strict-maximum single-crossing collapse, 870/870.**

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
| represented endpoint/horizontal/guarded partial-collinear triangle contact | `SourceClipper1TwoConvexPartialCollinearUnion2` | #510 **4392/4392** + #518 **36000/36000** exact raw paths | `parity_verified` (scoped) | Mixed crossing/contact is separate. |
| remaining non-fixup decreasing-Y host-end partial collinear contact | `SourceClipper1TwoConvexDecreasingHostEndUnion2` | #525 **23400/23400** exact raw paths | `parity_verified` (scoped) | Wider-convex state is separate. |
| non-horizontal staggered collinear triangle contact | `SourceClipper1TwoConvexNonHorizontalStaggeredUnion2` | #532 **145800/145800** exact raw paths across positive/negative/vertical support lines | `parity_verified` (scoped) | Mixed crossing/contact not implied. |
| endpoint-aligned host-end join where exactly one shared endpoint is removed by `FixupOutPolygon()` | `SourceClipper1TwoConvexHostEndFixupUnion2` | #549 **145800/145800** exact full raw paths across Y directions, vertical, horizontal, shears, rotations/orders; eight tests | `parity_verified` (scoped) | Wider/multi-point/mixed fixup states remain open. |
| symmetric endpoint-aligned host-start one-point fixup join | `SourceClipper1TwoConvexHostStartFixupUnion2` via fixup gateway | #552 **145800/145800** exact full raw paths across same direction/shear/rotation/order families; eight tests | `parity_verified` (scoped) | Wider/multi-point/mixed fixup states remain open. |
| full-shared-edge strict-triangle join where exactly one shared endpoint is removed by `FixupOutPolygon()` | `SourceClipper1TwoConvexFullSharedEdgeFixupUnion2` via fixup gateway | #562 **226908/226908** exact raw paths: 64800 non-start removal + 64800 removed-start classification + 97200 independent unequal-distance + 108 equal-Y; eight tests | `parity_verified` (scoped) | Wider-convex, multi-point and mixed-crossing cleanup not implied. |
| two positive strict-convex triangles with proper crossings + exactly one vertex↔strict-edge point touch in the #569 strict-minimum and represented non-horizontal strict-maximum ordering classes (#575 `<`, #588 `==`, #582/#601/#608 late `>`), plus #615 rounded-to-touch AEL-contained collapse | `SourceClipper1TwoConvexMixedPointUnion2` | #569 **39600/39600**, #575 **72000/72000**, #582 **64800/64800** exact full raw paths; #588 **54000/54000** raw-start matches plus fixed full-path fixture; #601 adds **216000/216000** generic late-multicross raw starts plus **64800/64800 exact full raw paths** on the multi-cross separated-minimum boundary; #608 adds **64800/64800 exact full raw paths** plus **18/18** fixed variants; #615 source trace + **9174 bases / 165132/165132 exact complete raw paths** for the exact `WindCnt == 1` AEL-contained rounded-collapse branch | `parity_verified` (scoped) | broader AEL-outside rounded/degenerated states beyond the two translation-locked retained-inner-vertex/retained-wedge families, horizontal, side-vertex, mixed-collinear and other rounded/degenerated output-list states remain open. |
| Arachne exact offset/final-union routing | `SourceArachneWallToolPathsPrepareExact2` | direct helper tests + route tests through #615 | `parity_verified` for represented branches | Remaining mixed states, interacting holes, >2 paths and generic boolean cases still fall back. |
| BridgeDetector / LineSegmentation / QIDI loop-node geometry represented subsets | source-shaped Dart helpers | translated/source-shaped fixtures | `parity_verified` (scoped) | Broader consumers/topologies remain open. |

The prior contact helper was deliberately narrowed in `bf3610af5327a82e43469d31d4fd825128635c23`: a direct wider-convex audit showed **0/40** random full-shared-edge quadrilateral cases matched the old raw-start heuristic. Triangle exactness must not be extrapolated to wider convex paths.

The #539 tied-bottom helper preserves standalone triangle starts but reverses input/AddPath contour order on equal bottom scanlines; direct broad/shared/sheared matrices matched **41400/41400** raw paths.

The #542 decreasing-Y strict-contained helper uses source-state start selection from guest-third Y relative to the overlap endpoint nearer host start; broad plus targeted matrices matched **30600/30600** full raw paths.

The #549/#552 endpoint-fixup pair closes only the source state where an endpoint-aligned partial join creates one shared host endpoint collinear between the two third vertices and `FixupOutPolygon()` removes that single point. Host-end and host-start matrices each matched **145800/145800**, for **291600/291600 combined**.

The #562 full-shared-edge helper adds the other strict-triangle one-point collinearity geometry. Its **226908/226908** raw matrix explicitly includes the state where `FixupOutPolygon()` removes the ordinary pre-fixup `BuildResult()` start; that branch depends on the source triangle whose directed shared edge ends at the removed endpoint and on AddPath/input order. The implementation preserves that source-state asymmetry rather than canonicalizing the contour.

For strict triangles with a single collinear shared interval, endpoint-aligned and full-shared-edge cases are the one-point cleanup geometries where the two off-support-line third edges become adjacent at a shared endpoint. Strict-contained/staggered overlap keeps a support-line boundary fragment at the relevant endpoint and does not create that same collinearity. Wider-convex, multi-point and mixed-crossing fixups remain unproved.

The mixed point helper remains explicitly source-event bounded. #569 proves the strict-minimum touching vertex class with **39600/39600** raw paths. #575 proves an early strict-max class with **72000/72000** full raw paths when the touched edge is non-horizontal and `otherThird.y < min(ownerPrevious.y, ownerNext.y)`, spanning 1–4 proper crossings. #588 proves the equal-Y boundary with **54000/54000** raw-start-rule matches plus a fixed complete-path regression. #582 proves the late `>` single-crossing class with **64800/64800** exact full raw paths. #601 extends the same late `>` class to multi-crossing states with **216000/216000** independent generic/targeted raw-start matches and a separate **64800/64800 exact full-path** multi-cross separated-minimum boundary matrix. #608 independently proves the matching single-cross separated-minimum endpoint-Y boundary with **64800/64800 exact full raw paths** plus **18/18** fixed variants; together the ordinary `>` source matrices span proper-count 1–4. #615 separately proves the rounded-to-touch single-crossing branch only when exact AEL ordering places both already-active other bounds between owner bounds: direct tracing distinguishes the accepted `WindCnt == 1` state from `WindCnt == 2` retained-vertex/wedge counterstates, and **9174 bases / 165132/165132 exact full raw paths** lock that classifier.

The #588, #601 and #608 audits establish independently classified states where a valid output may have two nonadjacent global minimum-Y vertices. `SourceClipper1TwoConvexMixedPointUnion2` relaxes its old adjacent-minima rebase guard only for those proved states and still chooses the source rightmost-minimum anchor. #615 does not widen that rebase rule; it ports the exact `E2InsertsBeforeE1()`/`TopX()` AEL-contained state and returns the traced owner contour before ordinary boundary reconstruction. AEL-outside rounded collapses, horizontal strict-max touches, side-vertex touches and mixed collinear states stay fallback. Runtime AEL / `AppendPolygon()` / `OutRec::Pts` behavior remains acceptance-relevant and the exact predicates above are the independently proved bounds.

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

1. Continue **mixed proper-crossing + point-touch/collinear degeneracies** beyond the #569/#575/#588/#582/#601/#608 event classes: remaining rounded/degenerated strict-max cases beyond the separated-minimum endpoint-Y boundary, then side-vertex touches, horizontal ordering and mixed collinear states. Use exact traced output-list state; do not reuse the proper-crossing rebase heuristic without proof.
2. Wider-convex and multi-point/non-triangle fixup state only with direct raw evidence.
3. Interacting holes and surviving hole hierarchy.
4. More than two interacting paths.
5. Generic final union and broader per-path `Execute()` topology.
6. Remove remaining Clipper2 compatibility seams only after independent pinned evidence.

## Mandatory update rule

Every meaningful migration batch must keep [`MIGRATION_STATUS.md`](MIGRATION_STATUS.md), [`VALIDATION.md`](VALIDATION.md), [`../docs/HANDOFF.md`](../docs/HANDOFF.md), and this ledger consistent with the actual code and executed CI evidence.