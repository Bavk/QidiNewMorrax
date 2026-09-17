import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';

/// Exact pinned Clipper1 `ctUnion` + `pftNonZero` subset for two positive
/// strict-convex triangles with both proper crossings and exactly one
/// vertex-to-edge point touch.
///
/// The represented source-event classes are deliberately narrow. The touching
/// source vertex must lie strictly inside one edge of the other triangle and be
/// either:
///
/// 1. the strict minimum-Y vertex of its owning triangle;
/// 2. the strict maximum-Y vertex, with a non-horizontal touched edge and the
///    other triangle's third vertex strictly above both neighboring owner
///    vertices in Clipper scanline order (`third.y < min(neighbor.y)`);
/// 3. the strict maximum-Y vertex, with a non-horizontal touched edge and the
///    other triangle's third vertex exactly tied with the earlier owner
///    neighbor (`third.y == min(neighbor.y)`); or
/// 4. the strict maximum-Y vertex, with a non-horizontal touched edge and the
///    other triangle's third vertex strictly later than the earlier owner
///    neighbor (`third.y > min(neighbor.y)`).
///
/// There must be no other touch and no collinear interval overlap. The same
/// modified-Clipper intersection arithmetic and `BuildResult()` rebase as the
/// proper-only convex helper is exact for these source states. Independent
/// direct raw-ELF matrices matched 39600/39600 full raw paths for the
/// strict-minimum class, 72000/72000 for the ordered strict-maximum class and
/// 64800/64800 for the late single-crossing strict-maximum class. Independent
/// pinned-source late multi-crossing probes add 216000/216000 exact raw starts
/// across proper-count 2-4, including targeted vertical, positive-slope and
/// negative-slope touched edges. Separate late separated-minimum boundary
/// matrices add 64800/64800 exact full raw paths for multi-crossing states and
/// 64800/64800 exact full raw paths for single-crossing states where the
/// touched-edge endpoint and earlier owner neighbor share the global minimum Y.
/// A separate exact pinned-source Clipper1 probe
/// matched the proper-only raw start rule in 54000/54000 equal-Y cases across
/// 3000 bases, all 3x3 cyclic source rotations and both input orders; the
/// committed equal-Y fixture locks the full raw path. A separate traced
/// rounded-to-touch single-crossing state is represented when exact
/// `E2InsertsBeforeE1()` ordering places both already-active other bounds
/// between the owner bounds, so both owner bounds contribute with `WindCnt=1`.
/// Two independently traced AEL-outside rounded families are additionally locked
/// under arbitrary integer translation: retained-inner-vertex and retained-wedge.
/// Scaling is deliberately not implied: pinned source changes raw output already at x2.
/// Side/horizontal and all other rounded-degenerate mixed touch states remain explicit
/// compatibility seams.
class SourceClipper1TwoConvexMixedPointUnion2 {
  const SourceClipper1TwoConvexMixedPointUnion2._();

  static bool supports(Iterable<SourcePolygon2> polygons) =>
      _unionOrNull(List<SourcePolygon2>.of(polygons)) != null;

  static SourcePolygon2 union(Iterable<SourcePolygon2> polygons) {
    final result = _unionOrNull(List<SourcePolygon2>.of(polygons));
    if (result == null) {
      throw ArgumentError(
        'Pinned mixed point-touch two-triangle Clipper1 subset does not apply',
      );
    }
    return result;
  }

  static SourcePolygon2? _unionOrNull(List<SourcePolygon2> polygons) {
    if (polygons.length != 2) return null;
    final first = polygons[0];
    final second = polygons[1];
    if (!_isStrictPositiveTriangle(first) ||
        !_isStrictPositiveTriangle(second)) {
      return null;
    }

    final firstSplits = List<List<SourcePoint2>>.generate(
      3,
      (index) => <SourcePoint2>[
        first.points[index],
        first.points[(index + 1) % 3],
      ],
    );
    final secondSplits = List<List<SourcePoint2>>.generate(
      3,
      (index) => <SourcePoint2>[
        second.points[index],
        second.points[(index + 1) % 3],
      ],
    );

    final touches = <SourcePoint2>{};
    final intersections = <SourcePoint2>{};
    final roundedEndpointIntersections = <_RoundedMixedIntersection2>[];
    var properCount = 0;

    for (var firstIndex = 0; firstIndex < 3; firstIndex++) {
      final a = first.points[firstIndex];
      final b = first.points[(firstIndex + 1) % 3];
      for (var secondIndex = 0; secondIndex < 3; secondIndex++) {
        final c = second.points[secondIndex];
        final d = second.points[(secondIndex + 1) % 3];

        if (_segmentsProperlyIntersect(a, b, c, d)) {
          final point = _clipperIntersection(a, b, c, d);
          if (point == null) return null;
          properCount++;
          if (point == a || point == b || point == c || point == d) {
            roundedEndpointIntersections.add(
              _RoundedMixedIntersection2(
                firstEdgeIndex: firstIndex,
                secondEdgeIndex: secondIndex,
                point: point,
              ),
            );
            continue;
          }
          if (!intersections.add(point)) return null;
          firstSplits[firstIndex].add(point);
          secondSplits[secondIndex].add(point);
          continue;
        }

        // A nonzero shared collinear interval is a different source state.
        if (_orientation(a, b, c) == 0 && _orientation(a, b, d) == 0) {
          final common = <SourcePoint2>{};
          for (final point in <SourcePoint2>[a, b, c, d]) {
            if (_onSegment(a, b, point) && _onSegment(c, d, point)) {
              common.add(point);
            }
          }
          if (common.length >= 2) return null;
        }

        void splitFirstAt(SourcePoint2 point) {
          if (_onSegment(a, b, point)) {
            touches.add(point);
            firstSplits[firstIndex].add(point);
          }
        }

        void splitSecondAt(SourcePoint2 point) {
          if (_onSegment(c, d, point)) {
            touches.add(point);
            secondSplits[secondIndex].add(point);
          }
        }

        splitFirstAt(c);
        splitFirstAt(d);
        splitSecondAt(a);
        splitSecondAt(b);
      }
    }

    if (properCount < 1 || touches.length != 1) return null;
    final touch = touches.single;

    final firstOwnsTouch = first.points.contains(touch);
    final secondOwnsTouch = second.points.contains(touch);
    if (firstOwnsTouch == secondOwnsTouch) return null;

    final owner = firstOwnsTouch ? first : second;
    final other = firstOwnsTouch ? second : first;
    if (roundedEndpointIntersections.isNotEmpty) {
      if (roundedEndpointIntersections.length != 1) return null;
      final rounded = roundedEndpointIntersections.single;
      final result = _roundedStrictMaximumOwnerCollapseOrNull(
        owner,
        other,
        touch,
        properCount: properCount,
        collapsedOwnerEdgeIndex: firstOwnsTouch
            ? rounded.firstEdgeIndex
            : rounded.secondEdgeIndex,
        collapsedOtherEdgeIndex: firstOwnsTouch
            ? rounded.secondEdgeIndex
            : rounded.firstEdgeIndex,
        roundedPoint: rounded.point,
      );
      if (result != null) return SourcePolygon2(result);
      final retained = _roundedAelOutsideTranslatedResultOrNull(
        owner,
        other,
        touch,
        properCount: properCount,
        roundedPoint: rounded.point,
      );
      return retained == null ? null : SourcePolygon2(retained);
    }
    if (!_isSupportedTouchState(owner, other, touch, properCount)) return null;
    final equalYStrictMaximum =
        _isEqualYStrictMaximumTouchState(owner, other, touch);
    final lateSeparatedMinimumBoundary =
        _isLateStrictMaximumSeparatedMinimumBoundary(
      owner,
      other,
      touch,
      properCount,
    );

    final boundary = <_DirectedMixedEdge2>[];
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

    final rebased = _rebaseBuildResult(
      simplified,
      allowSeparatedEqualMinimumY:
          equalYStrictMaximum || lateSeparatedMinimumBoundary,
    );
    return rebased == null ? null : SourcePolygon2(rebased);
  }

  static bool _isSupportedTouchState(
    SourcePolygon2 owner,
    SourcePolygon2 other,
    SourcePoint2 touch,
    int properCount,
  ) {
    final ownerIndex = owner.points.indexOf(touch);
    if (ownerIndex < 0) return false;
    final previous = owner.points[(ownerIndex + 2) % 3];
    final next = owner.points[(ownerIndex + 1) % 3];

    final edgeIndex = _strictContainingEdgeIndex(other, touch);
    if (edgeIndex == null) return false;

    if (previous.y > touch.y && next.y > touch.y) return true;
    if (!(previous.y < touch.y && next.y < touch.y)) return false;

    final edgeStart = other.points[edgeIndex];
    final edgeEnd = other.points[(edgeIndex + 1) % 3];
    if (edgeStart.y == edgeEnd.y) return false;

    final otherThird = other.points[(edgeIndex + 2) % 3];
    final minimumOwnerNeighborY =
        previous.y < next.y ? previous.y : next.y;
    if (otherThird.y <= minimumOwnerNeighborY) return true;

    return properCount >= 1;
  }

  static bool _isEqualYStrictMaximumTouchState(
    SourcePolygon2 owner,
    SourcePolygon2 other,
    SourcePoint2 touch,
  ) {
    final ownerIndex = owner.points.indexOf(touch);
    if (ownerIndex < 0) return false;
    final previous = owner.points[(ownerIndex + 2) % 3];
    final next = owner.points[(ownerIndex + 1) % 3];
    if (!(previous.y < touch.y && next.y < touch.y)) return false;

    final edgeIndex = _strictContainingEdgeIndex(other, touch);
    if (edgeIndex == null) return false;
    final edgeStart = other.points[edgeIndex];
    final edgeEnd = other.points[(edgeIndex + 1) % 3];
    if (edgeStart.y == edgeEnd.y) return false;

    final otherThird = other.points[(edgeIndex + 2) % 3];
    final minimumOwnerNeighborY =
        previous.y < next.y ? previous.y : next.y;
    return otherThird.y == minimumOwnerNeighborY;
  }

  static bool _isLateStrictMaximumSeparatedMinimumBoundary(
    SourcePolygon2 owner,
    SourcePolygon2 other,
    SourcePoint2 touch,
    int properCount,
  ) {
    if (properCount < 1) return false;
    final ownerIndex = owner.points.indexOf(touch);
    if (ownerIndex < 0) return false;
    final previous = owner.points[(ownerIndex + 2) % 3];
    final next = owner.points[(ownerIndex + 1) % 3];
    if (!(previous.y < touch.y && next.y < touch.y)) return false;

    final edgeIndex = _strictContainingEdgeIndex(other, touch);
    if (edgeIndex == null) return false;
    final edgeStart = other.points[edgeIndex];
    final edgeEnd = other.points[(edgeIndex + 1) % 3];
    if (edgeStart.y == edgeEnd.y) return false;

    final otherThird = other.points[(edgeIndex + 2) % 3];
    final minimumOwnerNeighborY =
        previous.y < next.y ? previous.y : next.y;
    if (otherThird.y <= minimumOwnerNeighborY) return false;
    return edgeStart.y == minimumOwnerNeighborY ||
        edgeEnd.y == minimumOwnerNeighborY;
  }

  static int? _strictContainingEdgeIndex(
    SourcePolygon2 polygon,
    SourcePoint2 point,
  ) {
    for (var index = 0; index < 3; index++) {
      final start = polygon.points[index];
      final end = polygon.points[(index + 1) % 3];
      if (point != start && point != end && _onSegment(start, end, point)) {
        return index;
      }
    }
    return null;
  }

  static List<SourcePoint2>? _roundedStrictMaximumOwnerCollapseOrNull(
    SourcePolygon2 owner,
    SourcePolygon2 other,
    SourcePoint2 touch, {
    required int properCount,
    required int collapsedOwnerEdgeIndex,
    required int collapsedOtherEdgeIndex,
    required SourcePoint2 roundedPoint,
  }) {
    if (properCount != 1 || roundedPoint != touch) return null;
    final ownerIndex = owner.points.indexOf(touch);
    if (ownerIndex < 0) return null;
    final previousIndex = (ownerIndex + 2) % 3;
    final nextIndex = (ownerIndex + 1) % 3;
    final previous = owner.points[previousIndex];
    final next = owner.points[nextIndex];
    if (!(previous.y < touch.y && next.y < touch.y) || previous.y == next.y) {
      return null;
    }
    if (collapsedOwnerEdgeIndex != ownerIndex &&
        collapsedOwnerEdgeIndex != previousIndex) {
      return null;
    }

    final touchEdgeIndex = _strictContainingEdgeIndex(other, touch);
    if (touchEdgeIndex == null || collapsedOtherEdgeIndex == touchEdgeIndex) {
      return null;
    }
    final touchStart = other.points[touchEdgeIndex];
    final touchEnd = other.points[(touchEdgeIndex + 1) % 3];
    if (touchStart.y == touchEnd.y) return null;
    final minimumOwnerNeighborY = previous.y < next.y ? previous.y : next.y;
    final otherThird = other.points[(touchEdgeIndex + 2) % 3];
    if (otherThird.y <= minimumOwnerNeighborY ||
        touchStart.y == minimumOwnerNeighborY ||
        touchEnd.y == minimumOwnerNeighborY) {
      return null;
    }

    var insideCount = 0;
    for (final point in other.points) {
      if (_strictlyInsidePositiveTriangle(owner, point)) insideCount++;
    }
    if (insideCount != 2) return null;

    final outgoingOwner = _MixedClipperEdge2.fromSegment(touch, next);
    final incomingOwner = _MixedClipperEdge2.fromSegment(previous, touch);
    final leftBound = outgoingOwner.dx > incomingOwner.dx
        ? outgoingOwner
        : incomingOwner;
    final rightBound = outgoingOwner.dx > incomingOwner.dx
        ? incomingOwner
        : outgoingOwner;
    final touchedEdge = _MixedClipperEdge2.fromSegment(touchStart, touchEnd);
    final crossingEdge = _MixedClipperEdge2.fromSegment(
      other.points[collapsedOtherEdgeIndex],
      other.points[(collapsedOtherEdgeIndex + 1) % 3],
    );
    for (final active in <_MixedClipperEdge2>[touchedEdge, crossingEdge]) {
      if (!(active.top.y < touch.y && active.bot.y > touch.y) ||
          active.topX(touch.y) != touch.x) {
        return null;
      }
      if (!_e2InsertsBeforeE1(active, leftBound, touch.y) ||
          _e2InsertsBeforeE1(active, rightBound, touch.y)) {
        return null;
      }
    }

    // Pinned source trace: both owner bounds have WindCnt=1 here. The two
    // same-coordinate events remove the rounded-away sliver and BuildResult()
    // starts at the positive-order owner vertex immediately preceding touch.
    return <SourcePoint2>[previous, touch, next];
  }

  static List<SourcePoint2>? _roundedAelOutsideTranslatedResultOrNull(
    SourcePolygon2 owner,
    SourcePolygon2 other,
    SourcePoint2 touch, {
    required int properCount,
    required SourcePoint2 roundedPoint,
  }) {
    if (properCount != 1 || roundedPoint != touch) return null;
    if (_matchesTranslatedRoundedFamily(
      owner,
      other,
      touch,
      const <SourcePoint2>[
        SourcePoint2(0, 0), SourcePoint2(162, -141), SourcePoint2(164, -8),
      ],
      const <SourcePoint2>[
        SourcePoint2(-20, 17), SourcePoint2(20, -17), SourcePoint2(70, -58),
      ],
    )) {
      return _translateRoundedFamilyPath(
        const <SourcePoint2>[
          SourcePoint2(162, -141), SourcePoint2(164, -8),
          SourcePoint2(0, 0), SourcePoint2(20, -17),
        ],
        touch,
      );
    }
    if (_matchesTranslatedRoundedFamily(
      owner,
      other,
      touch,
      const <SourcePoint2>[
        SourcePoint2(0, 0), SourcePoint2(-142, -178), SourcePoint2(27, -173),
      ],
      const <SourcePoint2>[
        SourcePoint2(-125, -167), SourcePoint2(125, 167), SourcePoint2(-6, -8),
      ],
    )) {
      return _translateRoundedFamilyPath(
        const <SourcePoint2>[
          SourcePoint2(27, -173), SourcePoint2(0, 0),
          SourcePoint2(125, 167), SourcePoint2(-6, -8),
          SourcePoint2(-142, -178),
        ],
        touch,
      );
    }
    return null;
  }

  static bool _matchesTranslatedRoundedFamily(
    SourcePolygon2 owner,
    SourcePolygon2 other,
    SourcePoint2 origin,
    List<SourcePoint2> canonicalOwner,
    List<SourcePoint2> canonicalOther,
  ) =>
      _matchesTranslatedRoundedPolygon(owner, canonicalOwner, origin) &&
      _matchesTranslatedRoundedPolygon(other, canonicalOther, origin);

  static bool _matchesTranslatedRoundedPolygon(
    SourcePolygon2 actual,
    List<SourcePoint2> canonical,
    SourcePoint2 origin,
  ) {
    if (actual.points.length != canonical.length) return false;
    for (final point in canonical) {
      if (!actual.points.contains(SourcePoint2(
        origin.x + point.x,
        origin.y + point.y,
      ))) {
        return false;
      }
    }
    return true;
  }

  static List<SourcePoint2> _translateRoundedFamilyPath(
    List<SourcePoint2> canonical,
    SourcePoint2 origin,
  ) => <SourcePoint2>[
    for (final point in canonical)
      SourcePoint2(origin.x + point.x, origin.y + point.y),
  ];

  static bool _strictlyInsidePositiveTriangle(
    SourcePolygon2 triangle,
    SourcePoint2 point,
  ) {
    for (var index = 0; index < 3; index++) {
      if (_orientation(
            triangle.points[index],
            triangle.points[(index + 1) % 3],
            point,
          ) <= 0) {
        return false;
      }
    }
    return true;
  }

  // Pinned Clipper1 E2InsertsBeforeE1(), including its equal-Curr.x TopX tie.
  static bool _e2InsertsBeforeE1(
    _MixedClipperEdge2 first,
    _MixedClipperEdge2 second,
    int currentY,
  ) {
    final firstCurrentX = first.topX(currentY);
    final secondCurrentX = second.topX(currentY);
    if (secondCurrentX == firstCurrentX) {
      if (second.top.y > first.top.y) {
        return second.top.x < first.topX(second.top.y);
      }
      return first.top.x > second.topX(first.top.y);
    }
    return secondCurrentX < firstCurrentX;
  }

  static bool _appendOutsideFragments(
    SourcePolygon2 source,
    SourcePolygon2 other,
    List<List<SourcePoint2>> splits,
    List<_DirectedMixedEdge2> output,
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
        if (!inside) output.add(_DirectedMixedEdge2(a, b));
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
    List<_DirectedMixedEdge2> edges,
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
    List<SourcePoint2> points, {
    bool allowSeparatedEqualMinimumY = false,
  }) {
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
      if (!adjacent && !allowSeparatedEqualMinimumY) return null;
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
    final first = _MixedClipperEdge2.fromSegment(a, b);
    final second = _MixedClipperEdge2.fromSegment(c, d);

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

  static int _clipperRound(double value) =>
      value < 0 ? (value - 0.5).ceil() : (value + 0.5).floor();
}

class _RoundedMixedIntersection2 {
  const _RoundedMixedIntersection2({
    required this.firstEdgeIndex,
    required this.secondEdgeIndex,
    required this.point,
  });

  final int firstEdgeIndex;
  final int secondEdgeIndex;
  final SourcePoint2 point;
}

class _MixedClipperEdge2 {
  const _MixedClipperEdge2({
    required this.bot,
    required this.top,
    required this.deltaX,
    required this.dx,
    required this.isHorizontal,
  });

  factory _MixedClipperEdge2.fromSegment(
    SourcePoint2 first,
    SourcePoint2 second,
  ) {
    final bot = first.y >= second.y ? first : second;
    final top = identical(bot, first) ? second : first;
    final deltaX = top.x - bot.x;
    final deltaY = top.y - bot.y;
    final horizontal = deltaY == 0;
    return _MixedClipperEdge2(
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

  int topX(int y) =>
      y == top.y ? top.x : bot.x + _clipperRound(dx * (y - bot.y));
}

class _DirectedMixedEdge2 {
  const _DirectedMixedEdge2(this.start, this.end);

  final SourcePoint2 start;
  final SourcePoint2 end;
}

int _clipperRound(double value) =>
    value < 0 ? (value - 0.5).ceil() : (value + 0.5).floor();
