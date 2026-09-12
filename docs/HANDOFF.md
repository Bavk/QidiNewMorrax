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

- code commit: `4a235117a905bf94fe7732031b1b3b8a7556867b` (`test: cover overhang-aware classic source pipeline`);
- normal workflow: `.github/workflows/flutter-parity.yml` run `34681600348` (#185);
- Flutter `3.47.2`;
- Dart `3.13.2`;
- `flutter analyze` → **No issues found!**;
- `flutter test --reporter expanded` → **225/225 passed**;
- job conclusion → **success**.

Important independently green milestones immediately before it include run `34681547786` (#183, 224/224) for open-subject Clipper2 seam + no-speed overhang traversal, run `34680042259` (#172) for source wall-sequence behavior, thin-wall → variable-width run `34678782013` (#147), and covered-width geometry run `34678922719` (#150).

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

The square segment full half-edge golden, extreme-int32 circle cases, known Voronoi regressions, QIDI repair-angle sequence and annotation are green.

### Clipper compatibility

The project uses pure-Dart Clipper2 behind compatibility adapters while QIDI/libslic3r mixes Clipper 6.x wrappers and QIDI Clipper2Utils. Current verified compatibility includes:

- Clipper1 miter-limit values below 2 behaving as effective 2;
- positive ExPolygon hole offsets retaining holes by explicit contour-minus-hole reconstruction;
- translated constant-offset/basic boolean fixtures;
- source-domain open-polyline offset used by `ExtrusionPath::polygons_covered_by_width()`: square joins, open-butt ends, non-zero union, and no millimeter round trip;
- QIDI Clipper2 `intersection_pl_2()` / `diff_pl_2()` through open subjects in source integer coordinates;
- the duplicated-start seam is intentional: a closed perimeter represented as an open polyline can produce two difference runs around the repeated first point. Do **not** merge them unless a C++ source oracle proves a different path for the exact input.

Do not remove these adapter quirks just because native Clipper2 defaults differ.

## Classic perimeter / MedialAxis checkpoint

The following source subset now works end-to-end and is covered by the 225-test suite:

- classic onion-shell inset formulas;
- QIDI smaller-external-width branch;
- exact source behavior `last = offsets` — smaller-width outer loops are output only and do **not** feed subsequent inner loops;
- source one-coordinate-unit / Clipper safety terms;
- alternate extra wall behavior;
- `detect_thin_wall` path:
  `Clipper difference/opening → SourceExPolygonMedialAxis2 → ThickPolyline2`;
- exact QIDI/libslic3r variable-width conversion from `ThickPolyline2` to extrusion entities;
- use of the same source `ext_perimeter_flow` for `nozzle/3` and thin-wall extrusion conversion;
- `ExtrusionEntity::polygons_covered_by_width()` represented path/multipath/loop/collection dispatch;
- classic gap collection on the **extra shell iteration**, source float32 casts, opening/max-width subtraction, closed-polygon Douglas–Peucker, MedialAxis, short-line filter, `variable_width(... erGapFill, solid_infill_flow ...)`, and covered-width subtraction from `last`;
- source `Polygon::contains()` / PointInPolygon semantics used by classic loop nesting;
- two source nesting passes: holes first, then contours;
- structural loop → `ExtrusionLoop2` conversion with source role, loop-role/second-perimeter bits, Flow selection and split-at-first-point behavior;
- source-shaped `chain_extrusion_entities()` constrained reversal graph, including fallback and loop-reversal suppression;
- thin-wall variable-width entities in the **same** nearest-neighbor collection, using the source far-bbox-corner start-point rule;
- recursive `traverse_loops()` order and orientation: contour children before contour; hole before children; contour CCW; hole CW;
- post-traversal wall sequence for `OuterInner`, first-layer outer-only brim, and `InnerOuterInner`, including the source quirk that trailing held second-wall entities are not re-appended;
- no-speed overhang branch: open-subject supported/unsupported clipping, supported role/flow, unsupported `erOverhangPerimeter` + overhang flow, degree 5 vs 6 `detect_bridge_wall()` classification, path reordering, customize-flag propagation, and `layer_id > raft_layers` activation;
- end-to-end shell → loop tree → overhang split → recursive traversal → wall-sequence pipeline for that represented branch.

Raw `thinWalls` and `gapFillPolylines` remain deliberately retained in `ClassicPerimeterResult` as regression evidence in addition to converted extrusion entities.

## Immediate next code task

Continue `PerimeterGenerator::process_classic()` at the next unresolved overhang dependency: **automatic lower-polygon-series generation and distance boundaries**.

Exact source behavior already located:

1. `generate_lower_polygons_series(float width)` reads the selected wall nozzle diameter and computes:
   - `start_offset = -0.5f * width`;
   - `end_offset = 0.5f * nozzle_diameter`;
   - first series offset = `start_offset + 0.5f * (end_offset - start_offset) / (overhang_sampling_number - 1)`;
   - second series offset = `end_offset`;
   - `overhang_sampling_number == 6` in the source;
2. both offsets are passed through `scale_(offset)` and then through source polygon `offset(...)` on the lower slices;
3. source width/nozzle/offset temporaries are `float`, so Dart must preserve **float32** arithmetic before scaling;
4. the first offset is commonly negative, so the Clipper1-style negative polygon-offset behavior is part of this dependency — do not silently substitute a convenient Clipper2 negative offset without source/oracle evidence;
5. `dist_boundary(width)` shares the same float calculations and returns `(0, scale_(end_offset) - degree_0)`;
6. after this is green, port `detect_overhang_degree()` for intermediate degrees 1–4;
7. then port fuzzy-skin transformation and `fuzzy_skin_allows_overhang_slowdown()` gating;
8. then continue remaining classic fill-surface/fill-no-overlap/later stages, followed by Arachne.

A useful first fixture is width `0.45 mm`, nozzle `0.4 mm`, but freeze its scaled values from exact float32/source behavior rather than from decimal intuition.

## Current represented parity evidence

The 225-test suite currently covers explicitly scoped subsets of:

- Point/Line/Polygon source geometry;
- Polyline/QIDI append/clip/extend and ArcFitter metadata;
- Circle/ArcSegment and arc helpers;
- ThickPolyline;
- Boost robust numeric helpers, predicates, circle formation and Fortune construction;
- QIDI Voronoi detection/repair/annotation;
- MedialAxis and ExPolygon post-processing;
- translated Clipper boolean/offset fixtures, covered-width open-line offset, and QIDI Clipper2 open-subject intersection/difference seam behavior;
- Flow;
- Extruder/QIDI variant resolution;
- Surface;
- ExtrusionEntity/Path/MultiPath/Loop/Collection;
- source variable-width extrusion conversion and extrusion covered-width geometry;
- source-style G-code formatting and fitting-result extrusion branch;
- classic perimeter shell, thin-wall conversion, gap-fill pipeline, loop nesting/traversal/chaining/winding/wall sequence, and no-speed supported/unsupported overhang pipeline;
- existing linear-infill/basic writer fixtures.

These are **scoped parity claims only**. All top-level product gates remain open.

## Major open areas

- automatic classic lower-layer overhang offset series and distance boundaries;
- speed-graded overhang degrees 1–4 and fuzzy-skin interaction;
- remaining classic fill-surface/fill-no-overlap and later stages;
- Arachne;
- full fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft toolpaths;
- complete native G-code templates/state/travel/retract/cooling/acceleration/multi-material behavior;
- complete project/profile persistence, STEP and source-enabled import formats;
- scene/editor parity;
- full Preview feature classification/interactions;
- full Device/cloud/P2P/account/camera/HMS/firmware flows and hardware-in-loop validation;
- all calibration workflows;
- desktop integrations, installers, updates, single-instance/file-association behavior;
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
