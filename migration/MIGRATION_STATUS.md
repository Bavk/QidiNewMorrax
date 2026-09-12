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
- validated code `ae218afee234afa92f7ef2967d61db8485a82d5a`;
- workflow `34694164752` (#260), conclusion **success**;
- `flutter analyze` — **No issues found!**;
- `flutter test --reporter expanded` — **351/351 passing**.

Run #260 is the first green checkpoint that composes the currently represented classic per-island fill path in source order: wall-count gates → shell → in-loop Alltop → optional gap discovery/fill mutation → final `fill_surfaces` / `fill_no_overlap`. Run #258 first validated the top-one-wall shell ordering at 346/346; #254 first validated the standalone Alltop producer at 340/340; #252 first validated the final fill boundary at 333/333.

## Top-level gates

All remain **OPEN**: formats/project persistence; scene/editor; slicer/toolpath; Preview; profiles/presets; Device/cloud; calibration; desktop/release integration; UI/localization/accessibility; complete reference/differential coverage.

## Verified foundations retained

The current green suite retains scoped `parity_verified` coverage for represented source integer geometry, Polyline/ArcFitter/Circle, ThickPolyline, Boost.Polygon 1.83 robust predicates/Fortune/Voronoi fixtures, MedialAxis, translated Clipper/ClipperUtils behavior used by current consumers, Flow, Extruder/QIDI config subset, Surface, ExtrusionEntity/variable-width/covered-width subset, source-style G-code formatter/path emitter subset, classic perimeter shell/nesting/chaining/wall-sequence/lower-support/no-speed/speed-graded overhang pipeline, and the represented fuzzy/Arachne subset.

The broader containing modules remain `port_started`.

## Classic `process_classic()` represented fill path — scoped `parity_verified`

Pinned source: `bambulab/BambuStudio@f2b55a5a83f266cf56e06c7943a81a08bebb7fad`.

### Shell and wall-count ordering

The green suite now covers:

- requested wall count and alternate-extra-wall behavior already represented by `ClassicPerimeterShellGenerator`;
- exact pre-shell one-wall gate for top-one-wall/topmost and first-layer-one-wall policy;
- semantic distinction between `upper_slices == nullptr` and a non-null empty upper-slice collection;
- source `TopOneWallType` order `None, Alltop, Topmost`;
- source stop at the final requested wall unless an extra gap-discovery iteration is required (`has_gap_fill && sparse_infill_density != 0`);
- effective wall-count collapse when the in-loop Alltop mutation leaves no next inner shell.

### `TopOneWallType::Alltop` producer

`SourceClassicTopFillAllTop2` remains scoped `parity_verified` for:

- configured `wall_loops` vs current `loop_number` distinction;
- source `offset_top_surface` and `top_area_threshold` arithmetic;
- literal bbox-pruning helper using `SCALED_EPSILON`-inflated `last` bounds;
- implicit source `float` boundaries on offset deltas;
- represented 10-source-unit `ApplySafetyOffset::Yes` clip growth;
- `top_polygons`, `temp_gap`, `inner_polygons`, optional lower-slice bridge checker/merge;
- `top_fills`, final `fill_clip`, mutation of `last`, and optional gap-fill re-union.

The producer is now invoked at the correct source position immediately after the first `last = offsets`, so its mutated `last` feeds the next shell iteration.

### Final fill boundary and process composition

`SourceClassicFillBoundary2` plus `SourceClassicPerimeterFillProcess2` are scoped `parity_verified` for:

- post-gap-fill `last` input;
- zero/one/two-or-more-wall inset selection;
- absolute and percentage `infill_wall_overlap`;
- exact source floating-point/truncation behavior, including the 20% oracle value **7999** source units;
- `simplify_p → union_ex` represented boundary;
- `min_perimeter_infill_spacing` coord truncation;
- `offset2_ex` collapse for `infill_exp`;
- represented `stInternal` fill surfaces;
- both `fill_no_overlap` branches;
- consumption of carried `top_fills` / `fill_clip`;
- ordinary two-wall, topmost one-wall, Alltop-only, zero-wall and percentage-overlap end-to-end fixtures.

### Classic work still open

The verified process starts from already supplied island geometry. Pinned source still has an unported preprocessing block immediately before it: `process_no_bridge`, conditional surface simplification, island chaining/order, per-surface extra perimeters, and QIDI circle-compensation metadata. Loop traversal/extrusion conversion and later fill generation also remain broader `port_started` work.

## Fuzzy skin / Arachne retained

The current suite re-executes the scoped fuzzy evidence from run #249 and later checkpoints: exact fuzzy policy and slowdown gates; one Classic RNG stream plus MT19937/libstdc++ oracles; pinned libnoise modes; Polygon/Polyline fuzzy and painted-region LineSegmentation; source ZAttributes / Dart Clipper2 compatibility; source-shaped Arachne extrusion-line subset; all three fuzzy modes with seeded C++ goldens; and Arachne painted-region composition.

The fuzzy scope still does not prove the full Arachne wall generator or every pathological clipping topology.

## Other major open areas

- `process_no_bridge` and source surface preprocessing before the verified classic per-island process;
- remaining classic traversal/metadata integration;
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

1. Port `PerimeterGenerator::process_no_bridge(all_surfaces, perimeter_spacing, ext_perimeter_width)` with translated/source fixtures for the counterbore sacrificial bridge behavior.
2. Port conditional classic surface simplification resolution (`0.2 * m_scaled_resolution` only with arc fitting enabled and fuzzy skin `None`).
3. Port `chain_expolygons(surface_exp)` ordering and feed `Surface::extra_perimeters` into each island's wall count.
4. Port QIDI circle-compensation propagation: surface flag, hole centroid matching with source `eps = 1000`, and compensation disable when simplification/union produces multiple islands.
5. Feed the prepared ordered surfaces into `SourceClassicPerimeterFillProcess2` and add end-to-end preprocessing→fill fixtures.
6. Continue remaining classic process/traversal integration, then broader Arachne wall generation.
7. Continue fill/support/seam/G-code/project/profile/device/cloud/calibration/desktop/UI parity in dependency order.
8. Publish and SHA-verify real runtime assets before any release-complete claim.

No item may be promoted because it merely looks equivalent or passes only common-case smoke tests.
