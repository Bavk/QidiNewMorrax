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

GitHub Actions `.github/workflows/flutter-parity.yml` run `34689260162` (#244) executed code commit `1f9d7010b52f48f56286d0b5b2772de352b865a9` and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **`+311: All tests passed!`**;
- job conclusion — **success**.

## New fuzzy evidence in this checkpoint

### Structured noise

Run #239 (`34688786051`) first validated the direct Dart `bambulab/libnoise@v1.0.0` subset and all-noise classic fuzzy path at **298/298 passing**. Run #244 re-executed those fixtures and additionally validated region composition.

Executed structured-noise evidence includes:

- libnoise integer value hash and gradient hash behavior;
- exact source 256-vector gradient table;
- `MakeInt32Range` signed `fmod` semantics;
- source cube-lower behavior at zero/negative integer boundaries;
- Perlin/Billow/RidgedMulti octave formulas;
- Voronoi cell displacement fixtures;
- source `max(0.01, fuzzy_skin_scale)` behavior;
- deterministic `slice_z` participation;
- deterministic noise consuming `random_value()` only for spacing;
- Perlin geometry flowing through apply/traversal/full represented classic loop output.

### LineSegmentation / painted classic fuzzy

Run #244 executed and passed fixtures for:

- empty/default polyline segmentation;
- one stripe producing default/painted/default ranges;
- multiple disjoint region groups and default gaps;
- one region covering the entire open polyline;
- QIDI `Point` scalar-truncation behavior in range endpoint interpolation;
- region-value mapping;
- polygon closure by repeating the first source point;
- full polygon coverage preserving distinct closing source index despite equal XY coordinates;
- one painted region selecting whole-polygon fuzzy config;
- multiple painted runs fuzzified as independent open polylines and rejoined;
- identity region reconstruction without RNG consumption;
- nonempty `perimeter_regions` disabling intermediate overhang speed grading for base `None`;
- painted Perlin geometry applied before classic loop wrapping.

The current Dart Clipper2 package has no Clipper-Z callback. The implemented Polyline/Polygon LineSegmentation subset therefore reconstructs source `(line_index,t)` endpoint attributes by projection onto the source integer polyline using QIDI's 10-coordinate threshold. This compatibility seam is covered by the tests above; the Arachne ExtrusionLine overload remains unported.

## Earlier fuzzy correction retained

Run #230 remains the source of the corrected Classic RNG model: pinned `FuzzySkin.cpp` uses one function-local thread-local `random_value()` stream for spacing and Classic displacement. The false independent-RNG `*Exact2` branch was removed. #244 re-executed the MT19937/libstdc++ and Classic call-order regressions.

## Other evidence re-exercised by #244

The same 311-test run re-executed the previously green represented subsets of source geometry, Polyline/ArcFitter/Circle, ThickPolyline, Boost.Polygon/Voronoi, MedialAxis, Clipper compatibility, Flow, Extruder, Surface, ExtrusionEntity, variable-width/covered-width geometry, source-style G-code path formatting/emission, classic perimeter shell/thin-wall/gap-fill/nesting/chaining/wall sequence, lower-support generation, and no-speed/speed-graded overhang traversal/pipeline behavior.

No fixture was skipped or rewritten to accept incorrect Dart output. The failing #241 region run led to a source-shaped closing-index reconstruction fix and removal of an unrelated role assumption from the slowdown test while retaining the actual slowdown contract assertion.

## Not proven by this checkpoint

Run #244 does **not** prove:

- Arachne `ExtrusionJunction` / `ExtrusionLine` fuzzy behavior;
- `FuzzySkinMode::Displacement`, `Extrusion`, or `Combined`;
- Arachne/extrusion-line LineSegmentation overload and region composition;
- every pathological overlap/hole/degenerate LineSegmentation case;
- exact platform-level `random_device` / thread-id nondeterministic seed selection;
- complete classic perimeter/fill stages or Arachne wall generation;
- complete Clipper/Boost regression spaces beyond represented fixtures;
- complete G-code state/templates/travel/retraction/cooling/acceleration/multimaterial behavior;
- all fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft algorithms;
- complete project/profile persistence, STEP/source-enabled formats, scene/editor, Preview, Device/cloud/P2P, calibration, desktop integration or full UI parity;
- hardware-in-the-loop printer behavior;
- remote publication and SHA verification of every runtime asset;
- release builds/installers across all supported platforms.

## Completion truth

**Zero top-level parity gates are closed.** Individual source behaviors may be marked `parity_verified` only for the exact scope covered above. Broader modules containing unported branches remain `port_started` or `pending`.
