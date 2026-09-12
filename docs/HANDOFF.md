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

- code commit `5a4d8b65e177ce6fe196594c4263d3f962a90422` (`fix: compile classic top-fill source polygon`);
- `.github/workflows/flutter-parity.yml` run `34693713324` (#254);
- Flutter `3.47.2`;
- Dart `3.13.2`;
- `flutter analyze` → **No issues found!**;
- `flutter test --reporter expanded` → **340/340 passed**;
- job conclusion → **success**.

The immediately preceding classic-fill checkpoints are also important:

- `549a731ebcf88b22f96359caa5a1d7419ea381a8` added the final classic `fill_surfaces` / `fill_no_overlap` boundary construction;
- `9ba4f919af5f7b339c7e22345c81ff297ede0aa2` froze the source C++ floating-point quirk where 20% of the represented `ratio_over` becomes **7999**, not an idealized 8000, after `scale_` and `coord_t` truncation; run `34691194040` (#252) was green with **333/333** tests;
- `aff2a3edc2720430f8e33376f097f1ebbf7f9628` added the pinned `TopOneWallType::Alltop` producer for `top_fills`, `fill_clip` and the source mutation of `last`;
- run #253 failed only because that new file invoked the non-const `SourcePolygon2` constructor with an accidental `const`; no geometry expectation failed. Commit `5a4d8b6` removed only that compile typo, and run #254 passed all **340/340** tests.

Earlier fuzzy/Arachne checkpoint `7c1c5d1f56a287cb812df3b511484851277d460f` / run #249 remains fully contained in the current suite.

## Current represented classic fill scope — scoped parity verified

Pinned source: `bambulab/BambuStudio@f2b55a5a83f266cf56e06c7943a81a08bebb7fad`.

`SourceClassicFillBoundary2` now covers the represented post-perimeter boundary block of `PerimeterGenerator::process_classic()`:

- zero/one/two-or-more wall inset selection;
- absolute and percent `infill_wall_overlap` with source `get_abs_value()` arithmetic and `coord_t` truncation;
- `simplify_p → union_ex` represented boundary;
- `min_perimeter_infill_spacing = coord_t(solid_infill_spacing * 0.6)`;
- source `offset2_ex()` construction of internal `fill_surfaces`;
- distinct `fill_no_overlap` branches and their overlap threshold;
- top-fill growth/intersection/union consumer behavior;
- intentional integer-vs-double-vs-float boundaries covered by regression tests.

`SourceClassicTopFillAllTop2` now covers the represented `TopOneWallType::Alltop` producer executed after the first perimeter offset:

- exact gate inputs represented by `loop_number > 0` and non-null `upper_slices` (the helper itself represents `i == 0` and `Alltop`);
- source `config->wall_loops` vs current `loop_number` distinction;
- `offset_top_surface` scale → unscale → multiply → scale/truncate order;
- `top_area_threshold` minimum width arithmetic;
- literal `clip_clipper_polygons_with_subject_bbox()` side-mask pruning with `SCALED_EPSILON`-inflated `last` bounds;
- implicit `float` boundaries on `offset()` / `offset_ex()` deltas;
- `ApplySafetyOffset::Yes` represented 10-source-unit clip growth;
- top/non-top split, `temp_gap`, `inner_polygons`, lower-slice bridge checker and merge;
- final `top_fills`, `fill_clip`, `last = intersection_ex(...)`, and optional gap-fill re-union;
- composition into the verified final fill-boundary helper.

This is still a scoped claim. The producer is deliberately not called after a completed shell as a fake approximation: pinned source executes it **inside** the first shell iteration and its mutated `last` feeds subsequent iterations.

## Fuzzy / Arachne scope retained

The current 340-test suite re-runs the previously verified fuzzy subset: exact source `FuzzySkinType` policy, one Classic RNG stream, direct MT19937/libstdc++ `[0,1)`, pinned libnoise Perlin/Billow/RidgedMulti/Voronoi, Polygon/Polyline sampling and painted-region LineSegmentation, source ZAttributes compatibility, source-shaped Arachne `ExtrusionLine`, all three `FuzzySkinMode` variants, seeded C++ position/width goldens and region-aware Arachne fuzzy application.

The direct Clipper-Z compatibility remains explicit: Dart Clipper2 open-path orientation/terminal-Z differences are normalized only at the adapter boundary; closed source wrap behavior is retained.

## First unfinished priority

Integrate the now-verified classic fill pieces at their exact source positions instead of composing them post hoc:

1. port the pre-shell one-wall gate exactly: after extra/alternate wall calculation, if `loop_number > 0` and either `(top_one_wall_type != None && upper_slices == nullptr)` or `(only_one_wall_first_layer && layer_id == 0)`, force `loop_number = 0`;
2. invoke the verified `Alltop` producer immediately after the first source `last = std::move(offsets)` when `i == 0 && i != loop_number`, so its mutated `last` drives the next inner-perimeter iteration and later loop collapse can still reduce the effective loop count;
3. carry `top_fills` / `fill_clip` through the classic shell result and feed them, after gap-fill mutation, into the verified `SourceClassicFillBoundary2` block;
4. add end-to-end fixtures for topmost/no-upper-slices, first-layer-one-wall, mixed upper coverage, lower-slice bridge merge, gap-fill re-union and final `fill_surfaces` / `fill_no_overlap` output;
5. only then continue remaining classic process integration and broader Arachne wall generation.

## Numeric/source invariants

- slicer coordinates use `SCALING_FACTOR = 0.00001` mm (100000 source units/mm);
- preserve source integer geometry until the source converts units;
- preserve explicit/implicit `float` boundaries before Clipper calls;
- keep Boost.Polygon 1.83 operand/bit semantics, including existing `BigInt` boundaries;
- keep QIDI/Clipper compatibility quirks frozen by regression tests;
- never replace a source oddity with a cleaner algorithm without an independent source oracle.

## Other major open areas

All top-level gates remain **OPEN**. Major remaining work includes full classic process integration, full Arachne wall generation, fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft toolpaths, full G-code state/templates/travel/retract/cooling/multimaterial behavior, project/profile round trips and STEP/source-enabled import formats, scene/editor and Preview parity, Device/cloud/P2P/account/camera/HMS/firmware, calibration, desktop integration, full UI/localization/accessibility, runtime asset publication/verification, and exhaustive reference/differential tests.

## Working discipline

For each source batch: identify exact source functions and dependencies; port literal behavior; add source-oracle/translated/differential tests; confirm `.github/workflows/flutter-parity.yml` on pinned Flutter 3.47.2; do not weaken analyzer/tests; then update migration ledgers and this handoff. A scoped passing test never closes a top-level product gate.
