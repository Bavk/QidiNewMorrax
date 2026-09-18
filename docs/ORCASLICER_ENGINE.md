# OrcaSlicer engine integration

QidiNewMorrax uses OrcaSlicer as its production slicing and G-code engine. Flutter/Dart owns the application shell, project state, QIDI profiles, Preview, Device/cloud integration, calibration workflows and presentation. The application does not maintain a parallel Dart slicer.

## Pinned engine

- upstream: `OrcaSlicer/OrcaSlicer`
- release: `v2.4.2`
- commit: `8500fcdccaa10b5099ac20d252af3a7c560046f1`
- Linux Ubuntu 24.04 AppImage SHA-256: `d12fb8c8eac1aecd2dfb6377acd48f994f8fa439ed5292fa532dd82880f029fd`
- license: GNU AGPL-3.0

The executable may be supplied with `ORCA_SLICER_BIN`. Platform defaults are used when the environment variable is absent.

## Runtime boundary

The Dart process bridge is `lib/core/orca/orca_slicer_engine.dart`.

Prepare/project state is handed to Orca as:

1. generated state -> Orca/Bambu production-extension project 3MF; imported vendor 3MF packages are repacked losslessly;
2. resolved QIDI machine/process/filament settings -> embedded `Metadata/project_settings.config` plus standalone preset JSON;
3. headless Orca CLI invocation using `--load-settings`, `--load-filaments`, `--slice`, `--export-3mf` and `--outputdir`;
4. sliced 3MF -> all available `Metadata/plate_N.gcode` entries for Preview and Device.

Multi-plate placement uses the same virtual-bed spacing convention as Orca, and the real pinned engine CI validates two plates in one `--slice 0` job.

## Progress and cancellation

On Linux, OrcaSlicer 2.4.2 implements CLI progress through `--pipe <fifo>`. The Dart bridge creates a named FIFO and consumes one JSON object per line. `OrcaSlicerProgress` exposes:

- `plate_index` / `plate_count`;
- `plate_percent`;
- `total_percent`;
- `message` or `warning`.

The workspace publishes this progress to the UI. While slicing, the top action becomes a determinate Cancel control.

Cancellation is process-owned: the bridge uses `Process.start`, keeps the active Orca process, terminates it on request, stops waiting on inherited stdout/stderr streams and reports `OrcaSlicerCancelledException` instead of a slicing failure.

The upstream `--pipe` callback manager is Linux-only in OrcaSlicer 2.4.2, so macOS/Windows keep normal slicing and process cancellation but do not yet receive native FIFO progress events.

## Current limitations

- OrcaSlicer must currently be installed or configured with `ORCA_SLICER_BIN`.
- Native progress transport is verified on Linux only; equivalent macOS/Windows progress transport remains a packaging/integration task.
- Rich sliced-3MF metadata (estimates, warnings, thumbnails and printer payload metadata) is not yet fully consumed by Dart.
- Rich Prepare editing for creating multiple plates/modifiers/paint/per-object settings still trails the already verified project serializer.
- Cross-platform bundled-engine packaging and exact-version/updater verification remain pending.

CI downloads the pinned Ubuntu 24.04 AppImage, verifies its SHA-256, loads QIDI X-Plus 4 presets, slices a two-plate project 3MF, validates both plate G-code entries and verifies real FIFO progress JSON.

## Licensing

OrcaSlicer is AGPL-3.0. Any distribution that includes or modifies the Orca engine must preserve the applicable license, notices and source-code obligations. Release packaging must not ship the engine until those obligations and corresponding source/attribution delivery are explicitly implemented.
