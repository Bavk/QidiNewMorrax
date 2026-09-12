# Validation record — strict 1:1 rewrite

This file records only work that has actually executed. The acceptance authority remains [`PARITY_CONTRACT.md`](PARITY_CONTRACT.md); a passing subset does not close a top-level application gate.

## Input identity / loss-prevention baseline

- Supplied archive: `QidiFlow-2.07.02.60-Pass28-Device-Reference-Redesign-Clean(1).zip`.
- Archive SHA-256 from the initial audit: `821ed379d65916df32f5d031bd583bc724ce72f4d229447adc61280701e4d57d`.
- Extracted source files inventoried: **8,632**.
- Previous local runtime-asset integrity pass: **3,657/3,657** entries marked as copied runtime assets matched source SHA-256; 0 missing, 0 mismatches.
- Full publication of those binary assets into GitHub is still open. The `.gitkeep` files used to keep declared asset directories present in CI are not asset-parity evidence.

## Executed Flutter/Dart checkpoint — 2026-09-12

Pinned toolchain:

- Flutter `3.47.2`;
- Dart `3.13.2`;
- Ubuntu 24.04 hosted runner.

### Current normal parity run

GitHub Actions `.github/workflows/flutter-parity.yml` run `34681600348` (#185) executed on code commit `4a235117a905bf94fe7732031b1b3b8a7556867b` and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **`+225: All tests passed!`**;
- job conclusion — **success**.

This checkpoint includes the represented classic loop tree, source shortest-path chaining, recursive traversal, wall-sequence adjustment, QIDI Clipper2 open-subject clipping, no-speed overhang splitting and the end-to-end overhang-aware classic source pipeline.

### Independently green intermediate source milestones

Run `34681547786` (#183) completed successfully with **224/224** after integrating supported/unsupported overhang splitting into recursive classic traversal and freezing the Clipper2 duplicated-start seam behavior.

Run `34680042259` (#172) completed successfully for the source classic wall-sequence helper and its ordering quirks.

Run `34678782013` (#147) completed successfully after wiring classic thin-wall MedialAxis output through `SourceVariableWidth2` using the source external perimeter `Flow`.

Run `34678922719` (#150) completed successfully after adding source integer-domain open-polyline offset and `ExtrusionEntity::polygons_covered_by_width()`-shaped dispatch. Its exact open-butt fixture checks a 1 mm path at width 0.4 mm plus 10 source units of epsilon.

Earlier Boost/Voronoi and Clipper compatibility repairs were also re-exercised by all of these later green full-suite runs; no fixture was weakened or skipped.

## What the 225-test suite currently proves

The passing suite contains source-derived, source-formula, or Boost/Clipper oracle coverage for the represented subsets of:

- integer `coord_t` Point/Line geometry and rounding-sensitive Line behavior;
- source `Polygon::contains()` / PointInPolygon boundary semantics used by loop nesting;
- QIDI `Polyline` append/clip/extend plus ArcFitter / fitting metadata reverse/split/clip behavior;
- Circle/ArcSegment and arc math;
- `ThickPolyline` width cardinality, reverse, `rebase_at`, and width indexing quirks;
- Boost.Polygon 1.83 robust numeric helpers, site/circle predicates, PPP/PPS/PSS/SSS circle formation, Fortune construction, topology adaptation, and known regression inputs;
- QIDI Voronoi issue detection, repair angles/remapping, annotation and default direct builder behavior;
- MedialAxis edge validation/traversal plus `ExPolygon::medial_axis()` post-processing;
- Clipper/ClipperUtils translated boolean and offset fixtures, including Clipper1 miter-limit and positive-hole reconstruction compatibility at the Dart Clipper2 adapter boundary;
- source open-polyline square/open-butt offset used by extrusion covered-width geometry;
- QIDI `Clipper2Utils.cpp` open-subject intersection/difference in source integer coordinates, including the duplicated-start seam split for a closed perimeter represented as an open polyline;
- Flow formulas/config fallback behavior;
- Extruder state/math and QIDI variant resolution;
- Surface classification/copy/assignment quirks;
- ExtrusionEntity/Path/MultiPath/Loop/Collection represented semantics;
- QIDI/libslic3r variable-width `ThickPolyline` conversion;
- represented `polygons_covered_by_width()` dispatch and exact integer-coordinate path coverage;
- source-style G-code formatter and linear/arc extrusion-path emission subset;
- classic perimeter onion-shell formulas and QIDI smaller-width outer-loop behavior;
- classic `detect_thin_wall` through MedialAxis **and** variable-width external-perimeter extrusion conversion;
- classic gap detection on the extra shell iteration, source float32 offset casts, width-limited gap region construction, closed-polygon Douglas–Peucker, MedialAxis, configured length filtering, gap-fill variable-width extrusion conversion, and covered-width subtraction from the residual region;
- source structural loop nesting and `is_internal_contour()` behavior;
- structural loop → `ExtrusionLoop2` conversion with source roles, loop-role flags, Flow selection and split-at-first-point semantics;
- source-shaped `chain_extrusion_entities()` graph/reversal behavior and thin-wall insertion into the same nearest-neighbor collection;
- recursive contour/hole child ordering and winding normalization in classic `traverse_loops()`;
- source wall-sequence postprocessing for outer-inner, first-layer outer-only brim and inner-outer-inner, including the trailing-second-wall drop quirk;
- the represented `detect_overhang_wall` branch when overhang-speed grading is disabled: supported/unsupported clipping, role/flow selection, bridge-wall degree 5/6 classification, path reordering and raft-layer activation condition;
- end-to-end classic shell → loop tree → overhang split → recursive traversal → wall-sequence composition for that branch;
- existing linear-infill and basic writer fixtures.

## What is not proven by this checkpoint

This checkpoint does **not** establish full application parity. In particular it does not prove:

- the full source Clipper/ClipperUtils regression space beyond translated/current-consumer fixtures;
- automatic source `generate_lower_polygons_series(width)` construction from lower slices, including source float32 arithmetic and exact positive/negative polygon-offset behavior;
- `detect_overhang_degree()` intermediate overhang-speed grades 1–4 and distance-boundary math;
- fuzzy-skin transformation and `fuzzy_skin_allows_overhang_slowdown()` interaction;
- complete remaining `PerimeterGenerator::process_classic()` fill-surface/fill-no-overlap and later stages, or Arachne;
- complete native G-code state/templates/travel/retraction/cooling/acceleration/multi-material behavior;
- all fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft algorithms;
- complete project/profile persistence, STEP/Assimp-enabled formats, or every repair/warning path;
- complete scene/editor, Preview, Device/cloud/P2P, calibration, desktop integration, or UI workflow parity;
- hardware-in-the-loop printer behavior;
- remote publication and SHA verification of every runtime asset;
- release builds/installers on every supported desktop platform.

## Completion truth

**Zero top-level parity gates are closed.** Individual, explicitly scoped source behaviors may be marked `parity_verified` where the translated/oracle tests above cover that exact row. Broader modules that contain unported branches remain `port_started`.
