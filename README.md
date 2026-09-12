# Qidi Flow — Flutter/Dart rewrite

This repository is the canonical Flutter/Dart rewrite workspace created from the supplied Qidi Flow 2.07.02.60 Pass28 source archive.

## Non-negotiable migration rule

The source application is not treated as “just a UI”. It contains the QIDIStudio/BambuStudio/PrusaSlicer-derived slicing engine, 3D scene/editor, project and profile formats, G-code pipeline, local/cloud printer integrations, QIDI Box/AMS, calibration, file/timelapse handling, diagnostics, localization, and a large data/profile bundle. A rewrite is considered complete only when these behaviors are accounted for and parity-tested.

`migration/original_file_manifest.json` is the loss-prevention ledger from the source audit: source files may be considered replaced only after their behavior/data/license role has been ported or proven unnecessary.

## Implemented foundation

- Desktop-first Flutter shell: Prepare, Preview, Device, Project, Calibration.
- Pass28-style Device workspace.
- Moonraker JSON-RPC WebSocket integration and QIDI LAN SSDP discovery.
- QIDI/Klipper printer commands, files/timelapse, QIDI Box command support.
- Profile inheritance / `compatible_printers` filtering and runtime PO localization.
- G-code parser/statistics.
- STL, OBJ, AMF/ZIP.AMF, package-aware 3MF import and loss-preserving 3MF repack.
- Pure-Dart triangle-plane mesh slicing with explicit open/non-manifold paths.
- Pure-Dart line infill with even-odd clipping and nested-hole support.
- First basic perimeter/infill toolpath planner.
- Deterministic basic G-code writer using absolute XYZ + relative extrusion.
- Unit tests for the compatibility layers above.

## Important status

This is **not yet a truthful 1:1 completion of the ~755k-line native slicer/application code**. The largest remaining areas are robust polygon booleans/offsets, real perimeter/Arachne planning, solid surfaces, supports, bridges, travel/retraction, full profile-driven G-code, full editor/multi-plate, cloud/P2P/account/camera/HMS, calibration parity, all source formats, OS integration and complete test parity.

A wrapper around old C++, FFI bridge, embedded legacy WebView, or copied native binary does not count as a completed Dart rewrite.

## Continue development from another chat

**Read [`docs/HANDOFF.md`](docs/HANDOFF.md) first.** It is the canonical, regularly updated continuation document: what is done, what is not, exact next priorities, validation rules, Git workflow, and a ready-to-use prompt for another ChatGPT chat.

Also read:

- `migration/MIGRATION_STATUS.md`
- `migration/MODULE_MAP.md`
- `migration/VALIDATION.md`

Every meaningful development batch must update the handoff/status together with code and tests.

## Running

A Flutter SDK is required:

```bash
flutter pub get
flutter create --platforms=windows,macos,linux .   # bootstrap only if runners are absent
flutter analyze
flutter test
flutter run -d windows
```

The environment used for the initial rewrite did not contain Flutter/Dart SDK, so build/test status must remain unverified until CI or a Flutter-enabled machine executes these commands.

## Assets

The audited migration workspace contains thousands of original runtime assets. Their local migration copy was previously checked byte-for-byte: 3,657/3,657 copied runtime assets matched source SHA-256, with 0 missing and 0 changed. GitHub publication of all binary assets must preserve those exact bytes; do not regenerate/recompress them and call them identical.

## License

The supplied project is AGPL-3.0-derived. Upstream licensing and attribution requirements remain applicable.