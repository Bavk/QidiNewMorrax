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
- `flutter test --reporter expanded`: **174/174 passing**;
- `git diff --check`: passing;
- validated code commit: `015dcdd4cbfb9b292a89642c0d736f2471483691`;
- temporary analyzer-cleanup workflow removed in `2f2c8486e09640dd4d6d03ebc85cee843146d8b2`.

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

The current pure-Dart Clipper2 adapter is `parity_verified` **for the translated fixtures currently in the suite**:

- union/difference/intersection fixture behavior;
- contour/hole reconstruction in those fixtures;
- positive/negative constant offsets;
- `offset2`, opening/closing building blocks used by current slicer code;
- Clipper1 miter-limit compatibility: source values below 2 behave as effective limit 2;
- positive `ExPolygon` hole-offset orientation compatibility where Clipper2 preserves orientation differently from Clipper1.

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
- supportTransition filtering quirk.

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

## Classic perimeter / thin wall

The currently represented `PerimeterGenerator::process_classic()` shell/thin-wall subset is `parity_verified` by source-formula and end-to-end tests for:

- common inset overlap tolerance `0.4`;
- QIDI smaller-external tolerance `0.22`;
- narrow-loop threshold `10`;
- requested/alternate extra wall count behavior;
- first external and external→internal inset formulas in source integer coordinates;
- one-coordinate-unit safety terms;
- spiral-vase largest-island subset;
- QIDI smaller-width external loop selection;
- exact source quirk `last = offsets`: smaller-width outer loops are output only and do **not** seed inner loops;
- `detect_thin_wall` geometry path: Clipper difference/opening → `SourceExPolygonMedialAxis2` → source-domain `ThickPolyline2`;
- explicit requirement for the source external-nozzle diameter used by the thin-wall branch.

This does **not** complete `process_classic()`. Still pending include:

- conversion of returned ThickPolyline data through the source variable-width extrusion path;
- gap-fill generation and its MedialAxis/width rules;
- remaining overhang/path-order/loop/extrusion-role behavior;
- exact covered-area helpers and later perimeter stages;
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

1. Port the source variable-width conversion that consumes classic thin-wall `ThickPolyline` output and add source/differential fixtures.
2. Port classic gap fill using the now-working MedialAxis chain.
3. Continue `PerimeterGenerator::process_classic()` line-by-line through remaining path/role/order/overhang branches.
4. Expand Clipper/ClipperUtils translated regression coverage and fix every discrepancy rather than relaxing fixtures.
5. Continue Arachne/surfaces/fill/bridge/support/seam toolpath modules.
6. Expand the native G-code state machine and integrate the exact ExtrusionEntity model into Preview/G-code consumers.
7. Continue project/profile/editor/device/cloud/calibration/desktop/UI parity in parallel.
8. Publish and SHA-verify the real runtime assets before any release-complete claim.

No item may be called complete because it merely looks equivalent or passes only common-case smoke tests.
