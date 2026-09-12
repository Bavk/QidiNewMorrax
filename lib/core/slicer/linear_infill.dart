import 'dart:math' as math;

import '../geometry/point.dart';
import '../geometry/polygon.dart';

class InfillSegment {
  const InfillSegment(this.a, this.b);

  final Point2 a;
  final Point2 b;

  double get length => a.distanceTo(b);
}

/// Generates parallel line infill clipped with the even-odd fill rule.
///
/// `contours` may contain multiple islands and nested holes. Pairing all edge
/// intersections on a scanline means nested contours are handled without
/// requiring callers to pre-classify exterior/hole winding.
class LinearInfillGenerator {
  const LinearInfillGenerator({this.epsilon = 1e-8});

  final double epsilon;

  List<InfillSegment> generate(
    List<Polygon2> contours, {
    required double spacing,
    double angleDegrees = 45,
    double phase = 0,
  }) {
    if (spacing <= 0) {
      throw ArgumentError.value(spacing, 'spacing', 'must be > 0');
    }
    if (contours.isEmpty) return const [];

    final angle = angleDegrees * math.pi / 180;
    final cosA = math.cos(-angle);
    final sinA = math.sin(-angle);

    Point2 rotate(Point2 p) => Point2(
          p.x * cosA - p.y * sinA,
          p.x * sinA + p.y * cosA,
        );

    final rotated = <List<Point2>>[];
    var minY = double.infinity;
    var maxY = double.negativeInfinity;
    for (final contour in contours) {
      if (contour.points.length < 3) continue;
      final points = [for (final p in contour.points) rotate(p)];
      rotated.add(points);
      for (final p in points) {
        minY = math.min(minY, p.y);
        maxY = math.max(maxY, p.y);
      }
    }
    if (rotated.isEmpty || !minY.isFinite || !maxY.isFinite) return const [];

    final normalizedPhase = ((phase % spacing) + spacing) % spacing;
    var y = minY + normalizedPhase;
    if (y < minY + epsilon) y += spacing;

    final result = <InfillSegment>[];
    for (; y < maxY - epsilon; y += spacing) {
      final intersections = <double>[];
      for (final polygon in rotated) {
        for (var i = 0; i < polygon.length; i++) {
          final a = polygon[i];
          final b = polygon[(i + 1) % polygon.length];
          if ((a.y - b.y).abs() <= epsilon) continue;

          final crosses = (a.y <= y && b.y > y) || (b.y <= y && a.y > y);
          if (!crosses) continue;
          final t = (y - a.y) / (b.y - a.y);
          intersections.add(a.x + (b.x - a.x) * t);
        }
      }

      intersections.sort();
      for (var i = 0; i + 1 < intersections.length; i += 2) {
        final x0 = intersections[i];
        final x1 = intersections[i + 1];
        if (x1 - x0 <= epsilon) continue;
        result.add(InfillSegment(
          _rotateBack(Point2(x0, y), angle),
          _rotateBack(Point2(x1, y), angle),
        ));
      }
    }
    return List.unmodifiable(result);
  }

  Point2 _rotateBack(Point2 p, double angle) {
    final c = math.cos(angle);
    final s = math.sin(angle);
    return Point2(p.x * c - p.y * s, p.x * s + p.y * c);
  }
}
