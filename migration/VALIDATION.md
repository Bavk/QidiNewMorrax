# Validation record — strict 1:1 rewrite

This file records only work that has actually executed. Acceptance authority remains [`PARITY_CONTRACT.md`](PARITY_CONTRACT.md); a passing subset never closes a top-level application gate.

## Input identity / loss-prevention baseline

- Supplied archive: `QidiFlow-2.07.02.60-Pass28-Device-Reference-Redesign-Clean(1).zip`.
- Archive SHA-256 from the initial audit: `821ed379d65916df32f5d031bd583bc724ce72f4d229447adc61280701e4d57d`.
- Extracted source files inventoried: **8,632**.
- Earlier local runtime-asset audit: **3,657/3,657** copied runtime entries matched source SHA-256; full publication/reverification from GitHub/release inputs is still open.

## Current executed Flutter/Dart checkpoint — 2026-09-14

Pinned toolchain:

- Flutter `3.47.2`;
- Dart `3.13.2`;
- Ubuntu 24.04 hosted runner.

GitHub Actions `.github/workflows/flutter-parity.yml` run `34858695268` (#525), job `104024892024`, executed code commit `d528f8f91607d0307a6d9c584ea9b5dfc3402fa2` and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **`+792: All tests passed!`**;
- job conclusion — **success**.

The suite re-executes all earlier represented Classic/Arachne/geometry/Boost/Clipper fixtures and includes six new regression tests for the remaining non-fixup decreasing-Y host-end triangle states, exact Arachne routing and the post-join fixup rejection boundary.

## Independent pinned BambuStudio oracle provenance

Reference evidence comes from the **actual upstream compiled BambuStudio artifact at the exact pinned source commit**, not from the Dart implementation under test.

- repository: `bambulab/BambuStudio`;
- source commit: `f2b55a5a83f266cf56e06c7943a81a08bebb7fad`;
- successful upstream GitHub Actions run: `34298498452` (`Build all`);
- Ubuntu 24.04 artifact ID/name: `10085378329` / `BambuStudio_ubuntu-24.04_V02.08.03.66`;
- downloaded artifact SHA-256: `912517d86774f4705c28a9e649f3fc91f96fe1623bdf070cb5f14f02ba3827f8`;
- extracted AppImage SHA-256: `ad90fda9a4537222a679b5d2ad12712a86652858106dce00f69fac24c3af8b46`;
- CLI version: `02.08.03.66`.

The debug-symbol ELF exposes the pinned modified Clipper 6.2.9 implementation. The preload probe calls the exact `clipper_union(Paths&, pftNonZero)` template at PIE offset `0x10b54d0` before application startup and dumps raw result paths without normalizing rotation/order. Batch and trace forms of the same probe were used for the matrices below.

Pinned source inspection and ELF tracing confirm why geometric equivalence is insufficient: `BuildResult(Paths&)` starts each result at `OutRec::Pts->Prev`; `AddOutPt()`, local-minimum side assignment, `AppendPolygon()`, `JoinPoints()` and `FixupOutPolygon()` can change output-list state and therefore raw path rotation/order.

## #525 remaining decreasing-Y host-end partial-collinear oracle

New exact helper: `SourceClipper1TwoConvexDecreasingHostEndUnion2`.

This follow-up deliberately keeps the older `SourceClipper1TwoConvexPartialCollinearUnion2` proof boundary intact and owns only the remaining **non-fixup decreasing-Y host-end** state:

- exactly two positive strict-convex triangles;
- the shorter guest edge is fully contained by one longer host edge and reaches exactly the **end** of that host edge;
- host edge has `dy < 0`;
- the two paths traverse the shared interval in opposite directions and occupy opposite sides of the support line;
- any merged cycle needing collinear `FixupOutPolygon()` cleanup is rejected.

Direct raw ELF differentials establish the exact `BuildResult()` start rule:

- guest third vertex below the interior overlap endpoint → **shared host edge end**;
- guest third vertex above the interior overlap endpoint → **host edge start**;
- equal Y → **standalone pinned Clipper1 start of the host triangle**.

Executed oracle matrices:

- broad decreasing-Y host-end matrix: **14400/14400 exact raw result paths**;
- targeted equal-Y tie matrix: **9000/9000 exact raw result paths**;
- combined #525 evidence: **23400/23400 exact raw result paths**.

The matrices vary translations, host-edge X direction including vertical edges, overlap ratios, third-vertex placement, all three cyclic rotations of both source triangles and both polygon input orders. Equality is raw contour count, integer coordinates, vertex sequence and `BuildResult()` start with no normalization.

A direct fixup counterexample was also executed: with host `(0,100000),(0,0),(100000,50000)` and guest `(0,0),(0,40000),(-80000,-40000)`, pinned Clipper1 removes the shared endpoint during cleanup and returns `0,100000 0,40000 -80000,-40000 100000,50000`. This proves the fixup branch requires separate pointer-state treatment and justifies rejecting it in the new helper.

Committed regression coverage in `test/core/slicer/source_clipper1_two_convex_decreasing_host_end_union_test.dart` contains six tests:

- guest third below the overlap endpoint;
- guest third above the overlap endpoint;
- equal-Y host standalone-start rule;
- the previously unrepresented vertical host-end fixture;
- exact Arachne zero-offset routing;
- rejection of post-join collinear fixup.

The exact-output helper in those tests also exercises all 3×3 cyclic source rotations and both polygon input orders for represented fixtures. All six tests are included in #525's **792/792** green suite.

## Retained #518 non-horizontal partial-collinear extension

The first unfinished #510 priority was the non-horizontal host-end/staggered triangle seam. Broad exploratory probing deliberately preceded implementation and showed that simple edge-slope or sign-only rules are not invariant under cyclic source-list rotation. The production helper therefore represents only source-state predicates that were independently differential-tested.

Represented contract retained in `SourceClipper1TwoConvexPartialCollinearUnion2`:

- inputs remain exactly two positive strict-convex triangles with one partial collinear boundary interval, disjoint interiors otherwise, opposite traversal along the common interval and no proper segment crossing;
- existing #510 host-start and horizontal states remain unchanged;
- non-horizontal host-end, host edge `dy > 0`: exact raw start is the host edge start for the represented non-fixup state;
- non-horizontal host-end, host edge `dy < 0`: represented when the guest triangle's standalone Clipper1 `BuildResult()` start is the shared host endpoint;
- non-horizontal staggered: represented for the negative-slope state where the source overlap edge directed down-left starts at that triangle's standalone Clipper1 result start;
- merged cycles needing duplicate/collinear cleanup by `FixupOutPolygon()` remain rejected;
- positive-slope/other staggered, mixed crossing/contact and wider-convex states remain compatibility fallback.

Independent raw ELF matrices retained by #525:

- increasing-Y non-horizontal host-end states: **12000/12000 exact raw result paths**;
- guarded decreasing-Y non-horizontal host-end states: **12000/12000 exact**;
- guarded negative-slope non-horizontal staggered states: **12000/12000 exact**;
- total #518 evidence: **36000/36000 exact raw paths**.

These matrices varied translations, overlap ratios, third-vertex placement, cyclic triangle vertex rotations and both polygon input orders. Equality was raw: contour count, integer coordinates, vertex sequence and `BuildResult()` start, with no post-normalization.

## Retained #510 contact-scope correction

The earlier contact helper was too broad in its type predicate: it accepted arbitrary strict-convex paths even though the direct fixtures had established only triangle states. The #510 oracle audit caught the extrapolation before extending it further.

Observed evidence retained by #525:

- random full-shared-edge quadrilateral audit: **0/40** matches to the previous raw-start heuristic, proving the old widening invalid;
- standalone positive triangle `BuildResult()` start behavior: **1100/1100** raw ELF cases;
- complete shared-edge triangle start behavior: **1000/1000** random raw cases;
- supported point/full/strict-contained triangle source-list/start/order predicates: **4600/4600** asserted cases including reversed input order;
- represented #510 partial-collinear baseline: **4392/4392 exact raw result paths** after excluding states requiring post-join fixup.

Commit `bf3610af5327a82e43469d31d4fd825128635c23` narrowed `SourceClipper1TwoConvexContactUnion2` to the proven triangle states. Equal-bottom point-contact ties, unsupported strict-contained directions and fixup-mutated contact joins remain fallback.

## Retained #493 proper-crossing convex evidence

The earlier non-rectangular proper-crossing subset remains independently validated:

- exactly two positive, strictly convex closed paths with only proper segment intersections;
- no edge/point touching, collinear overlap or containment-only case;
- exact pinned scanline `TopX()` / `IntersectPoint()` rounding and exact `BuildResult()` order/start;
- 7 hand-selected cases plus 32 deterministic random pairs;
- **39/39 exact** raw ELF matches, including reversed input order and 2/4/6 crossing topologies.

Committed coverage remains in `test/core/slicer/source_clipper1_two_convex_union_test.dart` and is re-executed by #525.

## Retained Clipper1 evidence

Earlier direct compiled-oracle batches remain re-executed by #525, including:

- `ClipperOffset::AddPath()` pruning, float caller delta, normals, miter/square/concave raw arithmetic;
- convex positive expansion/erosion and CW-hole sign/orientation semantics;
- orthogonal concave `Execute()` including topology-changing positive results;
- isolated positive V-notch and one-reflex negative `pftNegative` cleanup;
- noninteracting NonZero cross-path result ordering/winding;
- two-positive axis-aligned rectangle union for same-span touch, diagonal area overlap, strict unequal/T edge contacts and point-only contacts (#488);
- two-positive strict-convex proper-crossing union (#493);
- bounded triangle zero-area contact and partial-collinear states through #518.

## Retained compiled Arachne process evidence

The suite retains independent pinned compiled-BambuStudio process fixtures for normal two-wall and one-wall gates, non-speed and speed-graded overhang, partial `Alltop`, through-hole walls, QIDI `LoopNode`, QIDI circle-copy metadata behavior, final Arachne fill boundaries and a narrow-wedge topology case. These remain scoped exact fixture evidence; the represented `process_arachne()` boundary is **`implemented_unverified` as a whole**.

## Still not proven

For the current Clipper1/Arachne priority, independent or complete representation is still missing for:

- wider-convex zero-area contact output-list state;
- equal-bottom point-contact ties and fixup-mutated contact joins;
- strict-contained decreasing-Y triangle **contact** joins;
- positive-slope and other unrepresented non-horizontal staggered partial joins;
- fixup-created collinearity after partial joins;
- mixed proper-crossing + touch/collinear cases;
- interacting positive/negative hole boundaries and deeper/multiple surviving hole hierarchy;
- more than two interacting final-union paths;
- multi-reflex/non-local non-orthogonal per-path cleanup, split/hole-producing non-orthogonal results and broader negative `pftNegative` execution;
- remaining prepared-outline final `unionNonZero()` cases where compatibility fallback can still introduce Clipper2 ordering/rounding differences;
- broader production/pathological `process_arachne()` geometry/config combinations.

Product-wide work also remains for later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft algorithms, complete native G-code behavior, full project/profile persistence and source-enabled formats, scene/editor/Preview, Device/cloud/P2P/account/camera/HMS/firmware, calibration, desktop integration, full UI/localization/accessibility, hardware-in-the-loop behavior, runtime assets and release builds/installers.

## Next validation boundary

1. Derive exact raw-ELF state for **positive-slope/other unrepresented non-horizontal staggered joins, equal-bottom/fixup contact cases, then mixed proper-crossing + touch/collinear**. Do not widen beyond triangles until the corresponding wider-convex `OutRec` state is independently proved.
2. Extend the final-union oracle matrix to **interacting holes**, then **more than two interacting paths**.
3. Continue generic/per-path Clipper1 execution only with exact source-order/rounding evidence.
4. Expand whole `process_arachne()` differentials after the remaining final-union seams are reduced.

## Completion truth

**Zero top-level parity gates are closed.** Individual source behaviors and exact compiled-oracle fixture scopes may be marked `parity_verified` only for their asserted contract. Broader modules remain incomplete until every required source path, integration boundary and reference test is covered.
