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

- code commit `7c1c5d1f56a287cb812df3b511484851277d460f` (`fix: normalize open Clipper Z path ordering`);
- `.github/workflows/flutter-parity.yml` run `34690713768` (#249);
- Flutter `3.47.2`;
- Dart `3.13.2`;
- `flutter analyze` → **No issues found!**;
- `flutter test --reporter expanded` → **325/325 passed**;
- job conclusion → **success**.

Important fuzzy milestones retained:

- `ffc005e678d0cf1e6d4000e6c9a842620700ddbe`: corrected the false independent-RNG interpretation and restored the one shared source `random_value()` stream;
- `9e798bb1e11872534f5903e5ad77b3dec8910413` / run #239: direct Dart `bambulab/libnoise@v1.0.0` subset and structured fuzzy noise;
- `1f9d7010b52f48f56286d0b5b2772de352b865a9` / run #244: represented Polyline/Polygon painted-region fuzzy path;
- `a5633836ed2153b40b77c173bb638246380009fc`: source-shaped Arachne `ExtrusionJunction`/`ExtrusionLine`, fuzzy modes and Arachne region segmentation;
- `7c1c5d1...` / run #249: direct Clipper-Z compatibility plus open-path ordering fix, all old and new fixtures green.

Runs #246–#248 were investigation checkpoints. The new Arachne C++ goldens already passed there; the only failures were two LineSegmentation adapter cases caused by Dart Clipper2 returning a represented open intersection in the opposite orientation from pinned `ClipperLib_Z`. The final compatibility fix preserved the original assertions; no fixture was weakened.

## Current represented fuzzy scope — scoped parity verified

Pinned source: `bambulab/BambuStudio@f2b55a5a83f266cf56e06c7943a81a08bebb7fad`; pinned structured-noise dependency: `bambulab/libnoise@v1.0.0`.

The represented scope now covers:

- `FuzzySkinType`: `None`, `External`, `All`, `AllWalls`, `Disabled_fuzzy`, first-layer gating and exact overhang-slowdown policy;
- `NoiseType`: `Classic`, `Perlin`, `Billow`, `RidgedMulti`, `Voronoi`;
- one-stream Classic RNG topology, direct MT19937/libstdc++ `[0,1)` behavior and production nondeterministic stream seam;
- direct libnoise value/gradient arithmetic, vector table, frequency/scale, octaves, persistence, Voronoi displacement and `slice_z` inputs;
- Polygon/Polyline fuzzy sampling, displacement, fallback and integer-cast quirks;
- Polyline/Polygon painted-region `LineSegmentation` and per-segment config composition;
- source-shaped Arachne `ExtrusionJunction` / `ExtrusionLine` subset;
- `FuzzySkinMode::{Displacement, Extrusion, Combined}` including `scaled(0.01)` minimum width and Combined half-width shift;
- seeded C++ position/width goldens for all three Arachne modes;
- Arachne fallback and endpoint-coordinate closure synchronization of front position/width;
- Arachne/extrusion-line region segmentation with source width interpolation and per-region fuzzy application.

`SourceLineSegmentation2` now uses `clipper2 0.0.3`'s real `Point64.z` and `Clipper64.zCallback` to encode the source 32-bit `ZAttributes` layout. Two narrow compatibility shims remain explicit: surviving open terminal points whose decoded source index contradicts exact XY can have their unique source index restored, and reversed Dart open-path output is normalized while retaining the original wrap rule only for subjects whose first and last XY actually coincide. Closed Polygon/Arachne seam behavior remains source-shaped.

This remains a scoped parity claim. It does not prove the full Arachne wall generator or every pathological LineSegmentation topology.

## First unfinished priority

The fuzzy branch boundary represented above is now closed enough to move forward. Continue the next missing part of pinned `PerimeterGenerator::process_classic()`:

1. port the post-perimeter construction of `fill_surfaces`, beginning with `not_filled_exp`, inset/collapse offsets and `stInternal` append behavior;
2. port the paired `fill_no_overlap` construction with the exact `min_perimeter_infill_spacing`, overlap and top-fill conditions;
3. add source-oracle/translated fixtures for simple contour, top-fill interaction and no-overlap boundaries before wiring the result into later fill stages;
4. then continue remaining classic perimeter/fill stages and broader Arachne wall generation, reusing the verified fuzzy helper rather than duplicating it.

## Numeric/source invariants

- slicer coordinates use `SCALING_FACTOR = 0.00001` mm (100000 source units/mm);
- preserve source integer geometry until the source converts units;
- keep Boost.Polygon 1.83 operand/bit semantics, including existing `BigInt` boundaries;
- keep QIDI/Clipper compatibility quirks frozen by regression tests;
- never replace a source oddity with a cleaner algorithm without an independent source oracle.

## Other major open areas

All top-level gates remain **OPEN**. Major remaining work includes later classic perimeter/fill stages, full Arachne wall generation, fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft toolpaths, full G-code state/templates/travel/retract/cooling/multimaterial behavior, project/profile round trips and STEP/source-enabled import formats, scene/editor and Preview parity, Device/cloud/P2P/account/camera/HMS/firmware, calibration, desktop integration, full UI/localization/accessibility, runtime asset publication/verification, and exhaustive reference/differential tests.

## Working discipline

For each source batch: identify exact source functions and dependencies; port literal behavior; add source-oracle/translated/differential tests; confirm `.github/workflows/flutter-parity.yml` on pinned Flutter 3.47.2; do not weaken analyzer/tests; then update migration ledgers and this handoff. A scoped passing test never closes a top-level product gate.
