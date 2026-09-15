# Validation record — strict 1:1 rewrite

This file records only work that has actually executed. Acceptance authority remains [`PARITY_CONTRACT.md`](PARITY_CONTRACT.md); a passing subset never closes a top-level application gate.

## Input identity / loss-prevention baseline

- Supplied archive: `QidiFlow-2.07.02.60-Pass28-Device-Reference-Redesign-Clean(1).zip`.
- Archive SHA-256 from the initial audit: `821ed379d65916df32f5d031bd583bc724ce72f4d229447adc61280701e4d57d`.
- Extracted source files inventoried: **8,632**.
- Earlier local runtime-asset audit: **3,657/3,657** copied runtime entries matched source SHA-256; full publication/reverification from GitHub/release inputs is still open.

## Current executed Flutter/Dart checkpoint — 2026-09-15

Pinned toolchain:

- Flutter `3.47.2`;
- Dart `3.13.2`;
- Ubuntu 24.04 hosted runner.

GitHub Actions `.github/workflows/flutter-parity.yml` run `34939897047` (#575), job `104285940280`, executed code commit `a987f4ae1858af1f973d1c72fb3ce17ff93c7f2c` and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **854/854 tests passed**;
- job conclusion — **success**.

The suite re-executes all earlier represented Classic/Arachne/geometry/Boost/Clipper fixtures and adds six regressions beyond #569 for the ordered strict-maximum mixed point-touch state: three exact all-rotation/input-order fixtures, exact Arachne zero-offset routing, and two explicit fallback boundaries.

## Independent pinned BambuStudio oracle provenance

Reference evidence comes from the **actual upstream compiled BambuStudio artifact at the exact pinned source commit**, not from the Dart implementation under test.

- repository: `bambulab/BambuStudio`;
- source commit: `f2b55a5a83f266cf56e06c7943a81a08bebb7fad`;
- successful upstream GitHub Actions run: `34298498452` (`Build all`);
- Ubuntu 24.04 artifact ID/name: `10085378329` / `BambuStudio_ubuntu-24.04_V02.08.03.66`;
- downloaded artifact SHA-256: `912517d86774f4705c28a9e649f3fc91f96fe1623bdf070cb5f14f02ba3827f8`;
- extracted AppImage SHA-256: `ad90fda9a4537222a679b5d2ad12712a86652858106dce00f69fac24c3af8b46`;
- CLI version: `02.08.03.66`.

The artifact was re-used from the previously SHA-verified download for this batch. The debug-symbol ELF exposes the pinned modified Clipper 6.2.9 implementation. The preload probe calls the exact `clipper_union(Paths&, pftNonZero)` template at PIE offset `0x10b54d0` before application startup and dumps raw result paths without normalizing rotation/order.

Pinned source inspection and ELF tracing confirm why geometric equivalence is insufficient: `BuildResult(Paths&)` starts each result at `OutRec::Pts->Prev`; `AddOutPt()`, local-minimum/local-maximum side assignment, `AppendPolygon()`, `JoinPoints()` and `FixupOutPolygon()` can change output-list state and therefore raw path rotation/order.

## #575 ordered strict-maximum mixed point-touch oracle

`SourceClipper1TwoConvexMixedPointUnion2` now represents a second independently proved mixed proper-crossing + point-touch source-event class in addition to the #569 strict-minimum class.

Represented #575 state:

- exactly two positive strict-convex triangles;
- at least one proper boundary crossing;
- exactly one unique vertex↔strict-edge-interior point touch;
- the touching source vertex is the **strict maximum-Y vertex** of its owning triangle, so both adjacent owner vertices have smaller Y;
- the touched edge of the other triangle is **non-horizontal**;
- the third vertex of the touched-edge triangle is strictly earlier in Clipper scanline order than both neighboring owner vertices: `otherThird.y < min(ownerPrevious.y, ownerNext.y)`;
- no second touch and no nonzero collinear overlap;
- wider-convex, side-vertex, horizontal/equal-Y and mixed-collinear states remain outside this proof.

An independently generated raw-ELF matrix matched **72000/72000 exact full raw result paths**:

- **4,000** newly generated base geometries using an independent seed;
- all **3×3 cyclic source rotations**;
- both polygon input/AddPath orders;
- proper-crossing distribution across the base set: 727 with one crossing, 1,869 with two, 982 with three, 422 with four;
- touched-edge directions include vertical, positive-slope and negative-slope states;
- equality includes raw contour count, exact integer coordinates, vertex sequence and `BuildResult()` start with no normalization.

The committed implementation extends the existing helper rather than creating a competing router. The pre-existing Arachne exact router already invokes this helper, so expanding its exact `supports()` predicate automatically routes the new zero-offset states before the generic compatibility fallback.

### Runtime output-list trace

A targeted preload trace over **500** canonical #575 bases hooked touch-time output-list transitions. Results:

- **400** bases had no touch-time local-maximum/append event;
- **100** bases executed touch-time `AddLocalMaxPoly()` together with `AppendPolygon()` at the touching vertex;
- **500/500** still matched the independently predicted raw result start and full path.

This is important limiting evidence: touch-time `AppendPolygon()` is acceptance-relevant but is **not** by itself a failure predicate. The safe class is bounded by the proved scanline ordering above, not by merely suppressing append states.

### Rejected weaker hypotheses

A weaker candidate — strict maximum-Y touching vertex + vertical touched edge + exactly one proper crossing — was tested independently and failed:

- **44712/45000** exact raw paths;
- **288/45000** mismatches, corresponding to 16 failing base geometries across cyclic rotations/input orders.

The broad exploratory matrix likewise retained raw-start failures outside the #575 ordering predicate: strict-maximum and side-vertex source-event classes are not generally safe. Horizontal touched edges and equal-Y owner/touch states remain unrepresented as well. These counterexamples are why the implementation uses the source scanline predicate rather than a broad maximum-vertex/slope heuristic.

Committed regression coverage adds six tests to `test/core/slicer/source_clipper1_two_convex_mixed_point_union_test.dart`: exact vertical, positive-slope and negative-slope ordered strict-max fixtures across all cyclic rotations/input orders; exact Arachne routing; rejection of a horizontal strict-max edge; and rejection when the scanline-order predicate is violated. CI #575 (`34939897047`, job `104285940280`) completed with analyzer clean and **854/854** total tests passed.

## Retained #569 strict-minimum mixed point-touch oracle

The same exact helper retains the first mixed source-event class proved in #569:

- exactly two positive strict-convex triangles;
- at least one proper boundary crossing;
- exactly one unique vertex↔strict-edge-interior point touch;
- touching source vertex is the **strict minimum-Y vertex** of its owning triangle;
- no second touch or nonzero collinear overlap.

The independent #569 matrix remains **39600/39600 exact full raw result paths**: 2,200 independently generated base geometries × all 3×3 cyclic source rotations × both polygon input orders.

### Broad mixed negative evidence retained

The helper was deliberately narrowed only after broader hypotheses failed.

First exploratory matrix against the proper-only rebase rule:

- total: **37,008** raw cases;
- exact raw-start matches: **35,874/37,008**;
- raw-start mismatches: **1,134/37,008**.

A second independently generated matrix testing a simpler geometric guard:

- total: **28,800** raw cases;
- exact matches: **27,450/28,800**;
- raw-start mismatches: **1,350/28,800**.

Earlier runtime tracing established that touch-time `AppendPolygon()` / `OutRec::Pts` lifecycle is acceptance-relevant. The new #575 trace refines that conclusion: append can still be exact under a stronger independently proved scanline ordering, so “append happened” must not become a static reject/accept shortcut.

## #562 full-shared-edge one-point fixup oracle

`SourceClipper1TwoConvexFullSharedEdgeFixupUnion2`, reached through the existing fixup gateway, covers two positive strict-convex triangles that share one complete edge where `FixupOutPolygon()` removes exactly one shared endpoint.

Represented source state:

- exactly two positive strict-convex triangles;
- complete shared edge in opposite traversal;
- no proper crossings or additional touches away from that edge;
- exactly one shared endpoint lies strictly between the two third vertices;
- `FixupOutPolygon()` removes exactly that point;
- the remaining cycle needs no further cleanup;
- wider-convex, multi-point and mixed-crossing states are not implied.

Direct raw-ELF evidence remains **226908/226908 exact raw result paths**:

- ordinary full-edge start survives cleanup: **64800/64800**;
- removed-start classification matrix: **64800/64800**;
- independent removed-start unequal-third-distance matrix: **97200/97200**;
- targeted equal-Y pointer boundaries: **108/108**.

The removed-start branch intentionally preserves the observed input/AddPath-order-sensitive `OutRec::Pts` rule rather than rotating to a canonical contour. Eight committed tests are re-executed by #575.

For strict triangles with one collinear shared interval, represented one-point cleanup geometries now include endpoint-aligned partial overlaps (#549/#552) and complete shared edges (#562). Strict-contained or staggered overlap retains support-line boundary fragments and does not create the same adjacent-third-vertex cleanup. This does **not** prove wider-convex, multi-point or mixed-crossing cleanup state.

## #549 / #552 endpoint-aligned one-point fixup oracles

`SourceClipper1TwoConvexHostEndFixupUnion2` and `SourceClipper1TwoConvexHostStartFixupUnion2` retain their exact endpoint-aligned triangle contracts.

- host-end direct raw ELF matrix: **145800/145800 exact full raw paths**;
- host-start symmetric raw ELF matrix: **145800/145800 exact full raw paths**;
- combined endpoint-aligned one-point cleanup evidence: **291600/291600 exact full raw paths**.

These cover both non-horizontal Y directions, vertical edges, both horizontal directions, integer shears, all 3×3 cyclic source rotations and both input orders. They remain separate from the full-edge #562 state and from wider/multi-point cleanup.

## #539 / #542 newer contact oracles

`SourceClipper1TwoConvexEqualBottomContactUnion2` retains **41400/41400** exact raw result paths for equal-bottom point-only triangle contacts. Each contour keeps its standalone positive-triangle start and tied-bottom contour order is reverse AddPath/input order.

`SourceClipper1TwoConvexDecreasingStrictContainedUnion2` retains **30600/30600** exact full raw result paths for the decreasing-Y strict-contained shared-edge triangle state, including vertical/equal-Y boundaries.

## Retained #532 all non-horizontal staggered partial-collinear oracle

`SourceClipper1TwoConvexNonHorizontalStaggeredUnion2` remains exact for non-horizontal staggered two-triangle contact without post-join fixup:

- positive-slope support lines: **48600/48600**;
- negative-slope support lines: **48600/48600**;
- vertical support lines: **48600/48600**;
- combined #532 evidence: **145800/145800 exact raw result paths**.

Each family covers start/end overlap states, equal-Y ties and equality boundaries, all cyclic rotations and both input orders.

## Retained #525 / #518 / #510 contact evidence

- #525 remaining non-fixup decreasing-Y host-end partial-collinear helper: **23400/23400** exact raw result paths.
- #518 guarded non-horizontal extension: **36000/36000** exact raw paths.
- #510 represented partial-collinear baseline: **4392/4392** exact raw paths after excluding fixup states.
- standalone positive triangle starts: **1100/1100**.
- complete shared-edge triangle starts: **1000/1000**.
- older supported point/full/strict-contained contact predicates: **4600/4600**.
- random wider-convex full-shared-edge audit: **0/40** matches to the old triangle raw-start heuristic, which is why wider-convex contact routing remains explicitly unproven.

## Retained #493 proper-crossing convex evidence

The exact proper-crossing subset remains limited to two positive strictly convex paths with only proper segment intersections: no edge/point touching, collinear overlap or containment-only case. Seven hand-selected plus 32 deterministic random pairs produced **39/39 exact** raw ELF matches including reversed input order and 2/4/6-crossing topologies.

The broad negative mixed audits above explicitly demonstrate that this proper-only raw-start rule must not be extrapolated outside the independently proved #569/#575 mixed event classes.

## Retained Clipper1 / compiled Arachne evidence

Earlier direct compiled-oracle batches remain re-executed by #575, including offset input pruning and arithmetic, convex contour/hole offset semantics, orthogonal concave Execute, isolated positive V-notch and one-reflex negative cleanup, noninteracting NonZero ordering/winding, rectangle interactions and the represented convex-contact/final-union subsets above.

The suite also retains independent pinned compiled-BambuStudio process fixtures for normal two-wall and one-wall gates, non-speed and speed-graded overhang, partial `Alltop`, through-hole walls, QIDI `LoopNode`, QIDI circle-copy metadata behavior, final Arachne fill boundaries and a narrow-wedge topology case. These remain scoped fixture evidence; `process_arachne()` is **`implemented_unverified` as a whole**.

## Still not proven

For the current Clipper1/Arachne priority, independent or complete representation is still missing for:

- remaining **mixed proper-crossing + point-touch/collinear cases**: strict-maximum states outside the #575 scanline predicate, side-vertex touches, horizontal/equal-Y touch ordering and mixed collinear states;
- wider-convex zero-area/contact/collinear and fixup output-list state;
- multi-point or otherwise unrepresented `FixupOutPolygon()` cleanup;
- interacting positive/negative hole boundaries and deeper/multiple surviving hole hierarchy;
- more than two interacting final-union paths;
- multi-reflex/non-local non-orthogonal per-path cleanup, split/hole-producing non-orthogonal results and broader negative `pftNegative` execution;
- remaining prepared-outline final `unionNonZero()` cases where compatibility fallback can still introduce Clipper2 ordering/rounding differences;
- broader production/pathological `process_arachne()` geometry/config combinations.

Product-wide work also remains for later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft algorithms, complete native G-code behavior, full project/profile persistence and source-enabled formats, scene/editor/Preview, Device/cloud/P2P/account/camera/HMS/firmware, calibration, desktop integration, full UI/localization/accessibility, hardware-in-the-loop behavior, runtime assets and release builds/installers.

## Next validation boundary

1. Derive exact raw-ELF scanline/output-list state for remaining **mixed proper-crossing + point-touch/collinear** cases beyond #569/#575: strict-max states outside the ordering guard, side-vertex touches, horizontal/equal-Y ordering, then mixed collinear cases. Do not widen the proper-only or mixed rebase rules without independent proof.
2. Keep wider-convex and multi-point/non-triangle fixup states on explicit compatibility fallback until their `OutRec`/`BuildResult()` behavior is independently proved.
3. Extend the final-union oracle matrix to **interacting holes**, then **more than two interacting paths**.
4. Continue generic/per-path Clipper1 execution only with exact source-order/rounding evidence.
5. Expand whole `process_arachne()` differentials after the remaining final-union seams are reduced.

## Completion truth

**Zero top-level parity gates are closed.** Individual source behaviors and exact compiled-oracle fixture scopes may be marked `parity_verified` only for their asserted contract. Broader modules remain incomplete until every required source path, integration boundary and reference test is covered.
