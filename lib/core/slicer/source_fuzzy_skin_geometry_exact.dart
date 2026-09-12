import 'dart:math' as math;
import 'dart:typed_data';

import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import '../geometry/source_polyline.dart';

/// Exact pinned-source order from `PrintConfig.hpp`.
enum SourceFuzzyNoiseTypeExact2 {
  classic,
  perlin,
  billow,
  ridgedMulti,
  voronoi,
}

/// QIDI `random_value()` stream used only for fuzzy sampling distances.
/// The source keeps this in its own function-local thread-local mt19937.
abstract interface class SourceFuzzySpacingRandom2 {
  double nextUnit();
}

/// QIDI Classic texture-displacement stream.
/// The source keeps a separate thread-local mt19937 and a
/// `uniform_real_distribution<float>(-1, 1)` for this stream.
abstract interface class SourceFuzzyClassicDisplacementRandom2 {
  double nextSignedUnit();
}

/// Exact sampling/displacement core of the pinned `FuzzySkin.cpp` Classic path.
///
/// The two RNG parameters are intentionally independent. Source spacing and
/// Classic displacement use different function-local thread-local mt19937
/// engines; collapsing them into one alternating stream changes all following
/// samples even when both engines happen to receive equal seeds.
class SourceFuzzySkinGeometryExact2 {
  const SourceFuzzySkinGeometryExact2._();

  static SourcePolyline2 fuzzyClassicPolyline({
    required SourcePolyline2 polyline,
    required double thicknessMm,
    required double pointDistanceMm,
    required SourceFuzzySpacingRandom2 spacingRandom,
    required SourceFuzzyClassicDisplacementRandom2 displacementRandom,
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
    var distanceLeftOver = _spacing(spacingRandom) * (minDistance / 2);
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

        // `textureRandomizer(... Classic ...)` returns float, so retain a
        // float32 boundary before applying the source-coordinate thickness.
        final noise = _classicDisplacement(displacementRandom);
        final displacement = noise * thickness;
        final normalX = -dy / segmentLength;
        final normalY = dx / segmentLength;
        output.add(SourcePoint2(
          sample.x + (normalX * displacement).truncate(),
          sample.y + (normalY * displacement).truncate(),
        ));

        distanceFromP0 +=
            minDistance + _spacing(spacingRandom) * randomRange;
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

  static SourcePolygon2 fuzzyClassicPolygon({
    required SourcePolygon2 polygon,
    required double thicknessMm,
    required double pointDistanceMm,
    required SourceFuzzySpacingRandom2 spacingRandom,
    required SourceFuzzyClassicDisplacementRandom2 displacementRandom,
  }) {
    if (polygon.points.length < 3) {
      throw StateError('source fuzzy polygon requires at least three points');
    }
    final fuzzy = fuzzyClassicPolyline(
      polyline: SourcePolyline2(polygon.points),
      thicknessMm: thicknessMm,
      pointDistanceMm: pointDistanceMm,
      spacingRandom: spacingRandom,
      displacementRandom: displacementRandom,
      closed: true,
    );
    return SourcePolygon2(_removeSameNeighbor(fuzzy.points));
  }

  static List<SourcePoint2> _removeSameNeighbor(List<SourcePoint2> points) {
    if (points.isEmpty) return const [];
    final unique = <SourcePoint2>[points.first];
    for (final point in points.skip(1)) {
      if (point != unique.last) unique.add(point);
    }
    if (unique.length > 1 && unique.last == unique.first) {
      unique.removeLast();
    }
    return unique;
  }

  static double _spacing(SourceFuzzySpacingRandom2 random) {
    final value = random.nextUnit();
    if (!value.isFinite || value < 0 || value >= 1) {
      throw StateError('source fuzzy spacing RNG must yield [0, 1) values');
    }
    return value;
  }

  static double _classicDisplacement(
    SourceFuzzyClassicDisplacementRandom2 random,
  ) {
    final value = random.nextSignedUnit();
    if (!value.isFinite || value < -1 || value >= 1) {
      throw StateError(
        'source Classic fuzzy displacement RNG must yield [-1, 1) values',
      );
    }
    return _f32(value);
  }

  static double _f32(double value) {
    final storage = Float32List(1)..[0] = value;
    return storage[0];
  }
}
