# Symbol-level 1:1 migration traceability

This ledger complements `original_file_manifest.json`. The file manifest prevents source files/assets from disappearing; this document tracks **source symbol / behavior replacement**.

Status meanings come from `PARITY_CONTRACT.md`:

- `pending` — no real Dart replacement yet;
- `port_started` — only part of the source behavior exists;
- `implemented_unverified` — intended Dart implementation exists but required source/reference tests have not actually run and passed;
- `parity_verified` — required source behavior has passing translated/differential tests;
- `runtime_asset_verified` — preserved data was verified byte-for-byte or by an explicit canonical transformation.

**No executable source symbol below is `parity_verified` yet.** The current environment has no Flutter/Dart SDK and checked GitHub Actions jobs fail before runner allocation (`steps=[]`, `runner_id=0`).

## Numeric / geometry foundation

| Source | Source symbol / behavior | Dart replacement | Reference tests | Status | Notes |
|---|---|---|---|---|---|
| `src/libslic3r/libslic3r.h` | `SCALING_FACTOR=0.00001`, `EPSILON=1e-4`, `SCALED_EPSILON=10` | `lib/core/geometry/source_geometry.dart` `Slic3rUnits` | `source_geometry_test.dart` | `implemented_unverified` | Exact slicer domain is integer `coord_t`; mm doubles are boundary/UI representations. |
| `Point.hpp/.cpp` | integer Point storage, rotate rounding used by geometry | `SourcePoint2` | translated Line rotation-sensitive fixtures | `implemented_unverified` | Rotation uses C++ `round()` compatible away-from-zero behavior. |
| `Line.hpp/.cpp` | vector/length/orientation/direction/distance/perp-distance/parallel/perpendicular/finite+infinite intersection subset | `SourceLine2` | translated `tests/libslic3r/test_geometry.cpp` Line cases | `implemented_unverified` | Integer result casts/truncation represented; source overflow-range guard still needs dedicated coverage. |
| `MultiPoint.cpp`, `Polyline.hpp/.cpp` | Polyline point constructor, QIDI append join-dedup, reverse, length, lines, linear clip/extend | `lib/core/geometry/source_polyline.dart` | `source_polyline_test.dart` | `implemented_unverified` | Constructor preserves existing adjacent duplicates; append only suppresses equal join endpoint. |
| QIDI `Polyline` additions | ArcFitter / `PathFittingData`, fitting-aware reverse/clip/split/simplify | no complete replacement | explicit `UnsupportedError` for arc simplify | `pending` | Must be ported; no silent linearization accepted. |
| `Polygon.*`, `ExPolygon.*` | source-coordinate polygon/expolygon boundary subset used by medial axis/surfaces | `lib/core/geometry/source_polygon.dart` | medial-axis/surface fixtures | `port_started` | Full Polygon/ExPolygon API still pending. |
| `Polyline.hpp/.cpp` | `ThickPolyline`, `thicklines`, `reverse`, `rebase_at`, `get_width_at`, width cardinality | `lib/core/geometry/thick_polyline.dart` | `thick_polyline_test.dart` | `implemented_unverified` | Points are integer source coords; widths are scaled `coordf_t`. |

## Clipper / boolean / offset geometry

| Source | Source symbol / behavior | Dart replacement | Reference tests | Status | Notes |
|---|---|---|---|---|---|
| source Clipper + `ClipperUtils.*` | union/difference/intersection/xor facade | `lib/core/geometry/clipper_geometry.dart` | initial translated `test_clipper_utils.cpp` | `implemented_unverified` | Current backend is pure-Dart Clipper2. Source uses Clipper 6.x plus custom semantics; replacement remains provisional until full source regression coverage. |
| `ClipperUtils.*` | offsets, holes, `offset2`, opening/closing, default miter limit | `ClipperGeometry` | initial translated `test_clipper_offset.cpp` | `implemented_unverified` | Source scaling represented. Exact source-coordinate facade still needs broader integration/reference proof. |

## Medial axis / thin-wall dependency chain

| Source | Source symbol / behavior | Dart replacement | Reference tests | Status | Notes |
|---|---|---|---|---|---|
| `Geometry/Voronoi.hpp` | source-shaped segment/cell/vertex/half-edge data consumed by MedialAxis | `voronoi_topology.dart` | handcrafted topology fixtures | `port_started` | Construction/repair/annotation still missing. Voronoi doubles are in scaled source-coordinate units. |
| `Geometry/MedialAxis.cpp` | `validate_edge()` | `medial_axis_core.dart` | `medial_axis_core_test.dart` | `implemented_unverified` | PI/8 rule, scaled epsilon, width filtering and lrint-compatible vertex conversion represented. |
| same | valid-edge selection + `process_edge_neighbors()` traversal | `MedialAxisCore.buildFromTopology()` | chain/end-point fixtures | `implemented_unverified` | Requires real Boost-compatible topology builder for end-to-end parity. |
| `ExPolygon.cpp` | `ExPolygon::medial_axis()` endpoint extension, short-branch pruning and reconnect post-pass | `medial_axis_postprocess.dart` | `medial_axis_postprocess_test.dart` | `implemented_unverified` | Runs in source coord units; extension line casts represented. |
| `Geometry/Voronoi.cpp/.hpp` | `construct_voronoi`, `repair_voronoi`, inside/outside/on-contour annotation/categories | none complete | pending | `pending` | Immediate blocker for real thin-wall/gap-fill. |
| Boost.Polygon behavior used by source | segment Voronoi construction and primary/curved edge semantics | none complete | source/reference fixtures pending | `pending` | Must be reproduced in Dart; old Boost/native code cannot be runtime backend. |

## Flow / extrusion numeric foundation

| Source | Source symbol / behavior | Dart replacement | Reference tests | Status | Notes |
|---|---|---|---|---|---|
| `Flow.hpp/.cpp` | role auto width, rounded-rectangle spacing, bridge spacing, `mm3_per_mm`, width/height/spacing/cross-section/ratio mutations | `lib/core/slicer/flow.dart` | translated `tests/fff_print/test_flow.cpp` math cases | `implemented_unverified` | Supplied source formula quirks intentionally retained. |
| `Flow.cpp` | config extrusion-width fallback and percentage resolution | `Flow.resolveExtrusionWidth()` | `flow_test.dart` | `implemented_unverified` | Includes initial-layer fallback behavior. |
| `Extruder.cpp` | E/mm3, E state, retract/unretract/restart-extra, used filament, speed fallback | `lib/core/gcode/extruder.dart` | `extruder_test.dart` | `implemented_unverified` | QIDI shared-extruder two-channel shape represented. |
| `PrintConfig.cpp` subset | QIDI `get_config_index_base`, filament variant resolution | `QidiConfigVariantResolver` | variant resolver tests | `implemented_unverified` | Full PrintConfig schema/expression pipeline pending. |
| native GCode pipeline | basic volume conversion uses source Flow + Extruder math | `gcode_writer.dart` foundation | writer tests | `port_started` | Native GCode state/templates/retract/travel/cooling/speed/acceleration still pending. |

## Surface semantic model

| Source | Source symbol / behavior | Dart replacement | Reference tests | Status | Notes |
|---|---|---|---|---|---|
| `Surface.hpp/.cpp` | SurfaceType ordering, flags, defaults, conversion helpers, merge predicate, colors | `lib/core/slicer/surface.dart` | `surface_test.dart` | `implemented_unverified` | `stPerimeter` classification represented exactly. |
| supplied QIDI Surface members | circle compensation members and copy/assignment omission quirks | `Surface2.sourceCopy*`, `sourceAssignFrom()` | `surface_test.dart` | `implemented_unverified` | Copy resets omitted compensation fields; assignment leaves destination values untouched. |

## ExtrusionEntity semantic model

| Source | Source symbol / behavior | Dart replacement | Reference tests | Status | Notes |
|---|---|---|---|---|---|
| `ExtrusionEntity.hpp` | exact `ExtrusionRole` ordering; perimeter/infill/solid/bridge/support classifiers | `lib/core/slicer/extrusion_entity.dart` | `extrusion_entity_test.dart` | `implemented_unverified` | Includes `erFlush`, `erMixed`, sentinel `erCount`. |
| `ExtrusionEntity.cpp` | `role_to_string` / `string_to_role` | `extrusionRoleToString`, `extrusionRoleFromString` | role-string tests | `implemented_unverified` | Source English labels retained exactly. |
| `ExtrusionEntity` base | `customize_flag`, `cooling_node`, virtual flags/contracts subset | `ExtrusionEntity2` | clone/collection fixtures | `port_started` | Coverage/polygon APIs and some utility methods remain open. |
| `ExtrusionPath` | fields/defaults, copy, reverse, role, can-reverse, force-no-extrusion, overhang/curve clamps, volume, `can_merge()` comparison set | `ExtrusionPath2` | path tests | `implemented_unverified` | `total_volume()` uses floating source length × `SCALING_FACTOR`; can-merge intentionally ignores polyline/overhang/customize/cooling. |
| `ExtrusionPathSloped` | slope state/interpolation; inherited base clone slicing quirk | `ExtrusionPathSloped2` | clone type fixture | `implemented_unverified` | Source does not override clone, so clone becomes base ExtrusionPath; preserved. |
| `ExtrusionPathOriented` | non-reversible oriented path and type-preserving clone | `ExtrusionPathOriented2` | clone type fixture | `implemented_unverified` | Explicit Dart clone preserves oriented dynamic type. |
| `ExtrusionMultiPath` | path vector, single-path canReverse inheritance, vector ctor default reverse, reverse/order, continuous as-polyline, volume | `ExtrusionMultiPath2` | multipath tests | `implemented_unverified` | Explicit source copy ctor resets base customize/cooling; preserved. |
| `ExtrusionLoop` subset | path container, role, winding, reverse, polygon/as-polyline, volume, speed-discontinuity role | `ExtrusionLoop2` | loop/collection tests | `port_started` | split/clip/seam/overhang utility methods still pending. |
| `ExtrusionEntityCollection.*` | role mixing, no-sort/can-sort/can-reverse, recursive count, reverse semantics, flatten/preserve-ordering, volume | `ExtrusionEntityCollection2` | translated `test_extrusion_entity.cpp` flatten cases | `implemented_unverified` | Source copy ctor resets base customize/cooling; loops are not individually reversed during collection reverse. |
| helper filtering | supportTransition included when filtering supportMaterial | `filterByExtrusionRole()` | filter fixture | `implemented_unverified` | Dart ownership differs, but behavioral selection is source-shaped. |
| `ExtrusionPath::polygons_covered_by_width/spacing` | exact path coverage geometry | none exact | pending | `pending` | Depends on verified exact-source boolean/offset geometry. |
| `ExtrusionLoop` remaining | `split_at_vertex`, `split_at`, clipping, seam-angle/overhang methods, fitting metadata preservation | none complete | pending | `pending` | ArcFitter-aware Polyline split is a dependency. |

## Classic perimeter

| Source | Source symbol / behavior | Dart replacement | Reference tests | Status | Notes |
|---|---|---|---|---|---|
| `PerimeterGenerator.cpp` | `process_classic()` onion-shell formula subset | `classic_perimeter.dart` | `classic_perimeter_test.dart` | `port_started` | Includes tolerances 0.4 / QIDI 0.22, first/internal insets, alternate wall, spiral-vase island subset. |
| same | `detect_thin_wall`, medial-axis extraction, gap fill, remaining path/overhang/order logic | no complete integration | pending | `pending` | `UnsupportedError` remains intentional until exact dependencies are ready. |
| Arachne source modules | variable-width wall generation | none complete | pending | `pending` | Full module required. |

## Model/project formats

| Source behavior | Dart replacement | Status | Notes |
|---|---|---|---|
| STL ASCII/binary | `stl_parser.dart` | `port_started` | Existing tests; full source repair/warning behavior not fully mapped. |
| OBJ | `obj_parser.dart` | `port_started` | Source parity coverage incomplete. |
| AMF / ZIP.AMF | `amf_parser.dart` | `port_started` | Units/constellation represented; full parity open. |
| package-aware 3MF | `three_mf_parser.dart`, `three_mf_writer.dart` | `port_started` | External parts/components/build transforms/unknown entry retention represented; full project metadata persistence open. |
| STEP and source-enabled Assimp formats | none complete | `pending` | Must be reimplemented in Dart; old native importer cannot be runtime backend. |

## Device / profiles / UI / calibration / OS

Existing Flutter foundations remain `port_started` and need finer symbol mapping:

- QIDI SSDP discovery;
- Moonraker JSON-RPC/subscriptions;
- typed/raw printer state;
- QIDI/Klipper commands and QIDI Box operations;
- files/timelapse;
- profile inheritance/`compatible_printers`;
- PO localization;
- Prepare/Preview/Device shell and interactions.

Still major pending areas include cloud/P2P/account, camera, HMS, firmware/update, complete device matrices, every calibration flow, complete editor/project behavior, exact UI state/workflow parity and desktop integration/release.

## Validation status

GitHub workflow exists but checked jobs fail before runner allocation; no steps execute. See `VALIDATION.md`. Therefore authored tests are not execution evidence yet.

## Mandatory update rule

Every meaningful development batch must:

1. identify exact source file + symbol/branch;
2. identify exact Dart symbol;
3. add/translate source/reference tests;
4. keep status `port_started`/`implemented_unverified` until tests actually run;
5. record source quirks intentionally preserved;
6. add newly discovered dependencies/pending symbols;
7. update `docs/HANDOFF.md`, this ledger, and `MIGRATION_STATUS.md` before ending.
