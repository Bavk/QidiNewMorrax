from pathlib import Path

replacements = {
    Path('docs/HANDOFF.md'): {
        '## Current validated checkpoint — 2026-09-16': '## Current validated checkpoint — 2026-09-17',
        '- code commit `00a49000cedaa85f21bd9fbfcf007e2512860bb6` (`chore: remove rounded collapse patch workflow`; clean two-file functional tree for the rounded-collapse change);': '- code commit `00a49000cedaa85f21bd9fbfcf007e2512860bb6` (clean production checkpoint for the translated AEL-outside rounded-family extension);',
        '- `.github/workflows/flutter-parity.yml` run `35218255121` (#615), job `105191803438`;': '- `.github/workflows/flutter-parity.yml` run `35218255121` (#628), job `105191803438`;',
        'The suite retains every earlier represented Classic/Arachne/geometry fixture and adds one independently traced **rounded-to-touch AEL-contained strict-maximum single-crossing collapse**. The accepted state uses exact pinned `E2InsertsBeforeE1()` / `TopX()` ordering: both already-active bounds from the touched triangle lie between the two owner bounds at the strict-max touch, both owner bounds contribute with `WindCnt == 1`, and the same-coordinate crossing/touch events collapse the rounded-away sliver to the owner triangle. AEL-outside `WindCnt == 2` retained-vertex/wedge states, side-vertex touches, horizontal touches and mixed-collinear states remain explicit fallback.': 'The suite retains every earlier represented Classic/Arachne/geometry fixture, including the #615 rounded-to-touch AEL-contained collapse, and additionally locks two independently traced **AEL-outside** strict-maximum rounded families: retained-inner-vertex and retained-wedge under integer translation only. Scaling is explicitly excluded by pinned-source counterevidence. Broader AEL-outside rounded/degenerated states, side-vertex touches, horizontal touches and mixed-collinear states remain explicit fallback.',
    },
    Path('migration/MIGRATION_STATUS.md'): {
        '## Current executable checkpoint — 2026-09-16': '## Current executable checkpoint — 2026-09-17',
        '- validated code `00a49000cedaa85f21bd9fbfcf007e2512860bb6` (clean branch checkpoint containing `fix: cover AEL-contained rounded strict-max collapse`);': '- validated code `00a49000cedaa85f21bd9fbfcf007e2512860bb6` (clean production checkpoint for the translated AEL-outside rounded-family extension);',
        '- workflow `35218255121` (#615), job `105191803438`, conclusion **success**;': '- workflow `35218255121` (#628), job `105191803438`, conclusion **success**;',
        'The current suite retains every earlier represented Classic/Arachne/geometry fixture and adds the independently traced rounded-to-touch strict-max single-crossing class where exact pinned `E2InsertsBeforeE1()` / `TopX()` ordering places both active other bounds between the owner bounds and both owner bounds contribute with `WindCnt == 1`. Exact all-rotation raw-path fixtures and Arachne zero-offset routing are locked; broader AEL-outside rounded/degenerated states beyond the two translation-locked retained-inner-vertex/retained-wedge families, side, horizontal and mixed-collinear neighbors remain fallback.': 'The current suite retains every earlier represented Classic/Arachne/geometry fixture, including the #615 AEL-contained rounded-to-touch collapse, and adds two source-traced AEL-outside rounded strict-max families under integer translation only: retained-inner-vertex and retained-wedge. Their exact raw paths and Arachne zero-offset routing are locked; scaling is explicitly excluded by source counterevidence. Broader AEL-outside rounded/degenerated states, side, horizontal and mixed-collinear neighbors remain fallback.',
    },
    Path('migration/VALIDATION.md'): {
        '## Current executed Flutter/Dart checkpoint — 2026-09-16': '## Current executed Flutter/Dart checkpoint — 2026-09-17',
        'GitHub Actions `.github/workflows/flutter-parity.yml` run `35218255121` (#615), job `105191803438`, executed clean code checkpoint `00a49000cedaa85f21bd9fbfcf007e2512860bb6` and completed successfully:': 'GitHub Actions `.github/workflows/flutter-parity.yml` run `35218255121` (#628), job `105191803438`, executed clean code checkpoint `00a49000cedaa85f21bd9fbfcf007e2512860bb6` and completed successfully:',
        'The suite re-executes all earlier represented Classic/Arachne/geometry/Boost/Clipper fixtures and adds the independently traced rounded-to-touch AEL-contained strict-maximum single-crossing collapse, exact small and translated/scaled all-rotation regressions, exact Arachne zero-offset routing, and two AEL-outside negative regressions that retain fallback.': 'The suite re-executes all earlier represented Classic/Arachne/geometry/Boost/Clipper fixtures, retains the #615 AEL-contained rounded collapse, and promotes the two independently traced AEL-outside retained-inner-vertex/retained-wedge families only for exact integer translations. Canonical/all-rotation and translated regressions plus Arachne zero-offset routing are exact; the ×2 pinned-source counterexample keeps scaling and broader neighboring AEL-outside states on fallback.',
    },
    Path('migration/TRACEABILITY.md'): {
        '- workflow: `.github/workflows/flutter-parity.yml` run `35218255121` (#615), job `105191803438`;': '- workflow: `.github/workflows/flutter-parity.yml` run `35218255121` (#628), job `105191803438`;',
    },
}

for path, mapping in replacements.items():
    text = path.read_text()
    for old, new in mapping.items():
        if old not in text:
            raise SystemExit(f'missing target in {path}: {old[:80]}')
        text = text.replace(old, new, 1)
    path.write_text(text)
