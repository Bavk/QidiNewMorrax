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
- validated code `69780005918e63a58485ebf7caf645214eacc37b`;
- workflow `34698420757` (#278), conclusion **success**;
- `flutter analyze` — **No issues found!**;
- `flutter test --reporter expanded` — **395/395 passing**.

Milestones in the current source path:

- #260 / `ae218af...`: represented per-island shell → Alltop → gap-fill → final fill boundary, 351/351;
- #264 / `1b2f5f4...`: pinned `BridgeDetector` plus translated upstream `t/bridges.t` fixtures, 359/359;
- #268 / `d9ad4a5...`: `process_no_bridge()` source gates and both active counterbore branches, 365/365;
- #273 / `0a9fa815...`: counterbore pre-pass → surface preprocessing/order → per-island fill composition, 377/377;
- #276 / `2a33afd...`: ordered islands → recursive classic traversal/fuzzy/overhang/wall-sequence plus QIDI outwall/loop-node metadata, 387/387;
- #278 / `6978000...`: `Arachne::WallToolPathsParams`, constructor numeric state and standalone source simplifier, 395/395.

## Top-level gates

All remain **OPEN**: formats/project persistence; scene/editor; slicer/toolpath; Preview; profiles/presets; Device/cloud; calibration; desktop/release integration; UI/localization/accessibility; complete reference/differential coverage.

## Verified foundations retained

The current green suite retains scoped `parity_verified` coverage for represented source integer geometry, Polyline/ArcFitter/Circle, ThickPolyline, Boost.Polygon 1.83 robust predicates/Fortune/Voronoi fixtures, MedialAxis, translated Clipper/ClipperUtils behavior used by current consumers, Flow, Extruder/QIDI config subset, Surface, ExtrusionEntity/variable-width/covered-width subset, source-style G-code formatter/path emitter subset, classic perimeter preprocessing/shell/traversal/metadata pipeline, and the represented fuzzy/Arachne subsets.

The broader containing modules remain `port_started`.

## Classic `process_classic()` represented path — scoped `parity_verified`

Pinned source: `bambulab/BambuStudio@f2b55a5a83f266cf56e06c7943a81a08bebb7fad`.

`SourceClassicPerimeterIslandProcess2` plus `SourceClassicPerimeterOrderedPipeline2` cover the represented source path through:

- source `Surface` vector-copy behavior;
- `BridgeDetector` and `process_no_bridge()` gates / `chbBridges` / `chbFilled`;
- conditional surface simplification resolution and `chain_expolygons()` island order;
- per-surface `extra_perimeters` and alternate-extra-wall accounting before one-wall gates;
- onion shell, Alltop, thin-wall/gap-fill and final `fill_surfaces` / `fill_no_overlap` composition;
- recursive classic fuzzy/overhang traversal per ordered island;
- one shared fuzzy RNG stream across islands;
- per-island wall-sequence adjustment and nested source collection shape;
- global gap-fill extrusion accumulation.

Important source quirk: the supplied `Surface` copy constructor omits QIDI `counter_circle_compensation` and `holes_circle_compensation`, so the high-level source copy resets these members before the later classic lookup. The Dart path preserves that quirk.

### QIDI outwall / loop-node metadata

`SourceNodeContour2`, `SourceLoopNode2`, `SourceLoopNodeBounds2` and the ordered pipeline remain scoped `parity_verified` for the represented classic producer: thin/smaller/normal outer-wall capture order, closed contour/hole form, literal `Point::is_in_lines`, strict epsilon distance, exact bbox expansion, one-outwall shortcut, multi-outwall post-wall-sequence matching, global node IDs and per-island `loop_node_range`.

Downstream inter-layer relationship/speed-control consumers remain open.

## Arachne `WallToolPaths` foundation — scoped `parity_verified`

Run #278 verifies the first source-shaped wall-generator dependency slice in `source_arachne_wall_tool_paths.dart`:

- `WallToolPathsParams` source `float` storage, including exact `process_arachne()` percentage × minimum-nozzle assignments before float32 storage;
- constructor state: `fill_outline_gaps`, source float-backed `scaled<coord_t>` members, `small_area_length`, and `toolpaths_generated=false`;
- pinned double `scaled<coord_t>` truncation quirks: `0.5→49999`, `0.025→2500`, `2.0→199999`, `0.01→999`, `0.005→499`;
- standalone `WallToolPaths.cpp::simplify(Polygon&, ...)`, including area accumulation, integer `height_2`, near-collinear rule, optional infinite-line replacement and wrapper removal of paths below three vertices.

Eight new direct fixtures passed in #278. This scope does **not** include the prepared-outline cleanup chain, beading strategies, `SkeletalTrapezoidation`, generated variable-width walls or `process_arachne()` composition. Therefore the full Arachne wall generator remains `port_started`.

## Fuzzy skin / Arachne retained

The 395-test suite re-executes the scoped fuzzy evidence from run #249 and later checkpoints: exact fuzzy policy and slowdown gates; one Classic RNG stream plus MT19937/libstdc++ oracles; pinned libnoise modes; Polygon/Polyline fuzzy and painted-region LineSegmentation; source ZAttributes / Dart Clipper2 compatibility; source-shaped Arachne extrusion-line subset; all three fuzzy modes with seeded C++ goldens; and Arachne painted-region composition.

## Immediate next dependency order

Continue pinned `Arachne::WallToolPaths::generate()` from the verified constructor/simplifier boundary:

1. Port the exact prepared-outline source chain: triple epsilon offset, simplify, self-intersection repair, degenerate removal, collinear removal, second repair/removal, small-area removal and final `union_`, preserving `outline_size_change` after each operation and the non-positive-area early return.
2. Port scalar pre-beading calculations: rounded-rectangle extrusion widths, source float-backed wall-transition scaling, split/add-middle thresholds and int32-limited `max_bead_count`.
3. Port `BeadingStrategyFactory` composition in pinned order: `Distributed → Redistribute → optional Widening → optional OuterWallInset → Limited`; pinned `OuterWallContourStrategy` is disabled under `#if 0`.
4. Follow the actual `SkeletalTrapezoidation` dependency chain and validate with source/C++ fixtures.
5. Only after those dependencies are green compose generated `WallToolPaths` and the `process_arachne()` one-wall/separate-wall branches, reusing existing Arachne `ExtrusionLine`, fuzzy and LineSegmentation consumers.
6. Continue later fill/support/seam/G-code/project/profile/device/cloud/calibration/desktop/UI parity in dependency order.
7. Publish and SHA-verify real runtime assets before any release-complete claim.

## Other major open areas

- full Arachne wall generation;
- later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft toolpaths;
- full native G-code state/templates/travel/retraction/cooling/speed/acceleration/multimaterial/postprocessing;
- complete project/profile persistence, STEP and source-enabled import formats;
- scene/editor and full Preview parity;
- full Device/cloud/P2P/account/camera/HMS/firmware flows and hardware-in-loop validation;
- calibration workflows;
- desktop integrations/installers/updates/single-instance/file associations;
- full source UI/state/localization/accessibility/visual parity;
- runtime asset publication plus repository/release SHA verification;
- exhaustive source/reference/differential tests.

No item may be promoted because it merely looks equivalent or passes only common-case smoke tests.
