# Traceability ledger — strict 1:1 Flutter/Dart rewrite

The source of truth for acceptance is [`PARITY_CONTRACT.md`](PARITY_CONTRACT.md). This ledger records only the scope that exists in Dart and the evidence attached to that exact scope.

## Status meanings

- `pending` — no real Dart replacement yet.
- `port_started` — source behavior exists only in part.
- `implemented_unverified` — intended implementation exists but lacks executed source/reference evidence.
- `parity_verified` — the explicitly scoped behavior has passing translated, differential, or source/oracle tests.
- `runtime_asset_verified` — preserved runtime data is byte-for-byte verified or covered by a documented canonical transform.

`parity_verified` never promotes an entire containing subsystem unless every required source branch is represented and tested.

## Executed validation checkpoint

Current normal GitHub Actions checkpoint:

- `.github/workflows/flutter-parity.yml` run `34682700807` (#203) on code commit `b6809d50912e5135a3d4851177093934a715adf9`;
- Flutter `3.47.2`, Dart `3.13.2`;
- `flutter analyze` = **No issues found**;
- `flutter test --reporter expanded` = **248/248 passing**;
- job conclusion = **success**.

Relevant independently green intermediate runs in the same source chain:

- run `34682605150` (#201): speed-graded recursive traversal;
- run `34682507521` (#199): speed-grading splitter branch;
- run `34682411840` (#197): standalone classic overhang degree helpers;
- run `34682165435` (#194): automatic overhang state from raw lower slices;
- run `34681985037` (#191): **231/231**, source lower-series generation and distance boundaries;
- run `34681547786` (#183): **224/224**, no-speed overhang splitter integrated into recursive traversal;
- run `34680042259` (#172): classic wall-sequence helper/source quirks;
- run `34678782013` (#147): thin-wall MedialAxis output → source variable-width extrusion integration;
- run `34678922719` (#150): source open-polyline offset and `polygons_covered_by_width()` dispatch.

## Numeric / geometry traceability

| Source area | Dart replacement | Evidence | Status | Remaining scope |
|---|---|---|---|---|
| libslic3r scaling constants / integer Point | `Slic3rUnits`, `SourcePoint2` | source-formula geometry tests | `parity_verified` | Broader source geometry APIs remain outside this row. |
| `Line` represented math | `SourceLine2` | translated/source-formula Line tests | `parity_verified` | Only represented Line methods are claimed. |
| `Polygon::contains()` / Clipper1 PointInPolygon | `SourcePolygon2.pointInPolygon()` / `contains()` | 0/1/-1, boundary, orientation, concave fixtures | `parity_verified` | Broader Polygon APIs remain open. |
| QIDI `Polyline` append/clip/extend/reverse and fitting metadata | `SourcePolyline2`, `PathFittingData2` | Polyline regression tests including exact-length and arc metadata quirks | `parity_verified` | Other Polyline APIs/consumers pending as encountered. |
| Arc fitting / Douglas–Peucker represented helpers | `SourceArcFitter2`, `SourceCircle2`, `SourceArcSegment2` | ArcFitter/Circle/ArcSegment tests plus classic closed-polygon gap consumer | `parity_verified` | Broader arc/simplification consumers still depend on later toolpath stages. |
| `ThickPolyline` represented behavior | `ThickPolyline2` | width-cardinality, reverse, `rebase_at`, `get_width_at` tests | `parity_verified` | Additional downstream consumers may expose more quirks. |
| Boost.Polygon robust numeric helpers | `BoostRobustFpt2`, extended-int/sqrt helpers | Boost 1.83 C++ oracle goldens | `parity_verified` | Only helpers currently required by direct Voronoi port are claimed. |
| Boost site/circle predicates and PPP/PPS/PSS/SSS formation | `BoostVoronoiPredicates2`, circle-formation ports | Boost 1.83 oracle fixtures incl. extreme int32 cases | `parity_verified` | Additional unrepresented Boost cases may still be added. |
| Boost direct Fortune construction | source Boost Voronoi builder + topology adapter | point/segment construction tests, square full half-edge golden, regression inputs | `parity_verified` | Broader source inputs not yet represented remain open. |
| QIDI Voronoi issue detection / rotation repair / annotation | `SourceVoronoiDiagram2`, annotator/utils | repair-angle, endpoint-remap, contour-category tests | `parity_verified` | Other consumers may expose additional source cases. |
| MedialAxis represented core and ExPolygon postprocess | `MedialAxisCore`, `SourceMedialAxis2`, `SourceExPolygonMedialAxis2` | edge validation/traversal/postprocess, thin-wall and gap-fill composition tests | `parity_verified` | Other MedialAxis callers may expose additional branches. |
| Remaining Polygon/ExPolygon geometry APIs | mixed partial Dart types | no complete reference matrix | `port_started` | Continue as source consumers require them. |

Implementation constraints that must not be simplified:

- Boost `uint64_t` wraparound and double-bit ULP comparisons are emulated with `BigInt` at the Dart boundary where signed native `int` would cross bit 63.
- PPP `robust_cross_product` operand ordering remains literal to Boost.Polygon 1.83, even if a reordered expression appears mathematically cleaner.

## Clipper / boolean / offset traceability

| Source area | Dart replacement | Evidence | Status | Remaining scope |
|---|---|---|---|---|
| translated boolean fixtures | `ClipperGeometry` over pure-Dart Clipper2 | translated intersection/union/difference fixtures | `parity_verified` | Full ClipperUtils source regression matrix pending. |
| translated constant offset fixtures | `offsetPolygonsEx`, `offsetExPolygon` | positive/negative box and hole fixtures | `parity_verified` | More join/end/fill/degenerate combinations pending. |
| Clipper1 miter-limit compatibility | adapter `_clipper2MiterLimit` | source fixture using low miter limit | `parity_verified` | Keep adapter boundary explicit; do not rely on Clipper2 default semantics. |
| positive ExPolygon hole reconstruction | explicit contour/hole offset + difference | expanded-hole fixture | `parity_verified` | More multi-hole/nested cases pending. |
| open Polyline offset for covered-width geometry | `offsetSourceOpenPolyline` | exact source-coordinate square/open-butt fixture | `parity_verified` | Other open-line wrappers/end types remain open. |
| QIDI Clipper2 open-subject intersection/difference | `intersectionSourceOpenPolylines`, `differenceSourceOpenPolylines` | source-integer line fixtures + duplicated-start seam golden | `parity_verified` | Other open/closed mixed operations remain open. |
| classic lower-support closed polygon offset subset | `SourceClassicOverhangSupport2` source-coordinate offset path | float32/scaling, positive/negative box and opposite-winding hole fixtures; run #191 | `parity_verified` | Broader Clipper1 offset/cleanup/degenerate regression space remains open. |
| complete Slic3r/QIDI ClipperUtils | partial adapter | incomplete original regression coverage | `port_started` | Translate remaining source tests/wrappers as new consumers require them. |

## Slicer semantic-model traceability

| Source area | Dart replacement | Evidence | Status | Remaining scope |
|---|---|---|---|---|
| Flow represented formulas/config resolution | `Flow`, config snapshot helpers | translated/source-formula Flow tests | `parity_verified` | Full config schema/expression integration pending. |
| Extruder represented E/retract/variant behavior | `ExtruderState`, `QidiConfigVariantResolver` | exact state/math and QIDI resolver tests | `parity_verified` | Full native print-state integration pending. |
| Surface represented classification/copy/assignment quirks | Dart Surface model | source-style Surface tests | `parity_verified` | Surface-processing pipeline remains incomplete. |
| ExtrusionRole/Path/MultiPath/Loop/Collection represented behavior | Dart extrusion entity model | source-semantic regression tests | `parity_verified` | Remaining entity operations/consumers pending. |
| QIDI/libslic3r variable-width ThickPolyline conversion | `SourceVariableWidth2` | translated/source-specific width segmentation and loop tests | `parity_verified` | Later unrepresented consumers remain open. |
| `ExtrusionEntity::polygons_covered_by_width()` represented dispatch | `extrusion_covered_geometry.dart` + integer open-line Clipper adapter | exact path coverage fixture + recursive collection/iterable fixture | `parity_verified` | Other source entity geometry methods remain open. |
| Linear infill current subset | `LinearInfill` | square/hole clipping fixtures | `implemented_unverified` | Not enough source-pattern/reference coverage for parity claim. |

## Classic perimeter traceability

| Source behavior | Dart replacement | Evidence | Status | Remaining scope |
|---|---|---|---|---|
| common onion-shell inset formulas | `ClassicPerimeterShellGenerator` | equal-flow source-formula fixture | `parity_verified` | Later `process_classic()` stages remain open. |
| alternate extra wall count | same | odd/even layer test | `parity_verified` | Other wall-count/config branches still open. |
| QIDI smaller-external-width decision | same | narrow-loop regression | `parity_verified` | Broader source cases still open. |
| source quirk `last = offsets` | same | regression proving smaller-width outer loop does not seed inner loops | `parity_verified` | Keep exact behavior in future refactors. |
| `detect_thin_wall` geometric branch | Clipper difference/opening → `SourceExPolygonMedialAxis2` → `ThickPolyline2` | end-to-end thin-wall tests | `parity_verified` | Other thin-wall source cases may still be added. |
| source external Flow dependency | `ClassicPerimeterSettings.externalPerimeterFlow` | required-input + converted-extrusion tests | `parity_verified` | Full config caller wiring remains later integration work. |
| variable-width conversion after thin-wall MedialAxis | `SourceVariableWidth2` wired into `ClassicPerimeterResult.thinWallExtrusions` | run #147 end-to-end test | `parity_verified` | Thin walls are now also integrated into traversal chaining. |
| classic gap collection extra iteration | source-literal i>0 gap difference in `ClassicPerimeterShellGenerator` | classic gap fixture | `parity_verified` | More complex gap geometries should be added as later regressions appear. |
| classic gap region filtering/MedialAxis/variable width | opening + max-width subtraction + DP + MedialAxis + length filter + `SourceVariableWidth2` | classic gap fixture, run #152 | `parity_verified` | Full surrounding process_classic path remains incomplete. |
| gap covered-width subtraction from `last` | `ExtrusionEntitiesCoveredGeometry2` + `differenceEx` | covered-width unit tests + classic gap end-to-end run | `parity_verified` | Other covered-area source helpers remain open. |
| loop nesting / `is_internal_contour()` | `SourcePerimeterLoop2`, `SourceClassicPerimeterLoopNester2`, `SourcePolygon2.contains` | hole/contour nesting fixtures | `parity_verified` | More pathological containment inputs may be added later. |
| source `chain_extrusion_entities()` ordering/reversal | `SourceShortestPath2` | reversal, fallback, loop suppression, reorder fixtures | `parity_verified` | KD-tree is replaced only as an acceleration detail; tie-specific oracle coverage can still be expanded. |
| structural loop → `ExtrusionLoop` and recursive `traverse_loops()` | `SourceClassicPerimeterTraversal2` | role/flow/loop-role, recursive order, winding, thin-wall-chain tests | `parity_verified` | Fuzzy-skin transform/gating remains outside this row. |
| source wall sequence | `SourceClassicWallSequence2` + pipeline integration | outer-inner, brim, inner-outer-inner and source quirk fixtures | `parity_verified` | Other higher-level config interactions may remain. |
| no-speed `detect_overhang_wall` supported/unsupported split | `SourceClassicOverhangSplitter2`, traversal/pipeline integration | open-subject seam, role/flow, degree 5/6, raft boundary, e2e pipeline fixtures | `parity_verified` | Fuzzy-skin interaction remains open. |
| `generate_lower_polygons_series(width)` / `dist_boundary(width)` | `SourceClassicOverhangSupport2` + `SourceClassicPerimeterOverhangSettings2.fromLowerSlices` | source float32/scaling, box/hole offset, equal-scaled-width reuse and pipeline fixtures; runs #191/#194 | `parity_verified` | More pathological Clipper1 offset inputs may expand coverage. |
| classic `detect_overhang_degree()` mapping/split/smoothing | `SourceClassicOverhangDegree2`, `SourceClassicOverhangDistancer2` | mapping, 0.6 mm cut, float query, smoothing, binary terrace, extrusion fixtures; run #197 | `parity_verified` | AABB tree is replaced only as an acceleration detail; fuzzy gating remains open. |
| speed-graded supported/zero/middle/unsupported split | `SourceClassicOverhangSplitter2.splitWithSpeedGrading` | independent splitter fixtures; run #199 | `parity_verified` | Fuzzy transform/gating remains open. |
| recursive speed-graded traversal / raw-lower-slices pipeline | `traverseWithSpeedGrading`, `buildExtrusionsFromLowerSlicesWithSpeedGrading` | selected boundary/Flow, customize, graded + unsupported e2e fixtures; runs #201/#203 | `parity_verified` | Fuzzy skin and perimeter-region segmentation remain open. |
| fuzzy-skin overhang interaction | not ported | source located; no Dart checkpoint yet | `pending` | Port enum/policy/identity first, then deterministic/random geometry and per-region segmentation. |
| remaining fill-surface/fill-no-overlap stages | partial | incomplete | `port_started` | Continue line-by-line. |
| Arachne wall generator | not ported | none | `pending` | Full source port required. |

## G-code traceability

| Source behavior | Dart replacement | Evidence | Status | Remaining scope |
|---|---|---|---|---|
| source formatter XYZ/E rounding/trimming | `SourceGCodeFormatter2` | source formatter tests | `parity_verified` | Other writer fields/templates pending. |
| G1/G2/G3 extrusion-path branch using fitting metadata | `SourceExtrusionPathEmitter2` | source branch tests including spiral and force-no-extrusion | `parity_verified` | Sloped XYZ, acceleration, travel/retract/cooling/multi-material and full state machine pending. |
| basic deterministic writer | current `GCodeWriter` subset | basic writer fixture | `implemented_unverified` | Not equivalent to full native pipeline. |
| complete native G-code pipeline | partial | incomplete | `port_started` | Large remaining source area. |

## Formats / project persistence

| Source area | Dart replacement | Status | Notes |
|---|---|---|---|
| STL | Dart parser | `port_started` | Basic supported paths exist; full source warning/repair semantics pending. |
| OBJ | Dart parser | `port_started` | Broader source behavior pending. |
| AMF / ZIP.AMF | Dart parser | `port_started` | Full edge-case/source regression coverage pending. |
| 3MF package structure | `ThreeMfParser` / package retention foundation | `port_started` | External components/build transforms/unknown entries represented; complete QIDI/Prusa/Bambu project semantics pending. |
| STEP | none complete | `pending` | Source-enabled format still required. |
| Assimp-enabled formats | none complete | `pending` | Source-supported formats still required. |
| project/preset round trip | partial foundations | `port_started` | Must preserve all metadata/settings/unknown entries and project state. |

## Device / profiles / UI traceability

| Source area | Dart replacement | Status | Notes |
|---|---|---|---|
| QIDI LAN SSDP discovery | Dart UDP discovery | `port_started` | Source-shaped discovery exists; full lifecycle/capability/retry parity pending. |
| Moonraker local control | Dart JSON-RPC foundations | `port_started` | Hardware-in-loop and full command/state coverage pending. |
| QIDI Box files/timelapse/control | Dart foundations | `port_started` | Full device workflow pending. |
| cloud/P2P/account/HMS/firmware | incomplete | `pending` / `port_started` | Large remaining source subsystem. |
| profile loading/inheritance/compatibility | Dart foundations | `port_started` | Full schema/expression/preset behavior pending. |
| PO localization | Dart reader | `port_started` | All catalogs, plural/context behavior and visual QA still required. |
| Prepare / Preview / Device / Project / Calibration UI | Flutter shell/functionality foundations | `port_started` | Visual/state/workflow parity remains open. |
| desktop integration/release | partial | `pending` / `port_started` | File associations, single-instance, installers, updates and OS integrations remain open. |

## Runtime assets

Earlier local audit evidence recorded 3,657/3,657 copied runtime entries matching source SHA-256. The remote GitHub repository still does **not** contain/verify the complete runtime asset set. Technical `.gitkeep` files used to keep declared directories valid for Flutter CI are not source assets and do not change this status.

Remote/release asset gate: `pending`.

## Mandatory update rule

Every migration batch must update this ledger, [`MIGRATION_STATUS.md`](MIGRATION_STATUS.md), [`VALIDATION.md`](VALIDATION.md), and [`../docs/HANDOFF.md`](../docs/HANDOFF.md) when the represented scope, evidence, blockers, or next dependency changes. Never promote a row because the UI looks similar or because a smoke test passes.
