# Validation record — strict 1:1 rewrite

This file records only work that has actually executed. Acceptance authority remains [`PARITY_CONTRACT.md`](PARITY_CONTRACT.md); a passing subset never closes a top-level application gate.

## Input identity / loss-prevention baseline

- Supplied archive: `QidiFlow-2.07.02.60-Pass28-Device-Reference-Redesign-Clean(1).zip`.
- Archive SHA-256 from the initial audit: `821ed379d65916df32f5d031bd583bc724ce72f4d229447adc61280701e4d57d`.
- Extracted source files inventoried: **8,632**.
- Earlier local runtime-asset audit: **3,657/3,657** copied runtime entries matched source SHA-256; full publication/reverification from GitHub/release inputs is still open.

## Current executed Flutter/Dart checkpoint — 2026-09-13

Pinned toolchain:

- Flutter `3.47.2`;
- Dart `3.13.2`;
- Ubuntu 24.04 hosted runner.

GitHub Actions `.github/workflows/flutter-parity.yml` run `34726060018` (#402) executed code commit `4a33e8d2592de1790ce0d63f01c0724a499ff356` and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **`+687: All tests passed!`**;
- job conclusion — **success**.

The suite includes all earlier source-shaped/translated/oracle coverage plus the independent compiled-BambuStudio `process_arachne()` fixtures listed below.

## Independent pinned BambuStudio process oracle

The `process_arachne()` end-to-end fixtures were obtained from the **actual upstream compiled BambuStudio artifact at the exact pinned source commit**, not from the Dart implementation under test.

Provenance:

- repository: `bambulab/BambuStudio`;
- source commit: `f2b55a5a83f266cf56e06c7943a81a08bebb7fad`;
- successful upstream GitHub Actions run: `34298498452` (`Build all`);
- Ubuntu 24.04 artifact ID/name: `10085378329` / `BambuStudio_ubuntu-24.04_V02.08.03.66`;
- downloaded artifact SHA-256: `912517d86774f4705c28a9e649f3fc91f96fe1623bdf070cb5f14f02ba3827f8`;
- extracted AppImage SHA-256: `ad90fda9a4537222a679b5d2ad12712a86652858106dce00f69fac24c3af8b46`;
- CLI version reported by the binary: `02.08.03.66`.

Committed fixtures record the same provenance. G-code coordinates are compared with `0.00051mm` serialization tolerance. Only global plate-arrange translation and, where required, closed-loop seam rebasing are normalized; wall spans, role classes and support split positions remain strict.

### Executed compiled-oracle fixtures

1. **Interior two-wall square** — run #394 / commit `4bfb5b5555975a44da4628d2fe926553762d417b`:
   - 20×20mm square, layer index 1 / Z=0.4mm;
   - inner wall bbox `18.886 × 18.886mm`;
   - outer wall bbox `19.600 × 19.600mm`;
   - line width comment `0.39999mm`;
   - source wall role order Inner→Outer.

2. **Topmost one-wall square** — same run #394:
   - topmost layer emits one external wall;
   - external centerline bbox `19.600 × 19.600mm`.

3. **First-layer one-wall square** — same run #394:
   - `only_one_wall_first_layer` branch emits one external wall;
   - external centerline bbox `19.600 × 19.600mm`.

4. **Non-speed active overhang** — run #398 / commit `425b64d6218c9691c444ccf2423cae09d018ea17`:
   - stepped solid with lower x=0..20mm and upper x=5..25mm;
   - inner/outer full wall spans `18.886mm` / `19.600mm`;
   - overhang-region widths `4.243mm` / `4.600mm`;
   - grown lower-support split exactly at model `x=20.2mm`;
   - cyclic role bands preserve supported versus `erOverhangPerimeter` classification. A failed first version of the test exposed only downstream/seam start-point rebasing, not a geometry mismatch; the corrected comparison is cyclic for closed loops while retaining the strict split coordinates.

5. **Partial `Alltop`** — run #400 / commit `e3823024b6cf4d280c7b06c357880649798d9697`:
   - current layer full 20×20mm; upper layer covers only x=0..10mm;
   - external first wall remains full `19.600 × 19.600mm`;
   - remainder inner wall is clipped to `8.864 × 18.886mm`;
   - relative placement against the outer wall matches the pinned CLI (`+0.357mm` to `+9.221mm` in X and `+0.357mm` to `+19.243mm` in Y), proving the separate first-wall/remainder/recombine path rather than only final wall size.

6. **Square through-hole** — run #402 / commit `4a33e8d2592de1790ce0d63f01c0724a499ff356`:
   - 20×20mm frame with a centered 10×10mm through-hole;
   - four closed Arachne wall loops;
   - outer material contour inner/external wall spans `18.886mm` / `19.600mm`;
   - hole-boundary inner/external wall spans `11.114mm` / `10.400mm`;
   - line width remains `0.39999mm`.

These six exact scenarios are independently **scoped `parity_verified`** at the process output aspects asserted by their tests.

## Functional Arachne process path executed

Before the compiled-oracle fixtures, the Dart suite had already executed the represented source-order path through:

- `WallToolPaths` prepared-outline, beading strategy, direct Boost/Voronoi construction and `SkeletalTrapezoidation::generateToolpaths()`;
- per-surface normal/topmost/first-layer/`Alltop` planning;
- Arachne region/extrusion ordering;
- non-overhang traversal and source variable-width conversion;
- non-speed Clipper-Z overhang splitting;
- speed-graded 2mm sampling, signed-distance mapping, 0.25-degree splitting and `smooth_overhang_level()`;
- Arachne QIDI raw external-wall `LoopNode` producer and global range accounting;
- final `loops` append and `add_infill_contour_for_arachne()` composition into `fill_surfaces` / `fill_no_overlap`.

Run #390 was the first complete represented surface-tail checkpoint (681/681); runs #394–#402 add independent process-level evidence without removing any earlier fixtures.

## Retained lower-level oracle/translated evidence

The 687-test suite re-executes, among other covered scopes:

- source integer geometry, Polyline, ArcFitter/Circle and ThickPolyline behavior;
- Boost.Polygon 1.83 robust numeric / Fortune / Voronoi fixtures and known regressions;
- MedialAxis and translated Clipper/ClipperUtils consumers;
- Flow / Surface / ExtrusionEntity / variable-width subsets;
- classic perimeter preprocessing, shell, top-one-wall/Alltop, fuzzy, overhang, wall sequence and QIDI LoopNode producer;
- MT19937/libstdc++ random stream oracles and pinned libnoise modes;
- Polygon/Polyline/Arachne fuzzy-skin and LineSegmentation behavior;
- seeded C++ Arachne fuzzy `Displacement`, `Extrusion` and `Combined` goldens;
- Arachne graph construction, beading strategies, transition/rib generation, stitching, simplification and generated-wall fixtures;
- Arachne binary and speed-graded overhang helper fixtures, including source numerical quirks.

## Still not proven by independent process oracle

The represented `process_arachne()` boundary remains **`implemented_unverified` as a whole**. Independent reference evidence is still missing for:

- process-level speed-graded overhang geometry/degree segmentation without conflating downstream G-code feedrate policy;
- Arachne QIDI `LoopNode` payload/range output (ordinary exported G-code does not expose it);
- QIDI counter/hole circle-compensation metadata/geometry; the through-hole fixture validates ordinary hole walls only;
- final `fill_surfaces` / `fill_no_overlap` contents, especially no-wall and one-wall mixed-spacing cases not directly observable from normal G-code;
- broader pathological/production geometries beyond the current fixed fixtures;
- downstream inter-layer QIDI loop-node matching / vertical-wall speed-control consumption;
- every later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft algorithm;
- complete native G-code state/templates/travel/retraction/cooling/acceleration/multimaterial/postprocessing;
- complete project/profile persistence, STEP/source-enabled formats, scene/editor, Preview, Device/cloud/P2P, calibration, desktop integration or full UI parity;
- hardware-in-the-loop printer behavior;
- remote publication and SHA verification of every runtime asset;
- release builds/installers across all supported platforms.

## Next validation boundary

1. Derive an independent process-level oracle for **speed-graded Arachne overhang geometry/degrees**, separating perimeter segmentation evidence from downstream G-code speed selection.
2. Obtain an independent observable/instrumented oracle for Arachne QIDI LoopNode/range data.
3. Obtain independent circle-compensation and final fill-boundary/no-wall evidence.
4. Expand differential fixtures to pathological and production models.
5. Only after those scopes are green consider promoting the represented `process_arachne()` boundary as a whole to scoped `parity_verified`.

## Completion truth

**Zero top-level parity gates are closed.** Individual source behaviors and the exact compiled-oracle fixtures above may be marked `parity_verified` only for their asserted scope. Broader modules remain incomplete until every required source path, integration boundary and reference test is covered.
