# Migration status — STRICT 1:1 Flutter/Dart rewrite

Acceptance authority: [`PARITY_CONTRACT.md`](PARITY_CONTRACT.md). The target is Qidi Flow 2.07.02.60 Pass28 reimplemented completely in Flutter + Dart with no legacy runtime backend.

## Status vocabulary

- `pending` — no real Dart replacement yet.
- `port_started` — only part of source behavior exists.
- `implemented_unverified` — intended replacement exists, required reference validation is not green yet.
- `parity_verified` — explicitly scoped behavior has passing translated/differential/oracle evidence.
- `runtime_asset_verified` — preserved data is byte-for-byte verified or uses a documented canonical transform.

A scoped `parity_verified` row never implies its top-level subsystem is complete.

## Current executable checkpoint — 2026-09-12

- Flutter **3.47.2**, Dart **3.13.2**;
- validated code `7c1c5d1f56a287cb812df3b511484851277d460f`;
- workflow `34690713768` (#249), conclusion **success**;
- `flutter analyze` — **No issues found!**;
- `flutter test --reporter expanded` — **325/325 passing**.

Run #249 is the first green checkpoint containing the represented Arachne fuzzy modes plus direct Clipper-Z LineSegmentation. Runs #246–#248 isolated a Dart Clipper2 open-path orientation difference; the final compatibility fix retained the old expectations and all Arachne C++ goldens.

## Top-level gates

All remain **OPEN**: formats/project persistence; scene/editor; slicer/toolpath; Preview; profiles/presets; Device/cloud; calibration; desktop/release integration; UI/localization/accessibility; complete reference/differential coverage.

## Verified foundations retained

The represented subsets covered by the green suite remain scoped `parity_verified`: source integer Point/Line/Polygon geometry; Polyline/ArcFitter/Circle; ThickPolyline; Boost.Polygon 1.83 robust predicates/Fortune/Voronoi represented fixtures; MedialAxis; translated Clipper/ClipperUtils behavior used by current consumers; Flow; Extruder/QIDI config subset; Surface; ExtrusionEntity/variable-width/covered-width subset; source-style G-code formatter/path emitter subset; and represented classic perimeter shell/thin-wall/gap-fill/nesting/chaining/wall-sequence/lower-support/no-speed/speed-graded overhang pipeline.

The broader containing modules remain `port_started`.

## Fuzzy skin

Pinned source: `bambulab/BambuStudio@f2b55a5a83f266cf56e06c7943a81a08bebb7fad`.
Pinned structured-noise dependency: `bambulab/libnoise@v1.0.0`.

### Policy / RNG / structured noise — scoped `parity_verified`

The green suite covers:

- `FuzzySkinType`: `None`, `External`, `All`, `AllWalls`, `Disabled_fuzzy`;
- first-layer, contour/hole and perimeter-index decisions plus region-aware slowdown policy;
- one source random stream for initial spacing, Classic displacement and following spacing draws;
- direct MT19937 and libstdc++ `[0,1)` oracle fixtures;
- all pinned noise modes: Classic, Perlin, Billow, RidgedMulti, Voronoi;
- required libnoise v1.0.0 arithmetic/vector table, scale/frequency, octave, persistence, Voronoi displacement and `slice_z` behavior.

### Polygon/Polyline fuzzy and painted regions — scoped `parity_verified`

Runs #239/#244/#249 cover the represented Polygon/Polyline path:

- 0.75 point-distance minimum, 0.5 random range, carried leftover distance, perpendicular displacement, source integer casts and repeated-penultimate fallback;
- deterministic modes consume RNG only for spacing while Classic shares spacing/displacement draws;
- direct 32-bit source `ZAttributes` through `Point64.z` / `Clipper64.zCallback` for LineSegmentation;
- range ordering, default gaps, source point interpolation and closed-polygon source-index identity;
- single/full/multiple painted-region config selection and classic traversal composition.

Dart Clipper2 differs from pinned `ClipperLib_Z` on represented open terminal Z retention/orientation. `SourceLineSegmentation2` contains narrow, regression-tested compatibility normalization without changing the source range contract; closed wrap behavior is retained only where the subject geometrically wraps.

### Arachne fuzzy extrusion line — scoped `parity_verified`

Run #249 covers the represented source subset:

- source-shaped `ExtrusionJunction` fields `p`, `w`, `perimeter_index`, compensation flag and `ExtrusionLine` metadata;
- `FuzzySkinMode` order: `Displacement`, `Extrusion`, `Combined`;
- exact seeded C++ position/width goldens for all three modes;
- `scaled(0.01)` minimum extrusion width;
- Combined position shift by half of `(new_width - old_width)` along the perpendicular;
- Classic shared RNG and structured-noise spacing-only RNG consumption;
- repeated-penultimate fallback;
- closure synchronization triggered by endpoint XY equality and affecting front position/width;
- Arachne LineSegmentation width interpolation, split-line openness, perimeter-index checks, per-region fuzzy application and XY-only seam duplicate removal.

### Fuzzy scope still not proven

- exhaustive overlap/hole/degenerate LineSegmentation inputs;
- full Arachne wall generation/integration around the verified helper;
- exact platform-level `random_device` / thread-id seed selection (specific runs are intentionally nondeterministic).

## Other major open areas

- remaining classic `fill_surfaces` / `fill_no_overlap` and later perimeter stages;
- full Arachne wall generation;
- fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft toolpaths;
- full native G-code state/templates/travel/retraction/cooling/speed/acceleration/multimaterial/postprocessing;
- complete project/profile persistence, STEP and source-enabled import formats;
- scene/editor and full Preview parity;
- full Device/cloud/P2P/account/camera/HMS/firmware flows and hardware-in-loop validation;
- calibration workflows;
- desktop integrations/installers/updates/single-instance/file associations;
- full source UI/state/localization/accessibility/visual parity;
- runtime asset publication plus repository/release SHA verification;
- exhaustive source/reference/differential tests.

## Immediate next dependency order

1. Port the next missing `PerimeterGenerator::process_classic()` post-perimeter output: `fill_surfaces`, starting from `not_filled_exp`, inset/collapse offsets and `stInternal` append behavior.
2. Port the paired `fill_no_overlap` construction with exact `min_perimeter_infill_spacing`, overlap and top-fill branches.
3. Add simple-contour, top-fill and no-overlap source/translated fixtures, then integrate with later classic fill stages.
4. Continue broader Arachne wall generation using the now-verified fuzzy helper.
5. Expand Clipper/Boost/source regression coverage only as new source consumers demand it.
6. Continue fill/support/seam/G-code/project/profile/device/cloud/calibration/desktop/UI parity in dependency order.
7. Publish and SHA-verify real runtime assets before any release-complete claim.

No item may be promoted because it merely looks equivalent or passes only common-case smoke tests.
