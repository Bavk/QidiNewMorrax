# Handoff — Qidi Flow strict Flutter/Dart rewrite

This repository is a **strict 1:1 reimplementation** of Qidi Flow 2.07.02.60 Pass28 in Flutter + Dart. The legacy C++/wxWidgets/React application is reference material only and must not remain a runtime backend through FFI, subprocesses, native shared libraries, hidden services, or embedded legacy WebViews.

## Read first

1. [`../migration/PARITY_CONTRACT.md`](../migration/PARITY_CONTRACT.md) — acceptance authority.
2. [`../migration/MIGRATION_STATUS.md`](../migration/MIGRATION_STATUS.md) — subsystem truth and next dependency order.
3. [`../migration/TRACEABILITY.md`](../migration/TRACEABILITY.md) — source → Dart → evidence ledger.
4. [`../migration/VALIDATION.md`](../migration/VALIDATION.md) — executed evidence.
5. [`../migration/FUZZY_SKIN_SOURCE_NOTES.md`](../migration/FUZZY_SKIN_SOURCE_NOTES.md) — pinned fuzzy-skin contract.

Do not infer completion from visual similarity, compilation, or common-case tests. Source quirks are part of the contract.

## Current validated checkpoint — 2026-09-12

Latest validated code checkpoint:

- code commit `1f9d7010b52f48f56286d0b5b2772de352b865a9` (`test: assert fuzzy region slowdown contract only`);
- `.github/workflows/flutter-parity.yml` run `34689260162` (#244);
- Flutter `3.47.2`;
- Dart `3.13.2`;
- `flutter analyze` → **No issues found!**;
- `flutter test --reporter expanded` → **311/311 passed**;
- job conclusion → **success**.

Important immediately preceding fuzzy milestones:

- `9e798bb1e11872534f5903e5ad77b3dec8910413` / run #239: direct Dart libnoise v1.0.0 subset + structured fuzzy noise, **298/298**, green;
- `a1ad0e44d44a55d642cff2c872e39c37458fb284`: source-shaped Polyline/Polygon `LineSegmentation` + region-aware classic fuzzy composition;
- `46a82407603fe7fa6d534940d803182f331de271`: corrected duplicate closing-point source-index reconstruction for fully covered polygons;
- `1f9d7010...` / run #244: region-aware classic fuzzy pipeline green end-to-end.

## Current represented classic fuzzy scope — scoped parity verified

Pinned source: `bambulab/BambuStudio@f2b55a5a83f266cf56e06c7943a81a08bebb7fad`; pinned noise dependency: `bambulab/libnoise@v1.0.0`.

The represented classic fuzzy path now covers:

- `FuzzySkinType`: `None`, `External`, `All`, `AllWalls`, `Disabled_fuzzy` and first-layer gating;
- exact `fuzzy_skin_allows_overhang_slowdown()` distinction between `None` and `Disabled_fuzzy`, including nonempty `perimeter_regions`;
- `NoiseType`: `Classic`, `Perlin`, `Billow`, `RidgedMulti`, `Voronoi`;
- source one-stream `random_value()` topology, direct MT19937 and libstdc++ `[0,1)` double composition;
- Classic displacement plus deterministic libnoise `Perlin`, `Billow`, `RidgedMulti` and `Voronoi` modules;
- exact `fuzzy_skin_scale` clamp/frequency, octave, persistence, Voronoi displacement and `slice_z` input behavior represented by the current tests;
- closed and open fuzzy polyline sampling, carried leftover distance, source coordinate truncation and fallback quirks;
- Polyline/Polygon `LineSegmentation` range construction, default gaps, clip ordering, source point lerp and closed-polygon duplicate endpoint identity for represented fixtures;
- painted/per-region config selection and per-segment open fuzzy-polyline application;
- recursive classic perimeter traversal and overhang-speed gating with real region emptiness.

The current Dart Clipper2 dependency does not expose Clipper-Z callbacks. `SourceLineSegmentation2` therefore reconstructs the source `(line_index,t)` endpoint attributes by projecting Clipper results back onto the integer source polyline using QIDI's `SCALED_EPSILON = 10` threshold. This adapter boundary is regression-tested and must not be casually simplified.

This remains a scoped parity claim. The whole fuzzy subsystem is not complete until Arachne branches and broader source-oracle cases are covered.

## First unfinished priority

The next fuzzy dependency is Arachne `fuzzy_extrusion_line()` from pinned `FuzzySkin.cpp`:

1. introduce/port the source-shaped Arachne `ExtrusionJunction` / `ExtrusionLine` subset needed by fuzzy skin, preserving `p`, width `w`, `perimeter_index`, closure behavior and integer-coordinate casts;
2. port `FuzzySkinMode::Displacement`, `Extrusion`, and `Combined` exactly, including `scaled(0.01)` minimum extrusion width and the Combined half-radius position shift;
3. preserve the same `random_value()` spacing topology and structured-noise `GetValue(unscale(pa.x), unscale(pa.y), slice_z)` calls;
4. add source-oracle fixtures for width/position values and closed-line front/back synchronization;
5. then integrate the Arachne line-segmentation overload used for per-region configs rather than substituting polygon segmentation.

After that, continue the next unresolved `process_classic()` fill-surface/fill-no-overlap/later stages and broader Arachne wall generation in dependency order.

## Numeric/source invariants

- slicer coordinates use `SCALING_FACTOR = 0.00001` mm (100000 source units/mm);
- preserve source integer geometry until the source converts units;
- keep Boost.Polygon 1.83 operand/bit semantics, including existing `BigInt` boundaries;
- keep QIDI/Clipper compatibility quirks frozen by existing regression tests;
- never replace a source oddity with a cleaner algorithm without an independent source oracle.

## Other major open areas

All top-level gates remain open. Major remaining work includes later classic perimeter/fill stages, full Arachne, fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft toolpaths, full G-code state/templates/travel/retract/cooling/multimaterial behavior, project/profile round trips and STEP/source-enabled import formats, scene/editor and Preview parity, Device/cloud/P2P/account/camera/HMS/firmware, calibration, desktop integration, full UI/localization/accessibility, runtime asset publication/verification, and exhaustive reference/differential tests.

## Working discipline

For each source batch: identify exact source functions and dependencies; port literal behavior; add source-oracle/translated/differential tests; confirm `.github/workflows/flutter-parity.yml` on pinned Flutter 3.47.2; do not weaken analyzer/tests; then update migration ledgers and this handoff. A scoped passing test never closes a top-level product gate.
