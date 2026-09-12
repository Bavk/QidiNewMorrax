import 'dart:math' as math;

import 'expolygon.dart';
import 'point.dart';
import 'thick_polyline.dart';

/// Exact post-processing stage from `ExPolygon::medial_axis()` after the raw
/// Voronoi `Geometry::MedialAxis::build()` result has been produced.
///
/// Keeping this independent from the still-pending Voronoi builder lets the
/// source endpoint extension / pruning / reconnect logic be parity-tested on
/// its own instead of hiding it inside a substitute skeletonizer.
class MedialAxisPostProcessor {
  const MedialAxisPostProcessor();

  static const double epsilon = 1e-4;

  List<ThickPolyline2> process({
    required ExPolygon2 expolygon,
    required List<ThickPolyline2> rawPolylines,
    required double maxWidth,
  }) {
    final pp = [for (final p in rawPolylines) _copy(p)];
    if (pp.isEmpty) return const [];

    var maxReturnedWidth = 0.0;
    for (final polyline in pp) {
      for (final value in polyline.width) {
        maxReturnedWidth = math.max(maxReturnedWidth, value);
      }
    }

    var removed = false;
    var i = 0;
    while (i < pp.length) {
      final polyline = pp[i];
      if (polyline.points.length < 2) {
        pp.removeAt(i);
        removed = true;
        continue;
      }

      var newFront = polyline.points.first;
      var newBack = polyline.points.last;

      if (polyline.startIsEndpoint &&
          !_onBoundary(expolygon, newFront, epsilon)) {
        var p1 = polyline.points.first;
        var p2 = polyline.points[1];
        if (polyline.points.length == 2) {
          p2 = (p1 + p2) * 0.5;
        }
        final direction = (p2 - p1).normalized();
        p1 = p1 - direction * maxWidth;
        final intersection = _firstSegmentIntersectionWithContour(
          expolygon.contour.points,
          p1,
          p2,
        );
        if (intersection != null) newFront = intersection;
      }

      if (polyline.endIsEndpoint &&
          !_onBoundary(expolygon, newBack, epsilon)) {
        var p1 = polyline.points[polyline.points.length - 2];
        var p2 = polyline.points.last;
        if (polyline.points.length == 2) {
          p1 = (p1 + p2) * 0.5;
        }
        final direction = (p2 - p1).normalized();
        p2 = p2 + direction * maxWidth;
        final intersection = _firstSegmentIntersectionWithContour(
          expolygon.contour.points,
          p1,
          p2,
        );
        if (intersection != null) newBack = intersection;
      }

      polyline.points[0] = newFront;
      polyline.points[polyline.points.length - 1] = newBack;

      if ((polyline.startIsEndpoint || polyline.endIsEndpoint) &&
          polyline.length < maxReturnedWidth * 2) {
        pp.removeAt(i);
        removed = true;
        continue;
      }
      i++;
    }

    if (removed) {
      i = 0;
      while (i < pp.length) {
        final polyline = pp[i];
        if (polyline.startIsEndpoint && polyline.endIsEndpoint) {
          i++;
          continue;
        }

        var j = i + 1;
        while (j < pp.length) {
          final other = pp[j];
          if (_same(polyline.lastPoint, other.lastPoint)) {
            other.reverse();
          } else if (_same(polyline.firstPoint, other.lastPoint)) {
            polyline.reverse();
            other.reverse();
          } else if (_same(polyline.firstPoint, other.firstPoint)) {
            polyline.reverse();
          } else if (!_same(polyline.lastPoint, other.firstPoint)) {
            j++;
            continue;
          }

          polyline.appendContinuation(other);
          pp.removeAt(j);
          // Source does `j = i` and lets the loop increment restart from i+1.
          // Here resetting directly to i+1 has the same search order.
          j = i + 1;
        }
        i++;
      }
    }

    return List.unmodifiable(pp);
  }

  ThickPolyline2 _copy(ThickPolyline2 source) => ThickPolyline2(
        points: source.points,
        width: source.width,
        startIsEndpoint: source.startIsEndpoint,
        endIsEndpoint: source.endIsEndpoint,
      );

  bool _onBoundary(ExPolygon2 expolygon, Point2 point, double eps) {
    if (expolygon.contour.distanceToBoundary(point) < eps) return true;
    for (final hole in expolygon.holes) {
      if (hole.distanceToBoundary(point) < eps) return true;
    }
    return false;
  }

  Point2? _firstSegmentIntersectionWithContour(
    List<Point2> contour,
    Point2 lineA,
    Point2 lineB,
  ) {
    if (contour.length < 2) return null;

    // Preserve `Polygon::intersection()` ordering: explicit front/back edge
    // first, then [0,1], [1,2] ... .
    final closing = _segmentIntersection(
      contour.first,
      contour.last,
      lineA,
      lineB,
    );
    if (closing != null) return closing;

    for (var i = 1; i < contour.length; i++) {
      final hit = _segmentIntersection(
        contour[i - 1],
        contour[i],
        lineA,
        lineB,
      );
      if (hit != null) return hit;
    }
    return null;
  }

  Point2? _segmentIntersection(
    Point2 a,
    Point2 b,
    Point2 c,
    Point2 d,
  ) {
    final r = b - a;
    final s = d - c;
    final denominator = r.cross(s);
    final cMinusA = c - a;

    if (denominator.abs() < 1e-12) return null;
    final t = cMinusA.cross(s) / denominator;
    final u = cMinusA.cross(r) / denominator;
    if (t < 0 || t > 1 || u < 0 || u > 1) return null;
    return a + r * t;
  }

  static bool _same(Point2 a, Point2 b) => a.x == b.x && a.y == b.y;
}
