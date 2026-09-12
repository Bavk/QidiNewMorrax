# Source module map

This map is generated from the supplied source tree. Line counts are audit sizing numbers, not a claim that equal line counts are needed in Dart. `Started` means at least the corresponding source file has an explicit Dart replacement in the migration ledger; it does **not** mean feature parity is complete.

| Module | Source files | Approx. lines | Started files | Pending files |
|---|---:|---:|---:|---:|
| `slic3r/GUI` | 836 | 450,785 | 5 | 831 |
| `libslic3r/(root)` | 275 | 153,531 | 14 | 261 |
| `libslic3r/GCode` | 38 | 29,380 | 0 | 38 |
| `slic3r/Utils` | 76 | 27,511 | 0 | 76 |
| `libslic3r/Format` | 23 | 18,838 | 12 | 11 |
| `libslic3r/Support` | 13 | 18,495 | 0 | 13 |
| `libslic3r/Fill` | 36 | 14,554 | 0 | 36 |
| `libslic3r/SLA` | 35 | 8,123 | 0 | 35 |
| `libslic3r/Arachne` | 41 | 7,648 | 0 | 41 |
| `libslic3r/Geometry` | 17 | 5,582 | 0 | 17 |
| `libslic3r/TextureToColor` | 8 | 3,167 | 0 | 8 |
| `slic3r/Config` | 4 | 1,175 | 0 | 4 |
| `libslic3r/Interlocking` | 4 | 1,102 | 0 | 4 |
| `libslic3r/CSGMesh` | 7 | 985 | 0 | 7 |
| `libslic3r/Algorithm` | 2 | 652 | 0 | 2 |
| `libslic3r/Optimize` | 3 | 556 | 0 | 3 |
| `libslic3r/Shape` | 2 | 292 | 0 | 2 |
| `libslic3r/Execution` | 3 | 290 | 0 | 3 |
| `slic3r/(root)` | 2 | 206 | 0 | 2 |

## Current Dart replacement areas

- `lib/core/model_io`: STL, OBJ, AMF/ZIP.AMF and package-aware 3MF import with external component models, build transforms and retention/repacking of every ZIP entry.
- `lib/core/geometry`: point, bounding-box and polygon primitives.
- `lib/core/slicer`: triangle-plane slicing with closed/open contour reconstruction, even-odd clipped linear infill, and a first basic perimeter/infill toolpath plan (not native slicer parity).
- `lib/core/gcode`: G-code tokenization/statistics plus a deterministic basic G-code writer for the new pure-Dart toolpath foundation.
- `lib/core/profiles`: original JSON profile catalog and inheritance loading.
- `lib/features/device`: local SSDP discovery, Moonraker JSON-RPC, raw+typed printer state, exact local command strings, cloud task contract and Pass28-style Flutter device UI.
- `lib/features/prepare` / `preview`: model loading/wireframe scene and G-code layer preview.

## Completion rule

A module moves from `port_started` to a completed status only after behavior-level parity tests exist. Native C++/wxWidgets/React code is not counted as migrated merely because a Flutter screen resembles it.
