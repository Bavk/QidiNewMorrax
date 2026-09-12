# QidiNewMorrax — canonical development handoff

> **Canonical repository:** `https://github.com/Bavk/QidiNewMorrax`
>
> **Source target:** supplied Qidi Flow 2.07.02.60 Pass28 tree.
>
> **Final requirement:** reproduce the application **1:1 in Flutter + Dart**. It must be the same application and implementation behavior on another language/runtime, with no lost function, workflow, data contract, algorithmic edge case or runtime resource.

This is the primary continuation document for every future ChatGPT chat/developer. **Read it before coding and update it after every meaningful development batch.**

The strict acceptance authority is [`migration/PARITY_CONTRACT.md`](../migration/PARITY_CONTRACT.md). If any shortcut conflicts with that contract, the contract wins.

---

## 1. Non-negotiable meaning of “rewrite 1:1”

The target is **not**:

- a similar slicer;
- a compatible printer client;
- a redesigned Flutter UI;
- a subset containing the most commonly used features;
- a UI shell around the old C++ engine;
- an FFI/subprocess/native-library wrapper;
- an embedded copy of the old React DeviceWeb application;
- an implementation that produces roughly comparable output in normal cases.

The target **is the supplied application, completely reimplemented in Flutter/Dart**.

For every source capability, preserve where applicable:

1. screens, dialogs, popovers, context menus, wizards and navigation;
2. every command/action and its enabled/disabled/hidden rules;
3. keyboard shortcuts, mouse/drag/drop and selection behavior;
4. validation, warnings, errors, confirmations and recovery paths;
5. source defaults, settings, inheritance, compatibility expressions and user presets;
6. all supported file/project formats and QIDI/Bambu/Prusa/vendor metadata behavior;
7. slicing/geometry/toolpath algorithms and source-required numeric/degenerate behavior;
8. G-code templates, command ordering, flow/speed/cooling/travel behavior, statistics and estimates;
9. preview feature classification and interactions;
10. LAN/cloud/P2P/device protocols, reconnects, capability gating, QIDI Box/AMS, camera, HMS, files, timelapses and firmware flows;
11. every calibration workflow and generated artifact/toolpath;
12. desktop integration and release behavior present in the source;
13. every shipped localization/resource that participates in runtime presentation/behavior;
14. quirks and edge cases relied upon by other source modules;
15. applicable original tests and fixtures.

A module is not “done” because a Dart class exists or because the UI looks correct.

### Runtime language rule

The old C++/wxWidgets/React code may be inspected as specification/reference material only. Production behavior must not remain delegated to it through FFI, copied `.dll/.so/.dylib`, native executables, subprocesses, hidden local services or embedded legacy WebViews.

### Algorithm rule

For application-owned algorithms, preserve the same source decision logic unless a deliberately different Dart implementation is proven equivalent against source/reference fixtures across normal and edge cases.

For third-party algorithms used by the source, use the same algorithm semantics/version where feasible, or prove a replacement with the original regression suite. “Works for typical geometry” does not establish parity.

---

## 2. Required source-of-truth files

Read these first, in this order:

1. `migration/PARITY_CONTRACT.md` — strict 1:1 acceptance contract.
2. `docs/HANDOFF.md` — this continuation document.
3. `migration/MIGRATION_STATUS.md` — current gates and exact verification state.
4. `migration/MODULE_MAP.md` — source sizing/module coverage.
5. `migration/original_file_manifest.json` — source-file SHA-256/status ledger.
6. `migration/status_counts.json` — ledger summary.
7. `migration/VALIDATION.md` — tests/builds actually executed versus merely authored.
8. `README.md` — repository overview.
9. GitHub Issue #1 — long-running top-level parity tracker.
10. latest commits/PRs before changing any code.

Original audited archive:

`QidiFlow-2.07.02.60-Pass28-Device-Reference-Redesign-Clean(1).zip`

The archive audit inventoried **8,632 source-tree files**. A previous local integrity pass verified **3,657/3,657 copied runtime assets** against source SHA-256 with 0 missing and 0 mismatches.

---

## 3. Traceability rule — mandatory from now on

The migration must converge to symbol/behavior traceability, not just file-level checkboxes:

`source file → source class/function/behavior → Dart file → Dart symbol → reference/parity tests → status`

Use these meanings:

- **`pending`** — no real Dart replacement.
- **`port_started`** — only a subset of the source behavior exists.
- **`implemented_unverified`** — intended implementation exists but source parity has not actually been executed/proven.
- **`parity_verified`** — required implementation plus translated/differential tests pass against source expectations.
- **`runtime_asset_verified`** — data preserved byte-for-byte or with a specifically documented canonical transformation.

Only `parity_verified` closes executable source behavior.

When a Dart substitute deliberately differs internally, record why and which differential fixtures prove equivalent relevant behavior.

---

## 4. Test rule — original tests are specification

Do not replace the original test intent with easier tests.

For every migrated subsystem:

1. locate applicable original unit/regression/integration tests;
2. translate their fixtures, numeric tolerances and edge cases to Dart/Flutter;
3. preserve source reference files where licensing/project structure permits;
4. add differential/golden comparisons for observable behavior not covered by the original tests;
5. compare serialized packages, generated G-code/toolpaths, protocol payloads and state transitions against source outputs whenever deterministic comparison is possible;
6. keep failure/degenerate cases, not only happy paths;
7. do not upgrade a module to `parity_verified` before the required tests have actually run successfully.

---

## 5. Implemented foundations so far

The sections below describe code that exists. They **do not imply top-level parity completion**.

### Flutter application architecture / UI

- Desktop-first Flutter shell with Prepare, Preview, Device, Project and Calibration areas.
- Pass28-oriented Device workspace with Overview / Control / Files / Automation organization.
- Unported actions are disabled instead of being fake clickable no-ops.

**Status:** `port_started`; final UI must reproduce source layouts, dialogs, states, shortcuts and workflows 1:1 rather than remain merely Pass28-inspired.

### Model I/O / package preservation

- ASCII and binary STL import.
- OBJ import.
- AMF and ZIP.AMF import including units and constellation transforms.
- Package-aware 3MF import with external model-part resolution, component recursion, build transforms and unit conversion.
- 3MF package preservation of unknown/vendor ZIP entries and replacement/repacking support.
- Basic mesh translate/rotate/scale/center-on-bed.
- Software wireframe viewport.

**Status:** mostly `port_started` / `implemented_unverified`. Full source project serialization, STEP/Assimp-enabled formats, warnings/repair semantics and complete QIDI/Bambu metadata remain open.

### Geometry / mesh slicing

- 2D/3D point, polygon and bounding-box primitives.
- triangle/plane mesh slicing;
- segment deduplication/contour stitching;
- closed contours plus explicit open/non-manifold paths;
- `ExPolygon2` contour + holes model;
- Clipper-compatible Dart geometry facade with union/difference/intersection/xor, offset, offset2, opening and closing;
- source scale preserved: `SCALING_FACTOR = 0.00001`, i.e. 100000 integer geometry units/mm;
- source default miter limit `3.0` preserved in compatibility calls.

The current Clipper facade uses the pure-Dart `clipper2` package. The supplied source includes Clipper 6.x semantics plus substantial `ClipperUtils` behavior. Therefore this implementation is explicitly **`implemented_unverified`** until translated source regression fixtures pass. If semantic mismatches are found, fix the compatibility layer or port the required source Clipper implementation directly. Do not rationalize a difference as “close enough”.

### Translated Clipper reference fixtures

Initial Dart tests have been translated from source Clipper tests, including:

- constant positive/negative box offsets;
- offsets with holes;
- non-zero winding union behavior;
- intersection preserving holes;
- difference creating holes.

These tests have been authored but **not executed in the current environment** because Flutter/Dart tooling is unavailable here.

### Classic perimeter port — current exact boundary

`ClassicPerimeterShellGenerator` has started a source-formula port of the onion-shell portion of `PerimeterGenerator::process_classic()`.

Currently represented:

- source `INSET_OVERLAP_TOLERANCE = 0.4`;
- QIDI `SMALLER_EXT_INSET_OVERLAP_TOLERANCE = 0.22`;
- narrow-loop length threshold `10`;
- requested wall loop calculation (`wall_loops + extra_perimeters - 1`);
- `alternate_extra_wall` increment on odd layers when not spiral vase;
- first external centerline inset by half external width;
- QIDI smaller-external-width probe/branch;
- precise outer-wall external→internal spacing branch;
- spiral-vase largest-island selection;
- internal `offset2` formula including the literal one source-coordinate-unit safety adjustment, mapped to **0.00001 mm**.

Not yet represented and therefore still pending:

- source `detect_thin_wall` medial-axis/thick-polyline behavior;
- gap-fill extraction;
- all remaining classic-perimeter paths/ordering/overhang behavior;
- Arachne;
- later surface/toolpath stages.

`detectThinWall=true` currently throws `UnsupportedError` intentionally. This is preferable to silently shipping a different algorithm.

### Infill/toolpath/G-code foundations

- rotated line infill with even-odd clipping and holes;
- basic perimeter/infill toolpath plan;
- layer-angle alternation;
- rejection of open/non-manifold slice paths in the basic planner;
- deterministic basic G-code writer with absolute XYZ/relative extrusion.

**Status:** foundations only. They are not replacements for native fill/perimeter/path/G-code generation and must eventually be either replaced or integrated into exact source-equivalent implementations.

### Profiles/localization/assets

- source JSON profile loading/inheritance;
- `compatible_printers` filtering;
- generated profile catalog for startup;
- PO localization reader;
- local copied resource tree and prior SHA-256 asset verification.

**Status:** `port_started`; compatibility expressions, every preset behavior, user preset persistence/import/export and full UI binding still require source parity.

### Device integration

- QIDI SSDP discovery on `239.255.255.250:5863`;
- Moonraker WebSocket JSON-RPC client/subscriptions;
- raw printer status retention plus typed common fields;
- pause/resume/cancel, motion, temperatures, speed, fans, polar cooler, case light;
- excluded-object operations;
- QIDI Box load/unload/eject/RFID commands;
- file deletion/listing and timelapse root listing;
- known cloud task contract scaffolding.

**Status:** `port_started`. Full account/auth/cloud/P2P, camera, HMS/diagnostics, firmware, all capability maps, reconnect/offline restoration and complete QIDI Box state behavior remain pending.

---

## 6. Major areas still NOT complete

Nothing in this section may be described as complete until its source implementation and reference tests are accounted for.

### Slicer / geometry / toolpaths — highest dependency chain

- complete Clipper/ClipperUtils semantics and regression coverage;
- medial-axis/thick-polyline geometry;
- complete classic perimeter generation;
- thin walls and gap fill;
- Arachne variable-width walls;
- surface classification and top/bottom skins;
- every source-enabled infill family and its exact parameters;
- bridges and bridge flow/direction/speed;
- supports/interfaces/tree or other source-supported support logic;
- overhang handling;
- seams;
- role-aware extrusion flow/spacing;
- travel ordering/avoidance, retract, wipe;
- ironing;
- brim/skirt/raft;
- multi-material/purge/prime/wipe structures;
- adaptive layers;
- cooling and fan scheduling;
- speed/acceleration/jerk/input-shaping-related emission where used;
- timelapse toolpath modifications;
- source template expansion and custom G-code;
- post-processing;
- native-compatible time/material estimation and preview classification.

### Scene/editor

- exact scene/object/part hierarchy and selection;
- complete transform gizmos and source interaction rules;
- undo/redo command system;
- cut/split/merge/repair/boolean operations;
- arrange/orient/lay-on-face;
- modifiers/negative volumes;
- multi-plate;
- support/seam/color painting;
- text/emboss;
- measurement and remaining gizmos;
- all shortcuts/context actions/dialogs.

### Formats/project persistence

- complete project save and round-trip semantics;
- all per-object/per-volume/per-plate settings;
- all metadata/images/custom G-code/source package entries;
- STEP;
- every format enabled through source Assimp/build configuration;
- identical warnings/repair behavior;
- preset import/export.

### Device/cloud

- account/auth;
- full cloud/P2P transport;
- camera streaming;
- HMS/diagnostics;
- firmware/update flows;
- every printer model capability matrix;
- reconnect/offline/state restoration edge cases;
- complete QIDI Box/AMS state machine and UI parity.

### Calibration / OS / release / localization

- every original calibration wizard and generated artifact;
- committed Windows/macOS/Linux Flutter runners;
- file associations, drag/drop, single instance, thumbnails/shell integrations;
- updater/packaging/release flow;
- complete original localization/resource usage;
- keyboard/accessibility parity;
- CI/release builds.

---

## 7. Immediate engineering order

Do work in dependency order; do not jump to visually impressive UI if core source behavior beneath it is missing.

### Priority 0 — establish executable truth

1. run a pinned compatible Flutter/Dart toolchain (current repo dependency set requires Dart >= 3.7 because of pure-Dart Clipper2);
2. run `flutter pub get`;
3. run `flutter analyze`;
4. run all tests;
5. fix compilation/API errors before assigning any new `parity_verified` status;
6. add GitHub Actions so subsequent commits cannot silently break tests.

### Priority 1 — source geometry semantics

1. translate more of `test_clipper_offset.cpp`, `test_clipper_utils.cpp` and related source geometry tests;
2. execute them against `ClipperGeometry`;
3. fix all Clipper1/ClipperUtils semantic mismatches;
4. port any missing source ClipperUtils operations called by slicer/editor;
5. establish behavior fixtures for nested islands, touching paths, degenerates, very small source-unit values and winding rules.

### Priority 2 — classic perimeter dependencies

1. port medial-axis/thick-polyline source logic used by `detect_thin_wall`;
2. port gap-fill geometry;
3. continue `PerimeterGenerator::process_classic()` line-by-line;
4. translate corresponding perimeter tests/fixtures;
5. only then replace the old basic “contour-as-wall” planner path.

### Priority 3 — Arachne / surfaces / fill / path planning

Proceed source-module by source-module with the same traceability/test rule.

### Parallel priorities after core truth

- full project serialization/editor;
- profile-expression/preset parity;
- preview parity;
- device/cloud/camera/HMS;
- calibration;
- OS/release/UI/localization detail parity.

---

## 8. Rules for EVERY future ChatGPT chat / developer

At the start:

1. open `migration/PARITY_CONTRACT.md` first;
2. read this entire `docs/HANDOFF.md`;
3. read all migration status/validation files;
4. inspect latest GitHub commits/issues/PRs;
5. locate the exact original source files/functions/tests for the next work item before implementing it.

While coding:

6. port source behavior, not an invented simplified substitute;
7. preserve source constants/formulas/edge cases unless a tested equivalent is intentionally chosen;
8. never call old C++/React at runtime to avoid rewriting it;
9. do not create fake clickable stubs;
10. explicitly fail/disable an unported branch rather than silently produce a different result;
11. translate applicable source tests alongside implementation;
12. add differential/golden fixtures when necessary.

Before finishing a batch:

13. run available analyze/tests/builds and record what actually ran;
14. update source→Dart→test traceability/status;
15. update `migration/MIGRATION_STATUS.md`;
16. update **this file** with exact implemented source symbols/branches, verification performed, unresolved differences and exact next task;
17. push all changes to `Bavk/QidiNewMorrax`;
18. update master Issue #1 when top-level status changes;
19. never claim project/module completion while required source behavior remains pending/unverified.

### Ready-to-use prompt for a new chat

> Continue development of `https://github.com/Bavk/QidiNewMorrax`. The requirement is a COMPLETE 1:1 Flutter/Dart rewrite of the supplied Qidi Flow 2.07.02.60 Pass28 application: the same application on another language/runtime, with no function, implementation behavior, file/profile/project data, protocol flow, UI workflow, slicer algorithm, calibration, resource or edge case silently lost. The old C++/wxWidgets/React code is reference only and must not be used as the runtime backend. First read `migration/PARITY_CONTRACT.md`, then the entire `docs/HANDOFF.md`, all `migration/*.md`, latest commits and Issue #1. Locate the exact original source functions/tests for the highest-priority unfinished dependency and port them to Dart/Flutter with translated/differential tests. Do not accept “close enough”, do not mark authored-but-unexecuted code as parity-verified, and do not create fake stubs. Push changes to GitHub and update HANDOFF/status/traceability before finishing.

---

## 9. Development / validation commands

Once a Flutter environment is available:

```bash
flutter --version
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

If runners are absent during bootstrap:

```bash
flutter create --platforms=windows,macos,linux .
```

Then validate platform builds on supported hosts.

---

## 10. Git workflow

Canonical remote:

```bash
git remote add origin https://github.com/Bavk/QidiNewMorrax.git
# or
git remote set-url origin https://github.com/Bavk/QidiNewMorrax.git
```

For substantial/risky work prefer a branch + PR; otherwise keep `main` coherent and never leave imported Dart files without their dependencies/tests.

---

## 11. Binary asset publication gap

The local migration workspace contains thousands of original binary/runtime resources. The GitHub connector does not expose Git LFS. The previous local integrity audit verified 3,657/3,657 copied runtime assets by SHA-256, but **GitHub publication of all of those binary bytes is still a repository-bootstrap gap until verified in the remote repository**.

Do not regenerate/recompress source assets and then label them identical. Preserve exact bytes or explicitly document and test an intentional canonical transformation.

---

## 12. Current validation limitation

The current execution environment has not provided a runnable Flutter/Dart SDK. Therefore newly authored Dart code/tests are not promoted to `parity_verified`. This is a hard status distinction, not a paperwork detail.

The repository now requires Dart >= 3.7 for the selected pure-Dart Clipper2 dependency. CI/toolchain selection must respect that requirement or the dependency choice must be revisited.

---

## 13. Last handoff update — current batch

User requirement was re-confirmed and strengthened to: **FULL application 1:1, same implementation behavior on another language, no lost function or implementation.**

Completed in this batch:

- added `migration/PARITY_CONTRACT.md` as the strict acceptance authority;
- changed project language from general “feature parity” to explicit 1:1 source behavior;
- introduced mandatory `pending / port_started / implemented_unverified / parity_verified` semantics;
- made applicable original tests part of the formal specification;
- required symbol-level `source → Dart → test → status` traceability;
- added `ExPolygon2`;
- added a pure-Dart Clipper compatibility layer for boolean operations and offsets;
- preserved source geometry scaling (`0.00001 mm` per integer unit) and default miter limit (`3.0`);
- translated initial cases from source `test_clipper_offset.cpp` / `test_clipper_utils.cpp`;
- started a line/formula-level port of `PerimeterGenerator::process_classic()` onion-shell generation;
- preserved QIDI-specific external inset tolerance `0.22`, common inset tolerance `0.4`, narrow-loop threshold `10`, alternate-extra-wall behavior, precise external→internal spacing and one-source-unit offset safety term;
- explicitly left the source thin-wall medial-axis branch unsupported instead of faking it;
- updated `README.md` and `migration/MIGRATION_STATUS.md` to the stricter contract.

Verification in this environment:

- source code and source tests were inspected directly;
- implementation/tests were authored and committed;
- **Flutter analyze/test/build were not executed**, so geometry/perimeter work remains unverified.

Exact next work:

1. establish Dart/Flutter CI and execute the new source-derived fixtures;
2. resolve every failing Clipper semantic difference;
3. continue original Clipper/ClipperUtils test translation;
4. port medial-axis/thick-polyline logic used by `detect_thin_wall` and gap fill;
5. resume `PerimeterGenerator::process_classic()` from that dependency boundary.
