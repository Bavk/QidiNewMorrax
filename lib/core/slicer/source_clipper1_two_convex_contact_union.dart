import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';

/// Exact pinned Clipper1 `ctUnion` + `pftNonZero` subset for two positive,
/// strictly convex triangles whose interiors are disjoint and whose boundaries
/// meet only through a represented zero-area contact.
///
/// The triangle restriction is intentional. Direct raw-ELF audits found that
/// wider convex polygons can reach different `OutRec::Pts` states even for the
/// same geometric contact, so they stay on the compatibility seam.
///
/// Represented contacts are:
///
/// - exactly one point contact (vertex/vertex or vertex/edge), provided the two
///   source triangles have different bottom scanlines; Clipper1 keeps two
///   positive result contours in local-minimum creation order;
/// - one complete shared edge with opposite traversal;
/// - one shorter shared edge strictly inside a longer host edge when the host
///   edge runs toward increasing Y, or is horizontal.
///
/// Partial endpoint/staggered collinear joins are owned by the separate partial
/// helper. Host edges running toward decreasing Y for strict-contained joins,
/// mixed crossing/contact cases, fixup-created collinearity and wider convex
/// polygons remain outside this helper rather than extrapolating Clipper state.
class SourceClipper1TwoConvexContactUnion2 {
  const SourceClipper1TwoConvexContactUnion2._();

  static bool supports(Iterable<SourcePolygon2> polygons) =>
      _resultOrNull(List<SourcePolygon2>.of(polygons)) != null;

  static List<SourcePolygon2> unionAll(Iterable<SourcePolygon2> polygons) {
    final result = _resultOrNull(List<SourcePolygon2>.of(polygons));
    if (result == null) {
      throw ArgumentError(
        'Pinned two-triangle contact Clipper1 union subset does not apply',
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
    if (first.points.length != 3 || second.points.length != 3) return null;
    if (!_isStrictPositiveConvex(first) ||
        !_isStrictPositiveConvex(second)) {
      return null;
    }

    final touchPoints = <SourcePoint2>{};
    final overlaps = <_SharedEdgeContact2>[];

    for (var firstIndex = 0;
        firstIndex < first.points.length;
        firstIndex++) {
      final a = first.points[firstIndex];
      final b = first.points[(firstIndex + 1) % first.points.length];
      for (var secondIndex = 0;
          secondIndex < second.points.length;
          secondIndex++) {
        final c = second.points[secondIndex];
        final d = second.points[(secondIndex + 1) % second.points.length];

        if (_segmentsProperlyIntersect(a, b, c, d)) return null;

        if (_orientation(a, b, c) == 0 &&
            _orientation(a, b, d) == 0) {
          final common = _commonCollinearPoints(a, b, c, d);
          if (common.length >= 2 && common.first != common.last) {
            overlaps.add(
              _SharedEdgeContact2(
                firstEdgeIndex: firstIndex,
                secondEdgeIndex: secondIndex,
                firstStart: a,
                firstEnd: b,
                secondStart: c,
                secondEnd: d,
                overlapStart: common.first,
                overlapEnd: common.last,
              ),
            );
            touchPoints.add(common.first);
            touchPoints.add(common.last);
          } else if (common.isNotEmpty) {
            touchPoints.add(common.single);
          }
          continue;
        }

        _appendTouchPoint(a, b, c, touchPoints);
        _appendTouchPoint(a, b, d, touchPoints);
        _appendTouchPoint(c, d, a, touchPoints);
        _appendTouchPoint(c, d, b, touchPoints);
      }
    }

    if (touchPoints.isEmpty) return null;

    if (_hasStrictInteriorVertex(first, second) ||
        _hasStrictInteriorVertex(second, first)) {
      return null;
    }

    if (overlaps.isEmpty) {
      if (touchPoints.length != 1) return null;
      final firstBottomY = _maximumY(first);
      final secondBottomY = _maximumY(second);
      if (firstBottomY == secondBottomY) return null;
      final result = [
        _rebasePositiveTriangle(first),
        _rebasePositiveTriangle(second),
      ];
      result.sort(
        (a, b) => _maximumY(b).compareTo(_maximumY(a)),
      );
      return result;
    }

    if (overlaps.length != 1) return null;
    final contact = overlaps.single;
    if (touchPoints.any(
      (point) => !_onSegment(
        contact.overlapStart,
        contact.overlapEnd,
        point,
      ),
    )) {
      return null;
    }

    final firstDirectionX = contact.firstEnd.x - contact.firstStart.x;
    final firstDirectionY = contact.firstEnd.y - contact.firstStart.y;
    final secondDirectionX = contact.secondEnd.x - contact.secondStart.x;
    final secondDirectionY = contact.secondEnd.y - contact.secondStart.y;
    final directionDot = BigInt.from(firstDirectionX) *
            BigInt.from(secondDirectionX) +
        BigInt.from(firstDirectionY) * BigInt.from(secondDirectionY);
    if (directionDot >= BigInt.zero) return null;

    final firstContainsSecond =
        _onSegment(contact.firstStart, contact.firstEnd, contact.secondStart) &&
            _onSegment(
              contact.firstStart,
              contact.firstEnd,
              contact.secondEnd,
            );
    final secondContainsFirst =
        _onSegment(contact.secondStart, contact.secondEnd, contact.firstStart) &&
            _onSegment(
              contact.secondStart,
              contact.secondEnd,
              contact.firstEnd,
            );

    SourcePoint2 buildStart;
    if (firstContainsSecond && secondContainsFirst) {
      buildStart = _fullSharedEdgeBuildStart(
        contact.overlapStart,
        contact.overlapEnd,
      );
    } else {
      final _HostSharedEdge2 host;
      if (firstContainsSecond &&
          _strictlyInsideSegment(
            contact.firstStart,
            contact.firstEnd,
            contact.secondStart,
          ) &&
          _strictlyInsideSegment(
            contact.firstStart,
            contact.firstEnd,
            contact.secondEnd,
          )) {
        host = _HostSharedEdge2(
          polygon: first,
          edgeIndex: contact.firstEdgeIndex,
          edgeStart: contact.firstStart,
          edgeEnd: contact.firstEnd,
          guestStart: contact.secondStart,
          guestEnd: contact.secondEnd,
        );
      } else if (secondContainsFirst &&
          _strictlyInsideSegment(
            contact.secondStart,
            contact.secondEnd,
            contact.firstStart,
          ) &&
          _strictlyInsideSegment(
            contact.secondStart,
            contact.secondEnd,
            contact.firstEnd,
          )) {
        host = _HostSharedEdge2(
          polygon: second,
          edgeIndex: contact.secondEdgeIndex,
          edgeStart: contact.secondStart,
          edgeEnd: contact.secondEnd,
          guestStart: contact.firstStart,
          guestEnd: contact.firstEnd,
        );
      } else {
        return null;
      }

      final dy = host.edgeEnd.y - host.edgeStart.y;
      if (dy < 0) return null;
      buildStart = _strictContainedBuildStart(host);
    }

    final boundary = <_DirectedEdge2>[];
    _appendBoundaryWithoutSharedInterval(
      first,
      contact.overlapStart,
      contact.overlapEnd,
      boundary,
    );
    _appendBoundaryWithoutSharedInterval(
      second,
      contact.overlapStart,
      contact.overlapEnd,
      boundary,
    );
    final cycle = _buildSingleCycle(boundary);
    if (cycle == null || cycle.length < 3 || _needsFixup(cycle)) return null;
    final startIndex = cycle.indexOf(buildStart);
    if (startIndex < 0) return null;
    final result = SourcePolygon2(_rotated(cycle, startIndex));
    if (result.signedArea <= 0) return null;
    return [result];
  }

  static int _maximumY(SourcePolygon2 polygon) => polygon.points
      .map((point) => point.y)
      .reduce((a, b) => a > b ? a : b);

  static SourcePolygon2 _rebasePositiveTriangle(SourcePolygon2 polygon) {
    final start = _triangleBuildStart(polygon);
    return SourcePolygon2(
      _rotated(polygon.points, polygon.points.indexOf(start)),
    );
  }

  /// Exact standalone positive-triangle `BuildResult()` start derived from the
  /// pinned Clipper edge-list state and checked against 1100 raw ELF triangles.
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

  static SourcePoint2 _strictContainedBuildStart(_HostSharedEdge2 host) {
    final ordered = _sortAlongEdge(
      [host.guestStart, host.guestEnd],
      host.edgeStart,
      host.edgeEnd,
    );
    final towardEnd = ordered.last;
    final dx = host.edgeEnd.x - host.edgeStart.x;
    final dy = host.edgeEnd.y - host.edgeStart.y;

    if (dy == 0 && dx > 0) return towardEnd;
    return host.polygon.points[
        (host.edgeIndex - 1 + host.polygon.points.length) %
            host.polygon.points.length];
  }

  static SourcePoint2 _fullSharedEdgeBuildStart(
    SourcePoint2 first,
    SourcePoint2 second,
  ) {
    if (first.y < second.y) return first;
    if (second.y < first.y) return second;
    return first.x >= second.x ? first : second;
  }

  static void _appendBoundaryWithoutSharedInterval(
    SourcePolygon2 polygon,
    SourcePoint2 overlapStart,
    SourcePoint2 overlapEnd,
    List<_DirectedEdge2> output,
  ) {
    for (var index = 0; index < polygon.points.length; index++) {
      final start = polygon.points[index];
      final end = polygon.points[(index + 1) % polygon.points.length];
      final split = <SourcePoint2>[start, end];
      if (_strictlyInsideSegment(start, end, overlapStart)) {
        split.add(overlapStart);
      }
      if (_strictlyInsideSegment(start, end, overlapEnd)) {
        split.add(overlapEnd);
      }
      final ordered = _sortAlongEdge(split, start, end);
      for (var splitIndex = 0;
          splitIndex + 1 < ordered.length;
          splitIndex++) {
        final a = ordered[splitIndex];
        final b = ordered[splitIndex + 1];
        if (_onSegment(overlapStart, overlapEnd, a) &&
            _onSegment(overlapStart, overlapEnd, b)) {
          continue;
        }
        output.add(_DirectedEdge2(a, b));
      }
    }
  }

  static List<SourcePoint2>? _buildSingleCycle(List<_DirectedEdge2> edges) {
    if (edges.length < 3) return null;
    final byStart = <SourcePoint2, SourcePoint2>{};
    final incoming = <SourcePoint2, int>{};
    for (final edge in edges) {
      if (edge.start == edge.end) return null;
      final previous = byStart[edge.start];
      if (previous != null && previous != edge.end) return null;
      byStart[edge.start] = edge.end;
      incoming.update(edge.end, (value) => value + 1, ifAbsent: () => 1);
    }
    if (byStart.length != edges.length ||
        byStart.keys.any((point) => incoming[point] != 1) ||
        incoming.keys.any((point) => !byStart.containsKey(point))) {
      return null;
    }

    final start = edges.first.start;
    final output = <SourcePoint2>[];
    final visited = <SourcePoint2>{};
    var current = start;
    while (visited.add(current)) {
      output.add(current);
      final next = byStart[current];
      if (next == null) return null;
      current = next;
      if (current == start) break;
      if (output.length > edges.length) return null;
    }
    if (current != start || output.length != edges.length) return null;
    return output;
  }

  static bool _needsFixup(List<SourcePoint2> cycle) {
    for (var index = 0; index < cycle.length; index++) {
      final previous = cycle[(index - 1 + cycle.length) % cycle.length];
      final point = cycle[index];
      final next = cycle[(index + 1) % cycle.length];
      if (point == previous || point == next) return true;
      if (_orientation(previous, point, next) == 0) return true;
    }
    return false;
  }

  static bool _hasStrictInteriorVertex(
    SourcePolygon2 source,
    SourcePolygon2 other,
  ) =>
      source.points.any((point) => _locateInConvex(point, other) == 1);

  /// -1 outside, 0 boundary, +1 strict interior.
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
    if (common.length <= 1) return common;
    return _sortAlongEdge(common, a, b);
  }

  static List<SourcePoint2> _sortAlongEdge(
    List<SourcePoint2> points,
    SourcePoint2 start,
    SourcePoint2 end,
  ) {
    final unique = <SourcePoint2>[];
    final seen = <SourcePoint2>{};
    for (final point in points) {
      if (seen.add(point)) unique.add(point);
    }
    final dx = BigInt.from(end.x - start.x);
    final dy = BigInt.from(end.y - start.y);
    BigInt position(SourcePoint2 point) =>
        BigInt.from(point.x - start.x) * dx +
        BigInt.from(point.y - start.y) * dy;
    unique.sort(
      (first, second) => position(first).compareTo(position(second)),
    );
    return unique;
  }

  static bool _strictlyInsideSegment(
    SourcePoint2 start,
    SourcePoint2 end,
    SourcePoint2 point,
  ) =>
      point != start && point != end && _onSegment(start, end, point);

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
    return abC * abD < 0 && cdA * cdB < 0;
  }

  static bool _isStrictPositiveConvex(SourcePolygon2 polygon) {
    if (polygon.points.length < 3 || polygon.signedArea <= 0) return false;
    for (var index = 0; index < polygon.points.length; index++) {
      final previous = polygon.points[
          (index - 1 + polygon.points.length) % polygon.points.length];
      final point = polygon.points[index];
      final next = polygon.points[(index + 1) % polygon.points.length];
      if (_orientation(previous, point, next) <= 0) return false;
    }
    return true;
  }

  static int _orientation(SourcePoint2 a, SourcePoint2 b, SourcePoint2 c) {
    final cross = BigInt.from(b.x - a.x) * BigInt.from(c.y - a.y) -
        BigInt.from(b.y - a.y) * BigInt.from(c.x - a.x);
    return cross.sign;
  }

  static bool _onSegment(SourcePoint2 a, SourcePoint2 b, SourcePoint2 point) {
    if (_orientation(a, b, point) != 0) return false;
    final minX = a.x < b.x ? a.x : b.x;
    final maxX = a.x > b.x ? a.x : b.x;
    final minY = a.y < b.y ? a.y : b.y;
    final maxY = a.y > b.y ? a.y : b.y;
    return point.x >= minX &&
        point.x <= maxX &&
        point.y >= minY &&
        point.y <= maxY;
  }

  static List<SourcePoint2> _rotated(
    List<SourcePoint2> points,
    int start,
  ) =>
      List<SourcePoint2>.generate(
        points.length,
        (index) => points[(start + index) % points.length],
        growable: false,
      );
}

class _SharedEdgeContact2 {
  const _SharedEdgeContact2({
    required this.firstEdgeIndex,
    required this.secondEdgeIndex,
    required this.firstStart,
    required this.firstEnd,
    required this.secondStart,
    required this.secondEnd,
    required this.overlapStart,
    required this.overlapEnd,
  });

  final int firstEdgeIndex;
  final int secondEdgeIndex;
  final SourcePoint2 firstStart;
  final SourcePoint2 firstEnd;
  final SourcePoint2 secondStart;
  final SourcePoint2 secondEnd;
  final SourcePoint2 overlapStart;
  final SourcePoint2 overlapEnd;
}

class _HostSharedEdge2 {
  const _HostSharedEdge2({
    required this.polygon,
    required this.edgeIndex,
    required this.edgeStart,
    required this.edgeEnd,
    required this.guestStart,
    required this.guestEnd,
  });

  final SourcePolygon2 polygon;
  final int edgeIndex;
  final SourcePoint2 edgeStart;
  final SourcePoint2 edgeEnd;
  final SourcePoint2 guestStart;
  final SourcePoint2 guestEnd;
}

class _DirectedEdge2 {
  const _DirectedEdge2(this.start, this.end);

  final SourcePoint2 start;
  final SourcePoint2 end;
}
