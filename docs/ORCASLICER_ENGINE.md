# OrcaSlicer engine integration

QidiNewMorrax uses OrcaSlicer as its production slicing and G-code engine. Flutter/Dart owns the application shell, model/project state, QIDI profiles, Preview, Device/cloud integration, calibration workflows, and presentation. The application no longer maintains a custom Dart Clipper, perimeter generator, Arachne implementation, infill engine, support generator, or G-code generator.

## Pinned engine

- upstream: `OrcaSlicer/OrcaSlicer`
- release: `v2.4.2`
- commit: `8500fcdccaa10b5099ac20d252af3a7c560046f1`
- license: GNU AGPL-3.0

The executable may be supplied with `ORCA_SLICER_BIN`. Platform defaults are used when the environment variable is absent.

## Runtime boundary

The current Dart bridge is `lib/core/orca/orca_slicer_engine.dart`.

Prepare state is handed to Orca as:

1. current transformed mesh -> temporary STL;
2. selected resolved QIDI machine/process/filament profiles -> standalone JSON presets;
3. headless Orca CLI invocation using `--load-settings`, `--load-filaments`, `--slice`, `--export-3mf`, and `--outputdir`.

The sliced 3MF is the canonical engine output. For the current single-plate bridge, Dart extracts `Metadata/plate_1.gcode` and feeds it to the existing Dart G-code parser/Preview and Device flows.

## Current limitations

This cutover establishes the engine boundary; it does not yet complete release packaging.

- OrcaSlicer must currently be installed or configured with `ORCA_SLICER_BIN`.
- Current Prepare handoff flattens the active Dart mesh to STL; full multi-plate/project/modifier/paint metadata handoff is still pending.
- Progress-pipe integration, cancellation, multiple plates/extruders, sliced 3MF metadata consumption, and installer bundling remain pending.
- CI validates the Dart bridge and archive/profile/STL contracts. End-to-end Orca execution must be added to a runner with the pinned Orca binary before release.

## Licensing

OrcaSlicer is AGPL-3.0. Any distribution that includes or modifies the Orca engine must preserve the applicable license, notices, and source-code obligations. Release packaging must not ship the engine until those obligations and corresponding source/attribution delivery are explicitly implemented.
