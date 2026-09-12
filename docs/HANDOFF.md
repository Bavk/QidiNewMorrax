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

Corrected fuzzy code checkpoint:

- code commit `ffc005e678d0cf1e6d4000e6c9a842620700ddbe` (`fix: align fuzzy skin rng with pinned source`);
- `.github/workflows/flutter-parity.yml` run `34688064516` (#230);
- Flutter `3.47.2`;
- Dart `3.13.2`;
- `flutter analyze` → **No issues found!**;
- `flutter test --reporter expanded` → **288/288 passed**;
- job conclusion → **success**.

Run #229 had failed three newly introduced `*Exact2` tests. Literal inspection of pinned `FuzzySkin.cpp` proved those tests encoded a false independent-RNG model. The corrective commit removed that duplicate branch and restored source semantics; #230 is the validating replacement checkpoint.

## Critical fuzzy correction

Pinned source: `bambulab/BambuStudio@f2b55a5a83f266cf56e06c7943a81a08bebb7fad`.

Literal `FuzzySkin.cpp` facts:

- `random_value()` owns one function-local thread-local `std::mt19937` plus one `uniform_real_distribution<double>(0,1)`;
- `NoiseType::Classic` is `UniformNoise`, whose `GetValue()` calls that **same** `random_value()` and maps it to `[-1,1)`;
- spacing and Classic displacement therefore share one random stream in call order;
- Classic displacement remains `double` in this pinned file; there is no separate float32 displacement boundary;
- pinned `fuzzy_polygon()` calls closed `fuzzy_polyline()` directly; there is no extra same-neighbor cleanup in this file.

The separate spacing/displacement `*Exact2` implementation was false parity and has been removed. `SourceFuzzyMt19937Random2` now ports MT19937 plus libstdc++ double-distribution composition, with seeded C++ oracle values in the green test suite. Production Classic fuzzy uses a per-isolate nondeterministically seeded stream.

The correction also removes the artificial coupling of fuzzy layer identity to overhang state: `SourceClassicFuzzyPerimeterTraversal2` receives explicit `layerId`, so first-layer suppression is correct even when overhang detection is off.

## Current represented classic fuzzy scope — scoped parity verified

Run #230 verifies the represented no-painted-region Classic branch:

- `FuzzySkinType`: `None`, `External`, `All`, `AllWalls`, `Disabled_fuzzy`;
- `NoiseType`: `Classic`, `Perlin`, `Billow`, `RidgedMulti`, `Voronoi` ordering;
- `should_fuzzify()` including first-layer gating;
- `fuzzy_skin_allows_overhang_slowdown()` distinction between `None` and `Disabled_fuzzy`;
- Classic `fuzzy_polyline()` / `fuzzy_polygon()` sampling and perpendicular displacement;
- source fallback quirk for fewer than three generated points;
- one-stream RNG call order;
- direct MT19937 + libstdc++ seeded oracle;
- recursive classic perimeter traversal order with explicit layer identity;
- represented Classic fuzzy/overhang slowdown composition in the no-region classic pipeline.

This is a scoped parity claim only. Non-Classic noise, painted regions and Arachne fuzzy modes remain open.

## First unfinished priority

Continue fuzzy skin with the first missing source branch, in this order:

1. port `get_noise_module()` dependencies for **Perlin**, **Billow**, **RidgedMulti**, and **Voronoi**, preserving source frequency/scale, octave, persistence, displacement, coordinate and `slice_z` semantics;
2. add deterministic C++/source oracle fixtures for those noise modules before integrating them into `SourceFuzzySkinGeometry2`;
3. port painted/per-region `LineSegmentation` and per-segment config selection used by `apply_fuzzy_skin()`; never fuzzify the whole loop as a substitute;
4. then port Arachne `fuzzy_extrusion_line()` including `Displacement`, `Extrusion`, and `Combined` width/position rules.

Only after those branches and corresponding CI evidence should fuzzy skin receive a broader parity claim.

## Numeric/source invariants

- slicer coordinates use `SCALING_FACTOR = 0.00001` mm (100000 source units/mm);
- preserve source integer geometry until the source converts units;
- keep Boost.Polygon 1.83 operand/bit semantics, including `BigInt` boundaries already required by the Dart port;
- keep QIDI/Clipper compatibility quirks frozen by existing regression tests;
- never replace a source oddity with a cleaner algorithm without an independent source oracle.

## Other major open areas

All top-level gates remain open. Major remaining work includes later classic perimeter/fill stages, Arachne, fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft toolpaths, full G-code state/templates/travel/retract/cooling/multimaterial behavior, project/profile round trips and STEP/source-enabled import formats, scene/editor and Preview parity, Device/cloud/P2P/account/camera/HMS/firmware, calibration, desktop integration, full UI/localization/accessibility, runtime asset publication/verification, and exhaustive reference/differential tests.

## Working discipline

For each source batch: identify exact source functions and dependencies; port literal behavior; add source-oracle/translated/differential tests; confirm `.github/workflows/flutter-parity.yml` on pinned Flutter 3.47.2; do not weaken analyzer/tests; then update migration ledgers and this handoff. A scoped passing test never closes a top-level product gate.
