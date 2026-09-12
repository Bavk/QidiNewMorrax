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

Classic overhang slowdown is intentionally distinct from geometry identity: `Disabled_fuzzy` always allows slowdown; `None` allows it only when `perimeter_regions` is empty; actual fuzzy modes do not allow it through this helper. Run #244 covers the nonempty-region `None` case through real classic traversal.

## Noise enums and configuration

Pinned `NoiseType`: `Classic`, `Perlin`, `Billow`, `RidgedMulti`, `Voronoi`.
Pinned `FuzzySkinMode`: `Displacement`, `Extrusion`, `Combined`.

`get_noise_module()` uses `scale = max(0.01, fuzzy_skin_scale)` and frequency `1 / scale`:

- Perlin: frequency + octave count + persistence;
- Billow: frequency + octave count + persistence;
- RidgedMulti: frequency + octave count;
- Voronoi: frequency + displacement 1.0, distance remains disabled;
- Classic: source `UniformNoise`, backed by `random_value()`.

Dart now directly ports the required libnoise v1.0.0 arithmetic, vector table and four modules. Run #239/#244 covers represented value/gradient/octave/Voronoi oracles, scale clamp and `slice_z` participation.

## RNG topology — corrected 2026-09-12

Pinned `FuzzySkin.cpp` has one function-local thread-local `random_value()`: one `std::mt19937` and one `std::uniform_real_distribution<double>(0.0, 1.0)`. `UniformNoise::GetValue()` (Classic) calls that same `random_value()` and maps it with `value * 2 - 1`.

Therefore initial spacing, every Classic displacement, and following spacing draws consume the same engine in call order. Structured libnoise modes consume that stream only for point spacing. The earlier independent spacing/displacement interpretation was incorrect; duplicate `*Exact2` code was removed in `ffc005e678d0cf1e6d4000e6c9a842620700ddbe`.

Dart uses `SourceFuzzyUnitRandom2`. `SourceFuzzyMt19937Random2` directly ports MT19937 and the libstdc++ double `[0,1)` draw composition; seeded C++ oracle values are covered. Production uses a per-isolate nondeterministically seeded stream, corresponding to source thread-local lifetime as closely as Dart exposes.

## Polygon/polyline fuzzy geometry

Represented pinned behavior:

- `min_dist = 0.75 * point_distance`;
- random spacing range = `0.5 * point_distance`;
- initial `distance_left_over = random_value() * (min_dist / 2)`;
- leftover distance carries between segments inside one fuzzy-polyline call;
- source integer coordinate casts truncate toward zero at represented Eigen cast boundaries;
- displacement is perpendicular to the current segment;
- deterministic noise queries use unscaled sampled XY plus exact `slice_z`;
- Classic consumes a displacement RNG draw before the following spacing draw; structured modes do not;
- the source fallback repeatedly appends the penultimate point because `point_idx` is redeclared inside the loop;
- pinned `fuzzy_polygon()` invokes closed `fuzzy_polyline()` without invented neighbor cleanup.

## Painted/per-region LineSegmentation

The represented Polyline/Polygon subset of source `Algorithm/LineSegmentation` is now implemented by `SourceLineSegmentation2` and validated in run #244.

Covered source behavior includes:

- polygon conversion to an open polyline with duplicated first point;
- open-subject intersection per region group;
- range sorting, default-gap insertion and earlier-region overlap precedence;
- 10-source-coordinate point-on-line threshold (`SCALED_EPSILON` squared = 100);
- source `lerp(Point,Point,t)` behavior where each scalar product truncates to `coord_t` before point addition;
- region/config value mapping;
- full closed-polygon coverage retaining distinct first and closing source indexes despite equal XY coordinates.

Source carries subject indexes through Clipper-Z. The current Dart Clipper2 package has no Z callback, so the adapter reconstructs `(line_index,t)` from the returned intersection endpoints by projection onto the original integer polyline. The duplicate closing-point case is disambiguated from its adjacent source vertex, matching the source index identity needed for full-cover ranges.

`SourceFuzzySkinApply2` now composes this segmentation with source policy: one segment takes the whole-polygon branch using that segment's config; multiple segments fuzzify independently as open polylines, remove only duplicate join boundaries, concatenate, and remove the final repeated closure point.

## Current Dart scope

Validated represented classic fuzzy scope now includes policy, all five noise modes, corrected RNG topology, polygon/polyline geometry, region-aware Polyline/Polygon segmentation, painted config selection, recursive classic traversal and region-aware overhang slowdown gating.

Still open before a broad fuzzy parity claim:

- Arachne `ExtrusionJunction` / `ExtrusionLine` source model required by fuzzy skin;
- Arachne `fuzzy_extrusion_line()` modes `Displacement`, `Extrusion`, `Combined`;
- `scaled(0.01)` minimum extrusion width, width mutation, Combined half-radius position shift and closed front/back synchronization;
- Arachne/extrusion-line LineSegmentation overload and per-region config transitions;
- broader source-oracle contour/hole/overlap/degenerate region cases;
- exact platform equivalence of source `random_device` / thread-id seed choice (specific production runs are intentionally nondeterministic).
