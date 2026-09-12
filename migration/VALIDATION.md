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

GitHub Actions `.github/workflows/flutter-parity.yml` run `34682700807` (#203) executed on code commit `b6809d50912e5135a3d4851177093934a715adf9` and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **`+248: All tests passed!`**;
- job conclusion — **success**.

This checkpoint includes the represented classic lower-support-series generation, source distance boundaries, continuous/intermediate overhang degree grading, speed/no-speed splitter branches, recursive traversal, and raw-lower-slices end-to-end speed-graded pipeline in addition to all earlier green geometry/slicer fixtures.

### Independently green intermediate source milestones

- run `34682605150` (#201): speed-graded recursive traversal, including selected external/smaller/internal boundary handling;
- run `34682507521` (#199): speed-grading splitter branch independently green;
- run `34682411840` (#197): standalone `detect_overhang_degree()` helpers green after freezing source IEEE-754 terrace behavior;
- run `34682165435` (#194): automatic overhang settings/pipeline from raw lower slices green;
- run `34681985037` (#191): **231/231**, source lower-overhang-series generation and `dist_boundary()` green;
- run `34681547786` (#183): **224/224**, no-speed overhang split integrated into recursive traversal and Clipper2 duplicated-start seam frozen;
- run `34680042259` (#172): source classic wall-sequence helper and ordering quirks green;
- run `34678782013` (#147): thin-wall MedialAxis output wired through `SourceVariableWidth2` using source external perimeter `Flow`;
- run `34678922719` (#150): source integer-domain open-polyline offset and `polygons_covered_by_width()` dispatch green.

Earlier Boost/Voronoi and Clipper compatibility repairs were re-exercised by all later full-suite runs; no fixture was weakened or skipped.

## What the 248-test suite currently proves

The passing suite contains source-derived, source-formula, or Boost/Clipper oracle coverage for the represented subsets of:

- integer `coord_t` Point/Line geometry and rounding-sensitive Line behavior;
- source `Polygon::contains()` / PointInPolygon boundary semantics used by loop nesting;
- QIDI `Polyline` append/clip/extend plus ArcFitter / fitting metadata reverse/split/clip behavior;
- Circle/ArcSegment and arc math;
- `ThickPolyline` width cardinality, reverse, `rebase_at`, and width indexing quirks;
- Boost.Polygon 1.83 robust numeric helpers, site/circle predicates, PPP/PPS/PSS/SSS circle formation, Fortune construction, topology adaptation, and known regression inputs;
- QIDI Voronoi issue detection, repair angles/remapping, annotation and default direct builder behavior;
- MedialAxis edge validation/traversal plus `ExPolygon::medial_axis()` post-processing;
- translated Clipper boolean/offset fixtures, Clipper1 miter-limit and positive-hole compatibility, open-line covered-width offset, and QIDI Clipper2 open-subject intersection/difference including duplicated-start seam behavior;
- source closed-polygon offset behavior required by classic lower-support generation for represented box/hole fixtures, including source float32 deltas and QIDI Clipper1 short-edge prefilter;
- Flow formulas/config fallback behavior;
- Extruder state/math and QIDI variant resolution;
- Surface classification/copy/assignment quirks;
- ExtrusionEntity/Path/MultiPath/Loop/Collection represented semantics;
- QIDI/libslic3r variable-width `ThickPolyline` conversion and covered-width geometry;
- source-style G-code formatter and linear/arc extrusion-path emission subset;
- classic perimeter onion-shell formulas, QIDI smaller-width outer-loop behavior, thin-wall conversion and gap-fill pipeline;
- source loop nesting, shortest-path chaining, recursive contour/hole ordering/winding and wall-sequence postprocessing;
- automatic `generate_lower_polygons_series(width)` for internal/external/smaller-external walls, including source float32 arithmetic, scaled-width reuse, hole winding/delta, positive/negative source-coordinate offsets and `dist_boundary(width)`;
- no-speed supported/unsupported overhang splitting, bridge-wall degree 5/6 classification, path reordering and raft activation boundary;
- classic speed grading: 0.6 mm SplitLines endpoint cuts, source Point/lrint split coordinates, float32 distance query/return boundary, non-uniform `{0,10,25,50,75,100}` mapping, smoothing, binary-double 0.1 terraces, adjacent-run merge, and extrusion payloads;
- recursive speed-graded traversal with correct external/smaller/internal series+boundary selection and customize flags;
- end-to-end raw lower slices → lower-series/boundaries → zero/intermediate/unsupported split → recursive traversal → wall sequence;
- existing linear-infill and basic writer fixtures.

## What is not proven by this checkpoint

This checkpoint does **not** establish full application parity. In particular it does not prove:

- the full source Clipper/ClipperUtils regression space beyond translated/current-consumer fixtures;
- fuzzy-skin policy, geometry, random/deterministic noise modes, per-region line segmentation, or `fuzzy_skin_allows_overhang_slowdown()` interaction;
- remaining lower-polygon bbox-clipping/performance wrappers where they may have observable source effects;
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
