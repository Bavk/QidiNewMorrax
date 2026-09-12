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

GitHub Actions `.github/workflows/flutter-parity.yml` run `34690713768` (#249) executed code commit `7c1c5d1f56a287cb812df3b511484851277d460f` and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **`+325: All tests passed!`**;
- job conclusion — **success**.

## Arachne fuzzy evidence executed in #249

The green suite includes source-shaped Arachne models and exact `FuzzySkin.cpp::fuzzy_extrusion_line()` evidence for:

- `FuzzySkinMode` source order: `Displacement`, `Extrusion`, `Combined`;
- seeded `std::mt19937(5489)` / libstdc++ Classic-oracle position values for `Displacement`;
- seeded width oracle for `Extrusion`;
- seeded position + width oracle for `Combined`;
- `scaled(0.01)` minimum extrusion width;
- Combined perpendicular shift by half the width delta;
- structured-noise mode consuming `random_value()` only for spacing;
- repeated-penultimate fallback behavior;
- closure synchronization based on endpoint XY equality and affecting output front position/width;
- source-shaped `ExtrusionLine` metadata retention.

## Arachne / LineSegmentation evidence executed in #249

The same run covers the represented `Algorithm/LineSegmentation` ExtrusionLine overload:

- source 32-bit `ZAttributes` encoding through `Point64.z` / `Clipper64.zCallback`;
- default/painted/default open-path segmentation;
- Point interpolation with QIDI per-product coord truncation;
- extrusion-width interpolation with final scalar truncation;
- perimeter-index consistency at interpolated boundaries;
- split Arachne segments using open-line constructor semantics;
- full-cover fast path retaining whole-line metadata;
- region-value mapping;
- painted-region fuzzy application and XY-only seam duplicate removal.

### Why #246–#248 failed before #249

Run #246 (`34690222711`) first executed the Arachne batch. All three C++ fuzzy-mode goldens and the Arachne composition fixtures passed. Only two LineSegmentation cases failed: an existing Polyline endpoint-interpolation case and its new Arachne width-interpolation analogue.

Run #247 added a narrow compatibility repair for surviving open terminal points whose Dart Clipper2 Z value no longer matched the point's unique exact source XY. The two failures remained.

Run #248 added diagnostics without weakening the assertion. It showed the painted intersection arriving in the opposite open-path direction: terminal source point → intersection, which activated the source first/last index seam exception on an actually open two-point subject and created a false trailing default range.

Pinned `ClipperLib_Z` supplies the represented open result in source direction; Dart Clipper2 may return it reversed. Commit `7c1c5d1` therefore restricts the first/last wrap exception to a subject whose first and last XY actually coincide. Open Dart paths normalize back to source order; closed Polygon/Arachne paths retain the source wrap behavior. Run #249 then passed all **325/325** tests. No expected geometry/width value was loosened.

## Earlier fuzzy evidence retained

Run #249 also re-executed the earlier green evidence:

- one shared Classic `random_value()` stream and direct MT19937/libstdc++ double fixtures;
- direct libnoise v1.0.0 value/gradient/vector-table/Perlin/Billow/RidgedMulti/Voronoi behavior;
- scale clamp, octave/persistence, Voronoi displacement and `slice_z` inputs;
- Polygon/Polyline fuzzy sampling/casts/fallback;
- painted Polyline/Polygon region composition;
- recursive classic fuzzy traversal and region-aware overhang slowdown policy.

It also re-executed the previously green represented subsets of source geometry, Polyline/ArcFitter/Circle, ThickPolyline, Boost.Polygon/Voronoi, MedialAxis, Clipper compatibility, Flow, Extruder, Surface, ExtrusionEntity, variable-width/covered-width geometry, source-style G-code path formatting/emission, classic perimeter shell/thin-wall/gap-fill/nesting/chaining/wall sequence, lower-support generation, and no-speed/speed-graded overhang traversal/pipeline behavior.

## Not proven by this checkpoint

Run #249 does **not** prove:

- full Arachne wall generation around the represented fuzzy helper;
- every pathological overlap/hole/degenerate LineSegmentation case;
- exact platform-level `random_device` / thread-id nondeterministic seed selection;
- remaining classic `fill_surfaces` / `fill_no_overlap` and later perimeter/fill stages;
- complete Clipper/Boost regression spaces beyond represented fixtures;
- complete G-code state/templates/travel/retraction/cooling/acceleration/multimaterial behavior;
- all fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft algorithms;
- complete project/profile persistence, STEP/source-enabled formats, scene/editor, Preview, Device/cloud/P2P, calibration, desktop integration or full UI parity;
- hardware-in-the-loop printer behavior;
- remote publication and SHA verification of every runtime asset;
- release builds/installers across all supported platforms.

## Completion truth

**Zero top-level parity gates are closed.** Individual source behaviors may be marked `parity_verified` only for the exact scope covered above. Broader modules containing unported branches remain `port_started` or `pending`.
