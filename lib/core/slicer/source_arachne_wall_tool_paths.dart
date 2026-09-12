import 'dart:math' as math;
import 'dart:typed_data';

import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';

/// Pinned `Arachne::WallToolPathsParams` value domain.
///
/// Every C++ member is `float` except `wall_distribution_count`. Keep the
/// float32 store boundary explicit: later `scaled<coord_t>(float)` arithmetic
/// is performed in float, not double.
class SourceArachneWallToolPathsParams2 {
  SourceArachneWallToolPathsParams2({
    required double minBeadWidthMm,
    required double minFeatureSizeMm,
    required double wallTransitionLengthMm,
    required double wallTransitionAngleDeg,
    required double wallTransitionFilterDeviationMm,
    required this.wallDistributionCount,
  })  : minBeadWidthMm = _f32(minBeadWidthMm),
        minFeatureSizeMm = _f32(minFeatureSizeMm),
        wallTransitionLengthMm = _f32(wallTransitionLengthMm),
        wallTransitionAngleDeg = _f32(wallTransitionAngleDeg),
        wallTransitionFilterDeviationMm =
            _f32(wallTransitionFilterDeviationMm);

  /// Exact `process_arachne()` percentage-to-nozzle assignments before those
  /// results are stored in the source `float` members.
  factory SourceArachneWallToolPathsParams2.fromProcessConfig({
    required double minNozzleDiameterMm,
    required double minBeadWidthPercent,
    required double minFeatureSizePercent,
    required double wallTransitionLengthPercent,
    required double wallTransitionAngleDeg,
    required double wallTransitionFilterDeviationPercent,
    required int wallDistributionCount,
  }) =>
      SourceArachneWallToolPathsParams2(
        minBeadWidthMm:
            minBeadWidthPercent * 0.01 * minNozzleDiameterMm,
        minFeatureSizeMm:
            minFeatureSizePercent * 0.01 * minNozzleDiameterMm,
        wallTransitionLengthMm:
            wallTransitionLengthPercent * 0.01 * minNozzleDiameterMm,
        wallTransitionAngleDeg: wallTransitionAngleDeg,
        wallTransitionFilterDeviationMm:
            wallTransitionFilterDeviationPercent *
                0.01 *
                minNozzleDiameterMm,
        wallDistributionCount: wallDistributionCount,
      );

  final double minBeadWidthMm;
  final double minFeatureSizeMm;
  final double wallTransitionLengthMm;
  final double wallTransitionAngleDeg;
  final double wallTransitionFilterDeviationMm;
  final int wallDistributionCount;

  static double _f32(double value) {
    final slot = Float32List(1)..[0] = value;
    return slot[0];
  }
}

/// Constructor state of pinned `Arachne::WallToolPaths` before `generate()`.
///
/// This intentionally does not claim toolpath generation yet. It freezes the
/// numeric boundary that the later beading / skeletal-trapezoidation port must
/// consume.
class SourceArachneWallToolPathsState2 {
  SourceArachneWallToolPathsState2({
    required this.outline,
    required this.beadWidth0,
    required this.beadWidthX,
    required this.insetCount,
    required this.wall0Inset,
    required this.layerHeightMm,
    required this.params,
  })  : printThinWalls = SourceArachneWallToolPathsPreprocess2.fillOutlineGaps,
        minFeatureSize = _scaleFloat(params.minFeatureSizeMm),
        minBeadWidth = _scaleFloat(params.minBeadWidthMm),
        smallAreaLength = beadWidth0.toDouble() / 2.0,
        wallTransitionFilterDeviation =
            _scaleFloat(params.wallTransitionFilterDeviationMm),
        toolpathsGenerated = false;

  final List<SourcePolygon2> outline;
  final int beadWidth0;
  final int beadWidthX;
  final int insetCount;
  final int wall0Inset;
  final double layerHeightMm;
  final SourceArachneWallToolPathsParams2 params;

  final bool printThinWalls;
  final int minFeatureSize;
  final int minBeadWidth;
  final double smallAreaLength;
  final int wallTransitionFilterDeviation;
  final bool toolpathsGenerated;

  static int _scaleFloat(double value) {
    final denominator = SourceArachneWallToolPathsPreprocess2.float32(
      Slic3rUnits.scalingFactor,
    );
    final quotient = SourceArachneWallToolPathsPreprocess2.float32(
      SourceArachneWallToolPathsPreprocess2.float32(value) / denominator,
    );
    return quotient.truncate();
  }
}

/// Independently testable preprocessing primitives at the front of pinned
/// `WallToolPaths.cpp`.
class SourceArachneWallToolPathsPreprocess2 {
  const SourceArachneWallToolPathsPreprocess2._();

  static const bool fillOutlineGaps = true;

  /// Pinned constants are `scaled<coord_t>(double_literal)`, so the division is
  /// IEEE double followed by integer truncation.
  static final int meshfixMaximumResolution = scaleDouble(0.5);
  static final int meshfixMaximumDeviation = scaleDouble(0.025);
  static final int meshfixMaximumExtrusionAreaDeviation = scaleDouble(2.0);

  static final int epsilonOffset = (meshfixMaximumDeviation ~/ 2) - 1;

  static double float32(double value) {
    final slot = Float32List(1)..[0] = value;
    return slot[0];
  }

  static int scaleDouble(double value) =>
      (value / Slic3rUnits.scalingFactor).truncate();

  static double scaledDouble(double value) =>
      value / Slic3rUnits.scalingFactor;

  /// Port of the standalone `simplify(Polygon&, ..., ...)` in pinned
  /// `Arachne/WallToolPaths.cpp`.
  static SourcePolygon2 simplifyPolygon(
    SourcePolygon2 polygon, {
    required int smallestLineSegment,
    required int allowedErrorDistance,
  }) {
    final original = polygon.points;
    if (original.length < 3) return SourcePolygon2(const []);
    if (original.length == 3) return SourcePolygon2(original);

    final smallestLineSegmentSquared =
        smallestLineSegment * smallestLineSegment;
    final allowedErrorDistanceSquared =
        allowedErrorDistance * allowedErrorDistance;

    final newPath = <SourcePoint2>[];
    var previous = original.last;
    var previousPrevious = original[original.length - 2];
    var current = original.first;

    var accumulatedAreaRemoved =
        previous.x * current.y - previous.y * current.x;

    final unconditionalShortSquared = scaleDouble(25.0);
    final nearCollinearCoord = scaleDouble(0.005);
    final nearCollinearSquared = nearCollinearCoord * nearCollinearCoord;
    final nearCollinearDistance = scaledDouble(0.005);

    for (var pointIndex = 0; pointIndex < original.length; pointIndex++) {
      current = original[pointIndex % original.length];

      late final SourcePoint2 next;
      if (pointIndex + 1 < original.length) {
        next = original[pointIndex + 1];
      } else if (pointIndex + 1 == original.length && newPath.length > 1) {
        next = newPath.first;
      } else {
        next = original[(pointIndex + 1) % original.length];
      }

      final removedAreaNext = current.x * next.y - current.y * next.x;
      final negativeAreaClosing =
          next.x * previous.y - next.y * previous.x;
      accumulatedAreaRemoved += removedAreaNext;

      final length2 = _squaredDistance(current, previous);
      if (length2 < unconditionalShortSquared) {
        continue;
      }

      final areaRemovedSoFar =
          accumulatedAreaRemoved + negativeAreaClosing;
      final baseLength2 = _squaredDistance(next, previous);
      if (baseLength2 == 0) {
        continue;
      }

      // C++ declares the destination `int64_t`, truncating this double result.
      final height2 =
          (areaRemovedSoFar.toDouble() * areaRemovedSoFar.toDouble() /
                  baseLength2.toDouble())
              .truncate();

      if (height2 <= nearCollinearSquared &&
          _distanceToInfinite(current, previous, next) <=
              nearCollinearDistance) {
        continue;
      }

      if (length2 < smallestLineSegmentSquared &&
          height2 <= allowedErrorDistanceSquared) {
        final nextLength2 = _squaredDistance(current, next);
        if (nextLength2 > 4 * smallestLineSegmentSquared) {
          final intersection =
              SourceLine2(previousPrevious, previous).intersectionInfinite(
            SourceLine2(current, next),
          );

          if (intersection != null &&
              _distanceToInfiniteSquared(
                    intersection,
                    previous,
                    current,
                  ) <=
                  allowedErrorDistanceSquared.toDouble() &&
              _squaredDistance(intersection, previous) <=
                  smallestLineSegmentSquared &&
              _squaredDistance(intersection, next) <=
                  smallestLineSegmentSquared) {
            current = intersection;
            if (newPath.isNotEmpty) {
              newPath.removeLast();
              previous = previousPrevious;
            }
          } else {
            // Source keeps the current vertex when no safe replacement exists.
          }
        } else {
          continue;
        }
      }

      accumulatedAreaRemoved = removedAreaNext;
      previousPrevious = previous;
      previous = current;
      newPath.add(current);
    }

    return SourcePolygon2(newPath);
  }

  /// Source `simplify(Polygons&, smallest_line_segment, allowed_error_distance)`
  /// removes polygons that drop below three vertices after simplification.
  static List<SourcePolygon2> simplifyPolygons(
    Iterable<SourcePolygon2> polygons, {
    int? smallestLineSegment,
    int? allowedErrorDistance,
  }) {
    final smallest = smallestLineSegment ?? scaleDouble(0.01);
    final allowed = allowedErrorDistance ?? scaleDouble(0.005);
    final result = <SourcePolygon2>[];
    for (final polygon in polygons) {
      final simplified = simplifyPolygon(
        polygon,
        smallestLineSegment: smallest,
        allowedErrorDistance: allowed,
      );
      if (simplified.points.length >= 3) result.add(simplified);
    }
    return List.unmodifiable(result);
  }

  static int _squaredDistance(SourcePoint2 a, SourcePoint2 b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return dx * dx + dy * dy;
  }

  static double _distanceToInfinite(
    SourcePoint2 point,
    SourcePoint2 a,
    SourcePoint2 b,
  ) =>
      math.sqrt(_distanceToInfiniteSquared(point, a, b));

  static double _distanceToInfiniteSquared(
    SourcePoint2 point,
    SourcePoint2 a,
    SourcePoint2 b,
  ) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final lengthSquared = dx.toDouble() * dx + dy.toDouble() * dy;
    if (lengthSquared == 0) {
      return _squaredDistance(point, a).toDouble();
    }
    final cross =
        dx.toDouble() * (a.y - point.y) - (a.x - point.x) * dy.toDouble();
    return cross * cross / lengthSquared;
  }
}
