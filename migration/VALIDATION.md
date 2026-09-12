# Validation record — strict 1:1 rewrite

This file records **what has actually been executed and proven**, separately from code/tests that merely exist in the repository.

## Input identity / loss-prevention baseline

- Supplied archive: `QidiFlow-2.07.02.60-Pass28-Device-Reference-Redesign-Clean(1).zip`.
- Archive SHA-256 from the initial audit: `821ed379d65916df32f5d031bd583bc724ce72f4d229447adc61280701e4d57d`.
- Extracted source files inventoried: **8,632**.
- Previous local runtime-asset integrity pass: **3,657/3,657** entries marked as copied runtime assets matched source SHA-256; 0 missing, 0 mismatches.
- Full publication of those binary assets into the GitHub repository is still an explicit repository-bootstrap gap. Local integrity does not equal remote publication verification.

## Local execution limitation

The current development environment does **not** provide a runnable Flutter/Dart SDK. Therefore it has not executed:

- `flutter analyze`;
- `flutter test`;
- Flutter desktop builds;
- Dart formatter/analyzer/compiler checks.

No authored Dart implementation is promoted to `parity_verified` on the basis of code inspection alone.

## GitHub Actions status

A repository workflow exists at `.github/workflows/flutter-parity.yml`. It pins Flutter `3.47.2`, obtains it directly from the official `flutter/flutter` repository, then intends to run:

1. toolchain identity;
2. `flutter pub get`;
3. `flutter analyze`;
4. `flutter test --reporter expanded`.

The first workflow revision used a third-party Flutter setup action. Because jobs failed before executing any step, the workflow was changed to remove that action and clone the official Flutter tag directly.

**The infrastructure failure remained.** The latest checked run at the time of this update was run `34662392194` for commit `a984d08adc1699d8f5c4801a56f0471cf874ff06`. GitHub reported:

- workflow conclusion: `failure`;
- job: `analyze-and-test`;
- `steps: []`;
- `runner_id: 0`;
- empty runner name/group;
- job created/started/completed in ~3 seconds.

This means no checkout, Flutter installation, dependency resolution, analyzer or test command ran. Treat this as a **GitHub Actions runner/account/repository infrastructure blocker**, not as a Dart test failure and not as a passing validation.

Before any module is upgraded to `parity_verified`, CI or another Flutter-enabled machine must actually allocate a runner and execute the reference suite.

## Authored source-derived tests currently awaiting execution

The repository now contains source-derived or source-formula tests for, among other existing tests:

- integer `coord_t` Line parallel/perpendicular/intersection semantics;
- source Polyline append/clip/extend linear behavior;
- ThickPolyline width-vector/reverse/rebase/index semantics;
- initial Clipper/ClipperUtils offset/boolean fixtures;
- MedialAxis edge validation, half-edge traversal and endpoint post-processing fixtures;
- Flow math/config-width fallbacks;
- Extruder E/mm3, retract/unretract and QIDI variant-resolution semantics;
- Surface flags, merge predicate and QIDI copy/assignment quirks;
- classic perimeter source-formula subset;
- ExtrusionEntity role strings/classifiers, copy/clone quirks, volume scaling, multipath and collection flattening.

These are **authored, not executed** in the current environment.

## Important numeric-parity finding

The source slicer geometry is fundamentally based on integer `coord_t` coordinates with:

- `SCALING_FACTOR = 0.00001` mm;
- 100000 integer units per mm;
- `EPSILON = 1e-4`;
- `SCALED_EPSILON = 10` source coordinate units.

This affects rounding-sensitive tests and algorithms. Exact-source geometry now has a dedicated integer domain (`SourcePoint2`, `SourceLine2`, `SourcePolygon2`, `SourcePolyline2`, `ThickPolyline2`). Existing older millimeter-double helpers are not by themselves sufficient evidence of 1:1 slicer parity.

## Completion truth

There are currently **zero top-level parity gates closed** and no executable subsystem should be described as fully `parity_verified` yet.

The strict acceptance authority remains `PARITY_CONTRACT.md`; symbol-level status is tracked in `TRACEABILITY.md`.
