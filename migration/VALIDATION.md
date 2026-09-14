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

GitHub Actions `.github/workflows/flutter-parity.yml` run `34853812738` (#518), job `104008105596`, executed code commit `fc088335516dcf63522260184b83d1791f696606` and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **`+786: All tests passed!`**;
- job conclusion — **success**.

The suite re-executes all earlier represented Classic/Arachne/geometry/Boost/Clipper fixtures and includes five tests beyond #510 for the newly represented non-horizontal partial-collinear triangle states and their rejection boundaries.

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

## #518 non-horizontal partial-collinear extension

The first unfinished #510 priority was the non-horizontal host-end/staggered triangle seam. Broad exploratory probing deliberately preceded implementation. It showed that simple edge-slope or sign-only rules are not invariant under cyclic source-list rotation: geometrically similar joins can carry different raw `OutRec::Pts` state. The production helper therefore represents only source-state predicates that were independently differential-tested.

New represented contract in `SourceClipper1TwoConvexPartialCollinearUnion2`:

- inputs remain exactly two positive strict-convex triangles with one partial collinear boundary interval, disjoint interiors otherwise, opposite traversal along the common interval and no proper segment crossing;
- existing #510 host-start and horizontal states remain unchanged;
- **non-horizontal host-end, host edge `dy > 0`:** exact raw start is the host edge start for the represented non-fixup state;
- **non-horizontal host-end, host edge `dy < 0`:** represented only when the guest triangle's standalone Clipper1 `BuildResult()` start is the shared host endpoint; exact merged start is that endpoint;
- **non-horizontal staggered:** represented only for the negative-slope state where the source overlap edge directed down-left starts at that triangle's standalone Clipper1 result start; exact merged start is that source edge start;
- merged cycles needing duplicate/collinear cleanup by `FixupOutPolygon()` remain rejected;
- other decreasing-Y host-end states, positive-slope/other staggered states, mixed crossing/contact and wider-convex states remain compatibility fallback.

Independent raw ELF matrices:

- increasing-Y non-horizontal host-end states: **12000/12000 exact raw result paths**;
- guarded decreasing-Y non-horizontal host-end states: **12000/12000 exact**;
- guarded negative-slope non-horizontal staggered states: **12000/12000 exact**;
- total new #518 evidence: **36000/36000 exact raw paths**.

These matrices varied translations, overlap ratios, third-vertex placement, cyclic triangle vertex rotations and both polygon input orders. Equality was raw: contour count, integer coordinates, vertex sequence and `BuildResult()` start, with no post-normalization.

Committed regression coverage in `test/core/slicer/source_clipper1_two_convex_partial_collinear_union_test.dart` now includes eighteen tests. New assertions cover increasing-Y host-end, guarded decreasing-Y host-end, negative-slope non-horizontal staggered output, Arachne exact routing and rejection of a neighboring decreasing-Y state whose guest standalone start does not satisfy the pinned predicate. They are included in #518's 786/786 green suite.

This establishes scoped `parity_verified` evidence only for the source-state predicates above. It does **not** establish generic non-horizontal collinear parity.

## Retained #510 contact-scope correction

The earlier contact helper was too broad in its type predicate: it accepted arbitrary strict-convex paths even though the direct fixtures had established only triangle states. The #510 oracle audit caught the extrapolation before extending it further.

Observed evidence retained by #518:

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

Committed coverage remains in `test/core/slicer/source_clipper1_two_convex_union_test.dart` and is re-executed by #518.

## Retained Clipper1 evidence

Earlier direct compiled-oracle batches remain re-executed by #518, including:

- `ClipperOffset::AddPath()` pruning, float caller delta, normals, miter/square/concave raw arithmetic;
- convex positive expansion/erosion and CW-hole sign/orientation semantics;
- orthogonal concave `Execute()` including topology-changing positive results;
- isolated positive V-notch and one-reflex negative `pftNegative` cleanup;
- noninteracting NonZero cross-path result ordering/winding;
- two-positive axis-aligned rectangle union for same-span touch, diagonal area overlap, strict unequal/T edge contacts and point-only contacts (#488);
- two-positive strict-convex proper-crossing union (#493);
- bounded triangle zero-area contact states and initial partial-collinear states (#510).

## Retained compiled Arachne process evidence

The suite retains independent pinned compiled-BambuStudio process fixtures for normal two-wall and one-wall gates, non-speed and speed-graded overhang, partial `Alltop`, through-hole walls, QIDI `LoopNode`, QIDI circle-copy metadata behavior, final Arachne fill boundaries and a narrow-wedge topology case. These remain scoped exact fixture evidence; the represented `process_arachne()` boundary is **`implemented_unverified` as a whole**.

## Still not proven

For the current Clipper1/Arachne priority, independent or complete representation is still missing for:

- wider-convex zero-area contact output-list state;
- equal-bottom point-contact ties and fixup-mutated contact joins;
- strict-contained decreasing-Y triangle contact joins;
- remaining decreasing-Y non-horizontal host-end partial joins whose guest standalone start does not satisfy the represented predicate;
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

1. Derive exact raw-ELF state for **remaining decreasing-Y host-end starts, positive-slope/other non-horizontal staggered joins, equal-bottom/fixup contact cases, then mixed proper-crossing + touch/collinear**. Do not widen beyond triangles until the corresponding wider-convex `OutRec` state is independently proved.
2. Extend the final-union oracle matrix to **interacting holes**, then **more than two interacting paths**.
3. Continue generic/per-path Clipper1 execution only with exact source-order/rounding evidence.
4. Expand whole `process_arachne()` differentials after the remaining final-union seams are reduced.

## Completion truth

**Zero top-level parity gates are closed.** Individual source behaviors and exact compiled-oracle fixture scopes may be marked `parity_verified` only for their asserted contract. Broader modules remain incomplete until every required source path, integration boundary and reference test is covered.
