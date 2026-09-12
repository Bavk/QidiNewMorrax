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

/// Explicit seam for QIDI's thread-local random stream.
///
/// The source seeds `std::mt19937` from `std::random_device`, so a specific
/// production run is intentionally nondeterministic. Keeping the stream
/// explicit lets the geometry algorithm be tested exactly without replacing
/// source randomness with a hidden Dart RNG. Values follow the source
/// `uniform_real_distribution<double>(0, 1)` contract.
abstract interface class SourceFuzzyUnitRandom2 {
  double nextUnit();
}

/// Exact sampling/displacement core of the pinned `FuzzySkin.cpp` Classic
/// noise path, parameterized only by its nondeterministic random stream.
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

        // `NoiseType::Classic` calls the same `random_value()` stream and maps
        // [0,1) -> [-1,1), then the displacement is cast back to coord_t.
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

  /// Pinned `fuzzy_polygon()` Classic branch followed by
  /// `remove_same_neighbor(Polygon&)`.
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

  static double _unit(SourceFuzzyUnitRandom2 random) {
    final value = random.nextUnit();
    if (!value.isFinite || value < 0 || value >= 1) {
      throw StateError('source fuzzy random stream must yield [0, 1) values');
    }
    return value;
  }
}
