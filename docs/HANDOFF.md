# Handoff — Qidi Flow strict Flutter/Dart rewrite

This repository is a **strict 1:1 reimplementation** of Qidi Flow 2.07.02.60 Pass28 in Flutter + Dart. The legacy C++/wxWidgets/React application is reference material only and must not remain a runtime backend through FFI, subprocesses, native shared libraries, hidden services, or embedded legacy WebViews.

## Read first

1. [`../migration/PARITY_CONTRACT.md`](../migration/PARITY_CONTRACT.md) — acceptance authority.
2. [`../migration/MIGRATION_STATUS.md`](../migration/MIGRATION_STATUS.md) — subsystem truth and dependency order.
3. [`../migration/TRACEABILITY.md`](../migration/TRACEABILITY.md) — source → Dart → evidence ledger.
4. [`../migration/VALIDATION.md`](../migration/VALIDATION.md) — executed evidence.
5. [`../migration/FUZZY_SKIN_SOURCE_NOTES.md`](../migration/FUZZY_SKIN_SOURCE_NOTES.md) — pinned fuzzy-skin contract.

Do not infer completion from visual similarity, compilation, or common-case tests. Source quirks are part of the contract.

## Current validated checkpoint — 2026-09-14

Latest validated code checkpoint:

- code commit `8824151bec364977cebf7e4af23e8b42f7949ba1` (`test: lock interacting Clipper1 rectangle union oracles`);
- `.github/workflows/flutter-parity.yml` run `34794661683` (#484), job `103825326336`;
- Flutter `3.47.2`;
- Dart `3.13.2`;
- `flutter analyze` → **No issues found!**;
- `flutter test --reporter expanded` → **746/746 passed**;
- job conclusion → **success**.

Recent source-parity checkpoints:

- #390 / `7eb43f3...`: represented per-surface `process_arachne()` tail → loops + Arachne fill boundaries, 681/681;
- #394–#423: exact pinned compiled BambuStudio evidence for ordinary two-wall, top/first-layer one-wall, non-speed/speed overhang, partial `Alltop`, through-hole, QIDI `LoopNode`, circle-metadata copy quirk and final fill boundaries, through 695/695;
- #438 / `e726950...`: narrow-wedge process oracle exposed and closed the Clipper1-vs-Clipper2 pre-wall drift, 699/699;
- #450 / `fdcbbf1...`: literal Clipper1 `AddPath()` / raw closed-path `OffsetPoint()` arithmetic plus exact convex contour/CW-hole per-path semantics, 709/709;
- #463 / `8ac1935...`: exact single-result orthogonal `Execute()` cleanup, including topology-changing narrow-L erosion, 724/724;
- #466 / `af49053...`: exact convex per-path outputs plus conservative noninteracting NonZero union for direct holes/disconnected positive islands, 729/729;
- #471 / `b59840e...`: exact multi-result orthogonal cleanup; one dumbbell erosion splits into the exact pinned left/right contour order, 731/731;
- #474 / `27b3f52...`: exact positive non-orthogonal V-notch union cleanup, 734/734;
- #477 / `e6e4636...`: exact negative V-notch `pftNegative` cleanup, 737/737;
- #481 / `c6cad34...`: nested same-sign NonZero suppression plus pinned `BuildResult()` rebasing/order for positive roots and direct holes, 738/738;
- #484 / `8824151...`: exact interacting two-positive-rectangle union for horizontal/vertical touch and all four diagonal-overlap orientations, including pinned topology-specific result starts, 746/746.

## Independent pinned BambuStudio oracle provenance

The process-level evidence comes from the **actual upstream compiled binary at the exact pinned source SHA**, not from Dart-generated snapshots:

- upstream repository: `bambulab/BambuStudio`;
- source commit: `f2b55a5a83f266cf56e06c7943a81a08bebb7fad`;
- successful upstream GitHub Actions run: `34298498452` (`Build all`);
- Ubuntu 24.04 artifact ID: `10085378329`, `BambuStudio_ubuntu-24.04_V02.08.03.66`;
- downloaded artifact SHA-256: `912517d86774f4705c28a9e649f3fc91f96fe1623bdf070cb5f14f02ba3827f8`;
- extracted AppImage SHA-256: `ad90fda9a4537222a679b5d2ad12712a86652858106dce00f69fac24c3af8b46`;
- CLI version: `02.08.03.66`.

Several stronger fixtures are captured directly from compiled process state or direct calls inside that ELF with debug symbols, rather than inferred from G-code. These include `detect_overhang_degree()`, Arachne `traverse_extrusions()` / `LoopNode`, `add_infill_contour_for_arachne()`, narrow-wedge junctions, Clipper1 `offset()` and `union_()` result polygons. Do not replace these exact fixtures with self-derived Dart snapshots.

## Current represented classic perimeter surface path

The represented `PerimeterGenerator::process_classic()` path is scoped `parity_verified` for the covered fixtures. It composes source `Surface` copy behavior; `BridgeDetector` / `process_no_bridge()`; simplification and island chaining; extra-perimeter accounting; one-wall gates; onion shell / `Alltop` / thin-wall / gap-fill / final fill boundaries; recursive fuzzy/overhang traversal; shared fuzzy RNG; wall sequence; nested island collection shape; and classic QIDI outwall/loop-node producer semantics.

The supplied source `Surface` copy constructor omits QIDI `counter_circle_compensation` and `holes_circle_compensation`; represented classic and Arachne high-level paths preserve that source quirk.

## Arachne wall-generation dependencies — represented functional surface path complete

The represented Arachne chain includes:

- `WallToolPaths` scalar/config state, prepared-outline repair/cleanup, beading strategies and factory composition;
- direct Boost/Voronoi topology → source skeletal graph → bead/transition/rib generation → `generateSegments()` → `generateToolpaths()` → `WallToolPaths::generate()`;
- normal/topmost/first-layer one-wall planning and complete represented `Alltop` first-wall/top/remainder/second-wall recombination;
- region constraints, blocked nearest extrusion ordering, open-before-closed ties and `InnerOuterInner` adjustment;
- fuzzy transformation, variable-width conversion, non-overhang traversal and loop/open packaging;
- non-speed Arachne overhang with width-preserving Clipper-Z splitting and bridge flow/role;
- speed-graded Arachne overhang with source 2mm sampling, signed-distance mapping, 0/10/25/50/75/100 map, 0.25 terraces and `smooth_overhang_level()` quirks;
- Arachne QIDI raw external `LoopNode` producer and global ranges;
- final per-surface walls → ordering → traversal → global loops → `add_infill_contour_for_arachne()` → `fill_surfaces` / `fill_no_overlap`.

### Clipper1 status inside Arachne preparation

Pinned Qidi/Bambu source uses modified Clipper 6.2.9 (`Clipper1`) for the pre-wall offset path. The represented exact subsets now cover:

- float32 caller delta, shortest-edge threshold and literal `AddPath()` pruning;
- double unit normals and half-away-from-zero `Round()`;
- near-collinear, concave-triplet, miter and square raw `OffsetPoint()` arithmetic;
- exact simple-convex positive contour expansion/erosion and exhausted erosion collapse;
- exact convex CW-hole sign/orientation semantics;
- orthogonal concave cleanup, including topology-changing single-result and multi-result positive contours;
- isolated positive non-orthogonal V-notch cleanup and the matching one-reflex negative `pftNegative` cleanup;
- noninteracting NonZero cross-path behavior for direct holes, disconnected positive roots and nested same-sign suppression, including pinned `BuildResult()` starts/order;
- interacting two-positive axis-aligned rectangles for horizontal/vertical touch and all four diagonal-overlap orientations, including pinned scanline/`BuildResult()` start order.

Still **not** general Clipper1 parity: arbitrary interacting polygons/holes, point-only contact, partial unequal edge-contact cases, more than two interacting paths, multi-reflex/non-local non-orthogonal cleanup, orthogonal hole/point-touch ambiguity, deeper/multiple surviving hole hierarchy, and any remaining final prepared-outline union cases not independently covered. Those continue to use the explicit Clipper2 compatibility fallback where necessary.

## Independently verified `process_arachne()` fixture scopes

The exact pinned compiled binary independently verifies the represented Dart result for:

- normal interior two-wall square and Inner→Outer order;
- topmost one wall and first-layer one wall;
- non-speed active overhang support/unsupported split;
- partial `Alltop` recombination;
- square through-hole contour/hole walls;
- speed-graded active overhang before downstream G-code speed policy;
- QIDI Arachne `LoopNode` payload/ranges;
- QIDI circle-compensation metadata reset at the source `Surface` copy boundary;
- final no-wall, one-wall mixed-spacing and two-wall Arachne fill boundaries;
- pathological variable-width narrow wedge;
- orthogonal concave narrow-L expansion/erosion;
- direct Clipper1 multi-result dumbbell, non-orthogonal V-notch and cross-path rectangle-union source dependencies.

These are scoped `parity_verified` fixtures. The represented `process_arachne()` boundary remains **`implemented_unverified` as a whole** until broader production/pathological differential coverage and the remaining general Clipper1 boolean seams are closed.

## First unfinished priority

Continue in source/dependency order:

1. extend the pinned Clipper1 final cross-path boolean coverage beyond the exact two-positive-rectangle subset: partial unequal edge contacts, point contact, arbitrary convex intersections, interacting holes and more than two paths; preserve exact `BuildResult()` order/start and do not substitute merely geometrically equivalent contours;
2. extend per-path Clipper1 `Execute()` coverage beyond the current V-notch/orthogonal subsets: multiple reflex vertices, non-local self-intersections, split/hole-producing non-orthogonal results and more general negative `pftNegative` cleanup;
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

All top-level product gates remain **OPEN**. As an engineering scope estimate, roughly **25–30% of the complete Qidi Flow rewrite is represented and validated enough to count as done, with roughly 70–75% still remaining**. The perimeter/Arachne slice is much further along than the whole product, but the remaining product work is dominated by later slicer/toolpath families, full G-code behavior, project/profile persistence and formats, scene/editor/Preview, Device/cloud/P2P/account/camera/HMS/firmware, calibration, desktop integration, full UI/localization/accessibility and release/runtime assets.

## Working discipline

For each source batch: identify the exact pinned source function and dependencies; port literal behavior; add translated/differential/compiled-oracle tests; confirm `.github/workflows/flutter-parity.yml` on pinned Flutter 3.47.2; never weaken analyzer/tests or widen tolerances just to turn CI green; then update migration ledgers. A scoped passing test never closes a top-level product gate.
