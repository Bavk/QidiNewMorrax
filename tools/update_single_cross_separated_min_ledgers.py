from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one replacement, found {count}")
    p.write_text(text.replace(old, new, 1))

# HANDOFF
p = "docs/HANDOFF.md"
replace_once(p,
"""- code commit `827938693fc719ab1ac02f2c6d84b78f6e5e9468` (`ci: revalidate late multicross checkpoint`; functional tree from `3a100f821806671e6ca40dfa0e2961447395134e`);
- `.github/workflows/flutter-parity.yml` run `35072315131` (#601), job `104716457571`;
- Flutter `3.47.2`;
- Dart `3.13.2`;
- `flutter analyze` → **No issues found!**;
- `flutter test --reporter expanded` → **862/862 passed**;
- job conclusion → **success**.

The suite retains every earlier represented Classic/Arachne/geometry fixture and adds the independently proved late strict-maximum multi-crossing mixed point-touch class, its separated-minimum source-state boundary, exact Arachne zero-offset routing and explicit fallback boundaries for rounded-degenerate, side-vertex and horizontal neighbors.
""",
"""- code commit `5bbdb555af8ecf662a7b906daee39b4a6acafc90` (`fix: cover strict-max single-cross separated minima`);
- `.github/workflows/flutter-parity.yml` run `35090634147` (#608), job `104775845616`;
- Flutter `3.47.2`;
- Dart `3.13.2`;
- `flutter analyze` → **No issues found!**;
- `flutter test --reporter expanded` → **863/863 passed**;
- job conclusion → **success**.

The suite retains every earlier represented Classic/Arachne/geometry fixture and adds the independently proved late strict-maximum **single-crossing separated-minimum** boundary, exact all-rotation raw-path regression and Arachne zero-offset routing. Side-vertex, horizontal, mixed-collinear and other rounded/degenerated strict-max states beyond this proved endpoint-Y boundary remain explicit fallback.
""", "handoff checkpoint")
replace_once(p,
"### #569 / #575 / #588 / #582 / #601 mixed proper-crossing + point-touch extensions",
"### #569 / #575 / #588 / #582 / #601 / #608 mixed proper-crossing + point-touch extensions", "handoff heading")
replace_once(p,
"""PR CI #594 correctly caught that the first Dart extension still rejected the valid two-nonadjacent-minimum fixture. The final implementation relaxes that rebase guard only for the independently classified late strict-max multi-crossing boundary above. Final CI #601 is green at **862/862**.

The represented non-horizontal strict-max partition is therefore: #575 `<` with 1–4 proper crossings, #588 `==` with at least one proper crossing, and #582 + #601 `>` spanning the proved single- and multi-crossing states (source matrices cover proper-count 1–4). Horizontal touched edges, side-vertex touches, rounded-degenerate states and mixed-collinear states remain on compatibility fallback. A previously retained rounded strict-max fixture stays explicitly locked as fallback.
""",
"""PR CI #594 correctly caught that the first Dart extension still rejected the valid two-nonadjacent-minimum fixture. The final implementation relaxes that rebase guard only for the independently classified late strict-max multi-crossing boundary above. Final CI #601 is green at **862/862**.

#608 independently closes the corresponding **single-crossing separated-minimum** boundary that had remained as the historical "rounded strict-max" fallback. Direct pinned-source run `35090443828`, job `104775225066`, locks the fixed fixture at **18/18 exact complete raw paths** and adds **3,600** independent bases — 1,200 vertical, 1,200 positive-slope and 1,200 negative-slope touched edges — across all 18 rotation/input-order variants. The generated matrix matched **64800/64800 exact raw starts and 64800/64800 exact complete raw paths**. The implementation therefore extends the separated-minimum rebase permission to `properCount == 1` only for the same late `>` endpoint-Y source state. Flutter parity #608 is green at **863/863**.

The represented non-horizontal strict-max partition is therefore: #575 `<` with 1–4 proper crossings, #588 `==` with at least one proper crossing, and #582 + #601 + #608 `>` spanning the proved single- and multi-crossing states (source matrices cover proper-count 1–4), including independently proved separated-minimum boundaries for both single- and multi-crossing cases. Horizontal touched edges, side-vertex touches, mixed-collinear states and other rounded/degenerated strict-max states beyond this endpoint-Y boundary remain on compatibility fallback.
""", "handoff 608 evidence")
replace_once(p,
"- exactly two positive strict-convex triangles for mixed proper-crossing + single point-touch states in the #569 strict-minimum, #575 early ordered strict-maximum, #588 equal-Y strict-maximum, #582 late single-crossing strict-maximum and #601 late multi-crossing strict-maximum classes described above.",
"- exactly two positive strict-convex triangles for mixed proper-crossing + single point-touch states in the #569 strict-minimum, #575 early ordered strict-maximum, #588 equal-Y strict-maximum, #582 late single-crossing strict-maximum, #601 late multi-crossing strict-maximum and #608 single-cross separated-minimum classes described above.", "handoff represented bullet")
replace_once(p,
"1. continue **mixed proper-crossing + point-touch/collinear two-positive paths** beyond the #569/#575/#588/#582/#601 proved event classes: rounded/degenerated strict-max cases, side-vertex touches, horizontal touch ordering, then mixed collinear cases; use traced `AppendPolygon()` / `OutRec::Pts` source state rather than a geometric normalization heuristic;",
"1. continue **mixed proper-crossing + point-touch/collinear two-positive paths** beyond the #569/#575/#588/#582/#601/#608 proved event classes: remaining rounded/degenerated strict-max cases beyond the separated-minimum endpoint-Y boundary, then side-vertex touches, horizontal touch ordering and mixed collinear cases; use traced `AppendPolygon()` / `OutRec::Pts` source state rather than a geometric normalization heuristic;", "handoff next")
replace_once(p,
"- `3a100f821806671e6ca40dfa0e2961447395134e` — `fix: cover late multicross separated minima` (#601 functional tree, 862/862).",
"- `3a100f821806671e6ca40dfa0e2961447395134e` — `fix: cover late multicross separated minima` (#601 functional tree, 862/862);\n- `5bbdb555af8ecf662a7b906daee39b4a6acafc90` — `fix: cover strict-max single-cross separated minima` (#608, 863/863).", "handoff commits")

# MIGRATION_STATUS
p = "migration/MIGRATION_STATUS.md"
replace_once(p,
"""- Flutter **3.47.2**, Dart **3.13.2**;
- validated code `827938693fc719ab1ac02f2c6d84b78f6e5e9468` (functional tree from `3a100f821806671e6ca40dfa0e2961447395134e`);
- workflow `35072315131` (#601), job `104716457571`, conclusion **success**;
- `flutter analyze` — **No issues found!**;
- `flutter test --reporter expanded` — **862/862 passing**.

The current suite retains every earlier represented Classic/Arachne/geometry fixture, promotes the late strict-maximum multi-crossing mixed point-touch class and its separated-minimum source-state boundary into the exact helper, locks the complete pinned raw fixture across all cyclic rotations/input orders, and adds exact Arachne zero-offset routing while retaining rounded-degenerate, side and horizontal neighbors on fallback.
""",
"""- Flutter **3.47.2**, Dart **3.13.2**;
- validated code `5bbdb555af8ecf662a7b906daee39b4a6acafc90` (`fix: cover strict-max single-cross separated minima`);
- workflow `35090634147` (#608), job `104775845616`, conclusion **success**;
- `flutter analyze` — **No issues found!**;
- `flutter test --reporter expanded` — **863/863 passing**.

The current suite retains every earlier represented Classic/Arachne/geometry fixture and promotes the historical rounded strict-max fallback into the exact helper only for the independently proved late strict-maximum single-crossing separated-minimum endpoint-Y state. Its complete pinned raw fixture is locked across all cyclic rotations/input orders, with exact Arachne zero-offset routing; side, horizontal, mixed-collinear and other rounded/degenerated neighbors remain fallback.
""", "status checkpoint")
replace_once(p,
"- exactly two positive strict-convex triangles with proper crossings plus exactly one vertex↔strict-edge-interior point touch for the independently proved #569 strict minimum-Y class and non-horizontal strict-maximum ordering classes: #575 `<`, #588 `==`, #582 late `>` single-crossing and #601 late `>` multi-crossing, with the #601 separated-minimum boundary independently source-proved.",
"- exactly two positive strict-convex triangles with proper crossings plus exactly one vertex↔strict-edge-interior point touch for the independently proved #569 strict minimum-Y class and non-horizontal strict-maximum ordering classes: #575 `<`, #588 `==`, #582 late `>` single-crossing, #601 late `>` multi-crossing and #608 late `>` single-cross separated-minimum boundary.", "status represented")
replace_once(p,
"- #601 late strict-maximum multi-crossing extension: broad and independently targeted pinned-source matrices matched **216000/216000 exact raw starts** across proper-count 2–4; a separate separated-minimum boundary matrix matched **64800/64800 exact full raw paths** across vertical/positive/negative touched edges and all 18 rotation/input-order variants. Combined new source evidence is **280800/280800 raw-start checks**, including **64800/64800 full-path matches** on the rebase boundary.",
"- #601 late strict-maximum multi-crossing extension: broad and independently targeted pinned-source matrices matched **216000/216000 exact raw starts** across proper-count 2–4; a separate separated-minimum boundary matrix matched **64800/64800 exact full raw paths** across vertical/positive/negative touched edges and all 18 rotation/input-order variants. Combined new source evidence is **280800/280800 raw-start checks**, including **64800/64800 full-path matches** on the rebase boundary;\n- #608 late strict-maximum **single-crossing separated-minimum** boundary: direct pinned-source run `35090443828`, job `104775225066`; fixed historical fixture **18/18 exact full raw paths**, plus **3,600** independent bases split 1,200/1,200/1,200 across vertical/positive/negative touched edges × all 18 variants = **64800/64800 exact raw starts and 64800/64800 exact full raw paths**.", "status evidence")
replace_once(p,
"""The #575/#588/#582/#601 strict-max predicates partition the represented non-horizontal ordering seam. #575 owns `otherThird.y < min(ownerPrevious.y, ownerNext.y)` with 1–4 proper crossings. #588 owns equality with at least one proper crossing. #582 plus #601 own `otherThird.y > min(...)` across the proved single- and multi-crossing states, with source matrices spanning proper-count 1–4. The equal-Y and late-multicross audits establish two narrow cases where a valid raw contour may contain two **nonadjacent** global minimum-Y vertices; the helper permits the rightmost-minimum `BuildResult()` rebase only for those independently classified states. Horizontal strict-max touches, side-vertex touches, rounded-degenerate states and mixed collinear cases remain explicit fallback.
""",
"""The #575/#588/#582/#601/#608 strict-max predicates partition the represented non-horizontal ordering seam. #575 owns `otherThird.y < min(ownerPrevious.y, ownerNext.y)` with 1–4 proper crossings. #588 owns equality with at least one proper crossing. #582 plus #601 plus #608 own `otherThird.y > min(...)` across the proved single- and multi-crossing states, with source matrices spanning proper-count 1–4. The equal-Y and late separated-minimum audits establish narrow states where a valid raw contour may contain two **nonadjacent** global minimum-Y vertices; #601 independently proves that endpoint-Y boundary for multi-crossing and #608 independently proves it for single-crossing. The helper permits the rightmost-minimum `BuildResult()` rebase only for those classified states. Horizontal strict-max touches, side-vertex touches, mixed collinear cases and other rounded/degenerated strict-max states remain explicit fallback.
""", "status partition")
replace_once(p,
"| modified Clipper1 represented offset/Execute/NonZero subsets | `source_clipper1_*` | direct pinned ELF/source oracles + #601 CI | `parity_verified` (exact fixture scopes) | remaining mixed states, wider/multi-point fixup, interacting holes, >2 paths and broader Execute cleanup |",
"| modified Clipper1 represented offset/Execute/NonZero subsets | `source_clipper1_*` | direct pinned ELF/source oracles + #608 CI | `parity_verified` (exact fixture scopes) | remaining mixed states, wider/multi-point fixup, interacting holes, >2 paths and broader Execute cleanup |", "status summary")
replace_once(p,
"1. Continue **mixed proper-crossing + point-touch/collinear two-positive paths** beyond the #569/#575/#582/#588/#601 proved classes: rounded/degenerated strict-max cases, side-vertex touches, horizontal touch ordering, then mixed collinear cases. Start from traced `AppendPolygon()` / `OutRec::Pts` state rather than assuming the proper-only rebase rule.",
"1. Continue **mixed proper-crossing + point-touch/collinear two-positive paths** beyond the #569/#575/#582/#588/#601/#608 proved classes: remaining rounded/degenerated strict-max cases beyond the separated-minimum endpoint-Y boundary, then side-vertex touches, horizontal touch ordering and mixed collinear cases. Start from traced `AppendPolygon()` / `OutRec::Pts` state rather than assuming the proper-only rebase rule.", "status next")

# VALIDATION
p = "migration/VALIDATION.md"
replace_once(p,
"""GitHub Actions `.github/workflows/flutter-parity.yml` run `35072315131` (#601), job `104716457571`, executed code commit `827938693fc719ab1ac02f2c6d84b78f6e5e9468` (functional tree from `3a100f821806671e6ca40dfa0e2961447395134e`) and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **862/862 tests passed**;
- job conclusion — **success**.

The suite re-executes all earlier represented Classic/Arachne/geometry/Boost/Clipper fixtures and adds the late strict-maximum multi-crossing mixed point-touch class, the independently proved separated-minimum rebase boundary, exact Arachne zero-offset routing and explicit conservative rejection boundaries for rounded-degenerate, side-vertex and horizontal neighbors.
""",
"""GitHub Actions `.github/workflows/flutter-parity.yml` run `35090634147` (#608), job `104775845616`, executed code commit `5bbdb555af8ecf662a7b906daee39b4a6acafc90` and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **863/863 tests passed**;
- job conclusion — **success**.

The suite re-executes all earlier represented Classic/Arachne/geometry/Boost/Clipper fixtures and adds the independently proved late strict-maximum single-crossing separated-minimum boundary, exact all-rotation raw-path regression and Arachne zero-offset routing while retaining side-vertex, horizontal, mixed-collinear and other rounded/degenerated strict-max states on fallback.
""", "validation checkpoint")
marker = "## #601 late strict-maximum multi-crossing mixed point-touch oracle\n"
section = """## #608 late strict-maximum single-crossing separated-minimum boundary

`SourceClipper1TwoConvexMixedPointUnion2` now independently represents the retained historical "rounded strict-max" fixture as a precise late strict-maximum **single-crossing separated-minimum** source state, rather than treating that fixture as a generic rounded-degeneracy class.

Represented #608 state remains bounded to exactly two positive strict-convex triangles, exactly one unique vertex↔strict-edge-interior point touch, a strict maximum-Y touching owner vertex, a non-horizontal touched edge, exactly one proper boundary crossing, no second touch and no nonzero collinear overlap. It additionally requires `otherThird.y > min(ownerPrevious.y, ownerNext.y)` and one touched-edge endpoint at exactly that earlier owner-neighbor minimum Y, yielding the proved two-nonadjacent-minimum raw contour boundary.

Direct pinned-source Clipper1 run `35090443828`, job `104775225066`, compiled BambuStudio commit `f2b55a5a83f266cf56e06c7943a81a08bebb7fad` and produced:

- the historical fixed fixture across all 3×3 cyclic rotations and both AddPath/input orders: **18/18 exact complete raw paths**;
- **3,600** independently generated single-crossing bases: 1,200 vertical, 1,200 positive-slope and 1,200 negative-slope touched edges;
- all 18 rotation/input-order variants per generated base: **64800/64800 exact raw starts and 64800/64800 exact complete raw paths**.

This evidence is independent of #601's multi-crossing separated-minimum batch. Together they prove the same endpoint-Y separated-minimum rebase boundary for proper-count 1–4 across the generated matrices. The Dart change only widens `_isLateStrictMaximumSeparatedMinimumBoundary()` from `properCount >= 2` to `properCount >= 1`; all other state predicates and rebase safety checks remain unchanged. The historical fallback regression is now an exact full-path regression across all 18 variants, and Arachne zero-offset routing is locked separately.

Flutter parity #608 (`35090634147`, job `104775845616`) is green on Flutter **3.47.2** / Dart **3.13.2**, analyzer clean, **863/863** tests passing.

This does **not** prove arbitrary rounded intersection degeneracies. Remaining rounded/degenerated strict-max states beyond the separated-minimum endpoint-Y boundary, side-vertex touches, horizontal touch ordering and mixed-collinear cases remain fallback.

"""
path = Path(p)
text = path.read_text()
if text.count(marker) != 1:
    raise RuntimeError("validation section marker")
path.write_text(text.replace(marker, section + marker, 1))
replace_once(p,
"Together, #582 and #601 cover the proved late `>` strict-max ordering states from single crossing through the generated multi-crossing matrix (proper-count 1–4). Horizontal touched edges, side-vertex touches, rounded/degenerated strict-max states and mixed-collinear cases remain fallback.",
"Together, #582, #601 and #608 cover the proved late `>` strict-max ordering states from single crossing through the generated multi-crossing matrix (proper-count 1–4), including independently proved separated-minimum endpoint-Y boundaries for both single- and multi-crossing cases. Horizontal touched edges, side-vertex touches, mixed-collinear cases and other rounded/degenerated strict-max states remain fallback.", "validation 601 conclusion")
replace_once(p,
"- #582 + #601: `otherThird.y > min(ownerPrevious.y, ownerNext.y)`, with the source matrices spanning the proved single- and multi-crossing states (proper-count 1–4).\n\nHorizontal touched edges, side-vertex touches, rounded/degenerated strict-max states and mixed-collinear cases remain fallback.",
"- #582 + #601 + #608: `otherThird.y > min(ownerPrevious.y, ownerNext.y)`, with the source matrices spanning the proved single- and multi-crossing states (proper-count 1–4), including the independently proved single- and multi-crossing separated-minimum endpoint-Y boundaries.\n\nHorizontal touched edges, side-vertex touches, mixed-collinear cases and other rounded/degenerated strict-max states remain fallback.", "validation partition")
replace_once(p,
"""### Corrected rounded-degeneracy regression

The first test commit for the #582 batch briefly treated a previously retained rounded strict-max fixture as newly represented. CI #581 correctly failed that assertion because the exact helper rejects the case later in its raw boundary/rebase checks. The fixture was restored to an explicit fallback regression in commit `83665f5ab62c70275a415e6d46ea6b0ac903b7e3`. The independent **64800/64800** #582 oracle matrix did not include or depend on that rounded-degeneracy case and remained unchanged. Final #582 CI was green, and #588 continues to retain that fixture as fallback.
""",
"""### Historical rounded-degeneracy regression, now classified by #608

The first test commit for the #582 batch briefly treated the retained strict-max fixture as newly represented. CI #581 correctly failed that assertion because the exact helper still rejected its two-nonadjacent-minimum raw state, so commit `83665f5ab62c70275a415e6d46ea6b0ac903b7e3` restored it to fallback. The independent **64800/64800** #582 oracle matrix did not include that boundary. #608 later isolated the actual source condition — a single-crossing separated-minimum endpoint-Y state — and independently proved it with **64800/64800 exact complete raw paths** plus **18/18** fixed-fixture variants. The fixture is therefore represented now for that exact source-state reason, not by a generic rounded-degeneracy heuristic.
""", "validation historical fallback")
replace_once(p,
"The exact #575/#588/#582/#601 predicates must not be widened from slope or extrema alone.",
"The exact #575/#588/#582/#601/#608 predicates must not be widened from slope or extrema alone.", "validation weak hypothesis")
replace_once(p,
"Earlier runtime tracing established that touch-time `AppendPolygon()` / `OutRec::Pts` lifecycle is acceptance-relevant. The #575/#588/#582/#601 results refine that conclusion: append state alone is not a static classifier.",
"Earlier runtime tracing established that touch-time `AppendPolygon()` / `OutRec::Pts` lifecycle is acceptance-relevant. The #575/#588/#582/#601/#608 results refine that conclusion: append state alone is not a static classifier.", "validation runtime")
replace_once(p,
"outside the independently proved #569/#575/#588/#582/#601 mixed event classes.",
"outside the independently proved #569/#575/#588/#582/#601/#608 mixed event classes.", "validation proper warning")
replace_once(p,
"Earlier direct compiled-oracle batches remain re-executed by #601,",
"Earlier direct compiled-oracle batches remain re-executed by #608,", "validation retained")
replace_once(p,
"- remaining **mixed proper-crossing + point-touch/collinear cases**: rounded/degenerated strict-max states, side-vertex touches, horizontal touch ordering and mixed collinear states;",
"- remaining **mixed proper-crossing + point-touch/collinear cases**: rounded/degenerated strict-max states beyond the proved separated-minimum endpoint-Y boundary, side-vertex touches, horizontal touch ordering and mixed collinear states;", "validation still open")
replace_once(p,
"1. Derive exact raw-ELF/source scanline/output-list state for remaining **mixed proper-crossing + point-touch/collinear** cases beyond #569/#575/#588/#582/#601: rounded/degenerated strict-max, side-vertex, horizontal ordering, then mixed collinear cases. Do not widen the proper-only or mixed rebase rules without independent proof.",
"1. Derive exact raw-ELF/source scanline/output-list state for remaining **mixed proper-crossing + point-touch/collinear** cases beyond #569/#575/#588/#582/#601/#608: rounded/degenerated strict-max states beyond the separated-minimum endpoint-Y boundary, side-vertex, horizontal ordering, then mixed collinear cases. Do not widen the proper-only or mixed rebase rules without independent proof.", "validation next")

# TRACEABILITY
p = "migration/TRACEABILITY.md"
replace_once(p,
"""- code: `827938693fc719ab1ac02f2c6d84b78f6e5e9468` (functional tree from `3a100f821806671e6ca40dfa0e2961447395134e`);
- workflow: `.github/workflows/flutter-parity.yml` run `35072315131` (#601), job `104716457571`;
- Flutter `3.47.2`, Dart `3.13.2`;
- analyzer: **No issues found**;
- tests: **862/862 passed**;
- conclusion: **success**.
""",
"""- code: `5bbdb555af8ecf662a7b906daee39b4a6acafc90`;
- workflow: `.github/workflows/flutter-parity.yml` run `35090634147` (#608), job `104775845616`;
- Flutter `3.47.2`, Dart `3.13.2`;
- analyzer: **No issues found**;
- tests: **863/863 passed**;
- conclusion: **success**.
""", "trace checkpoint")
replace_once(p,
"- **#601 / `82793869...` (functional `3a100f82...`): late strict-maximum multi-crossing mixed point-touch extension and separated-minimum source-state rebase, 862/862.**",
"- #601 / `82793869...` (functional `3a100f82...`): late strict-maximum multi-crossing mixed point-touch extension and separated-minimum source-state rebase, 862/862;\n- **#608 / `5bbdb555...`: late strict-maximum single-crossing separated-minimum boundary, 863/863.**", "trace milestone")
replace_once(p,
"""| two positive strict-convex triangles with proper crossings + exactly one vertex↔strict-edge point touch in the #569 strict-minimum and represented non-horizontal strict-maximum ordering classes (#575 `<`, #588 `==`, #582/#601 late `>`) | `SourceClipper1TwoConvexMixedPointUnion2` | #569 **39600/39600**, #575 **72000/72000**, #582 **64800/64800** exact full raw paths; #588 **54000/54000** raw-start matches plus fixed full-path fixture; #601 adds **216000/216000** generic late-multicross raw starts plus **64800/64800 exact full raw paths** on the separated-minimum boundary | `parity_verified` (scoped) | Horizontal, side-vertex, rounded-degenerate and mixed-collinear output-list states remain open. |
| Arachne exact offset/final-union routing | `SourceArachneWallToolPathsPrepareExact2` | direct helper tests + route tests through #601 | `parity_verified` for represented branches | Remaining mixed states, interacting holes, >2 paths and generic boolean cases still fall back. |
""",
"""| two positive strict-convex triangles with proper crossings + exactly one vertex↔strict-edge point touch in the #569 strict-minimum and represented non-horizontal strict-maximum ordering classes (#575 `<`, #588 `==`, #582/#601/#608 late `>`) | `SourceClipper1TwoConvexMixedPointUnion2` | #569 **39600/39600**, #575 **72000/72000**, #582 **64800/64800** exact full raw paths; #588 **54000/54000** raw-start matches plus fixed full-path fixture; #601 adds **216000/216000** generic late-multicross raw starts plus **64800/64800 exact full raw paths** on the multi-cross separated-minimum boundary; #608 adds **64800/64800 exact full raw paths** plus **18/18** fixed variants for the independent single-cross separated-minimum boundary | `parity_verified` (scoped) | Horizontal, side-vertex, mixed-collinear and other rounded/degenerated output-list states remain open. |
| Arachne exact offset/final-union routing | `SourceArachneWallToolPathsPrepareExact2` | direct helper tests + route tests through #608 | `parity_verified` for represented branches | Remaining mixed states, interacting holes, >2 paths and generic boolean cases still fall back. |
""", "trace rows")
replace_once(p,
"""The mixed point helper remains explicitly source-event bounded. #569 proves the strict-minimum touching vertex class with **39600/39600** raw paths. #575 proves an early strict-max class with **72000/72000** full raw paths when the touched edge is non-horizontal and `otherThird.y < min(ownerPrevious.y, ownerNext.y)`, spanning 1–4 proper crossings. #588 proves the equal-Y boundary with **54000/54000** raw-start-rule matches plus a fixed complete-path regression. #582 proves the late `>` single-crossing class with **64800/64800** exact full raw paths. #601 extends the same late `>` class to multi-crossing states with **216000/216000** independent generic/targeted raw-start matches and a separate **64800/64800 exact full-path** separated-minimum boundary matrix; together the `>` source matrices span proper-count 1–4.

The #588 and #601 audits establish two independently classified cases where a valid output may have two nonadjacent global minimum-Y vertices. `SourceClipper1TwoConvexMixedPointUnion2` relaxes its old adjacent-minima rebase guard only for those proved states and still chooses the source rightmost-minimum anchor. Horizontal strict-max touches, side-vertex touches, rounded-degenerate cases and mixed collinear states stay fallback.
""",
"""The mixed point helper remains explicitly source-event bounded. #569 proves the strict-minimum touching vertex class with **39600/39600** raw paths. #575 proves an early strict-max class with **72000/72000** full raw paths when the touched edge is non-horizontal and `otherThird.y < min(ownerPrevious.y, ownerNext.y)`, spanning 1–4 proper crossings. #588 proves the equal-Y boundary with **54000/54000** raw-start-rule matches plus a fixed complete-path regression. #582 proves the late `>` single-crossing class with **64800/64800** exact full raw paths. #601 extends the same late `>` class to multi-crossing states with **216000/216000** independent generic/targeted raw-start matches and a separate **64800/64800 exact full-path** multi-cross separated-minimum boundary matrix. #608 independently proves the matching single-cross separated-minimum endpoint-Y boundary with **64800/64800 exact full raw paths** plus **18/18** fixed variants; together the `>` source matrices span proper-count 1–4.

The #588, #601 and #608 audits establish independently classified states where a valid output may have two nonadjacent global minimum-Y vertices. `SourceClipper1TwoConvexMixedPointUnion2` relaxes its old adjacent-minima rebase guard only for those proved states and still chooses the source rightmost-minimum anchor. Horizontal strict-max touches, side-vertex touches, mixed collinear states and other rounded/degenerated cases stay fallback.
""", "trace prose")
replace_once(p,
"1. Continue **mixed proper-crossing + point-touch/collinear degeneracies** beyond the #569/#575/#588/#582/#601 event classes: rounded/degenerated strict-max cases, side-vertex touches, horizontal ordering, then mixed collinear states. Use exact traced output-list state; do not reuse the proper-crossing rebase heuristic without proof.",
"1. Continue **mixed proper-crossing + point-touch/collinear degeneracies** beyond the #569/#575/#588/#582/#601/#608 event classes: remaining rounded/degenerated strict-max cases beyond the separated-minimum endpoint-Y boundary, then side-vertex touches, horizontal ordering and mixed collinear states. Use exact traced output-list state; do not reuse the proper-crossing rebase heuristic without proof.", "trace next")
