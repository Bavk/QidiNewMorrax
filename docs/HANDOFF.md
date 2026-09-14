# Handoff — Qidi Flow strict Flutter/Dart rewrite

This repository is a **strict 1:1 reimplementation** of Qidi Flow 2.07.02.60 Pass28 in Flutter + Dart. The legacy C++/wxWidgets/React application is reference material only and must not remain a runtime backend through FFI, subprocesses, native shared libraries, hidden services or embedded legacy WebViews.

## Read first

1. [`../migration/PARITY_CONTRACT.md`](../migration/PARITY_CONTRACT.md) — acceptance authority.
2. [`../migration/MIGRATION_STATUS.md`](../migration/MIGRATION_STATUS.md) — subsystem truth and dependency order.
3. [`../migration/TRACEABILITY.md`](../migration/TRACEABILITY.md) — source → Dart → evidence ledger.
4. [`../migration/VALIDATION.md`](../migration/VALIDATION.md) — executed evidence.
5. [`../migration/FUZZY_SKIN_SOURCE_NOTES.md`](../migration/FUZZY_SKIN_SOURCE_NOTES.md) — pinned fuzzy-skin contract.

Do not infer completion from visual similarity, compilation or common-case tests. Source quirks are part of the contract.

## Current validated checkpoint — 2026-09-14

Latest validated code checkpoint:

- code commit `3f22e86e437e87201282c07d95a103b38b9b7dc7` (`test: lock Clipper1 rectangle contact oracles`);
- `.github/workflows/flutter-parity.yml` run `34828496375` (#488), job `103926026097`;
- Flutter `3.47.2`;
- Dart `3.13.2`;
- `flutter analyze` → **No issues found!**;
- `flutter test --reporter expanded` → **751/751 passed**;
- job conclusion → **success**.

The suite retains all earlier source-parity checkpoints through #484 and adds exact Clipper1 partial-edge and point-contact rectangle union coverage in #488.

## Independent pinned BambuStudio oracle provenance

Process and Clipper1 evidence comes from the **actual upstream compiled binary at the exact pinned source SHA**, not Dart-generated snapshots:

- upstream repository: `bambulab/BambuStudio`;
- source commit: `f2b55a5a83f266cf56e06c7943a81a08bebb7fad`;
- successful upstream GitHub Actions run: `34298498452` (`Build all`);
- Ubuntu 24.04 artifact ID: `10085378329`, `BambuStudio_ubuntu-24.04_V02.08.03.66`;
- downloaded artifact SHA-256: `912517d86774f4705c28a9e649f3fc91f96fe1623bdf070cb5f14f02ba3827f8`;
- extracted AppImage SHA-256: `ad90fda9a4537222a679b5d2ad12712a86652858106dce00f69fac24c3af8b46`;
- CLI version: `02.08.03.66`.

For #488 the same artifact was downloaded and both hashes reverified. Direct calls into the debug-symbol ELF captured `clipper_union(..., pftNonZero)` results for strict unequal edge contacts, endpoint-aligned T contacts and all four point-contact orientations. Reversing the two input rectangles produced the same exact result order/start for the asserted fixtures.

## Current represented perimeter / Arachne path

The represented `PerimeterGenerator::process_classic()` path remains scoped `parity_verified` for covered fixtures. It composes source `Surface` copy behavior, bridge/no-bridge preprocessing, simplification/island chaining, extra-perimeter accounting, one-wall gates, onion shell / `Alltop` / thin-wall / gap-fill / final fill boundaries, recursive fuzzy/overhang traversal, shared fuzzy RNG, wall sequence, nested island shape and QIDI outwall/loop-node producer semantics.

The represented Arachne chain includes `WallToolPaths` numeric/config state and preparation, beading strategies, direct Boost/Voronoi topology → skeletal graph → generated variable-width toolpaths, one-wall and `Alltop` planning, region/extrusion ordering, fuzzy conversion, non-speed and speed-graded overhang traversal, QIDI `LoopNode` production and final `add_infill_contour_for_arachne()` composition.

Independent compiled fixtures cover normal two-wall, topmost/first-layer one-wall, non-speed/speed overhang, partial `Alltop`, through-hole walls, QIDI `LoopNode`, QIDI circle-metadata copy behavior, final fill boundaries and the pathological narrow wedge. The represented `process_arachne()` boundary nevertheless remains **`implemented_unverified` as a whole** until broader production/pathological coverage and remaining general Clipper1 seams are closed.

## Clipper1 status inside Arachne preparation

Pinned Qidi/Bambu source uses modified Clipper 6.2.9. Exact represented subsets now cover:

- float32 caller delta, shortest-edge threshold and literal `AddPath()` pruning;
- double unit normals and half-away-from-zero `Round()`;
- near-collinear, concave-triplet, miter and square raw `OffsetPoint()` arithmetic;
- exact convex positive contour expansion/erosion and exhausted erosion collapse;
- exact convex CW-hole sign/orientation semantics;
- orthogonal concave cleanup, including topology-changing single-result and multi-result positive contours;
- isolated positive non-orthogonal V-notch cleanup and matching one-reflex negative `pftNegative` cleanup;
- noninteracting NonZero cross-path behavior for direct holes, disconnected positive roots and nested same-sign suppression, including pinned `BuildResult()` starts/order;
- interacting two-positive axis-aligned rectangles for same-span horizontal/vertical touch and all four diagonal area-overlap orientations;
- **new:** partial unequal edge contacts, including strict interval overlap and endpoint-aligned T contacts, with pinned scanline/`BuildResult()` starts;
- **new:** point-only rectangle contact, preserving Clipper1's two separate result contours and their exact result order/start.

Still **not** general Clipper1 parity: arbitrary convex intersections, interacting holes, more than two interacting paths, deeper/multiple surviving hole hierarchy, multi-reflex/non-local non-orthogonal cleanup, orthogonal hole/point-touch ambiguity and remaining prepared-outline final-union cases. Those continue to use explicit compatibility fallback where necessary.

## First unfinished priority

Continue in source/dependency order:

1. continue the same Clipper1 final cross-path boolean priority beyond rectangle contacts: derive exact pinned oracles and port **arbitrary convex intersections**, then **interacting holes** and **more than two interacting paths**; preserve exact `BuildResult()` order/start and do not substitute merely geometrically equivalent contours;
2. extend per-path Clipper1 `Execute()` beyond current V-notch/orthogonal subsets: multiple reflex vertices, non-local self-intersections, split/hole-producing non-orthogonal results and more general negative `pftNegative` cleanup;
3. validate remaining prepared-outline final `unionNonZero()` cases so that a later Clipper2 call cannot silently reintroduce source-order/rounding drift after exact pre-offset work;
4. expand whole `process_arachne()` differentials to disconnected islands, small/narrow holes, non-orthogonal concave notches, variable-width/open-line cases and one-wall/overhang/fuzzy combinations;
5. only after broader green evidence consider promoting represented `process_arachne()` as a whole to scoped `parity_verified`;
6. continue separate preprocessing dependencies such as the full QIDI auto circle-compensation geometry producer where still unrepresented;
7. continue later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft toolpaths, then full G-code, persistence/profiles, scene/Preview, Device/cloud, calibration, desktop and UI parity;
8. publish and SHA-verify real runtime assets before any release-complete claim.

## Numeric/source invariants

- slicer coordinates use `SCALING_FACTOR = 0.00001` mm (100000 source units/mm);
- pinned `EPSILON = 1e-4` and `SCALED_EPSILON = 10` source units;
- preserve source integer geometry until the source converts units;
- preserve explicit/implicit `float` boundaries before geometry/config arithmetic;
- preserve source `scaled<T>` truncation, `lrint`, half-away `Round()` and narrowing-cast boundaries;
- keep Boost.Polygon 1.83 operand/bit semantics, including existing `BigInt` boundaries;
- never replace a source oddity with a cleaner algorithm without an independent source oracle.

## Overall product state

All top-level product gates remain **OPEN**. The perimeter/Arachne slice is much further along than the whole product, but major remaining work includes later slicer/toolpath families, full G-code behavior, project/profile persistence and formats, scene/editor/Preview, Device/cloud/P2P/account/camera/HMS/firmware, calibration, desktop integration, full UI/localization/accessibility and release/runtime assets.

## Working discipline

For each source batch: identify the exact pinned source function and dependencies; port literal behavior; add translated/differential/compiled-oracle tests; confirm `.github/workflows/flutter-parity.yml` on pinned Flutter 3.47.2; never weaken analyzer/tests or widen tolerances just to turn CI green; then update migration ledgers. A scoped passing test never closes a top-level product gate.
