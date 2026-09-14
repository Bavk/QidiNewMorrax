# Migration status — STRICT 1:1 Flutter/Dart rewrite

Acceptance authority: [`PARITY_CONTRACT.md`](PARITY_CONTRACT.md). The target is Qidi Flow 2.07.02.60 Pass28 reimplemented completely in Flutter + Dart with no legacy runtime backend.

## Status vocabulary

- `pending` — no real Dart replacement yet.
- `port_started` — only part of source behavior exists.
- `implemented_unverified` — intended replacement exists, required reference validation is not green yet.
- `parity_verified` — explicitly scoped behavior has passing translated/differential/oracle evidence.
- `runtime_asset_verified` — preserved data is byte-for-byte verified or uses a documented canonical transform.

A scoped `parity_verified` row never implies its top-level subsystem is complete.

## Current executable checkpoint — 2026-09-14

- Flutter **3.47.2**, Dart **3.13.2**;
- validated code `d528f8f91607d0307a6d9c584ea9b5dfc3402fa2` (`test: lock decreasing host-end Clipper1 joins`);
- workflow `34858695268` (#525), job `104024892024`, conclusion **success**;
- `flutter analyze` — **No issues found!**;
- `flutter test --reporter expanded` — **792/792 passing**.

The current suite retains every earlier represented Classic/Arachne/geometry fixture and adds six tests beyond #518 for the remaining non-fixup decreasing-Y host-end triangle scope, exact Arachne routing and explicit rejection of post-join fixup state.

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
- exactly two positive strict-convex **triangles** for the raw-ELF-proven zero-area contact states: supported single point contacts with distinct bottom scanlines, complete shared edge and represented strict-contained shared-edge directions;
- exactly two positive strict-convex triangles with one represented partial collinear contact. The #510 host-start/horizontal states and #518 guarded non-horizontal host-end/staggered states remain exact; **new #525 scope** adds the remaining non-fixup decreasing-Y host-end states through `SourceClipper1TwoConvexDecreasingHostEndUnion2`. Cycles needing post-join collinear `FixupOutPolygon()` cleanup remain rejected.

The exact pinned artifact remains Actions artifact `10085378329`, with downloaded SHA-256 `912517d86774f4705c28a9e649f3fc91f96fe1623bdf070cb5f14f02ba3827f8` and AppImage SHA-256 `ad90fda9a4537222a679b5d2ad12712a86652858106dce00f69fac24c3af8b46`.

Retained direct raw-ELF evidence includes standalone triangle starts **1100/1100**, complete shared-edge triangle starts **1000/1000**, supported contact source-list/start/order predicates **4600/4600**, the #510 represented partial-collinear matrix **4392/4392 exact raw paths**, and the #518 non-horizontal extension **36000/36000 exact raw paths**.

The #525 extension adds **23400/23400 exact raw result paths** for the remaining non-fixup decreasing-Y host-end triangle state: 14400 broad cases plus 9000 targeted equal-Y ties. The matrices vary translations, host-edge X direction including vertical edges, overlap ratio, third-vertex placement, all cyclic rotations and polygon input order. The exact raw start is the shared host end when the guest third vertex is below the interior overlap endpoint, the host edge start when it is above, and the host triangle's standalone Clipper1 start when Y is equal. Direct fixup probing showed that post-join collinear cleanup can remove the shared endpoint, so those cases remain fallback.

Still **not** general Clipper1 parity: wider-convex contact output-list state, equal-bottom point-contact ties, strict-contained decreasing-Y contact joins, positive-slope/other unrepresented non-horizontal staggered states, fixup-created collinearity, mixed crossing/contact cases, interacting holes, more than two interacting paths, deeper/multiple surviving hole hierarchy, multi-reflex/non-local non-orthogonal cleanup, orthogonal hole/point-touch ambiguity and remaining prepared-outline final-union cases. Those remain explicit compatibility seams and must not be promoted from Clipper2 fallback without independent source evidence.

## Traceability summary

| Source scope | Dart replacement | Evidence | Status | Remaining |
|---|---|---|---|---|
| represented integer geometry / Polyline / ArcFitter / Circle / ThickPolyline / Boost-Voronoi / MedialAxis | `lib/core/geometry` source-shaped ports | translated and direct C++/Boost fixtures in current suite | `parity_verified` (scoped) | broader source APIs/pathologies |
| Classic perimeter represented surface path | classic source pipeline modules | translated/source-shaped process fixtures | `parity_verified` (scoped) | later toolpath families and wider production matrix |
| Arachne wall-generation dependency chain | `lib/core/slicer/source_arachne_*` | direct/source-shaped plus compiled process fixtures | `parity_verified` (scoped dependencies) | broader production/pathological matrix |
| modified Clipper1 represented offset/Execute/NonZero subsets | `source_clipper1_*` | direct pinned ELF oracles + #525 CI | `parity_verified` (exact fixture scopes) | remaining contact/collinear states, interacting holes, >2 paths and broader Execute cleanup |
| represented `process_arachne()` boundary | `SourceArachneProcessPipeline2` + dependencies | common/hole/Alltop/overhang/fill/LoopNode/wedge exact fixtures | `implemented_unverified` | general Clipper1 seams + wider process differentials |
| full slicer/toolpath product | multiple foundations | partial | `port_started` | fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft/full G-code etc. |
| formats/profiles/scene/Preview/Device/UI | Flutter/Dart foundations | partial | `port_started` | complete 1:1 behavior and integrations |
| complete runtime assets | earlier local audit only | not remotely release-verified | `pending` gate | publish and SHA-verify real runtime assets |

## Immediate next dependency order

1. Finish the remaining two-path convex boundary-degeneracy seam with direct pinned evidence: **positive-slope/other unrepresented non-horizontal staggered collinear joins, equal-bottom/fixup contact states, then mixed proper-crossing + touch/collinear cases**. Widen beyond triangles only where raw `OutRec`/`BuildResult()` state is proved.
2. Continue the same Clipper1 final cross-path priority with **interacting holes**, then **more than two interacting paths**.
3. Extend per-path Clipper1 `Execute()` beyond current orthogonal/V-notch subsets: multiple reflex vertices, non-local self-intersections, split/hole-producing non-orthogonal results and more general negative `pftNegative` cleanup.
4. Validate remaining prepared-outline final `unionNonZero()` cases so a later Clipper2 call cannot silently reintroduce source-order/rounding drift after exact pre-offset work.
5. Expand whole `process_arachne()` differentials to disconnected islands, small/narrow holes, non-orthogonal concave notches, variable-width/open-line cases and one-wall/overhang/fuzzy combinations.
6. Only after broader green evidence consider promoting represented `process_arachne()` as a whole to scoped `parity_verified`.
7. Continue the separate QIDI auto circle-compensation geometry producer and later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft toolpaths, then full G-code, persistence/profiles, scene/Preview, Device/cloud, calibration, desktop and UI parity.
8. Publish and SHA-verify real runtime assets before any release-complete claim.

## Completion truth

**Zero top-level parity gates are closed.** The complete product remains far from done; current exact Clipper1/Arachne work is a scoped dependency slice only. Do not infer completion from compilation, visual similarity or common-case tests.
