# Migration status — STRICT 1:1 Flutter/Dart rewrite

Acceptance authority: [`PARITY_CONTRACT.md`](PARITY_CONTRACT.md). The target is Qidi Flow 2.07.02.60 Pass28 reimplemented completely in Flutter + Dart with no legacy runtime backend.

## Status vocabulary

- `pending` — no real Dart replacement yet.
- `port_started` — only part of source behavior exists.
- `implemented_unverified` — intended replacement exists, required reference validation is not green yet.
- `parity_verified` — explicitly scoped behavior has passing translated/differential/oracle evidence.
- `runtime_asset_verified` — preserved data is byte-for-byte verified or uses a documented canonical transform.

A scoped `parity_verified` row never implies its top-level subsystem is complete.

## Current executable checkpoint — 2026-09-15

- Flutter **3.47.2**, Dart **3.13.2**;
- validated code `d238cc809cc40f55a29db20c0010188007832414` (`feat: route mixed point-touch Clipper1 subset`);
- workflow `34911206898` (#569), job `104198867460`, conclusion **success**;
- `flutter analyze` — **No issues found!**;
- `flutter test --reporter expanded` — **848/848 passing**.

The current suite retains every earlier represented Classic/Arachne/geometry fixture and adds eight mixed proper-crossing + point-touch regressions beyond #562, including exact Arachne zero-offset routing and ownership/rejection boundaries.

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
- exactly two positive strict-convex triangles with proper crossings plus exactly one vertex↔strict-edge-interior point touch when the touching source vertex is the strict minimum-Y vertex of its owning triangle.

The exact pinned artifact remains Actions artifact `10085378329`, with downloaded SHA-256 `912517d86774f4705c28a9e649f3fc91f96fe1623bdf070cb5f14f02ba3827f8` and AppImage SHA-256 `ad90fda9a4537222a679b5d2ad12712a86652858106dce00f69fac24c3af8b46`.

Retained direct raw-ELF evidence includes standalone triangle starts **1100/1100**, complete shared-edge triangle starts **1000/1000**, older contact predicates **4600/4600**, #510 partial-collinear **4392/4392**, #518 guarded non-horizontal **36000/36000**, #525 decreasing-Y host-end **23400/23400**, and #532 all-slope non-horizontal staggered **145800/145800**.

Newer contact/fixup/mixed evidence:

- #539 equal-bottom point contacts: **41400/41400 exact raw paths**;
- #542 decreasing-Y strict-contained contacts: **30600/30600 exact full raw paths**;
- #549 host-end endpoint-aligned one-point fixup: **145800/145800 exact full raw paths**;
- #552 host-start endpoint-aligned one-point fixup: **145800/145800 exact full raw paths**;
- combined endpoint-aligned one-point fixup evidence: **291600/291600 exact full raw paths**;
- #562 full-shared-edge one-point fixup: **226908/226908 exact raw paths**;
- #569 mixed proper-crossing + strict-minimum-Y vertex↔edge point-touch: **39600/39600 exact full raw paths** from 2,200 independent base geometries × all 3×3 cyclic rotations × both input orders.

The broad mixed seam is intentionally still open. Before defining the #569 narrow source-event class, one exploratory matrix matched the proper-only raw-start rebase in only **35874/37008** cases, leaving **1134** mismatches. A second independently generated matrix matched only **27450/28800**, leaving **1350** raw-start mismatches. Runtime tracing tied the dangerous states to the touch event's output-list lifecycle and touch-time `AppendPolygon()`: no-touch-append bases were exact in both traced samples, while touch-time-append bases could change the final raw start. This is limiting evidence, not a general routing predicate.

For strict triangles with one collinear shared interval, the represented one-point cleanup geometry covers endpoint-aligned and full-shared-edge cases. Strict-contained and staggered overlaps retain support-line boundary segments and do not create the same adjacent-third-vertex one-point cleanup. This statement does **not** promote wider-convex, multi-point or mixed-crossing fixup topologies.

Still **not** general Clipper1 parity: remaining mixed proper-crossing + touch/collinear output-list states, wider-convex contact/fixup output-list state, multi-point/unrepresented cleanup, interacting holes, more than two interacting paths, deeper/multiple surviving hole hierarchy, multi-reflex/non-local non-orthogonal cleanup, orthogonal hole/point-touch ambiguity and remaining prepared-outline final-union cases. Those remain explicit compatibility seams and must not be promoted from Clipper2 fallback without independent source evidence.

## Traceability summary

| Source scope | Dart replacement | Evidence | Status | Remaining |
|---|---|---|---|---|
| represented integer geometry / Polyline / ArcFitter / Circle / ThickPolyline / Boost-Voronoi / MedialAxis | `lib/core/geometry` source-shaped ports | translated and direct C++/Boost fixtures in current suite | `parity_verified` (scoped) | broader source APIs/pathologies |
| Classic perimeter represented surface path | classic source pipeline modules | translated/source-shaped process fixtures | `parity_verified` (scoped) | later toolpath families and wider production matrix |
| Arachne wall-generation dependency chain | `lib/core/slicer/source_arachne_*` | direct/source-shaped plus compiled process fixtures | `parity_verified` (scoped dependencies) | broader production/pathological matrix |
| modified Clipper1 represented offset/Execute/NonZero subsets | `source_clipper1_*` | direct pinned ELF oracles + #569 CI | `parity_verified` (exact fixture scopes) | remaining mixed states, wider/multi-point fixup, interacting holes, >2 paths and broader Execute cleanup |
| represented `process_arachne()` boundary | `SourceArachneProcessPipeline2` + dependencies | common/hole/Alltop/overhang/fill/LoopNode/wedge exact fixtures | `implemented_unverified` | general Clipper1 seams + wider process differentials |
| full slicer/toolpath product | multiple foundations | partial | `port_started` | fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft/full G-code etc. |
| formats/profiles/scene/Preview/Device/UI | Flutter/Dart foundations | partial | `port_started` | complete 1:1 behavior and integrations |
| complete runtime assets | earlier local audit only | not remotely release-verified | `pending` gate | publish and SHA-verify real runtime assets |

## Immediate next dependency order

1. Continue **mixed proper-crossing + point-touch/collinear two-positive paths** beyond the #569 strict-minimum-Y touching-vertex subset. Start from the traced touch-time `AppendPolygon()` / `OutRec::Pts` states and retained raw-start counterexamples rather than assuming the proper-only rebase rule.
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
