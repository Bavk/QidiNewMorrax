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

- code commit `0d52a4272197bbbaa5a6c799023eed4c59dc0362` (`test: cover Arachne process branch plan`);
- `.github/workflows/flutter-parity.yml` run `34718196236` (#346);
- Flutter `3.47.2`;
- Dart `3.13.2`;
- `flutter analyze` → **No issues found!**;
- `flutter test --reporter expanded` → **618/618 passed**;
- job conclusion → **success**.

Important checkpoints leading here:

- `2a33afd...` / run #276: ordered classic islands through fuzzy/overhang/wall-sequence plus QIDI loop-node metadata, 387/387 green;
- `6978000...` / run #278: first `Arachne::WallToolPaths` constructor/simplifier slice, 395/395 green;
- `10f642e...` / run #317: post-construction `SkeletalTrapezoidation::generateToolpaths()` runtime composed, 551/551 green;
- `5c77305...` / run #330: polygon construction is composed into skeletal variable-width toolpaths, 584/584 green;
- `f23293e...` / run #340: full represented `WallToolPaths::generate()` source-order composition is green, 604/604;
- `4832008...` + `9ac38dc...`: `computePointCellRange()` secondary-edge assertion corrected to pinned `!is_secondary()` semantics and frozen by regression coverage;
- `41c8ffe...` + `0d52a42...` / run #346: first source-shaped `PerimeterGenerator::process_arachne()` orchestration slice, 618/618 green.

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

## Arachne wall-generation dependencies — polygon construction and WallToolPaths runtime represented

The Arachne dependency chain has moved past the old graph-construction blocker:

- `WallToolPaths` numeric/config state and standalone simplifier retain source float/double/truncation quirks;
- prepared-outline repair/cleanup, beading scalar inputs, `BeadingStrategy` implementations and factory composition are represented;
- the direct Boost/Voronoi Dart topology is connected to source-shaped Arachne polygon segment/source-index semantics;
- `computePointCellRange()`, all represented `discretize()` branches, `makeNode()` / `transferEdge()` identity behavior, pointy-end separation, `collapseSmallEdges()` and incident-edge normalization are composed in `constructFromPolygons()`;
- the `computePointCellRange()` secondary-edge invariant now matches pinned C++ (`vertex0 == sourcePoint || !edge.secondary`), with an explicit regression fixture;
- real square polygon fixtures execute Boost Voronoi → Arachne half-edge construction and retain reciprocal twin / chain-start invariants;
- post-construction `SkeletalTrapezoidation::generateToolpaths()` composes source order through central classification, bead-count propagation, transition/rib generation and all seven represented `generateSegments()` stages;
- `WallToolPaths::generate()` now composes prepared outline → beading strategy → skeletal generation → stitch → small-line removal → inner-contour extraction → simplify → empty-path removal, including early-return state and hole-compensation gate;
- the represented real-square path reaches variable-width Arachne lines and `WallToolPaths` output under CI.

This is still **not full Arachne `PerimeterGenerator::process_arachne()` parity**. The first orchestration slice now freezes the source one-wall gates, normal-vs-separate generation decision, exact precise-outer-wall `wall_0_inset`, `loop_number + 1` inset count, no-wall early skip, and normal/one-wall handoff into the composed `WallToolPaths::generate()` path. The `Alltop` separate-wall clipping/recombination branch is intentionally exposed as an unfinished seam instead of being approximated.

## Fuzzy / Arachne scope retained

The 618-test suite re-runs all previously verified fuzzy evidence: exact `FuzzySkinType` policy; one Classic RNG stream; MT19937/libstdc++ `[0,1)` oracles; pinned libnoise Perlin/Billow/RidgedMulti/Voronoi; Polygon/Polyline fuzzy geometry and painted-region LineSegmentation; source ZAttributes compatibility; source-shaped Arachne `ExtrusionLine`; `Displacement`, `Extrusion`, `Combined` seeded C++ goldens; and region-aware Arachne fuzzy composition.

## First unfinished priority

Continue pinned `PerimeterGenerator::process_arachne()` from the explicit `separateWallGeneration` seam:

1. port/compose the `Alltop` one-wall area decision around `should_enable_top_one_wall()`, preserving null/non-null upper-slice behavior, bbox pruning, offsets and clipping order;
2. reproduce the separate first-wall generation, `top_fills` / remainder split, second `WallToolPaths` generation and exact recombination into perimeter toolpaths and inner contour;
3. compose source wall-path conversion/order (`getRegionOrder`, blocked-order nearest candidate handling, `InnerOuterInner` adjustment and `traverse_extrusions`) without normalizing source tie-breaking;
4. compose `add_infill_contour_for_arachne()` and the final `fill_surfaces` / `fill_no_overlap` boundary for normal, one-wall and separate-wall branches;
5. add independent C++/source goldens for complete per-surface polygon → Arachne walls → ordered extrusion/fill-boundary output, including holes, top-one-wall and circle-compensation cases;
6. only then promote the represented `process_arachne()` slice beyond `port_started`.

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
