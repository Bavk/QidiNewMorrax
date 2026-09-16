from pathlib import Path

helper = Path('lib/core/slicer/source_clipper1_two_convex_mixed_point_union.dart')
text = helper.read_text()

old = "    final touches = <SourcePoint2>{};\n    final intersections = <SourcePoint2>{};\n    var properCount = 0;\n"
new = "    final touches = <SourcePoint2>{};\n    final intersections = <SourcePoint2>{};\n    final roundedEndpointIntersections = <_RoundedMixedIntersection2>[];\n    var properCount = 0;\n"
assert old in text
text = text.replace(old, new, 1)

old = """        if (_segmentsProperlyIntersect(a, b, c, d)) {
          final point = _clipperIntersection(a, b, c, d);
          if (point == null ||
              point == a ||
              point == b ||
              point == c ||
              point == d ||
              !intersections.add(point)) {
            return null;
          }
          properCount++;
          firstSplits[firstIndex].add(point);
          secondSplits[secondIndex].add(point);
          continue;
        }
"""
new = """        if (_segmentsProperlyIntersect(a, b, c, d)) {
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
"""
assert old in text
text = text.replace(old, new, 1)

old = """    final owner = firstOwnsTouch ? first : second;
    final other = firstOwnsTouch ? second : first;
    if (!_isSupportedTouchState(owner, other, touch, properCount)) return null;
"""
new = """    final owner = firstOwnsTouch ? first : second;
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
      return result == null ? null : SourcePolygon2(result);
    }
    if (!_isSupportedTouchState(owner, other, touch, properCount)) return null;
"""
assert old in text
text = text.replace(old, new, 1)

marker = "  static bool _appendOutsideFragments(\n"
assert marker in text
methods = """  static List<SourcePoint2>? _roundedStrictMaximumOwnerCollapseOrNull(
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

"""
text = text.replace(marker, methods + marker, 1)

marker = "class _MixedClipperEdge2 {\n"
assert marker in text
record = """class _RoundedMixedIntersection2 {
  const _RoundedMixedIntersection2({
    required this.firstEdgeIndex,
    required this.secondEdgeIndex,
    required this.point,
  });

  final int firstEdgeIndex;
  final int secondEdgeIndex;
  final SourcePoint2 point;
}

"""
text = text.replace(marker, record + marker, 1)

old = """/// committed equal-Y fixture locks the full raw path. Side/horizontal and
/// other rounded-degenerate mixed touch states remain explicit compatibility
/// seams.
"""
new = """/// committed equal-Y fixture locks the full raw path. A separate traced
/// rounded-to-touch single-crossing state is represented when exact
/// `E2InsertsBeforeE1()` ordering places both already-active other bounds
/// between the owner bounds, so both owner bounds contribute with `WindCnt=1`.
/// Side/horizontal, AEL-outside rounded collapses and other rounded-degenerate
/// mixed touch states remain explicit compatibility seams.
"""
assert old in text
text = text.replace(old, new, 1)
helper.write_text(text)

test = Path('test/core/slicer/source_clipper1_two_convex_rounded_collapse_test.dart')
test.write_text("""import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths_prepare_exact.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_two_convex_mixed_point_union.dart';

SourcePolygon2 _poly(List<(int, int)> points) => SourcePolygon2([
      for (final point in points) SourcePoint2(point.$1, point.$2),
    ]);

SourcePolygon2 _rotated(SourcePolygon2 polygon, int start) => SourcePolygon2([
      for (var index = 0; index < polygon.points.length; index++)
        polygon.points[(start + index) % polygon.points.length],
    ]);

void _expectExactAllRotations(
  SourcePolygon2 first,
  SourcePolygon2 second,
  List<SourcePoint2> expected,
) {
  for (var firstRotation = 0; firstRotation < 3; firstRotation++) {
    for (var secondRotation = 0; secondRotation < 3; secondRotation++) {
      final a = _rotated(first, firstRotation);
      final b = _rotated(second, secondRotation);
      for (final values in [[a, b], [b, a]]) {
        expect(SourceClipper1TwoConvexMixedPointUnion2.supports(values), isTrue);
        expect(
          SourceClipper1TwoConvexMixedPointUnion2.union(values).points,
          expected,
        );
      }
    }
  }
}

void main() {
  test('rounded strict-max AEL-contained collapse is exact', () {
    _expectExactAllRotations(
      _poly([(0, 0), (-129, -164), (149, -16)]),
      _poly([(-21, 56), (21, -56), (28, -74)]),
      const [
        SourcePoint2(149, -16),
        SourcePoint2(0, 0),
        SourcePoint2(-129, -164),
      ],
    );
  });

  test('translated scaled rounded AEL collapse is exact', () {
    _expectExactAllRotations(
      _poly([
        (376000000, 761000000),
        (375996396, 760996566),
        (376000527, 760997280),
      ]),
      _poly([
        (375999133, 760998300),
        (375999983, 760999966),
        (376001734, 761003400),
      ]),
      const [
        SourcePoint2(376000527, 760997280),
        SourcePoint2(376000000, 761000000),
        SourcePoint2(375996396, 760996566),
      ],
    );
  });

  test('Arachne zero offset routes rounded AEL collapse exactly', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [
        _poly([(0, 0), (-129, -164), (149, -16)]),
        _poly([(-21, 56), (21, -56), (28, -74)]),
      ],
      0,
    );
    expect(result, hasLength(1));
    expect(result.single.points, const [
      SourcePoint2(149, -16),
      SourcePoint2(0, 0),
      SourcePoint2(-129, -164),
    ]);
  });

  test('rounded strict-max retained inner vertex stays fallback', () {
    final values = [
      _poly([(0, 0), (162, -141), (164, -8)]),
      _poly([(-20, 17), (20, -17), (70, -58)]),
    ];
    expect(SourceClipper1TwoConvexMixedPointUnion2.supports(values), isFalse);
  });

  test('rounded strict-max retained wedge stays fallback', () {
    final values = [
      _poly([(0, 0), (-142, -178), (27, -173)]),
      _poly([(-125, -167), (125, 167), (-6, -8)]),
    ];
    expect(SourceClipper1TwoConvexMixedPointUnion2.supports(values), isFalse);
  });
}
""")