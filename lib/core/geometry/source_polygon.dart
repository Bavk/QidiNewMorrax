import 'dart:math' as math;

import 'source_geometry.dart';

/// Integer-coordinate polygon domain corresponding to `Slic3r::Polygon`.
class SourcePolygon2 {
  SourcePolygon2(Iterable<SourcePoint2> points)
      : points = List.unmodifiable(points);

  final List<SourcePoint2> points;

  double get signedArea {
    if (points.length < 3) return 0;
    var twiceArea = 0;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      twiceArea += a.x * b.y - b.x * a.y;
    }
    return twiceArea / 2.0;
  }

  double get area => signedArea.abs();
  bool get isClockwise => signedArea < 0;

  SourcePolygon2 reversed() => SourcePolygon2(points.reversed);

  /// Source `Polygon::contains()` delegates to Clipper1 `PointInPolygon()` and
  /// treats a boundary hit (-1) as inside by default.
  bool contains(SourcePoint2 point, {bool borderResult = true}) {
    final result = pointInPolygon(point);
    if (result == -1) return borderResult;
    return result.isOdd;
  }

  /// Clipper1-shaped point-in-polygon result: 0 outside, +1 inside, -1 on the
  /// polygon boundary. The crossing test is division-free and uses BigInt for
  /// the determinant so Dart does not introduce signed-64 overflow where the
  /// source uses integer geometry.
  int pointInPolygon(SourcePoint2 point) {
    if (points.length < 3) return 0;

    var inside = false;
    var a = points.last;
    for (final b in points) {
      if (_pointOnSegment(point, a, b)) return -1;

      if ((a.y > point.y) != (b.y > point.y)) {
        final dx = BigInt.from(b.x - a.x);
        final py = BigInt.from(point.y - a.y);
        final px = BigInt.from(point.x - a.x);
        final dy = BigInt.from(b.y - a.y);
        final cross = dx * py - px * dy;
        if ((cross > BigInt.zero) == (b.y > a.y)) {
          inside = !inside;
        }
      }
      a = b;
    }
    return inside ? 1 : 0;
  }

  bool _pointOnSegment(
    SourcePoint2 point,
    SourcePoint2 a,
    SourcePoint2 b,
  ) {
    final abx = BigInt.from(b.x - a.x);
    final aby = BigInt.from(b.y - a.y);
    final apx = BigInt.from(point.x - a.x);
    final apy = BigInt.from(point.y - a.y);
    if (abx * apy - aby * apx != BigInt.zero) return false;

    return point.x >= math.min(a.x, b.x) &&
        point.x <= math.max(a.x, b.x) &&
        point.y >= math.min(a.y, b.y) &&
        point.y <= math.max(a.y, b.y);
  }

  List<SourceLine2> lines() {
    if (points.length < 2) return const [];
    return List<SourceLine2>.generate(
      points.length,
      (i) => SourceLine2(points[i], points[(i + 1) % points.length]),
      growable: false,
    );
  }

  double distanceToBoundary(SourcePoint2 point) {
    if (points.length < 2) return double.infinity;
    var best = double.infinity;
    for (final line in lines()) {
      best = math.min(best, line.distanceTo(point));
    }
    return best;
  }

  bool onBoundary(SourcePoint2 point, double eps) =>
      distanceToBoundary(point) < eps;

  /// Port of `Polygon::intersection()`: closing front/back segment first,
  /// followed by [0,1], [1,2], ... .
  SourcePoint2? intersection(SourceLine2 line) {
    if (points.length < 2) return null;
    final closing = SourceLine2(points.first, points.last).intersection(line);
    if (closing != null) return closing;
    for (var i = 1; i < points.length; i++) {
      final hit = SourceLine2(points[i - 1], points[i]).intersection(line);
      if (hit != null) return hit;
    }
    return null;
  }
}

class SourceExPolygon2 {
  SourceExPolygon2({
    required this.contour,
    Iterable<SourcePolygon2> holes = const [],
  }) : holes = List.unmodifiable(holes);

  final SourcePolygon2 contour;
  final List<SourcePolygon2> holes;

  double get area =>
      contour.area - holes.fold<double>(0, (sum, hole) => sum + hole.area);

  bool onBoundary(SourcePoint2 point, double eps) {
    if (contour.onBoundary(point, eps)) return true;
    for (final hole in holes) {
      if (hole.onBoundary(point, eps)) return true;
    }
    return false;
  }

  List<SourceLine2> lines() => [
        ...contour.lines(),
        for (final hole in holes) ...hole.lines(),
      ];
}
