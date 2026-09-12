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

GitHub Actions `.github/workflows/flutter-parity.yml` run `34694164752` (#260) executed code commit `ae218afee234afa92f7ef2967d61db8485a82d5a` and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **`+351: All tests passed!`**;
- job conclusion — **success**.

## Classic source-order fill process evidence

Run #260 is the first green run containing the current represented classic per-island fill process as one composition. `SourceClassicPerimeterFillProcess2` executes the verified stages in pinned source order:

1. shell settings / pre-shell top-one-wall gate;
2. classic onion-shell generation;
3. in-loop `TopOneWallType::Alltop` immediately after the first `last = offsets`;
4. source final-wall stop, with an extra iteration only when gap discovery is required;
5. thin-wall / gap-fill processing and subtraction from `last`;
6. final `not_filled_exp` → `fill_surfaces` / `fill_no_overlap` construction.

Five end-to-end process fixtures passed in #260:

- ordinary two-wall shell feeding final fill geometry;
- topmost `upper_slices == nullptr` forcing one wall before shell generation;
- non-null empty upper slices entering Alltop and yielding the represented top-fill-only output;
- percentage wall overlap preserving the source **7999** truncation quirk end-to-end;
- zero wall loops leaving the entire represented island for fill.

## Top-one-wall shell ordering evidence

Run #258 (`34694064452`) first validated six source-order integration fixtures at **346/346** total tests, and #260 re-ran them:

- pinned `TopOneWallType` order `None, Alltop, Topmost`;
- null upper slices force one wall before shell generation;
- `only_one_wall_first_layer` affects layer zero but not layer one;
- non-null empty upper slices run Alltop inside the first shell iteration and can collapse the following inner shell;
- full upper coverage preserves the next wall;
- zero sparse infill density skips the source extra gap-discovery iteration.

Run #257 had already shown the integration code itself did not regress the prior 340-test suite before these six fixtures were added.

## Standalone Alltop producer and fill-boundary evidence

Run #254 (`34693713324`) first validated `SourceClassicTopFillAllTop2` at **340/340** total tests. Covered behavior includes source scalar order for `offset_top_surface`, `top_area_threshold`, bbox pruning, implicit float offset boundaries, represented 10-unit safety offset, `temp_gap`, lower-slice bridge merge, `top_fills`, `fill_clip`, mutated `last`, optional gap-fill re-union, and composition into the final boundary helper.

Run #252 (`34691194040`) first validated `SourceClassicFillBoundary2` at **333/333** total tests. It covers zero/one/multiple-wall inset choice, absolute/percentage wall overlap, `min_perimeter_infill_spacing`, `offset2_ex` collapse, `stInternal` output, both no-overlap branches and top-fill consumer behavior.

A literal C++ oracle confirmed the represented percentage-overlap floating-point result: 20% of the source `ratio_over` becomes **7999** source units after binary-double evaluation, `scale_`, and `coord_t` truncation. The Dart implementation was not changed to produce an idealized 8000.

## Earlier Arachne / fuzzy evidence retained

Run #260 re-executed all previously green Arachne/fuzzy evidence from run #249 and later checkpoints:

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

The same run re-executed the previously green represented subsets of source geometry, Polyline/ArcFitter/Circle, ThickPolyline, Boost.Polygon/Voronoi, MedialAxis, Clipper compatibility, Flow, Extruder, Surface, ExtrusionEntity, variable-width/covered-width geometry, source-style G-code path formatting/emission, classic perimeter nesting/chaining/wall sequence, lower-support generation, and no-speed/speed-graded overhang traversal/pipeline behavior.

## Not proven by this checkpoint

Run #260 does **not** prove:

- `PerimeterGenerator::process_no_bridge(all_surfaces, ...)` or the complete source surface preprocessing that precedes the represented per-island process;
- conditional classic surface simplification resolution and `chain_expolygons` island ordering;
- per-surface `extra_perimeters` propagation from `Surface` through the process wrapper;
- QIDI circle-compensation metadata consumption, including `holes_circle_compensation` centroid matching and split-island disable behavior;
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
