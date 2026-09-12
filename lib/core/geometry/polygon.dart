import 'dart:math' as math;

import 'bounding_box.dart';
import 'point.dart';

class Polygon2 {
  Polygon2(Iterable<Point2> points) : points = List.unmodifiable(points);

  final List<Point2> points;

  double get signedArea {
    if (points.length < 3) return 0;
    var sum = 0.0;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      sum += a.x * b.y - b.x * a.y;
    }
    return sum / 2;
  }

  double get area => signedArea.abs();
  bool get isClockwise => signedArea < 0;

  BoundingBox2 get bounds {
    final box = BoundingBox2.empty();
    for (final point in points) {
      box.include(point);
    }
    return box;
  }

  Point2 get centroid {
    if (points.isEmpty) return const Point2(0, 0);
    final a = signedArea;
    if (a.abs() < 1e-12) {
      final sx = points.fold<double>(0, (s, p) => s + p.x);
      final sy = points.fold<double>(0, (s, p) => s + p.y);
      return Point2(sx / points.length, sy / points.length);
    }
    var cx = 0.0;
    var cy = 0.0;
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final q = points[(i + 1) % points.length];
      final cross = p.x * q.y - q.x * p.y;
      cx += (p.x + q.x) * cross;
      cy += (p.y + q.y) * cross;
    }
    final f = 1 / (6 * a);
    return Point2(cx * f, cy * f);
  }

  bool contains(Point2 point) {
    var inside = false;
    for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
      final pi = points[i];
      final pj = points[j];
      final intersects = ((pi.y > point.y) != (pj.y > point.y)) &&
          (point.x <
              (pj.x - pi.x) *
                      (point.y - pi.y) /
                      ((pj.y - pi.y).abs() < 1e-18 ? 1e-18 : (pj.y - pi.y)) +
                  pi.x);
      if (intersects) inside = !inside;
    }
    return inside;
  }

  Polygon2 reversed() => Polygon2(points.reversed);

  double distanceToBoundary(Point2 p) {
    if (points.length < 2) return double.infinity;
    var best = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      final ab = b - a;
      final denom = ab.dot(ab);
      final t = denom == 0
          ? 0.0
          : math.max(0.0, math.min(1.0, (p - a).dot(ab) / denom));
      best = math.min(best, p.distanceTo(a + ab * t));
    }
    return best;
  }
}
