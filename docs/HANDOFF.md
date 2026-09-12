# Handoff — Qidi Flow strict Flutter/Dart rewrite

This repository is a **strict 1:1 reimplementation** of Qidi Flow 2.07.02.60 Pass28 in Flutter + Dart. The legacy C++/wxWidgets/React application is reference material only and must not remain a runtime backend through FFI, subprocesses, native shared libraries, hidden services, or embedded legacy WebViews.

## Read first

1. [`../migration/PARITY_CONTRACT.md`](../migration/PARITY_CONTRACT.md) — acceptance authority.
2. [`../migration/MIGRATION_STATUS.md`](../migration/MIGRATION_STATUS.md) — subsystem truth and dependency order.
3. [`../migration/TRACEABILITY.md`](../migration/TRACEABILITY.md) — source → Dart → evidence ledger.
4. [`../migration/VALIDATION.md`](../migration/VALIDATION.md) — executed evidence.
5. [`../migration/FUZZY_SKIN_SOURCE_NOTES.md`](../migration/FUZZY_SKIN_SOURCE_NOTES.md) — pinned fuzzy-skin contract.

Do not infer completion from visual similarity, compilation, or common-case tests. Source quirks are part of the contract.

## Current validated checkpoint — 2026-09-12

Latest validated code checkpoint:

- code commit `b069eb1d5091149780b8257821a5bc28dc49d6c2` (`fix: preserve double epsilon in Arachne traversal`);
- `.github/workflows/flutter-parity.yml` run `34720179978` (#371);
- Flutter `3.47.2`;
- Dart `3.13.2`;
- `flutter analyze` → **No issues found!**;
- `flutter test --reporter expanded` → **669/669 passed**;
- job conclusion → **success**.

Important checkpoints leading here:

- `2a33afd...` / run #276: ordered classic islands through fuzzy/overhang/wall-sequence plus QIDI loop-node metadata, 387/387 green;
- `6978000...` / run #278: first `Arachne::WallToolPaths` constructor/simplifier slice, 395/395 green;
- `10f642e...` / run #317: post-construction `SkeletalTrapezoidation::generateToolpaths()` runtime composed, 551/551 green;
- `5c77305...` / run #330: polygon construction is composed into skeletal variable-width toolpaths, 584/584 green;
- `f23293e...` / run #340: full represented `WallToolPaths::generate()` source-order composition is green, 604/604;
- `4832008...` + `9ac38dc...`: `computePointCellRange()` secondary-edge assertion corrected to pinned `!is_secondary()` semantics and frozen by regression coverage;
- `41c8ffe...` + `0d52a42...` / run #346: first source-shaped `PerimeterGenerator::process_arachne()` orchestration slice, 618/618 green;
- `3fcb49d...` + `90eec08...` / run #353: non-separated per-surface Arachne processing composes simplify/offset, circle-compensation topology mapping, real `WallToolPaths`, and inner-contour output, 638/638 green;
- `7319a3e...` + `6d71b50...`: pinned `should_enable_top_one_wall()` geometry and bbox/clipping helpers represented;
- `a5281ce...` + `a8c2327...`: `Alltop` separate first-wall/remainder wall generation and recombination represented;
- `aff8220...` + `de200a2...` and `62fe187...` + `06187f8...`: `getRegionOrder`, blocked nearest-candidate ordering and `InnerOuterInner` Arachne ordering represented;
- `f8c7774...`: Arachne `to_thick_polyline()` helper corrected to the actual `ThickPolyline2` source-shaped fields;
- `8664d98...` + `7c801dc...` + `b069eb1...` / run #371: non-overhang `traverse_extrusions()` now composes fuzzy transform, source variable-width conversion, loop/open packaging, winding restoration and circle-compensation propagation, 669/669 green.

## Current represented classic surface → extrusion path — scoped parity verified

Pinned source: `bambulab/BambuStudio@f2b55a5a83f266cf56e06c7943a81a08bebb7fad`.

The represented `PerimeterGenerator::process_classic()` path composes, in source order:

- `Surfaces all_surfaces = this->slices->surfaces` with pinned `Surface` copy semantics;
- `BridgeDetector` plus `process_no_bridge()` for `None`, `Bridges` and `Filled` branches;
- conditional surface simplification resolution, `chain_expolygons()` ordering and per-surface `extra_perimeters` / alternate-extra-wall accounting;
- per-island top-one-wall gates, onion shell, Alltop mutation, thin-wall/gap-fill and final `fill_surfaces` / `fill_no_overlap` boundary;
- each prepared island feeding the classic loop tree and recursive fuzzy/overhang traversal;
- wall-sequence adjustment inside each island before global `loops` append;
- one shared fuzzy random stream across ordered islands;
- null versus non-null empty lower-slice semantics;
- nested per-island `ExtrusionEntityCollection` shape and global gap-fill accumulation.

### QIDI outwall / loop-node metadata represented in this scope

The classic `z_direction_outwall_speed_continuous` producer is represented for raw thin/smaller/normal outer-wall `NodeContour` capture, literal `Point::is_in_lines`, single/multiple outwall matching, global node IDs and per-island `loop_node_range`. Downstream inter-layer relationship/speed-control consumers remain open.

### Important QIDI compensation quirk retained

The supplied source `Surface` copy constructor omits QIDI `counter_circle_compensation` and `holes_circle_compensation`. Therefore `Surfaces all_surfaces = this->slices->surfaces` resets those additions before the later classic lookup. The Dart high-level path preserves this behavior.

## Arachne wall-generation dependencies — construction, surface planning and non-overhang traversal represented

The Arachne dependency chain has moved past the old graph-construction and `Alltop` blockers:

- `WallToolPaths` numeric/config state and standalone simplifier retain source float/double/truncation quirks;
- prepared-outline repair/cleanup, beading scalar inputs, `BeadingStrategy` implementations and factory composition are represented;
- the direct Boost/Voronoi Dart topology is connected to source-shaped Arachne polygon segment/source-index semantics;
- `computePointCellRange()`, represented `discretize()` branches, `makeNode()` / `transferEdge()` identity behavior, pointy-end separation, `collapseSmallEdges()` and incident-edge normalization are composed in `constructFromPolygons()`;
- post-construction `SkeletalTrapezoidation::generateToolpaths()` composes source order through central classification, bead-count propagation, transition/rib generation and all represented `generateSegments()` stages;
- `WallToolPaths::generate()` composes prepared outline → beading strategy → skeletal generation → stitch → small-line removal → inner-contour extraction → simplify → empty-path removal;
- per-surface processing covers normal/topmost/first-layer one-wall planning plus `Alltop` area decision, upper/lower bbox clipping, first-wall generation, top/remainder split, second wall generation, inset-index shift and recombination;
- source Arachne extrusion ordering covers region constraints, open-before-closed candidate handling, nearest selection, contour/hole classification and `InnerOuterInner` reorder;
- the non-overhang `traverse_extrusions()` path now applies existing Arachne fuzzy-skin logic, source `to_thick_polyline()` width pairs, QIDI variable-width conversion, closed-loop/open-multipath packaging, original contour/hole winding restoration, and circle-compensation flags.

This is still **not full Arachne `PerimeterGenerator::process_arachne()` parity**. The active overhang branch inside `traverse_extrusions()` is deliberately rejected rather than approximated, and the Arachne-specific QIDI `z_direction_outwall_speed_continuous` loop-node producer is likewise still an explicit seam. The standalone `add_infill_contour_for_arachne()` helper is represented, but the final per-surface process composition into global `loops`, `fill_surfaces` and `fill_no_overlap` still needs to be closed and independently validated.

## Fuzzy / Arachne scope retained

The 669-test suite re-runs all previously verified fuzzy evidence: exact `FuzzySkinType` policy; one Classic RNG stream; MT19937/libstdc++ `[0,1)` oracles; pinned libnoise Perlin/Billow/RidgedMulti/Voronoi; Polygon/Polyline fuzzy geometry and painted-region LineSegmentation; source ZAttributes compatibility; source-shaped Arachne `ExtrusionLine`; `Displacement`, `Extrusion`, `Combined` seeded C++ goldens; and region-aware Arachne fuzzy composition.

## First unfinished priority

Continue pinned `PerimeterGenerator::traverse_extrusions()` and the final `process_arachne()` boundary in source order:

1. port the active Arachne overhang path exactly: lower-slice bbox pruning, width-carrying Clipper-Z intersection/difference, source overhang-speed branch, unsupported bridge-wall role/flow, open-path start-point preference, chain/reorder and `smooth_overhang_level()`;
2. compose the Arachne-specific `z_direction_outwall_speed_continuous` external `LoopNode` producer and `loop_node_range` semantics without borrowing classic-only assumptions;
3. compose per-surface walls → Arachne ordering → `traverse_extrusions()` → already represented `add_infill_contour_for_arachne()` → global `loops`, `fill_surfaces` and `fill_no_overlap` in pinned source order;
4. add independent C++/source goldens for complete per-surface polygon → Arachne walls → ordered extrusion/fill-boundary output, including holes, Alltop/topmost/first-layer one-wall, circle compensation and overhang cases;
5. only then promote the represented `process_arachne()` slice beyond `port_started`.

Full Arachne wall generation remains `port_started` until that end-to-end process boundary is validated.

## Numeric/source invariants

- slicer coordinates use `SCALING_FACTOR = 0.00001` mm (100000 source units/mm);
- preserve source integer geometry until the source converts units;
- preserve explicit/implicit `float` boundaries before geometry/config arithmetic;
- preserve source `scaled<T>` truncation, `lrint`, round and cast boundaries rather than normalizing them;
- keep Boost.Polygon 1.83 operand/bit semantics, including existing `BigInt` boundaries;
- keep QIDI/Clipper compatibility quirks frozen by regression tests;
- never replace a source oddity with a cleaner algorithm without an independent source oracle.

## Other major open areas

All top-level gates remain **OPEN**. Major remaining work includes complete Arachne process integration, later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft toolpaths, full G-code state/templates/travel/retract/cooling/multimaterial behavior, project/profile round trips and STEP/source-enabled import formats, scene/editor and Preview parity, Device/cloud/P2P/account/camera/HMS/firmware, calibration, desktop integration, full UI/localization/accessibility, runtime asset publication/verification, and exhaustive reference/differential tests.

## Working discipline

For each source batch: identify exact source functions and dependencies; port literal behavior; add source-oracle/translated/differential tests; confirm `.github/workflows/flutter-parity.yml` on pinned Flutter 3.47.2; do not weaken analyzer/tests; then update migration ledgers and this handoff. A scoped passing test never closes a top-level product gate.
