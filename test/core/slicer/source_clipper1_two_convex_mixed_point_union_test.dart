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
      _poly([(0, 0), (100000, 0), (50000, 100000)]),
      _poly([(50000, 0), (150000, 20000), (50000, 80000)]),
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
      _poly([(0, 0), (100000, 0), (50000, 100000)]),
      _poly([(50000, 0), (140000, 40000), (80000, 120000)]),
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
      _poly([(950000, -410000), (800000, 670000), (680000, -380000)]),
      _poly([(900000, -50000), (2400000, 290000), (690000, 1090000)]),
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
      _poly([(650000, -260000), (390000, -510000), (720000, -480000)]),
      _poly([(650000, -210000), (650000, -320000), (680000, -590000)]),
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
      _poly([(580000, -260000), (400000, -510000), (490000, -580000)]),
      _poly([(670000, 10000), (490000, -530000), (950000, -680000)]),
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
      _poly([(-80000, 800000), (-350000, 720000), (10000, 770000)]),
      _poly([(-160000, 840000), (220000, 650000), (310000, 650000)]),
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

  test('late strict-maximum vertical single-crossing touch is exact', () {
    _expectExactAllRotations(
      _poly([
        (-870000, -1033000),
        (-1060000, -1164000),
        (-659000, -1202000),
      ]),
      _poly([
        (-870000, -1133000),
        (-870000, -683000),
        (-1530000, -1125000),
      ]),
      const [
        SourcePoint2(-870000, -1033000),
        SourcePoint2(-870000, -683000),
        SourcePoint2(-1530000, -1125000),
        SourcePoint2(-1012532, -1131272),
        SourcePoint2(-1060000, -1164000),
        SourcePoint2(-659000, -1202000),
      ],
    );
  });

  test('late strict-maximum positive-slope single-crossing touch is exact', () {
    _expectExactAllRotations(
      _poly([(262000, -1122000), (67000, -1154000), (547000, -1601000)]),
      _poly([(112000, -1242000), (612000, -842000), (-367000, -831000)]),
      const [
        SourcePoint2(262000, -1122000),
        SourcePoint2(612000, -842000),
        SourcePoint2(-367000, -831000),
        SourcePoint2(112000, -1242000),
        SourcePoint2(138625, -1220700),
        SourcePoint2(547000, -1601000),
      ],
    );
  });

  test('late strict-maximum negative-slope single-crossing touch is exact', () {
    _expectExactAllRotations(
      _poly([(-240000, -29000), (-410000, -364000), (51000, -114000)]),
      _poly([(-160000, -99000), (-560000, 251000), (-863000, -172000)]),
      const [
        SourcePoint2(51000, -114000),
        SourcePoint2(-240000, -29000),
        SourcePoint2(-560000, 251000),
        SourcePoint2(-863000, -172000),
        SourcePoint2(-281948, -111663),
        SourcePoint2(-410000, -364000),
      ],
    );
  });

  test('strict-maximum equal-Y boundary matches pinned raw path', () {
    _expectExactAllRotations(
      _poly([(-126000, 102000), (-455000, -127000), (65000, -185000)]),
      _poly([(24000, 312000), (-176000, 32000), (91000, -185000)]),
      const [
        SourcePoint2(24000, 312000),
        SourcePoint2(-126000, 102000),
        SourcePoint2(-455000, -127000),
        SourcePoint2(65000, -185000),
        SourcePoint2(34370, -138975),
        SourcePoint2(91000, -185000),
      ],
    );
  });

  test('late strict-maximum single-cross separated-minimum state is exact', () {
    _expectExactAllRotations(
      _poly([(-420000, -80000), (-620000, -260000), (-390000, -160000)]),
      _poly([(-420000, -30000), (-420000, -260000), (-340000, -180000)]),
      const [
        SourcePoint2(-340000, -180000),
        SourcePoint2(-420000, -30000),
        SourcePoint2(-420000, -80000),
        SourcePoint2(-620000, -260000),
        SourcePoint2(-420000, -173043),
        SourcePoint2(-420000, -260000),
      ],
    );
  });

  test('Arachne zero offset routes represented mixed point state exactly', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [
        _poly([(0, 0), (100000, 0), (50000, 100000)]),
        _poly([(50000, 0), (150000, 20000), (50000, 80000)]),
      ],
      0,
    );
    expect(result, hasLength(1));
    expect(result.single.points, const [
      SourcePoint2(95455, 9091),
      SourcePoint2(150000, 20000),
      SourcePoint2(64286, 71429),
      SourcePoint2(50000, 100000),
      SourcePoint2(0, 0),
      SourcePoint2(100000, 0),
    ]);
  });

  test('Arachne zero offset routes ordered strict-maximum state exactly', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [
        _poly([(650000, -260000), (390000, -510000), (720000, -480000)]),
        _poly([(650000, -210000), (650000, -320000), (680000, -590000)]),
      ],
      0,
    );
    expect(result, hasLength(1));
    expect(result.single.points, const [
      SourcePoint2(671663, -484394),
      SourcePoint2(720000, -480000),
      SourcePoint2(655250, -276500),
      SourcePoint2(650000, -210000),
      SourcePoint2(650000, -260000),
      SourcePoint2(390000, -510000),
      SourcePoint2(668300, -484700),
      SourcePoint2(680000, -590000),
    ]);
  });

  test('Arachne zero offset routes late strict-maximum state exactly', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [
        _poly([
          (-870000, -1033000),
          (-1060000, -1164000),
          (-659000, -1202000),
        ]),
        _poly([
          (-870000, -1133000),
          (-870000, -683000),
          (-1530000, -1125000),
        ]),
      ],
      0,
    );
    expect(result, hasLength(1));
    expect(result.single.points, const [
      SourcePoint2(-870000, -1033000),
      SourcePoint2(-870000, -683000),
      SourcePoint2(-1530000, -1125000),
      SourcePoint2(-1012532, -1131272),
      SourcePoint2(-1060000, -1164000),
      SourcePoint2(-659000, -1202000),
    ]);
  });

  test('Arachne zero offset routes strict-maximum equal-Y state exactly', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [
        _poly([(-126000, 102000), (-455000, -127000), (65000, -185000)]),
        _poly([(24000, 312000), (-176000, 32000), (91000, -185000)]),
      ],
      0,
    );
    expect(result, hasLength(1));
    expect(result.single.points, const [
      SourcePoint2(24000, 312000),
      SourcePoint2(-126000, 102000),
      SourcePoint2(-455000, -127000),
      SourcePoint2(65000, -185000),
      SourcePoint2(34370, -138975),
      SourcePoint2(91000, -185000),
    ]);
  });

  test('Arachne zero offset routes late multi-crossing strict-maximum state exactly', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [
        _poly([(-606000, 279000), (-905000, 166000), (-354000, 79000)]),
        _poly([(-856000, 79000), (-406000, 439000), (-870000, 163000)]),
      ],
      0,
    );
    expect(result, hasLength(1));
    expect(result.single.points, const [
      SourcePoint2(-606000, 279000),
      SourcePoint2(-406000, 439000),
      SourcePoint2(-795185, 207502),
      SourcePoint2(-905000, 166000),
      SourcePoint2(-869568, 160405),
      SourcePoint2(-856000, 79000),
      SourcePoint2(-773253, 145198),
      SourcePoint2(-354000, 79000),
    ]);
  });

  test('Arachne zero offset routes single-cross separated-minimum state exactly', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [
        _poly([(-420000, -80000), (-620000, -260000), (-390000, -160000)]),
        _poly([(-420000, -30000), (-420000, -260000), (-340000, -180000)]),
      ],
      0,
    );
    expect(result, hasLength(1));
    expect(result.single.points, const [
      SourcePoint2(-340000, -180000),
      SourcePoint2(-420000, -30000),
      SourcePoint2(-420000, -80000),
      SourcePoint2(-620000, -260000),
      SourcePoint2(-420000, -173043),
      SourcePoint2(-420000, -260000),
    ]);
  });

  test('side touching vertex remains on mixed compatibility seam', () {
    final values = [
      _poly([(410000, -470000), (260000, 470000), (300000, -330000)]),
      _poly([(335000, 0), (25000, -1160000), (1375000, 660000)]),
    ];
    expect(SourceClipper1TwoConvexMixedPointUnion2.supports(values), isFalse);
    expect(SourceClipper1TwoConvexUnion2.supports(values), isFalse);
  });

  test('horizontal strict-maximum touched edge remains fallback', () {
    final values = [
      _poly([(60000, 50000), (-80000, 30000), (-10000, 20000)]),
      _poly([(120000, 50000), (30000, 50000), (-120000, -90000)]),
    ];
    expect(SourceClipper1TwoConvexMixedPointUnion2.supports(values), isFalse);
    expect(SourceClipper1TwoConvexUnion2.supports(values), isFalse);
  });

  test('late strict-maximum multi-crossing touch is exact', () {
    _expectExactAllRotations(
      _poly([(-606000, 279000), (-905000, 166000), (-354000, 79000)]),
      _poly([(-856000, 79000), (-406000, 439000), (-870000, 163000)]),
      const [
        SourcePoint2(-606000, 279000),
        SourcePoint2(-406000, 439000),
        SourcePoint2(-795185, 207502),
        SourcePoint2(-905000, 166000),
        SourcePoint2(-869568, 160405),
        SourcePoint2(-856000, 79000),
        SourcePoint2(-773253, 145198),
        SourcePoint2(-354000, 79000),
      ],
    );
  });

  test('point-only contact stays owned by zero-area contact helper', () {
    final values = [
      _poly([(0, 0), (100000, 0), (50000, 100000)]),
      _poly([(100000, 0), (160000, -60000), (180000, 20000)]),
    ];
    expect(SourceClipper1TwoConvexMixedPointUnion2.supports(values), isFalse);
    expect(SourceClipper1TwoConvexContactUnion2.supports(values), isTrue);
  });

  test('proper-only crossing remains owned by proper-convex helper', () {
    final values = [
      _poly([(0, 0), (120000, 0), (60000, 120000)]),
      _poly([(30000, -20000), (150000, 70000), (10000, 90000)]),
    ];
    expect(SourceClipper1TwoConvexMixedPointUnion2.supports(values), isFalse);
    expect(SourceClipper1TwoConvexUnion2.supports(values), isTrue);
  });

  test('wider convex mixed path is deliberately outside triangle proof', () {
    final triangle = _poly([(0, 0), (100000, 0), (50000, 100000)]);
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
