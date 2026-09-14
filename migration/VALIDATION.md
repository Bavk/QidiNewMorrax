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

GitHub Actions `.github/workflows/flutter-parity.yml` run `34844487290` (#501), job `103976992231`, executed code commit `34f3ef832b77057dc026b81f07ff5896fd1bada0` and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **`+768: All tests passed!`**;
- job conclusion — **success**.

The suite re-executes all earlier represented Classic/Arachne/geometry/Boost/Clipper fixtures and includes the new exact Clipper1 strict-convex contact-union tests described below.

## Independent pinned BambuStudio oracle provenance

Reference evidence comes from the **actual upstream compiled BambuStudio artifact at the exact pinned source commit**, not from the Dart implementation under test.

- repository: `bambulab/BambuStudio`;
- source commit: `f2b55a5a83f266cf56e06c7943a81a08bebb7fad`;
- successful upstream GitHub Actions run: `34298498452` (`Build all`);
- Ubuntu 24.04 artifact ID/name: `10085378329` / `BambuStudio_ubuntu-24.04_V02.08.03.66`;
- downloaded artifact SHA-256: `912517d86774f4705c28a9e649f3fc91f96fe1623bdf070cb5f14f02ba3827f8`;
- extracted AppImage SHA-256: `ad90fda9a4537222a679b5d2ad12712a86652858106dce00f69fac24c3af8b46`;
- CLI version: `02.08.03.66`.

The debug-symbol ELF exposes the pinned modified Clipper 6.2.9 implementation. Direct probes call the exact `clipper_union(Paths&, pftNonZero)` path before application startup and dump raw result paths without normalizing rotation/order. The exact template entry remains at PIE offset `0x10b54d0`; the probe exits from a preload constructor before GUI startup.

## #501 Clipper1 two-positive strict-convex contact oracle

The first non-rectangular zero-area contact subset is now independently validated.

Represented contract:

- exactly two positive, strictly convex closed paths;
- interiors are disjoint;
- no proper segment crossing;
- contact is exactly one represented form: a single point, one complete shared edge, or one shorter shared edge whose two endpoints lie strictly inside the other edge;
- single-point contact may be vertex↔vertex or vertex↔edge and remains two positive result contours;
- represented shared-edge contact removes the internal common interval and emits one positive contour;
- result contour count, exact vertex sequence and `BuildResult()` start/order are preserved, not merely equivalent geometry;
- endpoint-aligned/staggered partial shared-edge cases, containment, multiple contact intervals and mixed proper-crossing + touch/collinear cases are rejected to the compatibility seam.

Direct raw ELF evidence executed during this batch includes:

- vertex↔vertex single-point contact;
- vertex↔edge single-point contact;
- complete non-horizontal shared edge;
- strict-contained slanted shared-edge interval;
- strict-contained horizontal shared-edge interval;
- reversed input order checks for the represented cases;
- additional endpoint-aligned, staggered, horizontal/vertical and opposite-scan-direction probes used to delimit the unsupported join-state boundary rather than generalize it without evidence.

Committed regression coverage in `test/core/slicer/source_clipper1_two_convex_contact_union_test.dart` contains eight tests: five exact contact outputs, an Arachne zero-offset route assertion, an endpoint-aligned rejection assertion and a proper-crossing ownership assertion. The first CI attempt (#500) exposed an implementation bug where a bounding-box-only segment predicate could split an adjacent non-collinear edge in the horizontal fixture. Commit `34f3ef832b77057dc026b81f07ff5896fd1bada0` corrected the predicate to require collinearity; #501 then passed all 768 tests and analyzer cleanly.

This establishes scoped `parity_verified` evidence only for the contract above. It does **not** prove general Clipper1 touching/collinear boolean parity.

## Retained #493 proper-crossing convex evidence

The earlier first non-rectangular interacting convex subset remains independently validated:

- exactly two positive, strictly convex closed paths with only proper segment intersections;
- no edge/point touching, collinear overlap or containment-only case;
- exact pinned scanline `TopX()` / `IntersectPoint()` rounding and exact `BuildResult()` order/start;
- 7 hand-selected cases plus 32 deterministic random pairs;
- **39/39 exact** raw ELF matches, including reversed input order and 2/4/6 crossing topologies.

Committed coverage remains in `test/core/slicer/source_clipper1_two_convex_union_test.dart` and is re-executed by #501.

## Retained Clipper1 evidence

Earlier direct compiled-oracle batches remain re-executed by #501, including:

- `ClipperOffset::AddPath()` pruning, float caller delta, normals, miter/square/concave raw arithmetic;
- convex positive expansion/erosion and CW-hole sign/orientation semantics;
- orthogonal concave `Execute()` including topology-changing positive results;
- isolated positive V-notch and one-reflex negative `pftNegative` cleanup;
- noninteracting NonZero cross-path result ordering/winding;
- two-positive axis-aligned rectangle union for same-span touch, diagonal area overlap, strict unequal/T edge contacts and point-only contacts (#488);
- two-positive strict-convex proper-crossing union (#493).

## Retained compiled Arachne process evidence

The suite also retains independent pinned compiled-BambuStudio process fixtures for normal two-wall and one-wall gates, non-speed and speed-graded overhang, partial `Alltop`, through-hole walls, QIDI `LoopNode`, QIDI circle-copy metadata behavior, final Arachne fill boundaries and a narrow-wedge topology case. These remain scoped exact fixture evidence; the represented `process_arachne()` boundary is **`implemented_unverified` as a whole**.

## Still not proven

For the current Clipper1/Arachne priority, independent or complete representation is still missing for:

- endpoint-aligned/staggered non-rectangular partial collinear joins and mixed proper-crossing + touch/collinear cases;
- interacting positive/negative hole boundaries and deeper/multiple surviving hole hierarchy;
- more than two interacting final-union paths;
- multi-reflex/non-local non-orthogonal per-path cleanup, split/hole-producing non-orthogonal results and broader negative `pftNegative` execution;
- remaining prepared-outline final `unionNonZero()` cases where compatibility fallback can still introduce Clipper2 ordering/rounding differences;
- broader production/pathological `process_arachne()` geometry/config combinations.

Product-wide work also remains for later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft algorithms, complete native G-code behavior, full project/profile persistence and source-enabled formats, scene/editor/Preview, Device/cloud/P2P/account/camera/HMS/firmware, calibration, desktop integration, full UI/localization/accessibility, hardware-in-the-loop behavior, runtime assets and release builds/installers.

## Next validation boundary

1. Derive direct pinned ELF oracles for **endpoint-aligned/staggered non-rectangular partial collinear joins and mixed crossing/contact cases**, then port only the proven exact subset.
2. Extend the final-union oracle matrix to **interacting holes**, then **more than two interacting paths**.
3. Continue generic/per-path Clipper1 execution only with exact source-order/rounding evidence.
4. Expand whole `process_arachne()` differentials after the remaining final-union seams are reduced.

## Completion truth

**Zero top-level parity gates are closed.** Individual source behaviors and exact compiled-oracle fixture scopes may be marked `parity_verified` only for their asserted contract. Broader modules remain incomplete until every required source path, integration boundary and reference test is covered.
