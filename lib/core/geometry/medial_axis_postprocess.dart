import 'dart:math' as math;

import 'source_geometry.dart';
import 'source_polygon.dart';
import 'thick_polyline.dart';

/// Exact post-processing stage from `ExPolygon::medial_axis()` after the raw
/// Voronoi `Geometry::MedialAxis::build()` result has been produced.
///
/// All coordinates/widths remain in the original scaled source coordinate
/// domain. This matters because the C++ implementation casts temporary Voronoi
/// extension lines back to integer `coord_t` before contour intersection.
class MedialAxisPostProcessor {
  const MedialAxisPostProcessor();

  List<ThickPolyline2> process({
    required SourceExPolygon2 expolygon,
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
          !expolygon.onBoundary(
            newFront,
            Slic3rUnits.scaledEpsilon.toDouble(),
          )) {
        var p1x = polyline.points.first.x.toDouble();
        var p1y = polyline.points.first.y.toDouble();
        var p2x = polyline.points[1].x.toDouble();
        var p2y = polyline.points[1].y.toDouble();
        if (polyline.points.length == 2) {
          p2x = (p1x + p2x) * 0.5;
          p2y = (p1y + p2y) * 0.5;
        }
        final dx = p2x - p1x;
        final dy = p2y - p1y;
        final len = math.sqrt(dx * dx + dy * dy);
        if (len > 0) {
          p1x -= dx / len * maxWidth;
          p1y -= dy / len * maxWidth;
          final hit = expolygon.contour.intersection(
            SourceLine2(
              _truncatedPoint(p1x, p1y),
              _truncatedPoint(p2x, p2y),
            ),
          );
          if (hit != null) newFront = hit;
        }
      }

      if (polyline.endIsEndpoint &&
          !expolygon.onBoundary(
            newBack,
            Slic3rUnits.scaledEpsilon.toDouble(),
          )) {
        var p1x = polyline.points[polyline.points.length - 2].x.toDouble();
        var p1y = polyline.points[polyline.points.length - 2].y.toDouble();
        var p2x = polyline.points.last.x.toDouble();
        var p2y = polyline.points.last.y.toDouble();
        if (polyline.points.length == 2) {
          p1x = (p1x + p2x) * 0.5;
          p1y = (p1y + p2y) * 0.5;
        }
        final dx = p2x - p1x;
        final dy = p2y - p1y;
        final len = math.sqrt(dx * dx + dy * dy);
        if (len > 0) {
          p2x += dx / len * maxWidth;
          p2y += dy / len * maxWidth;
          final hit = expolygon.contour.intersection(
            SourceLine2(
              _truncatedPoint(p1x, p1y),
              _truncatedPoint(p2x, p2y),
            ),
          );
          if (hit != null) newBack = hit;
        }
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
          if (polyline.lastPoint == other.lastPoint) {
            other.reverse();
          } else if (polyline.firstPoint == other.lastPoint) {
            polyline.reverse();
            other.reverse();
          } else if (polyline.firstPoint == other.firstPoint) {
            polyline.reverse();
          } else if (polyline.lastPoint != other.firstPoint) {
            j++;
            continue;
          }

          polyline.appendContinuation(other);
          pp.removeAt(j);
          // C++ assigns j=i and the for-loop increment restarts at i+1.
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

  SourcePoint2 _truncatedPoint(double x, double y) =>
      SourcePoint2(x.truncate(), y.truncate());
}
