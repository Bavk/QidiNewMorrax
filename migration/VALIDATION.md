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

GitHub Actions `.github/workflows/flutter-parity.yml` run `34896399166` (#542), job `104151463543`, executed code commit `1299cb5999f31b5c1659e1796d6d462fafa5d9f1` and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **`+816: All tests passed!`**;
- job conclusion — **success**.

The suite re-executes all earlier represented Classic/Arachne/geometry/Boost/Clipper fixtures and adds fourteen tests beyond #532: seven for equal-bottom point-contact ordering and seven for decreasing-Y strict-contained triangle contacts, including exact Arachne routing and ownership/rejection boundaries.

## Independent pinned BambuStudio oracle provenance

Reference evidence comes from the **actual upstream compiled BambuStudio artifact at the exact pinned source commit**, not from the Dart implementation under test.

- repository: `bambulab/BambuStudio`;
- source commit: `f2b55a5a83f266cf56e06c7943a81a08bebb7fad`;
- successful upstream GitHub Actions run: `34298498452` (`Build all`);
- Ubuntu 24.04 artifact ID/name: `10085378329` / `BambuStudio_ubuntu-24.04_V02.08.03.66`;
- downloaded artifact SHA-256: `912517d86774f4705c28a9e649f3fc91f96fe1623bdf070cb5f14f02ba3827f8`;
- extracted AppImage SHA-256: `ad90fda9a4537222a679b5d2ad12712a86652858106dce00f69fac24c3af8b46`;
- CLI version: `02.08.03.66`.

The artifact was re-used from the previously SHA-verified download for this batch. The debug-symbol ELF exposes the pinned modified Clipper 6.2.9 implementation. The preload probe calls the exact `clipper_union(Paths&, pftNonZero)` template at PIE offset `0x10b54d0` before application startup and dumps raw result paths without normalizing rotation/order. Batch forms of the same probe were used for the matrices below.

Pinned source inspection and ELF tracing confirm why geometric equivalence is insufficient: `BuildResult(Paths&)` starts each result at `OutRec::Pts->Prev`; `AddOutPt()`, local-minimum side assignment, `AppendPolygon()`, `JoinPoints()` and `FixupOutPolygon()` can change output-list state and therefore raw path rotation/order.

## #539 equal-bottom point-contact oracle

New exact helper: `SourceClipper1TwoConvexEqualBottomContactUnion2`.

Represented contract:

- exactly two positive strict-convex triangles;
- exactly one point-only contact and otherwise disjoint interiors;
- both source triangles have the same maximum-Y / bottom scanline;
- no proper crossing and no nonzero collinear overlap;
- wider convex paths remain outside the helper.

Direct raw ELF probing established the missing equal-bottom source-list rule:

- Clipper1 keeps the point-touching triangles as **two separate contours**;
- each contour preserves its exact standalone positive-triangle `BuildResult()` start;
- tied-bottom result contour order is exactly the **reverse of `AddPath()` / input order**.

Executed oracle matrices:

- broad vertex↔vertex / vertex↔edge tied-bottom states: **21600/21600 exact raw paths**;
- shared-bottom and flat-bottom vertex-contact states: **9000/9000 exact raw paths**;
- sheared nonvertical vertex↔edge states: **10800/10800 exact raw paths**;
- combined #539 evidence: **41400/41400 exact raw result paths**.

Every matrix includes all 3×3 cyclic rotations of both source triangles and both polygon input orders. Equality is raw contour count, integer coordinates, vertex sequence, per-contour start and contour order with no normalization.

Committed regression coverage in `test/core/slicer/source_clipper1_two_convex_equal_bottom_contact_union_test.dart` contains seven tests covering ordinary tied-bottom vertex contact, shared flat-bottom contact, sheared vertex-edge contact, exact Arachne routing and ownership/rejection boundaries. CI #539 (`34895670398`, job `104148897010`) completed with analyzer clean and **809/809** tests passed.

## #542 decreasing-Y strict-contained contact oracle

New exact helper: `SourceClipper1TwoConvexDecreasingStrictContainedUnion2`.

Represented contract:

- exactly two positive strict-convex triangles;
- both endpoints of one shorter guest edge lie **strictly inside** one longer host edge;
- the shared interval is traversed in opposite directions;
- the host edge has `dy < 0` in positive host source order, including vertical decreasing edges;
- the two third vertices lie in opposite open half-planes of the common support line;
- endpoint-aligned/partial joins remain owned by their separate helpers;
- wider convex paths remain outside this helper.

Let host edge be `H0→H1`, `qStart` the overlap endpoint nearer `H0`, `qEnd` the endpoint nearer `H1`, `H` the host third vertex and `G` the guest third vertex. Direct raw ELF differentials establish the exact merged contour `BuildResult()` start:

- `G.y < qStart.y` → **`qEnd`**;
- `G.y > qStart.y` → **host third `H`**;
- `G.y == qStart.y` → **standalone pinned Clipper1 start of the host triangle**.

Executed oracle matrices:

- broad translations/slopes/overlap/third-vertex matrix: **25200/25200 exact full raw result paths**;
- targeted vertical/equal-Y/slope-boundary matrix: **5400/5400 exact**;
- combined #542 evidence: **30600/30600 exact full raw result paths**.

The matrices include all 3×3 cyclic rotations and both polygon input orders. Equality is raw contour count, integer coordinates, vertex sequence and `BuildResult()` start with no normalization.

Committed regression coverage in `test/core/slicer/source_clipper1_two_convex_decreasing_strict_contained_union_test.dart` contains seven tests: below/above/equal-Y branches, vertical host edge, exact Arachne zero-offset routing, old-helper ownership of increasing-Y contact and endpoint-aligned rejection. All are included in #542's **816/816** green suite.

## Retained #532 all non-horizontal staggered partial-collinear oracle

`SourceClipper1TwoConvexNonHorizontalStaggeredUnion2` remains the exact helper for two positive strict-convex triangles with one non-horizontal staggered collinear interval, opposite traversal, disjoint interiors otherwise and no post-join fixup.

Independent raw ELF matrices remain:

- positive-slope support lines: **48600/48600 exact raw paths**;
- negative-slope support lines: **48600/48600 exact raw paths**;
- vertical support lines: **48600/48600 exact raw paths**;
- combined #532 evidence: **145800/145800 exact raw result paths**.

Each family covers strict end-overlap, start-overlap, equal-Y ties and the equality boundary, with all 3×3 cyclic rotations and both input orders. Horizontal staggered joins remain owned by the earlier #510 partial-collinear helper.

## Retained #525 remaining decreasing-Y host-end partial-collinear oracle

`SourceClipper1TwoConvexDecreasingHostEndUnion2` owns the remaining non-fixup decreasing-Y host-end triangle state while preserving the older helper's proof boundary.

Direct raw ELF differentials established:

- broad decreasing-Y host-end matrix: **14400/14400 exact raw result paths**;
- targeted equal-Y tie matrix: **9000/9000 exact raw result paths**;
- combined #525 evidence: **23400/23400 exact raw result paths**.

The raw start is shared host end when the guest third vertex is below the interior overlap endpoint, host start when above, and the standalone pinned host-triangle start when Y is equal. Matrices vary translations, host-edge X direction including vertical, overlap ratios, third-vertex placement, all cyclic rotations and both input orders.

A direct fixup counterexample showed pinned Clipper1 can remove the shared endpoint during cleanup, so post-join collinear fixup remains a separate seam.

## Retained #518 non-horizontal partial-collinear extension

`SourceClipper1TwoConvexPartialCollinearUnion2` retains its exact host-start, horizontal, increasing-Y host-end and guarded older non-horizontal states. The #518 raw matrices remain **36000/36000 exact** across three guarded source states. #532 supersedes the previous staggered guard only by routing the independently proven generic non-horizontal staggered triangle helper first; the older helper itself is not widened.

## Retained #510 contact-scope correction

The earlier contact helper was deliberately narrowed to triangle states after a random full-shared-edge quadrilateral audit produced **0/40** matches to the old raw-start heuristic. Retained triangle evidence:

- standalone positive triangle `BuildResult()` starts: **1100/1100**;
- complete shared-edge triangle starts: **1000/1000**;
- older supported point/full/strict-contained triangle source-list/start/order predicates: **4600/4600**;
- represented #510 partial-collinear baseline: **4392/4392 exact raw result paths** after excluding post-join fixup states.

Commit `bf3610af5327a82e43469d31d4fd825128635c23` narrowed `SourceClipper1TwoConvexContactUnion2` to those proven triangle states. Equal-bottom point contacts and decreasing-Y strict-contained contacts were deliberately left fallback at #510 and are now independently covered by the #539 and #542 helpers above. **Fixup-mutated contact joins remain fallback.**

## Retained #493 proper-crossing convex evidence

The earlier non-rectangular proper-crossing subset remains independently validated:

- exactly two positive, strictly convex closed paths with only proper segment intersections;
- no edge/point touching, collinear overlap or containment-only case;
- exact pinned scanline `TopX()` / `IntersectPoint()` rounding and exact `BuildResult()` order/start;
- 7 hand-selected cases plus 32 deterministic random pairs;
- **39/39 exact** raw ELF matches, including reversed input order and 2/4/6 crossing topologies.

Committed coverage remains in `test/core/slicer/source_clipper1_two_convex_union_test.dart` and is re-executed by #542.

## Retained Clipper1 evidence

Earlier direct compiled-oracle batches remain re-executed by #542, including:

- `ClipperOffset::AddPath()` pruning, float caller delta, normals, miter/square/concave raw arithmetic;
- convex positive expansion/erosion and CW-hole sign/orientation semantics;
- orthogonal concave `Execute()` including topology-changing positive results;
- isolated positive V-notch and one-reflex negative `pftNegative` cleanup;
- noninteracting NonZero cross-path result ordering/winding;
- two-positive axis-aligned rectangle union for same-span touch, diagonal area overlap, strict unequal/T edge contacts and point-only contacts (#488);
- two-positive strict-convex proper-crossing union (#493);
- bounded triangle zero-area contact and partial-collinear states through #542.

## Retained compiled Arachne process evidence

The suite retains independent pinned compiled-BambuStudio process fixtures for normal two-wall and one-wall gates, non-speed and speed-graded overhang, partial `Alltop`, through-hole walls, QIDI `LoopNode`, QIDI circle-copy metadata behavior, final Arachne fill boundaries and a narrow-wedge topology case. These remain scoped exact fixture evidence; the represented `process_arachne()` boundary is **`implemented_unverified` as a whole**.

## Still not proven

For the current Clipper1/Arachne priority, independent or complete representation is still missing for:

- wider-convex zero-area/contact/collinear output-list state;
- **fixup-mutated contact joins and fixup-created collinearity after partial joins**;
- mixed proper-crossing + touch/collinear cases;
- interacting positive/negative hole boundaries and deeper/multiple surviving hole hierarchy;
- more than two interacting final-union paths;
- multi-reflex/non-local non-orthogonal per-path cleanup, split/hole-producing non-orthogonal results and broader negative `pftNegative` execution;
- remaining prepared-outline final `unionNonZero()` cases where compatibility fallback can still introduce Clipper2 ordering/rounding differences;
- broader production/pathological `process_arachne()` geometry/config combinations.

Product-wide work also remains for later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft algorithms, complete native G-code behavior, full project/profile persistence and source-enabled formats, scene/editor/Preview, Device/cloud/P2P/account/camera/HMS/firmware, calibration, desktop integration, full UI/localization/accessibility, hardware-in-the-loop behavior, runtime assets and release builds/installers.

## Next validation boundary

1. Derive exact raw-ELF pointer/output-list state for **fixup-mutated contact/partial joins**, then **mixed proper-crossing + touch/collinear** cases. Do not widen beyond triangles until corresponding wider-convex `OutRec` state is independently proved.
2. Extend the final-union oracle matrix to **interacting holes**, then **more than two interacting paths**.
3. Continue generic/per-path Clipper1 execution only with exact source-order/rounding evidence.
4. Expand whole `process_arachne()` differentials after the remaining final-union seams are reduced.

## Completion truth

**Zero top-level parity gates are closed.** Individual source behaviors and exact compiled-oracle fixture scopes may be marked `parity_verified` only for their asserted contract. Broader modules remain incomplete until every required source path, integration boundary and reference test is covered.
