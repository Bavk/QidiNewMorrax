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
- validated code `10f642e0d3952b61eefe4c8bdda2fcd909a4eba2`;
- workflow `34714922159` (#317), conclusion **success**;
- `flutter analyze` — **No issues found!**;
- `flutter test --reporter expanded` — **551/551 passing**.

Milestones in the current source path:

- #276 / `2a33afd...`: ordered classic islands → traversal/fuzzy/overhang/wall sequence + QIDI loop-node metadata, 387/387;
- #278 / `6978000...`: first Arachne `WallToolPaths` numeric/simplifier dependency slice, 395/395;
- #308 / `f211b19...`: `generateSegments()` foundation, 521/521;
- #311 / `34eaac7...`: source beading propagation and shared-object mutation semantics;
- #313 / `9b61d75...`: Arachne junction generation with exact `scaled(0.005) == 499` boundary;
- #314 / `3d8bf3c...`: junction connection and variable-width path stitching;
- #315 / `09c6249...`: local-max single-bead circles;
- #316 / `0ede85b...`: all seven `generateSegments()` stages composed;
- #317 / `10f642e...`: post-construction `SkeletalTrapezoidation::generateToolpaths()` runtime composed, 551/551.

## Top-level gates

All remain **OPEN**: formats/project persistence; scene/editor; slicer/toolpath; Preview; profiles/presets; Device/cloud; calibration; desktop/release integration; UI/localization/accessibility; complete reference/differential coverage.

## Verified foundations retained

The current green suite retains scoped `parity_verified` coverage for represented source integer geometry, Polyline/ArcFitter/Circle, ThickPolyline, Boost.Polygon 1.83 robust predicates/Fortune/Voronoi fixtures, MedialAxis, translated Clipper/ClipperUtils behavior used by current consumers, Flow, Extruder/QIDI config subset, Surface, ExtrusionEntity/variable-width/covered-width subset, source-style G-code formatter/path emitter subset, classic perimeter preprocessing/shell/traversal/metadata pipeline, fuzzy/Arachne subsets, Arachne beading strategies, and the represented post-construction skeletal runtime.

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
- central classification/filtering, bead-count propagation, noncentral dissolution, transition generation/filtering/application, nonlinear extra ribs;
- full represented `generateSegments()` runtime after graph construction: upward ordering, local beadings/interpolation, upward/downward propagation, extrusion-junction generation, junction connection and local-maximum single beads;
- top-level post-construction `generateToolpaths()` source-order composition.

The exact `generateToolpaths()` runtime on an already constructed graph is now scoped `parity_verified` by #317. Important source numeric seams remain explicit: `scaled(0.1)==10000`, `scaled(0.02)==2000`, `scaled(0.010)==999`, `scaled(0.005)==499`, float32 transition/interpolation ratios, integer cast/truncation behavior, and shared `BeadingPropagation` identity mutation.

Full Arachne wall generation remains `port_started`: the missing constructor seam is `SkeletalTrapezoidation::constructFromPolygons()` from real polygon segments through the Boost Voronoi diagram into the half-edge graph. `WallToolPaths::generate()` / `PerimeterGenerator::process_arachne()` have not yet been validated end-to-end from input polygons to generated wall paths.

## Fuzzy skin / Arachne retained

The 551-test suite re-executes the scoped fuzzy evidence: exact fuzzy policy and slowdown gates; one Classic RNG stream plus MT19937/libstdc++ oracles; pinned libnoise modes; Polygon/Polyline fuzzy and painted-region LineSegmentation; source ZAttributes / Dart Clipper2 compatibility; source-shaped Arachne extrusion-line subset; all three fuzzy modes with seeded C++ goldens; and Arachne painted-region composition.

## Immediate next dependency order

Continue pinned `SkeletalTrapezoidation::constructFromPolygons()`:

1. connect the existing direct Boost/Voronoi Dart representation to source Arachne polygon-segment/source-index semantics;
2. port `computePointCellRange()` exactly;
3. port `discretize()` in the source branch order (straight/secondary, point-line parabola, point-point marking/step logic);
4. port `makeNode()` / `transferEdge()` with identity maps for VD vertices/edges and exact twin-first versus first-side behavior;
5. compose polygon → Voronoi → half-edge graph → pointy-end separation → `collapseSmallEdges()` → incident-edge normalization and validate simple real polygons against source/C++ topology/toolpath oracles;
6. then compose actual `WallToolPaths::generate()` and `process_arachne()` output;
7. continue later fill/support/seam/G-code/project/profile/device/cloud/calibration/desktop/UI parity in dependency order;
8. publish and SHA-verify real runtime assets before any release-complete claim.

## Other major open areas

- Voronoi-to-Arachne graph construction and full `WallToolPaths::generate()` / `process_arachne()` integration;
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
