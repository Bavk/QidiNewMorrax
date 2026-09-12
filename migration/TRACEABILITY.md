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

Two independent GitHub Actions executions confirm the current code checkpoint:

- cleanup validation run `34668728368`: Flutter 3.47.2 / Dart 3.13.2, `flutter analyze` = **No issues found**, `flutter test` = **174/174 passing**, `git diff --check` clean; it produced code commit `015dcdd4cbfb9b292a89642c0d736f2471483691`;
- ordinary read-only parity run `34668800262` (#139) on commit `2f2c8486e09640dd4d6d03ebc85cee843146d8b2`: Analyze **success**, Unit and parity tests **success**, final `+174: All tests passed!`.

The temporary write-enabled cleanup workflow was removed before the ordinary confirmation. Normal CI is `.github/workflows/flutter-parity.yml`.

## Numeric / geometry traceability

| Source area | Dart replacement | Evidence | Status | Remaining scope |
|---|---|---|---|---|
| libslic3r scaling constants / integer Point | `Slic3rUnits`, `SourcePoint2` | source-formula geometry tests | `parity_verified` | Broader source geometry APIs remain outside this row. |
| `Line` represented math | `SourceLine2` | translated/source-formula Line tests | `parity_verified` | Only represented Line methods are claimed. |
| QIDI `Polyline` append/clip/extend/reverse and fitting metadata | `SourcePolyline2`, `PathFittingData2` | Polyline regression tests including exact-length and arc metadata quirks | `parity_verified` | Other Polyline APIs/consumers pending as encountered. |
| Arc fitting | `SourceArcFitter2`, `SourceCircle2`, `SourceArcSegment2` | ArcFitter/Circle/ArcSegment source-formula tests | `parity_verified` | Broader arc consumers still depend on later toolpath/G-code stages. |
| `ThickPolyline` represented behavior | `ThickPolyline2` | width-cardinality, reverse, `rebase_at`, `get_width_at` tests | `parity_verified` | Variable-width extrusion conversion is a separate pending stage. |
| Boost.Polygon robust numeric helpers | `BoostRobustFpt2`, extended-int/sqrt helpers | Boost 1.83 C++ oracle goldens | `parity_verified` | Only helpers currently required by direct Voronoi port are claimed. |
| Boost site/circle predicates and PPP/PPS/PSS/SSS formation | `BoostVoronoiPredicates2`, circle-formation ports | Boost 1.83 oracle fixtures incl. extreme int32 cases | `parity_verified` | Additional unrepresented Boost cases may still be added. |
| Boost direct Fortune construction | source Boost Voronoi builder + topology adapter | point/segment construction tests, square full half-edge golden, regression inputs | `parity_verified` | Broader source inputs not yet represented remain open. |
| QIDI Voronoi issue detection / rotation repair / annotation | `SourceVoronoiDiagram2`, annotator/utils | repair-angle, endpoint-remap, contour-category tests | `parity_verified` | Other consumers may expose additional source cases. |
| MedialAxis represented core and ExPolygon postprocess | `MedialAxisCore`, `SourceMedialAxis2`, `SourceExPolygonMedialAxis2` | edge validation/traversal/postprocess and composition tests | `parity_verified` | Downstream variable-width/gap-fill conversion is not part of this row. |
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
| positive ExPolygon hole orientation | Clipper2 adapter orientation handling | source-equivalent expanded-hole fixture | `parity_verified` | More multi-hole/nested cases pending. |
| complete Slic3r/QIDI ClipperUtils | partial adapter | incomplete original regression coverage | `port_started` | Translate remaining source tests and wrappers. |

## Slicer semantic-model traceability

| Source area | Dart replacement | Evidence | Status | Remaining scope |
|---|---|---|---|---|
| Flow represented formulas/config resolution | `Flow`, config snapshot helpers | translated/source-formula Flow tests | `parity_verified` | Full config schema/expression integration pending. |
| Extruder represented E/retract/variant behavior | `ExtruderState`, `QidiConfigVariantResolver` | exact state/math and QIDI resolver tests | `parity_verified` | Full native print-state integration pending. |
| Surface represented classification/copy/assignment quirks | Dart Surface model | source-style Surface tests | `parity_verified` | Surface-processing pipeline remains incomplete. |
| ExtrusionRole/Path/MultiPath/Loop/Collection represented behavior | Dart extrusion entity model | source-semantic regression tests | `parity_verified` | Remaining entity operations/consumers pending. |
| Linear infill current subset | `LinearInfill` | square/hole clipping fixtures | `implemented_unverified` | Not enough source-pattern/reference coverage for parity claim. |

## Classic perimeter traceability

| Source behavior | Dart replacement | Evidence | Status | Remaining scope |
|---|---|---|---|---|
| common onion-shell inset formulas | `ClassicPerimeterShellGenerator` | equal-flow source-formula fixture | `parity_verified` | Later `process_classic()` stages remain open. |
| alternate extra wall count | same | odd/even layer test | `parity_verified` | Other wall ordering rules pending. |
| QIDI smaller-external-width decision | same | narrow-loop regression | `parity_verified` | Later extrusion conversion pending. |
| source quirk `last = offsets` | same | regression proving smaller-width outer loop does not seed inner loops | `parity_verified` | Keep exact behavior in future refactors. |
| `detect_thin_wall` geometric branch | Clipper difference/opening → `SourceExPolygonMedialAxis2` → `ThickPolyline2` | end-to-end thin-wall tests | `parity_verified` | Returned ThickPolyline → variable-width extrusion-path conversion pending. |
| source nozzle-diameter dependency | explicit `externalNozzleDiameter` | required-input regression | `parity_verified` | Must be wired from full Flow/config caller later. |
| variable-width conversion after thin-wall medial axis | none complete | no Dart reference tests | `pending` | Immediate next source unit. |
| classic gap fill | none complete | no Dart reference tests | `pending` | Follow variable-width conversion using working MedialAxis chain. |
| remaining `process_classic()` path/order/overhang/covered-area stages | partial | incomplete | `port_started` | Continue line-by-line. |
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
