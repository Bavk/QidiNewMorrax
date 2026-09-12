# Migration status / parity contract

## Source audit

- Archive files inventoried: see `original_file_manifest.json`.
- Runtime data copied: profiles, printers, models, calibration data, fonts, images, shaders, certificates, i18n and PO catalogs.
- Legacy WebView JS/TS and native helpers are **not** executed by the Flutter application. Their behavior remains explicitly tracked as pending until replaced.

## Parity gates before calling the rewrite “complete”

1. **Formats:** open/save 3MF/project files, STL/OBJ and all formats used by the original build; preserve metadata and per-object/per-plate settings.
2. **Scene/editor:** selection, move/scale/rotate, cut, split, repair, combine, text/emboss, painting, supports, seams, multi-plate, undo/redo and shortcuts.
3. **Slicer:** identical-enough toolpath semantics for supported QIDI profiles: walls, Arachne/classic perimeters, infill families, bridges, supports, ironing, brim/skirt, wipe/prime tower, multi-material, adaptive layers, overhang logic, travel/retraction, cooling, timelapse and post-processing.
4. **Preview:** layer/tool/color/feature views, G-code statistics, time/material estimates and interactions.
5. **Profiles:** machine/filament/process inheritance, compatibility conditions, defaults, user presets, import/export and validation.
6. **Device:** local discovery, local Moonraker, cloud printer selection/control, QIDI Box/AMS, files, timelapses, camera, HMS, firmware/device capabilities, reconnect and state restoration.
7. **Calibration:** every original wizard and generated calibration pattern.
8. **OS integration:** file associations, drag/drop, single-instance behavior, desktop integration, update flow, thumbnails where applicable.
9. **Localization/accessibility:** all shipped languages and keyboard navigation.
10. **Tests:** original behavioral tests translated to Dart/Flutter or replaced by equivalent golden/unit/integration tests.

## Current honest coverage

The current tree establishes the Flutter architecture and ports several high-value compatibility layers, including STL/OBJ/AMF and package-aware 3MF handling, source profile loading, local QIDI/Moonraker device control, G-code parsing/preview, pure-Dart triangle-plane slicing, even-odd clipped line infill, a first basic toolpath planner, and deterministic basic G-code emission. These toolpath stages are foundations and are not parity with native perimeter offsets/Arachne/support/travel/flow planning. The project is not yet at parity gate completion. See `status_counts.json` and per-file statuses in the manifest for exact audit state.
