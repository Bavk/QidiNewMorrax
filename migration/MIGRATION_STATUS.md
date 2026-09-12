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
- validated code `90eec08b5c8f6474bbbfa78d1e71f3996d2246e0`;
- workflow `34718370244` (#353), conclusion **success**;
- `flutter analyze` — **No issues found!**;
- `flutter test --reporter expanded` — **638/638 passing**.

Milestones in the current source path:

- #276 / `2a33afd...`: ordered classic islands → traversal/fuzzy/overhang/wall sequence + QIDI loop-node metadata, 387/387;
- #278 / `6978000...`: first Arachne `WallToolPaths` numeric/simplifier dependency slice, 395/395;
- #317 / `10f642e...`: post-construction `SkeletalTrapezoidation::generateToolpaths()` runtime composed, 551/551;
- #330 / `5c77305...`: polygon → Boost Voronoi → skeletal graph → variable-width Arachne toolpaths composed, 584/584;
- #340 / `f23293e...`: represented `WallToolPaths::generate()` source-order runtime composed, 604/604;
- `4832008...` + `9ac38dc...`: pinned `computePointCellRange()` secondary-edge assertion restored to `!is_secondary()` behavior with regression coverage;
- #346 / `41c8ffe...` + `0d52a42...`: first `PerimeterGenerator::process_arachne()` orchestration slice, 618/618;
- #353 / `3fcb49d...` + `90eec08...`: non-separated per-surface Arachne wall generation now composes simplify/offset, circle-compensation topology mapping, real `WallToolPaths`, and inner-contour output, 638/638.

## Top-level gates

All remain **OPEN**: formats/project persistence; scene/editor; slicer/toolpath; Preview; profiles/presets; Device/cloud; calibration; desktop/release integration; UI/localization/accessibility; complete reference/differential coverage.

## Verified foundations retained

The current green suite retains scoped `parity_verified` coverage for represented source integer geometry, Polyline/ArcFitter/Circle, ThickPolyline, Boost.Polygon 1.83 robust predicates/Fortune/Voronoi fixtures, MedialAxis, translated Clipper/ClipperUtils behavior used by current consumers, Flow, Extruder/QIDI config subset, Surface, ExtrusionEntity/variable-width/covered-width subset, source-style G-code formatter/path emitter subset, classic perimeter preprocessing/shell/traversal/metadata pipeline, fuzzy/Arachne subsets, Arachne beading strategies, real-polygon Voronoi-to-skeletal construction fixtures, the represented skeletal runtime, and the represented `WallToolPaths::generate()` composition.

The broader containing modules remain `port_started`.

## Classic `process_classic()` represented path — scoped `parity_verified`

Pinned source: `bambulab/BambuStudio@f2b55a5a83f266cf56e06c7943a81a08bebb7fad`.

`SourceClassicPerimeterIslandProcess2` plus `SourceClassicPerimeterOrderedPipeline2` cover the represented source path through source `Surface` vector-copy behavior; `BridgeDetector` and `process_no_bridge()`; conditional simplification / `chain_expolygons`; extra-perimeter accounting; one-wall gates; onion shell / Alltop / thin-wall / gap-fill / final fill boundaries; recursive fuzzy/overhang traversal; shared fuzzy RNG; per-island wall sequence; nested collection shape; and global gap-fill accumulation.

Important source quirk: the supplied `Surface` copy constructor omits QIDI `counter_circle_compensation` and `holes_circle_compensation`, so the high-level source copy resets these members before the later classic lookup. The Dart path preserves that quirk.

### QIDI outwall / loop-node metadata

`SourceNodeContour2`, `SourceLoopNode2`, `SourceLoopNodeBounds2` and the ordered pipeline remain scoped `parity_verified` for the represented classic producer: thin/smaller/normal outer-wall capture order, closed contour/hole form, literal `Point::is_in_lines`, exact bbox/range/global-ID behavior, one-outwall shortcut and multi-outwall post-wall-sequence matching.

Downstream inter-layer relationship/speed-control consumers remain open.

## Arachne wall-generation dependency chain — scoped status

The represented `WallToolPaths` / skeletal dependency chain now includes:

- source float-backed `WallToolPathsParams` and constructor numeric state;
- standalone simplifier plus represented prepared-outline repair/cleanup chain;
- scalar pre-beading inputs and exact source casts;
- `Distributed`, `Redistribute`, `Widening`, `OuterWallInset`, `Limited` strategy behavior and `BeadingStrategyFactory` composition;
- source-shaped skeletal graph and mutation helpers, pointy-end separation and `collapseSmallEdges()`;
- source polygon/source-index mapping into direct Boost/Voronoi topology;
- `computePointCellRange()`, straight/secondary + point-line + point-point discretization, `makeNode()` / `transferEdge()` identity maps, twin reconstruction and source metadata transfer;
- `constructFromPolygons()` composition through pointy-end separation, collapse and incident-edge normalization on real square polygon fixtures;
- central classification/filtering, bead-count propagation, noncentral dissolution, transition generation/filtering/application, nonlinear extra ribs;
- full represented `generateSegments()` runtime after graph construction: upward ordering, local beadings/interpolation, upward/downward propagation, extrusion-junction generation, junction connection and local-maximum single beads;
- top-level `generateToolpaths()` source-order composition;
- represented `WallToolPaths::generate()` composition through outline preparation, beading strategy, skeletal generation, polyline stitch, small-line removal, inner-contour separation, simplification and empty-path removal.

The latest correction restores the pinned `computePointCellRange()` invariant for a non-source-starting edge: it must be primary (`!edge.secondary`), not secondary. The regression suite explicitly rejects the inverted topology.

These construction and `WallToolPaths` slices are scoped `parity_verified` for their represented fixtures. They do **not** imply complete Arachne process parity across arbitrary production geometry.

## `PerimeterGenerator::process_arachne()` — `port_started`

The represented orchestration now covers two source-order layers.

`SourceArachneProcessPlanner2` preserves:

- `only_one_wall_first_layer && layer_id == 0`;
- top-most one-wall behavior when `top_one_wall_type != None && upper_slices == nullptr`;
- `Alltop && upper_slices != nullptr` selection of the separate-wall branch;
- `loop_number == 0` one-wall behavior;
- exact precise-outer-wall `wall_0_inset = -(ext_perimeter_width / 2 - ext_perimeter_spacing / 2)` in source integer division order;
- normal `loop_number + 1` inset count and one-wall inset count `1`;
- negative loop-number no-generation seam;
- normal and one-wall handoff into the represented `WallToolPaths::generate()` runtime.

`SourceArachneProcessSurface2` additionally composes the non-separated per-surface path through surface simplify, external-wall offset, source-shaped circle-compensation topology gate and flag mapping, real `WallToolPaths` generation, and returned inner contour. It deliberately rejects the `Alltop` separate-wall candidate instead of approximating it.

The `Alltop` separate-wall branch remains **open**. The unfinished seam includes `should_enable_top_one_wall()` geometry, upper/lower clipping and offsets, first-wall/top-fill/remainder split, second wall generation, recombination, source extrusion ordering/traversal, and final integration of the represented Arachne infill-contour boundary into `fill_surfaces` / `fill_no_overlap`.

Therefore full Arachne wall generation remains `port_started`.

## Fuzzy skin / Arachne retained

The 638-test suite re-executes the scoped fuzzy evidence: exact fuzzy policy and slowdown gates; one Classic RNG stream plus MT19937/libstdc++ oracles; pinned libnoise modes; Polygon/Polyline fuzzy and painted-region LineSegmentation; source ZAttributes / Dart Clipper2 compatibility; source-shaped Arachne extrusion-line subset; all three fuzzy modes with seeded C++ goldens; and Arachne painted-region composition.

## Immediate next dependency order

Continue pinned `PerimeterGenerator::process_arachne()` from the exposed `Alltop` separate-wall seam:

1. port `should_enable_top_one_wall()` and its exact upper-slice bbox/offset/clipping behavior;
2. compose separate first-wall generation, `top_fills` and remainder geometry, second `WallToolPaths` generation and source recombination;
3. port/compose Arachne wall conversion and ordering (`getRegionOrder`, blocked-order nearest-candidate logic, `InnerOuterInner` adjustment and `traverse_extrusions`);
4. integrate the represented Arachne infill-contour boundary into final `fill_surfaces` / `fill_no_overlap` behavior;
5. add independent C++/source goldens for complete per-surface polygon → wall paths → ordered extrusions/fill boundaries, including holes, Alltop/topmost/first-layer one-wall and compensation cases;
6. continue later fill/support/seam/G-code/project/profile/device/cloud/calibration/desktop/UI parity in dependency order;
7. publish and SHA-verify real runtime assets before any release-complete claim.

## Other major open areas

- complete `process_arachne()` separate-wall / ordering / infill-contour integration and independent end-to-end goldens;
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
