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

- code commit `2a33afd97b4f987a7edf4b482eebf8d34da7f9c0` (`chore: keep ordered pipeline analyze clean`);
- feature commit `92d27b6ac300f1ce07207caf5100b9568eed3ce3` (`feat: compose ordered classic extrusion pipeline`);
- `.github/workflows/flutter-parity.yml` run `34697866558` (#276);
- Flutter `3.47.2`;
- Dart `3.13.2`;
- `flutter analyze` → **No issues found!**;
- `flutter test --reporter expanded` → **387/387 passed**;
- job conclusion → **success**.

Important checkpoints leading here:

- `ae218afee234afa92f7ef2967d61db8485a82d5a` / run #260: represented per-island shell → Alltop → gap-fill → final fill boundary, 351/351 green;
- `1b2f5f4aa8274795f88a6088db11fb5a06202186` / run #264: pinned `BridgeDetector` plus translated upstream `t/bridges.t` angle/coverage fixtures, 359/359 green;
- `d9ad4a5564e6ef5fa06a622a626d2091ec432475` / run #268: represented `process_no_bridge()` gates plus `chbBridges` / `chbFilled`, 365/365 green;
- `0a9fa8155e0e860b82177280a379a7b9dccfeeb5` / run #273: source surface preprocessing composed into the per-island fill path, 377/377 green;
- `2a33afd...` / run #276: ordered islands composed through classic traversal/fuzzy/overhang/wall-sequence plus represented QIDI loop-node metadata, 387/387 green.

## Current represented classic surface → extrusion path — scoped parity verified

Pinned source: `bambulab/BambuStudio@f2b55a5a83f266cf56e06c7943a81a08bebb7fad`.

The represented `PerimeterGenerator::process_classic()` path now composes, in source order:

- `Surfaces all_surfaces = this->slices->surfaces` with the pinned `Surface` copy semantics;
- `BridgeDetector` plus `process_no_bridge()` for `None`, `Bridges` and `Filled` branches;
- conditional surface simplification resolution, `chain_expolygons()` ordering and per-surface `extra_perimeters` / alternate-extra-wall accounting;
- per-island top-one-wall gates, onion shell, Alltop mutation, thin-wall/gap-fill and final `fill_surfaces` / `fill_no_overlap` boundary;
- each prepared island feeding the already-ported classic loop tree and recursive fuzzy/overhang traversal;
- wall-sequence adjustment **inside each island**, at the same source boundary before that island collection is appended to global `loops`;
- one shared fuzzy random stream across the ordered islands rather than reseeding/restarting per island;
- raw lower-slice conversion once for the ordered traversal path, preserving null versus non-null empty lower input semantics;
- source nested collection shape: each non-empty island is appended to the outer loop collection as one `ExtrusionEntityCollection`, not flattened globally;
- source global gap-fill accumulation in island order.

The high-level composition wrapper is `SourceClassicPerimeterOrderedPipeline2`; it builds on `SourceClassicPerimeterIslandProcess2` and the already-verified `SourceClassicFuzzyPerimeterPipeline2` rather than duplicating those algorithms.

### QIDI outwall / loop-node metadata represented in this scope

The ordered pipeline additionally represents the classic `z_direction_outwall_speed_continuous` metadata producer:

- outer-wall `NodeContour` capture for raw thin walls, smaller-width depth-zero walls, then normal depth-zero walls;
- closed wall contours preserve the source contour-then-holes order and append the first point explicitly;
- source `Point::is_in_lines(const Points&)` endpoint, horizontal/vertical and strict `< SCALED_EPSILON` finite-line distance behavior;
- `LoopNode` IDs append to one caller-supplied global vector and therefore preserve preexisting node offsets;
- single-outwall source shortcut (`loop_id = 0`, no geometric matching);
- multiple-outwall matching in **post-wall-sequence extrusion entity order**, skipping only exact `erPerimeter` roles;
- per-island `loop_node_range = [start,end)` assignment after matching;
- node bounding boxes expanded by exact `SCALED_EPSILON = 10` source units.

The 387-test checkpoint covers three ordered islands, per-island `OuterInner`, non-null empty lower slices, one shared fuzzy RNG, sequential loop-node ranges, a contour+hole matching case and preexisting global node IDs.

### Important QIDI compensation quirk retained

The supplied source `Surface` copy constructor copies fields only through `extra_perimeters`; QIDI `counter_circle_compensation` and `holes_circle_compensation` additions are omitted. Therefore `Surfaces all_surfaces = this->slices->surfaces` resets those members before the later classic compensation lookup. The Dart high-level path preserves this behavior rather than restoring the apparent intended metadata. Standalone centroid / split-disable semantics remain represented and tested for callers that explicitly supply such metadata.

## Fuzzy / Arachne scope retained

The 387-test suite re-runs all previously verified fuzzy evidence: exact `FuzzySkinType` policy; one Classic RNG stream; MT19937/libstdc++ `[0,1)` oracles; pinned libnoise Perlin/Billow/RidgedMulti/Voronoi; Polygon/Polyline fuzzy geometry and painted-region LineSegmentation; source ZAttributes compatibility; source-shaped Arachne `ExtrusionLine`; `Displacement`, `Extrusion`, `Combined` seeded C++ goldens; and region-aware Arachne fuzzy composition.

This remains scoped. It does not prove the full Arachne wall generator or every pathological clipping topology.

## First unfinished priority

The next major wall-generation boundary is pinned `PerimeterGenerator::process_arachne()`. Do **not** treat the existing Arachne fuzzy `ExtrusionLine` subset as a full wall generator.

Dependency order for the next batch:

1. port the source-shaped `Arachne::WallToolPathsParams` contract and constructor scaling boundaries used by `process_arachne()`;
2. port the first independently testable `Arachne::WallToolPaths` foundation from pinned `Arachne/WallToolPaths.hpp/.cpp`, including its exact input polygon normalization/simplification prerequisites before claiming any generated wall parity;
3. follow the real dependency chain through the beading-strategy / skeletal-trapezoidation pieces required by `WallToolPaths::generate()`; add upstream/C++ oracle fixtures at each independently testable seam;
4. only after those dependencies are green, compose the `process_arachne()` one-wall / separate-wall-generation branches, `getToolPaths()`/inner-contour outputs and the already-ported Arachne fuzzy/LineSegmentation consumers;
5. keep full Arachne wall generation `port_started` until variable-width wall paths and their source ordering are validated end-to-end.

## Numeric/source invariants

- slicer coordinates use `SCALING_FACTOR = 0.00001` mm (100000 source units/mm);
- preserve source integer geometry until the source converts units;
- preserve explicit/implicit `float` boundaries before Clipper calls;
- preserve source `lrint`/round/truncation boundaries rather than normalizing them;
- keep Boost.Polygon 1.83 operand/bit semantics, including existing `BigInt` boundaries;
- keep QIDI/Clipper compatibility quirks frozen by regression tests;
- never replace a source oddity with a cleaner algorithm without an independent source oracle.

## Other major open areas

All top-level gates remain **OPEN**. Major remaining work includes full Arachne wall generation, later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft toolpaths, full G-code state/templates/travel/retract/cooling/multimaterial behavior, project/profile round trips and STEP/source-enabled import formats, scene/editor and Preview parity, Device/cloud/P2P/account/camera/HMS/firmware, calibration, desktop integration, full UI/localization/accessibility, runtime asset publication/verification, and exhaustive reference/differential tests.

## Working discipline

For each source batch: identify exact source functions and dependencies; port literal behavior; add source-oracle/translated/differential tests; confirm `.github/workflows/flutter-parity.yml` on pinned Flutter 3.47.2; do not weaken analyzer/tests; then update migration ledgers and this handoff. A scoped passing test never closes a top-level product gate.
