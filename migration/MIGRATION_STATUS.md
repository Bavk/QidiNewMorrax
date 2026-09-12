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
- validated code `b069eb1d5091149780b8257821a5bc28dc49d6c2`;
- workflow `34720179978` (#371), conclusion **success**;
- `flutter analyze` — **No issues found!**;
- `flutter test --reporter expanded` — **669/669 passing**.

Milestones in the current source path:

- #276 / `2a33afd...`: ordered classic islands → traversal/fuzzy/overhang/wall sequence + QIDI loop-node metadata, 387/387;
- #278 / `6978000...`: first Arachne `WallToolPaths` numeric/simplifier dependency slice, 395/395;
- #317 / `10f642e...`: post-construction `SkeletalTrapezoidation::generateToolpaths()` runtime composed, 551/551;
- #330 / `5c77305...`: polygon → Boost Voronoi → skeletal graph → variable-width Arachne toolpaths composed, 584/584;
- #340 / `f23293e...`: represented `WallToolPaths::generate()` source-order runtime composed, 604/604;
- `4832008...` + `9ac38dc...`: pinned `computePointCellRange()` secondary-edge assertion restored to `!is_secondary()` behavior with regression coverage;
- #346 / `41c8ffe...` + `0d52a42...`: first `PerimeterGenerator::process_arachne()` orchestration slice, 618/618;
- #353 / `3fcb49d...` + `90eec08...`: non-separated per-surface Arachne wall generation composes simplify/offset, circle-compensation topology mapping, real `WallToolPaths`, and inner-contour output, 638/638;
- `7319a3e...` + `6d71b50...`: `should_enable_top_one_wall()` and source bbox/boolean helpers represented;
- `a5281ce...` + `a8c2327...`: `Alltop` separate first-wall/remainder generation and recombination represented;
- `aff8220...` + `de200a2...` and `62fe187...` + `06187f8...`: Arachne region constraints and source ordering represented;
- #371 / `f8c7774...` + `8664d98...` + `7c801dc...` + `b069eb1...`: non-overhang `traverse_extrusions()` composition, 669/669.

## Top-level gates

All remain **OPEN**: formats/project persistence; scene/editor; slicer/toolpath; Preview; profiles/presets; Device/cloud; calibration; desktop/release integration; UI/localization/accessibility; complete reference/differential coverage.

## Verified foundations retained

The current green suite retains scoped `parity_verified` coverage for represented source integer geometry, Polyline/ArcFitter/Circle, ThickPolyline, Boost.Polygon 1.83 robust predicates/Fortune/Voronoi fixtures, MedialAxis, translated Clipper/ClipperUtils behavior used by current consumers, Flow, Extruder/QIDI config subset, Surface, ExtrusionEntity/variable-width/covered-width subset, source-style G-code formatter/path emitter subset, classic perimeter preprocessing/shell/traversal/metadata pipeline, fuzzy/Arachne subsets, Arachne beading strategies, real-polygon Voronoi-to-skeletal construction fixtures, the represented skeletal runtime, `WallToolPaths::generate()`, Alltop per-surface wall generation, Arachne extrusion ordering, and the represented non-overhang Arachne traversal.

The broader containing modules remain `port_started`.

## Classic `process_classic()` represented path — scoped `parity_verified`

Pinned source: `bambulab/BambuStudio@f2b55a5a83f266cf56e06c7943a81a08bebb7fad`.

`SourceClassicPerimeterIslandProcess2` plus `SourceClassicPerimeterOrderedPipeline2` cover the represented source path through source `Surface` vector-copy behavior; `BridgeDetector` and `process_no_bridge()`; conditional simplification / `chain_expolygons`; extra-perimeter accounting; one-wall gates; onion shell / Alltop / thin-wall / gap-fill / final fill boundaries; recursive fuzzy/overhang traversal; shared fuzzy RNG; per-island wall sequence; nested collection shape; and global gap-fill accumulation.

Important source quirk: the supplied `Surface` copy constructor omits QIDI `counter_circle_compensation` and `holes_circle_compensation`, so the high-level source copy resets these members before the later classic lookup. The Dart path preserves that quirk.

### QIDI outwall / loop-node metadata

`SourceNodeContour2`, `SourceLoopNode2`, `SourceLoopNodeBounds2` and the ordered pipeline remain scoped `parity_verified` for the represented classic producer: thin/smaller/normal outer-wall capture order, closed contour/hole form, literal `Point::is_in_lines`, exact bbox/range/global-ID behavior, one-outwall shortcut and multi-outwall post-wall-sequence matching.

Downstream inter-layer relationship/speed-control consumers remain open. The Arachne-specific direct loop-node producer inside `traverse_extrusions()` is also still open.

## Arachne wall-generation dependency chain — scoped status

The represented Arachne dependency chain includes:

- source float-backed `WallToolPathsParams`, prepared-outline repair/cleanup and exact scalar casts;
- represented `BeadingStrategy` implementations and factory composition;
- source-shaped skeletal graph, mutations, source-index transfer and direct Boost/Voronoi topology;
- `constructFromPolygons()` through pointy-end separation, collapse and incident-edge normalization;
- central classification/filtering, bead-count propagation, transitions, nonlinear ribs and represented `generateSegments()` stages;
- top-level `generateToolpaths()` and `WallToolPaths::generate()` source-order composition;
- one-wall planning and per-surface simplify/offset/circle-compensation mapping;
- `should_enable_top_one_wall()`, upper/lower bbox clipping, `Alltop` first-wall/top/remainder split, second `WallToolPaths` generation, inset-index shift and recombination;
- `getRegionOrder()`, blocked nearest-candidate ordering, open-before-closed behavior and `InnerOuterInner` reorder;
- non-overhang `traverse_extrusions()` fuzzy transform, source `to_thick_polyline()` width pairs, variable-width conversion, loop/open packaging, winding restoration and circle-compensation flags;
- standalone `add_infill_contour_for_arachne()` fill-boundary helper.

These slices are scoped `parity_verified` for their represented fixtures. They do **not** imply complete Arachne process parity across arbitrary production geometry.

## `PerimeterGenerator::process_arachne()` — `port_started`

The old `Alltop` and source-ordering blockers are no longer the first open seams. The represented path now reaches ordered Arachne extrusions and a real non-overhang `ExtrusionEntityCollection`.

Still open inside the exact process boundary:

- active Arachne overhang traversal: lower-slice bbox pruning, width-preserving Clipper-Z clipping, optional overhang-speed grading, unsupported bridge-wall role/flow, start-point selection, chain/reorder and smoothing;
- Arachne-specific `z_direction_outwall_speed_continuous` external `LoopNode` creation and `loop_node_range` accounting;
- high-level source-order composition of per-surface wall generation → ordering → traversal → `add_infill_contour_for_arachne()` → global `loops`, `fill_surfaces` and `fill_no_overlap`;
- independent C++/source end-to-end goldens covering full per-surface output.

Therefore full Arachne wall generation remains `port_started`.

## Fuzzy skin / Arachne retained

The 669-test suite re-executes the scoped fuzzy evidence: exact fuzzy policy and slowdown gates; one Classic RNG stream plus MT19937/libstdc++ oracles; pinned libnoise modes; Polygon/Polyline fuzzy and painted-region LineSegmentation; source ZAttributes / Dart Clipper2 compatibility; source-shaped Arachne extrusion-line subset; all three fuzzy modes with seeded C++ goldens; Arachne painted-region composition; and non-overhang fuzzy-to-variable-width traversal.

## Immediate next dependency order

1. Port the active Arachne overhang path in `traverse_extrusions()` exactly, including width-carrying clipping and source start-point/reorder/smoothing behavior.
2. Compose the Arachne-specific QIDI external `LoopNode` producer and range semantics.
3. Compose the final per-surface Arachne process boundary into `loops`, `fill_surfaces` and `fill_no_overlap` using the already represented infill-contour helper.
4. Add independent source/C++ end-to-end goldens for normal, topmost/first-layer one-wall, Alltop, holes/circle compensation and overhang cases.
5. Continue later fill/support/seam/G-code/project/profile/device/cloud/calibration/desktop/UI parity in dependency order.
6. Publish and SHA-verify real runtime assets before any release-complete claim.

## Other major open areas

- complete Arachne overhang/QIDI loop-node/final process integration and independent end-to-end goldens;
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
