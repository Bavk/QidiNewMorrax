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

- code commit `3be152aa74f3c555423a39d1b2ab36b63f959343` (`test: lock host-start fixup triangle joins`);
- `.github/workflows/flutter-parity.yml` run `34897876786` (#552), job `104156397361`;
- Flutter `3.47.2`;
- Dart `3.13.2`;
- `flutter analyze` → **No issues found!**;
- `flutter test --reporter expanded` → **832/832 passed**;
- job conclusion → **success**.

The suite retains every earlier represented Classic/Arachne/geometry fixture and adds thirty tests beyond #532: seven equal-bottom point-contact tests, seven decreasing-Y strict-contained contact tests, eight host-end fixup tests and eight host-start fixup tests.

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

Retained evidence includes the #493 **39/39** exact proper-crossing convex matrix, the #510 triangle contact/start audits (`1100/1100` standalone starts, `1000/1000` full shared-edge starts, `4600/4600` older supported contact predicates), the #510 partial-collinear matrix (`4392/4392`), the #518 guarded non-horizontal extension (**36000/36000**), the #525 remaining decreasing-Y host-end extension (**23400/23400**) and the #532 all-slope non-horizontal staggered extension (**145800/145800**).

### #539 equal-bottom point-contact extension

`SourceClipper1TwoConvexEqualBottomContactUnion2` closes the point-contact ordering seam for exactly two positive strict-convex triangles whose maximum-Y/bottom scanline is equal. Direct raw ELF evidence matched **41400/41400 exact raw result paths**:

- broad vertex↔vertex / vertex↔edge equal-bottom matrix: **21600/21600**;
- shared-bottom and flat-bottom vertex-contact matrix: **9000/9000**;
- sheared nonvertical vertex↔edge matrix: **10800/10800**.

Each contour preserves its standalone positive-triangle `BuildResult()` start, while tied-bottom result contour order is exactly the **reverse of `AddPath()` / input order**. All matrices include all 3×3 cyclic rotations and both input orders. Wider convex paths and non-point contacts are not implied.

### #542 decreasing-Y strict-contained extension

`SourceClipper1TwoConvexDecreasingStrictContainedUnion2` closes the previously unrepresented strict-contained shared-edge triangle state whose longer host edge has `dy < 0`. Direct raw ELF matrices matched **30600/30600 exact full result paths**: **25200/25200** broad cases plus **5400/5400** targeted vertical/equal-Y/slope-boundary cases.

Let `qStart` be the overlap endpoint nearer host start, `qEnd` nearer host end, `G` the guest third vertex and `H` the host third vertex. Exact raw start is `qEnd` for `G.y < qStart.y`, `H` for `G.y > qStart.y`, and the standalone host-triangle Clipper1 start on equality. All matrices include all 3×3 cyclic rotations and both input orders.

### #549 / #552 endpoint-aligned fixup extension

Two independent helpers now cover the exact endpoint-aligned triangle state where the join creates **one shared host endpoint collinear between the two third vertices**, and `FixupOutPolygon()` removes exactly that point. These helpers do not generalize to other fixup topologies.

`SourceClipper1TwoConvexHostEndFixupUnion2` directly owns the host-end state. Its raw matrix matched **145800/145800** full result paths across increasing/decreasing non-horizontal edges, vertical edges, both horizontal directions, integer shears, all 3×3 cyclic rotations and both input orders. Post-fix raw start is `hostStart` for every non-horizontal or leftward-horizontal host edge, and `guestThird` for a rightward horizontal host edge.

`SourceClipper1TwoConvexHostStartFixupUnion2` independently owns the symmetric host-start state. Its raw matrix also matched **145800/145800** full result paths across the same direction/shear/rotation/order families. Post-fix start follows the already-proven host-start source-state rule: interior overlap for `dy < 0` or horizontal-right, otherwise host third.

Combined endpoint-aligned one-point fixup evidence is therefore **291600/291600 exact full raw paths**. The central exact router reaches both through the fixup gateway; non-endpoint/staggered/full-edge cleanup states remain fallback.

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
- exactly two positive strict-convex **triangles** for the raw-proven zero-area contact states: distinct-bottom point contacts, equal-bottom point contacts, complete shared edge and represented strict-contained directions including decreasing-Y;
- exactly two positive strict-convex triangles with represented partial collinear contact: host-start/horizontal states, guarded/remaining host-end states, all non-horizontal staggered non-fixup states, plus the newly proven **endpoint-aligned host-start/host-end one-point fixup** states.

Still **not** general Clipper1 parity: wider-convex contact `OutRec` state, **other non-endpoint fixup-mutated contact/partial joins**, mixed proper-crossing + touch/collinear cases, interacting holes, more than two interacting paths, deeper/multiple surviving hole hierarchy, multi-reflex/non-local non-orthogonal cleanup, orthogonal hole/point-touch ambiguity and remaining prepared-outline final-union cases. Those continue to use explicit compatibility fallback where necessary.

## First unfinished priority

Continue in source/dependency order:

1. finish the remaining two-path convex boundary-degeneracy seam with exact pinned evidence: **other non-endpoint fixup-mutated contact/partial joins, then mixed proper-crossing + touch/collinear cases**; widen beyond triangles only after raw `OutRec`/`BuildResult()` behavior is independently proved;
2. continue the same Clipper1 final cross-path boolean priority with **interacting holes**, then **more than two interacting paths**;
3. extend per-path Clipper1 `Execute()` beyond current V-notch/orthogonal subsets: multiple reflex vertices, non-local self-intersections, split/hole-producing non-orthogonal results and more general negative `pftNegative` cleanup;
4. validate remaining prepared-outline final `unionNonZero()` cases so that a later Clipper2 call cannot silently reintroduce source-order/rounding drift after exact pre-offset work;
5. expand whole `process_arachne()` differentials to disconnected islands, small/narrow holes, non-orthogonal concave notches, variable-width/open-line cases and one-wall/overhang/fuzzy combinations;
6. only after broader green evidence consider promoting represented `process_arachne()` as a whole to scoped `parity_verified`;
7. continue separate preprocessing dependencies such as the full QIDI auto circle-compensation geometry producer where still unrepresented;
8. continue later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft toolpaths, then full G-code, persistence/profiles, scene/Preview, Device/cloud, calibration, desktop and UI parity;
9. publish and SHA-verify real runtime assets before any release-complete claim.

## Latest implementation commits

Equal-bottom point contacts:

- `cd7ba4823d8325367e0357518ba22dc300156e52` — `feat: port equal-bottom triangle point contacts`;
- `416d65a0dd265200a6c24cd1d05f22e3ffe8bb56` — `feat: route equal-bottom triangle contacts`;
- `c95cdaad9da17ce48ad01a3fc06697d483acdd99` — `test: lock equal-bottom triangle contacts` (#539, 809/809).

Decreasing-Y strict-contained contacts:

- `f8d034d9a16d0f654940bbdb05547ad56e038098` — `feat: port decreasing strict-contained contacts`;
- `7c4521919b961f0d50c4a32ab07a748f6305d70b` — `feat: route decreasing strict-contained contacts`;
- `1299cb5999f31b5c1659e1796d6d462fafa5d9f1` — `test: lock decreasing strict-contained contacts` (#542, 816/816).

Endpoint-aligned one-point fixup contacts:

- `95bff65f41cf25c92465d2e48e71cca37e5320fb` — `feat: port host-end fixup triangle joins`;
- `2815d153f7ffeec84a9cce71af074487ede4a9f0` — `feat: route host-end fixup triangle joins`;
- `7c5e6ea5abc19281c0c8b46ef414a921da40db9d` — `test: lock host-end fixup triangle joins` (#549, 824/824);
- `902d8ec1de7bde47c9bfb954056aabbcd348fabd` — `feat: port host-start fixup triangle joins`;
- `767b861f9c118ef1039398648dd8a14afe9c7b5b` — `feat: route host-start fixup triangle joins`;
- `3be152aa74f3c555423a39d1b2ab36b63f959343` — `test: lock host-start fixup triangle joins` (#552, 832/832).

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
