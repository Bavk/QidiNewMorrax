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

  test('ordered strict-maximum vertical touch with three crossings is exact', () {
    _expectExactAllRotations(
      _poly([
        (650000, -260000),
        (390000, -510000),
        (720000, -480000),
      ]),
      _poly([
        (650000, -210000),
        (650000, -320000),
        (680000, -590000),
      ]),
      const [
        SourcePoint2(671663, -484394),
        SourcePoint2(720000, -480000),
        SourcePoint2(655250, -276500),
        SourcePoint2(650000, -210000),
        SourcePoint2(650000, -260000),
        SourcePoint2(390000, -510000),
        SourcePoint2(668300, -484700),
        SourcePoint2(680000, -590000),
      ],
    );
  });

  test('ordered strict-maximum positive-slope touch is exact', () {
    _expectExactAllRotations(
      _poly([
        (580000, -260000),
        (400000, -510000),
        (490000, -580000),
      ]),
      _poly([
        (670000, 10000),
        (490000, -530000),
        (950000, -680000),
      ]),
      const [
        SourcePoint2(670000, 10000),
        SourcePoint2(580000, -260000),
        SourcePoint2(400000, -510000),
        SourcePoint2(490000, -580000),
        SourcePoint2(502881, -534200),
        SourcePoint2(950000, -680000),
      ],
    );
  });

  test('ordered strict-maximum negative-slope touch is exact', () {
    _expectExactAllRotations(
      _poly([
        (-80000, 800000),
        (-350000, 720000),
        (10000, 770000),
      ]),
      _poly([
        (-160000, 840000),
        (220000, 650000),
        (310000, 650000),
      ]),
      const [
        SourcePoint2(-160000, 840000),
        SourcePoint2(-80000, 800000),
        SourcePoint2(-350000, 720000),
        SourcePoint2(-13478, 766739),
        SourcePoint2(220000, 650000),
        SourcePoint2(310000, 650000),
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

  test('Arachne zero offset routes ordered strict-maximum state exactly', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [
        _poly([
          (650000, -260000),
          (390000, -510000),
          (720000, -480000),
        ]),
        _poly([
          (650000, -210000),
          (650000, -320000),
          (680000, -590000),
        ]),
      ],
      0,
    );

    expect(result, hasLength(1));
    expect(
      result.single.points,
      const [
        SourcePoint2(671663, -484394),
        SourcePoint2(720000, -480000),
        SourcePoint2(655250, -276500),
        SourcePoint2(650000, -210000),
        SourcePoint2(650000, -260000),
        SourcePoint2(390000, -510000),
        SourcePoint2(668300, -484700),
        SourcePoint2(680000, -590000),
      ],
    );
  });

  test('side touching vertex remains on mixed compatibility seam', () {
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

  test('horizontal strict-maximum touched edge remains fallback', () {
    final values = [
      _poly([
        (60000, 50000),
        (-80000, 30000),
        (-10000, 20000),
      ]),
      _poly([
        (120000, 50000),
        (30000, 50000),
        (-120000, -90000),
      ]),
    ];

    expect(SourceClipper1TwoConvexMixedPointUnion2.supports(values), isFalse);
    expect(SourceClipper1TwoConvexUnion2.supports(values), isFalse);
  });

  test('strict-maximum without proved scanline ordering remains fallback', () {
    final values = [
      _poly([
        (-420000, -80000),
        (-620000, -260000),
        (-390000, -160000),
      ]),
      _poly([
        (-420000, -30000),
        (-420000, -260000),
        (-340000, -180000),
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
