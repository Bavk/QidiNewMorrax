# Validation record

## Input identity

- Supplied archive: `QidiFlow-2.07.02.60-Pass28-Device-Reference-Redesign-Clean(1).zip`
- SHA-256: `821ed379d65916df32f5d031bd583bc724ce72f4d229447adc61280701e4d57d`
- Extracted source files inventoried: **8,632**
- Every inventoried source file has a byte count, SHA-256 and migration status in `original_file_manifest.json`.

## Loss-prevention checks performed

- Runtime resources were copied from the supplied tree rather than recreated from screenshots. **All 3,657 manifest entries marked `copied_runtime_asset` were re-hashed after copying: 3,657/3,657 match their source SHA-256, with 0 missing and 0 mismatches.**
- `pubspec.yaml` explicitly declares every asset directory that contains files, including nested profile, localization, shader and calibration directories.
- The generated profile catalog contains **2,341** source profile JSON documents while the original individual JSON files remain in `assets/resources/profiles`.
- 3MF import retains every ZIP entry in memory and resolves external component model parts/build transforms instead of importing only the root XML mesh.
- Local QIDI discovery and Moonraker/Klipper command strings were taken from the supplied source behavior rather than guessed generic printer commands.
- Clickable no-op UI controls were removed or disabled when their corresponding parity work is still pending.

## Tests present in this tree

- Pure-Dart layer intersection / contour stitching tests.
- G-code parser/state-mode tests.
- ASCII and binary STL parser tests.
- Local QIDI/Klipper and cloud task contract tests.
- Even-odd clipped linear infill tests, including nested-hole behavior.
- Basic pure-Dart toolpath G-code writer contract test.

## Environment limitation

The environment used to prepare this rewrite does not contain a Flutter or Dart SDK, and outbound SDK installation was unavailable. Therefore `flutter analyze`, `flutter test` and desktop builds could not be executed here. This is explicitly **not** counted as passing build/test parity. Run:

```bash
flutter pub get
flutter analyze
flutter test
flutter create --platforms=windows,macos,linux .
flutter build windows
```

Repeat platform builds for macOS/Linux on their supported hosts.

## Completion truth

This validation file records a substantial migration start, not a claim of complete parity. `MIGRATION_STATUS.md`, `MODULE_MAP.md` and the per-file manifest remain the authority for unported behavior.
