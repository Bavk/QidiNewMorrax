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
- validated code `2a33afd97b4f987a7edf4b482eebf8d34da7f9c0`;
- workflow `34697866558` (#276), conclusion **success**;
- `flutter analyze` — **No issues found!**;
- `flutter test --reporter expanded` — **387/387 passing**.

Milestones in the current classic source path:

- #260 / `ae218af...`: represented per-island shell → Alltop → gap-fill → final fill boundary, 351/351;
- #264 / `1b2f5f4...`: pinned `BridgeDetector` plus translated upstream `t/bridges.t` fixtures, 359/359;
- #268 / `d9ad4a5...`: `process_no_bridge()` source gates and both active counterbore branches, 365/365;
- #273 / `0a9fa815...`: counterbore pre-pass → surface preprocessing/order → per-island fill composition, 377/377;
- #276 / `2a33afd...`: ordered islands → recursive classic traversal/fuzzy/overhang/wall-sequence plus QIDI outwall/loop-node metadata, 387/387.

## Top-level gates

All remain **OPEN**: formats/project persistence; scene/editor; slicer/toolpath; Preview; profiles/presets; Device/cloud; calibration; desktop/release integration; UI/localization/accessibility; complete reference/differential coverage.

## Verified foundations retained

The current green suite retains scoped `parity_verified` coverage for represented source integer geometry, Polyline/ArcFitter/Circle, ThickPolyline, Boost.Polygon 1.83 robust predicates/Fortune/Voronoi fixtures, MedialAxis, translated Clipper/ClipperUtils behavior used by current consumers, Flow, Extruder/QIDI config subset, Surface, ExtrusionEntity/variable-width/covered-width subset, source-style G-code formatter/path emitter subset, classic perimeter shell/nesting/chaining/wall-sequence/lower-support/no-speed/speed-graded overhang pipeline, and the represented fuzzy/Arachne subset.

The broader containing modules remain `port_started`.

## Classic `process_classic()` represented path — scoped `parity_verified`

Pinned source: `bambulab/BambuStudio@f2b55a5a83f266cf56e06c7943a81a08bebb7fad`.

### Surface preprocessing and per-island fill

The previously verified `SourceClassicPerimeterIslandProcess2` continues to cover:

- source `Surface` vector-copy behavior;
- `BridgeDetector` and `process_no_bridge()` gates / `chbBridges` / `chbFilled`;
- conditional surface simplification resolution and `chain_expolygons()` island order;
- per-surface `extra_perimeters` and alternate-extra-wall accounting before one-wall gates;
- onion shell, Alltop, thin-wall/gap-fill and final `fill_surfaces` / `fill_no_overlap` composition;
- counterbore fill ordering and the source 20% overlap result **7999** source units.

Important source quirk: the supplied `Surface` copy constructor omits QIDI `counter_circle_compensation` and `holes_circle_compensation`, so the high-level source copy resets these members before the later classic lookup. The Dart path preserves that quirk.

### Ordered island → extrusion traversal composition

`SourceClassicPerimeterOrderedPipeline2` is now scoped `parity_verified` for the represented source boundary after shell/fill preparation:

- consumes islands in the existing `chain_expolygons()` order;
- invokes the existing classic fuzzy/overhang recursive traversal separately for every island;
- preserves one shared fuzzy RNG stream across ordered islands;
- applies source wall-sequence adjustment per island rather than to a globally flattened list;
- appends each non-empty island as one nested `ExtrusionEntityCollection2` into the outer `loops` collection;
- accumulates gap-fill extrusion entities globally in island order;
- preserves null versus non-null empty lower-slice semantics when building overhang state;
- normalizes the high-level depth-zero source seam so smaller-width external loops enter nesting before normal external loops, matching pinned `process_classic()` construction order without changing the lower-level shell evidence.

Run #276 validates three-island chain order, per-island `OuterInner`, empty-lower overhang traversal and a shared fuzzy RNG stream.

### QIDI outwall / loop-node metadata

`SourceNodeContour2`, `SourceLoopNode2`, `SourceLoopNodeBounds2` and the ordered pipeline are scoped `parity_verified` for the represented classic metadata producer:

- thin-wall, smaller-width outer-wall and normal outer-wall `outwall_paths` ordering;
- source closed contour/hole polyline form;
- literal `Point::is_in_lines(const Points&)` matching semantics;
- strict `< SCALED_EPSILON` diagonal distance boundary;
- exact `SCALED_EPSILON = 10` node-bbox expansion;
- one-outwall `loop_id = 0` shortcut;
- multi-outwall matching after wall-sequence in extrusion entity order while skipping exact internal-perimeter role;
- global sequential `node_id` assignment, including preexisting caller-owned nodes;
- per-island `[first, second)` `loop_node_range` assignment.

This is the classic producer side only. Later consumers that use loop-node relationships across layers are not automatically proven by these tests.

## Fuzzy skin / Arachne retained

The 387-test suite re-executes the scoped fuzzy evidence from run #249 and later checkpoints: exact fuzzy policy and slowdown gates; one Classic RNG stream plus MT19937/libstdc++ oracles; pinned libnoise modes; Polygon/Polyline fuzzy and painted-region LineSegmentation; source ZAttributes / Dart Clipper2 compatibility; source-shaped Arachne extrusion-line subset; all three fuzzy modes with seeded C++ goldens; and Arachne painted-region composition.

The fuzzy scope still does not prove the full Arachne wall generator or every pathological clipping topology.

## Classic work still open

The represented classic source path is substantially more connected now, but later consumers and broad pathological geometry remain open. The loop-node producer does not prove the downstream inter-layer matching / speed-control consumer. Complete later fill generation, seam logic and full G-code integration are also outside this checkpoint.

## Immediate next dependency order

The next wall-generation priority is pinned `PerimeterGenerator::process_arachne()`:

1. Port `Arachne::WallToolPathsParams` and exact constructor scaling/state from pinned `Arachne/WallToolPaths.hpp/.cpp`.
2. Port independently testable `WallToolPaths` input-normalization/simplification foundations with source/C++ fixtures before attempting generated walls.
3. Follow the actual `WallToolPaths::generate()` dependency chain through beading strategies and `SkeletalTrapezoidation`; validate each seam independently.
4. Compose the `process_arachne()` one-wall/separate-wall-generation paths only after those wall-generator dependencies are green.
5. Reuse the already-ported Arachne `ExtrusionLine`, fuzzy-skin and LineSegmentation consumers rather than duplicating them.
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
