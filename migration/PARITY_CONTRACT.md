# QidiNewMorrax — strict 1:1 parity contract

This file defines the acceptance rule for the Qidi Flow 2.07.02.60 Pass28 → Flutter/Dart rewrite. It is stricter than “feature parity”, “similar behavior”, “compatible implementation” or “UI recreation”.

## Final target

The final Flutter/Dart application must be a **1:1 replacement of the supplied application** from a user-visible, data, protocol and algorithmic-behavior point of view.

A migration item is complete only when the original capability has been reimplemented in Dart/Flutter and all observable behavior that matters to users, files, printers, network peers and downstream tooling is preserved.

The target includes every relevant source feature, not only currently visible Pass28 screens.

## What must not be lost

For every source subsystem we must preserve, where applicable:

- every screen, dialog, panel, wizard, context menu, action, state and navigation route;
- every keyboard shortcut, mouse/gesture interaction, drag/drop path and selection rule;
- every validation rule, error condition, warning, confirmation and recovery path;
- every model/project/profile setting, default, inheritance rule, compatibility expression and serialization field;
- every supported import/export/project format and source-specific metadata extension;
- every slicing/toolpath algorithm and the edge-case behavior required by the original regression suite;
- every G-code generation rule, template expansion, post-process step, estimate/statistic and preview classification;
- every local/cloud/device protocol operation, reconnect/state behavior, QIDI Box/AMS capability, file/timelapse/camera/HMS/firmware flow;
- every calibration mode and generated calibration artifact;
- every desktop integration behavior that the original shipping application exposes;
- every shipped localization/resource that affects runtime behavior or presentation;
- every original testable quirk that another part of the application relies on.

“Close enough” is not a completion criterion.

## Implementation preservation rule

The application runtime must be Flutter + Dart. The old C++/wxWidgets/React implementation may be read as the specification/reference, but it must not remain the production runtime implementation through FFI, subprocess execution, copied native libraries/executables, embedded legacy WebViews or hidden service wrappers.

Where source code contains application-owned algorithms, the Dart implementation must preserve the same algorithm/decision logic unless a deliberately different Dart implementation is proven behaviorally equivalent by reference fixtures covering normal and edge cases.

Where the source uses a third-party algorithm/library, one of the following is required:

1. port/use a Dart implementation of the same algorithm/version and verify source regression behavior; or
2. use a replacement implementation only after parity tests prove identical relevant semantics for the application.

A substitute library that merely handles the common case does not close the source module.

## Traceability requirement

Every source item must remain traceable until completion.

The migration ledger must ultimately support mapping at least:

`source file / source class-or-function / behavior → Dart file / Dart symbol / parity tests / status`

Statuses must distinguish at minimum:

- `pending` — no Dart replacement yet;
- `port_started` — implementation exists but is incomplete or not fully verified;
- `implemented_unverified` — intended implementation exists but source parity has not been executed/proven;
- `parity_verified` — implementation and reference tests demonstrate the required 1:1 behavior;
- `runtime_asset_verified` — runtime data is preserved byte-for-byte or by explicitly verified canonical transformation.

A source file must not be considered migrated because a similarly named Dart file exists.

## Test rule

The original source tests are part of the specification.

For each migrated subsystem:

1. translate applicable original tests to Dart/Flutter;
2. retain the original fixtures and numeric tolerances unless there is a documented language/platform reason not to;
3. add differential/golden fixtures when the source test suite does not fully capture observable behavior;
4. compare serialized files, G-code/toolpaths, protocol payloads and state transitions against source reference outputs where deterministic comparison is possible;
5. test failure and degenerate inputs, not only happy paths.

A module cannot become `parity_verified` if its required tests have not run successfully.

## UI 1:1 rule

The final UI is not allowed to be merely “inspired by” the source. The target is the same application behavior and presentation translated to Flutter:

- same information architecture and feature availability;
- equivalent layout, controls, states and workflows;
- equivalent enabled/disabled/hidden rules;
- equivalent modal behavior and interactions;
- same functional keyboard/mouse workflows;
- assets, text and localization preserved unless the source itself selects them dynamically.

Platform-native rendering differences that do not alter behavior are acceptable; missing or redesigned functionality is not.

## Data-loss rule

Opening, editing and saving supported source projects must not silently discard data, including unknown/vendor metadata that the original preserves.

The migration must maintain round-trip tests for representative source project files and edge-case fixtures. Unknown source package entries must be retained when the original retains them.

## Slicer 1:1 rule

The slicer is a first-class part of the rewrite, not an external dependency to call back into the old application.

Completion requires parity for the source algorithms and interactions relevant to QIDI profiles, including geometry cleanup, boolean/offset semantics, classic/Arachne walls, surfaces, infill families, gap fill, bridges, supports, seams, overhangs, multi-material behavior, purge/prime structures, travel/retraction/wipe, cooling, adaptive layers, ironing, brim/skirt/raft, G-code templates, acceleration/speed/flow decisions, timelapse/post-processing, estimates and preview feature classification.

The source Clipper/ClipperUtils regression tests are part of the geometry acceptance suite. A simplified polygon implementation cannot replace them.

## Device 1:1 rule

A protocol endpoint being callable is not sufficient. State machines, errors, reconnects, capability gating, progress, file operations, camera/timelapse, QIDI Box/AMS, HMS/diagnostics, account/cloud/P2P and firmware/update workflows must behave as the original application expects.

## Completion gate

Do **not** call the project complete while any source capability remains `pending`, `port_started` or `implemented_unverified`, or while any required reference/parity test is absent/failing.

The final completion statement requires:

- all source behavior accounted for in the traceability ledger;
- all required runtime assets published and verified;
- all parity gates closed;
- Flutter analyzer/tests passing;
- supported desktop builds passing;
- reference fixture comparisons passing;
- no old native/web implementation being used as the runtime backend.

## Rule for every future chat/developer

Before coding, read this file and `docs/HANDOFF.md`. When finishing a development batch, update the traceability/status documentation with exactly what became implemented, what was actually executed/tested, what remains unverified and the next source module/symbols to port.

If there is a conflict between a shortcut and 1:1 parity, choose 1:1 parity.