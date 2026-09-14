import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';

/// Exact pinned Clipper1 `ctUnion` + `pftNonZero` subset for two positive,
/// strictly convex triangles with a single partial collinear boundary contact.
///
/// This helper deliberately represents only join states that were captured
/// directly from the pinned BambuStudio ELF:
///
/// - endpoint-aligned partial overlap whose short edge reaches the *start* of
///   the longer host edge, for any host-edge slope;
/// - endpoint-aligned partial overlap whose short edge reaches the *end* of a
///   horizontal host edge;
/// - staggered horizontal overlap where neither source edge contains the other
///   and the merged contour has one unique minimum-Y vertex.
///
/// Both inputs are required to be triangles because the exact `BuildResult()`
/// start for wider convex polygons depends on additional Clipper output-list
/// state. Non-horizontal host-end joins, non-horizontal staggered joins, mixed
/// proper-crossing/contact cases and wider convex polygons stay on the full
/// compatibility seam rather than extrapolating the oracle.
class SourceClipper1TwoConvexPartialCollinearUnion2 {
  const SourceClipper1TwoConvexPartialCollinearUnion2._();

  static bool supports(Iterable<SourcePolygon2> polygons) =>
      _resultOrNull(List<SourcePolygon2>.of(polygons)) != null;

  static SourcePolygon2 union(Iterable<SourcePolygon2> polygons) {
    final result = _resultOrNull(List<SourcePolygon2>.of(polygons));
    if (result == null) {
      throw ArgumentError(
        'Pinned partial-collinear two-triangle Clipper1 union subset does not apply',
      );
    }
    return result;
  }

  static SourcePolygon2? _resultOrNull(List<SourcePolygon2> polygons) {
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

        // Mixed proper-crossing/contact topology is intentionally not owned by
        // this helper yet.
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
    if (touchPoints.any(
      (point) => !_onSegment(
        contact.overlapStart,
        contact.overlapEnd,
        point,
      ),
    )) {
      return null;
    }

    // With no proper crossings, a strict interior vertex would mean material
    // overlap or containment rather than the represented zero-area join.
    if (_hasStrictInteriorVertex(first, second) ||
        _hasStrictInteriorVertex(second, first)) {
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

    // A complete common edge is owned by the earlier contact helper.
    if (firstContainsSecond && secondContainsFirst) return null;

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
    if (cycle == null || cycle.length < 3) return null;

    SourcePoint2? buildStart;
    if (firstContainsSecond || secondContainsFirst) {
      final host = firstContainsSecond
          ? _HostSharedEdge2(
              polygon: first,
              edgeIndex: contact.firstEdgeIndex,
              edgeStart: contact.firstStart,
              edgeEnd: contact.firstEnd,
              guestPolygon: second,
              guestEdgeIndex: contact.secondEdgeIndex,
              guestStart: contact.secondStart,
              guestEnd: contact.secondEnd,
            )
          : _HostSharedEdge2(
              polygon: second,
              edgeIndex: contact.secondEdgeIndex,
              edgeStart: contact.secondStart,
              edgeEnd: contact.secondEnd,
              guestPolygon: first,
              guestEdgeIndex: contact.firstEdgeIndex,
              guestStart: contact.firstStart,
              guestEnd: contact.firstEnd,
            );

      final guestTouchesStart =
          host.guestStart == host.edgeStart || host.guestEnd == host.edgeStart;
      final guestTouchesEnd =
          host.guestStart == host.edgeEnd || host.guestEnd == host.edgeEnd;

      if (guestTouchesStart && !guestTouchesEnd) {
        final other = host.guestStart == host.edgeStart
            ? host.guestEnd
            : host.guestStart;
        if (!_strictlyInsideSegment(host.edgeStart, host.edgeEnd, other)) {
          return null;
        }
        buildStart = _hostStartAlignedBuildStart(host, other);
      } else if (guestTouchesEnd &&
          !guestTouchesStart &&
          host.edgeStart.y == host.edgeEnd.y) {
        final other = host.guestStart == host.edgeEnd
            ? host.guestEnd
            : host.guestStart;
        if (!_strictlyInsideSegment(host.edgeStart, host.edgeEnd, other)) {
          return null;
        }
        buildStart = _horizontalHostEndBuildStart(host);
      } else {
        // Strict-contained joins are owned by the earlier contact helper;
        // non-horizontal host-end joins remain unrepresented.
        return null;
      }
    } else {
      // Staggered overlap: only the directly probed horizontal state is
      // represented. The unique minimum-Y condition intentionally excludes
      // tie cases whose BuildResult rotation has not been derived yet.
      if (contact.firstStart.y != contact.firstEnd.y ||
          contact.secondStart.y != contact.secondEnd.y) {
        return null;
      }
      buildStart = _uniqueMinimumY(cycle);
      if (buildStart == null) return null;
    }

    final startIndex = cycle.indexOf(buildStart);
    if (startIndex < 0) return null;
    final result = SourcePolygon2(_rotated(cycle, startIndex));
    if (result.signedArea <= 0) return null;
    return result;
  }

  static SourcePoint2 _hostStartAlignedBuildStart(
    _HostSharedEdge2 host,
    SourcePoint2 interiorOverlapEnd,
  ) {
    final dx = host.edgeEnd.x - host.edgeStart.x;
    final dy = host.edgeEnd.y - host.edgeStart.y;

    // Direct ELF audit: 80/80 deterministic random triangle cases across all
    // edge quadrants matched this exact source-list branch. Downward host edges
    // and horizontal left-to-right keep the interior overlap endpoint; the
    // opposite scan direction keeps the host vertex preceding the shared edge.
    if (dy < 0 || (dy == 0 && dx > 0)) return interiorOverlapEnd;
    return host.polygon.points[
        (host.edgeIndex - 1 + host.polygon.points.length) %
            host.polygon.points.length];
  }

  static SourcePoint2 _horizontalHostEndBuildStart(_HostSharedEdge2 host) {
    final dx = host.edgeEnd.x - host.edgeStart.x;
    if (dx > 0) {
      return host.guestPolygon.points[
          (host.guestEdgeIndex - 1 + host.guestPolygon.points.length) %
              host.guestPolygon.points.length];
    }
    return host.edgeStart;
  }

  static SourcePoint2? _uniqueMinimumY(List<SourcePoint2> points) {
    var minimumY = points.first.y;
    for (final point in points.skip(1)) {
      if (point.y < minimumY) minimumY = point.y;
    }
    SourcePoint2? result;
    for (final point in points) {
      if (point.y != minimumY) continue;
      if (result != null) return null;
      result = point;
    }
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
    required this.guestPolygon,
    required this.guestEdgeIndex,
    required this.guestStart,
    required this.guestEnd,
  });

  final SourcePolygon2 polygon;
  final int edgeIndex;
  final SourcePoint2 edgeStart;
  final SourcePoint2 edgeEnd;
  final SourcePolygon2 guestPolygon;
  final int guestEdgeIndex;
  final SourcePoint2 guestStart;
  final SourcePoint2 guestEnd;
}

class _DirectedEdge2 {
  const _DirectedEdge2(this.start, this.end);

  final SourcePoint2 start;
  final SourcePoint2 end;
}
