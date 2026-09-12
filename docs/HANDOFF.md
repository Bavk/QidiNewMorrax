# QidiNewMorrax — canonical development handoff

> **Canonical repository:** `https://github.com/Bavk/QidiNewMorrax`
>
> **Source target:** supplied Qidi Flow 2.07.02.60 Pass28 tree.
>
> **Hard requirement:** completely rewrite the application **1:1 in Flutter + Dart**. It must be the same application and implementation behavior on another language/runtime. No relevant source function, edge case, UI workflow, file/profile/project field, slicer algorithm, protocol operation, calibration flow or runtime asset may be silently lost.

This is the mandatory continuation document for every future ChatGPT chat/developer. Read it before coding and update it after every meaningful batch.

The strict acceptance authority is [`migration/PARITY_CONTRACT.md`](../migration/PARITY_CONTRACT.md). If a shortcut conflicts with that contract, strict 1:1 parity wins.

---

## 1. What “1:1 rewrite” means

This project is **not**:

- a similar slicer;
- a compatible QIDI client;
- a redesign;
- a reduced set of common features;
- a Flutter UI on top of the old native engine;
- an FFI/subprocess/native-library wrapper;
- an embedded copy of the old React DeviceWeb;
- an implementation that is merely visually or numerically close in normal cases.

The target is the supplied application, fully reimplemented in Flutter/Dart.

For every source capability preserve, where applicable:

1. screens, dialogs, popovers, context menus, wizards, navigation;
2. actions and enabled/disabled/hidden rules;
3. keyboard/mouse/drag/drop/selection behavior;
4. validation, warnings, errors, confirmations and recovery paths;
5. settings/defaults/inheritance/compatibility expressions/user presets;
6. supported file/project formats and all QIDI/Bambu/Prusa/vendor metadata semantics;
7. slicing/geometry/toolpath algorithms including numeric and degenerate behavior;
8. G-code templates, ordering, flow/speed/cooling/retraction/travel and estimates;
9. Preview feature classification and interaction;
10. LAN/cloud/P2P/device protocols, reconnect/capability state, QIDI Box/AMS, camera, HMS, files, firmware;
11. every calibration mode and generated artifact/toolpath;
12. desktop integration/release behavior;
13. every shipped runtime localization/resource;
14. quirks relied on by other source code;
15. applicable original tests/fixtures.

A Dart class existing, a screen looking similar, or common cases working is not sufficient.

### Runtime rule

The original C++/wxWidgets/React code is specification/reference only. Do not use it at runtime through FFI, `.dll/.so/.dylib`, old executables, subprocesses, hidden services or legacy WebViews.

### Algorithm rule

Application-owned source decision logic must be ported. A different Dart implementation is allowed only when reference/differential tests prove the relevant source semantics including edge cases.

Third-party algorithms used by source must retain the required algorithm/version semantics or be replaced only after source regression tests establish equivalence.

---

## 2. Read these files first

In every new chat/machine/session, read in this order:

1. `migration/PARITY_CONTRACT.md`
2. `docs/HANDOFF.md` — this file
3. `migration/MIGRATION_STATUS.md`
4. `migration/TRACEABILITY.md`
5. `migration/VALIDATION.md`
6. `migration/MODULE_MAP.md`
7. `migration/original_file_manifest.json`
8. `migration/status_counts.json`
9. `README.md`
10. latest commits / PRs / GitHub Issue #1

Original audited archive:

`QidiFlow-2.07.02.60-Pass28-Device-Reference-Redesign-Clean(1).zip`

Baseline audit:

- 8,632 source-tree files inventoried;
- previous local runtime-resource check: 3,657/3,657 copied assets matched source SHA-256, 0 missing, 0 mismatches;
- full remote publication of all binary resources is still an explicit bootstrap gap until GitHub bytes are verified.

---

## 3. Mandatory traceability/status system

Migration must converge to:

`source file → source class/function/branch/behavior → Dart file/symbol → translated/differential tests → status`

Statuses:

- `pending` — no real Dart replacement;
- `port_started` — subset only;
- `implemented_unverified` — intended implementation exists but required reference tests have not actually executed/passed;
- `parity_verified` — implementation + source/reference tests prove required behavior;
- `runtime_asset_verified` — data preservation byte-for-byte or by documented canonical transform.

Only `parity_verified` closes executable behavior.

Update `migration/TRACEABILITY.md` with each meaningful port batch.

---

## 4. Original tests are part of the specification

For each subsystem:

1. locate original tests/fixtures;
2. translate their inputs, tolerances and edge cases;
3. keep reference files where appropriate;
4. add differential/golden comparisons when original tests do not cover observable behavior;
5. compare serialized project packages, generated G-code/toolpaths, protocol payloads and state transitions when deterministic comparison is possible;
6. preserve failure/degenerate cases;
7. never mark `parity_verified` before required tests actually run successfully.

Do not replace hard source fixtures with easier newly invented tests.

---

## 5. Critical numeric architecture rule discovered during port

libslic3r’s exact 2D slicer geometry is fundamentally an integer `coord_t` domain:

- `SCALING_FACTOR = 0.00001` mm;
- 100000 source units per mm;
- `EPSILON = 1e-4`;
- `SCALED_EPSILON = 10` source coordinate units.

This affects rotation rounding, segment intersections, Clipper/Voronoi tolerances, thin walls and regression behavior.

**Rule:** where original source algorithms operate in `coord_t`, preserve an integer-coordinate Dart core unless equivalence of another representation is proven by source tests. Do not casually rewrite those algorithms in millimeter doubles.

Current exact-source numeric types:

- `SourcePoint2`, `SourceLine2` — `lib/core/geometry/source_geometry.dart`;
- `SourcePolygon2`, `SourceExPolygon2` — `source_polygon.dart`;
- `SourcePolyline2` — `source_polyline.dart`;
- `ThickPolyline2` — `thick_polyline.dart`.

Older millimeter-double helpers remain useful at import/UI boundaries but are not by themselves evidence of slicer parity.

---

## 6. What is currently implemented / exact boundary

Everything below describes code that exists. It does **not** imply any top-level parity gate is closed.

### 6.1 Flutter shell / UI foundations

Existing Flutter areas:

- Prepare;
- Preview;
- Device;
- Project;
- Calibration;
- Pass28-oriented Device workspace.

Status: `port_started`. Final UI must reproduce all source screens/dialogs/actions/states/shortcuts/workflows 1:1, not merely retain the present inspired layout.

### 6.2 Model/project I/O foundations

Implemented foundations:

- ASCII/binary STL;
- OBJ;
- AMF / ZIP.AMF with units and constellation transforms;
- package-aware 3MF with external model parts, recursive components, build transforms and unit conversion;
- retention/repack of unknown/vendor ZIP entries;
- basic mesh transforms and software wireframe preview.

Still open:

- complete source project serialization and all per-object/per-volume/per-plate settings;
- full QIDI/Bambu/Prusa metadata;
- STEP;
- every format enabled by the original build/Assimp path;
- exact repair/warning behavior;
- complete preset import/export.

### 6.3 Exact-source Point / Line / Polyline

`SourcePoint2` / `SourceLine2` now represent source integer coordinates.

Ported subset:

- Point rotation with C++ `round()`-compatible behavior;
- Line length/orientation/direction;
- segment/perpendicular distance;
- parallel/perpendicular epsilon tests;
- finite/infinite intersection subset;
- translated source `test_geometry.cpp` Line fixtures including the short-line rounding quirk.

`SourcePolyline2` now preserves:

- source constructor behavior: input point vector is preserved exactly;
- QIDI append behavior: only an equal join endpoint is suppressed;
- reverse;
- linear length/lines;
- linear `clip_end` / `clip_start`;
- QIDI linear extend start/end integer cast behavior.

**Pending:** QIDI ArcFitter / `PathFittingData`, fitting-aware reverse/clip/split/simplify. `simplifyByFittingArc()` intentionally throws `UnsupportedError` rather than silently linearizing.

### 6.4 Clipper / ClipperUtils

There is a pure-Dart compatibility facade for:

- union/difference/intersection/xor;
- offsets;
- `offset2`;
- opening/closing;
- contour/hole reconstruction;
- source scaling and miter-limit defaults.

Current backend is Dart `clipper2`; supplied source uses Clipper 6.x plus custom `ClipperUtils` behavior.

Status: **`implemented_unverified`**. Initial source Clipper tests are translated, but the full regression suite has not run. Any mismatch must be fixed; if needed, directly port required source Clipper behavior. Do not call this geometry parity yet.

### 6.5 ThickPolyline / MedialAxis

`ThickPolyline2` now works in source coordinate units and preserves:

- width cardinality `2*N-2`;
- thickline mapping;
- reverse;
- `rebase_at`;
- source `get_width_at` indexing.

MedialAxis application-owned logic currently represented:

- source-shaped Voronoi vertex/cell/half-edge topology model;
- `MedialAxis::validate_edge()` branch structure;
- PI/8 facing-segment logic;
- `SCALED_EPSILON` tests;
- min/max-width filtering;
- active half-edge chaining / `rot_next`-style traversal;
- Voronoi double → Point conversion using `lrint` nearest-even semantics;
- `ExPolygon::medial_axis()` postprocessing: endpoint extension, short branch removal and reconnect pass.

**Critical missing dependency:** the real segment Voronoi topology is not constructed yet.

Still pending:

- Boost.Polygon-compatible segment Voronoi construction in Dart;
- source `construct_voronoi` behavior;
- `repair_voronoi`;
- inside/outside/on-contour vertex annotation;
- primary/curved edge behavior/discretization needed by source.

Do NOT replace this with a generic skeletonizer. `detect_thin_wall` must remain unavailable until this chain is real and tested.

### 6.6 Flow / Extruder

`Flow.hpp/.cpp` subset ported:

- auto extrusion widths by role;
- rounded-rectangle spacing/cross-section;
- bridge spacing `+0.05`;
- `mm3_per_mm`;
- `with_width`, `with_height`, `with_spacing`, `with_cross_section`, flow ratio;
- source config-width fallback/percentage rules including initial-layer quirks.

`Extruder.cpp` subset ported:

- E/mm3 = flow ratio / filament cross-section;
- relative/absolute E state;
- retract/unretract/restart extra;
- used filament semantics;
- retract/deretract speed fallback;
- QIDI two-channel shared extruder shape;
- QIDI config variant names/index resolution subset.

The basic G-code foundation now uses source Flow + Extruder volume math. This does **not** make the basic writer equivalent to native GCode; full templates, state machine, retraction/travel, cooling, speed/acceleration, multi-material and postprocessing remain pending.

### 6.7 Surface semantic model

`Surface.hpp/.cpp` subset ported:

- exact SurfaceType ordering/classification;
- defaults/thickness/layers/bridge angle/extra perimeters;
- conversion helpers and source color labels;
- exact `surfaces_could_merge()` comparison set;
- QIDI circle-compensation members;
- supplied source copy-constructor quirk: compensation members omitted and reset;
- supplied assignment quirk: destination compensation fields remain unchanged.

This model should be used in future slicer code instead of reducing all layer state to plain polygons.

### 6.8 ExtrusionEntity semantic model

Current `lib/core/slicer/extrusion_entity.dart` ports source data/behavior needed by G-code/Preview:

- exact `ExtrusionRole` order including Flush/Mixed/Count;
- exact source display strings;
- perimeter/infill/solid/bridge/support classifiers;
- `CustomizeFlag`;
- loop role bit flags;
- `ExtrusionPath` fields: polyline, overhang degree, curve degree, mm3/mm, width, height, smooth speed, reverse and force-no-extrusion state;
- source overhang/curve clamp behavior;
- exact `can_merge()` field comparison set, including fields it intentionally ignores;
- `total_volume()` with floating source length × `SCALING_FACTOR` and no extra coord rounding;
- `ExtrusionPathSloped` slope/interpolation plus source clone-slicing quirk;
- `ExtrusionPathOriented` non-reversible/type-preserving clone behavior;
- `ExtrusionMultiPath` continuity/as-polyline/reverse/volume behavior and single-path constructor can-reverse rule;
- source explicit-copy quirk for MultiPath: base customize/cooling reset;
- `ExtrusionLoop` basic winding/reverse/polygon/as-polyline/volume behavior;
- `ExtrusionEntityCollection` role mixing, no-sort/can-sort/can-reverse, recursive item count, reverse semantics, flattening and volume;
- source explicit-copy quirk for Collection: base customize/cooling reset;
- translated flatten cases from `tests/fff_print/test_extrusion_entity.cpp`;
- supportTransition inclusion when filtering supportMaterial.

Still pending here:

- fitting-aware Polyline split/seam logic;
- `ExtrusionLoop::split_at_vertex`, `split_at`, clipping and remaining seam/overhang helpers;
- exact `polygons_covered_by_width/spacing()` on verified source-coordinate boolean geometry;
- remaining QIDI loop/path utility behavior;
- integrating this model into full native-equivalent GCode and Preview instead of the current simplified toolpath feature enum.

### 6.9 Classic perimeter

A source-formula subset of `PerimeterGenerator::process_classic()` exists:

- `INSET_OVERLAP_TOLERANCE = 0.4`;
- QIDI smaller external inset tolerance `0.22`;
- narrow-loop threshold `10`;
- requested wall loop calculation;
- alternate-extra-wall odd-layer behavior;
- external centerline first inset;
- QIDI smaller external-width branch;
- precise external→internal spacing;
- spiral-vase largest-island subset;
- source one-coordinate-unit offset safety term.

`detectThinWall=true` intentionally throws until the exact MedialAxis/Voronoi chain and gap-fill dependencies are implemented.

### 6.10 Existing device/profile/localization foundations

Port-started foundations include:

- QIDI SSDP discovery `239.255.255.250:5863`;
- Moonraker WebSocket JSON-RPC/subscriptions;
- raw + typed printer state;
- QIDI/Klipper local command subset;
- excluded-object control;
- QIDI Box load/unload/eject/RFID commands;
- files/timelapse root;
- source profile inheritance/`compatible_printers`;
- PO localization reader.

Still open: full auth/cloud/P2P/camera/HMS/firmware/capability/reconnect state machines and complete Device UI behavior.

---

## 7. Validation truth / CI blocker

The current local execution environment has no runnable Flutter/Dart SDK.

A GitHub workflow exists at `.github/workflows/flutter-parity.yml` and is intended to run a pinned Flutter toolchain, `flutter pub get`, `flutter analyze`, then tests.

Important current fact: checked GitHub jobs are failing **before a runner is allocated**. Latest examined run during this batch showed:

- `steps: []`;
- `runner_id: 0`;
- no runner name/group;
- completion within seconds.

The workflow was already changed from a third-party setup action to direct cloning of the official Flutter repository; the pre-runner failure remained.

Therefore:

- no checkout occurred in those failed jobs;
- Flutter was not installed;
- analyzer did not run;
- tests did not run;
- those workflow failures are infrastructure failures, not evidence of Dart code failure;
- authored tests remain `implemented_unverified`.

See `migration/VALIDATION.md`.

---

## 8. Major areas still NOT complete

### Geometry/slicer/toolpath

- full source Point/Polygon/Polyline/ArcFitter APIs;
- full Clipper/ClipperUtils semantics/regressions;
- real segment Voronoi constructor/repair/annotation;
- medial-axis end-to-end integration;
- thin walls / gap fill;
- remaining classic perimeter;
- Arachne;
- complete surface classification;
- all source fill families;
- bridges;
- supports/interfaces;
- seams/overhang handling;
- role-aware flow/spacing/path ordering;
- retraction/wipe/travel avoidance;
- ironing;
- brim/skirt/raft;
- multi-material/purge/prime structures;
- adaptive layers;
- cooling/speed/acceleration scheduling;
- timelapse toolpath modifications;
- templates/custom G-code/postprocessing;
- exact time/material estimates and Preview classification.

### Scene/editor

- exact object/part hierarchy;
- complete selection/gizmos;
- undo/redo;
- cut/split/merge/repair/boolean;
- arrange/orient/lay-on-face;
- modifiers/negative volumes;
- multi-plate;
- support/seam/color painting;
- text/emboss;
- measurement and remaining tools/shortcuts/context actions.

### Formats/project

- complete 3MF/project save and round-trip semantics;
- all per-object/per-volume/per-plate settings;
- all metadata/images/custom G-code;
- STEP;
- all source-enabled Assimp formats;
- exact import warnings/repair behavior;
- complete user preset import/export.

### Device/cloud

- account/auth;
- full cloud/P2P;
- camera;
- HMS/diagnostics;
- firmware/update;
- every model capability matrix;
- reconnect/offline/state restoration;
- complete QIDI Box/AMS state machine/UI.

### Calibration / OS / release / localization

- every original calibration wizard/pattern;
- Windows/macOS/Linux runners committed and verified;
- associations, drag/drop, single instance, updater, thumbnails/shell integration;
- complete localized UI/resource behavior;
- accessibility/keyboard parity;
- working CI/release builds.

---

## 9. Exact next engineering order

### Priority 0 — get executable truth

1. Resolve GitHub Actions runner/repository/account infrastructure so a runner is actually assigned.
2. Execute `flutter pub get`, `flutter analyze`, all tests.
3. Fix every real analyzer/test failure before any status becomes `parity_verified`.
4. Keep CI mandatory after it works.

### Priority 1 — exact source geometry dependencies

1. Translate more Point/Line/Polyline and Clipper/ClipperUtils source regression tests.
2. Port QIDI ArcFitter / `PathFittingData` because ExtrusionEntity loop split/seam behavior depends on it.
3. Implement Boost-compatible segment Voronoi construction in Dart.
4. Port source `construct_voronoi`, repair and vertex inside/outside/on-contour annotation.
5. Validate end-to-end MedialAxis against source fixtures.

### Priority 2 — classic perimeter completion

1. Integrate real `ExPolygon::medial_axis`.
2. Port `detect_thin_wall` extraction.
3. Port gap-fill geometry.
4. Continue `PerimeterGenerator::process_classic()` line-by-line.
5. Translate corresponding reference fixtures.

### Priority 3 — ExtrusionEntity → GCode/Preview

1. Finish Polyline fitting/split dependencies.
2. Complete remaining loop/path utilities.
3. Replace simplified toolpath feature model with source `ExtrusionEntity` roles/entities.
4. Port native GCode state behavior and Preview feature classification on top of it.

### Priority 4 — Arachne / surfaces / fill / supports / travels

Continue source-module by source-module with the same source→Dart→test traceability.

Parallel after core dependencies become reliable: editor/project persistence, profiles, Device cloud/camera/HMS, calibration, desktop/release/UI details.

---

## 10. Rules for EVERY future chat / developer

At start:

1. read `migration/PARITY_CONTRACT.md`;
2. read this entire file;
3. read `MIGRATION_STATUS.md`, `TRACEABILITY.md`, `VALIDATION.md`;
4. inspect latest commits/Issue #1/PRs;
5. locate exact original source file/functions/tests for the next task.

While coding:

6. port source behavior, not a newly invented simplified substitute;
7. preserve source constants/formulas/rounding/edge cases unless a tested equivalent is intentionally chosen;
8. where source uses `coord_t`, keep integer source semantics unless proven otherwise;
9. never delegate runtime behavior back to old native/web code;
10. never hide unported behavior behind clickable no-ops or approximate output;
11. explicit unsupported behavior is preferable to a silent wrong implementation;
12. translate source tests alongside implementation;
13. preserve discovered source quirks unless a change is explicitly intended and proven acceptable by project requirement (default: preserve them).

Before ending a batch:

14. run every available analyzer/test/build and state exactly what ran;
15. update source→Dart→test traceability;
16. update `MIGRATION_STATUS.md`;
17. update `VALIDATION.md` when execution status changes;
18. update **this HANDOFF** with exact new symbols/branches and unresolved dependencies;
19. push all changes to `Bavk/QidiNewMorrax`;
20. update master Issue #1 when status/dependency ordering changes;
21. never claim completion while any required behavior remains pending/unverified.

### Ready-to-use prompt for another chat

> Continue development of `https://github.com/Bavk/QidiNewMorrax`. The requirement is a COMPLETE 1:1 Flutter/Dart rewrite of the supplied Qidi Flow 2.07.02.60 Pass28 application: the same application and implementation behavior on another language/runtime, with no function, algorithmic edge case, UI workflow, project/profile data, protocol flow, calibration, resource or testable quirk silently lost. The old C++/wxWidgets/React code is reference only and must not be the runtime backend. First read `migration/PARITY_CONTRACT.md`, the entire `docs/HANDOFF.md`, `migration/MIGRATION_STATUS.md`, `migration/TRACEABILITY.md`, `migration/VALIDATION.md`, latest commits and Issue #1. Locate exact original source functions/tests for the highest-priority unfinished dependency and port them to Dart/Flutter. Preserve integer coord_t semantics where the source uses them. Add translated/differential tests, do not accept “close enough”, do not mark unexecuted code as parity-verified, do not make fake stubs. Push changes to GitHub and update HANDOFF/status/traceability before finishing.

---

## 11. Binary asset publication gap

The audited local migration workspace contains thousands of original binary/runtime resources. Previous local hash verification reported 3,657/3,657 matching source bytes.

The GitHub connector does not expose Git LFS and the complete remote binary-resource publication has not yet been verified.

Rules:

- do not regenerate/recompress and call an asset identical;
- preserve exact bytes when exact preservation is required;
- after remote publication, hash remote/materialized bytes against `original_file_manifest.json` before marking `runtime_asset_verified` remotely.

---

## 12. Last handoff update — this batch

User requirement was re-confirmed as absolute: **FULL application 1:1 on Flutter/Dart, no lost function or implementation behavior.**

Added/refined in this batch:

- strict integer `coord_t` source geometry architecture;
- `SourcePoint2` / `SourceLine2` with source-sensitive rounding/intersection semantics;
- translated Line parallel/perpendicular regression fixtures;
- `SourcePolygon2` / `SourceExPolygon2` subset;
- `SourcePolyline2` with corrected constructor vs append semantics and explicit ArcFitter gap;
- `ThickPolyline2` moved to exact source-coordinate domain;
- source-shaped Voronoi topology model;
- `MedialAxis::validate_edge()` and half-edge traversal subset;
- `ExPolygon::medial_axis()` postprocessing in source units;
- `Flow` source math/config-width subset;
- `Extruder` source E/retraction + QIDI variant-resolution subset;
- `Surface` source semantics and QIDI copy/assignment quirks;
- `ExtrusionEntity` roles/strings/classifiers;
- `ExtrusionPath`, sloped/oriented path, MultiPath, Loop, Collection core semantics;
- source clone/copy quirks for sloped/oriented/MultiPath/Collection;
- exact floating-length `total_volume()` scaling;
- translated `test_extrusion_entity.cpp` flattening behavior plus role/clone/volume tests;
- expanded `migration/TRACEABILITY.md` symbol map;
- updated validation record with real GitHub Actions pre-runner failure rather than treating it as test failure.

Still explicitly unresolved after this batch:

- GitHub Actions runner allocation;
- QIDI ArcFitter / PathFittingData;
- full Clipper semantic proof;
- Boost-compatible segment Voronoi construction/repair/annotation;
- end-to-end medial axis;
- thin wall/gap fill and remaining classic perimeter;
- remaining ExtrusionLoop split/seam/coverage helpers;
- integration of source ExtrusionEntity model into full GCode/Preview.

No executable module added in this batch is promoted to `parity_verified` because the reference suite has not actually executed.
