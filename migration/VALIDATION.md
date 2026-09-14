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

GitHub Actions `.github/workflows/flutter-parity.yml` run `34897876786` (#552), job `104156397361`, executed code commit `3be152aa74f3c555423a39d1b2ab36b63f959343` and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **`+832: All tests passed!`**;
- job conclusion — **success**.

The suite re-executes all earlier represented Classic/Arachne/geometry/Boost/Clipper fixtures and adds thirty tests beyond #532: seven equal-bottom point-contact tests, seven decreasing-Y strict-contained tests, eight host-end fixup tests and eight host-start fixup tests.

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

## #539 equal-bottom point-contact oracle

Exact helper: `SourceClipper1TwoConvexEqualBottomContactUnion2`.

Represented contract: exactly two positive strict-convex triangles, exactly one point-only contact, equal maximum-Y/bottom scanline, no proper crossing or nonzero collinear overlap, and no wider-convex extrapolation.

Direct raw ELF probing established:

- Clipper1 keeps the point-touching triangles as two contours;
- each contour preserves its standalone positive-triangle `BuildResult()` start;
- tied-bottom result contour order is exactly the reverse of `AddPath()` / input order.

Executed matrices:

- broad vertex↔vertex / vertex↔edge ties: **21600/21600**;
- shared-bottom and flat-bottom vertex contacts: **9000/9000**;
- sheared nonvertical vertex↔edge contacts: **10800/10800**;
- combined #539 evidence: **41400/41400 exact raw result paths**.

All include all 3×3 cyclic rotations and both input orders. Seven committed regression tests were green in CI #539 (`34895670398`, job `104148897010`) with **809/809** total tests.

## #542 decreasing-Y strict-contained contact oracle

Exact helper: `SourceClipper1TwoConvexDecreasingStrictContainedUnion2`.

Represented contract: exactly two positive strict-convex triangles; both endpoints of the guest edge lie strictly inside one longer host edge; opposite traversal; host edge `dy < 0` including vertical; third vertices lie in opposite open half-planes; wider convex and endpoint-aligned states remain separate.

For host edge `H0→H1`, overlap endpoint `qStart` nearer `H0`, `qEnd` nearer `H1`, host third `H` and guest third `G`, exact raw start is:

- `G.y < qStart.y` → `qEnd`;
- `G.y > qStart.y` → `H`;
- equality → standalone pinned Clipper1 start of the host triangle.

Executed matrices:

- broad translations/slopes/overlap/third-vertex cases: **25200/25200**;
- targeted vertical/equal-Y/slope-boundary cases: **5400/5400**;
- combined #542 evidence: **30600/30600 exact full raw result paths**.

Seven committed regression tests were green in #542 (`34896399166`, job `104151463543`) with **816/816** total tests.

## #549 endpoint-aligned host-end fixup oracle

Exact helper: `SourceClipper1TwoConvexHostEndFixupUnion2`.

Represented source state:

- exactly two positive strict-convex triangles;
- the shorter guest edge reaches the **end** of one longer host edge and its other endpoint lies strictly inside that host edge;
- opposite traversal and otherwise disjoint interiors;
- the shared `hostEnd` lies strictly between the guest and host third vertices, making `guestThird -> hostEnd -> hostThird` collinear;
- `FixupOutPolygon()` removes exactly that shared endpoint;
- the resulting four-point cycle requires no further duplicate/collinear cleanup.

The canonical pinned counterexample is host `(0,100000),(0,0),(100000,50000)` and guest `(0,0),(0,40000),(-80000,-40000)`. Pinned Clipper1 removes `(0,0)` and returns `0,100000 0,40000 -80000,-40000 100000,50000`.

Direct raw ELF matrices matched **145800/145800 exact full result paths** across increasing/decreasing non-horizontal host edges, vertical edges, both horizontal directions, integer shears, all 3×3 cyclic rotations and both polygon input orders.

Exact post-fix `BuildResult()` start:

- non-horizontal host edge → `hostStart`;
- horizontal host edge directed left → `hostStart`;
- horizontal host edge directed right → `guestThird`.

Eight committed regression tests, including exact Arachne routing of the canonical counterexample, were green in CI #549 (`34897377874`, job `104154737632`) with analyzer clean and **824/824** total tests.

## #552 endpoint-aligned host-start fixup oracle

Exact helper: `SourceClipper1TwoConvexHostStartFixupUnion2`, reached through the existing endpoint-fixup gateway in `SourceClipper1TwoConvexHostEndFixupUnion2`.

Represented source state is the independent symmetric case:

- the shorter guest edge reaches the **start** of the longer host edge and its other endpoint lies strictly inside the host edge;
- `hostStart` lies strictly between the host and guest third vertices, so `hostThird -> hostStart -> guestThird` is collinear;
- `FixupOutPolygon()` removes exactly `hostStart`;
- the remaining four-point cycle needs no additional cleanup.

Direct raw ELF matrices matched **145800/145800 exact full result paths** across both non-horizontal Y directions, vertical edges, both horizontal directions, integer shears, all 3×3 cyclic rotations and both input orders.

Exact post-fix start follows the already-proven host-start source-state rule:

- `dy < 0` → interior overlap endpoint;
- `dy > 0` → host third vertex;
- horizontal rightward → interior overlap endpoint;
- horizontal leftward → host third vertex.

Eight committed regression tests were green in CI #552 (`34897876786`, job `104156397361`), which completed with analyzer clean and **832/832** tests passed.

The two endpoint-aligned fixup matrices therefore provide **291600/291600 exact full raw paths combined**. This is evidence only for the one-shared-endpoint-removal class; other `FixupOutPolygon()` mutations remain open.

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

## Retained Clipper1 / compiled Arachne evidence

Earlier direct compiled-oracle batches remain re-executed by #552, including offset input pruning and arithmetic, convex contour/hole offset semantics, orthogonal concave Execute, isolated positive V-notch and one-reflex negative cleanup, noninteracting NonZero ordering/winding, rectangle interactions and the represented convex-contact/final-union subsets above.

The suite also retains independent pinned compiled-BambuStudio process fixtures for normal two-wall and one-wall gates, non-speed and speed-graded overhang, partial `Alltop`, through-hole walls, QIDI `LoopNode`, QIDI circle-copy metadata behavior, final Arachne fill boundaries and a narrow-wedge topology case. These remain scoped fixture evidence; `process_arachne()` is **`implemented_unverified` as a whole**.

## Still not proven

For the current Clipper1/Arachne priority, independent or complete representation is still missing for:

- wider-convex zero-area/contact/collinear output-list state;
- **other non-endpoint fixup-mutated contact/partial joins** such as cleanup after non-endpoint/staggered/full-edge source states;
- mixed proper-crossing + touch/collinear cases;
- interacting positive/negative hole boundaries and deeper/multiple surviving hole hierarchy;
- more than two interacting final-union paths;
- multi-reflex/non-local non-orthogonal per-path cleanup, split/hole-producing non-orthogonal results and broader negative `pftNegative` execution;
- remaining prepared-outline final `unionNonZero()` cases where compatibility fallback can still introduce Clipper2 ordering/rounding differences;
- broader production/pathological `process_arachne()` geometry/config combinations.

Product-wide work also remains for later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft algorithms, complete native G-code behavior, full project/profile persistence and source-enabled formats, scene/editor/Preview, Device/cloud/P2P/account/camera/HMS/firmware, calibration, desktop integration, full UI/localization/accessibility, hardware-in-the-loop behavior, runtime assets and release builds/installers.

## Next validation boundary

1. Derive exact raw-ELF pointer/output-list state for **other non-endpoint fixup-mutated contact/partial joins**, then **mixed proper-crossing + touch/collinear** cases. Do not widen beyond triangles until corresponding wider-convex `OutRec` state is independently proved.
2. Extend the final-union oracle matrix to **interacting holes**, then **more than two interacting paths**.
3. Continue generic/per-path Clipper1 execution only with exact source-order/rounding evidence.
4. Expand whole `process_arachne()` differentials after the remaining final-union seams are reduced.

## Completion truth

**Zero top-level parity gates are closed.** Individual source behaviors and exact compiled-oracle fixture scopes may be marked `parity_verified` only for their asserted contract. Broader modules remain incomplete until every required source path, integration boundary and reference test is covered.
