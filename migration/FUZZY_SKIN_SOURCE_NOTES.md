# Fuzzy skin source contract — pinned Qidi/Bambu source

Reference commit: `bambulab/BambuStudio@f2b55a5a83f266cf56e06c7943a81a08bebb7fad`.

This note exists to prevent accidental parity claims based on older fuzzy-skin descriptions while the full fuzzy branch is still being ported. Acceptance still belongs to `PARITY_CONTRACT.md`; this file does not mark the subsystem complete.

## Policy

Pinned `FuzzySkinType` behavior represented by the Dart policy layer:

- `None` — never fuzzify;
- `External` — fuzzify contour perimeter index 0 only;
- `All` — fuzzify contour and hole at perimeter index 0 only;
- `AllWalls` — fuzzify contour and hole at every perimeter index;
- `Disabled_fuzzy` — never fuzzify.

If `fuzzy_skin_first_layer` is false, layer 0 is not fuzzified.

Classic overhang slowdown gating is intentionally different from geometry identity:

```text
Disabled_fuzzy -> slowdown allowed
None + no perimeter regions -> slowdown allowed
None + perimeter regions -> slowdown not allowed
actual fuzzy modes -> slowdown not allowed
```

Thus `None` and `Disabled_fuzzy` must not be collapsed to one enum/state.

## Pinned noise enum

The pinned source uses the order:

1. `Classic`;
2. `Perlin`;
3. `Billow`;
4. `RidgedMulti`;
5. `Voronoi`.

Older notes referring to a `Uniform` fuzzy noise mode are not authoritative for this pinned source.

## Classic RNG topology

There are **two independent random engines** in the pinned source path:

1. fuzzy sample spacing is drawn by `random_value()` from its own function-local thread-local `std::mt19937` / `[0,1)` distribution;
2. `NoiseType::Classic` displacement is drawn by the texture randomizer from a separate function-local thread-local `std::mt19937` / signed float distribution.

They are not one alternating stream. Both states persist across polygon calls on the thread, but a new `fuzzy_polyline()` call draws a fresh initial spacing value from the spacing engine.

The exact Dart parity path therefore uses `SourceFuzzySpacingRandom2` and `SourceFuzzyClassicDisplacementRandom2` independently. A single injected random stream is insufficient evidence for source parity.

## Classic sampling geometry

Pinned behavior:

- `min_dist = 0.75 * point_distance`;
- random spacing range = `0.5 * point_distance`;
- initial `distance_left_over = random_value() * (min_dist / 2)`;
- `distance_left_over` carries only between segments inside the current fuzzy polyline call;
- sample point placement uses Eigen floating math followed by `.cast<coord_t>()`, so the represented integer cast truncates toward zero;
- Classic displacement is perpendicular to the current source segment;
- Classic displacement has a float32 boundary before source-coordinate thickness is applied;
- every emitted sample consumes one Classic-displacement draw and then one spacing draw;
- `fuzzy_polygon()` runs the closed-polyline branch and then removes same-neighbor / closing duplicates.

The pinned fallback contains an observable quirk: while fewer than three fuzzy points exist, `point_idx` is declared inside the loop, so a multi-point input may repeatedly append the same penultimate input point. The exact Dart port preserves this rather than replacing it with a cleaner backwards walk.

## Current Dart scope

Policy/identity behavior and the classic lower-level sampling algorithm have dedicated Dart ports and tests. The source-correct Classic path with independent RNG topology is represented by the `*Exact2` fuzzy classes.

Still open before a broad fuzzy parity claim:

- source-compatible production RNG implementation/seeding boundary beyond injected test streams;
- Perlin/Billow/RidgedMulti/Voronoi texture functions;
- painted/per-region `LineSegmentation` and per-segment region configs;
- full source-oracle coverage of complex fuzzy contours/holes and region transitions;
- final migration-ledger promotion only after pinned CI passes the complete exact branch.
