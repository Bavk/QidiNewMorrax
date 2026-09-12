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

- code commit `69780005918e63a58485ebf7caf645214eacc37b` (`feat: port Arachne WallToolPaths preprocessing`);
- `.github/workflows/flutter-parity.yml` run `34698420757` (#278);
- Flutter `3.47.2`;
- Dart `3.13.2`;
- `flutter analyze` → **No issues found!**;
- `flutter test --reporter expanded` → **395/395 passed**;
- job conclusion → **success**.

Important checkpoints leading here:

- `ae218afee234afa92f7ef2967d61db8485a82d5a` / run #260: represented per-island shell → Alltop → gap-fill → final fill boundary, 351/351 green;
- `1b2f5f4aa8274795f88a6088db11fb5a06202186` / run #264: pinned `BridgeDetector` plus translated upstream `t/bridges.t` angle/coverage fixtures, 359/359 green;
- `d9ad4a5564e6ef5fa06a622a626d2091ec432475` / run #268: represented `process_no_bridge()` gates plus `chbBridges` / `chbFilled`, 365/365 green;
- `0a9fa8155e0e860b82177280a379a7b9dccfeeb5` / run #273: source surface preprocessing composed into the per-island fill path, 377/377 green;
- `2a33afd97b4f987a7edf4b482eebf8d34da7f9c0` / run #276: ordered islands composed through classic traversal/fuzzy/overhang/wall-sequence plus represented QIDI loop-node metadata, 387/387 green;
- `6978000...` / run #278: first independently verified `Arachne::WallToolPaths` dependency slice, 395/395 green.

## Current represented classic surface → extrusion path — scoped parity verified

Pinned source: `bambulab/BambuStudio@f2b55a5a83f266cf56e06c7943a81a08bebb7fad`.

The represented `PerimeterGenerator::process_classic()` path now composes, in source order:

- `Surfaces all_surfaces = this->slices->surfaces` with the pinned `Surface` copy semantics;
- `BridgeDetector` plus `process_no_bridge()` for `None`, `Bridges` and `Filled` branches;
- conditional surface simplification resolution, `chain_expolygons()` ordering and per-surface `extra_perimeters` / alternate-extra-wall accounting;
- per-island top-one-wall gates, onion shell, Alltop mutation, thin-wall/gap-fill and final `fill_surfaces` / `fill_no_overlap` boundary;
- each prepared island feeding the already-ported classic loop tree and recursive fuzzy/overhang traversal;
- wall-sequence adjustment **inside each island**, before that island collection is appended to global `loops`;
- one shared fuzzy random stream across ordered islands;
- null versus non-null empty lower-slice semantics;
- nested per-island `ExtrusionEntityCollection` shape and global gap-fill accumulation.

`SourceClassicPerimeterOrderedPipeline2` builds on `SourceClassicPerimeterIslandProcess2` and `SourceClassicFuzzyPerimeterPipeline2` rather than duplicating their algorithms.

### QIDI outwall / loop-node metadata represented in this scope

The classic `z_direction_outwall_speed_continuous` producer is represented for:

- raw thin-wall, smaller-width outer-wall and normal outer-wall `NodeContour` capture;
- source contour-then-holes closed polyline form;
- literal `Point::is_in_lines(const Points&)`, including strict `< SCALED_EPSILON` diagonal distance;
- single-outwall `loop_id = 0` shortcut;
- multiple-outwall matching in post-wall-sequence extrusion order;
- caller-owned global node IDs and per-island `[start,end)` `loop_node_range`;
- node bbox expansion by exact `SCALED_EPSILON = 10` source units.

This is producer-side scope only. Downstream inter-layer relationship/speed-control consumers remain open.

### Important QIDI compensation quirk retained

The supplied source `Surface` copy constructor omits QIDI `counter_circle_compensation` and `holes_circle_compensation`. Therefore `Surfaces all_surfaces = this->slices->surfaces` resets those additions before the later classic lookup. The Dart high-level path preserves this behavior rather than restoring the apparent intended metadata.

## Arachne `WallToolPaths` foundation — scoped parity verified, generator still open

The first source-shaped dependency slice for pinned `PerimeterGenerator::process_arachne()` is now represented in `source_arachne_wall_tool_paths.dart`:

- `SourceArachneWallToolPathsParams2` mirrors source float members and stores `process_arachne()` percentage/nozzle results at an explicit IEEE float32 boundary;
- `SourceArachneWallToolPathsState2` mirrors constructor state before `generate()`, including `fill_outline_gaps == true`, `small_area_length = bead_width_0 / 2`, and source `scaled<coord_t>(float)` behavior;
- pinned `scaled<coord_t>(double)` truncation quirks are frozen by tests: `0.5 → 49999`, `0.025 → 2500`, `2.0 → 199999`, `0.01 → 999`, `0.005 → 499` source units;
- the standalone `WallToolPaths.cpp::simplify(Polygon&, ...)` and its polygon-vector wrapper are ported, including area accumulator, integer-truncated `height_2`, 5-micron near-collinear rule, infinite-line replacement path, and removal of polygons that drop below three points.

Run #278 adds eight direct fixtures for these contracts. This does **not** generate Arachne walls, create a beading strategy, or run `SkeletalTrapezoidation`.

## Fuzzy / Arachne scope retained

The 395-test suite re-runs all previously verified fuzzy evidence: exact `FuzzySkinType` policy; one Classic RNG stream; MT19937/libstdc++ `[0,1)` oracles; pinned libnoise Perlin/Billow/RidgedMulti/Voronoi; Polygon/Polyline fuzzy geometry and painted-region LineSegmentation; source ZAttributes compatibility; source-shaped Arachne `ExtrusionLine`; `Displacement`, `Extrusion`, `Combined` seeded C++ goldens; and region-aware Arachne fuzzy composition.

The fuzzy scope still does not prove the full Arachne wall generator.

## First unfinished priority

Continue pinned `Arachne::WallToolPaths::generate()` immediately after the now-verified constructor/simplifier boundary:

1. port the exact prepared-outline pipeline in source order: triple epsilon offset `-eps → +2eps → -eps`, `simplify`, `fixSelfIntersections`, `removeDegenerateVerts`, `removeColinearEdges(..., 0.005)`, second self-intersection/degenerate pass, `removeSmallAreas(small_area_length², false)`, then `union_`;
2. preserve `outline_size_change` tracking after every source operation and the `area(prepared_outline) <= 0` early return;
3. port the scalar pre-beading calculations: rounded-rectangle extrusion widths, float-backed `wall_transition_length` scaling, split/add-middle thresholds, and int32-limited `max_bead_count`;
4. port `BeadingStrategyFactory` composition in source order (`Distributed → Redistribute → optional Widening → optional OuterWallInset → Limited`; `OuterWallContourStrategy` is disabled by `#if 0` in the pinned source);
5. then follow the real dependency into `SkeletalTrapezoidation` and only after green source/C++ fixtures compose actual `WallToolPaths::generate()` output and `process_arachne()`.

Full Arachne wall generation remains `port_started` until variable-width wall paths and their source ordering are validated end-to-end.

## Numeric/source invariants

- slicer coordinates use `SCALING_FACTOR = 0.00001` mm (100000 source units/mm);
- preserve source integer geometry until the source converts units;
- preserve explicit/implicit `float` boundaries before geometry/config arithmetic;
- preserve source `scaled<T>` truncation, `lrint`, round and cast boundaries rather than normalizing them;
- keep Boost.Polygon 1.83 operand/bit semantics, including existing `BigInt` boundaries;
- keep QIDI/Clipper compatibility quirks frozen by regression tests;
- never replace a source oddity with a cleaner algorithm without an independent source oracle.

## Other major open areas

All top-level gates remain **OPEN**. Major remaining work includes full Arachne wall generation, later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft toolpaths, full G-code state/templates/travel/retract/cooling/multimaterial behavior, project/profile round trips and STEP/source-enabled import formats, scene/editor and Preview parity, Device/cloud/P2P/account/camera/HMS/firmware, calibration, desktop integration, full UI/localization/accessibility, runtime asset publication/verification, and exhaustive reference/differential tests.

## Working discipline

For each source batch: identify exact source functions and dependencies; port literal behavior; add source-oracle/translated/differential tests; confirm `.github/workflows/flutter-parity.yml` on pinned Flutter 3.47.2; do not weaken analyzer/tests; then update migration ledgers and this handoff. A scoped passing test never closes a top-level product gate.
