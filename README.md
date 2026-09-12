# Qidi Flow — strict 1:1 Flutter/Dart rewrite

This repository is the canonical workspace for a **complete 1:1 rewrite** of the supplied Qidi Flow 2.07.02.60 Pass28 application in Flutter + Dart.

## Non-negotiable target

The target is **the same application on another language/runtime**, not a redesign, not a compatible client, not a reduced reimplementation, and not a UI recreation.

Nothing that the supplied application implements may be silently lost. Every relevant screen, action, state, validation rule, file/project/profile field, slicer behavior, G-code rule, protocol operation, printer/cloud flow, calibration flow, desktop integration, localization/resource and testable edge case must remain represented until it has a verified Dart/Flutter replacement.

The authoritative acceptance rules are in [`migration/PARITY_CONTRACT.md`](migration/PARITY_CONTRACT.md). Read that file before changing code.

The old C++/wxWidgets/React implementation is specification/reference material only. It does **not** count as rewritten if it is still used at runtime through FFI, native libraries/executables, subprocesses, embedded legacy WebViews or hidden service wrappers.

For application-owned algorithms, port the same decision logic. A different Dart implementation is acceptable only after reference/differential tests prove the observable semantics required by the source. A source module is never considered migrated simply because a similarly named Dart file or visually similar screen exists.

## Traceability / loss prevention

`migration/original_file_manifest.json` is the source-file loss-prevention ledger. The migration is moving toward symbol-level traceability:

`source file / source symbol / behavior → Dart file / Dart symbol → reference tests → status`

Expected statuses distinguish `pending`, `port_started`, `implemented_unverified`, `parity_verified`, and verified runtime assets. Only `parity_verified` closes executable source behavior.

The source test suite is part of the specification. Applicable tests and fixtures must be translated or differentially reproduced in Dart/Flutter before corresponding modules can be called 1:1.

## Implemented foundations — not completion claims

Current code includes foundations for:

- Flutter desktop shell: Prepare, Preview, Device, Project and Calibration areas;
- Pass28-style Device workspace;
- Moonraker JSON-RPC WebSocket integration and QIDI LAN SSDP discovery;
- QIDI/Klipper commands, files/timelapse and QIDI Box command support;
- profile inheritance / `compatible_printers` filtering and runtime PO localization;
- G-code parsing/statistics;
- STL, OBJ, AMF/ZIP.AMF and package-aware 3MF import/repack with unknown-entry preservation;
- triangle-plane mesh slicing with explicit open/non-manifold paths;
- basic even-odd clipped line infill;
- basic toolpath/G-code pipeline;
- `ExPolygon2` and a Clipper-compatible boolean/offset layer preserving QIDI/Slic3r coordinate scaling;
- the first source-formula subset of `PerimeterGenerator::process_classic()`;
- translated Clipper/perimeter regression fixtures.

These items remain **unverified/incomplete wherever reference parity has not been executed**. In particular, the current pure-Dart Clipper2-backed geometry layer is an `implemented_unverified` compatibility implementation for source Clipper/ClipperUtils semantics; if the original Clipper regression suite reveals differences, it must be corrected or replaced by a direct Dart port of the required source behavior.

## Current status

This repository is **not yet the finished 1:1 application**. No top-level parity gate is closed yet. Major remaining work includes full geometry semantics, classic + Arachne perimeters, thin walls/gap fill, all surface/infill/support/bridge/travel/flow/cooling logic, complete G-code templates and estimates, full editor/multi-plate/project persistence, cloud/P2P/account/camera/HMS/firmware, all calibration workflows, remaining formats, OS integration, localization/UI detail parity and full translated/differential tests.

Unimplemented source branches must stay visibly pending or fail explicitly; they must not be hidden behind approximate behavior or clickable no-op UI.

## Continue development from another chat

Read, in this order:

1. [`migration/PARITY_CONTRACT.md`](migration/PARITY_CONTRACT.md)
2. [`docs/HANDOFF.md`](docs/HANDOFF.md)
3. `migration/MIGRATION_STATUS.md`
4. `migration/MODULE_MAP.md`
5. `migration/VALIDATION.md`
6. the latest commits and open master tracker issue

Every meaningful development batch must update the handoff/status together with code and tests.

## Running / validation

A Flutter SDK is required:

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

If desktop runner folders are absent during bootstrap:

```bash
flutter create --platforms=windows,macos,linux .
```

The environment used for the current migration work has not had a runnable Flutter/Dart SDK, so `flutter analyze`, `flutter test` and desktop builds must remain **unverified**, not assumed passing, until CI or a Flutter-enabled machine executes them.

## Assets

The local audited migration workspace previously verified **3,657/3,657 copied runtime assets** against the supplied source by SHA-256, with 0 missing and 0 changed. GitHub publication of binary assets must preserve those exact bytes; regenerated/recompressed substitutes are not allowed to masquerade as identical assets.

## License

The supplied project is AGPL-3.0-derived. Upstream licensing and attribution requirements remain applicable.