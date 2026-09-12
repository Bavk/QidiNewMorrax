import 'dart:math' as math;

import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import '../geometry/source_polyline.dart';
import 'source_libnoise.dart';

/// Exact pinned-source order from `PrintConfig.hpp`.
enum SourceFuzzyNoiseType2 {
  classic,
  perlin,
  billow,
  ridgedMulti,
  voronoi,
}

/// Exact pinned-source `FuzzySkinMode` order.
enum SourceFuzzySkinMode2 {
  displacement,
  extrusion,
  combined,
}

/// Explicit seam for QIDI's function-local thread-local `random_value()`.
///
/// The pinned source uses this same stream for initial sample spacing, Classic
/// displacement, and every following sample-spacing draw. Deterministic
/// libnoise modes consume this stream only for spacing.
abstract interface class SourceFuzzyUnitRandom2 {
  double nextUnit();
}

/// Direct `std::mt19937` port used by pinned `FuzzySkin.cpp::random_value()`.
///
/// [nextUnit] preserves libstdc++'s `uniform_real_distribution<double>`
/// behavior for `[0, 1)`: two 32-bit engine draws are combined by
/// `generate_canonical`, with the first draw as the low limb.
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
      return (DateTime.now().microsecondsSinceEpoch ^
              identityHashCode(Object())) &
          _uint32Mask;
    }
  }
}

SourceFuzzyUnitRandom2? _productionFuzzyRandom;

/// Per-isolate production stream corresponding to source's thread-local RNG.
SourceFuzzyUnitRandom2 sourceFuzzyProductionRandom2() =>
    _productionFuzzyRandom ??= SourceFuzzyMt19937Random2.systemSeeded();

/// Pinned `FuzzySkin.cpp::get_noise_module()` settings.
class SourceFuzzyNoiseSettings2 {
  const SourceFuzzyNoiseSettings2({
    required this.type,
    this.scaleMm = 1.0,
    this.octaves = 4,
    this.persistence = 0.5,
  });

  final SourceFuzzyNoiseType2 type;
  final double scaleMm;
  final int octaves;
  final double persistence;
}

/// Exact sampling/displacement core of pinned `FuzzySkin.cpp::fuzzy_polyline`.
class SourceFuzzySkinGeometry2 {
  const SourceFuzzySkinGeometry2._();

  static SourcePolyline2 fuzzyPolyline({
    required SourcePolyline2 polyline,
    required double thicknessMm,
    required double pointDistanceMm,
    required double sliceZMm,
    required SourceFuzzyNoiseSettings2 noiseSettings,
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
    var distanceLeftOver = unitRandom(random) * (minDistance / 2);
    final deterministicNoise = noiseModule(noiseSettings);
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
        final sample = SourcePoint2(
          p0.x + (dx * ratio).truncate(),
          p0.y + (dy * ratio).truncate(),
        );

        final noiseValue = noiseSettings.type == SourceFuzzyNoiseType2.classic
            ? unitRandom(random) * 2.0 - 1.0
            : deterministicNoise!.getValue(
                sample.x * Slic3rUnits.scalingFactor,
                sample.y * Slic3rUnits.scalingFactor,
                sliceZMm,
              );
        final displacement = noiseValue * thickness;
        final normalX = -dy / segmentLength;
        final normalY = dx / segmentLength;
        output.add(SourcePoint2(
          sample.x + (normalX * displacement).truncate(),
          sample.y + (normalY * displacement).truncate(),
        ));

        distanceFromP0 += minDistance + unitRandom(random) * randomRange;
      }

      distanceLeftOver = distanceFromP0 - segmentLength;
      p0 = p1;
    }

    // Preserve the pinned source fallback literally. `point_idx` is declared
    // inside the while loop, so the same penultimate point may repeat.
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

  static SourcePolygon2 fuzzyPolygon({
    required SourcePolygon2 polygon,
    required double thicknessMm,
    required double pointDistanceMm,
    required double sliceZMm,
    required SourceFuzzyNoiseSettings2 noiseSettings,
    required SourceFuzzyUnitRandom2 random,
  }) {
    if (polygon.points.length < 3) {
      throw StateError('source fuzzy polygon requires at least three points');
    }
    final fuzzy = fuzzyPolyline(
      polyline: SourcePolyline2(polygon.points),
      thicknessMm: thicknessMm,
      pointDistanceMm: pointDistanceMm,
      sliceZMm: sliceZMm,
      noiseSettings: noiseSettings,
      random: random,
      closed: true,
    );
    return SourcePolygon2(fuzzy.points);
  }

  static SourcePolyline2 fuzzyClassicPolyline({
    required SourcePolyline2 polyline,
    required double thicknessMm,
    required double pointDistanceMm,
    required SourceFuzzyUnitRandom2 random,
    bool closed = false,
  }) =>
      fuzzyPolyline(
        polyline: polyline,
        thicknessMm: thicknessMm,
        pointDistanceMm: pointDistanceMm,
        sliceZMm: 0,
        noiseSettings: const SourceFuzzyNoiseSettings2(
          type: SourceFuzzyNoiseType2.classic,
        ),
        random: random,
        closed: closed,
      );

  static SourcePolygon2 fuzzyClassicPolygon({
    required SourcePolygon2 polygon,
    required double thicknessMm,
    required double pointDistanceMm,
    required SourceFuzzyUnitRandom2 random,
  }) =>
      fuzzyPolygon(
        polygon: polygon,
        thicknessMm: thicknessMm,
        pointDistanceMm: pointDistanceMm,
        sliceZMm: 0,
        noiseSettings: const SourceFuzzyNoiseSettings2(
          type: SourceFuzzyNoiseType2.classic,
        ),
        random: random,
      );

  /// Shared pinned `get_noise_module()` construction used by both Polygon and
  /// Arachne fuzzy paths. Classic returns null because its UniformNoise reads
  /// from the shared [SourceFuzzyUnitRandom2] stream instead.
  static SourceLibNoiseModule2? noiseModule(
    SourceFuzzyNoiseSettings2 settings,
  ) {
    if (settings.type == SourceFuzzyNoiseType2.classic) return null;

    // Literal `std::max(0.01, (double)cfg.fuzzy_skin_scale.value)` behavior.
    final scale = 0.01 < settings.scaleMm ? settings.scaleMm : 0.01;
    final frequency = 1.0 / scale;
    return switch (settings.type) {
      SourceFuzzyNoiseType2.classic => null,
      SourceFuzzyNoiseType2.perlin => SourceLibNoisePerlin2(
          frequency: frequency,
          octaveCount: settings.octaves,
          persistence: settings.persistence,
        ),
      SourceFuzzyNoiseType2.billow => SourceLibNoiseBillow2(
          frequency: frequency,
          octaveCount: settings.octaves,
          persistence: settings.persistence,
        ),
      SourceFuzzyNoiseType2.ridgedMulti => SourceLibNoiseRidgedMulti2(
          frequency: frequency,
          octaveCount: settings.octaves,
        ),
      SourceFuzzyNoiseType2.voronoi => SourceLibNoiseVoronoi2(
          frequency: frequency,
          displacement: 1.0,
        ),
    };
  }

  /// Validated call to pinned `random_value()`'s `[0, 1)` contract.
  static double unitRandom(SourceFuzzyUnitRandom2 random) {
    final value = random.nextUnit();
    if (!value.isFinite || value < 0 || value >= 1) {
      throw StateError('source fuzzy random stream must yield [0, 1) values');
    }
    return value;
  }
}
