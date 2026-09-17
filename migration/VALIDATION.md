# Validation record — strict 1:1 rewrite

This file records only work that has actually executed. Acceptance authority remains [`PARITY_CONTRACT.md`](PARITY_CONTRACT.md); a passing subset never closes a top-level application gate.

## Input identity / loss-prevention baseline

- Supplied archive: `QidiFlow-2.07.02.60-Pass28-Device-Reference-Redesign-Clean(1).zip`.
- Archive SHA-256 from the initial audit: `821ed379d65916df32f5d031bd583bc724ce72f4d229447adc61280701e4d57d`.
- Extracted source files inventoried: **8,632**.
- Earlier local runtime-asset audit: **3,657/3,657** copied runtime entries matched source SHA-256; full publication/reverification from GitHub/release inputs is still open.

## Current executed Flutter/Dart checkpoint — 2026-09-18

Pinned toolchain:

- Flutter `3.47.2`;
- Dart `3.13.2`;
- Ubuntu 24.04 hosted runner.

GitHub Actions `.github/workflows/flutter-parity.yml` run `35284252825` (#639), job `105412942943`, executed clean code checkpoint `9f04863ea904552d8edd7034067630bd82f8be98` and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **874/874 tests passed**;
- job conclusion — **success**.

The suite re-executes all earlier represented Classic/Arachne/geometry/Boost/Clipper fixtures and adds exact AEL-outside retained-wedge and retained-inner rounded strict-max regressions, Arachne zero-offset routing for both, an alternate source `BuildResult()` start, and negative early-second-touch / extra-`TopX` scanbeam neighbors that remain on fallback.

## Independent pinned BambuStudio oracle provenance

Reference evidence comes from the **actual upstream compiled BambuStudio artifact and exact pinned source commit**, not from the Dart implementation under test.

- repository: `bambulab/BambuStudio`;
- source commit: `f2b55a5a83f266cf56e06c7943a81a08bebb7fad`;
- successful upstream GitHub Actions run: `34298498452` (`Build all`);
- Ubuntu 24.04 artifact ID/name: `10085378329` / `BambuStudio_ubuntu-24.04_V02.08.03.66`;
- downloaded artifact SHA-256: `912517d86774f4705c28a9e649f3fc91f96fe1623bdf070cb5f14f02ba3827f8`;
- extracted AppImage SHA-256: `ad90fda9a4537222a679b5d2ad12712a86652858106dce00f69fac24c3af8b46`;
- CLI version: `02.08.03.66`.

The artifact was re-used from the previously SHA-verified download for retained raw-ELF batches. The debug-symbol ELF exposes the pinned modified Clipper 6.2.9 implementation. The preload probe calls the exact `clipper_union(Paths&, pftNonZero)` template at PIE offset `0x10b54d0` before application startup and dumps raw result paths without normalizing rotation/order.

Pinned source inspection and ELF tracing confirm why geometric equivalence is insufficient: `BuildResult(Paths&)` starts each result at `OutRec::Pts->Prev`; `AddOutPt()`, local-minimum/local-maximum side assignment, `AppendPolygon()`, `JoinPoints()` and `FixupOutPolygon()` can change output-list state and therefore raw path rotation/order.

## #615 rounded-to-touch AEL-contained strict-maximum collapse

`SourceClipper1TwoConvexMixedPointUnion2` now represents one rounded/degenerated strict-max state beyond the #608 separated-minimum endpoint-Y boundary. The state has exactly one proper crossing whose pinned Clipper1 rounded intersection lands on the strict maximum-Y point-touch coordinate. This is **not** accepted from geometry alone.

A direct pinned-source event trace in run `35122390233`, job `104883098941`, established the source-shaped discriminator. At `touch.y`, the accepted branch has both already-active bounds from the touched triangle between the two owner bounds under the exact Clipper1 `E2InsertsBeforeE1()` / `TopX()` ordering. Both owner bounds therefore contribute with `WindCnt == 1`; the same-coordinate proper-cross/touch events remove the rounded-away sliver and the raw result is the owner contour beginning at the positive-order owner predecessor. Two traced counterstates put an active other bound outside that interval, give the owner `WindCnt == 2`, and retain either an inner vertex or a wedge; both are committed as fallback regressions.

Independent pinned-source matrices at commit `f2b55a5a83f266cf56e06c7943a81a08bebb7fad` produced:

- run `35122592466`, job `104883775222`: **5,000** bases × 18 variants = **90000/90000 exact complete raw paths**;
- run `35123441575`, job `104886606102`, conclusion success: **1,000** asymmetric, nonzero-translated bases × 18 variants = **18000/18000 exact complete raw paths**, with collapsed-owner-edge split 531/469;
- supplementary run `35122868681`, job `104884696367`: **1,239** translated/scaled valid bases = **22302/22302 exact complete raw paths** before its generation-attempt cap;
- supplementary run `35123235250`, job `104885923066`: **1,935** asymmetric translated valid bases = **34830/34830 exact complete raw paths** before its generation-attempt cap.

The supplementary runs ended because their requested valid-base quota was not reached inside the attempt cap; neither produced a source mismatch. Aggregate represented evidence is **9,174 bases / 165132/165132 exact complete raw-path comparisons**, each base checked over all 3×3 cyclic rotations and both input/AddPath orders.

The Dart change ports the pinned equal-`Curr.x` `E2InsertsBeforeE1()` tie branch, validates the AEL-contained state, and returns the exact owner predecessor→touch→successor path before the ordinary boundary reconstruction. #615 deliberately left AEL-outside rounded retained-output cases for separate classification; #639 below promotes only two independently proved sub-branches. Side-vertex touches, horizontal touch ordering, mixed-collinear output-list states and other rounded degeneracies remain fallback.

Flutter parity #615 (`35124252980`, job `104889290591`) is green on Flutter **3.47.2** / Dart **3.13.2**, analyzer clean, **868/868** tests passing.

## #639 AEL-outside retained-output rounded strict-maximum branches

`SourceClipper1TwoConvexMixedPointUnion2` now represents two AEL-outside `WindCnt == 2` rounded-to-touch states that were explicit #615 counterclasses, without promoting the surrounding family.

The **retained-wedge** branch is accepted only when the touched other bound is between the owner bounds, the crossing-side other bound is outside, the positive-order touched endpoint is outside owner, and the inner other edge does **not** cross the owner-predecessor scanbeam. Under that bounded source state the raw contour is the traced five-point cycle and uses the ordinary rightmost-global-minimum `BuildResult()` anchor. A generated counterstate where the inner other edge spans that scanbeam produces an additional source `TopX` output vertex and remains fallback.

The **retained-inner** branch is accepted only when the positive-order touched endpoint is strictly inside owner, it occurs below the owner predecessor, the other third vertex occurs below that endpoint, and the active touched bound remains integer-`TopX` tied with the outgoing owner bound at the first owner-predecessor scanbeam. Direct source event trace run `35283858278`, job `105411701842`, proves this discriminator: the retained fixture does not process the second same-coordinate touch intersection at `touch.y`; the traced owner-only counterstate has divergent `TopX` values on that first scanbeam, processes the second intersection at the touch, and loses the inner endpoint.

Independent pinned-source oracle run `35284009243` at source commit `f2b55a5a83f266cf56e06c7943a81a08bebb7fad` produced:

- wedge job `105412173334`: fixed fixture **18/18 exact complete raw paths**, plus **1,200/1,200** independently generated bases × all 18 cyclic-rotation/input-order variants = **21600/21600 exact complete raw paths**;
- retained-inner job `105412173551`: fixed fixture **18/18 exact complete raw paths**, plus **1,200/1,200** independently generated bases × all 18 variants = **21600/21600 exact complete raw paths**.

The committed Dart regressions additionally lock the alternate wedge `BuildResult()` start, exact Arachne zero-offset routing for both represented states, the retained-inner first-scanbeam-divergence owner-only counterstate, and both retained/wedge extra-`TopX` scanbeam neighbors as fallback.

Flutter parity #639 (`35284252825`, job `105412942943`) is green on Flutter **3.47.2** / Dart **3.13.2**, analyzer clean, **874/874** tests passing.

## #608 late strict-maximum single-crossing separated-minimum boundary

`SourceClipper1TwoConvexMixedPointUnion2` now independently represents the retained historical "rounded strict-max" fixture as a precise late strict-maximum **single-crossing separated-minimum** source state, rather than treating that fixture as a generic rounded-degeneracy class.

Represented #608 state remains bounded to exactly two positive strict-convex triangles, exactly one unique vertex↔strict-edge-interior point touch, a strict maximum-Y touching owner vertex, a non-horizontal touched edge, exactly one proper boundary crossing, no second touch and no nonzero collinear overlap. It additionally requires `otherThird.y > min(ownerPrevious.y, ownerNext.y)` and one touched-edge endpoint at exactly that earlier owner-neighbor minimum Y, yielding the proved two-nonadjacent-minimum raw contour boundary.

Direct pinned-source Clipper1 run `35090443828`, job `104775225066`, compiled BambuStudio commit `f2b55a5a83f266cf56e06c7943a81a08bebb7fad` and produced:

- the historical fixed fixture across all 3×3 cyclic rotations and both AddPath/input orders: **18/18 exact complete raw paths**;
- **3,600** independently generated single-crossing bases: 1,200 vertical, 1,200 positive-slope and 1,200 negative-slope touched edges;
- all 18 rotation/input-order variants per generated base: **64800/64800 exact raw starts and 64800/64800 exact complete raw paths**.

This evidence is independent of #601's multi-crossing separated-minimum batch. Together they prove the same endpoint-Y separated-minimum rebase boundary for proper-count 1–4 across the generated matrices. The Dart change only widens `_isLateStrictMaximumSeparatedMinimumBoundary()` from `properCount >= 2` to `properCount >= 1`; all other state predicates and rebase safety checks remain unchanged. The historical fallback regression is now an exact full-path regression across all 18 variants, and Arachne zero-offset routing is locked separately.

Flutter parity #608 (`35090634147`, job `104775845616`) is green on Flutter **3.47.2** / Dart **3.13.2**, analyzer clean, **863/863** tests passing.

This does **not** prove arbitrary rounded intersection degeneracies. Remaining rounded/degenerated strict-max states beyond the separated-minimum endpoint-Y boundary, side-vertex touches, horizontal touch ordering and mixed-collinear cases remain fallback.

## #601 late strict-maximum multi-crossing mixed point-touch oracle

`SourceClipper1TwoConvexMixedPointUnion2` now extends the non-horizontal late strict-maximum `otherThird.y > min(ownerPrevious.y, ownerNext.y)` class beyond the #582 single-crossing state.

Represented #601 state remains deliberately bounded to exactly two positive strict-convex triangles, exactly one unique vertex↔strict-edge-interior point touch, a strict maximum-Y touching owner vertex, a non-horizontal touched edge, no second touch and no nonzero collinear overlap. The new evidence covers the multiple-proper-crossing branch (proper-count 2–4 in the generated source matrices).

Three independent pinned-source batches were executed against BambuStudio commit `f2b55a5a83f266cf56e06c7943a81a08bebb7fad`:

- broad run `35070969892`, job `104712127182`: **6,000** independent bases × all 3×3 cyclic rotations × both AddPath orders = **108000/108000 exact raw-start matches**, spanning proper-count 2–4;
- independently targeted slope run `35071087252`, job `104712499829`: another **108000/108000 exact raw-start matches**, split into **36,000 vertical**, **36,000 positive-slope** and **36,000 negative-slope** touched-edge executions, again spanning proper-count 2–4;
- separated-minimum boundary run `35072113339`, job `104715791685`: **3,600** independently generated bases × all 18 rotation/input-order variants = **64800/64800 exact raw starts and 64800/64800 exact complete raw paths**. This batch targets the source state where one touched-edge endpoint shares the earlier owner-neighbor minimum Y and the final contour has two nonadjacent global minima.

Combined new #601 evidence is **280800/280800 raw-start checks**, with **64800/64800 full raw-path matches** on the independently isolated separated-minimum boundary.

The first Dart extension intentionally retained the old separated-minimum safety guard. PR CI #594 (`35071653958`, job `104714339008`) kept analyzer green but failed the all-rotations regression, correctly exposing that the fixed three-crossing source path has two nonadjacent minima. The final implementation adds `_isLateStrictMaximumSeparatedMinimumBoundary()` and relaxes the rebase guard only for that independently proved source state. Final CI #601 (`35072315131`, job `104716457571`) is green at **862/862**.

Together, #582, #601 and #608 cover the proved late `>` strict-max ordering states from single crossing through the generated multi-crossing matrix (proper-count 1–4), including independently proved separated-minimum endpoint-Y boundaries for both single- and multi-crossing cases. Horizontal touched edges, side-vertex touches, mixed-collinear cases and other rounded/degenerated strict-max states remain fallback.

## #588 strict-maximum equal-Y mixed point-touch boundary

`SourceClipper1TwoConvexMixedPointUnion2` now independently represents the non-horizontal strict-maximum equality boundary between the earlier #575 and #582 classes.

Represented #588 state:

- exactly two positive strict-convex triangles;
- exactly one unique vertex↔strict-edge-interior point touch;
- the touching source vertex is the **strict maximum-Y vertex** of its owning triangle;
- the touched edge of the other triangle is **non-horizontal**;
- there is at least one proper boundary crossing;
- the third vertex of the touched-edge triangle satisfies `otherThird.y == min(ownerPrevious.y, ownerNext.y)`;
- there is no second touch and no nonzero collinear overlap.

For this boundary, an exact Clipper1 source probe was compiled directly from pinned BambuStudio commit `f2b55a5a83f266cf56e06c7943a81a08bebb7fad` in Actions run `35068502159`, job `104704216962`. The generator produced **3,000** independent base geometries:

- **528** one-crossing bases;
- **2,472** multi-crossing bases;
- all **3×3 cyclic source rotations**;
- both polygon input/AddPath orders;
- total: **54,000** raw executions.

All **54000/54000** raw results matched the source `BuildResult()` start rule: select the rightmost global minimum-Y output vertex as the Clipper anchor and begin at its cyclic successor. This broad matrix validates the raw **start rule**, not an independently precomputed full coordinate sequence. A committed fixed equal-Y fixture separately locks the **complete raw path** for all 18 rotation/order variants, including exact integer intersection coordinates and start.

The equality audit exposed a valid source result with two **nonadjacent** global minimum-Y vertices. The first implementation kept the old conservative requirement that two minima be adjacent, so PR CI #587 (`35068818762`, job `104705245694`) correctly failed the new equal-Y `supports()` assertion while analyzer remained clean. Commit `81beaaed952b67843ae63ff114943673304a4b0c` relaxes that adjacency guard **only** for the independently classified #588 equal-Y strict-maximum state; all other rebase safety checks remain unchanged. Final CI #588 is green at **861/861**.

The independently proved non-horizontal strict-maximum partition is now:

- #575: `otherThird.y < min(ownerPrevious.y, ownerNext.y)`, with its matrix spanning 1–4 proper crossings;
- #588: `otherThird.y == min(ownerPrevious.y, ownerNext.y)`, with at least one proper crossing;
- #582 + #601 + #608: `otherThird.y > min(ownerPrevious.y, ownerNext.y)`, with the source matrices spanning the proved single- and multi-crossing states (proper-count 1–4), including the independently proved single- and multi-crossing separated-minimum endpoint-Y boundaries.

Horizontal touched edges, side-vertex touches, mixed-collinear cases and other rounded/degenerated strict-max states remain fallback.

## #582 late strict-maximum single-crossing mixed point-touch oracle

The same helper retains the independently proved late strict-maximum class.

Represented #582 state:

- exactly two positive strict-convex triangles;
- exactly one unique vertex↔strict-edge-interior point touch;
- the touching source vertex is the **strict maximum-Y vertex** of its owning triangle;
- the touched edge of the other triangle is **non-horizontal**;
- there is **exactly one proper boundary crossing**;
- the third vertex of the touched-edge triangle is strictly later than the earlier of the two owner neighbors: `otherThird.y > min(ownerPrevious.y, ownerNext.y)`;
- there is no second touch and no nonzero collinear overlap.

An independently generated direct raw-ELF matrix matched **64800/64800 exact full raw result paths**:

- **3,600** independently generated base geometries with a fresh seed;
- **1,200** vertical touched-edge bases;
- **1,200** positive-slope touched-edge bases;
- **1,200** negative-slope touched-edge bases;
- all **3×3 cyclic source rotations**;
- both polygon input/AddPath orders;
- equality includes raw contour count, exact integer coordinates, vertex sequence and `BuildResult()` start with no normalization.

### Historical rounded-degeneracy regression, now classified by #608

The first test commit for the #582 batch briefly treated the retained strict-max fixture as newly represented. CI #581 correctly failed that assertion because the exact helper still rejected its two-nonadjacent-minimum raw state, so commit `83665f5ab62c70275a415e6d46ea6b0ac903b7e3` restored it to fallback. The independent **64800/64800** #582 oracle matrix did not include that boundary. #608 later isolated the actual source condition — a single-crossing separated-minimum endpoint-Y state — and independently proved it with **64800/64800 exact complete raw paths** plus **18/18** fixed-fixture variants. The fixture is therefore represented now for that exact source-state reason, not by a generic rounded-degeneracy heuristic.

## #575 ordered strict-maximum mixed point-touch oracle

The same helper retains the second mixed source-event class proved in #575:

- strict maximum-Y touching owner vertex;
- non-horizontal touched edge;
- `otherThird.y < min(ownerPrevious.y, ownerNext.y)`;
- no second touch or nonzero collinear overlap.

Its independent raw-ELF matrix remains **72000/72000 exact full raw result paths** from **4,000** newly generated base geometries × all 3×3 cyclic source rotations × both input orders. The base set spans 1–4 proper crossings and vertical, positive-slope and negative-slope touched edges.

A targeted runtime preload trace over **500** canonical #575 bases found 400 without touch-time local-max/append activity and 100 with touch-time `AddLocalMaxPoly()` + `AppendPolygon()` at the touching vertex; **500/500** still matched the proved raw start. Touch-time append is therefore acceptance-relevant but not itself a failure predicate.

A weaker strict-max hypothesis was falsified independently: vertical touched edge + exactly one proper crossing matched only **44712/45000**, leaving **288** raw mismatches. The exact #575/#588/#582/#601/#608/#615 predicates must not be widened from slope, extrema or rounded-coordinate coincidence alone.

## #569 strict-minimum mixed point-touch oracle

The helper retains the first mixed source-event class proved in #569:

- exactly two positive strict-convex triangles;
- at least one proper boundary crossing;
- exactly one unique vertex↔strict-edge-interior point touch;
- touching source vertex is the **strict minimum-Y vertex** of its owning triangle;
- no second touch or nonzero collinear overlap.

The independent #569 matrix remains **39600/39600 exact full raw result paths**: 2,200 independently generated base geometries × all 3×3 cyclic source rotations × both polygon input orders.

### Broad mixed negative evidence retained

The helper remains narrow because broader hypotheses fail raw output-list parity.

First exploratory matrix against the proper-only rebase rule:

- total: **37,008** raw cases;
- exact raw-start matches: **35,874/37,008**;
- raw-start mismatches: **1,134/37,008**.

A second independently generated matrix testing a simpler geometric guard:

- total: **28,800** raw cases;
- exact matches: **27,450/28,800**;
- raw-start mismatches: **1,350/28,800**.

Earlier runtime tracing established that touch-time `AppendPolygon()` / `OutRec::Pts` lifecycle is acceptance-relevant. The #575/#588/#582/#601/#608/#615 results refine that conclusion: append state or rounded-coordinate coincidence alone is not a static classifier. The exact accept/reject boundary must come from independently proved scanline/AEL/output-list state.

## #562 full-shared-edge one-point fixup oracle

`SourceClipper1TwoConvexFullSharedEdgeFixupUnion2`, reached through the existing fixup gateway, covers two positive strict-convex triangles that share one complete edge where `FixupOutPolygon()` removes exactly one shared endpoint.

Represented source state:

- exactly two positive strict-convex triangles;
- complete shared edge in opposite traversal;
- no proper crossings or additional touches away from that edge;
- exactly one shared endpoint lies strictly between the two third vertices;
- `FixupOutPolygon()` removes exactly that point;
- the remaining cycle needs no further cleanup;
- wider-convex, multi-point and mixed-crossing states are not implied.

Direct raw-ELF evidence remains **226908/226908 exact raw result paths**:

- ordinary full-edge start survives cleanup: **64800/64800**;
- removed-start classification matrix: **64800/64800**;
- independent removed-start unequal-third-distance matrix: **97200/97200**;
- targeted equal-Y pointer boundaries: **108/108**.

The removed-start branch intentionally preserves the observed input/AddPath-order-sensitive `OutRec::Pts` rule rather than rotating to a canonical contour.

For strict triangles with one collinear shared interval, represented one-point cleanup geometries include endpoint-aligned partial overlaps (#549/#552) and complete shared edges (#562). Strict-contained or staggered overlap retains support-line boundary fragments and does not create the same adjacent-third-vertex cleanup. This does **not** prove wider-convex, multi-point or mixed-crossing cleanup state.

## #549 / #552 endpoint-aligned one-point fixup oracles

`SourceClipper1TwoConvexHostEndFixupUnion2` and `SourceClipper1TwoConvexHostStartFixupUnion2` retain their exact endpoint-aligned triangle contracts.

- host-end direct raw ELF matrix: **145800/145800 exact full raw paths**;
- host-start symmetric raw ELF matrix: **145800/145800 exact full raw paths**;
- combined endpoint-aligned one-point cleanup evidence: **291600/291600 exact full raw paths**.

These cover both non-horizontal Y directions, vertical edges, both horizontal directions, integer shears, all 3×3 cyclic source rotations and both input orders. They remain separate from the full-edge #562 state and from wider/multi-point cleanup.

## #539 / #542 newer contact oracles

`SourceClipper1TwoConvexEqualBottomContactUnion2` retains **41400/41400** exact raw result paths for equal-bottom point-only triangle contacts. Each contour keeps its standalone positive-triangle start and tied-bottom contour order is reverse AddPath/input order.

`SourceClipper1TwoConvexDecreasingStrictContainedUnion2` retains **30600/30600** exact full raw result paths for the decreasing-Y strict-contained shared-edge triangle state, including vertical/equal-Y boundaries.

## Retained #532 all non-horizontal staggered partial-collinear oracle

`SourceClipper1TwoConvexNonHorizontalStaggeredUnion2` remains exact for non-horizontal staggered two-triangle contact without post-join fixup:

- positive-slope support lines: **48600/48600**;
- negative-slope support lines: **48600/48600**;
- vertical support lines: **48600/48600**;
- combined #532 evidence: **145800/145800 exact raw result paths**.

Each family covers start/end overlap states, equal-Y ties and equality boundaries, all cyclic rotations and both input orders.

## Retained #525 / #518 / #510 contact evidence

- #525 remaining non-fixup decreasing-Y host-end partial-collinear helper: **23400/23400** exact raw result paths.
- #518 guarded non-horizontal extension: **36000/36000** exact raw paths.
- #510 represented partial-collinear baseline: **4392/4392** exact raw paths after excluding fixup states.
- standalone positive triangle starts: **1100/1100**.
- complete shared-edge triangle starts: **1000/1000**.
- older supported point/full/strict-contained contact predicates: **4600/4600**.
- random wider-convex full-shared-edge audit: **0/40** matches to the old triangle raw-start heuristic, which is why wider-convex contact routing remains explicitly unproven.

## Retained #493 proper-crossing convex evidence

The exact proper-crossing subset remains limited to two positive strictly convex paths with only proper segment intersections: no edge/point touching, collinear overlap or containment-only case. Seven hand-selected plus 32 deterministic random pairs produced **39/39 exact** raw ELF matches including reversed input order and 2/4/6-crossing topologies.

The broad negative mixed audits above explicitly demonstrate that this proper-only raw-start rule must not be extrapolated outside the independently proved #569/#575/#588/#582/#601/#608 mixed event classes.

## Retained Clipper1 / compiled Arachne evidence

Earlier direct compiled-oracle batches remain re-executed by #608, including offset input pruning and arithmetic, convex contour/hole offset semantics, orthogonal concave Execute, isolated positive V-notch and one-reflex negative cleanup, noninteracting NonZero ordering/winding, rectangle interactions and the represented convex-contact/final-union subsets above.

The suite also retains independent pinned compiled-BambuStudio process fixtures for normal two-wall and one-wall gates, non-speed and speed-graded overhang, partial `Alltop`, through-hole walls, QIDI `LoopNode`, QIDI circle-copy metadata behavior, final Arachne fill boundaries and a narrow-wedge topology case. These remain scoped fixture evidence; `process_arachne()` is **`implemented_unverified` as a whole**.

## Still not proven

For the current Clipper1/Arachne priority, independent or complete representation is still missing for:

- remaining **mixed proper-crossing + point-touch/collinear cases**: rounded/degenerated strict-max states beyond the proved separated-minimum endpoint-Y boundary, side-vertex touches, horizontal touch ordering and mixed collinear states;
- wider-convex zero-area/contact/collinear and fixup output-list state;
- multi-point or otherwise unrepresented `FixupOutPolygon()` cleanup;
- interacting positive/negative hole boundaries and deeper/multiple surviving hole hierarchy;
- more than two interacting final-union paths;
- multi-reflex/non-local non-orthogonal per-path cleanup, split/hole-producing non-orthogonal results and broader negative `pftNegative` execution;
- remaining prepared-outline final `unionNonZero()` cases where compatibility fallback can still introduce Clipper2 ordering/rounding differences;
- broader production/pathological `process_arachne()` geometry/config combinations.

Product-wide work also remains for later fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft algorithms, complete native G-code behavior, full project/profile persistence and source-enabled formats, scene/editor/Preview, Device/cloud/P2P/account/camera/HMS/firmware, calibration, desktop integration, full UI/localization/accessibility, hardware-in-the-loop behavior, runtime assets and release builds/installers.

## Next validation boundary

1. Derive exact raw-ELF/source scanline/output-list state for remaining **mixed proper-crossing + point-touch/collinear** cases beyond #569/#575/#588/#582/#601/#608: rounded/degenerated strict-max states beyond the separated-minimum endpoint-Y boundary, side-vertex, horizontal ordering, then mixed collinear cases. Do not widen the proper-only or mixed rebase rules without independent proof.
2. Keep wider-convex and multi-point/non-triangle fixup states on explicit compatibility fallback until their `OutRec`/`BuildResult()` behavior is independently proved.
3. Extend the final-union oracle matrix to **interacting holes**, then **more than two interacting paths**.
4. Continue generic/per-path Clipper1 execution only with exact source-order/rounding evidence.
5. Expand whole `process_arachne()` differentials after the remaining final-union seams are reduced.

## Completion truth

**Zero top-level parity gates are closed.** Individual source behaviors and exact compiled-oracle fixture scopes may be marked `parity_verified` only for their asserted contract. Broader modules remain incomplete until every required source path, integration boundary and reference test is covered.