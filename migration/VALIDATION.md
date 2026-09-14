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

GitHub Actions `.github/workflows/flutter-parity.yml` run `34839681185` (#493), job `103961480006`, executed code commit `d718ff276028ee525739475d0858f4e43c9673dc` and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **`+760: All tests passed!`**;
- job conclusion — **success**.

The suite re-executes all earlier represented Classic/Arachne/geometry/Boost/Clipper fixtures and includes the new exact Clipper1 proper-convex final-union tests described below.

## Independent pinned BambuStudio oracle provenance

Reference evidence comes from the **actual upstream compiled BambuStudio artifact at the exact pinned source commit**, not from the Dart implementation under test.

- repository: `bambulab/BambuStudio`;
- source commit: `f2b55a5a83f266cf56e06c7943a81a08bebb7fad`;
- successful upstream GitHub Actions run: `34298498452` (`Build all`);
- Ubuntu 24.04 artifact ID/name: `10085378329` / `BambuStudio_ubuntu-24.04_V02.08.03.66`;
- downloaded artifact SHA-256: `912517d86774f4705c28a9e649f3fc91f96fe1623bdf070cb5f14f02ba3827f8`;
- extracted AppImage SHA-256: `ad90fda9a4537222a679b5d2ad12712a86652858106dce00f69fac24c3af8b46`;
- CLI version: `02.08.03.66`.

The debug-symbol ELF exposes the pinned modified Clipper 6.2.9 implementation. Direct probes call the exact `clipper_union(Paths&, pftNonZero)` path before application startup and dump raw result paths without normalizing rotation/order.

## #493 Clipper1 two-positive strict-convex proper-crossing oracle

The first non-rectangular interacting convex subset is now independently validated.

Represented contract:

- exactly two positive, strictly convex closed paths;
- boundaries cross only through proper segment intersections;
- no edge/point touching or collinear overlap;
- no containment-only case;
- no duplicate/endpoint rounded intersection degeneracy;
- output is one positive contour;
- intersection coordinates use the pinned Clipper scanline `TopX()` / `IntersectPoint()` double arithmetic and half-away-from-zero `Round()`;
- result vertex order/start preserves the observed pinned `FixupOutPolygon()` / `BuildResult()` behavior, not merely equivalent geometry.

Direct ELF evidence executed during this batch:

- 7 hand-selected cases: two- and six-crossing triangles, diamond pair, four-crossing trapezoids, pentagon/quadrilateral, thin slanted quadrilaterals and a mixed five-sided six-crossing case;
- 32 deterministic random strict-convex pairs with 2 or 4 proper crossings;
- reversed input order checked against the same exact result;
- **39/39 exact matches** between the derived Dart algorithm and raw pinned ELF result paths, including every integer coordinate and output start/order.

Committed regression coverage in `test/core/slicer/source_clipper1_two_convex_union_test.dart` asserts representative 2/4/6-crossing outputs, source rounding, non-horizontal `BuildResult()` start, Arachne exact routing, and rejection of touching/containment cases. These tests are included in #493's 760/760 green suite.

This establishes scoped `parity_verified` evidence only for the contract above. It does **not** prove general Clipper1 boolean parity.

## Retained Clipper1 evidence

Earlier direct compiled-oracle batches remain re-executed by #493, including:

- `ClipperOffset::AddPath()` pruning, float caller delta, normals, miter/square/concave raw arithmetic;
- convex positive expansion/erosion and CW-hole sign/orientation semantics;
- orthogonal concave `Execute()` including topology-changing positive results;
- isolated positive V-notch and one-reflex negative `pftNegative` cleanup;
- noninteracting NonZero cross-path result ordering/winding;
- two-positive axis-aligned rectangle union for same-span touch, diagonal area overlap, strict unequal/T edge contacts and point-only contacts (#488).

## Retained compiled Arachne process evidence

The suite also retains independent pinned compiled-BambuStudio process fixtures for normal two-wall and one-wall gates, non-speed and speed-graded overhang, partial `Alltop`, through-hole walls, QIDI `LoopNode`, QIDI circle-copy metadata behavior, final Arachne fill boundaries and a narrow-wedge topology case. These remain scoped exact fixture evidence; the represented `process_arachne()` boundary is **`implemented_unverified` as a whole**.

## Still not proven

For the current Clipper1/Arachne priority, independent or complete representation is still missing for:

- non-rectangular convex edge/point touching and collinear overlap outside the rectangle helper;
- interacting positive/negative hole boundaries and deeper/multiple surviving hole hierarchy;
- more than two interacting final-union paths;
- multi-reflex/non-local non-orthogonal per-path cleanup, split/hole-producing non-orthogonal results and broader negative `pftNegative` execution;
- remaining prepared-outline final `unionNonZero()` cases where compatibility fallback can still introduce Clipper2 ordering/rounding differences;
- broader production/pathological `process_arachne()` geometry/config combinations.

Product-wide work also remains for later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft algorithms, complete native G-code behavior, full project/profile persistence and source-enabled formats, scene/editor/Preview, Device/cloud/P2P/account/camera/HMS/firmware, calibration, desktop integration, full UI/localization/accessibility, hardware-in-the-loop behavior, runtime assets and release builds/installers.

## Next validation boundary

1. Derive direct pinned ELF oracles for **non-rectangular convex edge/point touching and collinear overlap**, then port only the proven exact subset.
2. Extend the final-union oracle matrix to **interacting holes**, then **more than two interacting paths**.
3. Continue generic/per-path Clipper1 execution only with exact source-order/rounding evidence.
4. Expand whole `process_arachne()` differentials after the remaining final-union seams are reduced.

## Completion truth

**Zero top-level parity gates are closed.** Individual source behaviors and exact compiled-oracle fixture scopes may be marked `parity_verified` only for their asserted contract. Broader modules remain incomplete until every required source path, integration boundary and reference test is covered.
