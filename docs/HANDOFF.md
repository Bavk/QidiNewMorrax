# Handoff — Qidi Flow strict Flutter/Dart rewrite

This repository is a **strict 1:1 reimplementation** of Qidi Flow 2.07.02.60 Pass28 in Flutter + Dart. The legacy C++/wxWidgets/React application is reference material only and must not remain a runtime backend through FFI, subprocesses, native shared libraries, hidden services, or embedded legacy WebViews.

## Read first

1. [`../migration/PARITY_CONTRACT.md`](../migration/PARITY_CONTRACT.md) — acceptance authority.
2. [`../migration/MIGRATION_STATUS.md`](../migration/MIGRATION_STATUS.md) — subsystem truth and dependency order.
3. [`../migration/TRACEABILITY.md`](../migration/TRACEABILITY.md) — source → Dart → evidence ledger.
4. [`../migration/VALIDATION.md`](../migration/VALIDATION.md) — executed evidence.
5. [`../migration/FUZZY_SKIN_SOURCE_NOTES.md`](../migration/FUZZY_SKIN_SOURCE_NOTES.md) — pinned fuzzy-skin contract.

Do not infer completion from visual similarity, compilation, or common-case tests. Source quirks are part of the contract.

## Current validated checkpoint — 2026-09-13

Latest validated code checkpoint:

- code commit `4a33e8d2592de1790ce0d63f01c0724a499ff356` (`test: compare Arachne hole walls with pinned CLI oracle`);
- `.github/workflows/flutter-parity.yml` run `34726060018` (#402);
- Flutter `3.47.2`;
- Dart `3.13.2`;
- `flutter analyze` → **No issues found!**;
- `flutter test --reporter expanded` → **687/687 passed**;
- job conclusion → **success**.

Important checkpoints leading here:

- `2a33afd...` / run #276: ordered classic islands through fuzzy/overhang/wall-sequence plus QIDI loop-node metadata, 387/387 green;
- `6978000...` / run #278: first Arachne `WallToolPaths` numeric/simplifier dependency slice, 395/395 green;
- `10f642e...` / run #317: post-construction `SkeletalTrapezoidation::generateToolpaths()` runtime composed, 551/551 green;
- `5c77305...` / run #330: polygon construction is composed into skeletal variable-width toolpaths, 584/584 green;
- `f23293e...` / run #340: represented `WallToolPaths::generate()` source-order composition, 604/604 green;
- `41c8ffe...` + `0d52a42...` / run #346: first source-shaped `PerimeterGenerator::process_arachne()` orchestration slice, 618/618 green;
- `3fcb49d...` + `90eec08...` / run #353: non-separated per-surface Arachne wall generation, 638/638 green;
- `8664d98...` + `7c801dc...` + `b069eb1...` / run #371: non-overhang `traverse_extrusions()`, 669/669 green;
- `2a99046...` + `628fdf3...` + `aa104bd...` + `87c20a7...` / run #377: non-speed active-overhang traversal with width-preserving Clipper-Z splitting, 672/672 green;
- `4854a5c...` + `945ced6...` + `8beb613...` + `86db415...` / run #383: Arachne speed-graded overhang with 2mm sampling, signed-distance mapping, quarter-degree splitting and source smoothing quirks, 675/675 green;
- `5f4d8d3...` + `5cceb9e...` + `0d2131d...` / run #386: Arachne QIDI raw external-wall `LoopNode` producer and global `loop_node_range`, 677/677 green;
- `324ee86...` + `b3ea9db...` + `aecf3ca...` + `7eb43f3...` / run #390: final represented per-surface `process_arachne()` tail composes wall generation → source ordering → traversal → global loops → `add_infill_contour_for_arachne()` → `fill_surfaces` / `fill_no_overlap`, 681/681 green;
- `4bfb5b5...` / run #394: exact pinned compiled BambuStudio CLI independently matches an interior two-wall layer plus topmost and first-layer one-wall geometry, 684/684 green;
- `425b64d...` / run #398: exact pinned compiled CLI independently matches non-speed overhang wall spans, cyclic supported/overhang role bands and the grown-support split at model `x=20.2mm`, 685/685 green;
- `e382302...` / run #400: exact pinned compiled CLI independently matches partial-`Alltop` first-wall/remainder recombination, including the clipped inner-wall placement, 686/686 green;
- `4a33e8d...` / run #402: exact pinned compiled CLI independently matches a 20×20mm frame with a 10×10mm through-hole: four Arachne loops and both contour/hole wall-span pairs, 687/687 green.

## Independent pinned BambuStudio oracle provenance

The new process-level evidence comes from the **actual upstream compiled binary at the exact pinned source SHA**, not from a Dart-generated snapshot:

- upstream repository: `bambulab/BambuStudio`;
- source commit: `f2b55a5a83f266cf56e06c7943a81a08bebb7fad`;
- successful upstream GitHub Actions run: `34298498452` (`Build all`);
- Ubuntu 24.04 artifact ID: `10085378329`, `BambuStudio_ubuntu-24.04_V02.08.03.66`;
- downloaded artifact SHA-256: `912517d86774f4705c28a9e649f3fc91f96fe1623bdf070cb5f14f02ba3827f8`;
- extracted AppImage SHA-256: `ad90fda9a4537222a679b5d2ad12712a86652858106dce00f69fac24c3af8b46`;
- CLI version: `02.08.03.66`.

Committed JSON fixtures record that provenance plus G-code-derived wall dimensions. The comparison deliberately removes only downstream/global plate-arrange translation or closed-loop seam rebasing when those do not alter the source perimeter geometry.

## Current represented classic surface → extrusion path — scoped parity verified

Pinned source: `bambulab/BambuStudio@f2b55a5a83f266cf56e06c7943a81a08bebb7fad`.

The represented `PerimeterGenerator::process_classic()` path composes, in source order, source `Surface` vector-copy behavior; `BridgeDetector` / `process_no_bridge()`; conditional simplification and island chaining; extra-perimeter accounting; top-one-wall gates; onion shell / Alltop / thin-wall / gap-fill / fill boundaries; recursive fuzzy/overhang traversal; per-island wall sequence; one shared fuzzy RNG; nested island collections; and global gap-fill accumulation.

### QIDI outwall / loop-node metadata

The classic `z_direction_outwall_speed_continuous` producer is represented for raw thin/smaller/normal outer-wall `NodeContour` capture, literal `Point::is_in_lines`, global node IDs and per-island `loop_node_range`. The Arachne producer is represented separately from raw pre-fuzzy external Arachne lines and preserves its distinct bbox behavior. Downstream inter-layer relationship/speed-control consumers remain open.

### Important QIDI compensation quirk retained

The supplied source `Surface` copy constructor omits QIDI `counter_circle_compensation` and `holes_circle_compensation`. Therefore `Surfaces all_surfaces = this->slices->surfaces` resets those additions before the later classic lookup. The Dart high-level path preserves this behavior.

## Arachne wall-generation dependencies — represented functional surface path complete

The represented Arachne dependency chain includes:

- `WallToolPaths` numeric/config state, prepared-outline repair/cleanup, exact scalar casts, beading strategies and factory composition;
- direct Boost/Voronoi topology through `constructFromPolygons()`, source-index transfer, pointy-end separation, small-edge collapse and incident normalization;
- post-construction skeletal classification, bead-count propagation, transition/rib generation, `generateSegments()`, `generateToolpaths()` and `WallToolPaths::generate()`;
- normal/topmost/first-layer one-wall planning plus `Alltop` area decision, upper/lower bbox clipping, first-wall/top/remainder split, second wall generation and inset-index recombination;
- `getRegionOrder()`, blocked nearest-candidate ordering, open-before-closed behavior and `InnerOuterInner` adjustment;
- non-overhang traversal with fuzzy skin, source width pairs, variable-width conversion, loop/open packaging, winding restoration and circle compensation;
- non-speed active overhang with lower-support bbox pruning, Clipper-Z width interpolation/repair, supported/unsupported splitting, bridge-wall role/flow and supported-start re-chaining;
- speed-graded active overhang with source 2mm sampling, signed lower-layer distance, width-aware non-uniform 0/10/25/50/75/100 mapping, 0.25 degree split terraces and `smooth_overhang_level()` integer-degree quirk;
- Arachne-specific QIDI `LoopNode` capture before fuzzy/overhang conversion, global node IDs/entity loop IDs and exact `loop_node_range`;
- final represented per-surface composition into global loop collections plus `add_infill_contour_for_arachne()` output for `fill_surfaces` / `fill_no_overlap`, including exact one-wall mixed-spacing selection and 7999/7599 overlap truncation fixtures.

### Independently verified process-level fixture scopes

The exact pinned compiled CLI now independently verifies the represented Dart output for:

- normal interior two-wall square geometry and Inner→Outer order;
- topmost one-wall geometry;
- first-layer one-wall geometry;
- non-speed active-overhang geometry and the support/unsupported split boundary;
- partial `Alltop` first-wall/remainder recombination and placement;
- through-hole contour/hole wall geometry, including the outer contour pair `18.886/19.600mm` and hole pair `11.114/10.400mm`.

These exact fixture scopes may be treated as **scoped `parity_verified` evidence**. The containing `process_arachne()` boundary remains **`implemented_unverified`** because the remaining process-level outputs below do not yet have independent pinned-binary/oracle coverage.

## Fuzzy / Arachne scope retained

The 687-test suite re-runs all previously verified fuzzy/Arachne evidence, including seeded C++ fuzzy goldens, source ZAttributes / LineSegmentation behavior, direct Boost/Voronoi fixtures, both represented Arachne overhang branches, QIDI LoopNode production, the final composed surface path and the new compiled-CLI differential fixtures.

## First unfinished priority

Continue independent validation in source order rather than adding another already-represented helper:

1. obtain a process-level independent oracle for **speed-graded Arachne overhang geometry/degrees** without conflating downstream G-code speed policy;
2. obtain independent evidence for Arachne QIDI `LoopNode` payload/ranges, which ordinary G-code does not expose directly;
3. obtain independent circle-compensation metadata/geometry evidence; the through-hole CLI fixture verifies hole wall geometry only, not QIDI compensation flags;
4. independently validate final `fill_surfaces` / `fill_no_overlap`, including no-wall and mixed-spacing cases that are not directly observable from normal G-code;
5. expand to additional pathological/production geometries and resolve every differential mismatch without weakening literal source quirks;
6. only after those gates are green consider promoting the represented `process_arachne()` boundary as a whole to scoped `parity_verified`, then continue later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft toolpaths and downstream product systems.

## Numeric/source invariants

- slicer coordinates use `SCALING_FACTOR = 0.00001` mm (100000 source units/mm);
- preserve source integer geometry until the source converts units;
- preserve explicit/implicit `float` boundaries before geometry/config arithmetic;
- preserve source `scaled<T>` truncation, `lrint`, round and cast boundaries rather than normalizing them;
- keep Boost.Polygon 1.83 operand/bit semantics, including existing `BigInt` boundaries;
- keep QIDI/Clipper compatibility quirks frozen by regression tests;
- never replace a source oddity with a cleaner algorithm without an independent source oracle.

## Other major open areas

All top-level gates remain **OPEN**. Major remaining work includes completion of Arachne process-level differential coverage, later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft toolpaths, full G-code state/templates/travel/retract/cooling/multimaterial behavior, project/profile round trips and STEP/source-enabled import formats, scene/editor and Preview parity, Device/cloud/P2P/account/camera/HMS/firmware, calibration, desktop integration, full UI/localization/accessibility, runtime asset publication/verification, and exhaustive reference/differential tests.

## Working discipline

For each source batch: identify exact source functions and dependencies; port literal behavior; add source-oracle/translated/differential tests; confirm `.github/workflows/flutter-parity.yml` on pinned Flutter 3.47.2; do not weaken analyzer/tests; then update migration ledgers and this handoff. A scoped passing test never closes a top-level product gate.
