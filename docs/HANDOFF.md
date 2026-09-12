# Handoff — Qidi Flow strict Flutter/Dart rewrite

This repository is a **strict 1:1 reimplementation** of the supplied Qidi Flow 2.07.02.60 Pass28 application in Flutter + Dart. The old C++/wxWidgets/React application is reference material only; it must never remain a runtime backend through FFI, subprocesses, native shared libraries, hidden local services, or embedded legacy WebViews.

## Read first

1. [`../migration/PARITY_CONTRACT.md`](../migration/PARITY_CONTRACT.md) — acceptance authority.
2. [`../migration/MIGRATION_STATUS.md`](../migration/MIGRATION_STATUS.md) — current subsystem truth and next dependency order.
3. [`../migration/TRACEABILITY.md`](../migration/TRACEABILITY.md) — source → Dart → evidence ledger.
4. [`../migration/VALIDATION.md`](../migration/VALIDATION.md) — what actually executed.
5. This file — operational continuation notes.

Do not infer completion from visual similarity, a compiling app shell, or a passing common-case test. Source quirks are part of the contract.

## Current validated checkpoint — 2026-09-12

Last validated code checkpoint before this documentation batch:

- code commit: `b6809d50912e5135a3d4851177093934a715adf9` (`test: cover speed graded classic source pipeline`);
- normal workflow: `.github/workflows/flutter-parity.yml` run `34682700807` (#203);
- Flutter `3.47.2`;
- Dart `3.13.2`;
- `flutter analyze` → **No issues found!**;
- `flutter test --reporter expanded` → **248/248 passed**;
- job conclusion → **success**.

Important independently green milestones immediately before it include run #201 (`34682605150`) for speed-graded recursive traversal, #199 (`34682507521`) for the independent graded splitter, #197 (`34682411840`) for standalone `detect_overhang_degree()` helpers, #194 (`34682165435`) for automatic overhang state from raw lower slices, and #191 (`34681985037`, 231/231) for source lower-support series / `dist_boundary()`.

## Numeric/source rules that must be preserved

### libslic3r coordinates

The source slicer is not a free-form millimeter-double system:

- `SCALING_FACTOR = 0.00001` mm;
- 100000 integer source units/mm;
- `EPSILON = 1e-4`;
- `SCALED_EPSILON = 10` source units.

Rounding/truncation-sensitive algorithms must stay in source integer types (`SourcePoint2`, `SourceLine2`, `SourcePolygon2`, `SourceExPolygon2`, `SourcePolyline2`, `ThickPolyline2`) until the actual source boundary converts units.

### Boost.Polygon 1.83

The direct Dart Fortune/Voronoi port is passing the represented Boost/QIDI oracle suite. Two implementation details are especially easy to break:

- Boost `uint64_t` arithmetic and double-bit ULP comparison cannot be represented safely by signed native Dart `int` when bit 63 is crossed; the port deliberately uses `BigInt` at those boundaries.
- PPP circle formation keeps the **literal Boost 1.83 operand order** for `robust_cross_product`. Do not reorder it into a mathematically nicer cross product without a Boost oracle proving equivalence.

### Clipper compatibility

Current verified compatibility includes:

- Clipper1 miter-limit values below 2 behaving as effective 2;
- positive ExPolygon hole offsets retaining holes by explicit contour-minus-hole reconstruction;
- source-domain open-polyline square/open-butt offset used by `polygons_covered_by_width()`;
- QIDI Clipper2 `intersection_pl_2()` / `diff_pl_2()` through open subjects in source integer coordinates;
- the duplicated-start seam: a closed perimeter represented as an open polyline may produce two difference runs around the repeated first point;
- the source-coordinate closed-polygon offset subset used by lower-overhang support generation, including float32 deltas, miter limit 3, hole delta/winding reversal, negative offsets, and QIDI-patched Clipper1 `ShortestEdgeLength = abs(delta * 0.005)` filtering.

Do not remove these adapter quirks just because native Clipper2 defaults differ.

## Classic perimeter / MedialAxis checkpoint

The following source subset now works end-to-end and is covered by the 248-test suite:

- classic onion-shell inset formulas and QIDI smaller-external-width behavior;
- exact `last = offsets` source quirk;
- thin-wall Clipper → MedialAxis → `ThickPolyline2` → source variable-width extrusion path;
- classic extra-iteration gap collection, float32 offset casts, DP simplify, MedialAxis, length filter, gap-fill variable width and covered-width subtraction;
- source `Polygon::contains()` loop nesting and `is_internal_contour()` semantics;
- source-shaped `chain_extrusion_entities()` graph/reversal behavior;
- recursive `traverse_loops()` order and contour/hole winding;
- thin-wall insertion into the same nearest-neighbor collection;
- post-traversal wall sequence for `OuterInner`, first-layer outer-only brim and `InnerOuterInner`, including the source trailing-second-wall drop quirk;
- QIDI Clipper2 open-subject supported/unsupported overhang splitting;
- automatic `generate_lower_polygons_series(width)` for internal/external/smaller-external walls, including source float32 arithmetic, source scaling, scaled-width reuse, hole delta/winding and source short-edge filtering;
- exact `dist_boundary(width)` calculations and per-wall boundary selection;
- no-speed overhang branch with degree 5/6 bridge-wall classification and overhang flow;
- speed grading through `prepare_split_polylines`, 0.6 mm endpoint cuts, source Point/lrint coordinates, float32 distance queries/returns, the non-uniform `{0,10,25,50,75,100}` map, smoothing and binary-double 0.1 terracing;
- intermediate graded paths retain the normal wall role/flow while fully unsupported paths switch to `erOverhangPerimeter` + overhang flow;
- recursive speed-graded traversal with external/smaller/internal series+boundary selection and customize flags;
- end-to-end raw lower slices → lower-series/boundaries → zero/intermediate/unsupported split → recursive traversal → wall sequence.

Raw `thinWalls` and `gapFillPolylines` remain deliberately retained in `ClassicPerimeterResult` as regression evidence in addition to converted extrusion entities.

## Immediate next code task — fuzzy skin policy first

The next unresolved classic overhang dependency is fuzzy skin. Do **not** jump directly to random displacement geometry; first port and verify the source policy/identity layer.

Source files are pinned in BambuStudio commit `f2b55a5a83f266cf56e06c7943a81a08bebb7fad`:

- `src/libslic3r/FuzzySkin.cpp`;
- `src/libslic3r/FuzzySkin.hpp`;
- `src/libslic3r/PrintConfig.hpp`;
- classic `traverse_loops()` in `PerimeterGenerator.cpp`.

### Exact enum/value rules

`FuzzySkinType` source order:

1. `None`;
2. `External`;
3. `All`;
4. `AllWalls`;
5. `Disabled_fuzzy`;
6. `Count` sentinel.

`NoiseType` source order:

1. `Perlin`;
2. `Billow`;
3. `RidgedMultifractal`;
4. `Voronoi`;
5. `Uniform`;
6. `Count` sentinel.

`FuzzySkinMode` is `None, FuzzySingle, FuzzyAll, FuzzyExternal, FuzzyHole, Smooth, Mixed`.

### `should_fuzzify()` source behavior

- `None` and `Disabled_fuzzy` always return false;
- `AllWalls` always returns true;
- `External` fuzzifies only contour depth 0 (`current_perimeter == 0 && is_contour`);
- `All` fuzzifies contour/hole at depth 0 but not deeper perimeters.

At the config wrapper level, `layer_id == 0 && !fuzzy_skin_first_layer` returns the original polygon unchanged before geometry transformation.

### Critical slowdown quirk

Source:

```cpp
return fs == FuzzySkinType::Disabled_fuzzy ||
       (fs == FuzzySkinType::None && perimeter_regions->empty());
```

Therefore `None` and `Disabled_fuzzy` both leave the polygon unchanged, but they are **not equivalent** for overhang speed:

- `Disabled_fuzzy` always allows overhang slowdown;
- `None` allows slowdown only when `perimeter_regions` is empty;
- actual fuzzy modes do not allow slowdown through this helper.

This distinction should be the first regression fixture.

### Geometry after policy is green

Source `fuzzy_polyline` uses:

- `min_dist = 0.75 * point_distance`;
- random point-spacing addition in `[0, 0.5 * point_distance]`;
- carried `distance_left_over`;
- source `Point(double,double)` / `lrint` placement;
- displacement perpendicular to the segment;
- `remove_same_neighbor()` after polygon fuzzing.

`Uniform` noise is nondeterministic (`std::mt19937(std::random_device{})`), so do not invent a stable golden. Introduce an explicit RNG seam/source-equivalent injection before testing it. Perlin/Billow/RidgedMultifractal/Voronoi are deterministic from coordinates and `slice_z` and can be ported with deterministic fixtures once the policy layer is green.

If `perimeter_regions` is non-empty, source uses line segmentation and per-region fuzzy config. Do not silently fuzzify the whole loop; port that segmentation before claiming the branch.

## Current represented parity evidence

The 248-test suite currently covers explicitly scoped subsets of Point/Line/Polygon geometry; Polyline/ArcFitter; Circle/ArcSegment; ThickPolyline; Boost robust predicates/Fortune/Voronoi; MedialAxis; translated Clipper behavior; Flow; Extruder; Surface; ExtrusionEntity; source variable-width and covered-width geometry; source-style G-code formatting/path emission; and the represented classic perimeter shell/thin-wall/gap-fill/nesting/chaining/wall-sequence/lower-support/no-speed and speed-graded overhang pipeline.

These are **scoped parity claims only**. All top-level product gates remain open.

## Major open areas

- fuzzy-skin policy, geometry/noise and perimeter-region segmentation;
- remaining classic fill-surface/fill-no-overlap and later stages;
- Arachne;
- full fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft toolpaths;
- complete native G-code templates/state/travel/retract/cooling/acceleration/multi-material behavior;
- complete project/profile persistence, STEP and source-enabled import formats;
- scene/editor and full Preview parity;
- full Device/cloud/P2P/account/camera/HMS/firmware flows and hardware-in-loop validation;
- all calibration workflows;
- desktop integrations/installers/updates/single-instance/file-association behavior;
- complete source UI/state/localization/accessibility/visual parity;
- exhaustive source/reference/differential tests.

## Runtime asset truth

Earlier local migration work verified 3,657/3,657 copied runtime entries against source SHA-256. The **GitHub repository has not yet published and re-verified the complete real runtime asset set**. Some declared asset directories contain `.gitkeep` solely so Flutter CI can resolve the directory declarations.

Therefore:

- do not call assets complete;
- do not treat `.gitkeep` as migrated content;
- do not remove source asset declarations merely to silence tooling;
- before release parity, publish the actual bytes and verify SHA-256 again from repository/release inputs.

## CI / working discipline

For every meaningful source batch:

1. identify the exact source functions and dependent types/constants;
2. port literal behavior, including odd branches/rounding/order;
3. add translated, differential, or source-oracle tests;
4. run/confirm `.github/workflows/flutter-parity.yml` on pinned Flutter 3.47.2;
5. do not weaken analyzer or tests to make CI green;
6. update `MIGRATION_STATUS.md`, `TRACEABILITY.md`, `VALIDATION.md`, and this handoff when scope/evidence/next dependency changes;
7. never promote a top-level gate until every required branch and reference test for that gate is complete.

If a future edit breaks Boost/Voronoi or Clipper fixtures, assume the port changed source semantics until proven otherwise; do not rewrite goldens to fit the Dart output without an independent C++/source oracle.
