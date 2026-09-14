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

GitHub Actions `.github/workflows/flutter-parity.yml` run `34883978610` (#532), job `104109901824`, executed code commit `7ad184aa99f19d492765a6fb9afbe540ff9f1a70` and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **`+802: All tests passed!`**;
- job conclusion — **success**.

The suite re-executes all earlier represented Classic/Arachne/geometry/Boost/Clipper fixtures and includes ten new regression tests for all non-horizontal staggered two-triangle states, exact Arachne routing and ownership/rejection boundaries.

## Independent pinned BambuStudio oracle provenance

Reference evidence comes from the **actual upstream compiled BambuStudio artifact at the exact pinned source commit**, not from the Dart implementation under test.

- repository: `bambulab/BambuStudio`;
- source commit: `f2b55a5a83f266cf56e06c7943a81a08bebb7fad`;
- successful upstream GitHub Actions run: `34298498452` (`Build all`);
- Ubuntu 24.04 artifact ID/name: `10085378329` / `BambuStudio_ubuntu-24.04_V02.08.03.66`;
- downloaded artifact SHA-256: `912517d86774f4705c28a9e649f3fc91f96fe1623bdf070cb5f14f02ba3827f8`;
- extracted AppImage SHA-256: `ad90fda9a4537222a679b5d2ad12712a86652858106dce00f69fac24c3af8b46`;
- CLI version: `02.08.03.66`.

The artifact was downloaded again for #532 and its ZIP SHA-256 matched the recorded provenance before probing. The debug-symbol ELF exposes the pinned modified Clipper 6.2.9 implementation. The preload probe calls the exact `clipper_union(Paths&, pftNonZero)` template at PIE offset `0x10b54d0` before application startup and dumps raw result paths without normalizing rotation/order. Batch forms of the same probe were used for the matrices below.

Pinned source inspection and ELF tracing confirm why geometric equivalence is insufficient: `BuildResult(Paths&)` starts each result at `OutRec::Pts->Prev`; `AddOutPt()`, local-minimum side assignment, `AppendPolygon()`, `JoinPoints()` and `FixupOutPolygon()` can change output-list state and therefore raw path rotation/order.

## #532 all non-horizontal staggered partial-collinear oracle

New exact helper: `SourceClipper1TwoConvexNonHorizontalStaggeredUnion2`.

Represented contract:

- exactly two positive strict-convex triangles;
- exactly one nonzero collinear boundary overlap;
- the common support line is non-horizontal (`dy != 0`), including vertical;
- the two source edges traverse the shared interval in opposite directions;
- neither source edge contains the other: this is a staggered overlap, not endpoint-contained contact;
- no proper segment crossing, extra touch outside the common interval or strict interior source vertex;
- the merged boundary is one positive cycle and does not require duplicate/collinear `FixupOutPolygon()` cleanup;
- wider convex polygons remain outside the helper because their raw output-list state has not been independently proved.

The exact source-state start rule canonicalizes to the shared source edge whose `dy > 0`. Let `third` be that triangle's third vertex and `otherThird` the opposite triangle's third vertex:

- if canonical `start` lies strictly inside the opposite source edge, raw `BuildResult()` start = `third`;
- otherwise canonical `end` lies strictly inside the opposite source edge;
- if `third.y < canonicalEnd.y`, start = canonical edge `start`;
- if `third.y > canonicalEnd.y`, start = `otherThird`;
- if `third.y == canonicalEnd.y`, start = opposite edge `end` when `canonicalStart.y < otherThird.y`, otherwise opposite edge `start` (including equality).

Independent raw ELF matrices:

- positive-slope support lines: **48600/48600 exact raw paths**;
- negative-slope support lines: **48600/48600 exact raw paths**;
- vertical support lines: **48600/48600 exact raw paths**;
- combined #532 evidence: **145800/145800 exact raw result paths**.

Each 48,600 family contains:

- **14400** strict end-overlap states;
- **14400** start-overlap states;
- **14400** equal-Y tie states;
- **5400** exact equality-boundary states.

Every matrix includes all 3×3 cyclic rotations of both source triangles and both polygon input orders. Equality is raw contour count, integer coordinates, vertex sequence and `BuildResult()` start with no normalization. Horizontal staggered joins remain owned by the earlier #510 partial-collinear helper.

Committed regression coverage in `test/core/slicer/source_clipper1_two_convex_nonhorizontal_staggered_union_test.dart` contains ten tests covering positive-slope start/end branches, opposite-third start, equal-Y endpoint selection and equality boundary, a previously rejected negative-slope state, exact Arachne routing, horizontal ownership, endpoint-contained rejection and proper-crossing rejection. Exact fixtures exercise 3×3 rotations and both input orders.

This is scoped `parity_verified` evidence only for the contract above. It does **not** prove wider-convex staggered joins, fixup-mutated joins or mixed crossing/contact topologies.

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
- supported point/full/strict-contained triangle source-list/start/order predicates: **4600/4600**;
- represented #510 partial-collinear baseline: **4392/4392 exact raw result paths** after excluding post-join fixup states.

Commit `bf3610af5327a82e43469d31d4fd825128635c23` narrowed `SourceClipper1TwoConvexContactUnion2` to those proven triangle states. Equal-bottom point-contact ties, unsupported strict-contained directions and fixup-mutated contact joins remain fallback.

## Retained #493 proper-crossing convex evidence

The earlier non-rectangular proper-crossing subset remains independently validated:

- exactly two positive, strictly convex closed paths with only proper segment intersections;
- no edge/point touching, collinear overlap or containment-only case;
- exact pinned scanline `TopX()` / `IntersectPoint()` rounding and exact `BuildResult()` order/start;
- 7 hand-selected cases plus 32 deterministic random pairs;
- **39/39 exact** raw ELF matches, including reversed input order and 2/4/6 crossing topologies.

Committed coverage remains in `test/core/slicer/source_clipper1_two_convex_union_test.dart` and is re-executed by #532.

## Retained Clipper1 evidence

Earlier direct compiled-oracle batches remain re-executed by #532, including:

- `ClipperOffset::AddPath()` pruning, float caller delta, normals, miter/square/concave raw arithmetic;
- convex positive expansion/erosion and CW-hole sign/orientation semantics;
- orthogonal concave `Execute()` including topology-changing positive results;
- isolated positive V-notch and one-reflex negative `pftNegative` cleanup;
- noninteracting NonZero cross-path result ordering/winding;
- two-positive axis-aligned rectangle union for same-span touch, diagonal area overlap, strict unequal/T edge contacts and point-only contacts (#488);
- two-positive strict-convex proper-crossing union (#493);
- bounded triangle zero-area contact and partial-collinear states through #525.

## Retained compiled Arachne process evidence

The suite retains independent pinned compiled-BambuStudio process fixtures for normal two-wall and one-wall gates, non-speed and speed-graded overhang, partial `Alltop`, through-hole walls, QIDI `LoopNode`, QIDI circle-copy metadata behavior, final Arachne fill boundaries and a narrow-wedge topology case. These remain scoped exact fixture evidence; the represented `process_arachne()` boundary is **`implemented_unverified` as a whole**.

## Still not proven

For the current Clipper1/Arachne priority, independent or complete representation is still missing for:

- wider-convex zero-area/contact/collinear output-list state;
- equal-bottom point-contact ties;
- strict-contained decreasing-Y triangle contact joins;
- fixup-mutated contact joins and fixup-created collinearity after partial joins;
- mixed proper-crossing + touch/collinear cases;
- interacting positive/negative hole boundaries and deeper/multiple surviving hole hierarchy;
- more than two interacting final-union paths;
- multi-reflex/non-local non-orthogonal per-path cleanup, split/hole-producing non-orthogonal results and broader negative `pftNegative` execution;
- remaining prepared-outline final `unionNonZero()` cases where compatibility fallback can still introduce Clipper2 ordering/rounding differences;
- broader production/pathological `process_arachne()` geometry/config combinations.

Product-wide work also remains for later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft algorithms, complete native G-code behavior, full project/profile persistence and source-enabled formats, scene/editor/Preview, Device/cloud/P2P/account/camera/HMS/firmware, calibration, desktop integration, full UI/localization/accessibility, hardware-in-the-loop behavior, runtime assets and release builds/installers.

## Next validation boundary

1. Derive exact raw-ELF state for **equal-bottom point-contact ties, strict-contained decreasing-Y contact states, fixup-mutated contact/partial joins, then mixed proper-crossing + touch/collinear cases**. Do not widen beyond triangles until the corresponding wider-convex `OutRec` state is independently proved.
2. Extend the final-union oracle matrix to **interacting holes**, then **more than two interacting paths**.
3. Continue generic/per-path Clipper1 execution only with exact source-order/rounding evidence.
4. Expand whole `process_arachne()` differentials after the remaining final-union seams are reduced.

## Completion truth

**Zero top-level parity gates are closed.** Individual source behaviors and exact compiled-oracle fixture scopes may be marked `parity_verified` only for their asserted contract. Broader modules remain incomplete until every required source path, integration boundary and reference test is covered.
