import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths_prepare_exact.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_two_convex_contact_union.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_two_convex_mixed_point_union.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_two_convex_union.dart';

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
      final rotatedFirst = _rotated(first, firstRotation);
      final rotatedSecond = _rotated(second, secondRotation);
      for (final values in [
        [rotatedFirst, rotatedSecond],
        [rotatedSecond, rotatedFirst],
      ]) {
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
  test('strict-minimum touching vertex plus crossings matches pinned raw path', () {
    _expectExactAllRotations(
      _poly([
        (0, 0),
        (100000, 0),
        (50000, 100000),
      ]),
      _poly([
        (50000, 0),
        (150000, 20000),
        (50000, 80000),
      ]),
      const [
        SourcePoint2(95455, 9091),
        SourcePoint2(150000, 20000),
        SourcePoint2(64286, 71429),
        SourcePoint2(50000, 100000),
        SourcePoint2(0, 0),
        SourcePoint2(100000, 0),
      ],
    );
  });

  test('second slanted mixed fixture preserves Clipper intersection rounding', () {
    _expectExactAllRotations(
      _poly([
        (0, 0),
        (100000, 0),
        (50000, 100000),
      ]),
      _poly([
        (50000, 0),
        (140000, 40000),
        (80000, 120000),
      ]),
      const [
        SourcePoint2(90909, 18182),
        SourcePoint2(140000, 40000),
        SourcePoint2(80000, 120000),
        SourcePoint2(66667, 66667),
        SourcePoint2(50000, 100000),
        SourcePoint2(0, 0),
        SourcePoint2(100000, 0),
      ],
    );
  });

  test('translated non-axis-aligned mixed fixture is exact', () {
    _expectExactAllRotations(
      _poly([
        (950000, -410000),
        (800000, 670000),
        (680000, -380000),
      ]),
      _poly([
        (900000, -50000),
        (2400000, 290000),
        (690000, 1090000),
      ]),
      const [
        SourcePoint2(900000, -50000),
        SourcePoint2(2400000, 290000),
        SourcePoint2(690000, 1090000),
        SourcePoint2(787506, 560680),
        SourcePoint2(680000, -380000),
        SourcePoint2(950000, -410000),
      ],
    );
  });

  test('Arachne zero offset routes represented mixed point state exactly', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [
        _poly([
          (0, 0),
          (100000, 0),
          (50000, 100000),
        ]),
        _poly([
          (50000, 0),
          (150000, 20000),
          (50000, 80000),
        ]),
      ],
      0,
    );

    expect(result, hasLength(1));
    expect(
      result.single.points,
      const [
        SourcePoint2(95455, 9091),
        SourcePoint2(150000, 20000),
        SourcePoint2(64286, 71429),
        SourcePoint2(50000, 100000),
        SourcePoint2(0, 0),
        SourcePoint2(100000, 0),
      ],
    );
  });

  test('non-minimum touching vertex remains on mixed compatibility seam', () {
    final values = [
      _poly([
        (410000, -470000),
        (260000, 470000),
        (300000, -330000),
      ]),
      _poly([
        (335000, 0),
        (25000, -1160000),
        (1375000, 660000),
      ]),
    ];

    expect(SourceClipper1TwoConvexMixedPointUnion2.supports(values), isFalse);
    expect(SourceClipper1TwoConvexUnion2.supports(values), isFalse);
  });

  test('point-only contact stays owned by zero-area contact helper', () {
    final values = [
      _poly([
        (0, 0),
        (100000, 0),
        (50000, 100000),
      ]),
      _poly([
        (100000, 0),
        (160000, -60000),
        (180000, 20000),
      ]),
    ];

    expect(SourceClipper1TwoConvexMixedPointUnion2.supports(values), isFalse);
    expect(SourceClipper1TwoConvexContactUnion2.supports(values), isTrue);
  });

  test('proper-only crossing remains owned by proper-convex helper', () {
    final values = [
      _poly([
        (0, 0),
        (120000, 0),
        (60000, 120000),
      ]),
      _poly([
        (30000, -20000),
        (150000, 70000),
        (10000, 90000),
      ]),
    ];

    expect(SourceClipper1TwoConvexMixedPointUnion2.supports(values), isFalse);
    expect(SourceClipper1TwoConvexUnion2.supports(values), isTrue);
  });

  test('wider convex mixed path is deliberately outside triangle proof', () {
    final triangle = _poly([
      (0, 0),
      (100000, 0),
      (50000, 100000),
    ]);
    final quadrilateral = _poly([
      (50000, 0),
      (150000, 20000),
      (120000, 70000),
      (50000, 80000),
    ]);

    expect(
      SourceClipper1TwoConvexMixedPointUnion2.supports([
        triangle,
        quadrilateral,
      ]),
      isFalse,
    );
  });
}
