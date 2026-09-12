# Handoff — Qidi Flow strict Flutter/Dart rewrite

This repository is a **strict 1:1 reimplementation** of the supplied Qidi Flow 2.07.02.60 Pass28 application in Flutter + Dart. The old C++/wxWidgets/React application is reference material only; it must never remain a runtime backend through FFI, subprocesses, native shared libraries, hidden local services, or embedded legacy WebViews.

## Read first

1. [`../migration/PARITY_CONTRACT.md`](../migration/PARITY_CONTRACT.md) — acceptance authority.
2. [`../migration/MIGRATION_STATUS.md`](../migration/MIGRATION_STATUS.md) — current subsystem truth and next dependency order.
3. [`../migration/TRACEABILITY.md`](../migration/TRACEABILITY.md) — source → Dart → evidence ledger.
4. [`../migration/VALIDATION.md`](../migration/VALIDATION.md) — what actually executed.
5. This file — operational continuation notes.

Do not infer completion from visual similarity, a compiling app shell, or a passing common-case test. Source quirks are part of the contract.

## Current validated checkpoint — 2026-09-12

Code checkpoint before this documentation update:

- validated code commit: `015dcdd4cbfb9b292a89642c0d736f2471483691` (`chore: finish analyzer cleanup`);
- current normal-workflow base after removing the temporary cleanup workflow: `2f2c8486e09640dd4d6d03ebc85cee843146d8b2`;
- Flutter `3.47.2`;
- Dart `3.13.2`.

Executed evidence:

- cleanup validation run `34668728368`: `flutter analyze` → **No issues found!**, `flutter test --reporter expanded` → **174/174 passed**, `git diff --check` passed;
- ordinary read-only parity run `34668800262` (#139) after the temporary workflow was removed: Analyze **success**, Unit and parity tests **success**, final `+174: All tests passed!`.

The temporary write-enabled analyzer-cleanup workflow has been deleted. Continue using only `.github/workflows/flutter-parity.yml` for normal validation.

## Numeric/source rules that must be preserved

### libslic3r coordinates

The source slicer is not a free-form millimeter-double system:

- `SCALING_FACTOR = 0.00001` mm;
- 100000 integer source units/mm;
- `EPSILON = 1e-4`;
- `SCALED_EPSILON = 10` source units.

Rounding/truncation-sensitive algorithms must stay in source integer types (`SourcePoint2`, `SourceLine2`, `SourcePolygon2`, `SourceExPolygon2`, `SourcePolyline2`, `ThickPolyline2`) until the actual source boundary converts units.

### Boost.Polygon 1.83

The direct Dart Fortune/Voronoi port is now passing the represented Boost/QIDI oracle suite. Two implementation details are especially easy to break:

- Boost `uint64_t` arithmetic and double-bit ULP comparison cannot be represented by signed native Dart `int` when bit 63 is crossed; the port deliberately uses `BigInt` at those boundaries.
- PPP circle formation keeps the **literal Boost 1.83 operand order** for `robust_cross_product`. Do not reorder it into a mathematically nicer cross product without a Boost oracle proving equivalence.

The square segment full half-edge golden, extreme-int32 circle cases, known Voronoi regressions, QIDI repair-angle sequence and annotation are currently green.

### Clipper compatibility

The project uses pure-Dart Clipper2 behind a compatibility adapter, while QIDI/libslic3r source behavior is Clipper 6.x/ClipperUtils-shaped. Current verified compatibility includes:

- Clipper1 miter-limit values below 2 behaving as effective 2;
- positive ExPolygon hole offsets retaining the final CW hole orientation despite Clipper2 preserving input orientation differently from Clipper1;
- translated constant-offset and basic boolean fixtures.

Do not remove these adapter quirks just because native Clipper2 defaults differ.

## Classic perimeter / MedialAxis checkpoint

The following source subset now works end-to-end and is covered by tests:

- classic onion-shell inset formulas;
- QIDI smaller-external-width branch;
- exact source behavior `last = offsets` — smaller-width outer loops are output only and do **not** feed subsequent inner loops;
- source one-coordinate-unit safety terms;
- alternate extra wall behavior;
- `detect_thin_wall` path:
  `Clipper difference/opening → SourceExPolygonMedialAxis2 → ThickPolyline2`;
- explicit use of source external nozzle diameter (`nozzle / 3` minimum thin-wall width path).

The next missing source stage is **not** more Voronoi. It is what consumes these `ThickPolyline2` objects.

## Immediate next code task

Port the source variable-width extrusion conversion used by classic thin walls, with translated/reference fixtures before integrating it into `ClassicPerimeterShellGenerator`.

Dependency order:

1. Locate the exact QIDI/libslic3r helper called after thin-wall `medial_axis()` in `PerimeterGenerator::process_classic()` (the variable-width ThickPolyline → extrusion path conversion).
2. Port its width clamping/interpolation, segment splitting, role/flow/mm3-per-mm construction, endpoint/continuity and any resolution rules literally into Dart.
3. Add source-derived or differential fixtures that exercise constant width, changing width, endpoint flags, short segments and source rounding.
4. Wire classic `detect_thin_wall` output through that helper without deleting the raw ThickPolyline evidence path unless the source structure requires it.
5. Then port the classic **gap-fill** branch, reusing the now-working MedialAxis chain and its source width limits.
6. Continue `PerimeterGenerator::process_classic()` line-by-line through covered-area, path ordering, overhang and extrusion-role stages.
7. Only after those stages, continue Arachne and broader fill/support/seam/bridge toolpaths.

Do not substitute a simple average-width `ExtrusionPath` for the source variable-width algorithm.

## Current represented parity evidence

The 174-test suite currently covers explicitly scoped subsets of:

- Point/Line source geometry;
- Polyline/QIDI append/clip/extend and ArcFitter metadata;
- Circle/ArcSegment and arc helpers;
- ThickPolyline;
- Boost robust numeric helpers, predicates, circle formation and Fortune construction;
- QIDI Voronoi detection/repair/annotation;
- MedialAxis and ExPolygon post-processing;
- translated Clipper boolean/offset fixtures;
- Flow;
- Extruder/QIDI variant resolution;
- Surface;
- ExtrusionEntity/Path/MultiPath/Loop/Collection;
- source-style G-code formatting and fitting-result extrusion branch;
- classic perimeter represented formulas and thin-wall geometry;
- existing linear-infill/basic writer fixtures.

These are **scoped parity claims only**. All top-level product gates remain open.

## Major open areas

- ThickPolyline → variable-width extrusion conversion and classic gap fill;
- remaining classic perimeter stages and Arachne;
- full fill/support/seam/bridge/adaptive/ironing/brim/skirt/raft toolpaths;
- complete native G-code templates/state/travel/retract/cooling/acceleration/multi-material behavior;
- complete project/profile persistence, STEP and source-enabled import formats;
- scene/editor parity;
- full Preview feature classification/interactions;
- full Device/cloud/P2P/account/camera/HMS/firmware flows and hardware-in-loop validation;
- all calibration workflows;
- desktop integrations, installers, updates, single-instance/file-association behavior;
- complete source UI/state/localization/accessibility/visual parity;
- exhaustive source/reference/differential tests.

## Runtime asset truth

Earlier local migration work verified 3,657/3,657 copied runtime entries against source SHA-256. The **GitHub repository has not yet published and re-verified the complete real runtime asset set**. Some declared asset directories contain `.gitkeep` solely so Flutter CI can resolve the directory declarations.

Therefore:

- do not call assets complete;
- do not treat `.gitkeep` as migrated content;
- do not remove source asset declarations merely to silence tooling;
- before release parity, publish the actual bytes and verify SHA-256 again from repository/release inputs.

## CI / working discipline

For every meaningful source batch:

1. identify the exact source functions and dependent types/constants;
2. port literal behavior, including odd branches/rounding/order;
3. add translated, differential, or source-oracle tests;
4. run/confirm `.github/workflows/flutter-parity.yml` on pinned Flutter 3.47.2;
5. do not weaken analyzer or tests to make CI green;
6. update `MIGRATION_STATUS.md`, `TRACEABILITY.md`, `VALIDATION.md`, and this handoff when scope/evidence/next dependency changes;
7. never promote a top-level gate until every required branch and reference test for that gate is complete.

If a future edit breaks Boost/Voronoi or Clipper fixtures, assume the port changed source semantics until proven otherwise; do not rewrite goldens to fit the Dart output without an independent C++/source oracle.
