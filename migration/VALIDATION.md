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

GitHub Actions `.github/workflows/flutter-parity.yml` run `34848910683` (#510), job `103991577409`, executed code commit `d1731f14121c80af883e78204fdcd6bc3b41116d` and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **`+781: All tests passed!`**;
- job conclusion — **success**.

The suite re-executes all earlier represented Classic/Arachne/geometry/Boost/Clipper fixtures and includes thirteen new regression tests for represented partial-collinear triangle unions and the corrected bounded contact scope.

## Independent pinned BambuStudio oracle provenance

Reference evidence comes from the **actual upstream compiled BambuStudio artifact at the exact pinned source commit**, not from the Dart implementation under test.

- repository: `bambulab/BambuStudio`;
- source commit: `f2b55a5a83f266cf56e06c7943a81a08bebb7fad`;
- successful upstream GitHub Actions run: `34298498452` (`Build all`);
- Ubuntu 24.04 artifact ID/name: `10085378329` / `BambuStudio_ubuntu-24.04_V02.08.03.66`;
- downloaded artifact SHA-256: `912517d86774f4705c28a9e649f3fc91f96fe1623bdf070cb5f14f02ba3827f8`;
- extracted AppImage SHA-256: `ad90fda9a4537222a679b5d2ad12712a86652858106dce00f69fac24c3af8b46`;
- CLI version: `02.08.03.66`.

The exact artifact was downloaded and SHA-verified again for #510. Its debug-symbol ELF exposes the pinned modified Clipper 6.2.9 implementation. The preload probe calls the exact `clipper_union(Paths&, pftNonZero)` template at PIE offset `0x10b54d0` before application startup and dumps raw result paths without normalizing rotation/order. A batch form of the same probe was used for the random matrices below.

Pinned source inspection also confirms why geometric equivalence is insufficient: `BuildResult(Paths&)` starts each result at `OutRec::Pts->Prev`; `AddOutPt()`, local-minimum side assignment, `JoinPoints()` and `FixupOutPolygon()` can change that pointer state and therefore the raw path rotation/order.

## #510 contact-scope correction

The previous contact helper was too broad in its type predicate: it accepted arbitrary strict-convex paths even though the direct fixtures had established only triangle states. The new oracle audit caught the extrapolation before extending it further.

Observed evidence:

- a direct random full-shared-edge **quadrilateral** audit produced **0/40** matches to the previous raw-start heuristic;
- standalone positive **triangle** `BuildResult()` start behavior was derived from pinned edge-list state and matched **1100/1100** raw ELF cases;
- complete shared-edge triangle start behavior matched **1000/1000** random raw cases;
- point-contact probing included broad vertex↔vertex local-minimum-order cases and **999/999** vertex↔edge cases with distinct bottom scanlines;
- the supported point/full/strict-contained triangle source-list/start/order predicates matched **4600/4600** asserted cases including reversed input order.

Commit `bf3610af5327a82e43469d31d4fd825128635c23` therefore narrows `SourceClipper1TwoConvexContactUnion2` to the proven triangle states. It also leaves equal-bottom point-contact ties and the unproven strict-contained decreasing-Y branch on compatibility fallback. Merged contact cycles that would need an additional collinear `FixupOutPolygon()` mutation are rejected rather than assigning an unproven post-fixup raw start.

This is a correctness tightening of the previous #501 scope. It does **not** establish wider-convex contact parity.

## #510 partial-collinear triangle oracle

New Dart helper: `SourceClipper1TwoConvexPartialCollinearUnion2`.

Represented contract:

- exactly two positive strict-convex triangles;
- interiors otherwise disjoint and no proper segment crossing;
- exactly one nonzero collinear boundary interval;
- opposite traversal along the common interval;
- one of these independently probed join states only:
  - endpoint-aligned partial overlap reaching the **start** of the longer host edge, for arbitrary host-edge slope;
  - endpoint-aligned partial overlap reaching the **end** of a **horizontal** host edge;
  - **horizontal staggered** overlap where neither source edge contains the other and the merged output has a unique minimum-Y vertex;
- merged cycles with duplicate/collinear consecutive output points are rejected because pinned `FixupOutPolygon()` would introduce additional pointer-state behavior not yet represented;
- non-horizontal host-end, non-horizontal staggered, mixed crossing/contact and wider-convex states are rejected.

A deterministic/random batch differential compared the derived helper result directly to raw pinned ELF `clipper_union(..., pftNonZero)` output, including reversed input order. After excluding cases outside the represented contract because they require post-join fixup, the matrix matched **4392/4392 exact raw result paths** — same contour count, integer coordinates, vertex sequence and `BuildResult()` start.

Committed regression coverage in `test/core/slicer/source_clipper1_two_convex_partial_collinear_union_test.dart` asserts:

- slanted and descending host-start endpoint overlaps;
- horizontal host-end joins in both directions;
- horizontal staggered joins in both directions;
- Arachne zero-offset exact routing;
- rejection of non-horizontal host-end/staggered and proper-crossing cases;
- exact standalone triangle contact starts/order regression;
- rejection of wider-convex contact state and unsupported decreasing-Y strict-contained contact.

These thirteen tests are included in #510's 781/781 green suite.

## Retained #493 proper-crossing convex evidence

The earlier non-rectangular proper-crossing subset remains independently validated:

- exactly two positive, strictly convex closed paths with only proper segment intersections;
- no edge/point touching, collinear overlap or containment-only case;
- exact pinned scanline `TopX()` / `IntersectPoint()` rounding and exact `BuildResult()` order/start;
- 7 hand-selected cases plus 32 deterministic random pairs;
- **39/39 exact** raw ELF matches, including reversed input order and 2/4/6 crossing topologies.

Committed coverage remains in `test/core/slicer/source_clipper1_two_convex_union_test.dart` and is re-executed by #510.

## Retained Clipper1 evidence

Earlier direct compiled-oracle batches remain re-executed by #510, including:

- `ClipperOffset::AddPath()` pruning, float caller delta, normals, miter/square/concave raw arithmetic;
- convex positive expansion/erosion and CW-hole sign/orientation semantics;
- orthogonal concave `Execute()` including topology-changing positive results;
- isolated positive V-notch and one-reflex negative `pftNegative` cleanup;
- noninteracting NonZero cross-path result ordering/winding;
- two-positive axis-aligned rectangle union for same-span touch, diagonal area overlap, strict unequal/T edge contacts and point-only contacts (#488);
- two-positive strict-convex proper-crossing union (#493);
- bounded triangle zero-area contact states corrected in #510.

## Retained compiled Arachne process evidence

The suite also retains independent pinned compiled-BambuStudio process fixtures for normal two-wall and one-wall gates, non-speed and speed-graded overhang, partial `Alltop`, through-hole walls, QIDI `LoopNode`, QIDI circle-copy metadata behavior, final Arachne fill boundaries and a narrow-wedge topology case. These remain scoped exact fixture evidence; the represented `process_arachne()` boundary is **`implemented_unverified` as a whole**.

## Still not proven

For the current Clipper1/Arachne priority, independent or complete representation is still missing for:

- wider-convex zero-area contact output-list state;
- equal-bottom point-contact ties and fixup-mutated contact joins;
- strict-contained decreasing-Y triangle joins;
- non-horizontal host-end and non-horizontal staggered partial collinear joins;
- mixed proper-crossing + touch/collinear cases;
- interacting positive/negative hole boundaries and deeper/multiple surviving hole hierarchy;
- more than two interacting final-union paths;
- multi-reflex/non-local non-orthogonal per-path cleanup, split/hole-producing non-orthogonal results and broader negative `pftNegative` execution;
- remaining prepared-outline final `unionNonZero()` cases where compatibility fallback can still introduce Clipper2 ordering/rounding differences;
- broader production/pathological `process_arachne()` geometry/config combinations.

Product-wide work also remains for later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft algorithms, complete native G-code behavior, full project/profile persistence and source-enabled formats, scene/editor/Preview, Device/cloud/P2P/account/camera/HMS/firmware, calibration, desktop integration, full UI/localization/accessibility, hardware-in-the-loop behavior, runtime assets and release builds/installers.

## Next validation boundary

1. Derive exact raw-ELF state for **non-horizontal host-end/staggered collinear joins, equal-bottom/fixup contact cases, then mixed proper-crossing + touch/collinear**. Do not widen beyond triangles until the corresponding wider-convex `OutRec` state is independently proved.
2. Extend the final-union oracle matrix to **interacting holes**, then **more than two interacting paths**.
3. Continue generic/per-path Clipper1 execution only with exact source-order/rounding evidence.
4. Expand whole `process_arachne()` differentials after the remaining final-union seams are reduced.

## Completion truth

**Zero top-level parity gates are closed.** Individual source behaviors and exact compiled-oracle fixture scopes may be marked `parity_verified` only for their asserted contract. Broader modules remain incomplete until every required source path, integration boundary and reference test is covered.
