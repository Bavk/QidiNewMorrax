# Handoff — Qidi Flow strict Flutter/Dart rewrite

This repository is a **strict 1:1 reimplementation** of Qidi Flow 2.07.02.60 Pass28 in Flutter + Dart. The legacy C++/wxWidgets/React application is reference material only and must not remain a runtime backend through FFI, subprocesses, native shared libraries, hidden services, or embedded legacy WebViews.

## Read first

1. [`../migration/PARITY_CONTRACT.md`](../migration/PARITY_CONTRACT.md) — acceptance authority.
2. [`../migration/MIGRATION_STATUS.md`](../migration/MIGRATION_STATUS.md) — subsystem truth and dependency order.
3. [`../migration/TRACEABILITY.md`](../migration/TRACEABILITY.md) — source → Dart → evidence ledger.
4. [`../migration/VALIDATION.md`](../migration/VALIDATION.md) — executed evidence.
5. [`../migration/FUZZY_SKIN_SOURCE_NOTES.md`](../migration/FUZZY_SKIN_SOURCE_NOTES.md) — pinned fuzzy-skin contract.

Do not infer completion from visual similarity, compilation, or common-case tests. Source quirks are part of the contract.

## Current validated checkpoint — 2026-09-14

Latest validated code checkpoint:

- code commit `af49053c1dec88f6a666c07939fd9bfe0a7a73ca` (`test: cover noninteracting Clipper1 NonZero union subset`);
- `.github/workflows/flutter-parity.yml` run `34792959794` (#466);
- Flutter `3.47.2`;
- Dart `3.13.2`;
- `flutter analyze` → **No issues found!**;
- `flutter test --reporter expanded` → **729/729 passed**;
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
- `4a33e8d...` / run #402: exact pinned compiled CLI independently matches a 20×20mm frame with a 10×10mm through-hole: four Arachne loops and both contour/hole wall-span pairs, 687/687 green;
- `70ba8a1...` / run #412: exact pinned compiled `detect_overhang_degree()` return paths independently match both stepped-solid Arachne walls: 39 exact role/degree buckets each, with only closed-loop Y reflection normalization and source `SCALED_EPSILON` geometry tolerance, 688/688 green;
- `7b4f2ba...` / run #416: exact pinned compiled `traverse_extrusions()` state independently matches Arachne QIDI `LoopNode` payload/ranges for normal two-wall and topmost one-wall cases, 690/690 green;
- `c1ef43d...` + `4455fb1...` / run #421: high-level Arachne preserves the source `Surface` copy quirk that clears QIDI circle-compensation metadata; an exact compiled ring probe proves compensation geometry changed upstream while all four Arachne lines still reach `shouldApplyHoleCompensation()` unmarked, 692/692 green;
- `bf8e661...` + `0ebb25a...` / run #423: exact compiled `add_infill_contour_for_arachne()` entry/output state independently matches no-wall, one-wall mixed-spacing and two-wall `fill_surfaces` / `fill_no_overlap`, 695/695 green;
- `7fe568c...` + `e726950...` / run #438: exact pinned compiled narrow-wedge Arachne output exposed and closed a real Clipper1-vs-Clipper2 pre-wall offset drift (up to 39 source units); the single-convex positive-contour Clipper1 miter/erosion subset matches the compiled wedge while preserving exhausted-inset collapse semantics, 699/699 green;
- `2a80fc4...` + `403cf2f...` + `510b0d4...` + `51ca143...` + `fdcbbf1...` / run #450: pinned Clipper1 closed-path arithmetic includes literal raw `OffsetPoint()` concave triplets, `AddPath()` shortest-edge pruning, convex CW-hole sign/orientation handling and exact per-path convex contour/hole offsets, 709/709 green;
- `8585dcb...` + `3913a04...` + `8ac1935...` / run #463: exact single-result rectilinear `Execute()` cleanup closes the topology-changing narrow-L expansion/erosion oracle rather than delegating that case to Clipper2, 724/724 green;
- `3df4434...` + `4df1e8f...` + `af49053...` / run #466: exact per-path convex outputs now bypass the final Clipper2 union for conservative noninteracting NonZero cases (direct holes and disconnected positive islands); nested/touching/interacting cases remain explicit fallbacks, and the pinned through-hole process oracle remains green, 729/729.

## Independent pinned BambuStudio oracle provenance

The process-level evidence comes from the **actual upstream compiled binary at the exact pinned source SHA**, not from a Dart-generated snapshot:

- upstream repository: `bambulab/BambuStudio`;
- source commit: `f2b55a5a83f266cf56e06c7943a81a08bebb7fad`;
- successful upstream GitHub Actions run: `34298498452` (`Build all`);
- Ubuntu 24.04 artifact ID: `10085378329`, `BambuStudio_ubuntu-24.04_V02.08.03.66`;
- downloaded artifact SHA-256: `912517d86774f4705c28a9e649f3fc91f96fe1623bdf070cb5f14f02ba3827f8`;
- extracted AppImage SHA-256: `ad90fda9a4537222a679b5d2ad12712a86652858106dce00f69fac24c3af8b46`;
- CLI version: `02.08.03.66`.

G-code fixtures deliberately remove only downstream/global plate-arrange translation or closed-loop seam rebasing when those do not alter source perimeter geometry. The speed-graded overhang oracle is stronger: it is captured from the compiled return value of `Slic3r::detect_overhang_degree()` before re-chaining, smoothing and G-code speed policy. For the symmetric closed stepped-solid probe, one global Y reflection is normalized because the source Clipper path may begin from the opposite horizontal side. Roles and quarter-degree buckets remain exact. Integer XY comparison uses only the pinned source `SCALED_EPSILON = EPSILON / SCALING_FACTOR = 10` source units to account for compiled STL slicing versus the Dart fixture beginning from the already-sliced polygon.

The QIDI Arachne `LoopNode` oracle is likewise captured from the compiled `traverse_extrusions()` process state rather than G-code. Machine-code inspection fixes the `LoopNode` stride at 136 bytes and identifies the global `loop_nodes` and returned `loop_node_range` fields. The differential keeps node/range IDs, raw width payloads, loop flags and raw junction order exact; it removes only global plate translation from XY and uses the same pinned `SCALED_EPSILON`. It also independently confirms the QIDI bbox quirk: `outer_wall_line_width / 2` is passed directly to integer `BoundingBox::offset`, so `0.4 / 2` narrows to zero source units.

The circle-compensation oracle uses an exact compiled 128-segment 20mm OD / 10mm ID ring. Enabling upstream auto circle compensation changes all four captured wall centerline radii versus the disabled run, proving the producer executed. Nevertheless pinned `process_arachne()` first copies `Surface`; because that copy constructor omits QIDI `counter_circle_compensation` / `holes_circle_compensation`, all four generated Arachne lines reach `shouldApplyHoleCompensation()` with zero marked junctions and return false. The Dart high-level process preserves that literal source quirk. This evidence verifies the `process_arachne()` metadata boundary; the broader upstream `LayerRegion::auto_circle_compensation()` geometry producer remains a separate slicer dependency to port/validate where not already represented.

The final-fill oracle reads the exact compiled `add_infill_contour_for_arachne()` call arguments and destination vectors before downstream infill/G-code. It independently verifies `loops=-1/0/1` for zero/one/two requested walls, and for a one-wall mixed-width case it captures external spacing `37707`, perimeter spacing `40707`, and caller-selected mixed spacing `39207`. Output `fill_surfaces` / `fill_no_overlap` spans are compared after removing only plate translation and allowing pinned `SCALED_EPSILON=10`.

The narrow-wedge oracle reads exact compiled `process_arachne()` variable-width junctions for a 20mm long polygon tapering from 0.45mm to 1.20mm. The first differential found a systematic Dart X drift from 2 to 39 source units while Y, width and perimeter index were exact. The mismatch was traced to using Clipper2 where pinned `process_arachne()` uses modified Clipper 6.2.9 (`Clipper1`) `offset(..., jtMiter, 3.)`. The represented source adapter now preserves Clipper1 float32 delta/shortest-edge setup, literal `AddPath()` pruning, double unit normals, half-away-from-zero `Round()`, near-collinear/concave/miter/square `OffsetPoint()` construction, convex negative cleanup, the per-path orientation/sign convention used by `raw_offset()`, exact single-result orthogonal topology cleanup, and a conservative noninteracting cross-path NonZero subset. General non-orthogonal concave cleanup, multi-result rectilinear cleanup and interacting/deep-nesting cross-path boolean union remain explicit open seams.

## Current represented classic surface → extrusion path — scoped parity verified

Pinned source: `bambulab/BambuStudio@f2b55a5a83f266cf56e06c7943a81a08bebb7fad`.

The represented `PerimeterGenerator::process_classic()` path composes, in source order, source `Surface` vector-copy behavior; `BridgeDetector` / `process_no_bridge()`; conditional simplification and island chaining; extra-perimeter accounting; top-one-wall gates; onion shell / Alltop / thin-wall / gap-fill / fill boundaries; recursive fuzzy/overhang traversal; per-island wall sequence; one shared fuzzy RNG; nested island collections; and global gap-fill accumulation.

### QIDI outwall / loop-node metadata

The classic `z_direction_outwall_speed_continuous` producer is represented for raw thin/smaller/normal outer-wall `NodeContour` capture, literal `Point::is_in_lines`, global node IDs and per-island `loop_node_range`. The Arachne producer is represented separately from raw pre-fuzzy external Arachne lines and preserves its distinct bbox behavior. The Arachne producer payload/range semantics also have independent compiled-binary evidence. Downstream inter-layer relationship/speed-control consumers remain open.

### Important QIDI compensation quirk retained

The supplied source `Surface` copy constructor omits QIDI `counter_circle_compensation` and `holes_circle_compensation`. Therefore `Surfaces all_surfaces = this->slices->surfaces` resets those additions before the later lookup. Both represented classic and Arachne high-level paths preserve this behavior. The compiled Arachne ring oracle independently confirms the reset occurs even when upstream auto circle compensation changed geometry before the copy.

## Arachne wall-generation dependencies — represented functional surface path complete

The represented Arachne dependency chain includes:

- `WallToolPaths` numeric/config state, prepared-outline repair/cleanup, exact scalar casts, beading strategies and factory composition;
- pinned Clipper1 closed-path arithmetic for simple convex positive contours plus exact per-path convex contour/hole handling: float32 delta/shortest-edge setup, literal `AddPath()` short-edge pruning, double unit normals, half-away `Round`, near-collinear/concave/miter/square `OffsetPoint()` construction, convex negative cleanup and CW-hole sign/orientation restoration; exact orthogonal concave cleanup includes both safe and single-result topology-changing cases; noninteracting one-level NonZero cross-path unions now bypass Clipper2, while non-orthogonal concave, multi-result rectilinear and interacting/deeper cross-path booleans remain explicit compatibility seams;
- direct Boost/Voronoi topology through `constructFromPolygons()`, source-index transfer, pointy-end separation, small-edge collapse and incident normalization;
- post-construction skeletal classification, bead-count propagation, transition/rib generation, `generateSegments()`, `generateToolpaths()` and `WallToolPaths::generate()`;
- normal/topmost/first-layer one-wall planning plus `Alltop` area decision, upper/lower bbox clipping, first-wall/top/remainder split, second wall generation and inset-index recombination;
- `getRegionOrder()`, blocked nearest-candidate ordering, open-before-closed behavior and `InnerOuterInner` adjustment;
- non-overhang traversal with fuzzy skin, source width pairs, variable-width conversion, loop/open packaging, winding restoration and circle compensation;
- non-speed active overhang with lower-support bbox pruning, Clipper-Z width interpolation/repair, supported/unsupported splitting, bridge-wall role/flow and supported-start re-chaining;
- speed-graded active overhang with source 2mm sampling, signed lower-layer distance, width-aware non-uniform 0/10/25/50/75/100 mapping, 0.25 degree split terraces and `smooth_overhang_level()` integer-degree quirk;
- Arachne-specific QIDI `LoopNode` capture before fuzzy/overhang conversion, global node IDs/entity loop IDs and exact `loop_node_range`;
- final represented per-surface composition into global loop collections plus `add_infill_contour_for_arachne()` output for `fill_surfaces` / `fill_no_overlap`, including independently captured no-wall, one-wall mixed-spacing and two-wall cases.

### Independently verified process-level fixture scopes

The exact pinned compiled binary now independently verifies the represented Dart output for:

- normal interior two-wall square geometry and Inner→Outer order;
- topmost one-wall geometry;
- first-layer one-wall geometry;
- non-speed active-overhang geometry and the support/unsupported split boundary;
- partial `Alltop` first-wall/remainder recombination and placement;
- through-hole contour/hole wall geometry, including the outer contour pair `18.886/19.600mm` and hole pair `11.114/10.400mm`; this oracle remains green after convex contour/hole per-path offsets and the noninteracting NonZero cross-path subset moved off the Clipper2 path;
- speed-graded active overhang before downstream speed policy: both inner/external supported walls return the same 39 exact role/degree buckets as compiled `detect_overhang_degree()`, with XY differing by no more than source `SCALED_EPSILON` after one global closed-loop reflection normalization;
- QIDI Arachne `LoopNode`: normal two-wall returns `loop_node_range=[0,1)`, `node_id=0`, `loop_id=1`; topmost one-wall returns the same range/node ID with `loop_id=0`; raw 6-junction order, six widths of `35707`, loop flag and empty upper/lower relationships match the compiled producer;
- QIDI circle-metadata source-copy quirk: upstream ring geometry changes under auto circle compensation, while copied process metadata reaches all four Arachne lines unmarked and final represented `CustomizeFlag` stays none;
- final Arachne fill boundary: no-wall, one-wall mixed-spacing and two-wall exact helper arguments plus `fill_surfaces` / `fill_no_overlap` spans match compiled process state;
- pathological narrow wedge: all three compiled variable-width lines and junction payloads match within source `SCALED_EPSILON`, verifying the convex Clipper1 pre-wall offset seam;
- orthogonal concave narrow-L expansion and topology-changing erosion: exact pinned compiled results are now produced by the represented rectilinear `Execute()` cleanup rather than the compatibility fallback.

These exact fixture scopes are **scoped `parity_verified` evidence**. The represented `process_arachne()` boundary is still kept at **`implemented_unverified` as a whole** until broader pathological and production geometry differential coverage is accumulated; non-orthogonal/multi-result concave cleanup and interacting/deep-nesting cross-path boolean union remain concrete dependency seams.

## Fuzzy / Arachne scope retained

The 729-test suite re-runs all previously verified fuzzy/Arachne evidence, including seeded C++ fuzzy goldens, source ZAttributes / LineSegmentation behavior, direct Boost/Voronoi fixtures, both represented Arachne overhang branches, QIDI LoopNode compiled payload/range evidence, the source Surface-copy circle quirk, final fill-boundary compiled evidence, the narrow-wedge Clipper1 differential, the orthogonal concave compiled fixtures, the pinned through-hole oracle after the noninteracting NonZero union change, and the composed final per-surface process boundary.

## First unfinished priority

Continue independent validation in source/dependency order:

1. port/validate the remaining pinned Clipper1 per-path `Execute(ctUnion, ...)` cases for **non-orthogonal concave closed paths** and **multi-result rectilinear cleanup**, including positive `pftPositive` and negative-offset outer-rectangle / `pftNegative` semantics; do not promote fallback behavior as 1:1 without exact oracle evidence;
2. port/validate the remaining final cross-path `clipper_union(raw_offset(...))` cases where boundaries interact/touch, same-sign nesting suppresses boundaries, or winding nesting is deeper than the now-represented direct-hole subset;
3. expand `process_arachne()` differential coverage to further pathological/production geometries: disconnected islands, small/narrow holes, non-orthogonal concave notches, variable-width/open-line cases, and combinations with one-wall/overhang/fuzzy policies;
4. resolve every differential mismatch without weakening literal source quirks; only after broader coverage is green consider promoting the represented `process_arachne()` boundary as a whole to scoped `parity_verified`;
5. separately continue upstream preprocessing dependencies not proven merely by this boundary evidence, including the full QIDI auto circle-compensation geometry producer where still unrepresented;
6. continue later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft toolpaths in dependency order;
7. continue full native G-code, project/profile, scene/Preview, Device/cloud, calibration, desktop and UI parity;
8. publish and SHA-verify real runtime assets before any release-complete claim.

## Numeric/source invariants

- slicer coordinates use `SCALING_FACTOR = 0.00001` mm (100000 source units/mm);
- pinned `EPSILON = 1e-4` and `SCALED_EPSILON = 10` source units;
- preserve source integer geometry until the source converts units;
- preserve explicit/implicit `float` boundaries before geometry/config arithmetic;
- preserve source `scaled<T>` truncation, `lrint`, round and cast boundaries rather than normalizing them;
- keep Boost.Polygon 1.83 operand/bit semantics, including existing `BigInt` boundaries;
- keep QIDI/Clipper compatibility quirks frozen by regression tests;
- never replace a source oddity with a cleaner algorithm without an independent source oracle.

## Other major open areas

All top-level gates remain **OPEN**. Major remaining work includes the still-unrepresented general Clipper1 non-orthogonal/multi-result/interacting boolean cases for current Arachne consumers, broader Arachne production/pathological differential coverage, later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft toolpaths, full G-code state/templates/travel/retract/cooling/multimaterial behavior, project/profile round trips and STEP/source-enabled import formats, scene/editor and Preview parity, Device/cloud/P2P/account/camera/HMS/firmware, calibration, desktop integration, full UI/localization/accessibility, runtime asset publication/verification, and exhaustive reference/differential tests.

## Working discipline

For each source batch: identify exact source functions and dependencies; port literal behavior; add source-oracle/translated/differential tests; confirm `.github/workflows/flutter-parity.yml` on pinned Flutter 3.47.2; do not weaken analyzer/tests; then update migration ledgers and this handoff. A scoped passing test never closes a top-level product gate.
