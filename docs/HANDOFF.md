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

Last validated code checkpoint before this documentation batch:

- code commit: `704b9900820d4ed479ad192cebbbe1958f0b89fb` (`test: cover classic gap fill pipeline`);
- normal workflow: `.github/workflows/flutter-parity.yml` run `34679098241` (#152);
- Flutter `3.47.2`;
- Dart `3.13.2`;
- `flutter analyze` → **No issues found!**;
- `flutter test --reporter expanded` → **185/185 passed**;
- job conclusion → **success**.

Earlier independently green milestones in the same chain include thin-wall → variable-width extrusion run `34678782013` (#147) and source covered-width geometry run `34678922719` (#150).

## Numeric/source rules that must be preserved

### libslic3r coordinates

The source slicer is not a free-form millimeter-double system:

- `SCALING_FACTOR = 0.00001` mm;
- 100000 integer source units/mm;
- `EPSILON = 1e-4`;
- `SCALED_EPSILON = 10` source units.

Rounding/truncation-sensitive algorithms must stay in source integer types (`SourcePoint2`, `SourceLine2`, `SourcePolygon2`, `SourceExPolygon2`, `SourcePolyline2`, `ThickPolyline2`) until the actual source boundary converts units.

### Boost.Polygon 1.83

The direct Dart Fortune/Voronoi port is passing the represented Boost/QIDI oracle suite. Two implementation details are especially easy to break:

- Boost `uint64_t` arithmetic and double-bit ULP comparison cannot be represented safely by signed native Dart `int` when bit 63 is crossed; the port deliberately uses `BigInt` at those boundaries.
- PPP circle formation keeps the **literal Boost 1.83 operand order** for `robust_cross_product`. Do not reorder it into a mathematically nicer cross product without a Boost oracle proving equivalence.

The square segment full half-edge golden, extreme-int32 circle cases, known Voronoi regressions, QIDI repair-angle sequence and annotation are green.

### Clipper compatibility

The project uses pure-Dart Clipper2 behind a compatibility adapter, while QIDI/libslic3r source behavior is Clipper 6.x/ClipperUtils-shaped. Current verified compatibility includes:

- Clipper1 miter-limit values below 2 behaving as effective 2;
- positive ExPolygon hole offsets retaining holes by explicit contour-minus-hole reconstruction;
- translated constant-offset/basic boolean fixtures;
- source-domain open-polyline offset used by `ExtrusionPath::polygons_covered_by_width()`: square joins, open-butt ends, non-zero union, and no millimeter round trip.

Do not remove these adapter quirks just because native Clipper2 defaults differ.

## Classic perimeter / MedialAxis checkpoint

The following source subset now works end-to-end and is covered by the 185-test suite:

- classic onion-shell inset formulas;
- QIDI smaller-external-width branch;
- exact source behavior `last = offsets` — smaller-width outer loops are output only and do **not** feed subsequent inner loops;
- source one-coordinate-unit / Clipper safety terms;
- alternate extra wall behavior;
- `detect_thin_wall` path:
  `Clipper difference/opening → SourceExPolygonMedialAxis2 → ThickPolyline2`;
- exact QIDI/libslic3r variable-width conversion from `ThickPolyline2` to extrusion entities;
- use of the same source `ext_perimeter_flow` for `nozzle/3` and thin-wall extrusion conversion;
- `ExtrusionEntity::polygons_covered_by_width()` represented path/multipath/loop/collection dispatch;
- classic gap collection on the **extra shell iteration**, source float32 casts, opening/max-width subtraction, closed-polygon Douglas–Peucker, MedialAxis, short-line filter, `variable_width(... erGapFill, solid_infill_flow ...)`, and covered-width subtraction from `last`.

Raw `thinWalls` and `gapFillPolylines` are deliberately retained in `ClassicPerimeterResult` as regression evidence in addition to the converted extrusion entities.

## Immediate next code task

Continue `PerimeterGenerator::process_classic()` at the next source boundary: **loop extrusion construction, recursive `traverse_loops`, and nearest-neighbor ordering**.

Source behavior already located in `PerimeterGenerator.cpp`:

1. convert each structural loop into `ExtrusionLoop` with external/internal role, loop-role flags, source flow/mm3/width/height and polygon split semantics;
2. add thin-wall variable-width entities into the same nearest-neighbor candidate collection;
3. choose thin-wall search origin from the far bbox corner as source does;
4. port `chain_extrusion_entities(...)` source ordering/reversal decisions instead of substituting a generic sort;
5. recurse children in source order: contour children before the contour loop, hole loop before its children;
6. force contour CCW and hole CW through source loop methods;
7. then continue overhang clipping/path-role branches and remaining fill-surface/covered-area stages;
8. only after the classic path is represented, continue Arachne and broader toolpaths.

Do not flatten the loop tree prematurely and do not replace source nearest-neighbor chaining with a convenience sort.

## Current represented parity evidence

The 185-test suite currently covers explicitly scoped subsets of:

- Point/Line source geometry;
- Polyline/QIDI append/clip/extend and ArcFitter metadata;
- Circle/ArcSegment and arc helpers;
- ThickPolyline;
- Boost robust numeric helpers, predicates, circle formation and Fortune construction;
- QIDI Voronoi detection/repair/annotation;
- MedialAxis and ExPolygon post-processing;
- translated Clipper boolean/offset fixtures plus source open-line covered-width offset;
- Flow;
- Extruder/QIDI variant resolution;
- Surface;
- ExtrusionEntity/Path/MultiPath/Loop/Collection;
- source variable-width extrusion conversion and extrusion covered-width geometry;
- source-style G-code formatting and fitting-result extrusion branch;
- classic perimeter shell, thin-wall conversion, and gap-fill pipeline represented so far;
- existing linear-infill/basic writer fixtures.

These are **scoped parity claims only**. All top-level product gates remain open.

## Major open areas

- remaining classic perimeter loop tree, ordering, overhang splitting/roles, fill-surface and later stages;
- Arachne;
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
