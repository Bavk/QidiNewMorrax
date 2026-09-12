# Fuzzy skin source contract — pinned Qidi/Bambu source

Reference commit: `bambulab/BambuStudio@f2b55a5a83f266cf56e06c7943a81a08bebb7fad`.
Structured noise dependency: `bambulab/libnoise@v1.0.0`.

Acceptance still belongs to `PARITY_CONTRACT.md`; this note records only the represented fuzzy-skin source contract.

## Policy

Pinned `FuzzySkinType` order and behavior:

1. `None` — never fuzzify;
2. `External` — contour perimeter index 0 only;
3. `All` — contour and hole at perimeter index 0 only;
4. `AllWalls` — contour and hole at every perimeter index;
5. `Disabled_fuzzy` — never fuzzify.

If `fuzzy_skin_first_layer` is false, layer 0 is not fuzzified.

Classic overhang slowdown is intentionally distinct from geometry identity: `Disabled_fuzzy` always allows slowdown; `None` allows it only when `perimeter_regions` is empty; actual fuzzy modes do not allow it through this helper.

## Noise enums and configuration

Pinned `NoiseType`: `Classic`, `Perlin`, `Billow`, `RidgedMulti`, `Voronoi`.
Pinned `FuzzySkinMode`: `Displacement`, `Extrusion`, `Combined`.

`get_noise_module()` uses `scale = max(0.01, fuzzy_skin_scale)` and frequency `1 / scale`:

- Perlin: frequency + octave count + persistence;
- Billow: frequency + octave count + persistence;
- RidgedMulti: frequency + octave count;
- Voronoi: frequency + displacement 1.0, distance disabled;
- Classic: source `UniformNoise`, backed by `random_value()`.

Dart directly ports the required libnoise v1.0.0 arithmetic, vector table and four deterministic modules.

## RNG topology

Pinned `FuzzySkin.cpp` has one function-local thread-local `random_value()`: one `std::mt19937` and one `std::uniform_real_distribution<double>(0.0, 1.0)`. `UniformNoise::GetValue()` (Classic) calls that same `random_value()` and maps it with `value * 2 - 1`.

Therefore initial spacing, every Classic displacement, and following spacing draws consume the same engine in call order. Structured libnoise modes consume that stream only for point spacing. Dart uses `SourceFuzzyUnitRandom2`; `SourceFuzzyMt19937Random2` ports MT19937 plus libstdc++ double composition and has seeded C++ oracle coverage. Production uses a per-isolate nondeterministically seeded stream.

## Polygon/polyline fuzzy geometry

Represented pinned behavior:

- `min_dist = 0.75 * point_distance`;
- random spacing range = `0.5 * point_distance`;
- initial `distance_left_over = random_value() * (min_dist / 2)`;
- leftover carries between segments;
- represented coordinate casts truncate toward zero;
- displacement is perpendicular to the current segment;
- deterministic noise queries use unscaled sampled XY and exact `slice_z`;
- Classic consumes displacement RNG before the following spacing RNG; structured modes do not;
- fallback repeatedly appends the penultimate point because `point_idx` is redeclared inside the loop;
- `fuzzy_polygon()` invokes closed `fuzzy_polyline()` without an invented neighbor cleanup.

## Arachne `fuzzy_extrusion_line()`

Pinned Arachne input is an `ExtrusionLine` of `ExtrusionJunction { p, w, perimeter_index, hole_compensation_flag }` values. The represented Dart model preserves that subset and line metadata (`inset_idx`, `is_odd`, `is_closed`).

The source uses the same point-spacing constants and the same noise module as Polygon fuzzy skin. For each sampled point `pa`, `r = noise(pa.x, pa.y, slice_z) * thickness` and:

- `Displacement`: position is shifted by perpendicular `r`; width remains `p1.w`;
- `Extrusion`: position remains `pa`; width is `max(p1.w + r + scaled(0.01), scaled(0.01))`;
- `Combined`: width uses the same formula, while position shifts perpendicularly by `(new_width - p1.w) / 2`.

Generated junctions are reconstructed with position, width and perimeter index; the source constructor default leaves `hole_compensation_flag` false. The same repeated-penultimate fallback bug is preserved. If input `back().p == front().p`, the output front position and width are overwritten from the output back junction regardless of the line's `is_closed` flag; only position/width are synchronized.

Run #249 freezes seeded C++ position/width goldens for all three modes and covers structured-noise RNG consumption and endpoint closure synchronization.

## Painted/per-region LineSegmentation

The represented Polyline, Polygon and Arachne `ExtrusionLine` subsets of source `Algorithm/LineSegmentation` are implemented by `SourceLineSegmentation2`.

Source `ZAttributes` is a 32-bit value:

- bit 31: clip point;
- bit 30: newly created intersection point;
- lower 30 bits: source point index.

The Dart adapter now uses `clipper2 0.0.3` `Point64.z` plus `Clipper64.zCallback` directly. Intersection points receive the minimum adjacent subject index and `is_new_point`; clip points can be remapped to the nearest subject line with the source 10-coordinate threshold. Polygon closure uses a distinct final source index despite equal first/last XY; closed Arachne input already contains its duplicated closing junction.

Represented range behavior includes sorting, default-gap insertion, overlap precedence and source interpolation. Point interpolation preserves QIDI Point's per-product coord truncation. Arachne width interpolation truncates the final scalar result, requires equal `perimeter_index` across interpolated boundaries and creates split segments through the source open-line constructor semantics.

### Dart Clipper2 compatibility boundary

Two differences from pinned `ClipperLib_Z` are handled narrowly and regression-tested:

1. a surviving open terminal point may lose its original nonzero source Z; if decoded index and exact XY contradict each other and the XY identifies exactly one source vertex, the source index is restored;
2. Dart Clipper2 may return a represented open intersection in reverse direction. Pinned `need_reverse()` contains first/last-index exceptions intended for wrap-around geometry. The adapter applies those exceptions only when the subject first/last XY actually coincide, so open paths normalize to pinned source order while closed Polygon/Arachne seams retain wrap behavior.

These are compatibility shims at the Clipper implementation boundary, not alternative LineSegmentation algorithms.

## Region-aware fuzzy composition

`SourceFuzzySkinApply2` now represents both source overloads used here:

- Polygon: one segment uses whole-polygon configuration; multiple segments fuzzify independently as open polylines and rejoin with duplicate boundary removal;
- Arachne ExtrusionLine: segmentation interpolates positions/widths, each segment uses its own config and fuzzy mode, and joined segments remove a duplicated seam by XY equality just like source `p` comparison even if widths differ.

Identity segments do not consume the fuzzy RNG.

## Current Dart scope

Run #249 validates the represented fuzzy scope: policy; all five noise modes; corrected RNG topology; Polygon/Polyline geometry; painted Polyline/Polygon segmentation; source-shaped Arachne junction/line model; `Displacement`, `Extrusion`, `Combined`; Arachne width interpolation; and per-region Arachne fuzzy composition.

Still open before any subsystem-wide fuzzy/Arachne claim:

- broader source-oracle overlap/hole/degenerate LineSegmentation cases;
- full Arachne wall-toolpath generation and integration around the verified fuzzy helper;
- exact platform equivalence of source `random_device` / thread-id seed choice (specific production runs are intentionally nondeterministic).
