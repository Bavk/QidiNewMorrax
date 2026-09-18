# QidiNewMorrax architecture and acceptance contract

This contract supersedes the earlier pure-Dart slicer rewrite requirement.

## Product target

QidiNewMorrax remains a Flutter/Dart desktop application for QIDI workflows, but the slicer is now an explicit external engine boundary. Flutter/Dart owns user-facing application behavior; OrcaSlicer owns slicing and G-code generation.

## Runtime architecture

Production runtime may launch the pinned OrcaSlicer executable as a subprocess. This is intentional and is no longer considered a migration failure.

The application must not maintain a second production slicing implementation. Custom Dart Clipper/Arachne/perimeter/infill/support/G-code generation code is out of scope and must not be reintroduced without an explicit architecture change.

## Pinned slicer contract

The baseline engine is OrcaSlicer v2.4.2 at commit `8500fcdccaa10b5099ac20d252af3a7c560046f1`.

The integration must preserve:

- selected QIDI machine/process/filament settings;
- model transforms, plate/object state and printable geometry;
- Orca validation failures and warnings;
- sliced 3MF/G-code output;
- Preview-visible toolpath semantics;
- printer-delivery artifacts;
- deterministic version/provenance information needed to reproduce a slice.

## Dart-owned contract

Flutter/Dart remains responsible for:

- UI/navigation/editor behavior;
- project/profile persistence and preservation of vendor metadata;
- QIDI profile selection and compatibility;
- Preview and slice-result presentation;
- Device/cloud/local-printer workflows;
- calibration orchestration;
- localization/accessibility and desktop integration.

## Testing

Acceptance is split at the engine boundary:

1. Dart tests validate request construction, profile/materialization, model/project handoff, result extraction, Preview parsing and application state.
2. Engine integration tests execute the pinned OrcaSlicer binary on representative QIDI projects and verify successful output plus selected golden invariants.
3. Release tests verify the exact bundled Orca version/commit and licensing/source notices.

Historical Dart Clipper/Arachne parity tests are no longer production acceptance gates.

## Licensing

OrcaSlicer is GNU AGPL-3.0. Release packaging must satisfy all applicable license, notice and corresponding-source obligations before distribution.
