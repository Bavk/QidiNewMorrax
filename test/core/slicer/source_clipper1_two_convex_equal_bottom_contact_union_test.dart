import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths_prepare_exact.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_two_convex_contact_union.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_two_convex_equal_bottom_contact_union.dart';

SourcePolygon2 _poly(List<(int, int)> points) => SourcePolygon2([
      for (final point in points) SourcePoint2(point.$1, point.$2),
    ]);

SourcePolygon2 _rotate(SourcePolygon2 polygon, int amount) => SourcePolygon2([
      ...polygon.points.skip(amount),
      ...polygon.points.take(amount),
    ]);

void _expectReverseInputForAllRotations(
  SourcePolygon2 first,
  SourcePolygon2 second,
  List<SourcePoint2> firstExpected,
  List<SourcePoint2> secondExpected,
) {
  for (var firstRotation = 0; firstRotation < 3; firstRotation++) {
    for (var secondRotation = 0; secondRotation < 3; secondRotation++) {
      final rotatedFirst = _rotate(first, firstRotation);
      final rotatedSecond = _rotate(second, secondRotation);

      final forward = [rotatedFirst, rotatedSecond];
      expect(
        SourceClipper1TwoConvexEqualBottomContactUnion2.supports(forward),
        isTrue,
      );
      expect(
        SourceClipper1TwoConvexEqualBottomContactUnion2.unionAll(forward)
            .map((polygon) => polygon.points)
            .toList(),
        [secondExpected, firstExpected],
      );

      final reversed = [rotatedSecond, rotatedFirst];
      expect(
        SourceClipper1TwoConvexEqualBottomContactUnion2.supports(reversed),
        isTrue,
      );
      expect(
        SourceClipper1TwoConvexEqualBottomContactUnion2.unionAll(reversed)
            .map((polygon) => polygon.points)
            .toList(),
        [firstExpected, secondExpected],
      );
    }
  }
}

void main() {
  test('equal-bottom vertex contact reverses AddPath contour order', () {
    _expectReverseInputForAllRotations(
      _poly([(0, 0), (-100000, 100000), (-150000, 0)]),
      _poly([(0, 0), (150000, 0), (100000, 100000)]),
      const [
        SourcePoint2(-100000, 100000),
        SourcePoint2(-150000, 0),
        SourcePoint2(0, 0),
      ],
      const [
        SourcePoint2(100000, 100000),
        SourcePoint2(0, 0),
        SourcePoint2(150000, 0),
      ],
    );
  });

  test('shared flat-bottom vertex tie keeps standalone starts', () {
    _expectReverseInputForAllRotations(
      _poly([(0, 100000), (-100000, 100000), (-50000, 0)]),
      _poly([(0, 100000), (50000, 0), (100000, 100000)]),
      const [
        SourcePoint2(0, 100000),
        SourcePoint2(-100000, 100000),
        SourcePoint2(-50000, 0),
      ],
      const [
        SourcePoint2(100000, 100000),
        SourcePoint2(0, 100000),
        SourcePoint2(50000, 0),
      ],
    );
  });

  test('slanted vertex-edge tie uses the same reverse-source rule', () {
    _expectReverseInputForAllRotations(
      _poly([(0, 0), (0, 100000), (-150000, 0)]),
      _poly([(-50000, -50000), (150000, 50000), (100000, 100000)]),
      const [
        SourcePoint2(0, 100000),
        SourcePoint2(-150000, 0),
        SourcePoint2(0, 0),
      ],
      const [
        SourcePoint2(150000, 50000),
        SourcePoint2(100000, 100000),
        SourcePoint2(-50000, -50000),
      ],
    );
  });

  test('Arachne zero offset routes equal-bottom tie off fallback', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [
        _poly([(0, 0), (-100000, 100000), (-150000, 0)]),
        _poly([(0, 0), (150000, 0), (100000, 100000)]),
      ],
      0,
    );

    expect(
      result.map((polygon) => polygon.points).toList(),
      const [
        [
          SourcePoint2(100000, 100000),
          SourcePoint2(0, 0),
          SourcePoint2(150000, 0),
        ],
        [
          SourcePoint2(-100000, 100000),
          SourcePoint2(-150000, 0),
          SourcePoint2(0, 0),
        ],
      ],
    );
  });

  test('different bottoms remain owned by the original contact helper', () {
    final values = [
      _poly([(0, 0), (100000, 0), (50000, 100000)]),
      _poly([(50000, 100000), (100000, 200000), (0, 200000)]),
    ];

    expect(
      SourceClipper1TwoConvexEqualBottomContactUnion2.supports(values),
      isFalse,
    );
    expect(SourceClipper1TwoConvexContactUnion2.supports(values), isTrue);
  });

  test('shared edge is not an equal-bottom point contact', () {
    expect(
      SourceClipper1TwoConvexEqualBottomContactUnion2.supports([
        _poly([(0, 0), (100000, 0), (50000, 100000)]),
        _poly([(100000, 0), (150000, 100000), (50000, 100000)]),
      ]),
      isFalse,
    );
  });

  test('proper crossing is rejected by the equal-bottom helper', () {
    expect(
      SourceClipper1TwoConvexEqualBottomContactUnion2.supports([
        _poly([(0, 0), (100000, 0), (50000, 100000)]),
        _poly([(25000, -25000), (125000, 25000), (25000, 100000)]),
      ]),
      isFalse,
    );
  });
}
