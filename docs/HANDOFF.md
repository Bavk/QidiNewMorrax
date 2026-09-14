# Handoff — Qidi Flow strict Flutter/Dart rewrite

This repository is a **strict 1:1 reimplementation** of Qidi Flow 2.07.02.60 Pass28 in Flutter + Dart. The legacy C++/wxWidgets/React application is reference material only and must not remain a runtime backend through FFI, subprocesses, native shared libraries, hidden services or embedded legacy WebViews.

## Read first

1. [`../migration/PARITY_CONTRACT.md`](../migration/PARITY_CONTRACT.md) — acceptance authority.
2. [`../migration/MIGRATION_STATUS.md`](../migration/MIGRATION_STATUS.md) — subsystem truth and dependency order.
3. [`../migration/TRACEABILITY.md`](../migration/TRACEABILITY.md) — source → Dart → evidence ledger.
4. [`../migration/VALIDATION.md`](../migration/VALIDATION.md) — executed evidence.
5. [`../migration/FUZZY_SKIN_SOURCE_NOTES.md`](../migration/FUZZY_SKIN_SOURCE_NOTES.md) — pinned fuzzy-skin contract.

Do not infer completion from visual similarity, compilation or common-case tests. Source quirks are part of the contract.

## Current validated checkpoint — 2026-09-14

Latest validated code checkpoint:

- code commit `d1731f14121c80af883e78204fdcd6bc3b41116d` (`feat: route exact partial collinear unions`);
- `.github/workflows/flutter-parity.yml` run `34848910683` (#510), job `103991577409`;
- Flutter `3.47.2`;
- Dart `3.13.2`;
- `flutter analyze` → **No issues found!**;
- `flutter test --reporter expanded` → **781/781 passed**;
- job conclusion → **success**.

The suite retains every earlier represented Classic/Arachne/geometry fixture and adds thirteen committed tests for partial-collinear triangle joins, exact triangle contact starts/order, routing and rejection of still-unproven Clipper1 join states.

## Independent pinned BambuStudio oracle provenance

Process and Clipper1 evidence comes from the **actual upstream compiled binary at the exact pinned source SHA**, not Dart-generated snapshots:

- upstream repository: `bambulab/BambuStudio`;
- source commit: `f2b55a5a83f266cf56e06c7943a81a08bebb7fad`;
- successful upstream GitHub Actions run: `34298498452` (`Build all`);
- Ubuntu 24.04 artifact ID: `10085378329`, `BambuStudio_ubuntu-24.04_V02.08.03.66`;
- downloaded artifact SHA-256: `912517d86774f4705c28a9e649f3fc91f96fe1623bdf070cb5f14f02ba3827f8`;
- extracted AppImage SHA-256: `ad90fda9a4537222a679b5d2ad12712a86652858106dce00f69fac24c3af8b46`;
- CLI version: `02.08.03.66`.

The raw preload probe calls the pinned modified Clipper1 `clipper_union(Paths&, pftNonZero)` template at PIE offset `0x10b54d0` and dumps result paths without rotating or reordering them. `BuildResult()` starts each path at `OutRec::Pts->Prev`, so exact parity depends on Clipper output-list state and later `FixupOutPolygon()`, not only on final geometry.

The #493 proper-crossing convex batch remains backed by **39/39 exact ELF cases**: seven hand-selected cases plus 32 deterministic random strict-convex pairs with 2/4/6 proper crossings.

For the current boundary-degeneracy batch, the exact artifact was downloaded and SHA-verified again. A batch ELF probe then established:

- standalone positive-triangle `BuildResult()` start rule: **1100/1100** raw cases;
- point-contact triangle scan/order evidence, including **999/999** vertex↔edge cases with distinct bottom scanlines and broader vertex↔vertex order probing;
- complete shared-edge triangle start rule: **1000/1000** random cases;
- safe represented point/full/strict-contained contact source-list/start/order predicates: **4600/4600** asserted cases including reversed input order;
- represented endpoint-aligned/horizontal-staggered partial-collinear triangle unions: **4392/4392 exact raw result paths** after excluding cases that require an additional Clipper `FixupOutPolygon()` mutation.

An important correction was made during that audit: the previous contact helper accepted arbitrary strict-convex polygons, while its fixtures only established triangle state. A direct wider-convex audit immediately disproved that extrapolation (for example, **0/40** random full-shared-edge quadrilateral cases matched the old raw start heuristic). Commit `bf3610af5327a82e43469d31d4fd825128635c23` therefore narrows the production exact route to the proven triangle states instead of silently claiming generic convex-contact parity.

## Current represented perimeter / Arachne path

The represented `PerimeterGenerator::process_classic()` path remains scoped `parity_verified` for covered fixtures. The represented Arachne chain includes `WallToolPaths` numeric/config state and preparation, beading strategies, direct Boost/Voronoi topology → skeletal graph → generated variable-width toolpaths, one-wall and `Alltop` planning, region/extrusion ordering, fuzzy conversion, non-speed and speed-graded overhang traversal, QIDI `LoopNode` production and final `add_infill_contour_for_arachne()` composition.

Independent compiled fixtures cover normal two-wall, topmost/first-layer one-wall, non-speed/speed overhang, partial `Alltop`, through-hole walls, QIDI `LoopNode`, QIDI circle-metadata copy behavior, final fill boundaries and the pathological narrow wedge. The represented `process_arachne()` boundary nevertheless remains **`implemented_unverified` as a whole** until broader production/pathological coverage and remaining general Clipper1 seams are closed.

## Clipper1 status inside Arachne preparation

Pinned Qidi/Bambu source uses modified Clipper 6.2.9. Exact represented subsets now cover:

- float32 caller delta, shortest-edge threshold and literal `AddPath()` pruning;
- double unit normals and half-away-from-zero `Round()`;
- near-collinear, concave-triplet, miter and square raw `OffsetPoint()` arithmetic;
- exact convex positive contour expansion/erosion and exhausted erosion collapse;
- exact convex CW-hole sign/orientation semantics;
- orthogonal concave cleanup, including topology-changing single-result and multi-result positive contours;
- isolated positive non-orthogonal V-notch cleanup and matching one-reflex negative `pftNegative` cleanup;
- noninteracting NonZero cross-path behavior for direct holes, disconnected positive roots and nested same-sign suppression, including pinned `BuildResult()` starts/order;
- interacting two-positive axis-aligned rectangles for same-span touch, diagonal area overlap, partial unequal edge/T contacts and point-only contacts;
- exactly two positive strictly convex contours with only proper boundary crossings, preserving modified Clipper1 scanline intersection rounding and exact `BuildResult()` order/start;
- exactly two positive strict-convex **triangles** for the bounded zero-area contact states now proven by the batch oracle: supported single-point contacts with distinct bottom scanlines, complete shared edge, and the represented strict-contained edge directions;
- **new #510 scope:** exactly two positive strict-convex triangles with one partial collinear contact for the proven states: endpoint-aligned overlap at the host-edge start for arbitrary slope, endpoint-aligned overlap at a horizontal host-edge end, and horizontal staggered overlap with a unique minimum-Y output vertex. Cases that would require post-join collinear fixup are rejected.

Still **not** general Clipper1 parity: wider-convex contact `OutRec` state, equal-bottom point-contact ties, strict-contained decreasing-Y joins, non-horizontal host-end partial joins, non-horizontal staggered joins, fixup-created collinearity, mixed proper-crossing + touch/collinear cases, interacting holes, more than two interacting paths, deeper/multiple surviving hole hierarchy, multi-reflex/non-local non-orthogonal cleanup, orthogonal hole/point-touch ambiguity and remaining prepared-outline final-union cases. Those continue to use explicit compatibility fallback where necessary.

## First unfinished priority

Continue in source/dependency order:

1. finish the remaining two-path convex boundary-degeneracy seam with exact pinned evidence: **non-horizontal host-end and non-horizontal staggered collinear joins, equal-bottom/fixup contact states, then mixed proper-crossing + touch/collinear cases**; widen beyond triangles only after raw `OutRec`/`BuildResult()` behavior is independently proved;
2. continue the same Clipper1 final cross-path boolean priority with **interacting holes**, then **more than two interacting paths**;
3. extend per-path Clipper1 `Execute()` beyond current V-notch/orthogonal subsets: multiple reflex vertices, non-local self-intersections, split/hole-producing non-orthogonal results and more general negative `pftNegative` cleanup;
4. validate remaining prepared-outline final `unionNonZero()` cases so that a later Clipper2 call cannot silently reintroduce source-order/rounding drift after exact pre-offset work;
5. expand whole `process_arachne()` differentials to disconnected islands, small/narrow holes, non-orthogonal concave notches, variable-width/open-line cases and one-wall/overhang/fuzzy combinations;
6. only after broader green evidence consider promoting represented `process_arachne()` as a whole to scoped `parity_verified`;
7. continue separate preprocessing dependencies such as the full QIDI auto circle-compensation geometry producer where still unrepresented;
8. continue later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft toolpaths, then full G-code, persistence/profiles, scene/Preview, Device/cloud, calibration, desktop and UI parity;
9. publish and SHA-verify real runtime assets before any release-complete claim.

## Latest implementation commits

- `1e4d9bcdb75bf975b48c54bd2b9d4b75a5637d70` — `feat: port partial collinear triangle unions`;
- `bf3610af5327a82e43469d31d4fd825128635c23` — `fix: bound convex contact union to proven triangles`;
- `949bca3d4f5f3495dcbb9f4571461fd9d9b552af` — `fix: reject partial joins needing Clipper fixup`;
- `e47419459d52587a7af7d86a5d025fe30dd97a66` — `test: lock partial collinear Clipper1 unions`;
- `d1731f14121c80af883e78204fdcd6bc3b41116d` — `feat: route exact partial collinear unions`.

## Numeric/source invariants

- slicer coordinates use `SCALING_FACTOR = 0.00001` mm (100000 source units/mm);
- pinned `EPSILON = 1e-4` and `SCALED_EPSILON = 10` source units;
- preserve source integer geometry until the source converts units;
- preserve explicit/implicit `float` boundaries before geometry/config arithmetic;
- preserve source `scaled<T>` truncation, `lrint`, half-away `Round()` and narrowing-cast boundaries;
- keep Boost.Polygon 1.83 operand/bit semantics, including existing `BigInt` boundaries;
- never replace a source oddity with a cleaner algorithm without an independent source oracle.

## Overall product state

All top-level product gates remain **OPEN**. The perimeter/Arachne slice is much further along than the whole product, but major remaining work includes later slicer/toolpath families, full G-code behavior, project/profile persistence and formats, scene/editor/Preview, Device/cloud/P2P/account/camera/HMS/firmware, calibration, desktop integration, full UI/localization/accessibility and release/runtime assets.

## Working discipline

For each source batch: identify the exact pinned source function and dependencies; port literal behavior; add translated/differential/compiled-oracle tests; confirm `.github/workflows/flutter-parity.yml` on pinned Flutter 3.47.2; never weaken analyzer/tests or widen tolerances just to turn CI green; then update migration ledgers. A scoped passing test never closes a top-level product gate.
