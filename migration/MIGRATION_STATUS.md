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
- validated code `0a9fa8155e0e860b82177280a379a7b9dccfeeb5`;
- workflow `34695501638` (#273), conclusion **success**;
- `flutter analyze` — **No issues found!**;
- `flutter test --reporter expanded` — **377/377 passing**.

Milestones in the current classic source-preprocessing slice:

- #260 / `ae218af...`: represented per-island shell → Alltop → gap-fill → final fill boundary, 351/351;
- #264 / `1b2f5f4...`: pinned `BridgeDetector` plus translated upstream `t/bridges.t` fixtures, 359/359;
- #268 / `d9ad4a5...`: `process_no_bridge()` source gates and both active counterbore branches, 365/365;
- #273 / `0a9fa815...`: counterbore pre-pass → surface preprocessing/order → per-island fill composition, 377/377.

## Top-level gates

All remain **OPEN**: formats/project persistence; scene/editor; slicer/toolpath; Preview; profiles/presets; Device/cloud; calibration; desktop/release integration; UI/localization/accessibility; complete reference/differential coverage.

## Verified foundations retained

The current green suite retains scoped `parity_verified` coverage for represented source integer geometry, Polyline/ArcFitter/Circle, ThickPolyline, Boost.Polygon 1.83 robust predicates/Fortune/Voronoi fixtures, MedialAxis, translated Clipper/ClipperUtils behavior used by current consumers, Flow, Extruder/QIDI config subset, Surface, ExtrusionEntity/variable-width/covered-width subset, source-style G-code formatter/path emitter subset, classic perimeter shell/nesting/chaining/wall-sequence/lower-support/no-speed/speed-graded overhang pipeline, and the represented fuzzy/Arachne subset.

The broader containing modules remain `port_started`.

## Classic `process_classic()` surface → fill path — scoped `parity_verified`

Pinned source: `bambulab/BambuStudio@f2b55a5a83f266cf56e06c7943a81a08bebb7fad`.

### Bridge detection and counterbore pre-pass

`SourceBridgeDetector2` is scoped `parity_verified` for the source behavior exercised by translated pinned `t/bridges.t` fixtures:

- source 5-degree candidate family plus boundary/support-edge directions;
- source direction de-duplication;
- support-edge and safety-grown anchor construction;
- anchored scanline coverage and max-span selection;
- source coverage trapezoids and final clipping;
- O/rotated-O, two-sided, C-shaped and L-shaped support cases plus airborne failure.

`SourceClassicNoBridge2` is scoped `parity_verified` for:

- `CounterboreHoleBridgingOption` order `None, Bridges, Filled`;
- exact `None` / null lower / empty lower gate;
- source surface-vector copy semantics;
- both `ApplySafetyOffset::Yes` difference boundaries used before bridge detection;
- 1 mm `BRIDGE_INFILL_MARGIN`;
- `chbBridges` square/miter iterative offset order;
- `chbFilled` convexity/bridgeability/containment path and nested-surface mutation;
- internal bridge-fill extraction and source-style surface vector replacement/splitting.

### Surface preprocessing and island order

`SourceClassicSurfacePrepare2` is scoped `parity_verified` for:

- `m_scaled_resolution = scaled<double>(max(resolution, EPSILON))`;
- `0.2 * m_scaled_resolution` only with arc fitting enabled and fuzzy skin `None`;
- `chain_expolygons()` via source ExPolygon bbox centers and source shortest-path chaining;
- `wall_loops + Surface::extra_perimeters - 1` before top-one-wall gates;
- odd-layer alternate extra wall when not spiral vase;
- represented `simplify_p → union_ex` preprocessing;
- source centroid `lrint` behavior and `eps = 1000` compensation-hole matching;
- local compensation disable when simplification/union yields multiple ExPolygons.

Important source quirk: the supplied `Surface` copy constructor omits QIDI `counter_circle_compensation` and `holes_circle_compensation`. Therefore `Surfaces all_surfaces = this->slices->surfaces` resets those fields before later classic processing. The high-level Dart path preserves this rather than restoring the apparent intended metadata.

### Ordered islands into fill process

`SourceClassicPerimeterIslandProcess2` is scoped `parity_verified` for composing:

1. source surface-vector copy + `process_no_bridge()`;
2. conditional resolution and `chain_expolygons` order;
3. per-surface extra-perimeter accounting;
4. source-order per-island call into `SourceClassicPerimeterFillProcess2`;
5. counterbore-generated fill surfaces before per-island final fill surfaces;
6. distinct conditional shell simplification versus base-resolution final fill-boundary simplification;
7. topmost one-wall gate after per-surface wall-count accounting.

The nested shell/Alltop/thin-wall/gap-fill/final-fill portion remains scoped `parity_verified`, including the source 20% wall-overlap result **7999** source units.

### Classic work still open

The next integration boundary is after each prepared island's shell result. Existing loop-tree, `traverse_loops()`, overhang/fuzzy traversal and wall-sequence helpers are already individually represented; they still need to be composed across the new ordered-island source path. QIDI `outwall_paths`, `loop_nodes`, `loop_node_range` and `z_direction_outwall_speed_continuous` metadata also remain open. The verified `Surface` copy-reset quirk must be preserved during that integration.

## Fuzzy skin / Arachne retained

The current suite re-executes the scoped fuzzy evidence from run #249 and later checkpoints: exact fuzzy policy and slowdown gates; one Classic RNG stream plus MT19937/libstdc++ oracles; pinned libnoise modes; Polygon/Polyline fuzzy and painted-region LineSegmentation; source ZAttributes / Dart Clipper2 compatibility; source-shaped Arachne extrusion-line subset; all three fuzzy modes with seeded C++ goldens; and Arachne painted-region composition.

The fuzzy scope still does not prove the full Arachne wall generator or every pathological clipping topology.

## Other major open areas

- ordered-island composition into classic loop tree/traversal and QIDI loop-node/outwall metadata;
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

1. Compose each ordered `SourceClassicProcessedIsland2.process.perimeter` into the existing `SourceClassicPerimeterPipeline2` loop-tree / recursive traversal path, preserving per-island and collection append order.
2. Reuse the existing lower-slice overhang and fuzzy traversal helpers on that ordered-island path; do not create duplicate geometry implementations.
3. Audit and port QIDI `outwall_paths`, `loop_nodes`, `loop_node_range` and `z_direction_outwall_speed_continuous` behavior around classic traversal.
4. Preserve the source `Surface` compensation-field copy-reset quirk; do not restore metadata the pinned source loses.
5. Continue broader Arachne wall generation.
6. Continue fill/support/seam/G-code/project/profile/device/cloud/calibration/desktop/UI parity in dependency order.
7. Publish and SHA-verify real runtime assets before any release-complete claim.

No item may be promoted because it merely looks equivalent or passes only common-case smoke tests.
