# Handoff — Qidi Flow strict Flutter/Dart rewrite

This repository is a **strict 1:1 reimplementation** of Qidi Flow 2.07.02.60 Pass28 in Flutter + Dart. The legacy C++/wxWidgets/React application is reference material only and must not remain a runtime backend through FFI, subprocesses, native shared libraries, hidden services, or embedded legacy WebViews.

## Read first

1. [`../migration/PARITY_CONTRACT.md`](../migration/PARITY_CONTRACT.md) — acceptance authority.
2. [`../migration/MIGRATION_STATUS.md`](../migration/MIGRATION_STATUS.md) — subsystem truth and dependency order.
3. [`../migration/TRACEABILITY.md`](../migration/TRACEABILITY.md) — source → Dart → evidence ledger.
4. [`../migration/VALIDATION.md`](../migration/VALIDATION.md) — executed evidence.
5. [`../migration/FUZZY_SKIN_SOURCE_NOTES.md`](../migration/FUZZY_SKIN_SOURCE_NOTES.md) — pinned fuzzy-skin contract.

Do not infer completion from visual similarity, compilation, or common-case tests. Source quirks are part of the contract.

## Current validated checkpoint — 2026-09-12

Latest validated code checkpoint:

- code commit `10f642e0d3952b61eefe4c8bdda2fcd909a4eba2` (`feat: compose Arachne skeletal toolpath runtime`);
- `.github/workflows/flutter-parity.yml` run `34714922159` (#317);
- Flutter `3.47.2`;
- Dart `3.13.2`;
- `flutter analyze` → **No issues found!**;
- `flutter test --reporter expanded` → **551/551 passed**;
- job conclusion → **success**.

Important checkpoints leading here:

- `2a33afd...` / run #276: ordered classic islands through fuzzy/overhang/wall-sequence plus QIDI loop-node metadata, 387/387 green;
- `6978000...` / run #278: first `Arachne::WallToolPaths` constructor/simplifier slice, 395/395 green;
- `f211b19...` / run #308: `generateSegments()` foundation (upward sort + node beading/interpolate), 521/521 green;
- `34eaac7...` / run #311: beading propagation with exact `scaled(0.1)` and shared-object mutation semantics, green;
- `9b61d75...` / run #313: extrusion-junction generation with literal `scaled(0.005) == 499`, green;
- `3d8bf3c...` / run #314: junction connection / toolpath stitching, green;
- `09c6249...` / run #315: local-maximum six-point single beads, green;
- `0ede85b...` / run #316: all seven `generateSegments()` stages composed in source order, green;
- `10f642e...` / run #317: post-construction `generateToolpaths()` runtime composed in source order, 551/551 green.

## Current represented classic surface → extrusion path — scoped parity verified

Pinned source: `bambulab/BambuStudio@f2b55a5a83f266cf56e06c7943a81a08bebb7fad`.

The represented `PerimeterGenerator::process_classic()` path composes, in source order:

- `Surfaces all_surfaces = this->slices->surfaces` with pinned `Surface` copy semantics;
- `BridgeDetector` plus `process_no_bridge()` for `None`, `Bridges` and `Filled` branches;
- conditional surface simplification resolution, `chain_expolygons()` ordering and per-surface `extra_perimeters` / alternate-extra-wall accounting;
- per-island top-one-wall gates, onion shell, Alltop mutation, thin-wall/gap-fill and final `fill_surfaces` / `fill_no_overlap` boundary;
- each prepared island feeding the classic loop tree and recursive fuzzy/overhang traversal;
- wall-sequence adjustment inside each island before global `loops` append;
- one shared fuzzy random stream across ordered islands;
- null versus non-null empty lower-slice semantics;
- nested per-island `ExtrusionEntityCollection` shape and global gap-fill accumulation.

### QIDI outwall / loop-node metadata represented in this scope

The classic `z_direction_outwall_speed_continuous` producer is represented for raw thin/smaller/normal outer-wall `NodeContour` capture, literal `Point::is_in_lines`, single/multiple outwall matching, global node IDs and per-island `loop_node_range`. Downstream inter-layer relationship/speed-control consumers remain open.

### Important QIDI compensation quirk retained

The supplied source `Surface` copy constructor omits QIDI `counter_circle_compensation` and `holes_circle_compensation`. Therefore `Surfaces all_surfaces = this->slices->surfaces` resets those additions before the later classic lookup. The Dart high-level path preserves this behavior.

## Arachne wall-generation dependencies — runtime after graph construction scoped parity verified

The Arachne dependency chain has advanced substantially beyond the old constructor-only checkpoint:

- `WallToolPaths` numeric/config state and standalone simplifier retain source float/double/truncation quirks;
- the represented prepared-outline repair chain and scalar pre-beading inputs have direct fixtures;
- `BeadingStrategy` implementations and `BeadingStrategyFactory` composition are represented and green;
- the source-shaped skeletal half-edge model, pointy-end separation, graph mutations and `collapseSmallEdges()` are represented;
- post-construction `SkeletalTrapezoidation::generateToolpaths()` is composed in exact source order:
  `updateIsCentral → filterCentral → optional filterOuterCentral → updateBeadCount → filterNoncentralRegions → generateTransitioningRibs → generateExtraRibs → generateSegments`;
- `generateTransitioningRibs()` composes its four source stages;
- `generateSegments()` composes all seven represented stages: upward-edge ordering, node beadings/interpolation, upward propagation, downward propagation, junction generation, junction connection, and local-max single beads;
- source numeric seams are frozen, including `scaled(0.005) == 499`, `scaled(0.010) == 999`, strict/inclusive comparisons, float32 ratios, integer normal/interpolation casts and shared `BeadingPropagation` identity mutation.

This is **not** full Arachne wall-generation parity. The validated runtime starts with an already constructed skeletal graph. The still-open source seam is `SkeletalTrapezoidation::constructFromPolygons()` — real polygon segments → Boost Voronoi cells/edges → discretized Arachne half-edge graph — followed by end-to-end `WallToolPaths::generate()` / `PerimeterGenerator::process_arachne()` integration.

## Fuzzy / Arachne scope retained

The 551-test suite re-runs all previously verified fuzzy evidence: exact `FuzzySkinType` policy; one Classic RNG stream; MT19937/libstdc++ `[0,1)` oracles; pinned libnoise Perlin/Billow/RidgedMulti/Voronoi; Polygon/Polyline fuzzy geometry and painted-region LineSegmentation; source ZAttributes compatibility; source-shaped Arachne `ExtrusionLine`; `Displacement`, `Extrusion`, `Combined` seeded C++ goldens; and region-aware Arachne fuzzy composition.

## First unfinished priority

Continue pinned `SkeletalTrapezoidation::constructFromPolygons()` at the real Voronoi-to-half-edge boundary:

1. bind the existing direct Boost/Voronoi Dart topology to source-shaped polygon-segment indices used by Arachne;
2. port `computePointCellRange()` exactly, including infinite-cell rejection, int64 range checks, `isInsideCorner`, and source edge rotation;
3. port `discretize()` in source branches: straight/secondary, point-line parabola, then point-point with float marking-bound and forced-even step count;
4. port identity maps and `makeNode()` / `transferEdge()`, preserving the two branches for already-transferred twins versus first-side discretization and exact `makeRib()` insertion points;
5. compose `constructFromPolygons()` through `separatePointyQuadEndNodes()`, `collapseSmallEdges()` and incident-edge normalization; add independent simple-polygon topology/toolpath goldens;
6. only after polygon → Voronoi → graph → `generateToolpaths()` is green, compose actual `WallToolPaths::generate()` and then `process_arachne()`.

Full Arachne wall generation remains `port_started` until that end-to-end path is validated.

## Numeric/source invariants

- slicer coordinates use `SCALING_FACTOR = 0.00001` mm (100000 source units/mm);
- preserve source integer geometry until the source converts units;
- preserve explicit/implicit `float` boundaries before geometry/config arithmetic;
- preserve source `scaled<T>` truncation, `lrint`, round and cast boundaries rather than normalizing them;
- keep Boost.Polygon 1.83 operand/bit semantics, including existing `BigInt` boundaries;
- keep QIDI/Clipper compatibility quirks frozen by regression tests;
- never replace a source oddity with a cleaner algorithm without an independent source oracle.

## Other major open areas

All top-level gates remain **OPEN**. Major remaining work includes full Arachne wall generation and process integration, later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft toolpaths, full G-code state/templates/travel/retract/cooling/multimaterial behavior, project/profile round trips and STEP/source-enabled import formats, scene/editor and Preview parity, Device/cloud/P2P/account/camera/HMS/firmware, calibration, desktop integration, full UI/localization/accessibility, runtime asset publication/verification, and exhaustive reference/differential tests.

## Working discipline

For each source batch: identify exact source functions and dependencies; port literal behavior; add source-oracle/translated/differential tests; confirm `.github/workflows/flutter-parity.yml` on pinned Flutter 3.47.2; do not weaken analyzer/tests; then update migration ledgers and this handoff. A scoped passing test never closes a top-level product gate.
