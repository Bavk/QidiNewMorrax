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

GitHub Actions `.github/workflows/flutter-parity.yml` run `34911206898` (#569), job `104198867460`, executed code commit `d238cc809cc40f55a29db20c0010188007832414` and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **`+848: All tests passed!`**;
- job conclusion — **success**.

The suite re-executes all earlier represented Classic/Arachne/geometry/Boost/Clipper fixtures and adds eight mixed proper-crossing + point-touch regressions beyond #562, including exact Arachne routing and strict ownership/rejection boundaries.

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

Pinned source inspection and ELF tracing confirm why geometric equivalence is insufficient: `BuildResult(Paths&)` starts each result at `OutRec::Pts->Prev`; `AddOutPt()`, local-minimum side assignment, `AppendPolygon()`, `JoinPoints()` and `FixupOutPolygon()` can change output-list state and therefore raw path rotation/order.

## #569 mixed proper-crossing + strict-minimum point-touch oracle

New exact helper: `SourceClipper1TwoConvexMixedPointUnion2`, routed by `SourceArachneWallToolPathsPrepareExact2` before the proper-only convex helper.

Represented source state:

- exactly two positive strict-convex triangles;
- at least one proper boundary crossing;
- exactly one unique vertex↔strict-edge-interior point touch;
- the touching source vertex is the **strict minimum-Y vertex of its owning triangle**, so both adjacent source vertices have greater Y;
- no second touch and no nonzero collinear overlap;
- wider-convex paths and every other mixed touch/collinear event class remain outside the helper.

For this narrow source-event class, the same modified-Clipper `TopX()` / intersection rounding and final rebase used by the proper-only convex helper is exact. An independently generated direct raw-ELF matrix matched **39600/39600 exact full raw result paths**:

- **2,200** independently generated base geometries;
- all **3×3 cyclic source rotations**;
- both polygon input/AddPath orders;
- equality includes raw contour count, exact integer coordinates, vertex sequence and `BuildResult()` start with no normalization.

Committed regression coverage in `test/core/slicer/source_clipper1_two_convex_mixed_point_union_test.dart` contains eight tests: three exact mixed fixtures with all rotations/orders, exact Arachne zero-offset routing, rejection of a non-minimum touching-vertex counterexample, ownership separation from point-only contact and proper-only crossing helpers, and rejection of wider-convex input. CI #569 (`34911206898`, job `104198867460`) completed with analyzer clean and **848/848** total tests passed.

### Broad mixed negative evidence retained

The #569 helper was deliberately narrowed only after broader hypotheses failed.

First exploratory matrix: positive strict-convex triangles with proper crossings plus a point touch were compared against a candidate that reused the #493 proper-only boundary reconstruction and “successor of rightmost minimum-Y result vertex” rebasing rule:

- total: **37,008** raw cases;
- exact raw-start matches: **35,874/37,008**;
- raw-start mismatches: **1,134/37,008**.

A second independently generated matrix tested a simpler geometric guard and also falsified it:

- total: **28,800** raw cases;
- exact matches: **27,450/28,800**;
- raw-start mismatches: **1,350/28,800**.

Runtime preload tracing hooked the output-list lifecycle around the touch event, including `AddLocalMinPoly`, `AddLocalMaxPoly`, `AppendPolygon` and `AddOutPt`. In the original traced base set:

- **1,993** bases had no touch-time `AppendPolygon()` and produced zero raw-start errors;
- **63** bases performed touch-time `AppendPolygon()` and all 63 were raw-start counterexamples.

In the independently generated traced base set:

- **1,265** no-touch-append bases were exact;
- among **335** touch-time-append bases, **75** changed the raw start and 260 happened to retain it.

This identifies touch-time `AppendPolygon()` / `OutRec::Pts` lifecycle as acceptance-relevant but does **not** establish a static general routing predicate. The remaining mixed seam therefore stays explicit fallback. The next proof must derive source scanline/output-list state, not normalize the geometry or widen the #569 guard heuristically.

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

The removed-start branch intentionally preserves the observed input/AddPath-order-sensitive `OutRec::Pts` rule rather than rotating to a canonical contour. Eight committed tests are re-executed by #569.

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

The broad negative mixed audits above explicitly demonstrate that this proper-only raw-start rule must not be extrapolated outside the #569 independently proved mixed event class.

## Retained Clipper1 / compiled Arachne evidence

Earlier direct compiled-oracle batches remain re-executed by #569, including offset input pruning and arithmetic, convex contour/hole offset semantics, orthogonal concave Execute, isolated positive V-notch and one-reflex negative cleanup, noninteracting NonZero ordering/winding, rectangle interactions and the represented convex-contact/final-union subsets above.

The suite also retains independent pinned compiled-BambuStudio process fixtures for normal two-wall and one-wall gates, non-speed and speed-graded overhang, partial `Alltop`, through-hole walls, QIDI `LoopNode`, QIDI circle-copy metadata behavior, final Arachne fill boundaries and a narrow-wedge topology case. These remain scoped fixture evidence; `process_arachne()` is **`implemented_unverified` as a whole**.

## Still not proven

For the current Clipper1/Arachne priority, independent or complete representation is still missing for:

- remaining **mixed proper-crossing + touch/collinear cases**, especially touch-time `AppendPolygon()` / `OutRec::Pts` states outside the strict-minimum-Y touching-vertex subset;
- wider-convex zero-area/contact/collinear and fixup output-list state;
- multi-point or otherwise unrepresented `FixupOutPolygon()` cleanup;
- interacting positive/negative hole boundaries and deeper/multiple surviving hole hierarchy;
- more than two interacting final-union paths;
- multi-reflex/non-local non-orthogonal per-path cleanup, split/hole-producing non-orthogonal results and broader negative `pftNegative` execution;
- remaining prepared-outline final `unionNonZero()` cases where compatibility fallback can still introduce Clipper2 ordering/rounding differences;
- broader production/pathological `process_arachne()` geometry/config combinations.

Product-wide work also remains for later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft algorithms, complete native G-code behavior, full project/profile persistence and source-enabled formats, scene/editor/Preview, Device/cloud/P2P/account/camera/HMS/firmware, calibration, desktop integration, full UI/localization/accessibility, hardware-in-the-loop behavior, runtime assets and release builds/installers.

## Next validation boundary

1. Derive exact raw-ELF scanline/output-list state for remaining **mixed proper-crossing + point-touch/collinear** cases beyond #569, starting from touch-time `AppendPolygon()` / `OutRec::Pts` counterexamples. Do not widen the proper-only or strict-minimum rebase rules without independent proof.
2. Keep wider-convex and multi-point/non-triangle fixup states on explicit compatibility fallback until their `OutRec`/`BuildResult()` behavior is independently proved.
3. Extend the final-union oracle matrix to **interacting holes**, then **more than two interacting paths**.
4. Continue generic/per-path Clipper1 execution only with exact source-order/rounding evidence.
5. Expand whole `process_arachne()` differentials after the remaining final-union seams are reduced.

## Completion truth

**Zero top-level parity gates are closed.** Individual source behaviors and exact compiled-oracle fixture scopes may be marked `parity_verified` only for their asserted contract. Broader modules remain incomplete until every required source path, integration boundary and reference test is covered.
