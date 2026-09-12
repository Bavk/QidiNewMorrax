import 'dart:math' as math;

import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import '../geometry/source_polyline.dart';

/// Exact pinned-source order from `PrintConfig.hpp`.
enum SourceFuzzyNoiseType2 {
  classic,
  perlin,
  billow,
  ridgedMulti,
  voronoi,
}

/// Explicit seam for QIDI's function-local thread-local `random_value()`.
///
/// The pinned source uses this same stream for the initial sample spacing,
/// Classic/Uniform displacement, and every following sample-spacing draw.
/// Keeping the stream explicit lets the geometry algorithm use deterministic
/// source-oracle fixtures without replacing production randomness with a
/// deterministic global seed.
abstract interface class SourceFuzzyUnitRandom2 {
  double nextUnit();
}

/// Direct `std::mt19937` port used by pinned `FuzzySkin.cpp::random_value()`.
///
/// [nextUnit] also preserves libstdc++'s `uniform_real_distribution<double>`
/// behavior for a `[0, 1)` distribution over mt19937: two 32-bit engine draws
/// are combined by `generate_canonical` with the first draw as the low limb.
class SourceFuzzyMt19937Random2 implements SourceFuzzyUnitRandom2 {
  SourceFuzzyMt19937Random2.seeded(int seed) {
    _state[0] = seed & _uint32Mask;
    for (var i = 1; i < _stateLength; i++) {
      final previous = _state[i - 1];
      _state[i] =
          (1812433253 * (previous ^ (previous >> 30)) + i) & _uint32Mask;
    }
  }

  factory SourceFuzzyMt19937Random2.systemSeeded() {
    return SourceFuzzyMt19937Random2.seeded(_systemSeed());
  }

  static const int _stateLength = 624;
  static const int _period = 397;
  static const int _uint32Mask = 0xffffffff;
  static const int _upperMask = 0x80000000;
  static const int _lowerMask = 0x7fffffff;
  static const int _matrixA = 0x9908b0df;
  static const double _two32 = 4294967296.0;
  static const double _two64 = 18446744073709551616.0;

  final List<int> _state = List<int>.filled(_stateLength, 0);
  int _index = _stateLength;

  int nextUint32() {
    if (_index >= _stateLength) _twist();

    var value = _state[_index++];
    value ^= value >> 11;
    value ^= (value << 7) & 0x9d2c5680;
    value ^= (value << 15) & 0xefc60000;
    value ^= value >> 18;
    return value & _uint32Mask;
  }

  @override
  double nextUnit() {
    final low = nextUint32().toDouble();
    final high = nextUint32().toDouble();
    return (low + high * _two32) / _two64;
  }

  void _twist() {
    for (var i = 0; i < _stateLength; i++) {
      final combined =
          (_state[i] & _upperMask) |
          (_state[(i + 1) % _stateLength] & _lowerMask);
      var next = _state[(i + _period) % _stateLength] ^ (combined >> 1);
      if ((combined & 1) != 0) next ^= _matrixA;
      _state[i] = next & _uint32Mask;
    }
    _index = 0;
  }

  static int _systemSeed() {
    try {
      final secure = math.Random.secure();
      return ((secure.nextInt(1 << 16) << 16) | secure.nextInt(1 << 16)) &
          _uint32Mask;
    } on UnsupportedError {
      // Pinned C++ falls back from random_device to a thread-id hash when
      // entropy is unavailable. Dart has no stable thread-id API, so retain
      // the same nondeterministic seed boundary with time + object identity.
      return (DateTime.now().microsecondsSinceEpoch ^ identityHashCode(Object())) &
          _uint32Mask;
    }
  }
}

SourceFuzzyUnitRandom2? _productionFuzzyRandom;

/// Per-isolate production stream corresponding to source's thread-local RNG.
SourceFuzzyUnitRandom2 sourceFuzzyProductionRandom2() =>
    _productionFuzzyRandom ??= SourceFuzzyMt19937Random2.systemSeeded();

/// Exact sampling/displacement core of the pinned `FuzzySkin.cpp` Classic
/// noise path, parameterized only by its single nondeterministic random stream.
class SourceFuzzySkinGeometry2 {
  const SourceFuzzySkinGeometry2._();

  static SourcePolyline2 fuzzyClassicPolyline({
    required SourcePolyline2 polyline,
    required double thicknessMm,
    required double pointDistanceMm,
    required SourceFuzzyUnitRandom2 random,
    bool closed = false,
  }) {
    if (polyline.points.length < 2) {
      throw StateError('source fuzzy polyline requires at least two points');
    }
    if (!thicknessMm.isFinite || thicknessMm < 0) {
      throw ArgumentError.value(
        thicknessMm,
        'thicknessMm',
        'must be finite and >= 0',
      );
    }
    if (!pointDistanceMm.isFinite || pointDistanceMm <= 0) {
      throw ArgumentError.value(
        pointDistanceMm,
        'pointDistanceMm',
        'must be finite and > 0',
      );
    }

    final thickness = thicknessMm / Slic3rUnits.scalingFactor;
    final pointDistance = pointDistanceMm / Slic3rUnits.scalingFactor;
    final minDistance = 0.75 * pointDistance;
    final randomRange = 0.5 * pointDistance;
    var distanceLeftOver = _unit(random) * (minDistance / 2);
    final output = <SourcePoint2>[];

    var p0 = closed ? polyline.points.last : polyline.points.first;
    final startIndex = closed ? 0 : 1;
    for (var index = startIndex; index < polyline.points.length; index++) {
      final p1 = polyline.points[index];
      final dx = p1.x - p0.x;
      final dy = p1.y - p0.y;
      final segmentLength = math.sqrt(
        dx.toDouble() * dx.toDouble() + dy.toDouble() * dy.toDouble(),
      );
      var distanceFromP0 = distanceLeftOver;

      while (distanceFromP0 < segmentLength) {
        final ratio = distanceFromP0 / segmentLength;
        // Source uses `(dir.cast<double>() * ratio).cast<coord_t>()`; Eigen's
        // numeric cast truncates floating coordinates toward zero here.
        final sample = SourcePoint2(
          p0.x + (dx * ratio).truncate(),
          p0.y + (dy * ratio).truncate(),
        );

        // `NoiseType::Classic` is UniformNoise::GetValue(), which calls the
        // exact same `random_value()` as spacing and maps [0,1) -> [-1,1).
        final noise = _unit(random) * 2 - 1;
        final displacement = noise * thickness;
        final normalX = -dy / segmentLength;
        final normalY = dx / segmentLength;
        output.add(SourcePoint2(
          sample.x + (normalX * displacement).truncate(),
          sample.y + (normalY * displacement).truncate(),
        ));

        distanceFromP0 += minDistance + _unit(random) * randomRange;
      }

      distanceLeftOver = distanceFromP0 - segmentLength;
      p0 = p1;
    }

    // Preserve the pinned source fallback literally. `point_idx` is declared
    // inside the while loop, so for polylines with >= 3 points the same
    // penultimate point may be appended repeatedly until output reaches three.
    while (output.length < 3) {
      var pointIndex = polyline.points.length - 2;
      output.add(polyline.points[pointIndex]);
      if (pointIndex == 0) break;
      --pointIndex;
    }

    return output.length >= 3
        ? SourcePolyline2(output)
        : polyline.copy();
  }

  /// Literal pinned `fuzzy_polygon()`: run the closed polyline path and keep
  /// the resulting point list exactly as produced (including fallback dupes).
  static SourcePolygon2 fuzzyClassicPolygon({
    required SourcePolygon2 polygon,
    required double thicknessMm,
    required double pointDistanceMm,
    required SourceFuzzyUnitRandom2 random,
  }) {
    if (polygon.points.length < 3) {
      throw StateError('source fuzzy polygon requires at least three points');
    }
    final fuzzy = fuzzyClassicPolyline(
      polyline: SourcePolyline2(polygon.points),
      thicknessMm: thicknessMm,
      pointDistanceMm: pointDistanceMm,
      random: random,
      closed: true,
    );
    return SourcePolygon2(fuzzy.points);
  }

  static double _unit(SourceFuzzyUnitRandom2 random) {
    final value = random.nextUnit();
    if (!value.isFinite || value < 0 || value >= 1) {
      throw StateError('source fuzzy random stream must yield [0, 1) values');
    }
    return value;
  }
}
