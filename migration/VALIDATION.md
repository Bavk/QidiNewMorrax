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

### Cleanup validation run

GitHub Actions run `34668728368` executed the final analyzer-cleanup candidate before committing it. Observed results:

- `dart format` on the five cleanup files — completed;
- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **`+174: All tests passed!`**;
- `git diff --check` — completed with no errors.

Only after those checks passed did the workflow create commit `015dcdd4cbfb9b292a89642c0d736f2471483691` (`chore: finish analyzer cleanup`).

### Independent ordinary parity run

The temporary write-enabled cleanup workflow was removed in commit `2f2c8486e09640dd4d6d03ebc85cee843146d8b2`. The normal read-only `.github/workflows/flutter-parity.yml` then ran independently as run `34668800262` (#139) against that commit and completed successfully:

- toolchain identity: Flutter `3.47.2`, Dart `3.13.2`;
- Analyze step: **success**, log line `No issues found!`;
- Unit and parity tests: **success**, final line `+174: All tests passed!`;
- job conclusion: **success**.

This second run confirms the green state without the temporary cleanup workflow or write permissions.

## What the 174-test suite currently proves

The passing suite contains source-derived, source-formula, or Boost/Clipper oracle coverage for the represented subsets of:

- integer `coord_t` Point/Line geometry and rounding-sensitive Line behavior;
- QIDI `Polyline` append/clip/extend plus ArcFitter / fitting metadata reverse/split/clip behavior;
- Circle/ArcSegment and arc math;
- `ThickPolyline` width cardinality, reverse, `rebase_at`, and width indexing quirks;
- Boost.Polygon 1.83 robust numeric helpers, site/circle predicates, PPP/PPS/PSS/SSS circle formation, Fortune construction, topology adaptation, and known regression inputs;
- QIDI Voronoi issue detection, repair angles/remapping, annotation and default direct builder behavior;
- MedialAxis edge validation/traversal plus `ExPolygon::medial_axis()` post-processing;
- Clipper/ClipperUtils translated boolean and offset fixtures, including Clipper1 miter-limit and positive-hole orientation compatibility at the Dart Clipper2 adapter boundary;
- Flow formulas/config fallback behavior;
- Extruder state/math and QIDI variant resolution;
- Surface classification/copy/assignment quirks;
- ExtrusionEntity/Path/MultiPath/Loop/Collection represented semantics;
- source-style G-code formatter and linear/arc extrusion-path emission subset;
- classic perimeter onion-shell formulas, QIDI smaller-width outer-loop behavior, and the `detect_thin_wall` MedialAxis branch;
- existing linear-infill and basic writer fixtures.

## What is not proven by this checkpoint

This checkpoint does **not** establish full application parity. In particular it does not prove:

- the full source Clipper/ClipperUtils regression space beyond translated fixtures;
- complete `PerimeterGenerator::process_classic()` downstream variable-width conversion, gap fill, overhang/path ordering, or Arachne;
- complete native G-code state/templates/travel/retraction/cooling/acceleration/multi-material behavior;
- all fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft algorithms;
- complete project/profile persistence, STEP/Assimp-enabled formats, or every repair/warning path;
- complete scene/editor, Preview, Device/cloud/P2P, calibration, desktop integration, or UI workflow parity;
- hardware-in-the-loop printer behavior;
- remote publication and SHA verification of every runtime asset;
- release builds/installers on every supported desktop platform.

## Completion truth

**Zero top-level parity gates are closed.** Individual, explicitly scoped source behaviors may be marked `parity_verified` where the translated/oracle tests above cover that exact row. Broader modules that contain unported branches remain `port_started`.
