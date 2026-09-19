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
- MMU/material color paint (`paint_color`) may reference only real materialized filament slots. For an unsplit whole triangle, pinned Orca `TriangleSelector::serialize()` encodes slot 1 as `"4"`, slot 2 as `"8"`, and slots 3–16 as `<HEX(slot-3)>C` (`3 -> "0C"`, `16 -> "DC"`); do not substitute the decimal slot number or reuse support/seam encoding heuristics;
- the first Dart facet editor may address whole source triangles by index/range; future viewport brush/hit-testing must write the same volume/facet state rather than introduce a second paint model;
- generated editor state must be the same state handed to `ThreeMfProjectWriter` and OrcaSlicer; do not maintain a separate presentation-only project model;
- imported vendor 3MF remains lossless by default. Do not structurally rewrite imported package internals until the edited metadata can be round-tripped without dropping unknown vendor entries;
- runtime filament/extruder assignments must not expose slots that are not backed by materialized filament profiles;
- generated multi-filament state is an **ordered, 1-based slot list**. Slot N maps to the Nth resolved preset passed both to `OrcaProjectSettingsBuilder` and `OrcaProfileMaterializer`, and object `extruder=N` is valid only while that slot exists;
- changing machine compatibility or removing a slot must repair/reject dangling object and painted-facet assignments before slicing. When a slot is deleted, references above it shift down by one and references to the deleted slot are moved to an explicit surviving replacement; never silently pass an object/facet slot outside the materialized range to Orca;
- the current pinned Orca material-paint state surface is capped at 16 slots. Object-level assignment and whole-facet MMU paint both use the same verified ordered preset list;
- source verification is against pinned `EnforcerBlockerType`, `TriangleSelector::serialize()` and `FacetsAnnotation::get_triangle_as_string()`. CI must include an extended-state example above slot 2 (currently slot 3 / `paint_color="0C"`) so future changes cannot regress to the 2-bit support/seam assumption.


## Packaged-engine contract

For the Linux-first v0.1 target:

- explicit `ORCA_SLICER_BIN` is a development override and remains highest precedence;
- a release bundle may select the sibling `orca/OrcaSlicer.AppImage` only when `orca/orca-engine.json` is also present;
- the manifest version, upstream commit, platform and SHA-256 must match the compile-time engine pin;
- the actual bundled AppImage bytes must be hashed before first use; manifest-only trust is insufficient;
- a packaged hash/provenance mismatch is fatal and must not silently fall back to another engine;
- release CI must build the real Flutter desktop bundle and verify runtime discovery against the packaged filesystem layout, not merely test a standalone Orca download.
- release builds must compile a usable QIDI profile catalog into the Flutter asset bundle. Bootstrap-marker directories are not runtime profiles and must never be treated as a complete release asset set;
- for Linux v0.1, the catalog is generated from the exact pinned Orca source revision before `flutter build`, and the release smoke must assert the target machine/process/filament names are present;
- the packaged application smoke must run with no `ORCA_SLICER_BIN` override so bundled-engine discovery, profile loading, project materialization, slicing and Preview-input parsing are verified together.

Windows/macOS packaging may use platform-appropriate layouts later, but must preserve the same provenance/fail-closed principle.

## Release legal/source contract

For the Linux-first v0.1 release pipeline:

- the repository and binary distribution must carry the GNU AGPL v3 license text and a release notice identifying the application and exact bundled Orca provenance;
- the application must expose a visible legal-notice surface including no-warranty and source-availability information;
- the release bundle must identify the exact application revision and pinned Orca source revision corresponding to the conveyed binaries;
- release automation must generate machine-readable source archives for both and record their SHA-256 values;
- a published GitHub Release must attach the binary and both corresponding-source archives to the same release;
- the optional non-free Orca/Bambu networking plugin must not be bundled or used by this product path;
- automated validation of these artifacts is an engineering gate only; it does not replace final legal review.

## Testing

Acceptance is split at the engine boundary:

1. Dart tests validate request construction, profile/materialization, model/project handoff, result extraction, Preview parsing and application state.
2. Engine integration tests execute the pinned OrcaSlicer binary on representative QIDI projects and verify successful output plus selected golden invariants. Generated-project fixtures must exercise structural features being promoted (for example modifier/support volumes and facet-paint triangle attributes), not only legacy two-plate geometry.
3. Release tests verify the exact bundled Orca version/commit, pinned runtime profile catalog, packaged application slice-to-Preview path and licensing/source notices.

Historical Dart Clipper/Arachne parity tests are no longer production acceptance gates.

## Licensing

OrcaSlicer is GNU AGPL-3.0. Release packaging must satisfy all applicable license, notice and corresponding-source obligations before distribution.
