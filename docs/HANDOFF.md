# Handoff — Qidi Flow strict Flutter/Dart rewrite

This repository is a **strict 1:1 reimplementation** of Qidi Flow 2.07.02.60 Pass28 in Flutter + Dart. The legacy C++/wxWidgets/React application is reference material only and must not remain a runtime backend through FFI, subprocesses, native shared libraries, hidden services or embedded legacy WebViews.

## Read first

1. [`../migration/PARITY_CONTRACT.md`](../migration/PARITY_CONTRACT.md) — acceptance authority.
2. [`../migration/MIGRATION_STATUS.md`](../migration/MIGRATION_STATUS.md) — subsystem truth and dependency order.
3. [`../migration/TRACEABILITY.md`](../migration/TRACEABILITY.md) — source → Dart → evidence ledger.
4. [`../migration/VALIDATION.md`](../migration/VALIDATION.md) — executed evidence.
5. [`../migration/FUZZY_SKIN_SOURCE_NOTES.md`](../migration/FUZZY_SKIN_SOURCE_NOTES.md) — pinned fuzzy-skin contract.

Do not infer completion from visual similarity, compilation or common-case tests. Source quirks are part of the contract.

## Current validated checkpoint — 2026-09-15

Latest validated code checkpoint:

- code commit `a987f4ae1858af1f973d1c72fb3ce17ff93c7f2c` (`test: lock ordered strict-max mixed point joins`);
- `.github/workflows/flutter-parity.yml` run `34939897047` (#575), job `104285940280`;
- Flutter `3.47.2`;
- Dart `3.13.2`;
- `flutter analyze` → **No issues found!**;
- `flutter test --reporter expanded` → **854/854 passed**;
- job conclusion → **success**.

The suite retains every earlier represented Classic/Arachne/geometry fixture and adds six tests beyond #569 for the independently proved ordered strict-maximum mixed point-touch state: three exact all-rotation/input-order fixtures, exact Arachne zero-offset routing and two explicit rejection boundaries.

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

### #549 / #552 endpoint-aligned one-point fixup extension

Two independent helpers cover the endpoint-aligned triangle states where the join creates **one shared host endpoint collinear between the two third vertices** and `FixupOutPolygon()` removes exactly that point.

`SourceClipper1TwoConvexHostEndFixupUnion2` directly owns the host-end state. Its raw matrix matched **145800/145800** full result paths across increasing/decreasing non-horizontal edges, vertical edges, both horizontal directions, integer shears, all 3×3 cyclic rotations and both input orders. Post-fix raw start is `hostStart` for every non-horizontal or leftward-horizontal host edge, and `guestThird` for a rightward horizontal host edge.

`SourceClipper1TwoConvexHostStartFixupUnion2` independently owns the symmetric host-start state. Its raw matrix also matched **145800/145800** full result paths across the same direction/shear/rotation/order families. Post-fix start follows the proven host-start source-state rule: interior overlap for `dy < 0` or horizontal-right, otherwise host third.

Combined endpoint-aligned one-point fixup evidence is **291600/291600 exact full raw paths**.

### #562 full-shared-edge one-point fixup extension

`SourceClipper1TwoConvexFullSharedEdgeFixupUnion2` covers exactly two positive strict-convex triangles that share one complete edge and where `FixupOutPolygon()` removes exactly one shared endpoint because it lies strictly between the two third vertices.

Direct raw-ELF evidence is **226908/226908 exact raw result paths**:

- removed endpoint is **not** the ordinary full-edge `BuildResult()` start: **64800/64800**;
- removed endpoint **is** that ordinary start, classification matrix: **64800/64800**;
- independently generated removed-start cases with unequal third-vertex distances from the support line: **97200/97200**;
- targeted equal-Y pointer-state boundaries: **108/108**.

Every broad matrix includes all 3×3 cyclic source rotations and both input orders. When cleanup removes the ordinary start, the exact replacement start is intentionally input/AddPath-order sensitive and is represented from the pinned `OutRec::Pts` state; the implementation does not canonicalize the contour.

For strict triangles with a single collinear shared interval, the one-point post-join collinearity classes are represented for endpoint-aligned overlaps (#549/#552) and full shared edges (#562). Strict-contained and staggered overlaps retain a support-line boundary segment at each relevant endpoint and therefore do not create the same third-vertex/third-vertex cleanup geometry. This does **not** prove wider-convex, multi-point cleanup or mixed-crossing fixup behavior.

### #569 / #575 mixed proper-crossing + point-touch extensions

`SourceClipper1TwoConvexMixedPointUnion2` remains deliberately state-bounded to exactly two positive strict-convex triangles with at least one proper boundary crossing, exactly one unique vertex↔strict-edge-interior point touch, no second touch and no nonzero collinear overlap.

#569 proved the first source-event class: the touching source vertex is the **strict minimum-Y vertex** of its owning triangle. Its independent raw-ELF matrix remains **39600/39600 exact full raw result paths**: 2,200 base geometries × all 3×3 cyclic source rotations × both polygon input orders.

#575 adds a second independent source-event class. The touching source vertex is the **strict maximum-Y vertex** of its owning triangle, the touched edge is non-horizontal, and the other triangle's third vertex is strictly earlier in Clipper scanline order than both adjacent owner vertices:

`otherThird.y < min(ownerPrevious.y, ownerNext.y)`.

The independent #575 raw matrix matched **72000/72000 exact full raw result paths**: 4,000 newly generated base geometries × all 3×3 cyclic source rotations × both polygon input orders. It spans 1–4 proper crossings and vertical, positive-slope and negative-slope touched edges. Equality includes raw contour count, exact integer coordinates, vertex sequence and `BuildResult()` start with no normalization.

A runtime trace of 500 targeted canonical bases showed **400** without touch-time local-max/append activity and **100** with touch-time `AddLocalMaxPoly()` + `AppendPolygon()` at the touching vertex; all 500 still produced the exact proved raw start. Therefore touch-time append is acceptance-relevant but is not by itself a failure predicate; the proved scanline ordering is what bounds this new class.

A tempting weaker guard was separately falsified: strict-maximum + vertical touched edge + exactly one proper crossing matched only **44712/45000**, leaving **288** raw mismatches (16 base geometries across rotations/orders). Broad strict-maximum and side-vertex states also retain raw-start counterexamples. Horizontal touched edges, equal-Y owner states and all remaining mixed collinear states therefore stay fallback.

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
- exactly two positive strict-convex **triangles** for raw-proven zero-area contact states, partial collinear contact states and one-point fixup states through #562;
- exactly two positive strict-convex triangles for mixed proper-crossing + single point-touch states when the touching vertex is either the #569 strict minimum-Y source vertex or the #575 ordered strict maximum-Y source vertex described above.

Still **not** general Clipper1 parity: remaining mixed proper-crossing + touch/collinear output-list states, wider-convex contact/fixup `OutRec` state, multi-point or otherwise unrepresented cleanup, interacting holes, more than two interacting paths, deeper/multiple surviving hole hierarchy, multi-reflex/non-local non-orthogonal cleanup, orthogonal hole/point-touch ambiguity and remaining prepared-outline final-union cases. Those continue to use explicit compatibility fallback where necessary.

## First unfinished priority

Continue in source/dependency order:

1. continue **mixed proper-crossing + point-touch/collinear two-positive paths** beyond the #569/#575 proved event classes: remaining strict-maximum states outside the scanline-order guard, side-vertex touches, horizontal/equal-Y touch ordering, then mixed collinear cases; use traced `AppendPolygon()` / `OutRec::Pts` source state rather than a geometric normalization heuristic;
2. keep wider-convex and any multi-point/non-triangle `FixupOutPolygon()` states explicit fallback until their raw `OutRec` behavior is independently proved;
3. continue the same Clipper1 final cross-path boolean priority with **interacting holes**, then **more than two interacting paths**;
4. extend per-path Clipper1 `Execute()` beyond current V-notch/orthogonal subsets: multiple reflex vertices, non-local self-intersections, split/hole-producing non-orthogonal results and more general negative `pftNegative` cleanup;
5. validate remaining prepared-outline final `unionNonZero()` cases so that a later Clipper2 call cannot silently reintroduce source-order/rounding drift after exact pre-offset work;
6. expand whole `process_arachne()` differentials to disconnected islands, small/narrow holes, non-orthogonal concave notches, variable-width/open-line cases and one-wall/overhang/fuzzy combinations;
7. only after broader green evidence consider promoting represented `process_arachne()` as a whole to scoped `parity_verified`;
8. continue separate preprocessing dependencies such as the full QIDI auto circle-compensation geometry producer where still unrepresented;
9. continue later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft toolpaths, then full G-code, persistence/profiles, scene/Preview, Device/cloud, calibration, desktop and UI parity;
10. publish and SHA-verify real runtime assets before any release-complete claim.

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

- `812325797141ebc93c60a64d30df36b89af419e1` — `feat: port host-end fixup triangle joins`;
- `f6c86e37d4f8c624180f032eed2e217f1157ce7a` — `feat: route host-end fixup triangle joins`;
- `7c5e6ea5abc19281c0c8b46ef414a921da40db9d` — `test: lock host-end fixup triangle joins` (#549, 824/824);
- `902d8ec10bc1b8bdef31ea73c2a85b97752a9d81` — `feat: port host-start fixup triangle joins`;
- `767b861f1a9ff19cfa310dbb3ea3ce10cdbc26a9` — `feat: route host-start fixup triangle joins`;
- `3be152aa74f3c555423a39d1b2ab36b63f959343` — `test: lock host-start fixup triangle joins` (#552, 832/832).

Full-shared-edge one-point fixup contacts:

- `48fa05631b10c3d6b3fcd90f849c371a121bd245` — `feat: port full-edge Clipper1 fixup subset`;
- `69f33f0c595e3c706262602d7e44bfb8bfc96789` — `feat: route full-edge Clipper1 fixup subset`;
- `0027cf0e44657c84bdfa81f52c115640085a7c18` — `test: lock full-edge Clipper1 fixup subset`;
- `debc03fcd136383d5018623ea2b208b897a58979` — `feat: cover removed-start full-edge fixups`;
- `8f9b8f0fbdea9c476ad9fd5b46161e5aaf76b5c1` — `test: cover full-edge removed-start fixups` (#562, 840/840).

Mixed proper-crossing + point-touch subsets:

- `b8fdfce251655201bfbd6e94afc55947efe06dc6` — `feat: port mixed point-touch Clipper1 union subset`;
- `c4e2861adcd73de4c54ef8624715358f484c4d90` — `test: lock mixed point-touch Clipper1 subset`;
- `d238cc809cc40f55a29db20c0010188007832414` — `feat: route mixed point-touch Clipper1 subset` (#569, 848/848);
- `dca1d60ad0bc2d3092469852da42c0bc9900f3d5` — `feat: extend ordered mixed point-touch unions`;
- `a987f4ae1858af1f973d1c72fb3ce17ff93c7f2c` — `test: lock ordered strict-max mixed point joins` (#575, 854/854).

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
