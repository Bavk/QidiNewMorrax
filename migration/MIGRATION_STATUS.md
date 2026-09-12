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
- validated code `ffc005e678d0cf1e6d4000e6c9a842620700ddbe`;
- workflow `34688064516` (#230), conclusion **success**;
- `flutter analyze` — **No issues found!**;
- `flutter test --reporter expanded` — **288/288 passing**.

Run #229 had failed three newly introduced `*Exact2` fuzzy tests. Pinned-source inspection showed their independent-RNG model was wrong. Commit `ffc005e` removed that false branch, restored one shared `random_value()` stream, added a direct MT19937/libstdc++ oracle, and is the green replacement checkpoint.

## Top-level gates

All remain **OPEN**: formats/project persistence; scene/editor; slicer/toolpath; Preview; profiles/presets; Device/cloud; calibration; desktop/release integration; UI/localization/accessibility; complete reference/differential coverage.

## Verified foundations retained

The represented subsets covered by the green suite remain scoped `parity_verified`: source integer Point/Line/Polygon geometry; Polyline/ArcFitter/Circle; ThickPolyline; Boost.Polygon 1.83 robust predicates/Fortune/Voronoi represented fixtures; MedialAxis; translated Clipper/ClipperUtils behavior used by current consumers; Flow; Extruder/QIDI config subset; Surface; ExtrusionEntity/variable-width/covered-width subset; source-style G-code formatter/path emitter subset; and represented classic perimeter shell/thin-wall/gap-fill/nesting/chaining/wall-sequence/lower-support/no-speed/speed-graded overhang pipeline.

The broader containing modules remain `port_started`.

## Fuzzy skin

Pinned source: `bambulab/BambuStudio@f2b55a5a83f266cf56e06c7943a81a08bebb7fad`.

### Policy — scoped `parity_verified`

Run #230 covers:

- `FuzzySkinType`: `None`, `External`, `All`, `AllWalls`, `Disabled_fuzzy`;
- first-layer suppression through `fuzzy_skin_first_layer`;
- contour/hole and perimeter-index decisions in `should_fuzzify()`;
- exact slowdown quirk: `Disabled_fuzzy` always allows overhang slowdown; `None` only when `perimeter_regions` is empty; actual fuzzy modes do not.

### Classic no-region geometry/RNG — scoped `parity_verified`

Run #230 covers:

- `NoiseType` order: `Classic`, `Perlin`, `Billow`, `RidgedMulti`, `Voronoi`;
- one shared source random stream for initial spacing, Classic displacement, and following spacing draws;
- `SourceFuzzyMt19937Random2` direct MT19937 port with libstdc++ `[0,1)` double composition and seeded C++ oracle values;
- production per-isolate nondeterministically seeded source-shaped stream;
- `min_dist = 0.75 * point_distance`, random range `0.5 * point_distance`, carried leftover distance, perpendicular displacement and represented source integer casts;
- literal fallback that repeats the penultimate point;
- pinned `fuzzy_polygon()` closed-polyline behavior without an invented cleanup pass;
- explicit layer identity in recursive classic fuzzy traversal even when overhang detection is disabled;
- represented Classic fuzzy + overhang slowdown integration through the no-painted-region classic perimeter pipeline.

The removed `*Exact2` files are not parity evidence; they encoded a false independent-RNG interpretation.

### Fuzzy branches still open

- Perlin/Billow/RidgedMulti/Voronoi module implementations and exact config/coordinate/`slice_z` behavior;
- painted/per-region `LineSegmentation`, region transitions, and per-segment config selection;
- Arachne `fuzzy_extrusion_line()` and `FuzzySkinMode::{Displacement,Extrusion,Combined}`;
- broader C++/source oracle cases for contours, holes and transitions;
- exact platform-level reproduction of nondeterministic `random_device` / thread-id seed selection (specific production runs are intentionally nondeterministic).

## Other major open areas

- remaining classic fill-surface/fill-no-overlap and later perimeter stages;
- Arachne wall generation;
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

1. Finish fuzzy `get_noise_module()` behavior: port **Perlin**, **Billow**, **RidgedMulti**, **Voronoi** plus scale/frequency/octave/persistence/displacement inputs and deterministic source oracles.
2. Integrate those modules into `fuzzy_polyline()` while preserving the verified single spacing/Classic RNG call order and coordinate/`slice_z` inputs.
3. Port painted/per-region `LineSegmentation` and per-segment fuzzy configs; never substitute whole-loop fuzzing.
4. Port Arachne `fuzzy_extrusion_line()` modes.
5. Continue classic fill-surface/fill-no-overlap and later perimeter stages after the fuzzy branch boundary is closed.
6. Expand Clipper/Boost/source regression coverage only as new source consumers demand it.
7. Continue Arachne/fill/support/seam/G-code/project/profile/device/cloud/calibration/desktop/UI parity in dependency order.
8. Publish and SHA-verify real runtime assets before any release-complete claim.

No item may be promoted because it merely looks equivalent or passes only common-case smoke tests.
