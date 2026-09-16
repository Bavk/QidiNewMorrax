from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f'missing replacement target: {label}')
    return text.replace(old, new, 1)


# HANDOFF
path = Path('docs/HANDOFF.md')
text = path.read_text()
text = replace_once(text, """- code commit `81beaaed952b67843ae63ff114943673304a4b0c` (`fix: preserve equal-y mixed raw start state`);
- `.github/workflows/flutter-parity.yml` run `35069180391` (#588), job `104706390860`;
- Flutter `3.47.2`;
- Dart `3.13.2`;
- `flutter analyze` → **No issues found!**;
- `flutter test --reporter expanded` → **861/861 passed**;
- job conclusion → **success**.

The suite retains every earlier represented Classic/Arachne/geometry fixture and adds the independently proved strict-maximum equal-Y mixed point-touch boundary, exact Arachne zero-offset routing and explicit fallback boundaries for late multi-crossing, rounded-degenerate, side-vertex and horizontal neighbors.
""", """- code commit `827938693fc719ab1ac02f2c6d84b78f6e5e9468` (`ci: revalidate late multicross checkpoint`; functional tree from `3a100f821806671e6ca40dfa0e2961447395134e`);
- `.github/workflows/flutter-parity.yml` run `35072315131` (#601), job `104716457571`;
- Flutter `3.47.2`;
- Dart `3.13.2`;
- `flutter analyze` → **No issues found!**;
- `flutter test --reporter expanded` → **862/862 passed**;
- job conclusion → **success**.

The suite retains every earlier represented Classic/Arachne/geometry fixture and adds the independently proved late strict-maximum multi-crossing mixed point-touch class, its separated-minimum source-state boundary, exact Arachne zero-offset routing and explicit fallback boundaries for rounded-degenerate, side-vertex and horizontal neighbors.
""", 'handoff checkpoint')
text = text.replace('### #569 / #575 / #588 / #582 mixed proper-crossing + point-touch extensions', '### #569 / #575 / #588 / #582 / #601 mixed proper-crossing + point-touch extensions')
text = replace_once(text, """#582 independently represents the strict-maximum class on the later side of that boundary. The touched edge is non-horizontal, there is **exactly one proper crossing**, and the touched-edge triangle's third vertex is strictly later than the earlier owner neighbor: `otherThird.y > min(ownerPrevious.y, ownerNext.y)`. Its matrix matched **64800/64800 exact full raw result paths** from 3,600 independently generated bases — 1,200 vertical, 1,200 positive-slope and 1,200 negative-slope touched edges — across all 3×3 rotations and both input/AddPath orders.

The represented non-horizontal strict-max partition is therefore: #575 `<` with 1–4 proper crossings, #588 `==` with at least one proper crossing, and #582 `>` with exactly one proper crossing. Horizontal touched edges, late strict-max states with multiple proper crossings, side-vertex touches, rounded-degenerate states and mixed-collinear states remain on compatibility fallback. A previously retained rounded strict-max fixture stays explicitly locked as fallback.
""", """#582 independently represents the strict-maximum class on the later side of that boundary. The touched edge is non-horizontal, there is **exactly one proper crossing**, and the touched-edge triangle's third vertex is strictly later than the earlier owner neighbor: `otherThird.y > min(ownerPrevious.y, ownerNext.y)`. Its matrix matched **64800/64800 exact full raw result paths** from 3,600 independently generated bases — 1,200 vertical, 1,200 positive-slope and 1,200 negative-slope touched edges — across all 3×3 rotations and both input/AddPath orders.

#601 extends that same late `>` source-event class to **multiple proper crossings**. Two independent pinned-source matrices matched **216000/216000 exact raw starts** across proper-count 2–4; the second matrix contributes 36,000 vertical, 36,000 positive-slope and 36,000 negative-slope touched-edge executions. A third targeted source matrix proves the separated-minimum boundary exposed by the fixed three-crossing regression: **64800/64800 exact full raw paths** across 3,600 bases where one touched-edge endpoint shares the earlier owner-neighbor minimum Y, again covering vertical/positive/negative touched edges and all 18 rotation/input-order variants. Combined new #601 source evidence is **280800/280800 raw-start checks**, including **64800/64800 complete raw-path matches** on the separated-minimum boundary.

PR CI #594 correctly caught that the first Dart extension still rejected the valid two-nonadjacent-minimum fixture. The final implementation relaxes that rebase guard only for the independently classified late strict-max multi-crossing boundary above. Final CI #601 is green at **862/862**.

The represented non-horizontal strict-max partition is therefore: #575 `<` with 1–4 proper crossings, #588 `==` with at least one proper crossing, and #582 + #601 `>` spanning the proved single- and multi-crossing states (source matrices cover proper-count 1–4). Horizontal touched edges, side-vertex touches, rounded-degenerate states and mixed-collinear states remain on compatibility fallback. A previously retained rounded strict-max fixture stays explicitly locked as fallback.
""", 'handoff mixed #601')
text = replace_once(text, """- exactly two positive strict-convex triangles for mixed proper-crossing + single point-touch states in the #569 strict-minimum, #575 early ordered strict-maximum, #588 equal-Y strict-maximum and #582 late single-crossing strict-maximum classes described above.
""", """- exactly two positive strict-convex triangles for mixed proper-crossing + single point-touch states in the #569 strict-minimum, #575 early ordered strict-maximum, #588 equal-Y strict-maximum, #582 late single-crossing strict-maximum and #601 late multi-crossing strict-maximum classes described above.
""", 'handoff clipper bullet')
text = replace_once(text, """1. continue **mixed proper-crossing + point-touch/collinear two-positive paths** beyond the #569/#575/#588/#582 proved event classes: strict-maximum late states with multiple proper crossings, rounded/degenerated strict-max cases, side-vertex touches, horizontal touch ordering, then mixed collinear cases; use traced `AppendPolygon()` / `OutRec::Pts` source state rather than a geometric normalization heuristic;
""", """1. continue **mixed proper-crossing + point-touch/collinear two-positive paths** beyond the #569/#575/#588/#582/#601 proved event classes: rounded/degenerated strict-max cases, side-vertex touches, horizontal touch ordering, then mixed collinear cases; use traced `AppendPolygon()` / `OutRec::Pts` source state rather than a geometric normalization heuristic;
""", 'handoff priority')
text = replace_once(text, """- `81beaaed952b67843ae63ff114943673304a4b0c` — `fix: preserve equal-y mixed raw start state` (#588, 861/861).
""", """- `81beaaed952b67843ae63ff114943673304a4b0c` — `fix: preserve equal-y mixed raw start state` (#588, 861/861);
- `db140fdd191d3432e38284a5652a7d13602c3d1d` — `feat: extend late strict-max multicross joins`;
- `3a100f821806671e6ca40dfa0e2961447395134e` — `fix: cover late multicross separated minima` (#601 functional tree, 862/862).
""", 'handoff latest commits')
path.write_text(text)


# MIGRATION_STATUS
path = Path('migration/MIGRATION_STATUS.md')
text = path.read_text()
text = replace_once(text, """- Flutter **3.47.2**, Dart **3.13.2**;
- validated code `81beaaed952b67843ae63ff114943673304a4b0c` (`fix: preserve equal-y mixed raw start state`);
- workflow `35069180391` (#588), job `104706390860`, conclusion **success**;
- `flutter analyze` — **No issues found!**;
- `flutter test --reporter expanded` — **861/861 passing**.

The current suite retains every earlier represented Classic/Arachne/geometry fixture, promotes the strict-maximum equal-Y mixed point-touch boundary into the exact helper, locks its complete pinned raw fixture across all cyclic rotations/input orders, and adds exact Arachne zero-offset routing while retaining late multi-crossing, rounded-degenerate, side and horizontal neighbors on fallback.
""", """- Flutter **3.47.2**, Dart **3.13.2**;
- validated code `827938693fc719ab1ac02f2c6d84b78f6e5e9468` (functional tree from `3a100f821806671e6ca40dfa0e2961447395134e`);
- workflow `35072315131` (#601), job `104716457571`, conclusion **success**;
- `flutter analyze` — **No issues found!**;
- `flutter test --reporter expanded` — **862/862 passing**.

The current suite retains every earlier represented Classic/Arachne/geometry fixture, promotes the late strict-maximum multi-crossing mixed point-touch class and its separated-minimum source-state boundary into the exact helper, locks the complete pinned raw fixture across all cyclic rotations/input orders, and adds exact Arachne zero-offset routing while retaining rounded-degenerate, side and horizontal neighbors on fallback.
""", 'status checkpoint')
text = replace_once(text, """- exactly two positive strict-convex triangles with proper crossings plus exactly one vertex↔strict-edge-interior point touch for four independently proved source-event classes: #569 strict minimum-Y owner vertex, #575 ordered strict maximum-Y owner vertex with `otherThird.y < min(ownerNeighbor.y)`, #582 late strict maximum-Y single-crossing state with `otherThird.y > min(ownerNeighbor.y)`, and #588 the non-horizontal strict-maximum equal-Y boundary `otherThird.y == min(ownerNeighbor.y)`.
""", """- exactly two positive strict-convex triangles with proper crossings plus exactly one vertex↔strict-edge-interior point touch for the independently proved #569 strict minimum-Y class and non-horizontal strict-maximum ordering classes: #575 `<`, #588 `==`, #582 late `>` single-crossing and #601 late `>` multi-crossing, with the #601 separated-minimum boundary independently source-proved.
""", 'status class bullet')
text = replace_once(text, """- #588 strict-maximum equal-Y mixed point-touch boundary: direct compilation of pinned BambuStudio Clipper1 source in Actions run `35068502159`, job `104704216962`, generated **3,000** independent bases (528 one-crossing and 2,472 multi-crossing), then all 3×3 rotations × both input/AddPath orders; **54000/54000** raw results matched the source `BuildResult()` start rule, while the committed fixed fixture locks the complete raw path for all 18 rotation/order variants.

The #575/#588/#582 strict-max predicates now partition the represented non-horizontal ordering seam. #575 owns `otherThird.y < min(ownerPrevious.y, ownerNext.y)` with 1–4 proper crossings. #588 owns equality with at least one proper crossing. #582 owns `otherThird.y > min(...)` only when there is exactly one proper crossing. The equal-Y audit also exposed that the valid raw contour may contain two **nonadjacent** global minimum-Y vertices; the helper therefore permits the proven rightmost-minimum `BuildResult()` rebase only for the independently classified equal-Y state. Horizontal strict-max touches, late strict-max states with multiple proper crossings, side-vertex touches, rounded-degenerate states and mixed collinear cases remain explicit fallback.
""", """- #588 strict-maximum equal-Y mixed point-touch boundary: direct compilation of pinned BambuStudio Clipper1 source in Actions run `35068502159`, job `104704216962`, generated **3,000** independent bases (528 one-crossing and 2,472 multi-crossing), then all 3×3 rotations × both input/AddPath orders; **54000/54000** raw results matched the source `BuildResult()` start rule, while the committed fixed fixture locks the complete raw path for all 18 rotation/order variants;
- #601 late strict-maximum multi-crossing extension: broad and independently targeted pinned-source matrices matched **216000/216000 exact raw starts** across proper-count 2–4; a separate separated-minimum boundary matrix matched **64800/64800 exact full raw paths** across vertical/positive/negative touched edges and all 18 rotation/input-order variants. Combined new source evidence is **280800/280800 raw-start checks**, including **64800/64800 full-path matches** on the rebase boundary.

The #575/#588/#582/#601 strict-max predicates partition the represented non-horizontal ordering seam. #575 owns `otherThird.y < min(ownerPrevious.y, ownerNext.y)` with 1–4 proper crossings. #588 owns equality with at least one proper crossing. #582 plus #601 own `otherThird.y > min(...)` across the proved single- and multi-crossing states, with source matrices spanning proper-count 1–4. The equal-Y and late-multicross audits establish two narrow cases where a valid raw contour may contain two **nonadjacent** global minimum-Y vertices; the helper permits the rightmost-minimum `BuildResult()` rebase only for those independently classified states. Horizontal strict-max touches, side-vertex touches, rounded-degenerate states and mixed collinear cases remain explicit fallback.
""", 'status evidence + partition')
text = text.replace('direct pinned ELF/source oracles + #588 CI', 'direct pinned ELF/source oracles + #601 CI')
text = replace_once(text, """1. Continue **mixed proper-crossing + point-touch/collinear two-positive paths** beyond the #569/#575/#582/#588 proved classes: late strict-max multi-crossing states, rounded/degenerated strict-max cases, side-vertex touches, horizontal touch ordering, then mixed collinear cases. Start from traced `AppendPolygon()` / `OutRec::Pts` state rather than assuming the proper-only rebase rule.
""", """1. Continue **mixed proper-crossing + point-touch/collinear two-positive paths** beyond the #569/#575/#582/#588/#601 proved classes: rounded/degenerated strict-max cases, side-vertex touches, horizontal touch ordering, then mixed collinear cases. Start from traced `AppendPolygon()` / `OutRec::Pts` state rather than assuming the proper-only rebase rule.
""", 'status priority')
path.write_text(text)


# VALIDATION
path = Path('migration/VALIDATION.md')
text = path.read_text()
text = replace_once(text, """GitHub Actions `.github/workflows/flutter-parity.yml` run `35069180391` (#588), job `104706390860`, executed code commit `81beaaed952b67843ae63ff114943673304a4b0c` and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **861/861 tests passed**;
- job conclusion — **success**.

The suite re-executes all earlier represented Classic/Arachne/geometry/Boost/Clipper fixtures and adds the strict-maximum equal-Y mixed point-touch boundary, exact Arachne zero-offset routing and explicit conservative rejection boundaries for late multi-crossing, rounded-degenerate, side-vertex and horizontal neighbors.
""", """GitHub Actions `.github/workflows/flutter-parity.yml` run `35072315131` (#601), job `104716457571`, executed code commit `827938693fc719ab1ac02f2c6d84b78f6e5e9468` (functional tree from `3a100f821806671e6ca40dfa0e2961447395134e`) and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **862/862 tests passed**;
- job conclusion — **success**.

The suite re-executes all earlier represented Classic/Arachne/geometry/Boost/Clipper fixtures and adds the late strict-maximum multi-crossing mixed point-touch class, the independently proved separated-minimum rebase boundary, exact Arachne zero-offset routing and explicit conservative rejection boundaries for rounded-degenerate, side-vertex and horizontal neighbors.
""", 'validation checkpoint')
section = """## #601 late strict-maximum multi-crossing mixed point-touch oracle

`SourceClipper1TwoConvexMixedPointUnion2` now extends the non-horizontal late strict-maximum `otherThird.y > min(ownerPrevious.y, ownerNext.y)` class beyond the #582 single-crossing state.

Represented #601 state remains deliberately bounded to exactly two positive strict-convex triangles, exactly one unique vertex↔strict-edge-interior point touch, a strict maximum-Y touching owner vertex, a non-horizontal touched edge, no second touch and no nonzero collinear overlap. The new evidence covers the multiple-proper-crossing branch (proper-count 2–4 in the generated source matrices).

Three independent pinned-source batches were executed against BambuStudio commit `f2b55a5a83f266cf56e06c7943a81a08bebb7fad`:

- broad run `35070969892`, job `104712127182`: **6,000** independent bases × all 3×3 cyclic rotations × both AddPath orders = **108000/108000 exact raw-start matches**, spanning proper-count 2–4;
- independently targeted slope run `35071087252`, job `104712499829`: another **108000/108000 exact raw-start matches**, split into **36,000 vertical**, **36,000 positive-slope** and **36,000 negative-slope** touched-edge executions, again spanning proper-count 2–4;
- separated-minimum boundary run `35072113339`, job `104715791685`: **3,600** independently generated bases × all 18 rotation/input-order variants = **64800/64800 exact raw starts and 64800/64800 exact complete raw paths**. This batch targets the source state where one touched-edge endpoint shares the earlier owner-neighbor minimum Y and the final contour has two nonadjacent global minima.

Combined new #601 evidence is **280800/280800 raw-start checks**, with **64800/64800 full raw-path matches** on the independently isolated separated-minimum boundary.

The first Dart extension intentionally retained the old separated-minimum safety guard. PR CI #594 (`35071653958`, job `104714339008`) kept analyzer green but failed the all-rotations regression, correctly exposing that the fixed three-crossing source path has two nonadjacent minima. The final implementation adds `_isLateStrictMaximumSeparatedMinimumBoundary()` and relaxes the rebase guard only for that independently proved source state. Final CI #601 (`35072315131`, job `104716457571`) is green at **862/862**.

Together, #582 and #601 cover the proved late `>` strict-max ordering states from single crossing through the generated multi-crossing matrix (proper-count 1–4). Horizontal touched edges, side-vertex touches, rounded/degenerated strict-max states and mixed-collinear cases remain fallback.

"""
marker = '## #588 strict-maximum equal-Y mixed point-touch boundary\n'
if marker not in text:
    raise RuntimeError('missing validation #588 marker')
text = text.replace(marker, section + marker, 1)
text = text.replace('#575/#588/#582', '#575/#588/#582/#601')
text = replace_once(text, """The independently proved non-horizontal strict-maximum partition is now:

- #575: `otherThird.y < min(ownerPrevious.y, ownerNext.y)`, with its matrix spanning 1–4 proper crossings;
- #588: `otherThird.y == min(ownerPrevious.y, ownerNext.y)`, with at least one proper crossing;
- #582: `otherThird.y > min(ownerPrevious.y, ownerNext.y)`, with **exactly one** proper crossing.

Horizontal touched edges, late strict-max states with multiple proper crossings, side-vertex touches, rounded/degenerated strict-max states and mixed-collinear cases remain fallback.
""", """The independently proved non-horizontal strict-maximum partition is now:

- #575: `otherThird.y < min(ownerPrevious.y, ownerNext.y)`, with its matrix spanning 1–4 proper crossings;
- #588: `otherThird.y == min(ownerPrevious.y, ownerNext.y)`, with at least one proper crossing;
- #582 + #601: `otherThird.y > min(ownerPrevious.y, ownerNext.y)`, with the source matrices spanning the proved single- and multi-crossing states (proper-count 1–4).

Horizontal touched edges, side-vertex touches, rounded/degenerated strict-max states and mixed-collinear cases remain fallback.
""", 'validation partition')
text = text.replace('Earlier direct compiled-oracle batches remain re-executed by #588', 'Earlier direct compiled-oracle batches remain re-executed by #601')
text = replace_once(text, """- remaining **mixed proper-crossing + point-touch/collinear cases**: late strict-max states with multiple proper crossings, rounded/degenerated strict-max states, side-vertex touches, horizontal touch ordering and mixed collinear states;
""", """- remaining **mixed proper-crossing + point-touch/collinear cases**: rounded/degenerated strict-max states, side-vertex touches, horizontal touch ordering and mixed collinear states;
""", 'validation still open')
text = replace_once(text, """1. Derive exact raw-ELF/source scanline/output-list state for remaining **mixed proper-crossing + point-touch/collinear** cases beyond #569/#575/#588/#582: late strict-max multi-crossing, rounded/degenerated strict-max, side-vertex, horizontal ordering, then mixed collinear cases. Do not widen the proper-only or mixed rebase rules without independent proof.
""", """1. Derive exact raw-ELF/source scanline/output-list state for remaining **mixed proper-crossing + point-touch/collinear** cases beyond #569/#575/#588/#582/#601: rounded/degenerated strict-max, side-vertex, horizontal ordering, then mixed collinear cases. Do not widen the proper-only or mixed rebase rules without independent proof.
""", 'validation next')
path.write_text(text)


# TRACEABILITY
path = Path('migration/TRACEABILITY.md')
text = path.read_text()
text = replace_once(text, """- code: `81beaaed952b67843ae63ff114943673304a4b0c`;
- workflow: `.github/workflows/flutter-parity.yml` run `35069180391` (#588), job `104706390860`;
- Flutter `3.47.2`, Dart `3.13.2`;
- analyzer: **No issues found**;
- tests: **861/861 passed**;
- conclusion: **success**.
""", """- code: `827938693fc719ab1ac02f2c6d84b78f6e5e9468` (functional tree from `3a100f821806671e6ca40dfa0e2961447395134e`);
- workflow: `.github/workflows/flutter-parity.yml` run `35072315131` (#601), job `104716457571`;
- Flutter `3.47.2`, Dart `3.13.2`;
- analyzer: **No issues found**;
- tests: **862/862 passed**;
- conclusion: **success**.
""", 'trace checkpoint')
text = replace_once(text, """- **#588 / `81beaaed...`: strict-maximum equal-Y mixed point-touch boundary and source-state rebase, 861/861.**
""", """- #588 / `81beaaed...`: strict-maximum equal-Y mixed point-touch boundary and source-state rebase, 861/861;
- **#601 / `82793869...` (functional `3a100f82...`): late strict-maximum multi-crossing mixed point-touch extension and separated-minimum source-state rebase, 862/862.**
""", 'trace milestone')
old_row = """| two positive strict-convex triangles with proper crossings + exactly one vertex↔strict-edge point touch in the #569 strict-minimum, #575 early strict-maximum, #588 equal-Y strict-maximum or #582 late single-crossing strict-maximum source-event classes | `SourceClipper1TwoConvexMixedPointUnion2` | #569 **39600/39600**, #575 **72000/72000**, #582 **64800/64800** exact full raw paths; #588 pinned-source probe **54000/54000** raw-start-rule matches from 3000 bases × 3×3 rotations × both orders, plus a committed fixed fixture locking the complete raw path across all 18 variants | `parity_verified` (scoped) | Horizontal, late multi-crossing, side-vertex, rounded-degenerate and mixed-collinear output-list states remain open. |
"""
new_row = """| two positive strict-convex triangles with proper crossings + exactly one vertex↔strict-edge point touch in the #569 strict-minimum and represented non-horizontal strict-maximum ordering classes (#575 `<`, #588 `==`, #582/#601 late `>`) | `SourceClipper1TwoConvexMixedPointUnion2` | #569 **39600/39600**, #575 **72000/72000**, #582 **64800/64800** exact full raw paths; #588 **54000/54000** raw-start matches plus fixed full-path fixture; #601 adds **216000/216000** generic late-multicross raw starts plus **64800/64800 exact full raw paths** on the separated-minimum boundary | `parity_verified` (scoped) | Horizontal, side-vertex, rounded-degenerate and mixed-collinear output-list states remain open. |
"""
text = replace_once(text, old_row, new_row, 'trace mixed row')
text = text.replace('direct helper tests + route tests through #588', 'direct helper tests + route tests through #601')
text = replace_once(text, """The mixed point helper remains explicitly source-event bounded. #569 proves the strict-minimum touching vertex class with **39600/39600** raw paths. #575 proves an early strict-max class with **72000/72000** full raw paths when the touched edge is non-horizontal and `otherThird.y < min(ownerPrevious.y, ownerNext.y)`, spanning 1–4 proper crossings. #588 proves the equal-Y boundary for non-horizontal touched edges with at least one proper crossing: a directly compiled pinned-source matrix produced **54000/54000** raw-start-rule matches across 3,000 independent bases (528 single-crossing, 2,472 multi-crossing), all cyclic rotations and both orders, while the fixed regression locks the complete raw path. #582 proves the complementary late strict-max class only for exactly one proper crossing and `otherThird.y > min(...)`, with **64800/64800** exact full raw paths from 3,600 independent bases split evenly across vertical, positive-slope and negative-slope touched edges.

The #588 audit also establishes that a valid equal-Y output may have two nonadjacent global minimum-Y vertices. `SourceClipper1TwoConvexMixedPointUnion2` therefore relaxes its old adjacent-minima rebase guard only for the independently classified #588 state and still chooses the source rightmost-minimum anchor. Horizontal strict-max touches, late strict-max states with multiple proper crossings, side-vertex touches, rounded-degenerate cases and mixed collinear states stay fallback. Runtime `AppendPolygon()` / `OutRec::Pts` behavior remains acceptance-relevant but is not by itself a safe static classifier; the exact predicates above are the independently proved bounds.
""", """The mixed point helper remains explicitly source-event bounded. #569 proves the strict-minimum touching vertex class with **39600/39600** raw paths. #575 proves an early strict-max class with **72000/72000** full raw paths when the touched edge is non-horizontal and `otherThird.y < min(ownerPrevious.y, ownerNext.y)`, spanning 1–4 proper crossings. #588 proves the equal-Y boundary with **54000/54000** raw-start-rule matches plus a fixed complete-path regression. #582 proves the late `>` single-crossing class with **64800/64800** exact full raw paths. #601 extends the same late `>` class to multi-crossing states with **216000/216000** independent generic/targeted raw-start matches and a separate **64800/64800 exact full-path** separated-minimum boundary matrix; together the `>` source matrices span proper-count 1–4.

The #588 and #601 audits establish two independently classified cases where a valid output may have two nonadjacent global minimum-Y vertices. `SourceClipper1TwoConvexMixedPointUnion2` relaxes its old adjacent-minima rebase guard only for those proved states and still chooses the source rightmost-minimum anchor. Horizontal strict-max touches, side-vertex touches, rounded-degenerate cases and mixed collinear states stay fallback. Runtime `AppendPolygon()` / `OutRec::Pts` behavior remains acceptance-relevant but is not by itself a safe static classifier; the exact predicates above are the independently proved bounds.
""", 'trace mixed narrative')
text = replace_once(text, """1. Continue **mixed proper-crossing + point-touch/collinear degeneracies** beyond the #569/#575/#588/#582 event classes: late strict-max multi-crossing states, rounded/degenerated strict-max cases, side-vertex touches, horizontal ordering, then mixed collinear states. Use exact traced output-list state; do not reuse the proper-crossing rebase heuristic without proof.
""", """1. Continue **mixed proper-crossing + point-touch/collinear degeneracies** beyond the #569/#575/#588/#582/#601 event classes: rounded/degenerated strict-max cases, side-vertex touches, horizontal ordering, then mixed collinear states. Use exact traced output-list state; do not reuse the proper-crossing rebase heuristic without proof.
""", 'trace priority')
path.write_text(text)

print('updated ledgers')
