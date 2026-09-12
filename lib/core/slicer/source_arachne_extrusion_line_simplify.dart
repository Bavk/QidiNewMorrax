import 'dart:math' as math;

import '../geometry/source_geometry.dart';
import 'source_arachne_extrusion_line.dart';
import 'source_arachne_wall_tool_paths.dart';

class SourceArachneExtrusionAreaDeviation2 {
  const SourceArachneExtrusionAreaDeviation2({
    required this.error,
    required this.weightedAverageWidth,
  });

  final int error;
  final int weightedAverageWidth;
}

/// Direct port of the pinned variable-width `ExtrusionLine` simplifier used by
/// `WallToolPaths::simplifyToolPaths()`.
extension SourceArachneExtrusionLineSimplify2 on SourceArachneExtrusionLine2 {
  void simplifySource(
    int smallestLineSegmentSquared,
    int allowedErrorDistanceSquared,
    int maximumExtrusionAreaDeviation,
  ) {
    final minPathSize = isClosed ? 3 : 2;
    if (junctions.length <= minPathSize) return;

    final newJunctions = <SourceArachneExtrusionJunction2>[
      junctions.first.copy(),
    ];
    var previousPrevious = junctions.first.copy();
    var previous = junctions.first.copy();
    final initial = junctions[1];
    var accumulatedAreaRemoved =
        previous.p.x * initial.p.y - previous.p.y * initial.p.x;

    for (var pointIndex = 1;
        pointIndex < junctions.length - 1;
        pointIndex++) {
      final current = junctions[pointIndex];
      // This condition is unreachable with the pinned loop bound, but retain it
      // literally rather than normalizing the source code.
      final spillOver =
          pointIndex + 1 == junctions.length && newJunctions.length > 1;
      final next = spillOver ? newJunctions.first : junctions[pointIndex + 1];

      final removedAreaNext =
          current.p.x * next.p.y - current.p.y * next.p.x;
      final negativeAreaClosing =
          next.p.x * previous.p.y - next.p.y * previous.p.x;
      accumulatedAreaRemoved += removedAreaNext;

      final length2 = _squaredDistance(current.p, previous.p);
      // Pinned source compares squared length against scaled<coord_t>(0.025),
      // not against the square of that value.
      if (length2 <
          SourceArachneWallToolPathsPreprocess2.scaleDouble(0.025)) {
        continue;
      }

      final areaRemovedSoFar =
          accumulatedAreaRemoved + negativeAreaClosing;
      final baseLength2 = _squaredDistance(next.p, previous.p);
      if (baseLength2 == 0) continue;

      final height2 =
          (areaRemovedSoFar.toDouble() * areaRemovedSoFar.toDouble() /
                  baseLength2.toDouble())
              .truncate();
      final extrusionArea = sourceCalculateExtrusionAreaDeviationError(
        previous,
        current,
        next,
      );
      if (height2 <=
              SourceArachneWallToolPathsPreprocess2.scaleDouble(0.001) &&
          _distanceToInfinite(current.p, previous.p, next.p) <=
              SourceArachneWallToolPathsPreprocess2.scaledDouble(0.001) &&
          extrusionArea.error <= maximumExtrusionAreaDeviation) {
        continue;
      }

      if (length2 < smallestLineSegmentSquared &&
          height2 <= allowedErrorDistanceSquared) {
        final nextLength2 = _squaredDistance(current.p, next.p);
        if (nextLength2 > 4 * smallestLineSegmentSquared) {
          final intersection =
              SourceLine2(previousPrevious.p, previous.p).intersectionInfinite(
            SourceLine2(current.p, next.p),
          );
          if (intersection != null &&
              _distanceToInfiniteSquared(
                    intersection,
                    previous.p,
                    current.p,
                  ) <=
                  allowedErrorDistanceSquared.toDouble() &&
              _squaredDistance(intersection, previous.p) <=
                  smallestLineSegmentSquared &&
              _squaredDistance(intersection, next.p) <=
                  smallestLineSegmentSquared) {
            final replacement = SourceArachneExtrusionJunction2(
              p: intersection,
              w: current.w,
              perimeterIndex: current.perimeterIndex,
              holeCompensationFlag: current.holeCompensationFlag,
            );
            if (newJunctions.isNotEmpty) {
              newJunctions.removeLast();
              previous = previousPrevious.copy();
            }
            accumulatedAreaRemoved = removedAreaNext;
            previousPrevious = previous.copy();
            previous = replacement.copy();
            newJunctions.add(replacement);
            continue;
          }
        } else {
          continue;
        }
      }

      accumulatedAreaRemoved = removedAreaNext;
      previousPrevious = previous.copy();
      previous = current.copy();
      newJunctions.add(current.copy());
    }

    newJunctions.add(junctions.last.copy());
    if (_squaredDistance(junctions.first.p, junctions.last.p) == 0) {
      newJunctions.last.p = junctions.first.p;
    }

    junctions
      ..clear()
      ..addAll(newJunctions);
  }
}

/// Direct port of
/// `ExtrusionLine::calculateExtrusionAreaDeviationError()`.
SourceArachneExtrusionAreaDeviation2
    sourceCalculateExtrusionAreaDeviationError(
  SourceArachneExtrusionJunction2 a,
  SourceArachneExtrusionJunction2 b,
  SourceArachneExtrusionJunction2 c,
) {
  final abLength = _norm(b.p - a.p);
  final bcLength = _norm(c.p - b.p);
  final widthDiff = math.max((b.w - a.w).abs(), (c.w - b.w).abs());

  if (widthDiff > 1) {
    final abWeight = (a.w + b.w) ~/ 2;
    final bcWeight = (b.w + c.w) ~/ 2;
    final acLength = _norm(c.p - a.p);
    if (acLength == 0) {
      throw StateError('Pinned width-area helper divides by zero for A == C');
    }
    final weightedAverageWidth =
        (abLength * abWeight + bcLength * bcWeight) ~/ acLength;
    final error =
        (abWeight - weightedAverageWidth).abs() * abLength +
            (bcWeight - weightedAverageWidth).abs() * bcLength;
    return SourceArachneExtrusionAreaDeviation2(
      error: error,
      weightedAverageWidth: weightedAverageWidth,
    );
  }

  final weightedAverageWidth = abLength > bcLength ? a.w : b.w;
  final error = abLength > bcLength
      ? widthDiff * bcLength
      : widthDiff * abLength;
  return SourceArachneExtrusionAreaDeviation2(
    error: error,
    weightedAverageWidth: weightedAverageWidth,
  );
}

int _norm(SourcePoint2 vector) =>
    math.sqrt(vector.squaredLength.toDouble()).truncate();

int _squaredDistance(SourcePoint2 a, SourcePoint2 b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  return dx * dx + dy * dy;
}

double _distanceToInfinite(
  SourcePoint2 point,
  SourcePoint2 a,
  SourcePoint2 b,
) =>
    math.sqrt(_distanceToInfiniteSquared(point, a, b));

double _distanceToInfiniteSquared(
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
