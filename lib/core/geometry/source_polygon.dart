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
