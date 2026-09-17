# Migration status — STRICT 1:1 Flutter/Dart rewrite

Acceptance authority: [`PARITY_CONTRACT.md`](PARITY_CONTRACT.md). The target is Qidi Flow 2.07.02.60 Pass28 reimplemented completely in Flutter + Dart with no legacy runtime backend.

## Status vocabulary

- `pending` — no real Dart replacement yet.
- `port_started` — only part of source behavior exists.
- `implemented_unverified` — intended replacement exists, required reference validation is not green yet.
- `parity_verified` — explicitly scoped behavior has passing translated/differential/oracle evidence.
- `runtime_asset_verified` — preserved data is byte-for-byte verified or uses a documented canonical transform.

A scoped `parity_verified` row never implies its top-level subsystem is complete.

## Current executable checkpoint — 2026-09-17

- Flutter **3.47.2**, Dart **3.13.2**;
- validated code `00a49000cedaa85f21bd9fbfcf007e2512860bb6` (clean production checkpoint for the translated AEL-outside rounded-family extension);
- workflow `35218255121` (#628), job `105191803438`, conclusion **success**;
- `flutter analyze` — **No issues found!**;
- `flutter test --reporter expanded` — **870/870 passing**.

The current suite retains every earlier represented Classic/Arachne/geometry fixture, including the #615 AEL-contained rounded-to-touch collapse, and adds two source-traced AEL-outside rounded strict-max families under integer translation only: retained-inner-vertex and retained-wedge. Their exact raw paths and Arachne zero-offset routing are locked; scaling is explicitly excluded by source counterevidence. Broader AEL-outside rounded/degenerated states, side, horizontal and mixed-collinear neighbors remain fallback.

### #628 translated AEL-outside rounded strict-max families

The represented rounded strict-max subset now also includes two independently traced **AEL-outside** raw output-list families: retained-inner-vertex and retained-wedge, under arbitrary integer translation only. Fixed source fixtures matched 36/36 complete raw paths across rotations/input order (`35217212927` / `105188120437`); a broad translation oracle matched **36000/36000 exact complete raw paths** (`35217607425` / `105189698086`). A negative source probe (`35217503833` / `105189359905`) changes the raw result at ×2 scaling, so scaled/neighboring AEL-outside states remain fallback rather than being geometry-normalized. PR parity run `35218255121` (#628), job `105191803438`, is green with clean analyze and **870/870** tests.

## Top-level gates

All remain **OPEN**: formats/project persistence; scene/editor; slicer/toolpath; Preview; profiles/presets; Device/cloud; calibration; desktop/release integration; UI/localization/accessibility; complete reference/differential coverage.

## Current perimeter / Arachne state

The represented classic `PerimeterGenerator::process_classic()` surface path remains scoped `parity_verified` for its covered fixtures. The represented `PerimeterGenerator::process_arachne()` surface boundary remains **`implemented_unverified` as a whole** despite substantial scoped exact evidence.

The represented Arachne dependency chain includes source `Surface` copy behavior, `WallToolPaths` preparation/config/beading, direct Boost/Voronoi skeletal construction, toolpath generation, one-wall/`Alltop` planning, extrusion ordering, fuzzy conversion, binary and speed-graded overhang traversal, QIDI `LoopNode` production, and final fill-boundary composition.

Independent exact compiled BambuStudio process evidence covers normal two-wall, topmost/first-layer one-wall, non-speed and speed-graded overhang, partial `Alltop`, through-hole walls, QIDI `LoopNode`, QIDI circle-metadata copy behavior, final Arachne fill boundaries and the pathological narrow wedge.

## Clipper1 status inside Arachne preparation

Pinned Qidi/Bambu source uses modified Clipper 6.2.9. The represented exact subsets now cover:

- float32 caller delta, shortest-edge threshold and literal `AddPath()` pruning;
- double unit normals, half-away-from-zero `Round()`, near-collinear/concave/miter/square raw `OffsetPoint()` arithmetic;
- exact convex positive contour expansion/erosion, exhausted erosion collapse and convex CW-hole sign/orientation semantics;
- exact orthogonal concave cleanup, including topology-changing single-result and multi-result positive contours;
- isolated positive non-orthogonal V-notch cleanup and matching one-reflex negative `pftNegative` cleanup;
- conservative noninteracting NonZero cross-path behavior for direct holes, disconnected positive roots and nested same-sign suppression, including pinned `BuildResult()` starts/order;
- exact interacting two-positive axis-aligned rectangles for same-span touch, diagonal area overlap, partial unequal edge/T contacts and point-only contacts;
- exactly two positive strictly convex contours with only proper boundary crossings, preserving the pinned modified-Clipper scanline intersection arithmetic and exact `BuildResult()` vertex order/start;
- exactly two positive strict-convex **triangles** for raw-proven point/full/strict-contained contact states, including equal-bottom point ordering and decreasing-Y strict-contained shared-edge contacts;
- exactly two positive strict-convex triangles with represented partial collinear contact, including host-start/horizontal, guarded/remaining host-end and all non-horizontal staggered non-fixup states;
- strict-triangle one-point `FixupOutPolygon()` cleanup for endpoint-aligned host-start/host-end joins and complete-shared-edge joins, including the input-order-sensitive removed-start state;
- exactly two positive strict-convex triangles with proper crossings plus exactly one vertex↔strict-edge-interior point touch for the independently proved #569 strict minimum-Y class and non-horizontal strict-maximum ordering classes: #575 `<`, #588 `==`, #582 late `>` single-crossing, #601 late `>` multi-crossing and #608 late `>` single-cross separated-minimum boundary; #615 additionally covers the traced rounded-to-touch single-crossing state only when exact AEL ordering keeps both active other bounds between the owner bounds (`WindCnt == 1`).

The exact pinned artifact remains Actions artifact `10085378329`, with downloaded SHA-256 `912517d86774f4705c28a9e649f3fc91f96fe1623bdf070cb5f14f02ba3827f8` and AppImage SHA-256 `ad90fda9a4537222a679b5d2ad12712a86652858106dce00f69fac24c3af8b46`.

Retained direct raw-ELF evidence includes standalone triangle starts **1100/1100**, complete shared-edge triangle starts **1000/1000**, older contact predicates **4600/4600**, #510 partial-collinear **4392/4392**, #518 guarded non-horizontal **36000/36000**, #525 decreasing-Y host-end **23400/23400**, and #532 all-slope non-horizontal staggered **145800/145800**.

Newer contact/fixup/mixed evidence:

- #539 equal-bottom point contacts: **41400/41400 exact raw paths**;
- #542 decreasing-Y strict-contained contacts: **30600/30600 exact full raw paths**;
- #549 host-end endpoint-aligned one-point fixup: **145800/145800 exact full raw paths**;
- #552 host-start endpoint-aligned one-point fixup: **145800/145800 exact full raw paths**;
- combined endpoint-aligned one-point fixup evidence: **291600/291600 exact full raw paths**;
- #562 full-shared-edge one-point fixup: **226908/226908 exact raw paths**;
- #569 mixed proper-crossing + strict-minimum-Y vertex↔edge point-touch: **39600/39600 exact full raw paths**;
- #575 ordered strict-maximum mixed point-touch: **72000/72000 exact full raw paths** from 4,000 independent base geometries × all 3×3 rotations × both input orders, spanning 1–4 proper crossings and vertical/positive/negative-slope touched edges;
- #582 late strict-maximum single-crossing mixed point-touch: **64800/64800 exact full raw paths** from 3,600 independent base geometries — 1,200 vertical, 1,200 positive-slope and 1,200 negative-slope touched edges — × all 3×3 rotations × both input orders;
- #588 strict-maximum equal-Y mixed point-touch boundary: direct compilation of pinned BambuStudio Clipper1 source in Actions run `35068502159`, job `104704216962`, generated **3,000** independent bases (528 one-crossing and 2,472 multi-crossing), then all 3×3 rotations × both input/AddPath orders; **54000/54000** raw results matched the source `BuildResult()` start rule, while the committed fixed fixture locks the complete raw path for all 18 rotation/order variants;
- #601 late strict-maximum multi-crossing extension: broad and independently targeted pinned-source matrices matched **216000/216000 exact raw starts** across proper-count 2–4; a separate separated-minimum boundary matrix matched **64800/64800 exact full raw paths** across vertical/positive/negative touched edges and all 18 rotation/input-order variants. Combined new source evidence is **280800/280800 raw-start checks**, including **64800/64800 full-path matches** on the rebase boundary;
- #608 late strict-maximum **single-crossing separated-minimum** boundary: direct pinned-source run `35090443828`, job `104775225066`; fixed historical fixture **18/18 exact full raw paths**, plus **3,600** independent bases split 1,200/1,200/1,200 across vertical/positive/negative touched edges × all 18 variants = **64800/64800 exact raw starts and 64800/64800 exact full raw paths**.
- #615 rounded-to-touch **AEL-contained strict-maximum single-crossing collapse**: direct source event trace `35122390233`, job `104883098941`, distinguishes the accepted `WindCnt == 1` owner-bound state from AEL-outside `WindCnt == 2` retained-vertex/wedge counterstates. Primary run `35122592466`, job `104883775222`, matched **90000/90000 exact full raw paths** from 5,000 bases; green asymmetric translated run `35123441575`, job `104886606102`, matched **18000/18000** from 1,000 bases; supplementary quota-limited no-mismatch matrices add **22302/22302** and **34830/34830**. Aggregate: **9,174 bases / 165132/165132 exact complete raw paths**, all 18 rotation/input-order variants.

The #575/#588/#582/#601/#608 strict-max predicates partition the represented non-horizontal ordinary-intersection ordering seam. #575 owns `otherThird.y < min(ownerPrevious.y, ownerNext.y)` with 1–4 proper crossings. #588 owns equality with at least one proper crossing. #582 plus #601 plus #608 own `otherThird.y > min(...)` across the proved single- and multi-crossing states, with source matrices spanning proper-count 1–4. The equal-Y and late separated-minimum audits establish narrow states where a valid raw contour may contain two **nonadjacent** global minimum-Y vertices; #601 independently proves that endpoint-Y boundary for multi-crossing and #608 independently proves it for single-crossing. #615 is orthogonal to that rebase partition: it covers exactly one proper crossing whose rounded intersection equals the strict-max touch, only when exact `E2InsertsBeforeE1()` ordering places both active other edges between owner bounds and the traced owner `WindCnt` is 1. AEL-outside rounded collapses, horizontal strict-max touches, side-vertex touches and mixed collinear cases remain explicit fallback.

The runtime output-list evidence continues to matter: touch-time `AddLocalMaxPoly()`/`AppendPolygon()` can alter `OutRec::Pts`, but append alone is not a static failure predicate. The represented classes are bounded by independently validated source scanline/output-list states rather than a geometry-normalized rebase.

For strict triangles with one collinear shared interval, the represented one-point cleanup geometry covers endpoint-aligned and full-shared-edge cases. Strict-contained and staggered overlaps retain support-line boundary segments and do not create the same adjacent-third-vertex one-point cleanup. This statement does **not** promote wider-convex, multi-point or mixed-crossing fixup topologies.

Still **not** general Clipper1 parity: remaining mixed proper-crossing + touch/collinear output-list states, wider-convex contact/fixup output-list state, multi-point/unrepresented cleanup, interacting holes, more than two interacting paths, deeper/multiple surviving hole hierarchy, multi-reflex/non-local non-orthogonal cleanup, orthogonal hole/point-touch ambiguity and remaining prepared-outline final-union cases. Those remain explicit compatibility seams and must not be promoted from Clipper2 fallback without independent source evidence.

## Traceability summary

| Source scope | Dart replacement | Evidence | Status | Remaining |
|---|---|---|---|---|
| represented integer geometry / Polyline / ArcFitter / Circle / ThickPolyline / Boost-Voronoi / MedialAxis | `lib/core/geometry` source-shaped ports | translated and direct C++/Boost fixtures in current suite | `parity_verified` (scoped) | broader source APIs/pathologies |
| Classic perimeter represented surface path | classic source pipeline modules | translated/source-shaped process fixtures | `parity_verified` (scoped) | later toolpath families and wider production matrix |
| Arachne wall-generation dependency chain | `lib/core/slicer/source_arachne_*` | direct/source-shaped plus compiled process fixtures | `parity_verified` (scoped dependencies) | broader production/pathological matrix |
| modified Clipper1 represented offset/Execute/NonZero subsets | `source_clipper1_*` | direct pinned ELF/source oracles + #615 CI | `parity_verified` (exact fixture scopes) | remaining mixed states, wider/multi-point fixup, interacting holes, >2 paths and broader Execute cleanup |
| represented `process_arachne()` boundary | `SourceArachneProcessPipeline2` + dependencies | common/hole/Alltop/overhang/fill/LoopNode/wedge exact fixtures | `implemented_unverified` | general Clipper1 seams + wider process differentials |
| full slicer/toolpath product | multiple foundations | partial | `port_started` | fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft/full G-code etc. |
| formats/profiles/scene/Preview/Device/UI | Flutter/Dart foundations | partial | `port_started` | complete 1:1 behavior and integrations |
| complete runtime assets | earlier local audit only | not remotely release-verified | `pending` gate | publish and SHA-verify real runtime assets |

## Immediate next dependency order

1. Continue **mixed proper-crossing + point-touch/collinear two-positive paths** beyond the #569/#575/#582/#588/#601/#608/#615 proved classes: first remaining AEL-outside / other rounded-degenerated strict-max families (including retained-vertex/wedge counterstates), then side-vertex touches, horizontal touch ordering and mixed collinear cases. Start from traced AEL / `AppendPolygon()` / `OutRec::Pts` state rather than assuming a geometric rebase rule.
2. Keep wider-convex and any multi-point/non-triangle `FixupOutPolygon()` states on explicit fallback until raw `OutRec`/`BuildResult()` state is independently proved.
3. Continue the same Clipper1 final cross-path priority with **interacting holes**, then **more than two interacting paths**.
4. Extend per-path Clipper1 `Execute()` beyond current orthogonal/V-notch subsets: multiple reflex vertices, non-local self-intersections, split/hole-producing non-orthogonal results and more general negative `pftNegative` cleanup.
5. Validate remaining prepared-outline final `unionNonZero()` cases so a later Clipper2 call cannot silently reintroduce source-order/rounding drift after exact pre-offset work.
6. Expand whole `process_arachne()` differentials to disconnected islands, small/narrow holes, non-orthogonal concave notches, variable-width/open-line cases and one-wall/overhang/fuzzy combinations.
7. Only after broader green evidence consider promoting represented `process_arachne()` as a whole to scoped `parity_verified`.
8. Continue the separate QIDI auto circle-compensation geometry producer and later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft toolpaths, then full G-code, persistence/profiles, scene/Preview, Device/cloud, calibration, desktop and UI parity.
9. Publish and SHA-verify real runtime assets before any release-complete claim.

## Completion truth

**Zero top-level parity gates are closed.** The complete product remains far from done; current exact Clipper1/Arachne work is a scoped dependency slice only. Do not infer completion from compilation, visual similarity or common-case tests.