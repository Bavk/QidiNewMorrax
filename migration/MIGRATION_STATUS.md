# Migration status — STRICT 1:1 Flutter/Dart rewrite

Acceptance authority: [`PARITY_CONTRACT.md`](PARITY_CONTRACT.md). The target is Qidi Flow 2.07.02.60 Pass28 reimplemented completely in Flutter + Dart with no legacy runtime backend.

## Status vocabulary

- `pending` — no real Dart replacement yet.
- `port_started` — only part of source behavior exists.
- `implemented_unverified` — intended replacement exists, required reference validation is not green yet.
- `parity_verified` — explicitly scoped behavior has passing translated/differential/oracle evidence.
- `runtime_asset_verified` — preserved data is byte-for-byte verified or uses a documented canonical transform.

A scoped `parity_verified` row never implies its top-level subsystem is complete.

## Current executable checkpoint — 2026-09-13

- Flutter **3.47.2**, Dart **3.13.2**;
- validated code `7b4f2ba667db4ff509e2da62addf8d5af49e4abc`;
- workflow `34743283594` (#416), conclusion **success**;
- `flutter analyze` — **No issues found!**;
- `flutter test --reporter expanded` — **690/690 passing**.

Milestones in the current source path:

- #276 / `2a33afd...`: ordered classic islands → traversal/fuzzy/overhang/wall sequence + QIDI loop-node metadata, 387/387;
- #278 / `6978000...`: first Arachne `WallToolPaths` numeric/simplifier dependency slice, 395/395;
- #317 / `10f642e...`: post-construction `SkeletalTrapezoidation::generateToolpaths()` runtime composed, 551/551;
- #330 / `5c77305...`: polygon → Boost Voronoi → skeletal graph → variable-width Arachne toolpaths composed, 584/584;
- #340 / `f23293e...`: represented `WallToolPaths::generate()` source-order runtime composed, 604/604;
- #346 / `41c8ffe...` + `0d52a42...`: first `process_arachne()` orchestration slice, 618/618;
- #353 / `3fcb49d...` + `90eec08...`: non-separated per-surface Arachne wall generation, 638/638;
- #371 / `8664d98...` + `7c801dc...` + `b069eb1...`: non-overhang Arachne traversal, 669/669;
- #377 / `2a99046...` + `628fdf3...` + `aa104bd...` + `87c20a7...`: non-speed width-preserving active-overhang traversal, 672/672;
- #383 / `4854a5c...` + `945ced6...` + `8beb613...` + `86db415...`: speed-graded Arachne overhang traversal, 675/675;
- #386 / `5f4d8d3...` + `5cceb9e...` + `0d2131d...`: Arachne QIDI raw external `LoopNode` producer and range semantics, 677/677;
- #390 / `324ee86...` + `b3ea9db...` + `aecf3ca...` + `7eb43f3...`: final represented per-surface Arachne process composition into loops and fill boundaries, 681/681;
- #394 / `4bfb5b5...`: exact pinned compiled BambuStudio CLI verifies normal two-wall plus topmost/first-layer one-wall output, 684/684;
- #398 / `425b64d...`: exact pinned CLI verifies non-speed overhang geometry and support split, 685/685;
- #400 / `e382302...`: exact pinned CLI verifies partial `Alltop` split/recombine geometry, 686/686;
- #402 / `4a33e8d...`: exact pinned CLI verifies square through-hole contour/hole Arachne walls, 687/687;
- #412 / `70ba8a1...`: exact pinned compiled `detect_overhang_degree()` return paths verify both speed-graded stepped-solid Arachne walls, 688/688;
- #416 / `7b4f2ba...`: exact pinned compiled `traverse_extrusions()` state verifies Arachne QIDI `LoopNode` payload/range semantics, 690/690.

## Top-level gates

All remain **OPEN**: formats/project persistence; scene/editor; slicer/toolpath; Preview; profiles/presets; Device/cloud; calibration; desktop/release integration; UI/localization/accessibility; complete reference/differential coverage.

## Verified foundations retained

The current green suite retains scoped `parity_verified` coverage for represented source integer geometry, Polyline/ArcFitter/Circle, ThickPolyline, Boost.Polygon 1.83 robust predicates/Fortune/Voronoi fixtures, MedialAxis, translated Clipper/ClipperUtils behavior used by current consumers, Flow, Extruder/QIDI config subset, Surface, ExtrusionEntity/variable-width/covered-width subset, source-style G-code formatter/path emitter subset, classic perimeter preprocessing/shell/traversal/metadata pipeline, fuzzy/Arachne subsets, Arachne beading strategies, real-polygon Voronoi-to-skeletal construction fixtures, the represented skeletal runtime, `WallToolPaths::generate()`, Alltop wall generation, Arachne extrusion ordering, both represented Arachne overhang branches and QIDI LoopNode generation.

The broader containing product modules remain incomplete.

## Classic `process_classic()` represented path — scoped `parity_verified`

Pinned source: `bambulab/BambuStudio@f2b55a5a83f266cf56e06c7943a81a08bebb7fad`.

`SourceClassicPerimeterIslandProcess2` plus `SourceClassicPerimeterOrderedPipeline2` cover the represented source path through source `Surface` vector-copy behavior; `BridgeDetector` and `process_no_bridge()`; conditional simplification / `chain_expolygons`; extra-perimeter accounting; one-wall gates; onion shell / Alltop / thin-wall / gap-fill / final fill boundaries; recursive fuzzy/overhang traversal; shared fuzzy RNG; per-island wall sequence; nested collection shape; and global gap-fill accumulation.

Important source quirk: the supplied `Surface` copy constructor omits QIDI `counter_circle_compensation` and `holes_circle_compensation`, so the high-level source copy resets these members before the later classic lookup. The Dart path preserves that quirk.

### QIDI outwall / loop-node metadata

Classic and Arachne producer paths are represented separately. The Arachne producer captures raw external Arachne junction points/widths before fuzzy/overhang conversion, uses the current output-entity count as `loop_id`, global source node IDs/ranges, and preserves the direct `outer_wall_line_width / 2` bbox narrowing behavior without inventing a scale conversion. Its normal two-wall and topmost one-wall payload/range semantics now have independent compiled-binary evidence. Downstream inter-layer relationship/speed-control consumers remain open.

## Arachne wall-generation dependency chain — scoped status

The represented Arachne chain includes:

- source float-backed `WallToolPathsParams`, prepared-outline repair/cleanup, exact scalar casts and beading strategies;
- source-shaped skeletal graph, source-index transfer and direct Boost/Voronoi topology through `constructFromPolygons()`;
- central classification/filtering, bead-count propagation, transitions, nonlinear ribs, `generateSegments()`, `generateToolpaths()` and top-level `WallToolPaths::generate()`;
- one-wall planning plus `should_enable_top_one_wall()`, upper/lower clipping and full `Alltop` first-wall/top/remainder/second-wall recombination;
- `getRegionOrder()`, blocked nearest-candidate ordering, open-before-closed behavior and `InnerOuterInner` adjustment;
- non-overhang traversal through fuzzy transform, source variable-width conversion, loop/open packaging, winding restoration and circle compensation;
- non-speed overhang through bbox-pruned support, source Clipper-Z width interpolation/repair, supported/unsupported split, bridge-wall role/flow and supported-start re-chaining;
- speed-graded overhang through source 2mm sampling, signed-distance calculation, width-aware non-uniform degree mapping, 0.25 split terraces, variable-width path emission and `smooth_overhang_level()` integer-degree behavior;
- Arachne QIDI external `LoopNode` creation and global `loop_node_range` accounting;
- standalone `add_infill_contour_for_arachne()` plus final represented per-surface composition into global loops, `fill_surfaces` and `fill_no_overlap`.

These lower slices retain scoped parity evidence for their represented fixtures. They do **not** by themselves prove the complete per-surface output matches pinned C++ for production geometry.

## Exact compiled-source oracle evidence for `process_arachne()`

Independent differential fixtures are derived from the exact pinned upstream compiled binary:

- upstream SHA `f2b55a5a83f266cf56e06c7943a81a08bebb7fad`;
- successful upstream Actions run `34298498452`;
- Ubuntu artifact `10085378329` / `BambuStudio_ubuntu-24.04_V02.08.03.66`;
- artifact SHA-256 `912517d86774f4705c28a9e649f3fc91f96fe1623bdf070cb5f14f02ba3827f8`;
- AppImage SHA-256 `ad90fda9a4537222a679b5d2ad12712a86652858106dce00f69fac24c3af8b46`.

The following exact fixture scopes are independently **scoped `parity_verified`**:

- normal interior two-wall square: wall spans/widths and Inner→Outer role order;
- topmost one-wall square;
- first-layer one-wall square;
- non-speed active-overhang stepped wall: supported/unsupported role bands, wall spans and support boundary at model `x=20.2mm`;
- partial `Alltop`: full first external wall plus clipped remainder inner wall and its placement;
- square through-hole: four closed Arachne walls, outer-contour spans `18.886/19.600mm` and hole spans `11.114/10.400mm`;
- speed-graded active-overhang `detect_overhang_degree()` output before downstream speed policy: both inner and external supported walls match the compiled 39-path role/quarter-degree sequence exactly, with integer XY within the pinned source `SCALED_EPSILON=10` after one global reflection normalization for the symmetric closed loop;
- Arachne QIDI `LoopNode` producer state: normal two-wall `loop_node_range=[0,1)`, `node_id=0`, `loop_id=1`; topmost one-wall same range/node ID with `loop_id=0`; raw six-junction order, six widths `35707`, `is_loop=true`, empty upper/lower relations and bbox span match the compiled process state. The XY comparison removes only plate translation and uses `SCALED_EPSILON=10`.

For G-code-derived fixtures only downstream/global arrange translation and closed-loop seam rebasing are normalized where necessary. The speed-graded and LoopNode fixtures instead read compiled process state before downstream G-code generation; their semantic fields remain exact.

## `PerimeterGenerator::process_arachne()` represented surface boundary — `implemented_unverified`

The functional boundary is composed in source order for the represented per-surface scope and now has substantial independent compiled-source evidence. It nevertheless remains **`implemented_unverified` as a whole**, because these process-level gates still lack independent reference coverage:

- QIDI counter/hole circle-compensation metadata/geometry; the through-hole fixture verifies ordinary hole walls only;
- final `fill_surfaces` / `fill_no_overlap` outputs, including no-wall and mixed-spacing cases not directly observable from normal G-code;
- broader pathological and production geometry coverage.

The broader slicer/toolpath subsystem remains `port_started`.

## Fuzzy skin / Arachne retained

The 690-test suite re-executes the scoped fuzzy/Arachne evidence: exact fuzzy policy and slowdown gates; shared Classic RNG and MT19937/libstdc++ oracles; pinned libnoise modes; Polygon/Polyline/Arachne LineSegmentation and ZAttributes behavior; seeded C++ fuzzy modes; direct Boost/Voronoi and skeletal fixtures; both represented Arachne overhang paths; QIDI LoopNode generation plus compiled payload/range oracle; the composed final per-surface process boundary; compiled CLI process fixtures; and the compiled-return speed-grade oracle.

## Immediate next dependency order

1. Obtain independent QIDI circle-compensation metadata/geometry evidence.
2. Obtain independent final fill-boundary/no-wall and mixed-spacing evidence.
3. Expand `process_arachne()` differential coverage to additional production/pathological geometry; only then consider promoting the whole represented boundary to scoped `parity_verified`.
4. Continue later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft toolpaths in dependency order.
5. Continue full native G-code, project/profile, scene/Preview, Device/cloud, calibration, desktop and UI parity.
6. Publish and SHA-verify real runtime assets before any release-complete claim.

## Other major open areas

- remaining Arachne process oracle gates and production-geometry differential coverage;
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
