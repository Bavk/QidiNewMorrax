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

- code commit `0a9fa8155e0e860b82177280a379a7b9dccfeeb5` (`test: cover classic pre-island composition`);
- `.github/workflows/flutter-parity.yml` run `34695501638` (#273);
- Flutter `3.47.2`;
- Dart `3.13.2`;
- `flutter analyze` → **No issues found!**;
- `flutter test --reporter expanded` → **377/377 passed**;
- job conclusion → **success**.

Important checkpoints leading here:

- `ae218afee234afa92f7ef2967d61db8485a82d5a` / run #260: represented per-island shell → Alltop → gap-fill → final fill boundary, 351/351 green;
- `1b2f5f4aa8274795f88a6088db11fb5a06202186` / run #264: pinned `BridgeDetector` plus translated upstream `t/bridges.t` angle/coverage fixtures, 359/359 green;
- `d9ad4a5564e6ef5fa06a622a626d2091ec432475` / run #268: represented `process_no_bridge()` gates plus `chbBridges` / `chbFilled`, 365/365 green;
- `0a9fa815...` / run #273: source surface preprocessing composed into the already-verified per-island fill path, 377/377 green.

## Current represented classic surface → fill path — scoped parity verified

Pinned source: `bambulab/BambuStudio@f2b55a5a83f266cf56e06c7943a81a08bebb7fad`.

The represented `PerimeterGenerator::process_classic()` path now covers, in source order:

- `Surfaces all_surfaces = this->slices->surfaces` using the supplied `Surface` copy semantics;
- source `CounterboreHoleBridgingOption` order and exact `process_no_bridge()` gate for `None`, null `lower_slices`, and non-null empty lower slices;
- source `BridgeDetector` candidate generation, 5-degree brute-force family, support edges/anchor regions, endpoint-anchored scanlines, coverage/max-span selection, trapezoid coverage and source safety offset;
- both active counterbore branches, `chbBridges` and `chbFilled`, including 1 mm `BRIDGE_INFILL_MARGIN`, safety-diff behavior, square/miter offset order, bridge extraction, nested-surface split/erase handling and `stInternal` bridge fill output;
- constructor `m_scaled_resolution = scaled<double>(max(resolution, EPSILON))` boundary;
- conditional `surface_simplify_resolution = 0.2 * m_scaled_resolution` only for arc fitting + `FuzzySkinType::None`, otherwise the base resolution;
- `chain_expolygons()` ordering through source bbox centers and the already-ported shortest-path chain;
- each `Surface::extra_perimeters` plus odd-layer `alternate_extra_wall` before top-one-wall gates;
- QIDI circle-compensation centroid semantics, including source `lrint` and `eps = 1000`, plus local disable when simplify/union splits an island;
- each prepared island feeding `SourceClassicPerimeterFillProcess2` in source order;
- counterbore-produced fill surfaces being accumulated before per-island final fills;
- the previously verified one-wall/Alltop, shell, thin-wall/gap-fill and final `fill_surfaces` / `fill_no_overlap` behavior, including the **7999** source-unit 20% overlap quirk.

The high-level composition wrapper is `SourceClassicPerimeterIslandProcess2`.

### Important QIDI compensation quirk

The supplied source `Surface` copy constructor copies fields only through `extra_perimeters`; the QIDI `counter_circle_compensation` and `holes_circle_compensation` additions are omitted. Therefore the actual source statement `Surfaces all_surfaces = this->slices->surfaces` resets those members before the later `process_classic()` compensation lookup. The Dart high-level path preserves this behavior rather than restoring the apparent intended metadata. Standalone centroid / split-disable semantics remain represented and tested for callers that explicitly supply such metadata.

## BridgeDetector evidence

`SourceBridgeDetector2` is covered by translated fixtures from pinned upstream `t/bridges.t`: wide/tall O-shaped supports, two rotated O cases, a two-sided bridge, C-shaped support, L-shaped anchors with half-area coverage, and a fully airborne negative case. The broader arbitrary/pathological geometry space remains open; this is scoped evidence, not a claim that every bridge topology has been exhaustively validated.

## Fuzzy / Arachne scope retained

The 377-test suite re-runs all previously verified fuzzy evidence: exact `FuzzySkinType` policy; one Classic RNG stream; MT19937/libstdc++ `[0,1)` oracles; pinned libnoise Perlin/Billow/RidgedMulti/Voronoi; Polygon/Polyline fuzzy geometry and painted-region LineSegmentation; source ZAttributes compatibility; source-shaped Arachne `ExtrusionLine`; `Displacement`, `Extrusion`, `Combined` seeded C++ goldens; and region-aware Arachne fuzzy composition.

This remains scoped. It does not prove the full Arachne wall generator or every pathological clipping topology.

## First unfinished priority

Continue the source block immediately **after** the now-verified ordered-island shell/fill preparation without re-porting already-green helpers:

1. feed each ordered `SourceClassicProcessedIsland2.process.perimeter` into the existing `SourceClassicPerimeterPipeline2` nesting / `traverse_loops()` path and preserve source collection append order across islands;
2. compose the existing lower-slice overhang and fuzzy traversal branches per ordered island, keeping wall sequence adjustment at the source position;
3. audit and port QIDI metadata surrounding this traversal, especially `outwall_paths`, `loop_nodes`, `loop_node_range` and `z_direction_outwall_speed_continuous` behavior;
4. preserve the verified `Surface` copy-reset quirk for circle compensation — do **not** silently restore metadata lost by the pinned source copy constructor;
5. after the classic ordered-island → extrusion traversal boundary is green, continue broader Arachne wall generation.

## Numeric/source invariants

- slicer coordinates use `SCALING_FACTOR = 0.00001` mm (100000 source units/mm);
- preserve source integer geometry until the source converts units;
- preserve explicit/implicit `float` boundaries before Clipper calls;
- preserve source `lrint`/round/truncation boundaries rather than normalizing them;
- keep Boost.Polygon 1.83 operand/bit semantics, including existing `BigInt` boundaries;
- keep QIDI/Clipper compatibility quirks frozen by regression tests;
- never replace a source oddity with a cleaner algorithm without an independent source oracle.

## Other major open areas

All top-level gates remain **OPEN**. Major remaining work includes ordered-island integration into classic extrusion traversal and QIDI loop metadata, full Arachne wall generation, fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft toolpaths, full G-code state/templates/travel/retract/cooling/multimaterial behavior, project/profile round trips and STEP/source-enabled import formats, scene/editor and Preview parity, Device/cloud/P2P/account/camera/HMS/firmware, calibration, desktop integration, full UI/localization/accessibility, runtime asset publication/verification, and exhaustive reference/differential tests.

## Working discipline

For each source batch: identify exact source functions and dependencies; port literal behavior; add source-oracle/translated/differential tests; confirm `.github/workflows/flutter-parity.yml` on pinned Flutter 3.47.2; do not weaken analyzer/tests; then update migration ledgers and this handoff. A scoped passing test never closes a top-level product gate.
