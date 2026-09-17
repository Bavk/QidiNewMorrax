from pathlib import Path

CODE = '00a49000cedaa85f21bd9fbfcf007e2512860bb6'
RUN = '35218255121'
JOB = '105191803438'

files = [
    Path('docs/HANDOFF.md'),
    Path('migration/MIGRATION_STATUS.md'),
    Path('migration/VALIDATION.md'),
    Path('migration/TRACEABILITY.md'),
]

for path in files:
    text = path.read_text()
    text = text.replace(
        'd3bc685a316b8d70bffe66b0eecf496e5dd9926f',
        CODE,
    )
    text = text.replace('35124252980', RUN)
    text = text.replace('104889290591', JOB)
    text = text.replace('868/868', '870/870')
    text = text.replace(
        'AEL-outside rounded retained-vertex/wedge states',
        'broader AEL-outside rounded/degenerated states beyond the two translation-locked retained-inner-vertex/retained-wedge families',
    )
    text = text.replace(
        'AEL-outside rounded retained-vertex / retained-wedge states',
        'broader AEL-outside rounded/degenerated states beyond the two translation-locked retained-inner-vertex/retained-wedge families',
    )
    text = text.replace(
        'AEL-outside rounded retained-vertex and retained-wedge states',
        'broader AEL-outside rounded/degenerated states beyond the two translation-locked retained-inner-vertex/retained-wedge families',
    )
    path.write_text(text)

# Add one concise batch paragraph to each ledger at a stable, nearby marker.
insertions = {
    Path('docs/HANDOFF.md'): (
        '## Current checkpoint',
        '''## #628 translated AEL-outside rounded strict-max extension\n\nPR #6 independently locks the two source-traced AEL-outside rounded-collapse output-list families that #615 deliberately left on fallback: retained-inner-vertex and retained-wedge. The runtime matcher accepts only integer translations of the two canonical coordinate-difference patterns; it does not infer a scale/affine family. Pinned-source run `35217212927`, job `105188120437`, matched both fixed families across all 18 cyclic-rotation/input-order variants (36/36 complete raw paths combined). Translation matrix run `35217607425`, job `105189698086`, matched 1,000 translations per topology × 18 variants = **36000/36000 exact complete raw paths**. A deliberate scale probe, run `35217503833`, job `105189359905`, changed the pinned source output already at ×2 for both topologies, so scaling remains an explicit compatibility seam. Flutter parity run `35218255121` (#628), job `105191803438`, on code checkpoint `00a49000cedaa85f21bd9fbfcf007e2512860bb6` is green with Flutter 3.47.2 / Dart 3.13.2, clean analyze and **870/870** tests.\n\n''',
    ),
    Path('migration/MIGRATION_STATUS.md'): (
        '## Top-level gates',
        '''### #628 translated AEL-outside rounded strict-max families\n\nThe represented rounded strict-max subset now also includes two independently traced **AEL-outside** raw output-list families: retained-inner-vertex and retained-wedge, under arbitrary integer translation only. Fixed source fixtures matched 36/36 complete raw paths across rotations/input order (`35217212927` / `105188120437`); a broad translation oracle matched **36000/36000 exact complete raw paths** (`35217607425` / `105189698086`). A negative source probe (`35217503833` / `105189359905`) changes the raw result at ×2 scaling, so scaled/neighboring AEL-outside states remain fallback rather than being geometry-normalized. PR parity run `35218255121` (#628), job `105191803438`, is green with clean analyze and **870/870** tests.\n\n''',
    ),
    Path('migration/VALIDATION.md'): (
        '## Validation rules',
        '''## #628 AEL-outside rounded strict-max validation\n\nValidated code checkpoint: `00a49000cedaa85f21bd9fbfcf007e2512860bb6`. GitHub Actions Flutter parity run `35218255121` (#628), job `105191803438`: Flutter **3.47.2**, Dart **3.13.2**, `flutter analyze` **No issues found!**, `flutter test --reporter expanded` **870/870 passing**. Direct pinned Clipper1 source evidence: fixed retained-inner-vertex + retained-wedge fixtures **36/36 exact complete raw paths** across all rotation/input-order variants (`35217212927` / `105188120437`); translation-only matrix **36000/36000 exact complete raw paths** from 2,000 translated bases (`35217607425` / `105189698086`). Negative boundary: ×2 scaling changes source output (`35217503833` / `105189359905`), therefore no scale/affine generalization is validated.\n\n''',
    ),
    Path('migration/TRACEABILITY.md'): (
        '## Source target',
        '''## #628 translated AEL-outside rounded trace\n\n`SourceClipper1TwoConvexMixedPointUnion2` now recognizes the two independently source-traced AEL-outside rounded strict-max families (retained-inner-vertex and retained-wedge) only when their point sets are exact integer translations of the canonical fixtures. Evidence: fixed 36/36 full raw paths (`35217212927` / `105188120437`), translation matrix **36000/36000** full raw paths (`35217607425` / `105189698086`), plus the explicit ×2 scaling counterexample (`35217503833` / `105189359905`) that keeps scaled and broader neighboring states outside this exact subset. Flutter checkpoint `00a49000cedaa85f21bd9fbfcf007e2512860bb6` is green in #628 (`35218255121` / `105191803438`) with **870/870** tests.\n\n''',
    ),
}

for path, (marker, block) in insertions.items():
    text = path.read_text()
    if block.strip() in text:
        continue
    if marker not in text:
        # Fall back to adding near the start without destroying the ledger.
        lines = text.splitlines(True)
        at = 1 if lines else 0
        lines.insert(at, '\n' + block)
        text = ''.join(lines)
    else:
        text = text.replace(marker, block + marker, 1)
    path.write_text(text)
