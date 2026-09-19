# Handoff — OrcaSlicer engine cutover

## Architecture decision

QidiNewMorrax no longer reimplements the slicer or Clipper in Dart. Production slicing and G-code generation are delegated to a pinned OrcaSlicer engine; Flutter/Dart owns the surrounding QIDI application, editor/project state, profile selection, Preview, Device integration and calibration.

Pinned engine:

- OrcaSlicer v2.4.2
- commit `8500fcdccaa10b5099ac20d252af3a7c560046f1`
- Ubuntu 24.04 AppImage SHA-256 `d12fb8c8eac1aecd2dfb6377acd48f994f8fa439ed5292fa532dd82880f029fd`
- GNU AGPL-3.0

Read [ORCASLICER_ENGINE.md](ORCASLICER_ENGINE.md) and [../migration/PARITY_CONTRACT.md](../migration/PARITY_CONTRACT.md) before continuing. Generated-project editing now follows the explicit `plate -> object -> volumes` contract in `PARITY_CONTRACT.md`; do not collapse modifier/support volumes into a single object mesh when extending Prepare.

## Current production path

The cutover now routes the application through:

1. Prepare model/project state and QIDI machine/process/filament selection in Dart.
2. Generated state -> Orca/Bambu split-model project 3MF with embedded resolved `project_settings.config`; imported QIDI/Bambu/Orca 3MF is repacked losslessly and keeps vendor entries.
3. `OrcaSlicerEngine` -> pinned Orca headless CLI.
4. Orca sliced `.gcode.3mf` -> all available `Metadata/plate_N.gcode` entries plus `Metadata/slice_info.config`.
5. Selected plate G-code + authoritative Orca estimates/warnings/material usage -> Dart Preview.
6. Latest selected G-code + selected-plate estimate -> Dart Device -> Moonraker `/server/files/upload` -> optional print start.

The old `lib/core/slicer` tree, its test suite, the Dart Clipper compatibility layer, custom G-code writer/emitter/extruder implementation, and `clipper2` dependency are removed from production.

## Validated checkpoint — 2026-09-19

Functional code checkpoint:

- code: `c8d0f9c703d98ac5ed25d2719390e71bcfc0e1ea`;
- Flutter parity run `35459879595` (#793), job `105941708672`;
- `flutter analyze` — **No issues found!**;
- `flutter test --reporter expanded` — **142/142 passed**;
- conclusion — **success**.

Real engine checkpoint on the same functional HEAD:

- Orca smoke run `35459879618` (#221), job `105941708762`;
- downloaded Orca v2.4.2 Ubuntu 24.04 AppImage passed the pinned SHA-256 check;
- QIDI X-Plus 4 machine/process/PLA profiles were loaded by the real engine;
- the real QIDI X-Plus 4 two-plate project fixture, containing modifier/support volumes plus source-shaped support/seam/fuzzy-skin facet paint attributes, sliced successfully;
- both `Metadata/plate_1.gcode` and `Metadata/plate_2.gcode` were present with printable G0/G1 moves;
- progress reached **100%**, and each plate retained the verified **1167 s** prediction / **1.335 m** filament metadata fallback;
- conclusion — **success**.

## Project/3MF handoff checkpoint — 2026-09-18

PR #11 replaces the temporary STL bridge with an Orca-compatible project 3MF boundary:

- split production-extension 3MF (`3D/3dmodel.model` + `3D/Objects/*.model` + relationships);
- embedded resolved QIDI `Metadata/project_settings.config`;
- objects, multiple volumes, modifier/support volume types, facet paint metadata, per-object/per-volume settings and extruder assignment;
- explicit plate membership plus Orca virtual-bed offsets;
- lossless pass-through of imported vendor 3MF entries while applying build transforms;
- all sliced `plate_N.gcode` outputs exposed by the engine;
- old `MeshStlWriter` bridge removed;
- real Orca v2.4.2 smoke run `35397155859` (#104) slices both plates in one `--slice 0` invocation successfully.

## Progress/cancellation checkpoint — 2026-09-18

PR #12 moves Orca invocation to a managed process and wires Linux `--pipe` progress into the workspace UI. The pinned Orca smoke validates real FIFO JSON while slicing the two-plate project; cancellation has dedicated process-lifecycle unit coverage. Orca 2.4.2 compiles this pipe callback only on Linux, so equivalent native progress transport for packaged Windows/macOS builds remains open.

## Sliced metadata checkpoint — 2026-09-19

PR #13 consumes Orca's sliced-result metadata instead of inferring estimates in Dart:

- `OrcaSliceMetadata` parses `Metadata/slice_info.config` per plate: prediction, first-layer time, build-area/support flags, objects, filament records and structured warnings;
- XML values stay authoritative when Orca provides them;
- when Orca CLI leaves time/material fields empty or zero, Dart fills only those gaps from Orca-authored `plate_N.gcode` statistics comments (`estimated printing time`, `estimated first layer printing time`, `filament used [g]` / `[mm]`);
- Preview follows the selected plate and displays Orca estimates, support state, warnings and material usage;
- Device shows the selected Orca time/material estimate on the print action;
- manually opened G-code does not inherit stale workspace metadata;
- no mass is fabricated: the real QIDI CLI fixture reports zero grams, so Preview uses Orca's exact filament length instead.

Functional checkpoint `a69646d98fbc07de7004cda6b62ad78757a8d61a` is green in Flutter run `35400170625` (#746), job `105778026686`: analyzer clean, **131/131 tests passed**. Real Orca smoke `35400170623` (#173), job `105778021824`, is also green: both plates report **1167 s** prediction and **1.335 m** filament via the verified fallback path.

## Editable Prepare project checkpoint — 2026-09-19

PR #14 wires the verified project serializer into real generated-project editing instead of keeping multi-plate state as a handoff-only capability:

- new immutable `WorkspaceEditableProject` domain state owns generated plates and objects;
- Prepare can add multiple source models, create/rename/lock/remove plates, select/move/remove objects between plates, and render the active plate as a merged viewport;
- Move/Rotate/Scale/Center operate on the selected generated object and the same edited state is handed to `WorkspaceController`;
- object name, plate assignment, wall-loop and sparse-infill overrides are serialized into the existing Orca/Bambu `model_settings.config`;
- the editor currently keeps the production filament slot at extruder 1 because runtime profile materialization still loads one selected filament;
- a single imported vendor 3MF intentionally stays on the existing lossless read/repack path; structural editing of imported package internals is not promoted by this batch.

Functional HEAD `cbc806db7ecf00c87b6730c4167fa3d3f622223a` is green in Flutter run `35401167437` (#752), job `105781146290`: analyzer clean, **134/134 tests passed**. Orca smoke `35401167530` (#180), job `105781147329`, is also green on the same HEAD with the pinned AppImage and verified two-plate QIDI fixture.

## Editable volume checkpoint — 2026-09-19

PR #15 extends generated objects from the earlier single-mesh assumption to an explicit Orca/Bambu volume model:

- `WorkspaceEditableObject` owns one or more `WorkspaceEditableVolume` values;
- supported subtypes are `normal_part`, `modifier`, `support_enforcer` and `support_blocker`;
- Prepare can add geometry as a child volume, select volumes, change subtype/name, edit volume-scoped wall/infill overrides and remove secondary volumes;
- object transforms apply to all child volumes together while volume settings/facet metadata stay scoped to the volume;
- `ThreeMfProjectWriter` receives the explicit volume list directly, preserving subtype/settings/facets in `Metadata/model_settings.config`;
- `PARITY_CONTRACT.md` now makes `plate -> object -> volumes` an explicit continuation rule and forbids flattening modifier/support state into a separate presentation-only mesh.

Functional HEAD `3aa01f3fd65c618c22d9eeffa1c9056e00e0689c` is green in Flutter run `35456145423` (#761), job `105931646159`: analyzer clean, **136/136 tests passed**. The strengthened pinned Orca smoke `35456145434` (#189), job `105931646222`, is green with a real fixture containing all three non-normal volume subtypes.

## Facet paint checkpoint — 2026-09-19

PR #16 promotes source-shaped facet annotations into generated Prepare state:

- `WorkspaceEditableProject.paintFacets()` / `clearFacetPaint()` edit support, seam and fuzzy-skin channels without overwriting sibling channels on the same triangle;
- pinned Orca `TriangleSelector` encoding is used directly for unsplit whole facets: ENFORCER = `"4"`, BLOCKER = `"8"`;
- facet paint is restricted to `normal_part` volumes, matching Orca painter behavior;
- Prepare exposes a first functional editor using facet indices/ranges (`0,2-8,15` or `all`) with Enforce/Block/Erase actions; a viewport brush can be layered on the same state later;
- MMU/material color paint is intentionally deferred until real multi-filament profiles/slots are materialized;
- `ThreeMfProjectWriter` emits `paint_supports`, `paint_seam` and `paint_fuzzy_skin` on the exact source triangles.

Functional HEAD `c54cbacf31346049e7dd342759e12f5795e95a8b` is green in Flutter run `35457718002` (#770), job `105935857211`: analyzer clean, **138/138 tests passed**. Pinned Orca smoke `35457717977` (#198), job `105935857104`, is green with real support/seam/fuzzy-skin facet attributes in the sliced project fixture.

## Linux packaged-engine checkpoint — 2026-09-19

PR #17 closes the first v0.1 release gate for a Linux-first portable bundle:

- `OrcaSlicerEngine.defaultExecutable()` keeps explicit `ORCA_SLICER_BIN` as the highest-precedence development override, then discovers `orca/OrcaSlicer.AppImage` beside the packaged Flutter executable;
- a bundled engine is selected only when the sibling `orca-engine.json` provenance manifest is present;
- before the first packaged slice, Dart validates manifest version `2.4.2`, source commit, `linux-x64` platform and the pinned AppImage SHA-256, then streams SHA-256 over the actual bundled AppImage;
- bundled AppImage launches with `APPIMAGE_EXTRACT_AND_RUN=1`, avoiding a hard runtime dependency on host FUSE;
- `.github/workflows/linux-release-smoke.yml` generates the missing Linux Flutter scaffold with pinned Flutter 3.47.2, builds the real release executable, downloads the exact 131 MB Orca artifact, verifies it, places it beside the app and archives the full portable bundle;
- `tool/verify_packaged_orca.dart` verifies the packaged discovery + provenance path using the real release layout.

Validation on HEAD `6e51c7e8c571a4158a43317ae5f6ca022cb1a195`:

- Flutter run `35459351874` (#783), job `105940282076` — analyzer clean, **141/141 tests passed**;
- Orca smoke `35459351908` (#211), job `105940282185` — **success**;
- Linux packaged release smoke `35459351920` (#4), job `105940282171` — **success**;
- uploaded artifact `qidi-new-morrax-linux-x64`, artifact id `10588977100`, size **147,540,938 bytes**.

This closes packaged pinned-engine discovery/version/hash verification for the first Linux target. It does not yet claim AGPL release completeness or a full GUI/printer end-to-end packaged smoke.

## AGPL/source-delivery checkpoint — 2026-09-19

PR #18 implements the Linux-first release notice/source-delivery pipeline:

- repository root now carries the full GNU AGPL v3 text as `LICENSE`;
- the packaged app contains `legal/AGPL-3.0.txt`, `legal/RELEASE-NOTICES.txt` and an exact generated `legal/SOURCE-MANIFEST.txt`;
- the application menu exposes a visible **Legal notices** dialog with the no-warranty notice, exact Orca version/commit and source-delivery information;
- release CI creates `qidi-new-morrax-source.tar.gz` from the exact checked-out application commit and downloads the full OrcaSlicer source archive for pinned commit `8500fcdccaa10b5099ac20d252af3a7c560046f1`;
- both source archives are content-checked and SHA-256 checksums are written into the binary bundle's source manifest;
- CI uploads binary + both source archives together as `qidi-new-morrax-linux-x64-release`;
- on a published GitHub Release, the same three files are attached to that release as assets;
- QidiNewMorrax does not bundle or use OrcaSlicer's optional non-free Bambu networking plugin; printer delivery remains in the Dart Moonraker/QIDI path.

Validation on functional HEAD `c8d0f9c703d98ac5ed25d2719390e71bcfc0e1ea`:

- Flutter run `35459879595` (#793), job `105941708672` — analyzer clean, **142/142 tests passed**;
- Orca smoke `35459879618` (#221), job `105941708762` — **success**;
- Linux packaged release smoke `35459879592` (#14), job `105941708711` — **success**;
- release-materials artifact `qidi-new-morrax-linux-x64-release`, artifact id `10589777552`, size **278,677,846 bytes**.

This closes the automated Linux v0.1 **notice/corresponding-source engineering gate**. It does not replace a final legal review of the public release or third-party notices.

## First-launch definition

For planning purposes, **v0.1 first launch** means an installable single-material desktop build that can:

1. open/import a model or generated project;
2. edit basic plate/object/volume state;
3. slice through the pinned Orca engine;
4. show the selected plate in Preview with Orca estimates/warnings/material usage;
5. upload the generated G-code to one representative QIDI printer through Moonraker and optionally start the print;
6. ship with reproducible Orca provenance plus required AGPL notices/corresponding-source information.

The following are **not blockers for that first launch** unless the release target is explicitly widened: true multi-filament/MMU authoring, paint-color/MMU brush parity, full imported-vendor-3MF structural editing, sliced thumbnails, all calibration surfaces, and all three desktop operating systems.

Hard first-launch gates still open after PR #18:

- validate Moonraker upload/start on representative QIDI hardware;
- run a packaged-app end-to-end smoke for the offline path (launch -> open/import -> slice -> Preview) and close release-blocking desktop errors.

Closed engineering gates:

- Linux packaged engine/version/hash verification;
- AGPL notice + exact corresponding-source generation/delivery automation.

A final legal review remains a release-owner responsibility rather than an automated acceptance result.

## First unfinished priority

Continue in this order:

1. For feature parity, add real multi-filament selection/materialization/assignment on top of the now-verified object/volume/facet model; `paint_color` stays coupled to that work. Widen per-object/per-volume overrides after slot materialization is correct.
2. In parallel with parity work, prioritize the remaining **v0.1 first-launch gates** above. Real-printer Moonraker validation requires representative hardware; while that is unavailable, continue with the packaged offline end-to-end smoke.
3. Improve facet-paint UX with viewport hit-testing/brushes without changing the source-shaped facet state.
4. Consume remaining sliced-package presentation data such as thumbnails and additional vendor printer-payload metadata where useful.
5. Continue broader Device/calibration/UI integration and cross-platform packaging after the first target is launchable.

Do not reintroduce a parallel custom production slicer or Clipper in Dart.
