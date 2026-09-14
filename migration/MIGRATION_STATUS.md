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
- validated code `d1731f14121c80af883e78204fdcd6bc3b41116d` (`feat: route exact partial collinear unions`);
- workflow `34848910683` (#510), job `103991577409`, conclusion **success**;
- `flutter analyze` — **No issues found!**;
- `flutter test --reporter expanded` — **781/781 passing**.

The current suite retains every earlier represented Classic/Arachne/geometry fixture and adds thirteen committed tests for the new partial-collinear triangle subset plus corrected exact contact scope/rejections.

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
- exactly two positive strict-convex **triangles** for the raw-ELF-proven zero-area contact states: supported single point contacts with distinct bottom scanlines, complete shared edge, and the represented strict-contained shared-edge directions;
- **new #510 scope:** exactly two positive strict-convex triangles with one represented partial collinear contact: host-start endpoint-aligned overlap at arbitrary slope, horizontal host-end endpoint-aligned overlap, or horizontal staggered overlap with unique minimum-Y output. Any merged result requiring additional collinear `FixupOutPolygon()` cleanup is deliberately rejected.

The exact pinned artifact remains Actions artifact `10085378329`, with downloaded SHA-256 `912517d86774f4705c28a9e649f3fc91f96fe1623bdf070cb5f14f02ba3827f8` and AppImage SHA-256 `ad90fda9a4537222a679b5d2ad12712a86652858106dce00f69fac24c3af8b46`.

The #510 audit materially corrected the prior contact scope. The earlier helper accepted arbitrary strict-convex paths, but its evidence did not establish arbitrary `OutRec::Pts` state. A random full-shared-edge quadrilateral audit produced **0/40** matches to the old raw-start heuristic, so commit `bf3610af5327a82e43469d31d4fd825128635c23` narrowed that exact route to proven triangle states. This is a parity correction, not a claim that wider-convex contacts are solved.

Current direct raw-ELF evidence includes: standalone positive-triangle starts **1100/1100**; complete shared-edge triangle starts **1000/1000**; supported contact source-list/start/order predicates **4600/4600** including reversed input order; and the represented partial-collinear triangle result matrix **4392/4392 exact raw paths** after filtering cases that require an additional Clipper fixup. The older proper-crossing strict-convex matrix remains **39/39 exact**.

Still **not** general Clipper1 parity: wider-convex contact output-list state, equal-bottom point-contact ties, strict-contained decreasing-Y joins, non-horizontal host-end and staggered collinear joins, fixup-created collinearity, mixed crossing/contact cases, interacting holes, more than two interacting paths, deeper/multiple surviving hole hierarchy, multi-reflex/non-local non-orthogonal cleanup, orthogonal hole/point-touch ambiguity and remaining prepared-outline final-union cases. Those remain explicit compatibility seams and must not be promoted from Clipper2 fallback without independent source evidence.

## Traceability summary

| Source scope | Dart replacement | Evidence | Status | Remaining |
|---|---|---|---|---|
| represented integer geometry / Polyline / ArcFitter / Circle / ThickPolyline / Boost-Voronoi / MedialAxis | `lib/core/geometry` source-shaped ports | translated and direct C++/Boost fixtures in current suite | `parity_verified` (scoped) | broader source APIs/pathologies |
| Classic perimeter represented surface path | classic source pipeline modules | translated/source-shaped process fixtures | `parity_verified` (scoped) | later toolpath families and wider production matrix |
| Arachne wall-generation dependency chain | `lib/core/slicer/source_arachne_*` | direct/source-shaped plus compiled process fixtures | `parity_verified` (scoped dependencies) | broader production/pathological matrix |
| modified Clipper1 represented offset/Execute/NonZero subsets | `source_clipper1_*` | direct pinned ELF oracles + #510 CI | `parity_verified` (exact fixture scopes) | remaining contact/collinear states, interacting holes, >2 paths and broader Execute cleanup |
| represented `process_arachne()` boundary | `SourceArachneProcessPipeline2` + dependencies | common/hole/Alltop/overhang/fill/LoopNode/wedge exact fixtures | `implemented_unverified` | general Clipper1 seams + wider process differentials |
| full slicer/toolpath product | multiple foundations | partial | `port_started` | fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft/full G-code etc. |
| formats/profiles/scene/Preview/Device/UI | Flutter/Dart foundations | partial | `port_started` | complete 1:1 behavior and integrations |
| complete runtime assets | earlier local audit only | not remotely release-verified | `pending` gate | publish and SHA-verify real runtime assets |

## Immediate next dependency order

1. Finish the remaining two-path convex boundary-degeneracy seam with direct pinned evidence: **non-horizontal host-end and non-horizontal staggered collinear joins, equal-bottom/fixup contact states, then mixed proper-crossing + touch/collinear cases**. Widen beyond triangles only where raw `OutRec`/`BuildResult()` state is proved.
2. Continue the same Clipper1 final cross-path priority with **interacting holes**, then **more than two interacting paths**.
3. Extend per-path Clipper1 `Execute()` beyond current orthogonal/V-notch subsets: multiple reflex vertices, non-local self-intersections, split/hole-producing non-orthogonal results and more general negative `pftNegative` cleanup.
4. Validate remaining prepared-outline final `unionNonZero()` cases so a later Clipper2 call cannot silently reintroduce source-order/rounding drift after exact pre-offset work.
5. Expand whole `process_arachne()` differentials to disconnected islands, small/narrow holes, non-orthogonal concave notches, variable-width/open-line cases and one-wall/overhang/fuzzy combinations.
6. Only after broader green evidence consider promoting represented `process_arachne()` as a whole to scoped `parity_verified`.
7. Continue the separate QIDI auto circle-compensation geometry producer and later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft toolpaths, then full G-code, persistence/profiles, scene/Preview, Device/cloud, calibration, desktop and UI parity.
8. Publish and SHA-verify real runtime assets before any release-complete claim.

## Completion truth

**Zero top-level parity gates are closed.** The complete product remains far from done; current exact Clipper1/Arachne work is a scoped dependency slice only. Do not infer completion from compilation, visual similarity or common-case tests.
