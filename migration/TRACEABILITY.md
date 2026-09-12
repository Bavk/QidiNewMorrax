# Symbol-level 1:1 migration traceability

This ledger complements `original_file_manifest.json`. The file manifest prevents source files/assets from disappearing; this document tracks **behavior/symbol replacement**.

Status meanings are authoritative from `PARITY_CONTRACT.md`:

- `pending` — no real Dart replacement yet.
- `port_started` — only part of the source behavior exists.
- `implemented_unverified` — intended Dart replacement exists but source/reference parity has not actually run and passed.
- `parity_verified` — required source behavior has passing translated/differential reference tests.
- `runtime_asset_verified` — data preservation was byte-for-byte or explicitly canonically verified.

**No executable source symbol listed below is `parity_verified` yet because the current GitHub Actions jobs are failing before a runner/steps are allocated and this environment has no Flutter/Dart SDK.**

## Numeric / geometry foundation

| Source | Source symbol / behavior | Dart replacement | Reference tests | Status | Notes |
|---|---|---|---|---|---|
| `src/libslic3r/libslic3r.h` | `SCALING_FACTOR=0.00001`, `EPSILON=1e-4`, scaled-coordinate semantics | `lib/core/geometry/source_geometry.dart` `Slic3rUnits` | `test/core/geometry/source_geometry_test.dart` | `implemented_unverified` | Integer `coord_t` domain is now explicit; mm doubles are boundary/UI representations, not the exact slicer geometry domain. |
| `src/libslic3r/Point.hpp`, `Point.cpp` | integer point rotation and rounding used by geometry | `SourcePoint2.rotated()` | source-derived Line regression tests | `implemented_unverified` | Uses C++ `round()`-compatible away-from-zero implementation for rotation. |
| `src/libslic3r/Line.hpp`, `Line.cpp` | `length`, `orientation`, `direction`, `distance_to`, `perp_distance_to`, `parallel_to`, `perpendicular_to`, finite/infinite intersection | `SourceLine2` | translated `tests/libslic3r/test_geometry.cpp` Line cases | `implemented_unverified` | Preserves integer coordinate rounding/truncation where represented. |
| `src/libslic3r/Polygon.*`, `ExPolygon.*` | source-coordinate polygon / expolygon boundary representation used by medial axis | `lib/core/geometry/source_polygon.dart` | medial-axis postprocess fixtures | `port_started` | Only current required subset exists; full Polygon/ExPolygon API still pending. |
| `src/libslic3r/Polyline.hpp`, `Polyline.cpp` | `ThickPolyline`, `thicklines`, `reverse`, `rebase_at`, `get_width_at` | `lib/core/geometry/thick_polyline.dart` | `test/core/geometry/thick_polyline_test.dart` | `implemented_unverified` | Uses integer `SourcePoint2`; width vector invariant `2*N-2` preserved. |

## Clipper / boolean / offset geometry

| Source | Source symbol / behavior | Dart replacement | Reference tests | Status | Notes |
|---|---|---|---|---|---|
| source Clipper + `src/libslic3r/ClipperUtils.*` | union/difference/intersection/xor facade | `lib/core/geometry/clipper_geometry.dart` | initial translated `test_clipper_utils.cpp` cases | `implemented_unverified` | Current backend is pure-Dart Clipper2. Source uses Clipper 6.x + custom ClipperUtils semantics; every discrepancy must be fixed or the required algorithm ported directly. |
| `ClipperUtils` | `offset_ex`, holes, `offset2_ex`, opening/closing, default miter limit | `ClipperGeometry` | initial translated `test_clipper_offset.cpp` cases | `implemented_unverified` | Source `SCALING_FACTOR` and default miter limit 3.0 represented. Full original regression suite still pending. |

## Medial axis / thin-wall dependencies

| Source | Source symbol / behavior | Dart replacement | Reference tests | Status | Notes |
|---|---|---|---|---|---|
| `src/libslic3r/Geometry/Voronoi.hpp` | source-shaped vertex/cell/half-edge model consumed by MedialAxis | `lib/core/geometry/voronoi_topology.dart` | `medial_axis_core_test.dart` handcrafted topology fixtures | `port_started` | Boost segment-Voronoi **construction, repair and annotation are still pending**. No substitute skeletonizer is accepted. |
| `src/libslic3r/Geometry/MedialAxis.cpp` | `validate_edge()` | `lib/core/geometry/medial_axis_core.dart` | `test/core/geometry/medial_axis_core_test.dart` | `implemented_unverified` | Preserves PI/8 facing-edge rule, scaled epsilon, width filtering and source point conversion. |
| same | `process_edge_neighbors()` and active-edge chain traversal | `MedialAxisCore.buildFromTopology()` | chain/end-point fixtures | `implemented_unverified` | Requires real Boost-compatible topology constructor before end-to-end parity can be assessed. |
| `src/libslic3r/ExPolygon.cpp` | `ExPolygon::medial_axis()` endpoint extension, short-branch pruning and reconnect pass after raw build | `lib/core/geometry/medial_axis_postprocess.dart` | `test/core/geometry/medial_axis_postprocess_test.dart` | `implemented_unverified` | Now entirely in source `coord_t` units; contour extension line casts are preserved. |
| `src/libslic3r/Geometry/Voronoi.cpp` | `construct_voronoi`, `repair_voronoi`, inside/outside annotation / vertex categories | none complete | none | `pending` | Immediate dependency before `detect_thin_wall` can be enabled. |
| Boost.Polygon segment Voronoi behavior used by source | segment Voronoi construction and curved/primary edge semantics | none complete | source/reference fixtures pending | `pending` | Must reproduce source behavior in Dart; old native Boost cannot be runtime backend. |

## Flow / extrusion / G-code numeric foundation

| Source | Source symbol / behavior | Dart replacement | Reference tests | Status | Notes |
|---|---|---|---|---|---|
| `src/libslic3r/Flow.hpp`, `Flow.cpp` | role auto width, rounded rectangle spacing, bridge spacing, `mm3_per_mm`, `with_width`, `with_height`, `with_spacing`, `with_cross_section`, flow ratio | `lib/core/slicer/flow.dart` | translated `tests/fff_print/test_flow.cpp` math fixtures + source-formula tests | `implemented_unverified` | Source quirks intentionally retained, including supplied `with_cross_section()` formulas. |
| `Flow.cpp` | config width fallback / percentage resolution | `Flow.resolveExtrusionWidth()` | `flow_test.dart` fallback/percentage fixtures | `implemented_unverified` | Includes initial-layer zero fallback behavior. |
| `src/libslic3r/Extruder.cpp` | E/mm3 conversion, E state, retract/unretract, restart extra, relative-E behavior, used filament, speed fallback | `lib/core/gcode/extruder.dart` `ExtruderState` | `test/core/gcode/extruder_test.dart` | `implemented_unverified` | QIDI two-channel shared-extruder shape represented. |
| `src/libslic3r/PrintConfig.cpp` | `get_config_index_base`, filament variant resolution subset | `QidiConfigVariantResolver` | variant resolver tests | `implemented_unverified` | Full PrintConfig schema/expression pipeline remains pending. |
| native GCode pipeline | Flow cross-section + Extruder E/mm3 conversion used for extrusion length | `lib/core/gcode/gcode_writer.dart` basic writer | existing writer tests | `port_started` | Basic writer now uses source Flow/Extruder math but native GCode state/templates/retraction/cooling/path logic are still missing. |

## Surface / slicer semantic model

| Source | Source symbol / behavior | Dart replacement | Reference tests | Status | Notes |
|---|---|---|---|---|---|
| `src/libslic3r/Surface.hpp`, `Surface.cpp` | `SurfaceType`, flags, defaults, conversion helpers, `surfaces_could_merge`, type colors | `lib/core/slicer/surface.dart` | `test/core/slicer/surface_test.dart` | `implemented_unverified` | `stPerimeter` classification and merge predicate represented exactly. |
| supplied QIDI `Surface` additions | `counter_circle_compensation`, `holes_circle_compensation`; copy/assignment omission quirks | `Surface2.sourceCopy*`, `sourceAssignFrom()` | `surface_test.dart` | `implemented_unverified` | Source copy constructors reset omitted compensation fields; assignment leaves destination compensation untouched. |
| `src/libslic3r/PerimeterGenerator.cpp` | `process_classic()` onion-shell subset | `lib/core/slicer/classic_perimeter.dart` | `test/core/slicer/classic_perimeter_test.dart` | `port_started` | Constants/formulas represented for initial insets, QIDI narrow external width, alternate extra wall, spiral-vase island selection. Thin wall/gap-fill branch remains deliberately unsupported. |
| same | `detect_thin_wall`, medial-axis extraction, gap fill, remaining path ordering/overhang behavior | none complete | pending | `pending` | Do not remove `UnsupportedError` until the real source dependencies above are integrated and reference-tested. |
| Arachne | all Arachne wall generation | none complete | pending | `pending` | Full source module required. |

## Model/project formats

| Source behavior | Dart replacement | Status | Notes |
|---|---|---|---|
| STL ASCII/binary import | `lib/core/model_io/stl_parser.dart` | `port_started` | Existing Dart tests; full source error/repair semantics still need traceability. |
| OBJ import | `lib/core/model_io/obj_parser.dart` | `port_started` | Source parity coverage incomplete. |
| AMF / ZIP.AMF | `lib/core/model_io/amf_parser.dart` | `port_started` | Units/constellation implemented; full source behavior still to verify. |
| package-aware 3MF with external models/components/build transforms and unknown entry retention | `three_mf_parser.dart`, `three_mf_writer.dart` | `port_started` | Full project/QIDI/Bambu metadata serialization parity still open. |
| STEP + source build-enabled Assimp formats | none complete | `pending` | Must be implemented in Dart, not delegated to old native importer. |

## Device / UI / profiles

These areas already have Flutter/Dart foundations but still require finer symbol-level mapping before they can move beyond `port_started`:

- local QIDI SSDP discovery;
- Moonraker JSON-RPC and object subscription;
- typed/raw printer state;
- QIDI/Klipper commands;
- QIDI Box commands;
- files/timelapse;
- profile loading/inheritance/`compatible_printers`;
- PO localization;
- Prepare/Preview/Device Flutter screens.

Cloud/P2P/account, camera, HMS, firmware/update, every device capability matrix, complete UI state/action parity, every calibration flow and desktop integration remain open.

## Rule for updating this file

For every meaningful port batch:

1. identify exact original source file + symbol/branch;
2. list exact Dart symbol;
3. list translated/differential reference tests;
4. keep status at `port_started` or `implemented_unverified` until tests **actually run**;
5. record any source quirk intentionally preserved;
6. add pending dependent symbols discovered during the port.

A source file being “covered” is not sufficient if some functions/branches in it remain unmapped.