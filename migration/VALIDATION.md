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

GitHub Actions `.github/workflows/flutter-parity.yml` run `34909811431` (#562), job `104194568959`, executed code commit `8f9b8f0fbdea9c476ad9fd5b46161e5aaf76b5c1` and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **`+840: All tests passed!`**;
- job conclusion — **success**.

The suite re-executes all earlier represented Classic/Arachne/geometry/Boost/Clipper fixtures and adds eight full-shared-edge one-point-fixup regressions beyond #552, including exact Arachne routing and the input/AddPath-order-sensitive raw start when `FixupOutPolygon()` removes the ordinary full-edge `BuildResult()` start.

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

## #562 full-shared-edge one-point fixup oracle

New exact helper: `SourceClipper1TwoConvexFullSharedEdgeFixupUnion2`, reached through the existing fixup gateway in `SourceClipper1TwoConvexHostEndFixupUnion2`.

Represented source state:

- exactly two positive strict-convex triangles;
- they share one complete edge and traverse it in opposite directions;
- there are no proper crossings or additional touches away from that edge;
- exactly one of the two shared endpoints lies strictly between the two third vertices;
- `FixupOutPolygon()` therefore removes exactly that one shared endpoint;
- the remaining three-point cycle has no duplicate or collinear point requiring further cleanup;
- wider-convex, multi-point cleanup and mixed-crossing states are not implied.

The ordinary non-fixup full-edge `BuildResult()` start is the lower-Y shared endpoint, or the greater-X endpoint on an equal-Y/horizontal tie. Two distinct pointer-state branches were independently audited.

### Ordinary start survives cleanup

When the removed shared endpoint is **not** the ordinary full-edge start, the post-fix raw start remains that ordinary start. A randomized direct raw-ELF matrix matched **64800/64800 exact raw result paths** across 3,600 base geometries, all 3×3 cyclic source rotations and both polygon input orders.

### Ordinary start is removed by cleanup

When `FixupOutPolygon()` removes the ordinary full-edge start itself, raw output is genuinely `OutRec::Pts` / input-order sensitive. Define:

- `R` — removed shared endpoint;
- `S` — surviving shared endpoint;
- `E` — third vertex of the source triangle whose directed shared edge ends at `R`;
- `O` — the other triangle's third vertex.

The independently observed exact raw-start rule is:

- horizontal shared edge → `E`;
- if the `E`-owning triangle is the first AddPath/input path: `E.y > S.y` → `S`, otherwise `E`;
- if the `E`-owning triangle is the second AddPath/input path: `E.y >= S.y` → `S`; otherwise, if `O.y < S.y && E.y > O.y` → `S`; otherwise `E`.

This asymmetry is preserved literally by the Dart helper; the contour is not canonicalized.

Executed direct raw-ELF evidence:

- removed-start classification matrix: **64800/64800 exact raw paths**;
- independent removed-start matrix with unequal third-vertex distances from the shared support line: **97200/97200 exact raw paths**;
- targeted equal-Y pointer-state boundaries: **108/108 exact raw paths**;
- combined with the surviving-start branch: **226908/226908 exact raw result paths**.

The broad matrices include all 3×3 cyclic rotations and both input orders. Equality includes raw contour count, exact integer coordinates, vertex sequence and `BuildResult()` start with no normalization.

Eight committed regression tests in `test/core/slicer/source_clipper1_two_convex_full_shared_edge_fixup_union_test.dart` cover non-start removal, sheared and horizontal cases, fixup-gateway delegation, exact Arachne zero-offset routing, input-order-sensitive removed-start output, an equal-Y pointer boundary and ownership of the ordinary non-fixup full-edge state. CI #562 (`34909811431`, job `104194568959`) completed with analyzer clean and **840/840** total tests passed.

For strict triangles with one collinear shared interval, the one-point cleanup geometries now represented are endpoint-aligned partial overlaps (#549/#552) and complete shared edges (#562). In a strict-contained or staggered overlap, a support-line boundary segment remains at the relevant overlap endpoint, so the two off-support-line third edges do not become adjacent there in the same way. This geometric classification does **not** prove wider-convex, multi-point or mixed-crossing cleanup state.

## Post-#562 mixed proper-crossing + point-touch negative audit

The next dependency seam was explored immediately after #562. The test family used positive strict-convex triangles with proper crossings plus a point touch and compared the pinned raw ELF against a candidate that reused the existing proper-crossing boundary reconstruction and its old “successor of rightmost minimum-Y result vertex” rebasing rule.

A **37,008-case** raw matrix showed why that shortcut is unsafe:

- exact raw-start matches: **35874/37008**;
- raw-start mismatches: **1134/37008**;
- the candidate often reconstructed the same geometric cycle, but pinned Clipper1 started the raw path at another `OutPt` position.

No mixed crossing/contact branch was promoted from this audit. The 1,134 counterexamples are retained as the next source-state target: mixed proper-crossing + point-touch/collinear topology needs its own scanline/`OutRec` proof rather than geometric normalization or reuse of the #493 proper-crossing start heuristic.

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

The post-#562 mixed audit above explicitly demonstrates that this proper-only raw-start rule must not be extrapolated to proper-crossing + touch/collinear states.

## Retained Clipper1 / compiled Arachne evidence

Earlier direct compiled-oracle batches remain re-executed by #562, including offset input pruning and arithmetic, convex contour/hole offset semantics, orthogonal concave Execute, isolated positive V-notch and one-reflex negative cleanup, noninteracting NonZero ordering/winding, rectangle interactions and the represented convex-contact/final-union subsets above.

The suite also retains independent pinned compiled-BambuStudio process fixtures for normal two-wall and one-wall gates, non-speed and speed-graded overhang, partial `Alltop`, through-hole walls, QIDI `LoopNode`, QIDI circle-copy metadata behavior, final Arachne fill boundaries and a narrow-wedge topology case. These remain scoped fixture evidence; `process_arachne()` is **`implemented_unverified` as a whole**.

## Still not proven

For the current Clipper1/Arachne priority, independent or complete representation is still missing for:

- wider-convex zero-area/contact/collinear and fixup output-list state;
- multi-point or otherwise unrepresented `FixupOutPolygon()` cleanup;
- **mixed proper-crossing + touch/collinear cases**, including the raw-start state behind the 1,134 post-#562 counterexamples;
- interacting positive/negative hole boundaries and deeper/multiple surviving hole hierarchy;
- more than two interacting final-union paths;
- multi-reflex/non-local non-orthogonal per-path cleanup, split/hole-producing non-orthogonal results and broader negative `pftNegative` execution;
- remaining prepared-outline final `unionNonZero()` cases where compatibility fallback can still introduce Clipper2 ordering/rounding differences;
- broader production/pathological `process_arachne()` geometry/config combinations.

Product-wide work also remains for later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft algorithms, complete native G-code behavior, full project/profile persistence and source-enabled formats, scene/editor/Preview, Device/cloud/P2P/account/camera/HMS/firmware, calibration, desktop integration, full UI/localization/accessibility, hardware-in-the-loop behavior, runtime assets and release builds/installers.

## Next validation boundary

1. Derive exact raw-ELF scanline/output-list state for **mixed proper-crossing + point-touch/collinear** cases, beginning with the 1,134/37,008 raw-start counterexamples. Do not reuse the #493 proper-crossing rebase heuristic without independent proof.
2. Keep wider-convex and multi-point/non-triangle fixup states on explicit compatibility fallback until their `OutRec`/`BuildResult()` behavior is independently proved.
3. Extend the final-union oracle matrix to **interacting holes**, then **more than two interacting paths**.
4. Continue generic/per-path Clipper1 execution only with exact source-order/rounding evidence.
5. Expand whole `process_arachne()` differentials after the remaining final-union seams are reduced.

## Completion truth

**Zero top-level parity gates are closed.** Individual source behaviors and exact compiled-oracle fixture scopes may be marked `parity_verified` only for their asserted contract. Broader modules remain incomplete until every required source path, integration boundary and reference test is covered.
