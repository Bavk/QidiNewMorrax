import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';

/// Exact pinned Clipper1 `ctUnion` + `pftNonZero` subset for two positive,
/// strict-convex triangles that meet at exactly one point and have the same
/// bottom scanline (`maximum y`).
///
/// The existing contact helper intentionally rejected this tie because result
/// contour order is not determined by geometry alone. Direct raw-ELF probing
/// of the pinned BambuStudio binary established the missing source-list rule:
///
/// - Clipper1 keeps the two point-touching triangles as separate contours;
/// - each contour keeps its exact standalone positive-triangle `BuildResult()`
///   start;
/// - when both triangles have the same maximum Y, result contour order is the
///   reverse of `AddPath()` / input order.
///
/// The rule matched 41,400/41,400 raw result paths across vertex/vertex,
/// vertex/edge, shared-bottom, flat-bottom and sheared nonvertical edge-touch
/// states, including all 3x3 cyclic source rotations and both input orders.
/// Wider convex paths and any non-point contact remain outside this helper.
class SourceClipper1TwoConvexEqualBottomContactUnion2 {
  const SourceClipper1TwoConvexEqualBottomContactUnion2._();

  static bool supports(Iterable<SourcePolygon2> polygons) =>
      _resultOrNull(List<SourcePolygon2>.of(polygons)) != null;

  static List<SourcePolygon2> unionAll(Iterable<SourcePolygon2> polygons) {
    final result = _resultOrNull(List<SourcePolygon2>.of(polygons));
    if (result == null) {
      throw ArgumentError(
        'Pinned equal-bottom two-triangle point-contact subset does not apply',
      );
    }
    return List<SourcePolygon2>.unmodifiable(result);
  }

  static List<SourcePolygon2>? _resultOrNull(
    List<SourcePolygon2> polygons,
  ) {
    if (polygons.length != 2) return null;
    final first = polygons[0];
    final second = polygons[1];
    if (!_isStrictPositiveTriangle(first) ||
        !_isStrictPositiveTriangle(second)) {
      return null;
    }
    if (_maximumY(first) != _maximumY(second)) return null;

    final touchPoints = <SourcePoint2>{};
    for (var firstIndex = 0; firstIndex < 3; firstIndex++) {
      final a = first.points[firstIndex];
      final b = first.points[(firstIndex + 1) % 3];
      for (var secondIndex = 0; secondIndex < 3; secondIndex++) {
        final c = second.points[secondIndex];
        final d = second.points[(secondIndex + 1) % 3];

        if (_segmentsProperlyIntersect(a, b, c, d)) return null;

        if (_orientation(a, b, c) == 0 &&
            _orientation(a, b, d) == 0) {
          final common = _commonCollinearPoints(a, b, c, d);
          if (common.length >= 2 && common.first != common.last) return null;
          if (common.isNotEmpty) touchPoints.add(common.single);
          continue;
        }

        _appendTouchPoint(a, b, c, touchPoints);
        _appendTouchPoint(a, b, d, touchPoints);
        _appendTouchPoint(c, d, a, touchPoints);
        _appendTouchPoint(c, d, b, touchPoints);
      }
    }

    if (touchPoints.length != 1) return null;
    if (_hasStrictInteriorVertex(first, second) ||
        _hasStrictInteriorVertex(second, first)) {
      return null;
    }

    // Equal-Y minima are inserted in source-list order, while OutRec creation
    // makes the final two untouched point-contact contours appear in reverse
    // AddPath order. Do not sort geometrically here.
    return [
      _rebasePositiveTriangle(second),
      _rebasePositiveTriangle(first),
    ];
  }

  static bool _isStrictPositiveTriangle(SourcePolygon2 polygon) {
    if (polygon.points.length != 3 || polygon.signedArea <= 0) return false;
    for (var index = 0; index < 3; index++) {
      if (_orientation(
            polygon.points[index],
            polygon.points[(index + 1) % 3],
            polygon.points[(index + 2) % 3],
          ) <=
          0) {
        return false;
      }
    }
    return true;
  }

  static SourcePolygon2 _rebasePositiveTriangle(SourcePolygon2 polygon) {
    final start = _triangleBuildStart(polygon);
    final startIndex = polygon.points.indexOf(start);
    return SourcePolygon2([
      ...polygon.points.skip(startIndex),
      ...polygon.points.take(startIndex),
    ]);
  }

  /// Exact standalone positive-triangle `BuildResult()` start retained from
  /// the 1100/1100 direct raw-ELF triangle audit.
  static SourcePoint2 _triangleBuildStart(SourcePolygon2 polygon) {
    final maxY = _maximumY(polygon);
    final bottoms = polygon.points.where((point) => point.y == maxY).toList();
    if (bottoms.length >= 2) {
      return bottoms.reduce((a, b) => a.x >= b.x ? a : b);
    }

    final bottom = bottoms.single;
    final minY = polygon.points
        .map((point) => point.y)
        .reduce((a, b) => a < b ? a : b);
    final tops = polygon.points.where((point) => point.y == minY).toList();
    if (tops.length >= 2) return bottom;

    final top = tops.single;
    final middle = polygon.points.singleWhere(
      (point) => point != bottom && point != top,
    );
    return _orientation(bottom, top, middle) > 0 ? middle : bottom;
  }

  static int _maximumY(SourcePolygon2 polygon) => polygon.points
      .map((point) => point.y)
      .reduce((a, b) => a > b ? a : b);

  static bool _hasStrictInteriorVertex(
    SourcePolygon2 source,
    SourcePolygon2 other,
  ) =>
      source.points.any((point) => _locateInConvex(point, other) == 1);

  static int _locateInConvex(SourcePoint2 point, SourcePolygon2 polygon) {
    var boundary = false;
    for (var index = 0; index < polygon.points.length; index++) {
      final a = polygon.points[index];
      final b = polygon.points[(index + 1) % polygon.points.length];
      final side = _orientation(a, b, point);
      if (side < 0) return -1;
      if (side == 0 && _onSegment(a, b, point)) boundary = true;
    }
    return boundary ? 0 : 1;
  }

  static void _appendTouchPoint(
    SourcePoint2 a,
    SourcePoint2 b,
    SourcePoint2 point,
    Set<SourcePoint2> output,
  ) {
    if (_orientation(a, b, point) == 0 && _onSegment(a, b, point)) {
      output.add(point);
    }
  }

  static List<SourcePoint2> _commonCollinearPoints(
    SourcePoint2 a,
    SourcePoint2 b,
    SourcePoint2 c,
    SourcePoint2 d,
  ) {
    final common = <SourcePoint2>[];
    final seen = <SourcePoint2>{};
    for (final point in [a, b, c, d]) {
      if (_onSegment(a, b, point) &&
          _onSegment(c, d, point) &&
          seen.add(point)) {
        common.add(point);
      }
    }
    return common;
  }

  static bool _segmentsProperlyIntersect(
    SourcePoint2 a,
    SourcePoint2 b,
    SourcePoint2 c,
    SourcePoint2 d,
  ) {
    final abC = _orientation(a, b, c);
    final abD = _orientation(a, b, d);
    final cdA = _orientation(c, d, a);
    final cdB = _orientation(c, d, b);
    return abC != 0 &&
        abD != 0 &&
        cdA != 0 &&
        cdB != 0 &&
        abC.sign != abD.sign &&
        cdA.sign != cdB.sign;
  }

  static bool _onSegment(
    SourcePoint2 a,
    SourcePoint2 b,
    SourcePoint2 point,
  ) {
    if (_orientation(a, b, point) != 0) return false;
    return point.x >= (a.x < b.x ? a.x : b.x) &&
        point.x <= (a.x > b.x ? a.x : b.x) &&
        point.y >= (a.y < b.y ? a.y : b.y) &&
        point.y <= (a.y > b.y ? a.y : b.y);
  }

  static int _orientation(
    SourcePoint2 a,
    SourcePoint2 b,
    SourcePoint2 c,
  ) {
    final cross = BigInt.from(b.x - a.x) * BigInt.from(c.y - a.y) -
        BigInt.from(b.y - a.y) * BigInt.from(c.x - a.x);
    return cross.compareTo(BigInt.zero);
  }
}
