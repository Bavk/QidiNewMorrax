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

## Editable project model contract

Generated Prepare projects must keep Orca/Bambu project structure explicit instead of flattening editor state into a single mesh:

- a plate owns object instances;
- an editable object owns one or more volumes;
- the first/simple volume may be a `normal_part`, while additional volumes may be `normal_part`, `modifier`, `support_enforcer` or `support_blocker`;
- per-object and per-volume settings must remain attached to their original scope when serialized to `Metadata/model_settings.config`;
- transforms that conceptually target an object must move all of its volumes together; volume-specific edits must not silently rewrite sibling volumes;
- facet paint metadata belongs to a volume/facet and must remain volume-scoped. Pinned Orca v2.4.2 uses `FacetsAnnotation` / `TriangleSelector`; for an unsplit whole triangle ENFORCER serializes as `"4"` and BLOCKER as `"8"`. Supports and seam may use either state; fuzzy-skin uses only the ENFORCER/enable state;
- facet paint authoring is valid only for `normal_part` volumes, matching Orca's painter behavior. Do not attach painter facets to modifier/support volumes;
- MMU/material color paint (`paint_color`) must not be exposed until the referenced filament/extruder slots are backed by materialized runtime filament profiles;
- the first Dart facet editor may address whole source triangles by index/range; future viewport brush/hit-testing must write the same volume/facet state rather than introduce a second paint model;
- generated editor state must be the same state handed to `ThreeMfProjectWriter` and OrcaSlicer; do not maintain a separate presentation-only project model;
- imported vendor 3MF remains lossless by default. Do not structurally rewrite imported package internals until the edited metadata can be round-tripped without dropping unknown vendor entries;
- runtime filament/extruder assignments must not expose slots that are not backed by materialized filament profiles.


## Packaged-engine contract

For the Linux-first v0.1 target:

- explicit `ORCA_SLICER_BIN` is a development override and remains highest precedence;
- a release bundle may select the sibling `orca/OrcaSlicer.AppImage` only when `orca/orca-engine.json` is also present;
- the manifest version, upstream commit, platform and SHA-256 must match the compile-time engine pin;
- the actual bundled AppImage bytes must be hashed before first use; manifest-only trust is insufficient;
- a packaged hash/provenance mismatch is fatal and must not silently fall back to another engine;
- release CI must build the real Flutter desktop bundle and verify runtime discovery against the packaged filesystem layout, not merely test a standalone Orca download.

Windows/macOS packaging may use platform-appropriate layouts later, but must preserve the same provenance/fail-closed principle.

## Testing

Acceptance is split at the engine boundary:

1. Dart tests validate request construction, profile/materialization, model/project handoff, result extraction, Preview parsing and application state.
2. Engine integration tests execute the pinned OrcaSlicer binary on representative QIDI projects and verify successful output plus selected golden invariants. Generated-project fixtures must exercise structural features being promoted (for example modifier/support volumes and facet-paint triangle attributes), not only legacy two-plate geometry.
3. Release tests verify the exact bundled Orca version/commit and licensing/source notices.

Historical Dart Clipper/Arachne parity tests are no longer production acceptance gates.

## Licensing

OrcaSlicer is GNU AGPL-3.0. Release packaging must satisfy all applicable license, notice and corresponding-source obligations before distribution.
