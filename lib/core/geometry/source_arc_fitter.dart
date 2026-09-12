import 'source_circle.dart';
import 'source_geometry.dart';

enum MovePathType2 { noop, linear, arcCw, arcCcw, count }

class PathFittingData2 {
  PathFittingData2({
    required this.startPointIndex,
    required this.endPointIndex,
    required this.pathType,
    SourceArcSegment2? arcData,
  }) : arcData = arcData ?? SourceArcSegment2();

  int startPointIndex;
  int endPointIndex;
  MovePathType2 pathType;
  SourceArcSegment2 arcData;

  bool get isLinearMove => pathType == MovePathType2.linear;
  bool get isArcMove =>
      pathType == MovePathType2.arcCcw || pathType == MovePathType2.arcCw;

  bool reverseArcPath() {
    if (!isArcMove || !arcData.reverse()) return false;
    pathType = arcData.direction == ArcDirection2.ccw
        ? MovePathType2.arcCcw
        : MovePathType2.arcCw;
    return true;
  }

  PathFittingData2 clone() => PathFittingData2(
        startPointIndex: startPointIndex,
        endPointIndex: endPointIndex,
        pathType: pathType,
        arcData: arcData.clone(),
      );
}

/// Literal port of QIDI `libslic3r/ArcFitter.cpp` plus the exact iterative
/// `MultiPoint::_douglas_peucker()` used by it.
class ArcFitter2 {
  const ArcFitter2._();

  static List<PathFittingData2> doArcFitting(
    List<SourcePoint2> points,
    double tolerance,
  ) {
    final result = <PathFittingData2>[];
    if (points.length < 3) {
      result.add(PathFittingData2(
        startPointIndex: 0,
        endPointIndex: points.length - 1,
        pathType: MovePathType2.linear,
      ));
      return result;
    }

    var frontIndex = 0;
    var backIndex = 0;
    var lastArc = SourceArcSegment2();
    final currentSegment = <SourcePoint2>[];

    for (var i = 0; i < points.length; i++) {
      backIndex = i;
      currentSegment.add(points[i]);
      if (backIndex - frontIndex < 2) continue;

      final targetArc = SourceArcSegment2.tryCreateArc(
        currentSegment,
        approximateLength: _polylineLength(currentSegment),
        maxRadius: SourceArcSegment2.defaultScaledMaxRadius,
        tolerance: tolerance,
        pathTolerancePercent:
            SourceArcSegment2.defaultArcLengthPercentTolerance,
      );
      if (targetArc != null) {
        lastArc = targetArc.clone();
        if (backIndex == points.length - 1) {
          result.add(PathFittingData2(
            startPointIndex: frontIndex,
            endPointIndex: backIndex,
            pathType: lastArc.direction == ArcDirection2.ccw
                ? MovePathType2.arcCcw
                : MovePathType2.arcCw,
            arcData: lastArc.clone(),
          ));
          frontIndex = backIndex;
        }
      } else {
        if (backIndex - frontIndex > 2) {
          result.add(PathFittingData2(
            startPointIndex: frontIndex,
            endPointIndex: backIndex - 1,
            pathType: lastArc.direction == ArcDirection2.ccw
                ? MovePathType2.arcCcw
                : MovePathType2.arcCw,
            arcData: lastArc.clone(),
          ));
        } else {
          if (result.isEmpty || result.last.pathType != MovePathType2.linear) {
            result.add(PathFittingData2(
              startPointIndex: frontIndex,
              endPointIndex: frontIndex + 1,
              pathType: MovePathType2.linear,
            ));
          } else {
            result.last.endPointIndex = frontIndex + 1;
          }
        }
        frontIndex = backIndex - 1;
        currentSegment
          ..clear()
          ..add(points[frontIndex])
          ..add(points[frontIndex + 1]);
      }
    }

    if (frontIndex != backIndex) {
      if (result.isEmpty || result.last.pathType != MovePathType2.linear) {
        result.add(PathFittingData2(
          startPointIndex: frontIndex,
          endPointIndex: backIndex,
          pathType: MovePathType2.linear,
        ));
      } else {
        result.last.endPointIndex = backIndex;
      }
    }
    return result;
  }

  static ({List<SourcePoint2> points, List<PathFittingData2> result})
      doArcFittingAndSimplify(
    List<SourcePoint2> sourcePoints,
    double tolerance,
  ) {
    var points = List<SourcePoint2>.of(sourcePoints);
    final result = tolerance.abs() > Slic3rUnits.scaledEpsilon
        ? doArcFitting(points, tolerance)
        : <PathFittingData2>[
            PathFittingData2(
              startPointIndex: 0,
              endPointIndex: points.length - 1,
              pathType: MovePathType2.linear,
            ),
          ];

    if (result.length == 1 && result[0].pathType == MovePathType2.linear) {
      points = douglasPeucker(points, tolerance);
      result[0].endPointIndex = points.length - 1;
      return (points: points, result: result);
    }

    final simplifiedPoints = <SourcePoint2>[points[0]];
    final reduceCount = List<int>.filled(result.length, 0);
    for (var i = 0; i < result.length; i++) {
      final start = result[i].startPointIndex;
      final end = result[i].endPointIndex;
      final part = douglasPeucker(
        List<SourcePoint2>.of(points.getRange(start, end + 1)),
        tolerance,
      );
      reduceCount[i] = end - start + 1 - part.length;
      simplifiedPoints.addAll(part.skip(1));
    }
    points = simplifiedPoints;

    for (var j = 1; j < reduceCount.length; j++) {
      reduceCount[j] += reduceCount[j - 1];
    }
    for (var j = 0; j < result.length; j++) {
      result[j].endPointIndex -= reduceCount[j];
      if (j != result.length - 1) {
        result[j + 1].startPointIndex = result[j].endPointIndex;
      }
    }
    return (points: points, result: result);
  }

  static List<SourcePoint2> douglasPeucker(
    List<SourcePoint2> points,
    double tolerance,
  ) {
    final result = <SourcePoint2>[];
    final toleranceSquared = tolerance * tolerance;
    if (points.isEmpty) return result;

    var anchorIndex = 0;
    var floaterIndex = points.length - 1;
    result.add(points[anchorIndex]);
    if (anchorIndex == floaterIndex) return result;

    final stack = <int>[floaterIndex];
    while (true) {
      var maxDistanceSquared = 0.0;
      var furthestIndex = anchorIndex;
      for (var i = anchorIndex + 1; i < floaterIndex; i++) {
        final distanceSquared = _distanceToSegmentSquared(
          points[i],
          points[anchorIndex],
          points[floaterIndex],
        );
        if (distanceSquared > maxDistanceSquared) {
          maxDistanceSquared = distanceSquared;
          furthestIndex = i;
        }
      }

      if (maxDistanceSquared <= toleranceSquared) {
        result.add(points[floaterIndex]);
        anchorIndex = floaterIndex;
        stack.removeLast();
        if (stack.isEmpty) break;
        floaterIndex = stack.last;
      } else {
        floaterIndex = furthestIndex;
        stack.add(floaterIndex);
      }
    }
    return result;
  }

  static double _distanceToSegmentSquared(
    SourcePoint2 point,
    SourcePoint2 a,
    SourcePoint2 b,
  ) {
    final vx = (b.x - a.x).toDouble();
    final vy = (b.y - a.y).toDouble();
    final vax = (point.x - a.x).toDouble();
    final vay = (point.y - a.y).toDouble();
    final lengthSquared = vx * vx + vy * vy;
    if (lengthSquared == 0) return vax * vax + vay * vay;
    final t = (vax * vx + vay * vy) / lengthSquared;
    if (t <= 0) return vax * vax + vay * vay;
    if (t >= 1) {
      final dx = (point.x - b.x).toDouble();
      final dy = (point.y - b.y).toDouble();
      return dx * dx + dy * dy;
    }
    final dx = t * vx - vax;
    final dy = t * vy - vay;
    return dx * dx + dy * dy;
  }

  static double _polylineLength(List<SourcePoint2> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += (points[i] - points[i - 1]).length;
    }
    return total;
  }
}
