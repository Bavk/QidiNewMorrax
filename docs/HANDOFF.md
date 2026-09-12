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

- code commit `ae218afee234afa92f7ef2967d61db8485a82d5a` (`test: cover classic fill process source order`);
- `.github/workflows/flutter-parity.yml` run `34694164752` (#260);
- Flutter `3.47.2`;
- Dart `3.13.2`;
- `flutter analyze` → **No issues found!**;
- `flutter test --reporter expanded` → **351/351 passed**;
- job conclusion → **success**.

Important checkpoints leading here:

- `7c1c5d1f56a287cb812df3b511484851277d460f` / run #249: represented Arachne fuzzy modes plus direct Clipper-Z LineSegmentation, 325/325 green;
- `9ba4f919af5f7b339c7e22345c81ff297ede0aa2` / run #252: final represented classic `fill_surfaces` / `fill_no_overlap` boundary, including the source 20% overlap result **7999** rather than idealized 8000, 333/333 green;
- `5a4d8b65e177ce6fe196594c4263d3f962a90422` / run #254: represented `TopOneWallType::Alltop` producer, 340/340 green;
- `7e51f78e9f6742320587999e980b04ff9947d6b9` / run #258: exact source-order top-one-wall shell integration, 346/346 green;
- `ae218af...` / run #260: composed shell → in-loop Alltop → gap-fill mutation → final fill-boundary process, 351/351 green.

## Current represented classic fill process — scoped parity verified

Pinned source: `bambulab/BambuStudio@f2b55a5a83f266cf56e06c7943a81a08bebb7fad`.

The represented `PerimeterGenerator::process_classic()` fill path now covers, in source order:

- configured wall count + surface extra/alternate-wall equivalent inputs represented by the shell settings;
- exact pre-shell one-wall gate for topmost/bottom-most and `only_one_wall_first_layer` behavior, preserving `upper_slices == nullptr` versus a non-null empty upper-slice set;
- classic onion-shell generation, QIDI smaller external perimeter, thin-wall and represented gap-fill paths;
- source final-wall stop: the extra shell iteration exists only for gap discovery when gap fill is enabled and sparse infill density is non-zero;
- `TopOneWallType::Alltop` producer immediately after the first `last = offsets`, so its mutated `last` drives subsequent shell offsets and may reduce effective wall count;
- literal bbox pruning used by that producer, source `float` offset boundaries, represented `ApplySafetyOffset::Yes`, lower-slice bridge merge, `temp_gap`, `top_fills`, `fill_clip` and optional gap-fill re-union;
- gap-fill subtraction from `last` before final fill construction;
- final `not_filled_exp` preparation, wall-overlap resolution, `fill_surfaces` and `fill_no_overlap` construction;
- end-to-end zero-wall, one-wall, two-wall, topmost, Alltop and percentage-overlap fixtures;
- the pinned floating-point quirk where the represented 20% overlap resolves to **7999** source units end-to-end.

The process wrapper is `SourceClassicPerimeterFillProcess2`. Its scope deliberately ends before the surrounding source surface preprocessing, loop traversal/extrusion conversion, loop-node metadata and later infill generation.

## Fuzzy / Arachne scope retained

The 351-test suite re-runs all previously verified fuzzy evidence: exact `FuzzySkinType` policy; one Classic RNG stream; MT19937/libstdc++ `[0,1)` oracles; pinned libnoise Perlin/Billow/RidgedMulti/Voronoi; Polygon/Polyline fuzzy geometry and painted-region LineSegmentation; source ZAttributes compatibility; source-shaped Arachne `ExtrusionLine`; `Displacement`, `Extrusion`, `Combined` seeded C++ goldens; and region-aware Arachne fuzzy composition.

This remains scoped. It does not prove the full Arachne wall generator or every pathological clipping topology.

## First unfinished priority

Continue the source block immediately **before** the now-verified per-island classic fill process:

1. port `PerimeterGenerator::process_no_bridge(all_surfaces, perimeter_spacing, ext_perimeter_width)` for counterbore-hole sacrificial bridge handling, with translated/source fixtures;
2. port conditional `surface_simplify_resolution`: `0.2 * m_scaled_resolution` only when arc fitting is enabled and fuzzy skin is `None`, otherwise `m_scaled_resolution`;
3. port `chain_expolygons(surface_exp)` island ordering and propagate each `Surface::extra_perimeters` into the per-island wall count instead of relying only on global settings;
4. carry QIDI circle-compensation metadata: `counter_circle_compensation`, `holes_circle_compensation` centroid matching with source `eps = 1000`, and disable counter compensation when simplification/union splits an island into more than one ExPolygon;
5. feed those prepared ordered islands into `SourceClassicPerimeterFillProcess2` and add source-order end-to-end fixtures;
6. after this preprocessing boundary is verified, continue remaining classic traversal/metadata integration and then broader Arachne wall generation.

## Numeric/source invariants

- slicer coordinates use `SCALING_FACTOR = 0.00001` mm (100000 source units/mm);
- preserve source integer geometry until the source converts units;
- preserve explicit/implicit `float` boundaries before Clipper calls;
- keep Boost.Polygon 1.83 operand/bit semantics, including existing `BigInt` boundaries;
- keep QIDI/Clipper compatibility quirks frozen by regression tests;
- never replace a source oddity with a cleaner algorithm without an independent source oracle.

## Other major open areas

All top-level gates remain **OPEN**. Major remaining work includes source surface preprocessing and remaining classic process integration, full Arachne wall generation, fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft toolpaths, full G-code state/templates/travel/retract/cooling/multimaterial behavior, project/profile round trips and STEP/source-enabled import formats, scene/editor and Preview parity, Device/cloud/P2P/account/camera/HMS/firmware, calibration, desktop integration, full UI/localization/accessibility, runtime asset publication/verification, and exhaustive reference/differential tests.

## Working discipline

For each source batch: identify exact source functions and dependencies; port literal behavior; add source-oracle/translated/differential tests; confirm `.github/workflows/flutter-parity.yml` on pinned Flutter 3.47.2; do not weaken analyzer/tests; then update migration ledgers and this handoff. A scoped passing test never closes a top-level product gate.
