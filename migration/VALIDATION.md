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

GitHub Actions `.github/workflows/flutter-parity.yml` run `34697866558` (#276) executed code commit `2a33afd97b4f987a7edf4b482eebf8d34da7f9c0` and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **`+387: All tests passed!`**;
- job conclusion — **success**.

Feature commit `92d27b6ac300f1ce07207caf5100b9568eed3ce3` contained the ordered classic extrusion and loop-node implementation. Its run #275 already passed all **387** tests; it failed only the repository's strict analyze-enforcement because the new test file contained two unused imports. Commit `2a33afd...` removed only those imports; no algorithm or assertion was weakened.

## Ordered classic surface → extrusion evidence

Run #276 is the first green checkpoint composing the represented classic source path through the per-island extrusion boundary. New end-to-end fixtures validate:

- `chain_expolygons()` source order preserved all the way to the outer `loops` collection;
- every produced island remains one nested `ExtrusionEntityCollection2`, matching source `loops->append(entities)` rather than flattening islands together;
- `OuterInner` wall sequence is applied independently inside every island;
- non-null empty lower slices produce the represented overhang branch for every ordered island;
- one shared fuzzy RNG object is consumed across multiple islands instead of restarting a random stream per island;
- the high-level classic seam uses smaller-width depth-zero loops before normal depth-zero loops, matching pinned source construction order;
- gap-fill extrusion output remains a global collection accumulated in island order.

The implementation reuses already-green `SourceClassicPerimeterIslandProcess2` and `SourceClassicFuzzyPerimeterPipeline2`; it does not introduce duplicate fuzzy, overhang or wall-sequence algorithms.

## QIDI outwall / loop-node producer evidence

Run #276 also first validates the represented classic `z_direction_outwall_speed_continuous` metadata producer:

- literal `Point::is_in_lines(const Points&)` endpoint, horizontal/vertical and diagonal-distance behavior;
- strict source comparison `abs(distance) < SCALED_EPSILON`;
- exact loop-node bounding-box expansion by `SCALED_EPSILON = 10` source units;
- one-outwall shortcut assigning `loop_id = 0` without geometric matching;
- sequential `node_id` and `[start,end)` `loop_node_range` values over three ordered islands;
- preexisting caller-owned global loop nodes shifting the next range and ID exactly;
- multiple-outwall contour+hole case where matching follows the **post-traversal/post-wall-sequence entity order** while raw outwall paths retain their source contour order.

This proves the represented producer side only. It does not prove downstream inter-layer loop-node relation construction or its eventual speed-control consumer.

## Earlier classic evidence retained

Run #276 re-executed all previously green classic preprocessing/fill evidence, including:

- pinned upstream `BridgeDetector` fixtures and fully airborne negative case;
- `process_no_bridge()` `None` / null / empty gates plus `chbBridges` and `chbFilled`;
- conditional surface simplification resolution and `chain_expolygons` preprocessing;
- per-surface extra-perimeter accounting before one-wall gates;
- top-one-wall / Alltop source order;
- thin-wall and gap-fill represented paths;
- final `fill_surfaces` / `fill_no_overlap` boundary and source **7999** overlap quirk;
- source `Surface` copy-constructor reset of QIDI circle-compensation fields.

## Earlier Arachne / fuzzy evidence retained

Run #276 re-executed all previously green Arachne/fuzzy evidence:

- one shared Classic `random_value()` stream and direct MT19937/libstdc++ double fixtures;
- direct libnoise v1.0.0 value/gradient/vector-table/Perlin/Billow/RidgedMulti/Voronoi behavior;
- Polygon/Polyline fuzzy sampling/casts/fallback and painted-region LineSegmentation;
- source-shaped Arachne `ExtrusionJunction` / `ExtrusionLine` subset;
- seeded C++ `Displacement`, `Extrusion`, `Combined` position/width goldens;
- Arachne width interpolation, full-cover path, painted-region fuzzy application and seam behavior;
- recursive classic fuzzy traversal and region-aware overhang slowdown policy.

The same run re-executed the represented subsets of source geometry, Polyline/ArcFitter/Circle, ThickPolyline, Boost.Polygon/Voronoi, MedialAxis, Clipper compatibility, Flow, Extruder, Surface, ExtrusionEntity, variable-width/covered-width geometry and source-style G-code path formatting/emission.

## Next audited wall-generation dependency

Pinned `PerimeterGenerator::process_arachne()` remains open. Source audit confirms it depends on `Arachne::WallToolPaths` from `src/libslic3r/Arachne/WallToolPaths.hpp/.cpp`; that class in turn includes `BeadingStrategyFactory`, `SkeletalTrapezoidation` and existing `ExtrusionLine` types. The next implementation should therefore start with `WallToolPathsParams` and independently testable constructor/input-normalization/simplification behavior, then follow the real `generate()` dependency chain. No full Arachne wall parity is claimed by the current `ExtrusionLine` fuzzy subset.

## Not proven by this checkpoint

Run #276 does **not** prove:

- full `Arachne::WallToolPaths` or `PerimeterGenerator::process_arachne()` wall generation;
- downstream inter-layer QIDI loop-node matching / vertical wall speed-control consumption;
- any behavior that would restore QIDI circle-compensation members after the pinned `Surface` copy constructor resets them;
- every pathological counterbore, bridge-detector, simplify, overlap, hole or degenerate clipping topology;
- exact platform-level `random_device` / thread-id nondeterministic seed selection;
- complete Clipper/Boost regression spaces beyond represented fixtures;
- complete G-code state/templates/travel/retraction/cooling/acceleration/multimaterial behavior;
- all later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft algorithms;
- complete project/profile persistence, STEP/source-enabled formats, scene/editor, Preview, Device/cloud/P2P, calibration, desktop integration or full UI parity;
- hardware-in-the-loop printer behavior;
- remote publication and SHA verification of every runtime asset;
- release builds/installers across all supported platforms.

## Completion truth

**Zero top-level parity gates are closed.** Individual source behaviors may be marked `parity_verified` only for the exact scope covered above. Broader modules containing unported branches remain `port_started` or `pending`.
