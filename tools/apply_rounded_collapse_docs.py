from pathlib import Path

CODE = 'd3bc685a316b8d70bffe66b0eecf496e5dd9926f'
RUN = '35124252980'
JOB = '104889290591'


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f'missing {label}')
    return text.replace(old, new, 1)


# docs/HANDOFF.md
path = Path('docs/HANDOFF.md')
text = path.read_text()
text = replace_once(
    text,
    """- code commit `5bbdb555af8ecf662a7b906daee39b4a6acafc90` (`fix: cover strict-max single-cross separated minima`);
- `.github/workflows/flutter-parity.yml` run `35090634147` (#608), job `104775845616`;
- Flutter `3.47.2`;
- Dart `3.13.2`;
- `flutter analyze` → **No issues found!**;
- `flutter test --reporter expanded` → **863/863 passed**;
- job conclusion → **success**.

The suite retains every earlier represented Classic/Arachne/geometry fixture and adds the independently proved late strict-maximum **single-crossing separated-minimum** boundary, exact all-rotation raw-path regression and Arachne zero-offset routing. Side-vertex, horizontal, mixed-collinear and other rounded/degenerated strict-max states beyond this proved endpoint-Y boundary remain explicit fallback.
""",
    f"""- code commit `{CODE}` (`chore: remove rounded collapse patch workflow`; clean two-file functional tree for the rounded-collapse change);
- `.github/workflows/flutter-parity.yml` run `{RUN}` (#615), job `{JOB}`;
- Flutter `3.47.2`;
- Dart `3.13.2`;
- `flutter analyze` → **No issues found!**;
- `flutter test --reporter expanded` → **868/868 passed**;
- job conclusion → **success**.

The suite retains every earlier represented Classic/Arachne/geometry fixture and adds one independently traced **rounded-to-touch AEL-contained strict-maximum single-crossing collapse**. The accepted state uses exact pinned `E2InsertsBeforeE1()` / `TopX()` ordering: both already-active bounds from the touched triangle lie between the two owner bounds at the strict-max touch, both owner bounds contribute with `WindCnt == 1`, and the same-coordinate crossing/touch events collapse the rounded-away sliver to the owner triangle. AEL-outside `WindCnt == 2` retained-vertex/wedge states, side-vertex touches, horizontal touches and mixed-collinear states remain explicit fallback.
""",
    'handoff checkpoint',
)
text = replace_once(
    text,
    '### #569 / #575 / #588 / #582 / #601 / #608 mixed proper-crossing + point-touch extensions',
    '### #569 / #575 / #588 / #582 / #601 / #608 / #615 mixed proper-crossing + point-touch extensions',
    'handoff mixed heading',
)
needle = """#608 independently closes the corresponding **single-crossing separated-minimum** boundary that had remained as the historical \"rounded strict-max\" fallback. Direct pinned-source run `35090443828`, job `104775225066`, locks the fixed fixture at **18/18 exact complete raw paths** and adds **3,600** independent bases — 1,200 vertical, 1,200 positive-slope and 1,200 negative-slope touched edges — across all 18 rotation/input-order variants. The generated matrix matched **64800/64800 exact raw starts and 64800/64800 exact complete raw paths**. The implementation therefore extends the separated-minimum rebase permission to `properCount == 1` only for the same late `>` endpoint-Y source state. Flutter parity #608 is green at **863/863**.

The represented non-horizontal strict-max partition is therefore: #575 `<` with 1–4 proper crossings, #588 `==` with at least one proper crossing, and #582 + #601 + #608 `>` spanning the proved single- and multi-crossing states (source matrices cover proper-count 1–4), including independently proved separated-minimum boundaries for both single- and multi-crossing cases. Horizontal touched edges, side-vertex touches, mixed-collinear states and other rounded/degenerated strict-max states beyond this endpoint-Y boundary remain on compatibility fallback.
"""
replacement = """#608 independently closes the corresponding **single-crossing separated-minimum** boundary that had remained as the historical \"rounded strict-max\" fallback. Direct pinned-source run `35090443828`, job `104775225066`, locks the fixed fixture at **18/18 exact complete raw paths** and adds **3,600** independent bases — 1,200 vertical, 1,200 positive-slope and 1,200 negative-slope touched edges — across all 18 rotation/input-order variants. The generated matrix matched **64800/64800 exact raw starts and 64800/64800 exact complete raw paths**. The implementation therefore extends the separated-minimum rebase permission to `properCount == 1` only for the same late `>` endpoint-Y source state. Flutter parity #608 is green at **863/863**.

#615 isolates a different rounded/degenerated state rather than widening #608. Exactly one proper crossing rounds to the strict-max touch coordinate. A direct pinned-source event trace (`35122390233`, job `104883098941`) showed that source output splits on AEL ordering: the represented branch has both already-active other bounds between the owner bounds at `touch.y`, so both owner bounds enter output with `WindCnt == 1`; AEL-outside counterstates instead give the owner `WindCnt == 2` and retain an inner vertex or wedge. The Dart classifier ports the pinned `E2InsertsBeforeE1()` equal-`Curr.x` / `TopX()` tie rule and accepts only the first branch.

Pinned-source matrices for that exact AEL-contained branch matched **165132/165132 exact complete raw paths** across **9,174** generated bases and all 18 cyclic-rotation/input-order variants: the primary matrix `35122592466` / `104883775222` contributed **5000 bases / 90000 paths**; the green asymmetric translated matrix `35123441575` / `104886606102` contributed **1000 / 18000** with collapsed-owner-edge split 531/469; two supplementary quota-limited runs contributed **1239 / 22302** (`35122868681` / `104884696367`) and **1935 / 34830** (`35123235250` / `104885923066`) without any source mismatch. The latter two ended only because their requested generation quota was not reached within the attempt cap and are retained as supplementary no-mismatch evidence, not as successful workflow gates. Flutter parity #615 is green at **868/868**.

The represented non-horizontal strict-max ordering partition from #575/#588/#582/#601/#608 remains unchanged for ordinary non-collapsed intersections. #615 additionally represents only the traced rounded-to-touch `WindCnt == 1` AEL-contained single-crossing collapse. AEL-outside rounded collapses (including the retained-inner-vertex and retained-wedge counterfixtures), horizontal touched edges, side-vertex touches and mixed-collinear states remain on compatibility fallback.
"""
text = replace_once(text, needle, replacement, 'handoff #615 section')
text = text.replace(
    '- exactly two positive strict-convex triangles for mixed proper-crossing + single point-touch states in the #569 strict-minimum, #575 early ordered strict-maximum, #588 equal-Y strict-maximum, #582 late single-crossing strict-maximum, #601 late multi-crossing strict-maximum and #608 single-cross separated-minimum classes described above.',
    '- exactly two positive strict-convex triangles for mixed proper-crossing + single point-touch states in the #569 strict-minimum, #575 early ordered strict-maximum, #588 equal-Y strict-maximum, #582 late single-crossing strict-maximum, #601 late multi-crossing strict-maximum and #608 single-cross separated-minimum classes, plus the #615 traced AEL-contained rounded-to-touch strict-max collapse described above.',
)
text = text.replace(
    '1. continue **mixed proper-crossing + point-touch/collinear two-positive paths** beyond the #569/#575/#588/#582/#601/#608 proved event classes: remaining rounded/degenerated strict-max cases beyond the separated-minimum endpoint-Y boundary, then side-vertex touches, horizontal touch ordering and mixed collinear cases; use traced `AppendPolygon()` / `OutRec::Pts` source state rather than a geometric normalization heuristic;',
    '1. continue **mixed proper-crossing + point-touch/collinear two-positive paths** beyond the #569/#575/#588/#582/#601/#608/#615 proved event classes: first the remaining AEL-outside / other rounded-degenerated strict-max families (including retained-vertex/wedge states excluded by #615), then side-vertex touches, horizontal touch ordering and mixed collinear cases; keep tracing AEL / `AppendPolygon()` / `OutRec::Pts` source state rather than using a geometric normalization heuristic;',
)
path.write_text(text)


# migration/MIGRATION_STATUS.md
path = Path('migration/MIGRATION_STATUS.md')
text = path.read_text()
text = replace_once(
    text,
    """- Flutter **3.47.2**, Dart **3.13.2**;
- validated code `5bbdb555af8ecf662a7b906daee39b4a6acafc90` (`fix: cover strict-max single-cross separated minima`);
- workflow `35090634147` (#608), job `104775845616`, conclusion **success**;
- `flutter analyze` — **No issues found!**;
- `flutter test --reporter expanded` — **863/863 passing**.

The current suite retains every earlier represented Classic/Arachne/geometry fixture and promotes the historical rounded strict-max fallback into the exact helper only for the independently proved late strict-maximum single-crossing separated-minimum endpoint-Y state. Its complete pinned raw fixture is locked across all cyclic rotations/input orders, with exact Arachne zero-offset routing; side, horizontal, mixed-collinear and other rounded/degenerated neighbors remain fallback.
""",
    f"""- Flutter **3.47.2**, Dart **3.13.2**;
- validated code `{CODE}` (clean branch checkpoint containing `fix: cover AEL-contained rounded strict-max collapse`);
- workflow `{RUN}` (#615), job `{JOB}`, conclusion **success**;
- `flutter analyze` — **No issues found!**;
- `flutter test --reporter expanded` — **868/868 passing**.

The current suite retains every earlier represented Classic/Arachne/geometry fixture and adds the independently traced rounded-to-touch strict-max single-crossing class where exact pinned `E2InsertsBeforeE1()` / `TopX()` ordering places both active other bounds between the owner bounds and both owner bounds contribute with `WindCnt == 1`. Exact all-rotation raw-path fixtures and Arachne zero-offset routing are locked; AEL-outside rounded retained-vertex/wedge states, side, horizontal and mixed-collinear neighbors remain fallback.
""",
    'migration checkpoint',
)
text = text.replace(
    '- exactly two positive strict-convex triangles with proper crossings plus exactly one vertex↔strict-edge-interior point touch for the independently proved #569 strict minimum-Y class and non-horizontal strict-maximum ordering classes: #575 `<`, #588 `==`, #582 late `>` single-crossing, #601 late `>` multi-crossing and #608 late `>` single-cross separated-minimum boundary.',
    '- exactly two positive strict-convex triangles with proper crossings plus exactly one vertex↔strict-edge-interior point touch for the independently proved #569 strict minimum-Y class and non-horizontal strict-maximum ordering classes: #575 `<`, #588 `==`, #582 late `>` single-crossing, #601 late `>` multi-crossing and #608 late `>` single-cross separated-minimum boundary; #615 additionally covers the traced rounded-to-touch single-crossing state only when exact AEL ordering keeps both active other bounds between the owner bounds (`WindCnt == 1`).',
)
needle = '- #608 late strict-maximum **single-crossing separated-minimum** boundary: direct pinned-source run `35090443828`, job `104775225066`; fixed historical fixture **18/18 exact full raw paths**, plus **3,600** independent bases split 1,200/1,200/1,200 across vertical/positive/negative touched edges × all 18 variants = **64800/64800 exact raw starts and 64800/64800 exact full raw paths**.\n'
addition = needle + '- #615 rounded-to-touch **AEL-contained strict-maximum single-crossing collapse**: direct source event trace `35122390233`, job `104883098941`, distinguishes the accepted `WindCnt == 1` owner-bound state from AEL-outside `WindCnt == 2` retained-vertex/wedge counterstates. Primary run `35122592466`, job `104883775222`, matched **90000/90000 exact full raw paths** from 5,000 bases; green asymmetric translated run `35123441575`, job `104886606102`, matched **18000/18000** from 1,000 bases; supplementary quota-limited no-mismatch matrices add **22302/22302** and **34830/34830**. Aggregate: **9,174 bases / 165132/165132 exact complete raw paths**, all 18 rotation/input-order variants.\n'
text = replace_once(text, needle, addition, 'migration #615 evidence')
old = """The #575/#588/#582/#601/#608 strict-max predicates partition the represented non-horizontal ordering seam. #575 owns `otherThird.y < min(ownerPrevious.y, ownerNext.y)` with 1–4 proper crossings. #588 owns equality with at least one proper crossing. #582 plus #601 plus #608 own `otherThird.y > min(...)` across the proved single- and multi-crossing states, with source matrices spanning proper-count 1–4. The equal-Y and late separated-minimum audits establish narrow states where a valid raw contour may contain two **nonadjacent** global minimum-Y vertices; #601 independently proves that endpoint-Y boundary for multi-crossing and #608 independently proves it for single-crossing. The helper permits the rightmost-minimum `BuildResult()` rebase only for those classified states. Horizontal strict-max touches, side-vertex touches, mixed collinear cases and other rounded/degenerated strict-max states remain explicit fallback.
"""
new = """The #575/#588/#582/#601/#608 strict-max predicates partition the represented non-horizontal ordinary-intersection ordering seam. #575 owns `otherThird.y < min(ownerPrevious.y, ownerNext.y)` with 1–4 proper crossings. #588 owns equality with at least one proper crossing. #582 plus #601 plus #608 own `otherThird.y > min(...)` across the proved single- and multi-crossing states, with source matrices spanning proper-count 1–4. The equal-Y and late separated-minimum audits establish narrow states where a valid raw contour may contain two **nonadjacent** global minimum-Y vertices; #601 independently proves that endpoint-Y boundary for multi-crossing and #608 independently proves it for single-crossing. #615 is orthogonal to that rebase partition: it covers exactly one proper crossing whose rounded intersection equals the strict-max touch, only when exact `E2InsertsBeforeE1()` ordering places both active other edges between owner bounds and the traced owner `WindCnt` is 1. AEL-outside rounded collapses, horizontal strict-max touches, side-vertex touches and mixed collinear cases remain explicit fallback.
"""
text = replace_once(text, old, new, 'migration partition')
text = text.replace('direct pinned ELF/source oracles + #608 CI', 'direct pinned ELF/source oracles + #615 CI')
text = text.replace(
    '1. Continue **mixed proper-crossing + point-touch/collinear two-positive paths** beyond the #569/#575/#582/#588/#601/#608 proved classes: remaining rounded/degenerated strict-max cases beyond the separated-minimum endpoint-Y boundary, then side-vertex touches, horizontal touch ordering and mixed collinear cases. Start from traced `AppendPolygon()` / `OutRec::Pts` state rather than assuming the proper-only rebase rule.',
    '1. Continue **mixed proper-crossing + point-touch/collinear two-positive paths** beyond the #569/#575/#582/#588/#601/#608/#615 proved classes: first remaining AEL-outside / other rounded-degenerated strict-max families (including retained-vertex/wedge counterstates), then side-vertex touches, horizontal touch ordering and mixed collinear cases. Start from traced AEL / `AppendPolygon()` / `OutRec::Pts` state rather than assuming a geometric rebase rule.',
)
path.write_text(text)


# migration/VALIDATION.md
path = Path('migration/VALIDATION.md')
text = path.read_text()
text = replace_once(
    text,
    """GitHub Actions `.github/workflows/flutter-parity.yml` run `35090634147` (#608), job `104775845616`, executed code commit `5bbdb555af8ecf662a7b906daee39b4a6acafc90` and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **863/863 tests passed**;
- job conclusion — **success**.

The suite re-executes all earlier represented Classic/Arachne/geometry/Boost/Clipper fixtures and adds the independently proved late strict-maximum single-crossing separated-minimum boundary, exact all-rotation raw-path regression and Arachne zero-offset routing while retaining side-vertex, horizontal, mixed-collinear and other rounded/degenerated strict-max states on fallback.
""",
    f"""GitHub Actions `.github/workflows/flutter-parity.yml` run `{RUN}` (#615), job `{JOB}`, executed clean code checkpoint `{CODE}` and completed successfully:

- `flutter pub get` — completed;
- `flutter analyze` — **`No issues found!`**;
- `flutter test --reporter expanded` — **868/868 tests passed**;
- job conclusion — **success**.

The suite re-executes all earlier represented Classic/Arachne/geometry/Boost/Clipper fixtures and adds the independently traced rounded-to-touch AEL-contained strict-maximum single-crossing collapse, exact small and translated/scaled all-rotation regressions, exact Arachne zero-offset routing, and two AEL-outside negative regressions that retain fallback.
""",
    'validation checkpoint',
)
marker = '## #608 late strict-maximum single-crossing separated-minimum boundary\n'
section = """## #615 rounded-to-touch AEL-contained strict-maximum collapse

`SourceClipper1TwoConvexMixedPointUnion2` now represents one rounded/degenerated strict-max state beyond the #608 separated-minimum endpoint-Y boundary. The state has exactly one proper crossing whose pinned Clipper1 rounded intersection lands on the strict maximum-Y point-touch coordinate. This is **not** accepted from geometry alone.

A direct pinned-source event trace in run `35122390233`, job `104883098941`, established the source-shaped discriminator. At `touch.y`, the accepted branch has both already-active bounds from the touched triangle between the two owner bounds under the exact Clipper1 `E2InsertsBeforeE1()` / `TopX()` ordering. Both owner bounds therefore contribute with `WindCnt == 1`; the same-coordinate proper-cross/touch events remove the rounded-away sliver and the raw result is the owner contour beginning at the positive-order owner predecessor. Two traced counterstates put an active other bound outside that interval, give the owner `WindCnt == 2`, and retain either an inner vertex or a wedge; both are committed as fallback regressions.

Independent pinned-source matrices at commit `f2b55a5a83f266cf56e06c7943a81a08bebb7fad` produced:

- run `35122592466`, job `104883775222`: **5,000** bases × 18 variants = **90000/90000 exact complete raw paths**;
- run `35123441575`, job `104886606102`, conclusion success: **1,000** asymmetric, nonzero-translated bases × 18 variants = **18000/18000 exact complete raw paths**, with collapsed-owner-edge split 531/469;
- supplementary run `35122868681`, job `104884696367`: **1,239** translated/scaled valid bases = **22302/22302 exact complete raw paths** before its generation-attempt cap;
- supplementary run `35123235250`, job `104885923066`: **1,935** asymmetric translated valid bases = **34830/34830 exact complete raw paths** before its generation-attempt cap.

The supplementary runs ended because their requested valid-base quota was not reached inside the attempt cap; neither produced a source mismatch. Aggregate represented evidence is **9,174 bases / 165132/165132 exact complete raw-path comparisons**, each base checked over all 3×3 cyclic rotations and both input/AddPath orders.

The Dart change ports the pinned equal-`Curr.x` `E2InsertsBeforeE1()` tie branch, validates the AEL-contained state, and returns the exact owner predecessor→touch→successor path before the ordinary boundary reconstruction. It deliberately leaves AEL-outside rounded retained-vertex/wedge cases, side-vertex touches, horizontal touch ordering, mixed-collinear output-list states and other rounded degeneracies on fallback.

Flutter parity #615 (`35124252980`, job `104889290591`) is green on Flutter **3.47.2** / Dart **3.13.2**, analyzer clean, **868/868** tests passing.

"""
if marker not in text:
    raise RuntimeError('missing validation #608 marker')
text = text.replace(marker, section + marker, 1)
text = text.replace(
    'A weaker strict-max hypothesis was falsified independently: vertical touched edge + exactly one proper crossing matched only **44712/45000**, leaving **288** raw mismatches. The exact #575/#588/#582/#601/#608 predicates must not be widened from slope or extrema alone.',
    'A weaker strict-max hypothesis was falsified independently: vertical touched edge + exactly one proper crossing matched only **44712/45000**, leaving **288** raw mismatches. The exact #575/#588/#582/#601/#608/#615 predicates must not be widened from slope, extrema or rounded-coordinate coincidence alone.',
)
text = text.replace(
    'The #575/#588/#582/#601/#608 results refine that conclusion: append state alone is not a static classifier. The exact accept/reject boundary must come from independently proved scanline/output-list state.',
    'The #575/#588/#582/#601/#608/#615 results refine that conclusion: append state or rounded-coordinate coincidence alone is not a static classifier. The exact accept/reject boundary must come from independently proved scanline/AEL/output-list state.',
)
text = text.replace(
    'Analyzer/tests are green through the #608 single-cross endpoint-Y extension (863/863)',
    'Analyzer/tests are green through the #615 AEL-contained rounded-collapse extension (868/868)',
)
path.write_text(text)


# migration/TRACEABILITY.md
path = Path('migration/TRACEABILITY.md')
text = path.read_text()
text = replace_once(
    text,
    """- code: `5bbdb555af8ecf662a7b906daee39b4a6acafc90`;
- workflow: `.github/workflows/flutter-parity.yml` run `35090634147` (#608), job `104775845616`;
- Flutter `3.47.2`, Dart `3.13.2`;
- analyzer: **No issues found**;
- tests: **863/863 passed**;
- conclusion: **success**.
""",
    f"""- code: `{CODE}`;
- workflow: `.github/workflows/flutter-parity.yml` run `{RUN}` (#615), job `{JOB}`;
- Flutter `3.47.2`, Dart `3.13.2`;
- analyzer: **No issues found**;
- tests: **868/868 passed**;
- conclusion: **success**.
""",
    'trace checkpoint',
)
text = replace_once(
    text,
    '- **#608 / `5bbdb555...`: late strict-maximum single-crossing separated-minimum boundary, 863/863.**\n',
    '- #608 / `5bbdb555...`: late strict-maximum single-crossing separated-minimum boundary, 863/863.\n- **#615 / `d3bc685a...`: rounded-to-touch AEL-contained strict-maximum single-crossing collapse, 868/868.**\n',
    'trace milestone',
)
old_row = '| two positive strict-convex triangles with proper crossings + exactly one vertex↔strict-edge point touch in the #569 strict-minimum and represented non-horizontal strict-maximum ordering classes (#575 `<`, #588 `==`, #582/#601/#608 late `>`) | `SourceClipper1TwoConvexMixedPointUnion2` | #569 **39600/39600**, #575 **72000/72000**, #582 **64800/64800** exact full raw paths; #588 **54000/54000** raw-start matches plus fixed full-path fixture; #601 adds **216000/216000** generic late-multicross raw starts plus **64800/64800 exact full raw paths** on the multi-cross separated-minimum boundary; #608 adds **64800/64800 exact full raw paths** plus **18/18** fixed variants for the independent single-cross separated-minimum boundary | `parity_verified` (scoped) | Horizontal, side-vertex, mixed-collinear and other rounded/degenerated output-list states remain open. |'
new_row = '| two positive strict-convex triangles with proper crossings + exactly one vertex↔strict-edge point touch in the #569 strict-minimum and represented non-horizontal strict-maximum ordering classes (#575 `<`, #588 `==`, #582/#601/#608 late `>`), plus #615 rounded-to-touch AEL-contained collapse | `SourceClipper1TwoConvexMixedPointUnion2` | #569 **39600/39600**, #575 **72000/72000**, #582 **64800/64800** exact full raw paths; #588 **54000/54000** raw-start matches plus fixed full-path fixture; #601 adds **216000/216000** generic late-multicross raw starts plus **64800/64800 exact full raw paths** on the multi-cross separated-minimum boundary; #608 adds **64800/64800 exact full raw paths** plus **18/18** fixed variants; #615 source trace + **9174 bases / 165132/165132 exact complete raw paths** for the exact `WindCnt == 1` AEL-contained rounded-collapse branch | `parity_verified` (scoped) | AEL-outside rounded retained-vertex/wedge states, horizontal, side-vertex, mixed-collinear and other rounded/degenerated output-list states remain open. |'
text = replace_once(text, old_row, new_row, 'trace mixed row')
text = text.replace(
    '| Arachne exact offset/final-union routing | `SourceArachneWallToolPathsPrepareExact2` | direct helper tests + route tests through #608 |',
    '| Arachne exact offset/final-union routing | `SourceArachneWallToolPathsPrepareExact2` | direct helper tests + route tests through #615 |',
)
needle = """The mixed point helper remains explicitly source-event bounded. #569 proves the strict-minimum touching vertex class with **39600/39600** raw paths. #575 proves an early strict-max class with **72000/72000** full raw paths when the touched edge is non-horizontal and `otherThird.y < min(ownerPrevious.y, ownerNext.y)`, spanning 1–4 proper crossings. #588 proves the equal-Y boundary with **54000/54000** raw-start-rule matches plus a fixed complete-path regression. #582 proves the late `>` single-crossing class with **64800/64800** exact full raw paths. #601 extends the same late `>` class to multi-crossing states with **216000/216000** independent generic/targeted raw-start matches and a separate **64800/64800 exact full-path** multi-cross separated-minimum boundary matrix. #608 independently proves the matching single-cross separated-minimum endpoint-Y boundary with **64800/64800 exact full raw paths** plus **18/18** fixed variants; together the `>` source matrices span proper-count 1–4.

The #588, #601 and #608 audits establish independently classified states where a valid output may have two nonadjacent global minimum-Y vertices. `SourceClipper1TwoConvexMixedPointUnion2` relaxes its old adjacent-minima rebase guard only for those proved states and still chooses the source rightmost-minimum anchor. Horizontal strict-max touches, side-vertex touches, mixed collinear states and other rounded/degenerated cases stay fallback. Runtime `AppendPolygon()` / `OutRec::Pts` behavior remains acceptance-relevant but is not by itself a safe static classifier; the exact predicates above are the independently proved bounds.
"""
replacement = """The mixed point helper remains explicitly source-event bounded. #569 proves the strict-minimum touching vertex class with **39600/39600** raw paths. #575 proves an early strict-max class with **72000/72000** full raw paths when the touched edge is non-horizontal and `otherThird.y < min(ownerPrevious.y, ownerNext.y)`, spanning 1–4 proper crossings. #588 proves the equal-Y boundary with **54000/54000** raw-start-rule matches plus a fixed complete-path regression. #582 proves the late `>` single-crossing class with **64800/64800** exact full raw paths. #601 extends the same late `>` class to multi-crossing states with **216000/216000** independent generic/targeted raw-start matches and a separate **64800/64800 exact full-path** multi-cross separated-minimum boundary matrix. #608 independently proves the matching single-cross separated-minimum endpoint-Y boundary with **64800/64800 exact full raw paths** plus **18/18** fixed variants; together the ordinary `>` source matrices span proper-count 1–4. #615 separately proves the rounded-to-touch single-crossing branch only when exact AEL ordering places both already-active other bounds between owner bounds: direct tracing distinguishes the accepted `WindCnt == 1` state from `WindCnt == 2` retained-vertex/wedge counterstates, and **9174 bases / 165132/165132 exact full raw paths** lock that classifier.

The #588, #601 and #608 audits establish independently classified states where a valid output may have two nonadjacent global minimum-Y vertices. `SourceClipper1TwoConvexMixedPointUnion2` relaxes its old adjacent-minima rebase guard only for those proved states and still chooses the source rightmost-minimum anchor. #615 does not widen that rebase rule; it ports the exact `E2InsertsBeforeE1()`/`TopX()` AEL-contained state and returns the traced owner contour before ordinary boundary reconstruction. AEL-outside rounded collapses, horizontal strict-max touches, side-vertex touches and mixed collinear states stay fallback. Runtime AEL / `AppendPolygon()` / `OutRec::Pts` behavior remains acceptance-relevant and the exact predicates above are the independently proved bounds.
"""
text = replace_once(text, needle, replacement, 'trace narrative')
text = text.replace(
    'remaining rounded/degenerated strict-max output-list states beyond #608 endpoint-Y boundary',
    'remaining AEL-outside / other rounded-degenerated strict-max output-list states beyond #615',
)
text = text.replace('current acceptance is enforced by CI history through #608', 'current acceptance is enforced by CI history through #615')
path.write_text(text)

print('updated HANDOFF, MIGRATION_STATUS, VALIDATION, TRACEABILITY')
