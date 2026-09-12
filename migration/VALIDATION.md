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

GitHub Actions `.github/workflows/flutter-parity.yml` run `34688064516` (#230) executed code commit `ffc005e678d0cf1e6d4000e6c9a842620700ddbe` and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **`+288: All tests passed!`**;
- job conclusion — **success**.

## Why #230 supersedes #229

Run #229 (`34683822158`) failed three newly added fuzzy `*Exact2` tests. Those failures were investigated against pinned `BambuStudio@f2b55a5a83f266cf56e06c7943a81a08bebb7fad` source rather than accepted as Dart regressions.

Literal `FuzzySkin.cpp` inspection established that spacing and Classic/Uniform displacement both call the same function-local thread-local `random_value()`. The failed tests had incorrectly assumed independent RNG engines. Commit `ffc005e` therefore:

- removed the false duplicate `*Exact2` implementation/tests;
- restored one shared `SourceFuzzyUnitRandom2` call stream;
- added a direct `SourceFuzzyMt19937Random2` engine port;
- froze standard MT19937 seed-5489 word output;
- froze libstdc++ `uniform_real_distribution<double>(0,1)` values against a C++ oracle;
- preserved source Classic sampling/displacement call order;
- removed an invented float32 displacement boundary and invented polygon cleanup not present in pinned `FuzzySkin.cpp`;
- passed explicit `layerId` through fuzzy traversal instead of carrying it through fake overhang state.

## Fuzzy evidence executed in #230

The green suite directly includes fixtures for:

- `FuzzySkinType` ordering and `should_fuzzify()` behavior;
- first-layer suppression;
- `None` vs `Disabled_fuzzy` overhang-slowdown distinction;
- `NoiseType` ordering (`Classic`, `Perlin`, `Billow`, `RidgedMulti`, `Voronoi`);
- MT19937 standard seeded output;
- libstdc++ double `[0,1)` oracle values;
- Classic initial spacing, 0.75 point-distance minimum, carried leftover distance and shared RNG call order;
- perpendicular displacement and source integer truncation behavior;
- pinned fallback repeated-penultimate-point quirk;
- literal closed `fuzzy_polygon()` fallback duplicate behavior;
- no-region fuzzy application identity/Classic dispatch;
- recursive Classic fuzzy perimeter traversal order;
- explicit first-layer identity without overhang state;
- represented Classic fuzzy/overhang slowdown integration through the no-region perimeter pipeline.

These are scoped parity claims only.

## Other evidence re-exercised by #230

The same 288-test run re-executed the previously green represented subsets of source geometry, Polyline/ArcFitter/Circle, ThickPolyline, Boost.Polygon/Voronoi, MedialAxis, Clipper compatibility, Flow, Extruder, Surface, ExtrusionEntity, variable-width/covered-width geometry, source-style G-code path formatting/emission, classic perimeter shell/thin-wall/gap-fill/nesting/chaining/wall sequence, lower-support generation, and no-speed/speed-graded overhang traversal/pipeline behavior.

No fixture was weakened or skipped to make #230 green.

## Not proven by this checkpoint

Run #230 does **not** prove:

- Perlin/Billow/RidgedMulti/Voronoi fuzzy noise-module implementation;
- painted/per-region fuzzy `LineSegmentation` or region transitions;
- Arachne fuzzy `Displacement`/`Extrusion`/`Combined` behavior;
- exact platform-level reproduction of `random_device` / thread-id nondeterministic seed selection;
- complete classic perimeter/fill stages or Arachne;
- complete Clipper/Boost regression spaces beyond represented fixtures;
- complete G-code state/templates/travel/retraction/cooling/acceleration/multimaterial behavior;
- all fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft algorithms;
- complete project/profile persistence, STEP/source-enabled formats, scene/editor, Preview, Device/cloud/P2P, calibration, desktop integration or full UI parity;
- hardware-in-the-loop printer behavior;
- remote publication and SHA verification of every runtime asset;
- release builds/installers across all supported platforms.

## Completion truth

**Zero top-level parity gates are closed.** Individual source behaviors may be marked `parity_verified` only for the exact scope covered above. Broader modules containing unported branches remain `port_started` or `pending`.
