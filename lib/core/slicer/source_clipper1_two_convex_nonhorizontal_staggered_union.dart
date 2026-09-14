import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';

/// Exact pinned Clipper1 `ctUnion` + `pftNonZero` subset for a non-horizontal
/// staggered collinear contact between two positive strict-convex triangles.
///
/// The two source edges overlap over a nonzero interval, traverse that interval
/// in opposite directions, and neither source edge contains the other. The
/// merged contour must not require `FixupOutPolygon()` duplicate/collinear
/// cleanup.
///
/// Direct raw BambuStudio ELF differentials establish one source-state rule for
/// both positive- and negative-slope support lines. Canonicalize to the shared
/// source edge whose `dy > 0`:
///
/// - if that edge's start lies strictly inside the opposite edge, the raw
///   `BuildResult()` start is that triangle's third vertex;
/// - otherwise its end lies strictly inside the opposite edge. If the owning
///   triangle's third vertex is above the edge end, start at the edge start; if
///   it is below, start at the opposite triangle's third vertex;
/// - if those Y values tie, start at the opposite edge end when the canonical
///   edge start is above the opposite third vertex, otherwise at the opposite
///   edge start.
///
/// Inputs remain triangles because wider-convex output-list state is not yet
/// independently proved.
class SourceClipper1TwoConvexNonHorizontalStaggeredUnion2 {
  const SourceClipper1TwoConvexNonHorizontalStaggeredUnion2._();

  static bool supports(Iterable<SourcePolygon2> polygons) =>
      _resultOrNull(List<SourcePolygon2>.of(polygons)) != null;

  static SourcePolygon2 union(Iterable<SourcePolygon2> polygons) {
    final result = _resultOrNull(List<SourcePolygon2>.of(polygons));
    if (result == null) {
      throw ArgumentError(
        'Pinned non-horizontal staggered two-triangle Clipper1 union subset does not apply',
      );
    }
    return result;
  }

  static SourcePolygon2? _resultOrNull(List<SourcePolygon2> polygons) {
    if (polygons.length != 2) return null;
    final first = polygons[0];
    final second = polygons[1];
    if (!_isStrictPositiveTriangle(first) ||
        !_isStrictPositiveTriangle(second)) {
      return null;
    }

    final touchPoints = <SourcePoint2>{};
    final overlaps = <_SharedEdgeContact2>[];
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

    if (overlaps.length != 1) return null;
    final contact = overlaps.single;
    if (contact.firstStart.y == contact.firstEnd.y ||
        contact.secondStart.y == contact.secondEnd.y) {
      return null;
    }
    if (touchPoints.any(
      (point) => !_onSegment(
        contact.overlapStart,
        contact.overlapEnd,
        point,
      ),
    )) {
      return null;
    }
    if (_hasStrictInteriorVertex(first, second) ||
        _hasStrictInteriorVertex(second, first)) {
      return null;
    }

    final firstDx = contact.firstEnd.x - contact.firstStart.x;
    final firstDy = contact.firstEnd.y - contact.firstStart.y;
    final secondDx = contact.secondEnd.x - contact.secondStart.x;
    final secondDy = contact.secondEnd.y - contact.secondStart.y;
    final directionDot = BigInt.from(firstDx) * BigInt.from(secondDx) +
        BigInt.from(firstDy) * BigInt.from(secondDy);
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
    if (firstContainsSecond || secondContainsFirst) return null;

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

    final candidates = <_CanonicalSharedEdge2>[
      _CanonicalSharedEdge2(
        polygon: first,
        edgeIndex: contact.firstEdgeIndex,
        start: contact.firstStart,
        end: contact.firstEnd,
        otherPolygon: second,
        otherEdgeIndex: contact.secondEdgeIndex,
        otherStart: contact.secondStart,
        otherEnd: contact.secondEnd,
      ),
      _CanonicalSharedEdge2(
        polygon: second,
        edgeIndex: contact.secondEdgeIndex,
        start: contact.secondStart,
        end: contact.secondEnd,
        otherPolygon: first,
        otherEdgeIndex: contact.firstEdgeIndex,
        otherStart: contact.firstStart,
        otherEnd: contact.firstEnd,
      ),
    ].where((edge) => edge.end.y > edge.start.y).toList();
    if (candidates.length != 1) return null;
    final edge = candidates.single;

    final startInsideOther =
        _strictlyInsideSegment(edge.otherStart, edge.otherEnd, edge.start);
    final endInsideOther =
        _strictlyInsideSegment(edge.otherStart, edge.otherEnd, edge.end);
    if (startInsideOther == endInsideOther) return null;

    final third = edge.polygon.points[(edge.edgeIndex + 2) % 3];
    final otherThird =
        edge.otherPolygon.points[(edge.otherEdgeIndex + 2) % 3];

    SourcePoint2 buildStart;
    if (startInsideOther) {
      buildStart = third;
    } else if (third.y < edge.end.y) {
      buildStart = edge.start;
    } else if (third.y > edge.end.y) {
      buildStart = otherThird;
    } else {
      buildStart = edge.start.y < otherThird.y
          ? edge.otherEnd
          : edge.otherStart;
    }

    final startIndex = cycle.indexOf(buildStart);
    if (startIndex < 0) return null;
    final result = SourcePolygon2(_rotated(cycle, startIndex));
    if (result.signedArea <= 0) return null;
    return result;
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

  static bool _isStrictPositiveTriangle(SourcePolygon2 polygon) {
    if (polygon.points.length != 3 || polygon.signedArea <= 0) return false;
    for (var index = 0; index < 3; index++) {
      final previous = polygon.points[(index + 2) % 3];
      final point = polygon.points[index];
      final next = polygon.points[(index + 1) % 3];
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

class _CanonicalSharedEdge2 {
  const _CanonicalSharedEdge2({
    required this.polygon,
    required this.edgeIndex,
    required this.start,
    required this.end,
    required this.otherPolygon,
    required this.otherEdgeIndex,
    required this.otherStart,
    required this.otherEnd,
  });

  final SourcePolygon2 polygon;
  final int edgeIndex;
  final SourcePoint2 start;
  final SourcePoint2 end;
  final SourcePolygon2 otherPolygon;
  final int otherEdgeIndex;
  final SourcePoint2 otherStart;
  final SourcePoint2 otherEnd;
}

class _DirectedEdge2 {
  const _DirectedEdge2(this.start, this.end);

  final SourcePoint2 start;
  final SourcePoint2 end;
}
