# Migration status — STRICT 1:1 Flutter/Dart rewrite

The acceptance authority is [`PARITY_CONTRACT.md`](PARITY_CONTRACT.md). The target is the supplied Qidi Flow 2.07.02.60 Pass28 application completely reimplemented in Flutter + Dart. The original C++/wxWidgets/React code is reference material only and must not remain a runtime backend through FFI, subprocesses, native libraries, hidden services, or embedded legacy WebViews.

## Status vocabulary

- `pending` — no real Dart replacement yet.
- `port_started` — only part of the source behavior exists.
- `implemented_unverified` — intended replacement exists, but required reference tests have not executed successfully yet.
- `parity_verified` — the explicitly scoped source behavior is covered by passing translated/differential/oracle tests.
- `runtime_asset_verified` — preserved data is byte-for-byte verified or uses a documented canonical transform.

A `parity_verified` row never implies that its containing top-level subsystem is complete.

## Current executable checkpoint

As of 2026-09-12:

- pinned Flutter: **3.47.2**;
- Dart: **3.13.2**;
- `flutter analyze`: **No issues found**;
- `flutter test --reporter expanded`: **185/185 passing**;
- validated code commit: `704b9900820d4ed479ad192cebbbe1958f0b89fb`;
- validation workflow: `.github/workflows/flutter-parity.yml` run `34679098241` (#152), conclusion **success**.

See [`VALIDATION.md`](VALIDATION.md) for the executed evidence and exact scope.

## Top-level completion gates

All top-level gates remain **OPEN**:

1. formats/project persistence 1:1;
2. scene/editor 1:1;
3. slicer/toolpath 1:1;
4. Preview 1:1;
5. profiles/presets 1:1;
6. Device/cloud 1:1;
7. calibration 1:1;
8. desktop integration/release 1:1;
9. UI/localization/accessibility 1:1;
10. complete reference/differential-test coverage.

## Numeric architecture

libslic3r’s 2D slicer geometry is an integer `coord_t` domain:

- `SCALING_FACTOR = 0.00001` mm;
- 100000 source units/mm;
- `EPSILON = 1e-4`;
- `SCALED_EPSILON = 10` source units.

Exact-source algorithms therefore use `SourcePoint2`, `SourceLine2`, `SourcePolygon2`, `SourceExPolygon2`, `SourcePolyline2`, and `ThickPolyline2`. Millimeter doubles remain boundary/UI representations unless equivalence is proven.

## Geometry / Boost / MedialAxis

### Verified represented subsets

The following represented behaviors are now `parity_verified` by the passing suite:

- SourcePoint/SourceLine rounding, orientation, distance, parallel/perpendicular, finite/infinite intersection subset;
- QIDI Polyline append/join dedup, clip/extend, reverse, ArcFitter, `PathFittingData`, fitting-aware split/reverse/clip quirks;
- Circle/ArcSegment construction, clipping, direction and arc helpers;
- `ThickPolyline` invariants, `thicklines`, reverse, `rebase_at`, `get_width_at`;
- Boost.Polygon 1.83 robust floating/error helpers and extended integer/sqrt expressions used by the port;
- Boost site-event ordering/categories, ULP comparisons, PPP/PPS/PSS/SSS circle formation and selected extreme-int32/regression oracles;
- direct Dart Fortune construction for the tested point/segment cases and full square segment half-edge golden;
- QIDI Voronoi issue detection, repair-angle sequence, endpoint remapping, inside/outside/on-contour annotation, and direct-builder wrapper behavior;
- MedialAxis edge validation, PI/8 rule, width filtering, half-edge traversal and `ExPolygon::medial_axis()` post-processing.

Two critical implementation details must be preserved in future edits:

- Boost `uint64_t` arithmetic/bit-pattern comparisons are emulated with `BigInt` where native Dart signed `int` would cross bit 63;
- the PPP robust-cross-product operand order is kept **literal to Boost 1.83**, even where a mathematically cleaner ordering looks tempting.

### Still open

- broader Boost/Voronoi source cases not represented by current oracle fixtures;
- remaining Polygon/ExPolygon APIs and downstream consumers;
- curved/primary-edge uses outside the tested MedialAxis path where additional source behavior may still be required.

## Clipper / ClipperUtils

The current pure-Dart Clipper2 adapter is `parity_verified` **for the translated fixtures/current consumers in the suite**:

- union/difference/intersection fixture behavior;
- contour/hole reconstruction in those fixtures;
- positive/negative constant offsets;
- `offset2`, opening/closing building blocks used by current slicer code;
- Clipper1 miter-limit compatibility: source values below 2 behave as effective limit 2;
- positive `ExPolygon` hole reconstruction across offset;
- source open-polyline offset used by `polygons_covered_by_width()`, with square join, open-butt end type and source integer coordinates.

The broader Clipper/ClipperUtils module remains `port_started`: the source uses Clipper 6.x plus custom Slic3r/QIDI wrappers, so more original regression coverage is still required before calling the whole subsystem equivalent.

## Flow / Extruder / Surface / ExtrusionEntity

The represented source subsets are now `parity_verified`:

### Flow

- role auto widths;
- rounded-rectangle spacing/cross section;
- bridge formulas;
- `mm3_per_mm`;
- width/height/spacing/cross-section mutations;
- config fallback and percentage resolution, including initial-layer quirks.

### Extruder / QIDI config subset

- E/mm3;
- absolute/relative E state;
- retract/unretract/restart-extra behavior;
- used-filament and speed-fallback semantics;
- shared-extruder two-channel shape;
- QIDI variant-name/index resolution subset.

### Surface

- represented SurfaceType ordering/classification/defaults/colors;
- merge predicate;
- QIDI compensation fields;
- source copy-constructor and assignment omission quirks.

### ExtrusionEntity

- represented ExtrusionRole ordering/strings/classifiers;
- path state, volume, overhang/curve clamps and `can_merge()` comparison set;
- sloped clone-slicing quirk and oriented-path dynamic type;
- MultiPath continuity/reverse/copy behavior;
- Loop basic behavior;
- Collection role/reverse/flatten/copy behavior;
- supportTransition filtering quirk;
- QIDI/libslic3r variable-width `ThickPolyline` conversion;
- represented `polygons_covered_by_width()` path/multipath/loop/collection dispatch and open-line coverage geometry.

The containing slicer/G-code modules remain `port_started` because many downstream source methods are still absent.

## G-code

`SourceGCodeFormatter2` / `SourceExtrusionPathEmitter2` are `parity_verified` for the tested source branch:

- source XYZ/E rounding/trimming;
- G1 fallback;
- G2/G3 use of ArcFitter metadata;
- spiral-mode arc disable;
- `force_no_extrusion` behavior;
- origin/extruder/plate coordinate transforms;
- full-comment formatting.

Sloped XYZ extrusion deliberately still refuses an XY-only approximation. Full native G-code state/templates/travel/retraction/cooling/speed/acceleration/multi-material/postprocessing remain `pending` or `port_started`.

## Classic perimeter / thin wall / gap fill

The currently represented `PerimeterGenerator::process_classic()` subset is `parity_verified` by source-formula and end-to-end tests for:

- common inset overlap tolerance `0.4`;
- QIDI smaller-external tolerance `0.22`;
- narrow-loop threshold `10`;
- requested/alternate extra wall count behavior;
- first external and external→internal inset formulas in source integer coordinates;
- one-coordinate-unit and Clipper safety terms;
- spiral-vase largest-island subset;
- QIDI smaller-width external loop selection;
- exact source quirk `last = offsets`: smaller-width outer loops are output only and do **not** seed inner loops;
- `detect_thin_wall`: Clipper difference/opening → `SourceExPolygonMedialAxis2` → `ThickPolyline2`;
- thin-wall conversion through source `variable_width(... erExternalPerimeter, ext_perimeter_flow ...)`;
- use of the same external perimeter `Flow` for nozzle-derived minimum width and converted extrusion semantics;
- source covered-width geometry required by downstream subtraction;
- classic gap collection on the extra shell iteration;
- gap min/max width formulas, explicit float32 offset casts, opening/max-width clipping, closed-polygon Douglas–Peucker, MedialAxis, configured short-line removal, `variable_width(... erGapFill, solid_infill_flow ...)`, and covered-width subtraction from `last`.

This does **not** complete `process_classic()`. Still pending include:

- structural loop → `ExtrusionLoop` construction with exact loop-role flags;
- recursive `traverse_loops()` nesting/orientation semantics;
- `chain_extrusion_entities()` nearest-neighbor ordering/reversal and thin-wall integration into that chain;
- overhang clipping/degree/bridge-wall path splitting and source role/flow selection;
- remaining fill-surface/fill-no-overlap and later perimeter stages;
- Arachne variable-width wall generation.

## Model/project I/O

Still `port_started`:

- STL ASCII/binary;
- OBJ;
- AMF / ZIP.AMF;
- package-aware 3MF parsing/repack foundations including external components/build transforms and unknown-entry retention.

Still open include complete project metadata/settings/repair warnings, STEP, source-enabled Assimp formats, and all preset/project round-trip semantics.

## Device / profiles / localization / UI

Port-started foundations include:

- source-shaped QIDI SSDP discovery;
- Moonraker JSON-RPC/subscriptions and local command foundations;
- QIDI Box command/file/timelapse foundations;
- profile loading/inheritance/compatibility foundations;
- PO localization reader;
- Prepare/Preview/Device/Project/Calibration Flutter shell areas.

These are not full parity. Cloud/P2P/account, camera/HMS/firmware, full capability/reconnect machines, every calibration flow, complete source UI state/workflow behavior, and desktop integration remain open.

## Runtime assets

The earlier local audit verified 3,657/3,657 copied runtime entries against source SHA-256. **That is not remote publication verification.** Some declared asset directories currently contain technical `.gitkeep` markers so CI can resolve `pubspec.yaml`; those markers do not satisfy the asset gate. Do not remove source asset declarations merely to make CI quiet, and do not mark them `runtime_asset_verified` until the real bytes are present and verified in the repository/release input.

## Immediate next dependency order

1. Port structural classic loop → `ExtrusionLoop` conversion and source loop-role/winding semantics.
2. Port recursive `traverse_loops()` plus exact `chain_extrusion_entities()` ordering/reversal, including thin walls in the same chain.
3. Continue `PerimeterGenerator::process_classic()` through overhang/path-role/covered-area/fill-surface branches.
4. Expand Clipper/ClipperUtils translated regression coverage as new source consumers require it.
5. Continue Arachne/surfaces/fill/bridge/support/seam toolpath modules.
6. Expand the native G-code state machine and integrate the exact ExtrusionEntity model into Preview/G-code consumers.
7. Continue project/profile/editor/device/cloud/calibration/desktop/UI parity in parallel.
8. Publish and SHA-verify the real runtime assets before any release-complete claim.

No item may be called complete because it merely looks equivalent or passes only common-case smoke tests.
