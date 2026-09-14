import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';

/// Exact pinned Clipper1 `ctUnion` + `pftNonZero` subset for two positive,
/// strictly convex closed paths whose boundaries cross properly.
///
/// This is the first non-rectangular interacting subset. It deliberately
/// rejects containment, edge/point touching, collinear overlap and any rounded
/// intersection degeneracy so those cases stay on their independently proven
/// helpers or the explicit compatibility seam.
///
/// Proper crossings are rounded with the modified Clipper 6.2.9 scanline
/// arithmetic (`TopX()` / half-away `Round()`). Boundary fragments are then
/// selected by NonZero union winding. For this proper-convex topology the
/// pinned `FixupOutPolygon()` / `BuildResult()` start is the CCW successor of
/// the rightmost minimum-Y result vertex. A direct ELF oracle matrix covers
/// triangle, diamond, trapezoid, pentagon and mixed 2/4/6-crossing cases.
class SourceClipper1TwoConvexUnion2 {
  const SourceClipper1TwoConvexUnion2._();

  static bool supports(Iterable<SourcePolygon2> polygons) =>
      _unionOrNull(List<SourcePolygon2>.of(polygons)) != null;

  static SourcePolygon2 union(Iterable<SourcePolygon2> polygons) {
    final result = _unionOrNull(List<SourcePolygon2>.of(polygons));
    if (result == null) {
      throw ArgumentError(
        'Pinned two-convex-path Clipper1 union subset does not apply',
      );
    }
    return result;
  }

  static SourcePolygon2? _unionOrNull(List<SourcePolygon2> polygons) {
    if (polygons.length != 2) return null;
    final first = polygons[0];
    final second = polygons[1];
    if (!_isStrictPositiveConvex(first) ||
        !_isStrictPositiveConvex(second)) {
      return null;
    }

    final firstSplits = List<List<SourcePoint2>>.generate(
      first.points.length,
      (index) => <SourcePoint2>[
        first.points[index],
        first.points[(index + 1) % first.points.length],
      ],
    );
    final secondSplits = List<List<SourcePoint2>>.generate(
      second.points.length,
      (index) => <SourcePoint2>[
        second.points[index],
        second.points[(index + 1) % second.points.length],
      ],
    );

    final intersectionPoints = <SourcePoint2>{};
    var intersectionCount = 0;
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

        if (_segmentsTouchOrOverlap(a, b, c, d)) return null;
        if (!_segmentsProperlyIntersect(a, b, c, d)) continue;

        final point = _clipperIntersection(a, b, c, d);
        if (point == null ||
            point == a ||
            point == b ||
            point == c ||
            point == d ||
            !intersectionPoints.add(point)) {
          return null;
        }
        intersectionCount++;
        firstSplits[firstIndex].add(point);
        secondSplits[secondIndex].add(point);
      }
    }

    if (intersectionCount < 2 || intersectionCount.isOdd) return null;

    final boundary = <_DirectedEdge2>[];
    if (!_appendOutsideFragments(first, second, firstSplits, boundary) ||
        !_appendOutsideFragments(second, first, secondSplits, boundary)) {
      return null;
    }
    if (boundary.length < 3) return null;

    final cycle = _buildSingleCycle(boundary);
    if (cycle == null) return null;
    final simplified = _removeClipperCollinear(cycle);
    if (simplified.length < 3) return null;

    final polygon = SourcePolygon2(simplified);
    if (polygon.signedArea <= 0) return null;

    final rebased = _rebaseBuildResult(simplified);
    return rebased == null ? null : SourcePolygon2(rebased);
  }

  static bool _appendOutsideFragments(
    SourcePolygon2 source,
    SourcePolygon2 other,
    List<List<SourcePoint2>> splits,
    List<_DirectedEdge2> output,
  ) {
    for (var index = 0; index < source.points.length; index++) {
      final start = source.points[index];
      final end = source.points[(index + 1) % source.points.length];
      final points = _sortAlongEdge(splits[index], start, end);
      for (var pointIndex = 0;
          pointIndex + 1 < points.length;
          pointIndex++) {
        final a = points[pointIndex];
        final b = points[pointIndex + 1];
        if (a == b) return false;
        final inside = _midpointStrictlyInsideConvex(a, b, other);
        if (inside == null) return false;
        if (!inside) output.add(_DirectedEdge2(a, b));
      }
    }
    return true;
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
    unique.sort((first, second) =>
        position(first).compareTo(position(second)));
    return unique;
  }

  /// Returns null when rounding makes a tested fragment land on the other
  /// boundary. That topology stays outside this exact subset.
  static bool? _midpointStrictlyInsideConvex(
    SourcePoint2 first,
    SourcePoint2 second,
    SourcePolygon2 polygon,
  ) {
    final midpointX2 = BigInt.from(first.x + second.x);
    final midpointY2 = BigInt.from(first.y + second.y);
    var onBoundary = false;
    for (var index = 0; index < polygon.points.length; index++) {
      final a = polygon.points[index];
      final b = polygon.points[(index + 1) % polygon.points.length];
      final cross = BigInt.from(b.x - a.x) *
              (midpointY2 - BigInt.from(a.y * 2)) -
          BigInt.from(b.y - a.y) *
              (midpointX2 - BigInt.from(a.x * 2));
      if (cross < BigInt.zero) return false;
      if (cross == BigInt.zero) onBoundary = true;
    }
    return onBoundary ? null : true;
  }

  static List<SourcePoint2>? _buildSingleCycle(
    List<_DirectedEdge2> edges,
  ) {
    final byStart = <SourcePoint2, SourcePoint2>{};
    final incoming = <SourcePoint2, int>{};
    for (final edge in edges) {
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

  static List<SourcePoint2> _removeClipperCollinear(
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
        if (point == previous ||
            point == following ||
            _orientation(previous, point, following) == 0) {
          changed = true;
          continue;
        }
        next.add(point);
      }
      points = next;
    }
    return points;
  }

  static List<SourcePoint2>? _rebaseBuildResult(
    List<SourcePoint2> points,
  ) {
    var minimumY = points.first.y;
    for (final point in points.skip(1)) {
      if (point.y < minimumY) minimumY = point.y;
    }
    final minima = <int>[
      for (var index = 0; index < points.length; index++)
        if (points[index].y == minimumY) index,
    ];
    if (minima.length > 2) return null;
    if (minima.length == 2) {
      final first = minima[0];
      final second = minima[1];
      final adjacent =
          (first + 1) % points.length == second ||
          (second + 1) % points.length == first;
      if (!adjacent) return null;
    }

    var anchor = minima.first;
    for (final index in minima.skip(1)) {
      if (points[index].x > points[anchor].x) anchor = index;
    }
    final start = (anchor + 1) % points.length;
    return List<SourcePoint2>.generate(
      points.length,
      (index) => points[(start + index) % points.length],
      growable: false,
    );
  }

  static SourcePoint2? _clipperIntersection(
    SourcePoint2 a,
    SourcePoint2 b,
    SourcePoint2 c,
    SourcePoint2 d,
  ) {
    final first = _ClipperEdge2.fromSegment(a, b);
    final second = _ClipperEdge2.fromSegment(c, d);

    int x;
    int y;
    if (first.isHorizontal) {
      y = first.bot.y;
      x = second.topX(y);
    } else if (second.isHorizontal) {
      y = second.bot.y;
      x = first.topX(y);
    } else if (first.dx == second.dx) {
      return null;
    } else if (first.deltaX == 0) {
      x = first.bot.x;
      final intercept = second.bot.y - second.bot.x / second.dx;
      y = _clipperRound(x / second.dx + intercept);
    } else if (second.deltaX == 0) {
      x = second.bot.x;
      final intercept = first.bot.y - first.bot.x / first.dx;
      y = _clipperRound(x / first.dx + intercept);
    } else {
      final interceptFirst = first.bot.x - first.bot.y * first.dx;
      final interceptSecond = second.bot.x - second.bot.y * second.dx;
      final q =
          (interceptSecond - interceptFirst) / (first.dx - second.dx);
      y = _clipperRound(q);
      x = first.dx.abs() < second.dx.abs()
          ? _clipperRound(first.dx * q + interceptFirst)
          : _clipperRound(second.dx * q + interceptSecond);
    }

    if (y < first.top.y || y < second.top.y) {
      y = first.top.y > second.top.y ? first.top.y : second.top.y;
      x = first.dx.abs() < second.dx.abs()
          ? first.topX(y)
          : second.topX(y);
    }
    if (y > first.bot.y || y > second.bot.y) return null;
    return SourcePoint2(x, y);
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

  static bool _segmentsTouchOrOverlap(
    SourcePoint2 a,
    SourcePoint2 b,
    SourcePoint2 c,
    SourcePoint2 d,
  ) {
    final abC = _orientation(a, b, c);
    final abD = _orientation(a, b, d);
    final cdA = _orientation(c, d, a);
    final cdB = _orientation(c, d, b);
    if (abC == 0 && _onSegment(a, b, c)) return true;
    if (abD == 0 && _onSegment(a, b, d)) return true;
    if (cdA == 0 && _onSegment(c, d, a)) return true;
    if (cdB == 0 && _onSegment(c, d, b)) return true;
    return false;
  }

  static int _orientation(SourcePoint2 a, SourcePoint2 b, SourcePoint2 c) {
    final cross = BigInt.from(b.x - a.x) * BigInt.from(c.y - a.y) -
        BigInt.from(b.y - a.y) * BigInt.from(c.x - a.x);
    return cross.sign;
  }

  static bool _onSegment(SourcePoint2 a, SourcePoint2 b, SourcePoint2 point) {
    final minX = a.x < b.x ? a.x : b.x;
    final maxX = a.x > b.x ? a.x : b.x;
    final minY = a.y < b.y ? a.y : b.y;
    final maxY = a.y > b.y ? a.y : b.y;
    return point.x >= minX &&
        point.x <= maxX &&
        point.y >= minY &&
        point.y <= maxY;
  }

  static int _clipperRound(double value) =>
      value < 0 ? (value - 0.5).ceil() : (value + 0.5).floor();
}

class _ClipperEdge2 {
  const _ClipperEdge2({
    required this.bot,
    required this.top,
    required this.deltaX,
    required this.dx,
    required this.isHorizontal,
  });

  factory _ClipperEdge2.fromSegment(SourcePoint2 first, SourcePoint2 second) {
    final bot = first.y >= second.y ? first : second;
    final top = identical(bot, first) ? second : first;
    final deltaX = top.x - bot.x;
    final deltaY = top.y - bot.y;
    final horizontal = deltaY == 0;
    return _ClipperEdge2(
      bot: bot,
      top: top,
      deltaX: deltaX,
      dx: horizontal ? -1.0e40 : deltaX / deltaY,
      isHorizontal: horizontal,
    );
  }

  final SourcePoint2 bot;
  final SourcePoint2 top;
  final int deltaX;
  final double dx;
  final bool isHorizontal;

  int topX(int currentY) => currentY == top.y
      ? top.x
      : bot.x + SourceClipper1TwoConvexUnion2._clipperRound(
          dx * (currentY - bot.y),
        );
}

class _DirectedEdge2 {
  const _DirectedEdge2(this.start, this.end);

  final SourcePoint2 start;
  final SourcePoint2 end;
}
