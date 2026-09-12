# Migration status — STRICT 1:1 Flutter/Dart rewrite

The authoritative acceptance contract is [`PARITY_CONTRACT.md`](PARITY_CONTRACT.md).

The target is not “similar functionality”, “feature parity in common cases”, or “a Flutter replacement client”. The target is the **same supplied Qidi Flow 2.07.02.60 Pass28 application, completely reimplemented in Flutter + Dart, with no relevant source function, behavior, data contract, algorithmic edge case, UI workflow, protocol operation, calibration flow or runtime asset silently lost**.

The old C++/wxWidgets/React application is specification/reference material only. It must not remain the runtime backend through FFI, old binaries/libraries, subprocesses, services or embedded legacy WebViews.

## Status vocabulary

- `pending` — no real Dart replacement yet.
- `port_started` — only part of the source behavior exists.
- `implemented_unverified` — intended replacement exists, but required source/reference tests have not actually executed and passed.
- `parity_verified` — required source behavior/edge cases are covered by passing translated/differential tests.
- `runtime_asset_verified` — data is preserved byte-for-byte or through an explicitly documented canonical transformation.

A similarly named Dart file or visually similar Flutter screen never closes a source item by itself.

## Top-level completion gates

All gates remain OPEN:

1. **Formats/project persistence 1:1** — every source-enabled format, project/package metadata, validation/repair/warning path and lossless round trip.
2. **Scene/editor 1:1** — hierarchy, selection, gizmos, transforms, cut/split/repair/boolean, arrange/orient, modifiers, painting, text/emboss, multi-plate, undo/redo, shortcuts/interactions.
3. **Slicer/toolpath 1:1** — numeric geometry semantics, classic/Arachne walls, thin walls/gap fill, surfaces, infills, bridges, supports, seams/overhangs, travel/retraction/wipe, flow/speed/cooling, multi-material/purge structures, adaptive layers, ironing, brim/skirt/raft, templates/postprocessing, estimates.
4. **Preview 1:1** — complete source feature/tool/layer classifications, statistics, estimates and interactions.
5. **Profiles/presets 1:1** — schema, inheritance, expressions, defaults, compatibility, validation, user presets/import/export.
6. **Device/cloud 1:1** — LAN, Moonraker, account/cloud/P2P, printer capability/state machines, QIDI Box/AMS, files/timelapses, camera, HMS, firmware/update, reconnect/offline restoration.
7. **Calibration 1:1** — every wizard, validation, generated model/toolpath and result flow.
8. **Desktop integration/release 1:1** — runners, file associations, drag/drop, single-instance, updater, packaging, shell/thumbnail integrations used by source.
9. **UI/localization/accessibility 1:1** — every screen/dialog/menu/control/state, visibility/enabled logic, keyboard/mouse workflow, shipped strings/resources.
10. **Reference tests 1:1** — applicable original tests translated plus differential/golden fixtures for observable behavior not covered by source tests.

## Important numeric architecture correction

A strict-source audit established that libslic3r’s 2D slicer geometry is fundamentally an integer `coord_t` domain, not millimeter `double` geometry:

- `SCALING_FACTOR = 0.00001` mm;
- 100000 source units/mm;
- `EPSILON = 1e-4`;
- `SCALED_EPSILON = 10` source units.

This affects rotations, intersections, tolerances, Voronoi conversion, thin walls and regression fixtures. A dedicated exact-source domain now exists:

- `SourcePoint2` / `SourceLine2`;
- `SourcePolygon2` / `SourceExPolygon2`;
- `SourcePolyline2`;
- `ThickPolyline2`.

Millimeter-double helpers may still be useful at import/UI boundaries, but they cannot by themselves establish 1:1 slicer geometry semantics.

## Current geometry status

### Point / Line / Polyline

- integer source units and scaling constants: **implemented_unverified**;
- source Point rotation rounding and Line orientation/distance/parallel/perpendicular/intersection subset: **implemented_unverified**;
- translated `test_geometry.cpp` parallel/perpendicular regression cases: authored, not executed;
- linear Polyline constructor/append/reverse/clip/extend behavior: **implemented_unverified**;
- QIDI ArcFitter / `PathFittingData` / fitting-aware split/clip/reverse: **pending** and intentionally not approximated.

### Clipper / ClipperUtils

- Dart union/difference/intersection/xor/offset facade: **implemented_unverified**;
- source scale and default miter-limit handling represented;
- initial `test_clipper_offset.cpp` / `test_clipper_utils.cpp` cases translated;
- current backend is pure-Dart Clipper2 while supplied source uses Clipper 6.x plus custom `ClipperUtils` semantics;
- **full source regression suite and semantic discrepancies remain open**. If Clipper2 cannot reproduce them, required source behavior must be directly ported.

### Medial axis / thin-wall dependency chain

Implemented but unverified:

- exact `ThickPolyline` source representation/invariants;
- source-shaped Voronoi vertex/cell/half-edge topology model;
- application-owned `MedialAxis::validate_edge()` branch logic;
- PI/8 facing-segment rule, scaled epsilon and min/max-width checks;
- `process_edge_neighbors()`-style active half-edge traversal;
- source Voronoi double → `Point(coord_t)` nearest-even `lrint` behavior;
- `ExPolygon::medial_axis()` post-pass: endpoint extension, short-branch pruning and reconnect logic in source units.

Still **pending and blocking real thin-wall parity**:

- Boost.Polygon-compatible segment Voronoi construction in Dart;
- source `construct_voronoi` wrapper behavior;
- `repair_voronoi`;
- inside/outside/contour vertex annotation/categories;
- curved/primary edge handling/discretization required by source.

Therefore `detect_thin_wall` in classic perimeter remains deliberately unsupported. No generic skeletonizer is accepted as a hidden substitute.

## Flow / extrusion numeric foundation

### Flow

`Flow.hpp/.cpp` mathematical/config-width subset is **implemented_unverified**:

- role auto widths;
- rounded-rectangle spacing / cross section;
- bridge spacing `+0.05`;
- `mm3_per_mm`;
- `with_width`, `with_height`, `with_spacing`, `with_cross_section`, flow ratio;
- source config-width fallback / percentage behavior, including initial-layer fallback quirks.

Source-derived `test_flow.cpp` math fixtures are authored but not executed.

### Extruder / QIDI config variant subset

`Extruder.cpp` state/math subset is **implemented_unverified**:

- E/mm3 = filament-flow-ratio / filament cross section;
- absolute/relative E tracking;
- retract/unretract/restart-extra behavior;
- used-filament semantics;
- speed fallback;
- QIDI two-channel shared-extruder shape;
- QIDI `get_config_index_base` / filament variant resolution subset and exact variant labels.

The basic Dart G-code foundation now consumes source Flow + Extruder volume math, but the full native GCode state machine/templates/retraction/travel/cooling/acceleration path is still **pending/port_started**.

## Surface semantic model

`Surface.hpp/.cpp` is **implemented_unverified** for the current represented subset:

- exact SurfaceType ordering/classification;
- defaults, thickness/layers/bridge angle/extra perimeters;
- conversion helpers and type colors;
- `surfaces_could_merge()` comparison set;
- supplied QIDI `counter_circle_compensation` / `holes_circle_compensation` fields;
- source copy-constructor quirk where those QIDI compensation members reset because they are omitted;
- source assignment quirk where destination compensation state is left untouched.

This model is now available to replace simplified `List<ExPolygon>` assumptions in later slicer stages, but full downstream surface generation/classification remains pending.

## ExtrusionEntity semantic model

`ExtrusionEntity.hpp/.cpp` and collection behavior are now **port_started / implemented_unverified**:

- exact `ExtrusionRole` ordering and source display strings;
- perimeter/infill/solid/bridge/support role classifiers;
- `CustomizeFlag` and loop-role bit flags;
- `ExtrusionPath` geometry/state fields including `overhang_degree`, `curve_degree`, `mm3_per_mm`, width, height, smooth speed, reverse and force-no-extrusion flags;
- source `set_overhang_degree` / `set_curve_degree` clamp/role behavior;
- exact `can_merge()` comparison set, including fields it intentionally ignores;
- `total_volume()` using floating source path length × `SCALING_FACTOR` without coordinate rounding;
- sloped/oriented path source clone behavior, including the source slicing quirk for sloped paths and type-preserving oriented clone;
- `ExtrusionMultiPath`, `ExtrusionLoop`, `ExtrusionEntityCollection` core ordering/reverse/volume/role behavior;
- source copy-constructor quirks where MultiPath/Collection base customize/cooling fields reset;
- collection flatten behavior translated from `test_extrusion_entity.cpp`, including `preserve_ordering && no_sort` nested-collection retention;
- source supportTransition inclusion when filtering for supportMaterial.

Still pending in this area:

- ArcFitter-aware Polyline split/simplify metadata;
- full loop split/clip/seam behavior;
- `polygons_covered_by_width/spacing()` on exact source-coordinate boolean/offset geometry;
- further QIDI loop/overhang utility methods and downstream G-code/preview consumption.

## Classic perimeter

A source-formula subset of `PerimeterGenerator::process_classic()` remains **port_started**:

- common inset overlap tolerance `0.4`;
- QIDI smaller external inset overlap tolerance `0.22`;
- narrow-loop threshold `10`;
- first external centerline inset;
- external→internal spacing branch;
- alternate-extra-wall behavior;
- spiral-vase island selection;
- source one-coordinate-unit safety adjustment.

Remaining classic perimeter work depends on exact MedialAxis/Voronoi, gap fill and verified Clipper semantics.

## Existing broader Flutter foundations

Still `port_started`, not top-level complete:

- STL/OBJ/AMF/ZIP.AMF and package-aware 3MF preservation;
- profile loading/inheritance/`compatible_printers`;
- runtime PO localization;
- QIDI SSDP + Moonraker + local command/device foundations;
- QIDI Box commands/files/timelapse foundations;
- triangle-plane slicing;
- basic line infill/toolpath/basic G-code;
- Prepare/Preview/Device Flutter shell areas.

## Validation blocker

The local environment has no Flutter/Dart SDK. GitHub Actions workflow exists, but checked jobs currently fail **before runner allocation** (`steps=[]`, `runner_id=0`), including after replacing the third-party Flutter setup action with direct cloning of the official Flutter tag. Therefore:

- analyzer has not run;
- Dart/Flutter tests have not run;
- no new executable source module is `parity_verified`.

See `VALIDATION.md`.

## Immediate next source dependency order

1. Resolve GitHub Actions runner/account/repository infrastructure so authored tests actually execute.
2. Continue translating source Point/Line/Polyline and Clipper/ClipperUtils regression fixtures; fix every discrepancy.
3. Port QIDI ArcFitter / `PathFittingData` semantics used by Polyline and ExtrusionEntity.
4. Port Boost-compatible segment Voronoi construction + source repair/annotation in Dart.
5. Integrate full medial axis into `ExPolygon::medial_axis`; then enable `detect_thin_wall` and gap fill only after passing references.
6. Resume `PerimeterGenerator::process_classic()` line-by-line; then Arachne/surfaces/fill.
7. Expand `ExtrusionEntity` into the native G-code/Preview pipeline instead of the current simplified feature model.
8. Continue scene/editor/project/device/cloud/calibration/OS/UI parity in parallel after core dependency truth is established.

No part of this ordering permits declaring a module complete because it “looks equivalent”.
