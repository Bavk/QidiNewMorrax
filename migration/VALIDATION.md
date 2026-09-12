# Validation record — strict 1:1 rewrite

This file records only work that has actually executed. Acceptance authority remains [`PARITY_CONTRACT.md`](PARITY_CONTRACT.md); a passing subset does not close a top-level application gate.

## Input identity / loss-prevention baseline

- Supplied archive: `QidiFlow-2.07.02.60-Pass28-Device-Reference-Redesign-Clean(1).zip`.
- Archive SHA-256 from the initial audit: `821ed379d65916df32f5d031bd583bc724ce72f4d229447adc61280701e4d57d`.
- Extracted source files inventoried: **8,632**.
- Earlier local runtime-asset audit: **3,657/3,657** copied runtime entries matched source SHA-256; full publication/reverification from GitHub/release inputs is still open.

## Current executed Flutter/Dart checkpoint — 2026-09-12

Pinned toolchain:

- Flutter `3.47.2`;
- Dart `3.13.2`;
- Ubuntu 24.04 hosted runner.

GitHub Actions `.github/workflows/flutter-parity.yml` run `34693713324` (#254) executed code commit `5a4d8b65e177ce6fe196594c4263d3f962a90422` and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **`+340: All tests passed!`**;
- job conclusion — **success**.

## Classic final fill-boundary evidence

Run #252 (`34691194040`) first validated `SourceClassicFillBoundary2` at **333/333** tests, and #254 re-executed the same fixtures. The represented evidence covers:

- no-perimeter, one-perimeter and two-or-more-perimeter inset choices;
- absolute `infill_wall_overlap`;
- percentage `infill_wall_overlap` using the pinned `FloatOrPercent::get_abs_value()` arithmetic;
- the C++ floating-point/truncation oracle where the represented 20% case produces **7999** source units rather than an idealized 8000;
- `min_perimeter_infill_spacing = coord_t(solid_infill_spacing * (1 - INSET_OVERLAP_TOLERANCE))`;
- source `offset2_ex()` collapse for `infill_exp`;
- represented `stInternal` fill-surface output;
- both `fill_no_overlap` source branches;
- top-fill growth/intersection/union consumer behavior;
- odd source-unit spacing truncation.

Run #251 initially failed only the percent-overlap expectation. The implementation had produced 7999; a standalone C++ oracle of the literal pinned formula confirmed 7999, so the test was corrected to the source result rather than changing the implementation.

## Classic `TopOneWallType::Alltop` producer evidence

Run #254 is the first green run containing `SourceClassicTopFillAllTop2`. Its seven new fixtures cover:

- source gate behavior for `loop_number == 0`;
- pinned scalar order for configured `wall_loops=2`: `offset_top_surface = 94500`, `min_width_top_surface = 4500`, and represented final fill-clip delta `0` under the test flows;
- non-null empty upper slices treating the represented island as entirely top surface;
- `temp_gap` re-union when gap fill is enabled;
- non-null empty lower slices exercising the bridge-checker path and source `1.5 * max(ext_perimeter_spacing, perimeter_width)` growth;
- literal `clip_clipper_polygons_with_subject_bbox()` pruning of a far-away upper polygon;
- composition of produced `top_fills` / `fill_clip` into `SourceClassicFillBoundary2`.

The implementation preserves source numeric boundaries relevant to this batch:

- `SCALING_FACTOR = 0.00001` and `SCALED_EPSILON = 10`;
- configured `wall_loops` is distinct from current `loop_number`;
- scale → unscale → multiply → scale/truncate order for `offset_top_surface`;
- implicit `float` delta conversion at `offset()` / `offset_ex()` call boundaries;
- represented `ApplySafetyOffset::Yes` clip growth by `ClipperSafetyOffset == 10` source units;
- sparse-infill half-width remains a macro-style double expression before the final float offset call.

### Why #253 failed before #254

Run #253 (`34693536191`) did not expose a source-semantic or geometry mismatch. Analyzer found one compile error in the newly added helper: `SourcePolygon2` has a non-const constructor, but the short-polygon return used `const SourcePolygon2([])`. That prevented the new test file from loading while the previous 333 tests still ran. Commit `5a4d8b65e177ce6fe196594c4263d3f962a90422` changed only that expression to `SourcePolygon2(const [])`. Run #254 then passed all **340/340** tests with the original new geometry/scalar expectations unchanged.

## Earlier Arachne / fuzzy evidence retained

Run #254 re-executed all previously green Arachne/fuzzy evidence from run #249 and later checkpoints:

- one shared Classic `random_value()` stream and direct MT19937/libstdc++ double fixtures;
- direct libnoise v1.0.0 value/gradient/vector-table/Perlin/Billow/RidgedMulti/Voronoi behavior;
- scale clamp, octave/persistence, Voronoi displacement and `slice_z` inputs;
- Polygon/Polyline fuzzy sampling/casts/fallback;
- direct source ZAttributes LineSegmentation plus Dart Clipper2 compatibility normalization;
- painted Polygon/Polyline region composition;
- source-shaped Arachne `ExtrusionJunction` / `ExtrusionLine` subset;
- seeded C++ `Displacement`, `Extrusion`, `Combined` position/width goldens;
- Arachne width interpolation, full-cover path, painted-region fuzzy application and seam behavior;
- recursive classic fuzzy traversal and region-aware overhang slowdown policy.

The same run also re-executed the previously green represented subsets of source geometry, Polyline/ArcFitter/Circle, ThickPolyline, Boost.Polygon/Voronoi, MedialAxis, Clipper compatibility, Flow, Extruder, Surface, ExtrusionEntity, variable-width/covered-width geometry, source-style G-code path formatting/emission, classic perimeter shell/thin-wall/gap-fill/nesting/chaining/wall sequence, lower-support generation, and no-speed/speed-graded overhang traversal/pipeline behavior.

## Not proven by this checkpoint

Run #254 does **not** prove:

- exact source-order integration of the pre-shell one-wall gate, the verified `Alltop` producer, subsequent shell-loop collapse, gap-fill mutation and final fill-boundary block as one `process_classic()` execution;
- full Arachne wall generation around the represented fuzzy helper;
- every pathological overlap/hole/degenerate LineSegmentation or top-fill clipping case;
- exact platform-level `random_device` / thread-id nondeterministic seed selection;
- complete Clipper/Boost regression spaces beyond represented fixtures;
- complete G-code state/templates/travel/retraction/cooling/acceleration/multimaterial behavior;
- all fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft algorithms;
- complete project/profile persistence, STEP/source-enabled formats, scene/editor, Preview, Device/cloud/P2P, calibration, desktop integration or full UI parity;
- hardware-in-the-loop printer behavior;
- remote publication and SHA verification of every runtime asset;
- release builds/installers across all supported platforms.

## Completion truth

**Zero top-level parity gates are closed.** Individual source behaviors may be marked `parity_verified` only for the exact scope covered above. Broader modules containing unported branches remain `port_started` or `pending`.
