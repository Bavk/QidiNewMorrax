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
- validated code `5a4d8b65e177ce6fe196594c4263d3f962a90422`;
- workflow `34693713324` (#254), conclusion **success**;
- `flutter analyze` — **No issues found!**;
- `flutter test --reporter expanded` — **340/340 passing**.

Run #254 is the first green checkpoint containing both the final represented classic fill-boundary block and the `TopOneWallType::Alltop` producer. Run #252 (`9ba4f919...`) had already validated the boundary block at **333/333**. Run #253 was compile-only red because of an accidental `const` on the non-const `SourcePolygon2` constructor; commit `5a4d8b6` removed only that typo, and all seven new producer/composition tests passed unchanged in #254.

## Top-level gates

All remain **OPEN**: formats/project persistence; scene/editor; slicer/toolpath; Preview; profiles/presets; Device/cloud; calibration; desktop/release integration; UI/localization/accessibility; complete reference/differential coverage.

## Verified foundations retained

The current green suite retains scoped `parity_verified` coverage for the previously represented source integer geometry, Polyline/ArcFitter/Circle, ThickPolyline, Boost.Polygon 1.83 robust predicates/Fortune/Voronoi fixtures, MedialAxis, translated Clipper/ClipperUtils behavior used by current consumers, Flow, Extruder/QIDI config subset, Surface, ExtrusionEntity/variable-width/covered-width subset, source-style G-code formatter/path emitter subset, classic perimeter shell/thin-wall/gap-fill/nesting/chaining/wall-sequence/lower-support/no-speed/speed-graded overhang pipeline, and the represented fuzzy/Arachne subset.

The broader containing modules remain `port_started`.

## Classic `process_classic()` fill path

Pinned source: `bambulab/BambuStudio@f2b55a5a83f266cf56e06c7943a81a08bebb7fad`.

### Final fill boundary — scoped `parity_verified`

Runs #252/#254 cover `SourceClassicFillBoundary2` for the represented post-gap-fill block:

- zero/one/two-or-more wall inset selection;
- absolute and percentage `infill_wall_overlap`;
- exact source floating-point/truncation behavior, including the C++ oracle where the represented 20% overlap becomes **7999** source units rather than 8000;
- `simplify_p → union_ex` boundary preparation;
- `min_perimeter_infill_spacing` coord truncation;
- `offset2_ex` internal fill collapse;
- `stInternal` fill-surface output representation;
- both `fill_no_overlap` branches;
- top-fill consumer intersection/growth/union semantics.

### `TopOneWallType::Alltop` producer — scoped `parity_verified`

Run #254 covers `SourceClassicTopFillAllTop2` for the represented producer inside the first shell iteration:

- source scalar arithmetic for `offset_top_surface` and `top_area_threshold`;
- separation of configured `wall_loops` from current `loop_number`;
- literal bbox-pruning helper with `SCALED_EPSILON` bounds;
- implicit source `float` offset-delta boundaries;
- represented `ApplySafetyOffset::Yes` 10-unit clip growth;
- all-top split, `temp_gap`, `inner_polygons`, optional lower-slice bridge checker/merge;
- `top_fills`, final `fill_clip`, mutation of `last`, and gap-fill re-union;
- composition into `SourceClassicFillBoundary2`.

### Classic fill integration still `port_started`

The verified helpers are not yet claimed as full `process_classic()` integration. Pinned source changes `loop_number` before the shell and executes the `Alltop` producer immediately after the first `last = std::move(offsets)`. Its mutated `last` must feed later shell iterations, which may themselves collapse and reduce effective wall count. A post-hoc call would be wrong and is intentionally not used as a completion claim.

## Fuzzy skin / Arachne retained

The current suite re-executes the scoped fuzzy evidence from run #249 and later checkpoints:

- exact `FuzzySkinType` policy and slowdown gates;
- one source Classic RNG stream plus MT19937/libstdc++ `[0,1)` oracles;
- pinned libnoise Perlin/Billow/RidgedMulti/Voronoi;
- Polygon/Polyline fuzzy geometry and painted-region LineSegmentation;
- source ZAttributes / Dart Clipper2 compatibility shims;
- source-shaped Arachne `ExtrusionJunction` / `ExtrusionLine` subset;
- `Displacement`, `Extrusion`, `Combined` seeded C++ goldens;
- Arachne painted-region segmentation and fuzzy composition.

The fuzzy scope still does not prove full Arachne wall generation or every pathological clipping topology.

## Other major open areas

- source-order integration of classic top-one-wall + final fill boundaries into the shell/process result;
- remaining classic process behavior around those verified helpers;
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

1. Integrate the source pre-shell one-wall gate: after extra/alternate wall resolution, force `loop_number = 0` under the exact top-one-wall/no-upper-slices or first-layer condition.
2. Invoke `SourceClassicTopFillAllTop2` at the exact first-iteration position after `last = offsets`, not after shell completion, and let its mutated `last` drive subsequent offsets/effective loop collapse.
3. Carry `top_fills` / `fill_clip` through the classic result and feed them after gap-fill mutation to `SourceClassicFillBoundary2`.
4. Add end-to-end fixtures covering topmost/no-upper-slices, first-layer one-wall, partial upper coverage, lower bridge merge, gap-fill re-union and final fill/no-overlap output.
5. Continue remaining classic process integration, then broader Arachne wall generation.
6. Continue fill/support/seam/G-code/project/profile/device/cloud/calibration/desktop/UI parity in dependency order.
7. Publish and SHA-verify real runtime assets before any release-complete claim.

No item may be promoted because it merely looks equivalent or passes only common-case smoke tests.
