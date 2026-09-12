# QidiNewMorrax — development handoff and continuation guide

> **Canonical repository:** `https://github.com/Bavk/QidiNewMorrax`
>
> **Goal:** completely rewrite the supplied Qidi Flow 2.07.02.60 Pass28 application in Flutter + Dart without silently dropping functionality or data. Native C++/wxWidgets/React code is reference material only; it is not considered a migrated implementation.

This file is the primary handoff for continuing development from another ChatGPT chat, another machine, or another developer. **Update it in every meaningful development batch** together with `migration/MIGRATION_STATUS.md`, tests, and the migration ledger.

## 1. Non-negotiable completion definition

The project is complete only when the Flutter/Dart application has behavior-level parity for all relevant capabilities of the supplied source archive:

1. model/project formats and metadata round-tripping;
2. complete 3D scene/editor behavior;
3. slicing/toolpath generation used by QIDI profiles;
4. G-code preview/statistics/estimation;
5. profile inheritance, compatibility and user presets;
6. local + cloud printer integration, QIDI Box/AMS, files, camera, diagnostics and firmware capabilities;
7. all calibration flows;
8. desktop OS integration;
9. localization/accessibility;
10. translated/replaced automated tests and parity fixtures.

A visually similar screen, an FFI bridge to the old slicer, a copied native executable/library, or an embedded legacy WebView does **not** satisfy the rewrite requirement.

## 2. Source-of-truth files

Read these before changing code:

- `docs/HANDOFF.md` — this document; current plan and continuation procedure.
- `migration/MIGRATION_STATUS.md` — parity gates and honest current status.
- `migration/MODULE_MAP.md` — source module sizing and port-start coverage.
- `migration/original_file_manifest.json` — per-source-file SHA-256/status ledger.
- `migration/status_counts.json` — summarized migration ledger counts.
- `migration/VALIDATION.md` — what has and has not actually been validated.
- `README.md` — end-user/developer overview.

The original archive used for the audit was `QidiFlow-2.07.02.60-Pass28-Device-Reference-Redesign-Clean(1).zip`.

## 3. What has already been implemented

### Application architecture/UI

- Flutter desktop-first shell with Prepare, Preview, Device, Project and Calibration areas.
- Pass28-inspired Device workspace with Overview / Control / Files / Automation organization.
- Unported actions are intentionally disabled instead of being fake clickable no-ops.

### Model I/O and project preservation

- ASCII + binary STL import.
- OBJ import.
- AMF and ZIP.AMF import, including units and constellation transforms.
- Package-aware 3MF import with external object resolution, component recursion, build transforms, unit conversion, project/model metadata retention, and preservation of unknown/vendor ZIP entries.
- 3MF repacking that keeps unknown binary/vendor entries and supports explicit replacement.
- Basic mesh transforms: translate, rotate, scale, center-on-bed.
- Flutter software wireframe viewport.

### Geometry and slicing foundation

- 2D/3D point and bounding-box primitives.
- Polygon area, centroid, containment and boundary-distance operations.
- Pure-Dart triangle/plane mesh slicing.
- Segment deduplication and contour stitching.
- Closed contours plus explicit open/non-manifold paths.
- Line infill generator with rotated scanlines and even-odd clipping, including nested holes.
- Basic toolpath planner converting valid slice contours to perimeter loops + alternating-angle infill while refusing layers with open paths.
- Deterministic basic G-code writer using absolute XYZ + relative extrusion and conservative Klipper/Marlin-style commands.

These last toolpath stages are foundations only. They are **not** parity with the native QIDI/PrusaSlicer toolpath engine yet.

### G-code

- G-code line parser with line numbers, parameters, checksums and comments.
- Basic statistics for motion/extrusion/temperature.
- Basic G-code emission from the new pure-Dart toolpath plan.

### Profiles/localization/assets

- Original JSON profile tree preserved in the local migration workspace.
- Generated profile catalog (~2.3k profiles) for startup performance.
- Profile inheritance and `compatible_printers` filtering.
- Original PO catalogs preserved and runtime PO reader implemented.
- Original non-executable runtime resources copied to the migration workspace.
- Previous integrity audit reported 3,657/3,657 copied runtime assets matching source SHA-256, 0 missing and 0 changed.

### Device integration

- QIDI LAN SSDP discovery on `239.255.255.250:5863`.
- Moonraker WebSocket JSON-RPC client and subscriptions.
- Raw printer state retention plus typed temperatures/progress/layers/fans/speed/light/excluded-object fields.
- Local commands for pause/resume/cancel, motion, temperatures, speed, fans, polar cooler and case light.
- Exclude-object support.
- QIDI Box load/unload/eject/RFID command support.
- File browsing/deletion and timelapse root browsing.
- Cloud task contract scaffolding for known dispatcher endpoints.

### Tests already present

Unit tests cover ASCII/binary STL, AMF units/transforms, 3MF unknown-entry preservation, G-code parsing/statistics, mesh slicing, QIDI command strings/cloud task contract, line-infill clipping with holes, and basic G-code writer output.

## 4. What is NOT complete

Do not describe any of these as done until implementation + parity tests exist.

### Slicer/toolpaths — highest priority

- robust polygon boolean/offset engine;
- correct perimeter offsets and multiple wall loops;
- Arachne variable-width walls and classic perimeter parity;
- top/bottom solid layers and skin detection;
- native infill patterns beyond basic lines;
- bridge detection/flow/speed;
- supports and interfaces;
- overhang logic, seam placement;
- retraction, wipe, travel avoidance and path ordering;
- ironing, brim/skirt/raft;
- prime/wipe tower and multi-material planning;
- adaptive layers;
- flow-role calculations matching the native slicer;
- cooling/fan scheduling;
- acceleration/jerk/input-shaper related emission where profiles require it;
- timelapse toolpath handling;
- profile start/end/layer-change template expansion;
- native-compatible print-time/material estimation;
- post-processing hooks.

### Scene/editor

- robust selection and object/part hierarchy;
- undo/redo command system;
- cut/split/merge/boolean operations and repair;
- lay-on-face/auto-orient/arrange;
- multi-plate behavior;
- modifiers/negative volumes;
- support/seam/color painting;
- text/emboss, measurement and remaining gizmos/shortcuts.

### Formats/project persistence

- full native project save semantics and all QIDI/Bambu metadata;
- STEP import;
- formats previously delegated to Assimp as enabled in the source build;
- exact import/export warnings and repair behavior;
- user preset import/export.

### Device/cloud

- full account/auth and cloud/P2P transport;
- camera streaming;
- HMS/diagnostics parity;
- firmware/update flows;
- every printer capability map;
- reconnect/offline restoration edge cases;
- complete QIDI Box state/control parity.

### Calibration / OS / release

- all original calibration wizards/pattern-generation flows;
- committed Flutter Windows/macOS/Linux runners;
- file associations, drag/drop, single instance, updater/release packaging, thumbnails/shell integration;
- CI release builds.

## 5. Immediate engineering priorities

Work in this order unless a failing parity test reveals a more fundamental dependency:

1. **Establish build/CI truth.** Generate desktop runners with a pinned Flutter stable version, run `flutter analyze` and `flutter test`, fix all errors, then add GitHub Actions.
2. **Geometry kernel.** Implement/test polygon boolean + offset operations robust enough for slicer use.
3. **Perimeter planner.** Replace contour-as-wall placeholder with real offset wall loops; test polygons, holes, thin walls and degenerates.
4. **Solid regions + infill.** Detect top/bottom surfaces, internal sparse regions and bridge candidates.
5. **Extrusion/path planner.** Add role-aware flow, ordering, retraction/travel and speed/acceleration selection from source profiles.
6. **Profile-driven G-code.** Expand machine start/end/layer templates and map source settings instead of hardcoded writer defaults.
7. **Preview parity.** Render toolpaths by feature/tool/layer and expose estimates/statistics.
8. **Project persistence/editor.** Expand 3MF serialization and scene model alongside undoable editing operations.
9. **Device/cloud/calibration.** Continue feature matrices with tests and protocol fixtures.

## 6. Rules for every future development chat

When starting another chat, tell it to:

1. read `docs/HANDOFF.md`, `migration/MIGRATION_STATUS.md`, `migration/MODULE_MAP.md`, and `migration/VALIDATION.md` first;
2. inspect latest commits/PRs before editing;
3. treat `main` as canonical unless a feature branch is explicitly active;
4. implement real behavior, not UI-only placeholders;
5. add/extend tests for every ported subsystem;
6. update migration ledger/status when source behavior is replaced;
7. update **this handoff file** in the same change set with implemented work, validation, remaining work, exact next task, and known risks;
8. commit/push to `Bavk/QidiNewMorrax` (prefer a feature branch + PR for risky changes);
9. never claim completion while any parity gate is open.

### Suggested prompt for another chat

> Continue development of `https://github.com/Bavk/QidiNewMorrax`. This is a complete Flutter/Dart rewrite of Qidi Flow 2.07.02.60 Pass28; losing functionality is not allowed and using the old C++/wxWidgets/React implementation as a runtime backend does not count as a rewrite. First read `docs/HANDOFF.md` and all `migration/*.md` status documents, inspect the latest repository commits, then continue the highest-priority unfinished parity work. Add tests, push your changes to the repository, and update `docs/HANDOFF.md` plus migration status before finishing. Do not mark unimplemented behavior as complete and do not create fake clickable stubs.

## 7. Development/validation commands

Once Flutter is installed and platform runners exist:

```bash
flutter --version
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

If runner folders are absent during bootstrap:

```bash
flutter create --platforms=windows,macos,linux .
```

## 8. Git workflow

Canonical remote:

```bash
git remote add origin https://github.com/Bavk/QidiNewMorrax.git
# or
git remote set-url origin https://github.com/Bavk/QidiNewMorrax.git
```

Recommended for substantial work:

```bash
git switch main
git pull --ff-only
git switch -c feature/<short-topic>
# edit + test
git add -A
git commit -m "feat: <what changed>"
git push -u origin feature/<short-topic>
```

## 9. Asset publication note

The local migration workspace contains thousands of preserved runtime resources, many binary. The GitHub connector used during repository bootstrap can create Git objects but does not expose Git LFS. Source code/docs/tests should be pushed immediately; binary asset publication must preserve exact bytes and should use normal Git/Git LFS from a machine with authenticated git access if connector payload limits prevent direct publication. **Do not regenerate or recompress source assets and then call them identical**; verify against `migration/original_file_manifest.json` hashes.

Until binary publication is verified in GitHub, this is an explicit repository-bootstrap gap, not a completed gate.

## 10. Current known validation limitation

The environment that produced the initial Flutter rewrite did not have Flutter/Dart SDK installed, so it could not truthfully run `flutter analyze`, `flutter test`, or a desktop build. New source/tests in this batch also require CI or a Flutter-enabled machine before their status can be upgraded from code-reviewed to execution-validated.

## 11. Last handoff update

Current batch:

- canonical GitHub repository selected: `Bavk/QidiNewMorrax`;
- repository admin/push access verified;
- handoff/continuation protocol established;
- line infill engine implemented with even-odd clipping and hole support;
- basic toolpath planner implemented;
- basic G-code writer implemented;
- unit tests added for infill and writer contracts;
- next engineering task: **build/CI truth first, then robust polygon offset/boolean geometry and real perimeter generation**.
