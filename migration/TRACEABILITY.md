# Traceability ledger — strict 1:1 Flutter/Dart rewrite

Acceptance authority: [`PARITY_CONTRACT.md`](PARITY_CONTRACT.md). This ledger records only implemented Dart scope and evidence attached to that exact scope. A scoped `parity_verified` entry never completes its containing subsystem.

## Current validation checkpoint

- code: `ffc005e678d0cf1e6d4000e6c9a842620700ddbe`;
- workflow: `.github/workflows/flutter-parity.yml` run `34688064516` (#230);
- Flutter `3.47.2`, Dart `3.13.2`;
- analyzer: **No issues found**;
- tests: **288/288 passed**;
- conclusion: **success**.

Run #229 is superseded: its three failures belonged to a false independent fuzzy-RNG interpretation. The pinned source uses one `random_value()` stream; commit `ffc005e` removed the duplicate `*Exact2` path and is the green replacement checkpoint.

## Core geometry / Boost / Clipper

| Source scope | Dart replacement | Evidence | Status | Remaining |
|---|---|---|---|---|
| libslic3r integer coordinate domain / Point / Line / represented Polygon APIs | `Slic3rUnits`, `SourcePoint2`, `SourceLine2`, `SourcePolygon2` | source-formula and translated geometry fixtures in #230 | `parity_verified` | Broader Polygon/ExPolygon APIs remain open. |
| Polyline / ArcFitter / Circle represented subset | `SourcePolyline2`, fitting/circle/arc helpers | regression/oracle fixtures in #230 | `parity_verified` | Later consumers may expose more source branches. |
| ThickPolyline / MedialAxis represented subset | `ThickPolyline2`, source MedialAxis ports | direct + end-to-end thin-wall/gap fixtures | `parity_verified` | Other consumers remain open. |
| Boost.Polygon 1.83 robust predicates/Fortune/Voronoi represented subset | direct Dart Boost/Voronoi port | C++ oracle and regression fixtures | `parity_verified` | Broader source input matrix remains open. |
| Clipper/ClipperUtils represented boolean/offset/open-subject subset | Dart Clipper2 adapters + source compatibility shims | translated and source-coordinate fixtures | `parity_verified` | Full QIDI/Clipper regression space remains `port_started`. |

Implementation constraints remain literal: Boost unsigned/ULP boundaries use `BigInt` where needed; PPP robust-cross-product operand order stays source-identical; QIDI/Clipper adapter quirks must not be simplified without a source oracle.

## Slicer semantic model

| Source scope | Dart replacement | Evidence | Status | Remaining |
|---|---|---|---|---|
| Flow | `Flow` | translated/source-formula tests | `parity_verified` | Full config integration open. |
| Extruder/QIDI config represented subset | Dart state/resolver | state/math tests | `parity_verified` | Full native print-state integration open. |
| Surface represented subset | Dart Surface model | classification/copy/assignment tests | `parity_verified` | Surface pipeline incomplete. |
| ExtrusionEntity represented subset | Dart entity model | role/path/multipath/loop/collection tests | `parity_verified` | Remaining operations/consumers open. |
| variable-width + covered-width represented subset | `SourceVariableWidth2`, covered geometry helpers | translated/end-to-end fixtures | `parity_verified` | Later consumers open. |

## Classic perimeter

| Source behavior | Dart replacement | Evidence | Status | Remaining |
|---|---|---|---|---|
| onion-shell / QIDI smaller external / source `last = offsets` | `ClassicPerimeterShellGenerator` | source-formula fixtures | `parity_verified` | Later process stages open. |
| thin wall / gap fill represented path | Clipper → MedialAxis → variable width | end-to-end fixtures | `parity_verified` | More pathological inputs may expand coverage. |
| nesting / shortest-path chain / recursive traversal / wall sequence | source-shaped Dart traversal helpers | ordering/winding/reversal fixtures | `parity_verified` | Higher-level config branches open. |
| lower support series / distance boundary | `SourceClassicOverhangSupport2` | float32/scaling/offset fixtures | `parity_verified` | Broader Clipper inputs open. |
| no-speed + speed-graded overhang | splitter/degree/traversal/pipeline helpers | source mapping/smoothing/role/flow fixtures | `parity_verified` | Other process stages remain open. |
| fuzzy policy | `SourceFuzzySkinPolicy2` | enum, first-layer, `None`/`Disabled_fuzzy`, slowdown fixtures in #230 | `parity_verified` (scoped) | Painted regions and non-Classic noise open. |
| Classic no-region fuzzy geometry | `SourceFuzzySkinGeometry2` | sampling, leftover, perpendicular displacement, fallback, polygon fixtures in #230 | `parity_verified` (scoped) | Non-Classic noise and region segmentation open. |
| fuzzy RNG topology | `SourceFuzzyUnitRandom2`, `SourceFuzzyMt19937Random2` | standard MT19937 words + libstdc++ double C++ oracle + shared-call-order fixture | `parity_verified` (scoped) | Exact platform random-device/thread-id seed selection is nondeterministic and not claimed. |
| Classic fuzzy recursive integration | `SourceClassicFuzzyPerimeterTraversal2`, `SourceClassicFuzzyPerimeterPipeline2` | first-layer/no-overhang, recursion and slowdown interaction fixtures in #230 | `parity_verified` (no-region Classic scope) | Per-region segmentation, non-Classic noise, Arachne fuzzy open. |
| Perlin/Billow/RidgedMulti/Voronoi fuzzy modules | not yet implemented | enum only | `pending` | First unfinished fuzzy priority. |
| painted/per-region `LineSegmentation` | not implemented | rejection fixture only | `pending` | Required before region-aware fuzzy claim. |
| Arachne fuzzy extrusion-line modes | not implemented | none | `pending` | `Displacement`, `Extrusion`, `Combined`. |
| remaining fill-surface/fill-no-overlap/later classic stages | partial | incomplete | `port_started` | Continue after current fuzzy branch. |
| Arachne wall generator | not ported | none | `pending` | Full source port required. |

## G-code / formats / device / UI

The represented source G-code formatter/extrusion-path emitter subset remains scoped `parity_verified`; the full native G-code state machine is `port_started`. STL/OBJ/AMF/3MF foundations are `port_started`; STEP, complete source-enabled formats and full project/preset round trips remain open. Device LAN/Moonraker/QIDI Box, profiles, localization and Flutter UI areas have foundations only and remain `port_started`; cloud/P2P/account/HMS/firmware, full calibration, desktop integration and full source UI/state/visual parity remain open.

## Runtime assets

An earlier local audit recorded 3,657/3,657 copied runtime entries matching source SHA-256, but the complete real runtime asset set is not yet published and reverified from GitHub/release inputs. `.gitkeep` files are not parity evidence. Remote/release asset gate remains `pending`.

## Mandatory update rule

Every meaningful migration batch must keep [`MIGRATION_STATUS.md`](MIGRATION_STATUS.md), [`VALIDATION.md`](VALIDATION.md), [`../docs/HANDOFF.md`](../docs/HANDOFF.md), and this ledger consistent with the actual code and executed CI evidence.
