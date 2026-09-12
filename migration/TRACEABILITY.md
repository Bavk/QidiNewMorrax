# Traceability ledger — strict 1:1 Flutter/Dart rewrite

Acceptance authority: [`PARITY_CONTRACT.md`](PARITY_CONTRACT.md). This ledger records only implemented Dart scope and evidence attached to that exact scope. A scoped `parity_verified` entry never completes its containing subsystem.

## Current validation checkpoint

- code: `5a4d8b65e177ce6fe196594c4263d3f962a90422`;
- workflow: `.github/workflows/flutter-parity.yml` run `34693713324` (#254);
- Flutter `3.47.2`, Dart `3.13.2`;
- analyzer: **No issues found**;
- tests: **340/340 passed**;
- conclusion: **success**.

Run #252 (`34691194040`) first validated the represented classic final fill-boundary block at 333/333. Run #253 was a compile-only diagnostic checkpoint for the new top-fill producer: an accidental `const` was applied to the non-const `SourcePolygon2` constructor, so the new test file could not load. Commit `5a4d8b6` removed only that typo; run #254 then passed all seven new top-fill/composition fixtures unchanged. Earlier Arachne/LineSegmentation checkpoint #249 remains fully re-executed by this suite.

## Core geometry / Boost / Clipper

| Source scope | Dart replacement | Evidence | Status | Remaining |
|---|---|---|---|---|
| libslic3r integer coordinate domain / Point / Line / represented Polygon APIs | `Slic3rUnits`, `SourcePoint2`, `SourceLine2`, `SourcePolygon2` | source-formula and translated geometry fixtures in #254 | `parity_verified` | Broader Polygon/ExPolygon APIs remain open. |
| Polyline / ArcFitter / Circle represented subset | `SourcePolyline2`, fitting/circle/arc helpers | regression/oracle fixtures in #254 | `parity_verified` | Later consumers may expose more source branches. |
| ThickPolyline / MedialAxis represented subset | `ThickPolyline2`, source MedialAxis ports | direct + end-to-end thin-wall/gap fixtures | `parity_verified` | Other consumers remain open. |
| Boost.Polygon 1.83 robust predicates/Fortune/Voronoi represented subset | direct Dart Boost/Voronoi port | C++ oracle and regression fixtures | `parity_verified` | Broader source input matrix remains open. |
| Clipper/ClipperUtils represented boolean/offset/open-subject subset | Dart Clipper2 adapters + source compatibility shims | translated and source-coordinate fixtures | `parity_verified` | Full QIDI/Clipper regression space remains `port_started`. |
| `clip_clipper_polygons_with_subject_bbox()` represented helper | literal source side-mask pruning in `SourceClassicTopFillAllTop2` | far-upper-polygon pruning fixture in #254 | `parity_verified` (scoped) | Other callers/input topologies open. |
| LineSegmentation Polyline/Polygon/Arachne subset | `SourceLineSegmentation2` with direct source ZAttributes | stripe/gap/full-cover/point-lerp/width-lerp/Arachne fixtures in #254 | `parity_verified` (scoped) | Broader overlap/hole/degenerate topology remains open. |

Implementation constraints remain literal: Boost unsigned/ULP boundaries use `BigInt` where needed; PPP robust-cross-product operand order stays source-identical; QIDI/Clipper adapter quirks must not be simplified without a source oracle. LineSegmentation uses `Point64.z` and `Clipper64.zCallback` for the source bit layout. Narrow shims restore a uniquely identifiable lost terminal source Z and normalize reversed Dart open-path output while preserving the source wrap rule for genuinely closed XY subjects.

## Slicer semantic model

| Source scope | Dart replacement | Evidence | Status | Remaining |
|---|---|---|---|---|
| Flow | `Flow` | translated/source-formula tests | `parity_verified` | Full config integration open. |
| Extruder/QIDI config represented subset | Dart state/resolver | state/math tests | `parity_verified` | Full native print-state integration open. |
| Surface represented subset | Dart Surface model | classification/copy/assignment tests | `parity_verified` | Surface pipeline incomplete. |
| ExtrusionEntity represented subset | Dart entity model | role/path/multipath/loop/collection tests | `parity_verified` | Remaining operations/consumers open. |
| variable-width + covered-width represented subset | `SourceVariableWidth2`, covered geometry helpers | translated/end-to-end fixtures | `parity_verified` | Later consumers open. |
| Arachne fuzzy data subset | `SourceArachneExtrusionJunction2`, `SourceArachneExtrusionLine2` | metadata/copy plus fuzzy/segmentation consumers in #254 | `parity_verified` (scoped) | Full Arachne wall-toolpath model remains open. |

## Classic perimeter / fuzzy

| Source behavior | Dart replacement | Evidence | Status | Remaining |
|---|---|---|---|---|
| onion-shell / QIDI smaller external / source `last = offsets` | `ClassicPerimeterShellGenerator` | source-formula fixtures | `parity_verified` | Top-one-wall producer still must be wired into the exact in-loop position. |
| thin wall / gap fill represented path | Clipper → MedialAxis → variable width | end-to-end fixtures | `parity_verified` | More pathological inputs may expand coverage. |
| nesting / shortest-path chain / recursive traversal / wall sequence | source-shaped Dart traversal helpers | ordering/winding/reversal fixtures | `parity_verified` | Higher-level config branches open. |
| lower support series / distance boundary | `SourceClassicOverhangSupport2` | float32/scaling/offset fixtures | `parity_verified` | Broader Clipper inputs open. |
| no-speed + speed-graded overhang | splitter/degree/traversal/pipeline helpers | source mapping/smoothing/role/flow fixtures | `parity_verified` | Other process stages remain open. |
| final `process_classic()` fill boundary (`not_filled_exp` → `fill_surfaces` / `fill_no_overlap`) | `SourceClassicFillBoundary2` | zero/one/multi-wall, absolute/percent overlap, top-fill, no-overlap and coord truncation fixtures in #252/#254 | `parity_verified` (scoped) | Exact in-process integration after gap-fill is still open. |
| `TopOneWallType::Alltop` producer (`top_fills`, `fill_clip`, `last`) | `SourceClassicTopFillAllTop2` | C++ scalar oracle, bbox-prune, all-top, gap-fill re-union, bridge merge and boundary-composition fixtures in #254 | `parity_verified` (scoped) | Must be invoked after first `last = offsets` so mutated `last` feeds later shell iterations. |
| pre-shell top-one-wall / first-layer loop-number gate | not yet integrated | source condition identified | `port_started` | Immediate next classic priority. |
| complete source-order classic fill/process composition | partial verified helpers | no single in-loop end-to-end fixture yet | `port_started` | Integrate one-wall gate + producer + gap fill + final boundary in source order. |
| fuzzy policy + region-aware slowdown | `SourceFuzzySkinPolicy2`, fuzzy traversal | enum/first-layer/None-vs-Disabled/region emptiness fixtures | `parity_verified` (scoped) | Full wall-engine integration open. |
| Classic fuzzy geometry/RNG | `SourceFuzzySkinGeometry2`, `SourceFuzzyMt19937Random2` | sampling/fallback/MT19937/libstdc++ fixtures | `parity_verified` (scoped) | Exact platform random-device seed choice not claimed. |
| libnoise Perlin/Billow/RidgedMulti/Voronoi | `SourceLibNoise*2` + pinned vector table | value/gradient/hash/octave/Voronoi fixtures | `parity_verified` (scoped) | More source-oracle points may expand coverage. |
| all-noise Polygon/Polyline fuzzy composition | `SourceFuzzySkinGeometry2.fuzzyPolyline/fuzzyPolygon` | scale clamp, `slice_z`, deterministic RNG-consumption and pipeline fixtures | `parity_verified` (scoped) | Broader path matrix open. |
| painted/per-region Polygon/Polyline fuzzy | `SourceLineSegmentation2`, `SourceFuzzySkinApply2`, region-aware traversal/pipeline | single/full/multi/identity painted fixtures | `parity_verified` (scoped) | Broader region topology open. |
| Arachne `fuzzy_extrusion_line()` | `SourceFuzzySkinArachne2` | seeded C++ goldens for Displacement/Extrusion/Combined; closure/RNG fixtures in #254 | `parity_verified` (scoped) | Full Arachne wall generator integration open. |
| Arachne region-aware fuzzy | Arachne LineSegmentation overload + `SourceFuzzySkinApply2.applyExtrusionLine` | width interpolation/full-cover/painted middle/seam fixtures in #254 | `parity_verified` (scoped) | Broader topology/integration open. |
| full Arachne wall generator | not ported | fuzzy helper only | `pending` | Full source wall toolpath port required. |

## G-code / formats / device / UI

The represented source G-code formatter/extrusion-path emitter subset remains scoped `parity_verified`; the full native G-code state machine is `port_started`. STL/OBJ/AMF/3MF foundations are `port_started`; STEP, complete source-enabled formats and full project/preset round trips remain open. Device LAN/Moonraker/QIDI Box, profiles, localization and Flutter UI areas have foundations only and remain `port_started`; cloud/P2P/account/HMS/firmware, full calibration, desktop integration and full source UI/state/visual parity remain open.

## Runtime assets

An earlier local audit recorded 3,657/3,657 copied runtime entries matching source SHA-256, but the complete real runtime asset set is not yet published and reverified from GitHub/release inputs. `.gitkeep` files are not parity evidence. Remote/release asset gate remains `pending`.

## Mandatory update rule

Every meaningful migration batch must keep [`MIGRATION_STATUS.md`](MIGRATION_STATUS.md), [`VALIDATION.md`](VALIDATION.md), [`../docs/HANDOFF.md`](../docs/HANDOFF.md), and this ledger consistent with the actual code and executed CI evidence.
