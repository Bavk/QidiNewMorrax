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

GitHub Actions `.github/workflows/flutter-parity.yml` run `34714922159` (#317) executed code commit `10f642e0d3952b61eefe4c8bdda2fcd909a4eba2` and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **`+551: All tests passed!`**;
- job conclusion — **success**.

## Arachne post-construction skeletal runtime evidence

Run #317 is the first green checkpoint where the represented `SkeletalTrapezoidation::generateToolpaths()` runtime is composed as one source-order entrypoint after the skeletal graph already exists.

The validated top-level order is:

1. `updateIsCentral()`;
2. `filterCentral(central_filter_dist)`;
3. optional `filterOuterCentral()`;
4. `updateBeadCount()`;
5. `filterNoncentralRegions()`;
6. `generateTransitioningRibs()`;
7. `generateExtraRibs()`;
8. `generateSegments()`.

The two top-level fixtures in #317 prove both the normal runtime composition and that `filter_outermost_central_edges` executes at the pinned source position between central filtering and bead-count assignment.

`generateTransitioningRibs()` is separately covered as the source four-stage sequence `generateTransitionMids → filterTransitionMids → generateAllTransitionEnds → applyTransitions`.

`generateSegments()` is separately covered as seven represented source-order stages:

- upward quad-mid collection / source comparator ordering;
- node beading materialization and source three-argument interpolation;
- upward beading propagation;
- downward propagation, lazy nearest/create lookup and switching-radius interpolation;
- extrusion-junction generation;
- junction connection into variable-width lines;
- isolated local-maximum odd single beads.

Important executed source seams include:

- `scaled<coord_t>(0.1) == 10000`;
- `scaled<coord_t>(0.02) == 2000`;
- literal double/truncation quirks `scaled<coord_t>(0.010) == 999` and `scaled<coord_t>(0.005) == 499`;
- strict versus inclusive snap/filter comparisons;
- source float32 transition/interpolation ratios;
- integer coordinate normals/interpolation/truncation;
- `BeadingPropagation` assignment mutating the existing shared object identity, matching C++ reference/shared_ptr semantics;
- stable transition sorting / Dart list-mutation compatibility seams;
- six-point local-max circle with integer `width / 8`, float angle and source point rounding.

## Arachne `WallToolPaths` dependency evidence retained

The #317 suite also re-executed all represented dependencies below `WallToolPaths::generate()`:

- `WallToolPathsParams` and constructor source float/scaled state;
- standalone simplifier;
- prepared-outline offset/repair/degenerate/collinear/small-area chain fixtures;
- scalar pre-beading width/threshold input casts;
- beading strategy implementations and factory wrapper order;
- half-edge graph model, pointy-end separation, graph mutation helpers and `collapseSmallEdges()`;
- fuzzy `ExtrusionLine` / LineSegmentation consumers.

This does **not** prove full Arachne walls from polygons. The still-open constructor path is real polygon segments → Boost Voronoi diagram → Arachne skeletal half-edge graph.

## Ordered classic surface → extrusion evidence retained

Run #317 re-executed the existing classic evidence, including source `Surface` copy semantics; `BridgeDetector` / `process_no_bridge`; conditional simplification and island order; per-surface wall accounting; top-one-wall / Alltop; thin-wall/gap-fill/final fill boundaries; recursive fuzzy/overhang traversal; shared fuzzy RNG; wall sequence; QIDI `outwall_paths` / `LoopNode` metadata; and non-null empty lower-slice semantics.

## Earlier Arachne / fuzzy evidence retained

Run #317 re-executed shared Classic `random_value()` and MT19937/libstdc++ fixtures; pinned libnoise; Polygon/Polyline fuzzy geometry and painted regions; source-shaped Arachne `ExtrusionJunction` / `ExtrusionLine`; seeded C++ `Displacement`, `Extrusion`, `Combined` goldens; Arachne width interpolation and region-aware fuzzy composition.

The same run re-executed represented source geometry, ArcFitter/Circle, ThickPolyline, direct Boost.Polygon/Voronoi, MedialAxis, Clipper compatibility, Flow, Extruder, Surface, ExtrusionEntity, variable-width/covered-width and G-code path formatting/emission subsets.

## Next audited Arachne boundary: `constructFromPolygons()`

Pinned source `SkeletalTrapezoidation::constructFromPolygons()` remains the next missing integration seam. The audited source order is:

1. create polygon `Segment` entries and construct the Boost Voronoi diagram;
2. for each cell derive source start/end range (`computePointCellRange()` for point cells or `compute_segment_cell_range()` for segment cells);
3. apply source hole-compensation selection from polygon index;
4. `transferEdge()` the starting, middle and ending Voronoi edges, inserting ribs at the exact source positions;
5. `transferEdge()` either reuses already-transferred twin chains or discretizes the first side;
6. `discretize()` handles straight/secondary, point-line parabola and point-point source branches;
7. set boundary-node distance-to-boundary to zero;
8. `separatePointyQuadEndNodes()`;
9. `collapseSmallEdges()`;
10. normalize chain-start `incident_edge` pointers.

Existing Dart initialization helpers intentionally begin **after** this transfer and therefore do not close it.

## Not proven by this checkpoint

Run #317 does **not** prove:

- `SkeletalTrapezoidation::constructFromPolygons()` or the real Voronoi-to-half-edge transfer;
- full polygon → `WallToolPaths::generate()` → generated Arachne wall output;
- full `PerimeterGenerator::process_arachne()` integration / one-wall / separate-wall branches;
- downstream inter-layer QIDI loop-node matching / vertical wall speed-control consumption;
- every pathological geometry topology beyond represented fixtures;
- exact platform-level `random_device` / thread-id nondeterministic seed selection;
- complete G-code state/templates/travel/retraction/cooling/acceleration/multimaterial behavior;
- all later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft algorithms;
- complete project/profile persistence, STEP/source-enabled formats, scene/editor, Preview, Device/cloud/P2P, calibration, desktop integration or full UI parity;
- hardware-in-the-loop printer behavior;
- remote publication and SHA verification of every runtime asset;
- release builds/installers across all supported platforms.

## Completion truth

**Zero top-level parity gates are closed.** Individual source behaviors may be marked `parity_verified` only for the exact scope covered above. Broader modules containing unported branches remain `port_started` or `pending`.
