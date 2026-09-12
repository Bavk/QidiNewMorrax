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

GitHub Actions `.github/workflows/flutter-parity.yml` run `34695501638` (#273) executed code commit `0a9fa8155e0e860b82177280a379a7b9dccfeeb5` and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **`+377: All tests passed!`**;
- job conclusion — **success**.

## BridgeDetector and counterbore evidence

Run #264 (`34694708899`) first validated `SourceBridgeDetector2` at **359/359** total tests. The translated pinned upstream `t/bridges.t` cases cover:

- wide and tall O-shaped supports;
- both rotated O-shaped source families;
- a two-sided horizontal bridge;
- C-shaped support selection;
- L-shaped anchors with half-area coverage;
- a fully airborne negative case.

These tests exercise source candidate generation, anchored scanline scoring, max-span tie behavior and coverage geometry instead of accepting a hand-picked bridge angle.

Run #268 (`34695120637`) first validated `SourceClassicNoBridge2` at **365/365** total tests. Covered behavior includes:

- pinned `CounterboreHoleBridgingOption` order;
- `None`, null lower-slice and non-null empty lower-slice gates;
- source `Surfaces all_surfaces = slices->surfaces` copy behavior;
- `chbBridges` extraction;
- `chbFilled` convex bridge path;
- non-zero configured bridge angle passed through the detector;
- safety-diff geometry and internal-fill output.

A failed intermediate run exposed one real Dart implementation issue in `chbFilled`: a Clipper result was immutable while source code mutates the vector element. The implementation was corrected to make the result mutable. The other failures in that run were unsupported test assumptions about idealized area and forced-angle failure; the algorithm was not changed to satisfy them.

## Surface preprocessing / ordered-island composition evidence

Run #273 is the first green run composing the new source preprocessing boundary into the previously verified per-island fill path. It validates:

- constructor `m_scaled_resolution` with `max(resolution, EPSILON)`;
- arc-fitting + `FuzzySkinType::None` selecting `0.2 * m_scaled_resolution`;
- non-None fuzzy skin retaining the full base resolution;
- source `chain_expolygons` ordering by ExPolygon bbox centers through the source shortest-path chain;
- `Surface::extra_perimeters` and odd-layer alternate extra wall before one-wall gates;
- source `Polygon::centroid() → Point(Vec2d)` nearest-even `lrint` behavior;
- `eps = 1000` compensation-hole matching and split-island disable semantics;
- `process_no_bridge` output feeding ordered prepared islands;
- actual extra-perimeter count reaching the shell generator;
- conditional shell simplification and base-resolution final-fill simplification staying distinct;
- counterbore-created fill surfaces accumulating before per-island final fill surfaces;
- topmost one-wall gate occurring after per-surface wall-count accounting;
- the supplied `Surface` copy-constructor quirk resetting QIDI circle-compensation members before high-level preprocessing.

One intermediate preprocessing run failed because the test used `SourcePoint2.fromMm(5,5)`, whose fixture boundary truncates to 499999, as the expected centroid. The pinned C++ centroid path uses `lrint` and correctly yields source coordinate 500000. Only the test oracle was corrected; the implementation remained unchanged.

## Previously verified classic fill evidence retained

Run #273 re-executed the earlier green classic process evidence, including:

- exact top-one-wall / null-vs-empty upper-slice ordering;
- `TopOneWallType::Alltop` at the first source shell position;
- source final-wall stop and optional extra gap-discovery iteration;
- thin-wall and gap-fill represented paths;
- final `fill_surfaces` / `fill_no_overlap` boundary;
- the source percentage-overlap floating-point result **7999** rather than idealized 8000.

The high-level wrapper `SourceClassicPerimeterIslandProcess2` now composes counterbore preprocessing → surface order/resolution → per-island shell/fill in this represented scope.

## Earlier Arachne / fuzzy evidence retained

Run #273 re-executed all previously green Arachne/fuzzy evidence:

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

Run #273 does **not** prove:

- composition of all ordered prepared islands into the existing loop-tree / recursive extrusion traversal as one high-level source path;
- QIDI `outwall_paths`, `loop_nodes`, `loop_node_range` and `z_direction_outwall_speed_continuous` metadata;
- any behavior that would restore QIDI circle-compensation members after the pinned `Surface` copy constructor has reset them;
- every pathological counterbore, bridge-detector, simplify, overlap, hole or degenerate clipping topology;
- full Arachne wall generation around the represented fuzzy helper;
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
