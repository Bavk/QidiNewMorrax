# Fuzzy skin source contract — pinned Qidi/Bambu source

Reference commit: `bambulab/BambuStudio@f2b55a5a83f266cf56e06c7943a81a08bebb7fad`.

Acceptance still belongs to `PARITY_CONTRACT.md`; this note records only the represented fuzzy-skin source contract.

## Policy

Pinned `FuzzySkinType` order and behavior:

1. `None` — never fuzzify;
2. `External` — contour perimeter index 0 only;
3. `All` — contour and hole at perimeter index 0 only;
4. `AllWalls` — contour and hole at every perimeter index;
5. `Disabled_fuzzy` — never fuzzify.

If `fuzzy_skin_first_layer` is false, layer 0 is not fuzzified.

Classic overhang slowdown is intentionally distinct from geometry identity: `Disabled_fuzzy` always allows slowdown; `None` allows it only when perimeter regions are empty; actual fuzzy modes do not allow it through this helper.

## Noise enums

Pinned `NoiseType`: `Classic`, `Perlin`, `Billow`, `RidgedMulti`, `Voronoi`.
Pinned `FuzzySkinMode`: `Displacement`, `Extrusion`, `Combined`.

## Classic RNG topology — corrected 2026-09-12

Pinned `FuzzySkin.cpp` has one function-local thread-local `random_value()`: one `std::mt19937` and one `std::uniform_real_distribution<double>(0.0, 1.0)`. `UniformNoise::GetValue()` (the Classic branch) calls that same `random_value()` and maps it with `value * 2 - 1`.

Therefore initial spacing, every Classic displacement, and following spacing draws consume the same engine in call order. The earlier independent spacing/displacement interpretation was incorrect. The duplicate `*Exact2` implementation was removed in `ffc005e678d0cf1e6d4000e6c9a842620700ddbe`.

Dart now uses `SourceFuzzyUnitRandom2`. `SourceFuzzyMt19937Random2` directly ports MT19937 and the libstdc++ double `[0,1)` draw composition; seeded C++ oracle values are covered by tests. Production uses a per-isolate nondeterministically seeded stream, corresponding to source thread-local lifetime as closely as Dart exposes.

## Classic geometry

Represented pinned behavior:

- `min_dist = 0.75 * point_distance`;
- random spacing range = `0.5 * point_distance`;
- initial `distance_left_over = random_value() * (min_dist / 2)`;
- leftover distance carries between segments inside one fuzzy-polyline call;
- represented Eigen coordinate casts truncate toward zero;
- Classic displacement is perpendicular to the segment and remains `double`;
- each sample consumes Classic displacement then the next spacing draw from the same stream;
- the source fallback repeatedly appends the penultimate point because `point_idx` is redeclared inside the loop;
- pinned `fuzzy_polygon()` simply invokes closed `fuzzy_polyline()`; this file has no extra same-neighbor cleanup.

## Current Dart scope

Represented now: policy, Classic no-painted-region geometry, single-stream RNG call order, seeded MT19937 oracle, production nondeterministic stream seam, recursive classic traversal with explicit layer identity, and Classic fuzzy/overhang gating through the represented classic perimeter pipeline.

Still open before a broad fuzzy parity claim:

- Perlin/Billow/RidgedMulti/Voronoi noise-module behavior and configuration;
- painted/per-region `LineSegmentation` with per-segment configs;
- Arachne `fuzzy_extrusion_line()` modes;
- broader source-oracle contour/hole/region-transition cases;
- exact platform equivalence of the source `random_device` / thread-id seed choice (specific production runs are intentionally nondeterministic).
