import 'dart:math' as math;

import 'source_geometry.dart';

enum ArcDirection2 { unknown, ccw, cw, count }

/// Integer-coordinate port of QIDI `libslic3r/Circle.hpp/.cpp`.
/// Radius and arc lengths remain in source `coord_t` units, matching C++.
class SourceCircle2 {
  const SourceCircle2({
    this.center = const SourcePoint2(0, 0),
    this.radius = 0,
  });

  final SourcePoint2 center;
  final double radius;

  SourcePoint2 getClosestPoint(SourcePoint2 input) {
    final dx = input.x - center.x;
    final dy = input.y - center.y;
    final norm = math.sqrt(dx.toDouble() * dx + dy.toDouble() * dy);
    if (norm == 0) return center;
    final ox = (dx / norm * radius).truncate();
    final oy = (dy / norm * radius).truncate();
    return SourcePoint2(center.x + ox, center.y + oy);
  }

  double getPolarRadians(SourcePoint2 point) {
    var value = math.atan2(point.y - center.y, point.x - center.x);
    if (value < 0) value = 2 * math.pi + value;
    return value;
  }

  bool isOverDeviation(List<SourcePoint2> points, double tolerance) {
    for (var index = 0; index < points.length - 1; index++) {
      if (index != 0) {
        final deviation = _radialDeviation(points[index]);
        if (deviation.abs() > tolerance) return true;
      }
      final closest = closestPerpendicularPoint(
        points[index],
        points[index + 1],
        center,
      );
      if (closest != null) {
        final deviation = _radialDeviation(closest);
        if (deviation.abs() > tolerance) return true;
      }
    }
    return false;
  }

  double? deviationSumSquaredOrNull(
    List<SourcePoint2> points,
    double tolerance,
  ) {
    var total = 0.0;
    for (var index = 1; index < points.length - 1; index++) {
      final deviation = _radialDeviation(points[index]).abs();
      total += deviation * deviation;
      if (deviation > tolerance) return null;
    }
    for (var index = 0; index < points.length - 1; index++) {
      final closest = closestPerpendicularPoint(
        points[index],
        points[index + 1],
        center,
      );
      if (closest != null) {
        final deviation = _radialDeviation(closest).abs();
        total += deviation * deviation;
        if (deviation > tolerance) return null;
      }
    }
    return total;
  }

  double _radialDeviation(SourcePoint2 point) {
    final dx = point.x - center.x;
    final dy = point.y - center.y;
    final distance = math.sqrt(dx.toDouble() * dx + dy.toDouble() * dy);
    return distance - radius;
  }

  static SourcePoint2? closestPerpendicularPoint(
    SourcePoint2 p1,
    SourcePoint2 p2,
    SourcePoint2 center,
  ) {
    final x1 = p1.x.toDouble();
    final y1 = p1.y.toDouble();
    final x2 = p2.x.toDouble();
    final y2 = p2.y.toDouble();
    final dx = x2 - x1;
    final dy = y2 - y1;
    final numerator = (center.x - x1) * dx + (center.y - y1) * dy;
    final denominator = dx * dx + dy * dy;
    final t = numerator / denominator;
    if (_lessThanOrEqual(t, 0) || _greaterThanOrEqual(t, 1)) return null;
    return SourcePoint2(
      (x1 + t * (x2 - x1)).truncate(),
      (y1 + t * (y2 - y1)).truncate(),
    );
  }

  static SourceCircle2? tryCreateFromThree(
    SourcePoint2 p1,
    SourcePoint2 p2,
    SourcePoint2 p3,
    double maxRadius,
  ) {
    final x1 = p1.x.toDouble();
    final y1 = p1.y.toDouble();
    final x2 = p2.x.toDouble();
    final y2 = p2.y.toDouble();
    final x3 = p3.x.toDouble();
    final y3 = p3.y.toDouble();

    // `scale_(scale_(0.0001))` from Circle.cpp.
    const parallelAreaThresholdScaledTwice = 1000000.0;
    final areaLike = (y1 - y2) * (x1 - x3) -
        (y1 - y3) * (x1 - x2);
    if (areaLike.abs() <= parallelAreaThresholdScaledTwice) return null;

    final a = x1 * (y2 - y3) -
        y1 * (x2 - x3) +
        x2 * y3 -
        x3 * y2;
    if (a.abs() < Slic3rUnits.scaledEpsilon) return null;

    final b = (x1 * x1 + y1 * y1) * (y3 - y2) +
        (x2 * x2 + y2 * y2) * (y1 - y3) +
        (x3 * x3 + y3 * y3) * (y2 - y1);
    final c = (x1 * x1 + y1 * y1) * (x2 - x3) +
        (x2 * x2 + y2 * y2) * (x3 - x1) +
        (x3 * x3 + y3 * y3) * (x1 - x2);

    final centerX = -b / (2 * a);
    final centerY = -c / (2 * a);
    final deltaX = centerX - x1;
    final deltaY = centerY - y1;
    final radius = math.sqrt(deltaX * deltaX + deltaY * deltaY);
    if (radius > maxRadius) return null;

    // Point(double,double) stores coord_t, therefore truncates toward zero.
    return SourceCircle2(
      center: SourcePoint2(centerX.truncate(), centerY.truncate()),
      radius: radius,
    );
  }

  static SourceCircle2? tryCreate(
    List<SourcePoint2> points, {
    required double maxRadius,
    required double tolerance,
  }) {
    if (points.length < 3) return null;
    final count = points.length;
    final middleIndex = count ~/ 2;

    if (count == 3) {
      final circle = tryCreateFromThree(
        points[0],
        points[middleIndex],
        points[count - 1],
        maxRadius,
      );
      if (circle != null && !circle.isOverDeviation(points, tolerance)) {
        return circle;
      }
      return null;
    }

    // Preserve the source's unusual odd-count choice: it averages the points
    // on either side of the actual middle, not the middle point itself.
    final middlePoint = count.isEven
        ? SourcePoint2(
            (points[middleIndex].x + points[middleIndex - 1].x) ~/ 2,
            (points[middleIndex].y + points[middleIndex - 1].y) ~/ 2,
          )
        : SourcePoint2(
            (points[middleIndex - 1].x + points[middleIndex + 1].x) ~/ 2,
            (points[middleIndex - 1].y + points[middleIndex + 1].y) ~/ 2,
          );

    final firstTry = tryCreateFromThree(
      points[0],
      middlePoint,
      points[count - 1],
      maxRadius,
    );
    if (firstTry != null && !firstTry.isOverDeviation(points, tolerance)) {
      return firstTry;
    }

    SourceCircle2? best;
    double? leastDeviation;
    for (var index = 1; index < count - 1; index++) {
      if (index == middleIndex) continue;
      final candidate = tryCreateFromThree(
        points[0],
        points[index],
        points[count - 1],
        maxRadius,
      );
      if (candidate == null) continue;
      final deviation = candidate.deviationSumSquaredOrNull(points, tolerance);
      if (deviation == null) continue;
      if (best == null || deviation < leastDeviation!) {
        best = candidate;
        leastDeviation = deviation;
      }
    }
    return best;
  }

  static const double zeroTolerance = 0.000005;

  static bool _isEqual(
    double x,
    double y, [
    double tolerance = zeroTolerance,
  ]) =>
      (x - y).abs() < tolerance;

  static bool _greaterThanOrEqual(double x, double y) =>
      x > y || _isEqual(x, y);

  static bool _lessThanOrEqual(double x, double y) =>
      x < y || _isEqual(x, y);
}

class SourceArcSegment2 extends SourceCircle2 {
  SourceArcSegment2({
    super.center,
    super.radius,
    this.startPoint = const SourcePoint2(0, 0),
    this.endPoint = const SourcePoint2(0, 0),
    this.direction = ArcDirection2.unknown,
    bool initialize = true,
  }) {
    if (initialize) {
      if (radius == 0 ||
          startPoint == center ||
          endPoint == center ||
          startPoint == endPoint) {
        isArc = false;
      } else {
        _updateAngleAndLength();
        isArc = true;
      }
    }
  }

  static const double defaultScaledMaxRadius = 200000000.0;
  static const double defaultScaledResolution = 5000.0;
  static const double defaultArcLengthPercentTolerance = 0.05;

  bool isArc = false;
  double length = 0;
  double angleRadians = 0;
  double polarStartTheta = 0;
  double polarEndTheta = 0;
  SourcePoint2 startPoint;
  SourcePoint2 endPoint;
  ArcDirection2 direction;

  bool get isValid => isArc;

  SourceArcSegment2 clone() {
    final out = SourceArcSegment2(
      center: center,
      radius: radius,
      startPoint: startPoint,
      endPoint: endPoint,
      direction: direction,
      initialize: false,
    );
    out
      ..isArc = isArc
      ..length = length
      ..angleRadians = angleRadians
      ..polarStartTheta = polarStartTheta
      ..polarEndTheta = polarEndTheta;
    return out;
  }

  bool reverse() {
    if (!isValid) return false;
    final oldStart = startPoint;
    startPoint = endPoint;
    endPoint = oldStart;
    direction = direction == ArcDirection2.ccw
        ? ArcDirection2.cw
        : ArcDirection2.ccw;
    angleRadians *= -1;
    final oldPolar = polarStartTheta;
    polarStartTheta = polarEndTheta;
    polarEndTheta = oldPolar;
    return true;
  }

  bool clipStart(SourcePoint2 point) {
    if (!isValid || point == center || !isPointInside(point)) return false;
    startPoint = getClosestPoint(point);
    _updateAngleAndLength();
    return true;
  }

  bool clipEnd(SourcePoint2 point) {
    if (!isValid || point == center || !isPointInside(point)) return false;
    endPoint = getClosestPoint(point);
    _updateAngleAndLength();
    return true;
  }

  (SourceArcSegment2, SourceArcSegment2)? splitAt(SourcePoint2 point) {
    if (!isValid || point == center || !isPointInside(point)) return null;
    final segmentPoint = getClosestPoint(point);
    return (
      SourceArcSegment2(
        center: center,
        radius: radius,
        startPoint: startPoint,
        endPoint: segmentPoint,
        direction: direction,
      ),
      SourceArcSegment2(
        center: center,
        radius: radius,
        startPoint: segmentPoint,
        endPoint: endPoint,
        direction: direction,
      ),
    );
  }

  bool isPointInside(SourcePoint2 point) {
    final polarTheta = getPolarRadians(point);
    var delta = polarTheta - polarStartTheta;
    if (delta > 0 && direction == ArcDirection2.cw) {
      delta -= 2 * math.pi;
    } else if (delta < 0 && direction == ArcDirection2.ccw) {
      delta += 2 * math.pi;
    }
    return direction == ArcDirection2.ccw
        ? delta > 0 && delta < angleRadians
        : delta < 0 && delta > angleRadians;
  }

  void _updateAngleAndLength() {
    polarStartTheta = getPolarRadians(startPoint);
    polarEndTheta = getPolarRadians(endPoint);
    angleRadians = polarEndTheta - polarStartTheta;
    if (angleRadians < 0 && direction == ArcDirection2.ccw) {
      angleRadians += 2 * math.pi;
    } else if (angleRadians > 0 && direction == ArcDirection2.cw) {
      angleRadians -= 2 * math.pi;
    }
    length = angleRadians.abs() * radius;
    isArc = true;
  }

  static SourceArcSegment2? tryCreateArc(
    List<SourcePoint2> points, {
    required double approximateLength,
    double maxRadius = defaultScaledMaxRadius,
    double tolerance = defaultScaledResolution,
    double pathTolerancePercent = defaultArcLengthPercentTolerance,
  }) {
    final circle = SourceCircle2.tryCreate(
      points,
      maxRadius: maxRadius,
      tolerance: tolerance,
    );
    if (circle == null) return null;
    final midPointIndex = ((points.length - 2) ~/ 2) + 1;
    final arc = _tryCreateArcFromCircle(
      circle,
      points.first,
      points[midPointIndex],
      points.last,
      approximateLength,
      pathTolerancePercent,
    );
    if (arc == null) return null;
    return arePointsWithinSlice(arc, points) ? arc : null;
  }

  static SourceArcSegment2? _tryCreateArcFromCircle(
    SourceCircle2 circle,
    SourcePoint2 start,
    SourcePoint2 mid,
    SourcePoint2 end,
    double approximateLength,
    double pathTolerancePercent,
  ) {
    final polarStart = circle.getPolarRadians(start);
    final polarMid = circle.getPolarRadians(mid);
    final polarEnd = circle.getPolarRadians(end);

    var angle = 0.0;
    var direction = ArcDirection2.unknown;
    if (polarEnd > polarStart) {
      if (polarStart < polarMid && polarMid < polarEnd) {
        direction = ArcDirection2.ccw;
        angle = polarEnd - polarStart;
      } else if ((0 <= polarMid && polarMid < polarStart) ||
          (polarEnd < polarMid && polarMid < 2 * math.pi)) {
        direction = ArcDirection2.cw;
        angle = polarStart + (2 * math.pi - polarEnd);
      }
    } else if (polarStart > polarEnd) {
      if ((polarStart < polarMid && polarMid < 2 * math.pi) ||
          (0 < polarMid && polarMid < polarEnd)) {
        direction = ArcDirection2.ccw;
        angle = polarEnd + (2 * math.pi - polarStart);
      } else if (polarEnd < polarMid && polarMid < polarStart) {
        direction = ArcDirection2.cw;
        angle = polarStart - polarEnd;
      }
    }

    if (direction == ArcDirection2.unknown ||
        angle.abs() < Slic3rUnits.epsilon) {
      return null;
    }

    var arcLength = circle.radius * angle;
    var difference = (arcLength - approximateLength) / approximateLength;
    if (difference.abs() >= pathTolerancePercent) {
      final testRadians = (angle - 2 * math.pi).abs();
      final testArcLength = circle.radius * testRadians;
      difference = (testArcLength - approximateLength) / approximateLength;
      if (difference.abs() >= pathTolerancePercent) return null;
      arcLength = testArcLength;
      direction = direction == ArcDirection2.ccw
          ? ArcDirection2.cw
          : ArcDirection2.ccw;
    }

    if (direction == ArcDirection2.cw) angle *= -1;
    final out = SourceArcSegment2(
      center: circle.center,
      radius: circle.radius,
      startPoint: start,
      endPoint: end,
      direction: direction,
      initialize: false,
    );
    out
      ..isArc = true
      ..length = arcLength
      ..angleRadians = angle
      ..polarStartTheta = polarStart
      ..polarEndTheta = polarEnd;
    return out;
  }

  /// Literal port of the supplied `are_points_within_slice()`. The original
  /// loop begins at `point_count - 2`; it does not walk every interior point.
  static bool arePointsWithinSlice(
    SourceArcSegment2 testArc,
    List<SourcePoint2> points,
  ) {
    var previousPolar = testArc.polarStartTheta;
    var willCrossZero = false;
    var crossedZero = false;
    final pointCount = points.length;
    final startNormX =
        (testArc.startPoint.x - testArc.center.x) / testArc.radius;
    final startNormY =
        (testArc.startPoint.y - testArc.center.y) / testArc.radius;
    final endNormX = (testArc.endPoint.x - testArc.center.x) / testArc.radius;
    final endNormY = (testArc.endPoint.y - testArc.center.y) / testArc.radius;

    if (testArc.direction == ArcDirection2.ccw) {
      willCrossZero = testArc.polarStartTheta > testArc.polarEndTheta;
    } else {
      willCrossZero = testArc.polarStartTheta < testArc.polarEndTheta;
    }

    for (var index = pointCount - 2; index < pointCount; index++) {
      final polarTest = index < pointCount - 1
          ? testArc.getPolarRadians(points[index])
          : testArc.polarEndTheta;

      if (testArc.direction == ArcDirection2.ccw) {
        if (index < pointCount - 1) {
          if (willCrossZero) {
            if (!(polarTest > testArc.polarStartTheta ||
                polarTest < testArc.polarEndTheta)) {
              return false;
            }
          } else if (!(testArc.polarStartTheta < polarTest &&
              polarTest < testArc.polarEndTheta)) {
            return false;
          }
        }
        if (previousPolar > polarTest) {
          if (!willCrossZero || crossedZero) return false;
          crossedZero = true;
        }
      } else {
        if (index < pointCount - 1) {
          if (willCrossZero) {
            if (!(polarTest < testArc.polarStartTheta ||
                polarTest > testArc.polarEndTheta)) {
              return false;
            }
          } else if (!(testArc.polarStartTheta > polarTest &&
              polarTest > testArc.polarEndTheta)) {
            return false;
          }
        }
        if (previousPolar < polarTest) {
          if (!willCrossZero || crossedZero) return false;
          crossedZero = true;
        }
      }

      final segment = SourceLine2(points[index - 1], points[index]);
      if ((index != 1 &&
              rayIntersectsSegment(
                testArc.center,
                startNormX,
                startNormY,
                segment,
              )) ||
          (index != pointCount - 1 &&
              rayIntersectsSegment(
                testArc.center,
                endNormX,
                endNormY,
                segment,
              ))) {
        return false;
      }
      previousPolar = polarTest;
    }
    return willCrossZero == crossedZero;
  }

  static bool rayIntersectsSegment(
    SourcePoint2 rayOrigin,
    double rayDirectionX,
    double rayDirectionY,
    SourceLine2 segment,
  ) {
    final v1x = rayOrigin.x - segment.a.x;
    final v1y = rayOrigin.y - segment.a.y;
    final v2x = segment.b.x - segment.a.x;
    final v2y = segment.b.y - segment.a.y;
    final v3x = -rayDirectionY;
    final v3y = rayDirectionX;

    final dot = v2x * v3x + v2y * v3y;
    if (dot.abs() < Slic3rUnits.scaledEpsilon) return false;
    final t1 = (v2x * v1y - v2y * v1x) / dot;
    final t2 = (v1x * v3x + v1y * v3y) / dot;
    return t1 >= 0 && t2 >= 0 && t2 <= 1;
  }
}
