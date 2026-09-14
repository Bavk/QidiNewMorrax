import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';

/// Exact pinned Clipper1 `ctUnion` + `pftNonZero` subset for two interacting
/// positive axis-aligned rectangles.
///
/// The resulting boundary is evaluated in the source integer domain. More
/// importantly, this helper preserves the topology-specific `BuildResult()`
/// order/start captured from the exact pinned BambuStudio ELF:
///
/// - horizontal same-span merge/touch -> lower-left;
/// - vertical same-span merge/touch -> lower-right;
/// - partial unequal edge contacts -> source scanline start for the exact
///   left/right or bottom/top interval topology;
/// - diagonal area overlap -> one of the four source scanline starts, selected
///   from the relative north/south and east/west rectangle positions;
/// - point-only contact -> two separate contours, north first, each rebased to
///   its top-right source `BuildResult()` start.
///
/// Input order does not affect these pinned results. Containment remains on the
/// represented noninteracting winding helper. General convex intersections,
/// holes and more than two interacting paths remain on the full Clipper1
/// boolean seam.
class SourceClipper1TwoRectangleUnion2 {
  const SourceClipper1TwoRectangleUnion2._();

  static bool supports(Iterable<SourcePolygon2> polygons) =>
      _unionOrNull(List<SourcePolygon2>.of(polygons)) != null;

  /// Returns every exact source result contour for the represented subset.
  ///
  /// Most represented interactions return one contour. Point-only contact is
  /// source-significant: Clipper1 keeps two separate positive contours.
  static List<SourcePolygon2> unionAll(Iterable<SourcePolygon2> polygons) {
    final result = _unionOrNull(List<SourcePolygon2>.of(polygons));
    if (result == null) {
      throw ArgumentError(
        'Pinned two-rectangle Clipper1 union subset does not apply',
      );
    }
    return List.unmodifiable(result);
  }

  /// Convenience accessor for represented interactions with exactly one result.
  static SourcePolygon2 union(Iterable<SourcePolygon2> polygons) {
    final result = unionAll(polygons);
    if (result.length != 1) {
      throw ArgumentError(
        'Pinned two-rectangle Clipper1 union produces multiple contours; '
        'use unionAll()',
      );
    }
    return result.single;
  }

  static List<SourcePolygon2>? _unionOrNull(List<SourcePolygon2> polygons) {
    if (polygons.length != 2) return null;
    final first = _Rect2.fromPolygon(polygons[0]);
    final second = _Rect2.fromPolygon(polygons[1]);
    if (first == null || second == null) return null;

    // Containment is already represented more generally by the noninteracting
    // winding helper, and keeping it there avoids claiming a second source-order
    // implementation for the same case.
    if (first.containsRect(second) || second.containsRect(first)) return null;

    final overlapMinX = first.minX > second.minX ? first.minX : second.minX;
    final overlapMaxX = first.maxX < second.maxX ? first.maxX : second.maxX;
    final overlapMinY = first.minY > second.minY ? first.minY : second.minY;
    final overlapMaxY = first.maxY < second.maxY ? first.maxY : second.maxY;
    final overlapX = overlapMaxX - overlapMinX;
    final overlapY = overlapMaxY - overlapMinY;
    if (overlapX < 0 || overlapY < 0) return null;

    if (overlapX == 0 && overlapY == 0) {
      return _pointContactResult(first, second);
    }

    SourcePoint2? sourceStart;
    if (first.minY == second.minY && first.maxY == second.maxY) {
      // Exact horizontal touch/overlap oracle.
      final minX = first.minX < second.minX ? first.minX : second.minX;
      sourceStart = SourcePoint2(minX, first.minY);
    } else if (first.minX == second.minX && first.maxX == second.maxX) {
      // Exact vertical touch/overlap oracle.
      final minY = first.minY < second.minY ? first.minY : second.minY;
      sourceStart = SourcePoint2(first.maxX, minY);
    } else if (overlapX == 0 && overlapY > 0) {
      sourceStart = _partialVerticalContactStart(first, second);
    } else if (overlapY == 0 && overlapX > 0) {
      sourceStart = _partialHorizontalContactStart(first, second);
    } else {
      // The represented diagonal oracles are area-overlap cases. Center-aligned
      // unequal-span intersections still remain on the general boolean seam.
      if (overlapX <= 0 || overlapY <= 0) return null;
      final firstCenterX2 = first.minX + first.maxX;
      final secondCenterX2 = second.minX + second.maxX;
      final firstCenterY2 = first.minY + first.maxY;
      final secondCenterY2 = second.minY + second.maxY;
      if (firstCenterX2 == secondCenterX2 || firstCenterY2 == secondCenterY2) {
        return null;
      }

      final south = firstCenterY2 < secondCenterY2 ? first : second;
      final north = identical(south, first) ? second : first;
      final southCenterX2 = south.minX + south.maxX;
      final northCenterX2 = north.minX + north.maxX;
      if (southCenterX2 < northCenterX2) {
        // South-west / north-east: exact scanline start is the south rect's
        // east edge at the north rect's south edge.
        sourceStart = SourcePoint2(south.maxX, north.minY);
      } else {
        // South-east / north-west: exact scanline start is the north-east
        // corner of the southern rectangle.
        sourceStart = SourcePoint2(south.maxX, south.maxY);
      }
    }
    if (sourceStart == null) return null;

    final xs = <int>{first.minX, first.maxX, second.minX, second.maxX}.toList()
      ..sort();
    final ys = <int>{first.minY, first.maxY, second.minY, second.maxY}.toList()
      ..sort();
    final edges = <_DirectedEdge2>[];

    for (var xIndex = 0; xIndex + 1 < xs.length; xIndex++) {
      final x0 = xs[xIndex];
      final x1 = xs[xIndex + 1];
      final midX = (x0 + x1) / 2.0;
      for (var yIndex = 0; yIndex + 1 < ys.length; yIndex++) {
        final y0 = ys[yIndex];
        final y1 = ys[yIndex + 1];
        final midY = (y0 + y1) / 2.0;
        if (!_insideEither(first, second, midX, midY)) continue;

        bool filled(double x, double y) => _insideEither(first, second, x, y);
        const probe = 0.25;
        if (!filled(midX, y0 - probe)) {
          edges.add(
            _DirectedEdge2(SourcePoint2(x0, y0), SourcePoint2(x1, y0)),
          );
        }
        if (!filled(x1 + probe, midY)) {
          edges.add(
            _DirectedEdge2(SourcePoint2(x1, y0), SourcePoint2(x1, y1)),
          );
        }
        if (!filled(midX, y1 + probe)) {
          edges.add(
            _DirectedEdge2(SourcePoint2(x1, y1), SourcePoint2(x0, y1)),
          );
        }
        if (!filled(x0 - probe, midY)) {
          edges.add(
            _DirectedEdge2(SourcePoint2(x0, y1), SourcePoint2(x0, y0)),
          );
        }
      }
    }

    final byStart = <SourcePoint2, List<_DirectedEdge2>>{};
    for (final edge in edges) {
      byStart.putIfAbsent(edge.start, () => <_DirectedEdge2>[]).add(edge);
    }
    if (byStart.values.any((entry) => entry.length != 1)) return null;
    final startEdges = byStart[sourceStart];
    if (startEdges == null || startEdges.length != 1) return null;

    final output = <SourcePoint2>[];
    var edge = startEdges.single;
    final seen = <String>{};
    while (true) {
      final key = '${edge.start.x},${edge.start.y}>${edge.end.x},${edge.end.y}';
      if (!seen.add(key)) return null;
      output.add(edge.start);
      if (edge.end == sourceStart) break;
      final next = byStart[edge.end];
      if (next == null || next.length != 1) return null;
      edge = next.single;
      if (output.length > edges.length) return null;
    }
    if (seen.length != edges.length) return null;

    final simplified = _removeCollinearKeepingStart(output);
    if (simplified.length < 4 || simplified.first != sourceStart) return null;
    final result = SourcePolygon2(simplified);
    return result.signedArea > 0 ? <SourcePolygon2>[result] : null;
  }

  static SourcePoint2? _partialVerticalContactStart(
    _Rect2 first,
    _Rect2 second,
  ) {
    late final _Rect2 left;
    late final _Rect2 right;
    if (first.maxX == second.minX) {
      left = first;
      right = second;
    } else if (second.maxX == first.minX) {
      left = second;
      right = first;
    } else {
      return null;
    }

    final overlapMinY = left.minY > right.minY ? left.minY : right.minY;
    final overlapMaxY = left.maxY < right.maxY ? left.maxY : right.maxY;
    if (overlapMaxY <= overlapMinY) return null;

    // Exact pinned scanline starts for unequal vertical edge contacts. These
    // three branches cover strict partial overlaps, interval containment and
    // one-endpoint-aligned T contacts.
    if (right.maxY == left.maxY) {
      return SourcePoint2(left.minX, left.minY);
    }
    if (right.maxY > left.maxY) {
      if (right.minY <= left.minY) {
        return SourcePoint2(right.maxX, right.maxY);
      }
      return SourcePoint2(left.maxX, right.minY);
    }
    return SourcePoint2(left.minX, left.maxY);
  }

  static SourcePoint2? _partialHorizontalContactStart(
    _Rect2 first,
    _Rect2 second,
  ) {
    late final _Rect2 bottom;
    late final _Rect2 top;
    if (first.maxY == second.minY) {
      bottom = first;
      top = second;
    } else if (second.maxY == first.minY) {
      bottom = second;
      top = first;
    } else {
      return null;
    }

    final overlapMinX = bottom.minX > top.minX ? bottom.minX : top.minX;
    final overlapMaxX = bottom.maxX < top.maxX ? bottom.maxX : top.maxX;
    if (overlapMaxX <= overlapMinX) return null;

    // Exact pinned scanline starts. A shared left edge or strict containment of
    // the bottom interval by the top interval starts at bottom-right; all other
    // unequal horizontal contacts start at bottom-left.
    final bottomInsideTop =
        top.minX < bottom.minX && bottom.maxX < top.maxX;
    if (bottom.minX == top.minX || bottomInsideTop) {
      return SourcePoint2(bottom.maxX, bottom.minY);
    }
    return SourcePoint2(bottom.minX, bottom.minY);
  }

  static List<SourcePolygon2>? _pointContactResult(
    _Rect2 first,
    _Rect2 second,
  ) {
    late final _Rect2 north;
    late final _Rect2 south;
    if (first.maxY == second.minY) {
      south = first;
      north = second;
    } else if (second.maxY == first.minY) {
      south = second;
      north = first;
    } else {
      return null;
    }

    final xTouches =
        south.maxX == north.minX || north.maxX == south.minX;
    if (!xTouches) return null;

    return <SourcePolygon2>[
      _buildResultRectangle(north),
      _buildResultRectangle(south),
    ];
  }

  static SourcePolygon2 _buildResultRectangle(_Rect2 rect) => SourcePolygon2([
        SourcePoint2(rect.maxX, rect.maxY),
        SourcePoint2(rect.minX, rect.maxY),
        SourcePoint2(rect.minX, rect.minY),
        SourcePoint2(rect.maxX, rect.minY),
      ]);

  static bool _insideEither(
    _Rect2 first,
    _Rect2 second,
    double x,
    double y,
  ) =>
      first.containsOpen(x, y) || second.containsOpen(x, y);

  static List<SourcePoint2> _removeCollinearKeepingStart(
    List<SourcePoint2> input,
  ) {
    var points = List<SourcePoint2>.of(input);
    var changed = true;
    while (changed && points.length > 3) {
      changed = false;
      final next = <SourcePoint2>[];
      for (var index = 0; index < points.length; index++) {
        final previous = points[(index - 1 + points.length) % points.length];
        final point = points[index];
        final following = points[(index + 1) % points.length];
        final isCollinear =
            (previous.x == point.x && point.x == following.x) ||
                (previous.y == point.y && point.y == following.y);
        if (isCollinear && index != 0) {
          changed = true;
          continue;
        }
        next.add(point);
      }
      points = next;
    }
    return points;
  }
}

class _Rect2 {
  const _Rect2(this.minX, this.minY, this.maxX, this.maxY);

  final int minX;
  final int minY;
  final int maxX;
  final int maxY;

  static _Rect2? fromPolygon(SourcePolygon2 polygon) {
    if (polygon.signedArea <= 0 || polygon.points.length != 4) return null;
    var minX = polygon.points.first.x;
    var maxX = minX;
    var minY = polygon.points.first.y;
    var maxY = minY;
    for (final point in polygon.points.skip(1)) {
      if (point.x < minX) minX = point.x;
      if (point.x > maxX) maxX = point.x;
      if (point.y < minY) minY = point.y;
      if (point.y > maxY) maxY = point.y;
    }
    if (minX == maxX || minY == maxY) return null;
    final expected = <SourcePoint2>{
      SourcePoint2(minX, minY),
      SourcePoint2(maxX, minY),
      SourcePoint2(maxX, maxY),
      SourcePoint2(minX, maxY),
    };
    if (polygon.points.toSet().length != 4 ||
        !polygon.points.every(expected.contains)) {
      return null;
    }
    return _Rect2(minX, minY, maxX, maxY);
  }

  bool containsRect(_Rect2 other) =>
      minX <= other.minX &&
      maxX >= other.maxX &&
      minY <= other.minY &&
      maxY >= other.maxY;

  bool containsOpen(double x, double y) =>
      x > minX && x < maxX && y > minY && y < maxY;
}

class _DirectedEdge2 {
  const _DirectedEdge2(this.start, this.end);

  final SourcePoint2 start;
  final SourcePoint2 end;
}
