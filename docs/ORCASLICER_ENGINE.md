# OrcaSlicer engine integration

QidiNewMorrax uses OrcaSlicer as its production slicing and G-code engine. Flutter/Dart owns the application shell, project state, QIDI profiles, Preview, Device/cloud integration, calibration workflows and presentation. The application does not maintain a parallel Dart slicer.

## Pinned engine

- upstream: `OrcaSlicer/OrcaSlicer`
- release: `v2.4.2`
- commit: `8500fcdccaa10b5099ac20d252af3a7c560046f1`
- Linux Ubuntu 24.04 AppImage SHA-256: `d12fb8c8eac1aecd2dfb6377acd48f994f8fa439ed5292fa532dd82880f029fd`
- license: GNU AGPL-3.0

`ORCA_SLICER_BIN` remains the highest-precedence development override. On packaged Linux builds, the runtime next looks for `orca/OrcaSlicer.AppImage` beside the Flutter executable and requires a sibling `orca-engine.json` provenance manifest. System platform defaults are used only when no valid packaged candidate is present.

## Runtime boundary

The Dart process bridge is `lib/core/orca/orca_slicer_engine.dart`.

Prepare/project state is handed to Orca as:

Filament selection is an ordered slot list. Each selected QIDI filament preset is inheritance-resolved, written as its own standalone Orca JSON, merged into `Metadata/project_settings.config` in the same order, and passed through `--load-filaments` as that ordered list. Generated object `extruder` values are 1-based references into this materialized list and are validated before slicing.


1. generated state -> Orca/Bambu production-extension project 3MF; imported vendor 3MF packages are repacked losslessly;
2. resolved QIDI machine/process/filament settings -> embedded `Metadata/project_settings.config` plus standalone preset JSON;
3. headless Orca CLI invocation using `--load-settings`, `--load-filaments`, `--slice`, `--export-3mf` and `--outputdir`;
4. sliced 3MF -> all available `Metadata/plate_N.gcode` entries plus `Metadata/slice_info.config`;
5. selected plate G-code + Orca estimates/warnings/material usage -> Preview and Device.

Multi-plate placement uses the same virtual-bed spacing convention as Orca, and the real pinned engine CI validates two plates in one `--slice 0` job. Generated Prepare state is editable through `WorkspaceEditableProject`; plate/object/volume/facet edits are serialized through the same `ThreeMfProjectWriter` boundary used by slicing. Editable generated objects are structurally volume-based: a single object may carry normal-part, modifier, support-enforcer and support-blocker volumes, each with its own settings/facet metadata. Facet annotations on normal parts use Orca's source-shaped `FacetsAnnotation` strings (`4` for unsplit ENFORCER, `8` for unsplit BLOCKER); pinned Orca smoke #198 accepts support/seam/fuzzy-skin paint attributes together with all three non-normal volume subtypes.

## Sliced metadata

`lib/core/orca/orca_slice_metadata.dart` consumes Orca's own sliced-package metadata. For each plate it exposes print-time prediction, first-layer time, build-area/support flags, object records, filament usage and structured warnings.

`Metadata/slice_info.config` is authoritative when it contains a positive value. OrcaSlicer 2.4.2 CLI may leave some material/time fields empty or zero, so only those gaps are filled from Orca-authored statistics comments embedded in the corresponding `Metadata/plate_N.gcode`:

- `estimated printing time (normal mode)`;
- `estimated first layer printing time (normal mode)`;
- `total filament used [g]` / `filament used [g]`;
- `filament used [mm]`.

The application does not infer mass from geometry, density or extrusion replay. If Orca reports no mass but does report filament length, the UI displays length and keeps mass unknown. The real pinned smoke currently exercises exactly this state: **1167 s** and **1.335 m** per plate with zero reported grams.

## Progress and cancellation

On Linux, OrcaSlicer 2.4.2 implements CLI progress through `--pipe <fifo>`. The Dart bridge creates a named FIFO and consumes one JSON object per line. `OrcaSlicerProgress` exposes:

- `plate_index` / `plate_count`;
- `plate_percent`;
- `total_percent`;
- `message` or `warning`.

The workspace publishes this progress to the UI. While slicing, the top action becomes a determinate Cancel control.

Cancellation is process-owned: the bridge uses `Process.start`, keeps the active Orca process, terminates it on request, stops waiting on inherited stdout/stderr streams and reports `OrcaSlicerCancelledException` instead of a slicing failure.

The upstream `--pipe` callback manager is Linux-only in OrcaSlicer 2.4.2, so macOS/Windows keep normal slicing and process cancellation but do not yet receive native FIFO progress events.

## Linux packaged engine

The first release target is Linux x64. The portable bundle contract is:

- Flutter executable at the bundle root;
- `orca/OrcaSlicer.AppImage`;
- `orca/orca-engine.json` carrying version, upstream commit, platform and SHA-256 provenance.

Before the first packaged slice, `OrcaSlicerEngine.verifyPackagedEngine()` checks the manifest against the compile-time pin and streams SHA-256 over the actual AppImage. A mismatch is a hard error; the application does not silently run an unknown bundled engine. Bundled AppImage processes receive `APPIMAGE_EXTRACT_AND_RUN=1` so the release does not require FUSE to mount the image.

`.github/workflows/linux-release-smoke.yml` builds the Linux release with pinned Flutter 3.47.2, downloads the exact OrcaSlicer v2.4.2 Ubuntu 24.04 AppImage, verifies its digest, bundles it and runs the Dart packaged-discovery/provenance verifier. The same workflow now extracts the pinned Orca source before Flutter build, generates a 1547-entry QIDI `profile_catalog.json` from `resources/profiles/Qidi`, compiles it into the app, and launches the packaged binary under Xvfb for a production-stack offline slice-to-Preview smoke. Release smoke #27 validates that packaged path; release smoke #14 established the legal/source archive path.

## Current limitations

- Linux release bundles carry the pinned Orca AppImage, verify it at runtime, and compile a QIDI profile catalog derived from the same pinned Orca source revision. Development/unpackaged builds may still use `ORCA_SLICER_BIN` or the platform default.
- Native progress transport is verified on Linux only; equivalent macOS/Windows progress transport remains a packaging/integration task.
- Estimates, warnings and material usage are consumed; sliced thumbnails and additional vendor printer-payload metadata are not yet fully integrated.
- Generated multi-plate/object/volume editing is wired into Prepare and production 3MF, including modifier/support-enforcer/support-blocker creation, volume-scoped wall/infill overrides, and source-shaped support/seam/fuzzy-skin facet annotations. Prepare now materializes an ordered list of real QIDI filament slots and object-level extruder assignment is restricted to those slots. MMU `paint_color` remains open until the slot-state triangle bitstream above slot 2 is source-verified; viewport brush/hit-testing and wider per-volume overrides also remain open. Imported vendor 3MF stays on the lossless repack path.
- The Linux-first packaged-engine gate is verified. Windows/macOS bundling, updater behavior and their native progress transport remain pending and are not v0.1 blockers for the deliberately Linux-first target.

Engine CI downloads the pinned Ubuntu 24.04 AppImage, verifies its SHA-256, loads QIDI X-Plus 4 presets, slices a two-plate project 3MF containing normal/modifier/support volumes plus support/seam/fuzzy-skin facet annotations, validates both plate G-code entries, parses real `slice_info.config`, verifies the G-code statistics fallback and verifies real FIFO progress JSON. A separate Linux packaged release smoke builds the real Flutter release bundle, embeds pinned QIDI profiles, re-verifies bundled-engine discovery/provenance from the packaged filesystem layout, and launches the packaged app through production `ProfileRepository -> WorkspaceController -> OrcaSlicerEngine -> GCodeParser` flow. Release smoke #27 produced 5005 moves / 1988 extrusion moves with a 537 s estimate and 0.35 m filament from that path.

## Licensing and source delivery

QidiNewMorrax and the bundled OrcaSlicer engine are distributed under GNU AGPL-3.0. The Linux release bundle includes:

- `legal/AGPL-3.0.txt`;
- `legal/RELEASE-NOTICES.txt`;
- `legal/SOURCE-MANIFEST.txt` with the exact application commit, Orca commit, source archive names and SHA-256 values.

Release CI produces `qidi-new-morrax-source.tar.gz` from the exact checked-out application revision and `orcaslicer-source-8500fcdccaa10b5099ac20d252af3a7c560046f1.tar.gz` from the pinned upstream source. The binary and both source archives are uploaded together in CI; for `release: published`, the same three files are attached to the GitHub Release.

The app exposes a visible Legal notices dialog. QidiNewMorrax does not bundle or use OrcaSlicer's optional non-free Bambu networking plugin.

Release smoke #14 validates the technical notice/source-delivery path. This is engineering evidence, not a substitute for final legal review of a public release or unrelated third-party notices.
