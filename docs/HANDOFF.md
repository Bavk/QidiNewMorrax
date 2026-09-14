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

- code commit `fc088335516dcf63522260184b83d1791f696606` (`test: cover guarded decreasing host-end joins`);
- `.github/workflows/flutter-parity.yml` run `34853812738` (#518), job `104008105596`;
- Flutter `3.47.2`;
- Dart `3.13.2`;
- `flutter analyze` → **No issues found!**;
- `flutter test --reporter expanded` → **786/786 passed**;
- job conclusion → **success**.

The suite retains every earlier represented Classic/Arachne/geometry fixture and adds five tests beyond #510 for exact non-horizontal host-end/staggered triangle states, Arachne routing and conservative rejection of neighboring unproved states.

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

Retained evidence includes the #493 **39/39** exact proper-crossing convex matrix, the #510 triangle contact/start audits (`1100/1100` standalone starts, `1000/1000` full shared-edge starts, `4600/4600` supported contact state predicates) and the #510 partial-collinear matrix (`4392/4392` exact raw result paths after excluding post-join fixup cases).

The #518 extension targeted the remaining non-horizontal partial-collinear triangle seam. Broad exploratory probing first showed that a slope/sign-only rule is not invariant under source-list state and cyclic input rotation. Exact routing was therefore restricted to raw-state predicates that survived independent differentials:

- non-horizontal host-end joins with host edge `dy > 0`: **12000/12000** exact raw result paths;
- non-horizontal host-end joins with `dy < 0` only when the guest triangle's standalone Clipper1 result start is the shared host endpoint: **12000/12000** exact;
- negative-slope non-horizontal staggered joins only when the down-left source edge starts at its owning triangle's standalone Clipper1 result start: **12000/12000** exact.

The new matrices vary translations, overlap ratios, third-vertex placement, cyclic triangle vertex rotations and both polygon input orders. Combined #518 evidence is **36000/36000 exact raw paths**. Other states still reject instead of extrapolating from geometry.

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
- exactly two positive strict-convex **triangles** for the bounded zero-area contact states proved by direct ELF evidence: supported single-point contacts with distinct bottom scanlines, complete shared edge and represented strict-contained directions;
- exactly two positive strict-convex triangles with one represented partial collinear contact: the #510 host-start/horizontal states plus **new #518 non-horizontal states** — host-end `dy > 0`, guarded host-end `dy < 0` when the guest standalone start is the shared endpoint, and negative-slope staggered overlap when the down-left source edge begins at the owning triangle's standalone result start. Merged cycles needing additional collinear `FixupOutPolygon()` cleanup remain rejected.

Still **not** general Clipper1 parity: wider-convex contact `OutRec` state, equal-bottom point-contact ties, strict-contained decreasing-Y contact states, other decreasing-Y host-end starts, positive-slope/other non-horizontal staggered states, fixup-created collinearity, mixed proper-crossing + touch/collinear cases, interacting holes, more than two interacting paths, deeper/multiple surviving hole hierarchy, multi-reflex/non-local non-orthogonal cleanup, orthogonal hole/point-touch ambiguity and remaining prepared-outline final-union cases. Those continue to use explicit compatibility fallback where necessary.

## First unfinished priority

Continue in source/dependency order:

1. finish the remaining two-path convex boundary-degeneracy seam with exact pinned evidence: **remaining decreasing-Y host-end states, positive-slope/other non-horizontal staggered states, equal-bottom/fixup contact states, then mixed proper-crossing + touch/collinear cases**; widen beyond triangles only after raw `OutRec`/`BuildResult()` behavior is independently proved;
2. continue the same Clipper1 final cross-path boolean priority with **interacting holes**, then **more than two interacting paths**;
3. extend per-path Clipper1 `Execute()` beyond current V-notch/orthogonal subsets: multiple reflex vertices, non-local self-intersections, split/hole-producing non-orthogonal results and more general negative `pftNegative` cleanup;
4. validate remaining prepared-outline final `unionNonZero()` cases so that a later Clipper2 call cannot silently reintroduce source-order/rounding drift after exact pre-offset work;
5. expand whole `process_arachne()` differentials to disconnected islands, small/narrow holes, non-orthogonal concave notches, variable-width/open-line cases and one-wall/overhang/fuzzy combinations;
6. only after broader green evidence consider promoting represented `process_arachne()` as a whole to scoped `parity_verified`;
7. continue separate preprocessing dependencies such as the full QIDI auto circle-compensation geometry producer where still unrepresented;
8. continue later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft toolpaths, then full G-code, persistence/profiles, scene/Preview, Device/cloud, calibration, desktop and UI parity;
9. publish and SHA-verify real runtime assets before any release-complete claim.

## Latest implementation commits

- `406bc5e30f700aad22026fcaf9cf935edaae71e8` — `feat: extend non-horizontal Clipper1 joins`;
- `f61c5a7e98fcc901b336a91d4edb1c16aff8b589` — `test: lock non-horizontal collinear joins`;
- `d65ea0412511f30ef7a56bdf901152481afc4749` — `feat: add guarded decreasing collinear joins`;
- `fc088335516dcf63522260184b83d1791f696606` — `test: cover guarded decreasing host-end joins`.

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
