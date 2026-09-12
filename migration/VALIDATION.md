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

GitHub Actions `.github/workflows/flutter-parity.yml` run `34698420757` (#278) executed code commit `69780005918e63a58485ebf7caf645214eacc37b` and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **`+395: All tests passed!`**;
- job conclusion — **success**.

## Arachne `WallToolPaths` foundation evidence

Run #278 is the first green checkpoint for the source-shaped foundation immediately below pinned `PerimeterGenerator::process_arachne()`.

Eight new tests passed for `source_arachne_wall_tool_paths.dart`:

- pinned `scaled<coord_t>(double)` constant truncation quirks: `0.5 → 49999`, `0.025 → 2500`, `2.0 → 199999`, `0.01 → 999`, `0.005 → 499`;
- exact `process_arachne()` percentage × minimum-nozzle assignments stored through a source `float`/IEEE float32 boundary;
- `WallToolPaths` constructor scaling from stored float parameters using float arithmetic and coord truncation;
- `<3`-vertex simplifier clear behavior;
- exactly-three-vertex identity behavior;
- exact collinear vertex removal;
- pinned 5-micron near-collinear deletion behavior;
- vector wrapper removal of polygons simplified below three vertices.

The represented constructor state also freezes `fill_outline_gaps == true`, `small_area_length = bead_width_0 / 2.` and `toolpaths_generated=false`.

This checkpoint does **not** contain generated Arachne walls. It does not yet port the complete prepared-outline repair/union chain, beading strategies or `SkeletalTrapezoidation`.

## Ordered classic surface → extrusion evidence retained

Run #278 re-executed the complete 387-test checkpoint from #276, including:

- `chain_expolygons()` order preserved to nested outer `loops` collections;
- per-island classic fuzzy/overhang recursive traversal and wall-sequence handling;
- one shared fuzzy RNG across ordered islands;
- non-null empty lower-slice overhang semantics;
- QIDI `outwall_paths`, literal `Point::is_in_lines`, global `LoopNode` IDs and per-island `loop_node_range` producer behavior.

It also re-executed all earlier classic preprocessing/fill evidence: pinned `BridgeDetector`, `process_no_bridge`, conditional surface simplification, extra-perimeter accounting, top-one-wall/Alltop, thin-wall/gap-fill, final fill boundary and the source **7999** overlap quirk.

## Earlier Arachne / fuzzy evidence retained

Run #278 re-executed all previously green Arachne/fuzzy evidence:

- shared Classic `random_value()` stream and MT19937/libstdc++ fixtures;
- pinned libnoise value/gradient/Perlin/Billow/RidgedMulti/Voronoi behavior;
- Polygon/Polyline fuzzy geometry and painted-region LineSegmentation;
- source-shaped Arachne `ExtrusionJunction` / `ExtrusionLine` subset;
- seeded C++ `Displacement`, `Extrusion`, `Combined` goldens;
- Arachne width interpolation and region-aware fuzzy composition.

The same run re-executed represented source geometry, ArcFitter/Circle, ThickPolyline, Boost.Polygon/Voronoi, MedialAxis, Clipper compatibility, Flow, Extruder, Surface, ExtrusionEntity, variable-width/covered-width and G-code path formatting/emission subsets.

## Next audited Arachne boundary

Pinned `WallToolPaths::generate()` continues from the now-verified constructor/simplifier through this prepared-outline chain:

1. triple epsilon offset: `offset(-epsilon) → offset(+2*epsilon) → offset(-epsilon)`;
2. `simplify()`;
3. `fixSelfIntersections()`;
4. `removeDegenerateVerts()`;
5. `removeColinearEdges(..., scaled<double>(0.005))`;
6. second `fixSelfIntersections()` and `removeDegenerateVerts()`;
7. `removeSmallAreas(..., small_area_length², false)`;
8. `union_()`;
9. source `outline_size_change` update after each mutation and `area(prepared_outline) <= 0` early return.

After that come rounded-rectangle extrusion width calculations, wall-transition/split/add thresholds, `BeadingStrategyFactory` composition, then `SkeletalTrapezoidation`. These are the next real dependencies; no full Arachne wall parity is claimed yet.

## Not proven by this checkpoint

Run #278 does **not** prove:

- the complete prepared-outline cleanup/union chain listed above;
- `BeadingStrategyFactory`, individual beading strategies or `SkeletalTrapezoidation`;
- full `Arachne::WallToolPaths::generate()` or `PerimeterGenerator::process_arachne()`;
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
