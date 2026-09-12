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
- validated code `1f9d7010b52f48f56286d0b5b2772de352b865a9`;
- workflow `34689260162` (#244), conclusion **success**;
- `flutter analyze` — **No issues found!**;
- `flutter test --reporter expanded` — **311/311 passing**.

Run #239 independently validated the direct Dart libnoise v1.0.0 / structured-noise batch at 298/298. Run #244 adds the represented Polyline/Polygon LineSegmentation, painted/per-region classic fuzzy composition, closed-polygon endpoint reconstruction and real `perimeter_regions.empty()` slowdown interaction.

## Top-level gates

All remain **OPEN**: formats/project persistence; scene/editor; slicer/toolpath; Preview; profiles/presets; Device/cloud; calibration; desktop/release integration; UI/localization/accessibility; complete reference/differential coverage.

## Verified foundations retained

The represented subsets covered by the green suite remain scoped `parity_verified`: source integer Point/Line/Polygon geometry; Polyline/ArcFitter/Circle; ThickPolyline; Boost.Polygon 1.83 robust predicates/Fortune/Voronoi represented fixtures; MedialAxis; translated Clipper/ClipperUtils behavior used by current consumers; Flow; Extruder/QIDI config subset; Surface; ExtrusionEntity/variable-width/covered-width subset; source-style G-code formatter/path emitter subset; and represented classic perimeter shell/thin-wall/gap-fill/nesting/chaining/wall-sequence/lower-support/no-speed/speed-graded overhang pipeline.

The broader containing modules remain `port_started`.

## Fuzzy skin

Pinned source: `bambulab/BambuStudio@f2b55a5a83f266cf56e06c7943a81a08bebb7fad`.
Pinned dependency for structured noise: `bambulab/libnoise@v1.0.0`.

### Policy/RNG — scoped `parity_verified`

The green suite covers:

- `FuzzySkinType`: `None`, `External`, `All`, `AllWalls`, `Disabled_fuzzy`;
- first-layer suppression and contour/hole/perimeter-index decisions;
- exact slowdown quirk: `Disabled_fuzzy` always allows overhang slowdown; `None` only when `perimeter_regions` is empty; actual fuzzy modes do not;
- one source random stream for initial spacing, Classic displacement and following spacing draws;
- `SourceFuzzyMt19937Random2` with standard MT19937 and libstdc++ `[0,1)` double oracle fixtures;
- explicit layer and `slice_z` propagation through the represented classic fuzzy pipeline.

### Classic + structured noise geometry — scoped `parity_verified`

Runs #239/#244 cover the represented polygon/polyline branch for all pinned noise modes:

- `Classic`, `Perlin`, `Billow`, `RidgedMulti`, `Voronoi`;
- direct libnoise v1.0.0 value/gradient hash behavior and exact 256-vector source table;
- libnoise `MakeInt32Range`, source cube-lower quirk, octave/persistence formulas and Voronoi displacement behavior;
- source `max(0.01, fuzzy_skin_scale)`, frequency `1/scale`, octave, persistence and `slice_z` inputs;
- deterministic noise consumes the random stream only for point spacing, while Classic consumes it for spacing and displacement;
- 0.75 point-distance minimum, 0.5 random range, carried leftover distance, perpendicular displacement, source integer casts and repeated-penultimate fallback.

### Painted/per-region classic fuzzy — scoped `parity_verified`

Run #244 covers the represented Polyline/Polygon subset of source LineSegmentation and its classic fuzzy consumer:

- open polyline intersection ranges, default gaps and ordered clip-group selection;
- polygon-to-closed-polyline conversion;
- source point interpolation with coord_t truncation;
- full-cover closed polygon keeps distinct first/last source indexes despite equal XY coordinates;
- generic region-value selection;
- single-region whole-polygon fast path;
- multiple painted runs fuzzify independently as open polylines and rejoin with source duplicate-boundary handling;
- identity segments do not consume RNG;
- nonempty perimeter regions feed the exact overhang slowdown gate;
- painted Perlin geometry is applied before classic loop wrapping.

The Dart Clipper2 package has no Clipper-Z callback. `SourceLineSegmentation2` reconstructs source `(line_index,t)` endpoint attributes by integer-polyline projection using QIDI's 10-coordinate `SCALED_EPSILON` threshold; this is an explicit compatibility seam, not a claim that all original LineSegmentation overloads are ported.

### Fuzzy branches still open

- Arachne `ExtrusionJunction` / `ExtrusionLine` fuzzy path;
- `FuzzySkinMode::{Displacement, Extrusion, Combined}` width/position behavior;
- Arachne/extrusion-line LineSegmentation overload and per-region composition;
- broader C++/source oracle cases for pathological contour/hole/overlapping region transitions;
- exact platform-level `random_device` / thread-id seed selection (specific runs are intentionally nondeterministic).

## Other major open areas

- remaining classic fill-surface/fill-no-overlap and later perimeter stages;
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

1. Port the minimal source-shaped Arachne `ExtrusionJunction` / `ExtrusionLine` model needed by `FuzzySkin.cpp::fuzzy_extrusion_line()`.
2. Port Arachne fuzzy `Displacement`, `Extrusion`, and `Combined` modes, including the 0.01 mm minimum width, Combined half-radius shift, closure synchronization and exact RNG/noise inputs.
3. Port the Arachne/extrusion-line LineSegmentation overload and region-aware fuzzy application.
4. Continue classic fill-surface/fill-no-overlap and later perimeter stages after the fuzzy branch boundary is closed.
5. Expand Clipper/Boost/source regression coverage only as new source consumers demand it.
6. Continue full Arachne/fill/support/seam/G-code/project/profile/device/cloud/calibration/desktop/UI parity in dependency order.
7. Publish and SHA-verify real runtime assets before any release-complete claim.

No item may be promoted because it merely looks equivalent or passes only common-case smoke tests.
