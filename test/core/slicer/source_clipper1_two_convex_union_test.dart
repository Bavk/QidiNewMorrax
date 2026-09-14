import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths_prepare_exact.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_two_convex_union.dart';

SourcePolygon2 _poly(List<(int, int)> points) => SourcePolygon2([
      for (final point in points) SourcePoint2(point.$1, point.$2),
    ]);

void _expectUnion(
  SourcePolygon2 first,
  SourcePolygon2 second,
  List<SourcePoint2> expected,
) {
  expect(SourceClipper1TwoConvexUnion2.supports([first, second]), isTrue);
  expect(
    SourceClipper1TwoConvexUnion2.union([first, second]).points,
    expected,
  );
  expect(
    SourceClipper1TwoConvexUnion2.union([second, first]).points,
    expected,
  );
}

void main() {
  test('two-crossing triangles match pinned Clipper1 start and rounding', () {
    _expectUnion(
      _poly([(0, 0), (100000, 0), (50000, 100000)]),
      _poly([(25000, 25000), (125000, 25000), (75000, 125000)]),
      const [
        SourcePoint2(87500, 25000),
        SourcePoint2(125000, 25000),
        SourcePoint2(75000, 125000),
        SourcePoint2(56250, 87500),
        SourcePoint2(50000, 100000),
        SourcePoint2(0, 0),
        SourcePoint2(100000, 0),
      ],
    );
  });

  test('six-crossing triangles preserve every rounded scanline intersection', () {
    _expectUnion(
      _poly([(0, 0), (120000, 0), (60000, 120000)]),
      _poly([(60000, -40000), (140000, 80000), (-20000, 80000)]),
      const [
        SourcePoint2(86667, 0),
        SourcePoint2(120000, 0),
        SourcePoint2(105714, 28571),
        SourcePoint2(140000, 80000),
        SourcePoint2(80000, 80000),
        SourcePoint2(60000, 120000),
        SourcePoint2(40000, 80000),
        SourcePoint2(-20000, 80000),
        SourcePoint2(14286, 28571),
        SourcePoint2(0, 0),
        SourcePoint2(33333, 0),
        SourcePoint2(60000, -40000),
      ],
    );
  });

  test('diamond overlap matches pinned non-horizontal BuildResult start', () {
    _expectUnion(
      _poly([(0, 50000), (50000, 0), (100000, 50000), (50000, 100000)]),
      _poly([
        (50000, 25000),
        (100000, -25000),
        (150000, 25000),
        (100000, 75000),
      ]),
      const [
        SourcePoint2(150000, 25000),
        SourcePoint2(100000, 75000),
        SourcePoint2(87500, 62500),
        SourcePoint2(50000, 100000),
        SourcePoint2(0, 50000),
        SourcePoint2(50000, 0),
        SourcePoint2(62500, 12500),
        SourcePoint2(100000, -25000),
      ],
    );
  });

  test('four-crossing trapezoids match pinned proper convex union', () {
    _expectUnion(
      _poly([(0, 0), (120000, 0), (100000, 100000), (20000, 100000)]),
      _poly([
        (50000, -20000),
        (160000, 30000),
        (120000, 120000),
        (30000, 70000),
      ]),
      const [
        SourcePoint2(94000, 0),
        SourcePoint2(120000, 0),
        SourcePoint2(117833, 10833),
        SourcePoint2(160000, 30000),
        SourcePoint2(120000, 120000),
        SourcePoint2(84000, 100000),
        SourcePoint2(20000, 100000),
        SourcePoint2(0, 0),
        SourcePoint2(45556, 0),
        SourcePoint2(50000, -20000),
      ],
    );
  });

  test('pentagon and quadrilateral keep pinned fractional intersection casts', () {
    _expectUnion(
      _poly([
        (0, 20000),
        (40000, 0),
        (100000, 20000),
        (120000, 80000),
        (30000, 110000),
      ]),
      _poly([
        (60000, -20000),
        (140000, 10000),
        (130000, 90000),
        (50000, 90000),
      ]),
      const [
        SourcePoint2(140000, 10000),
        SourcePoint2(130000, 90000),
        SourcePoint2(90000, 90000),
        SourcePoint2(30000, 110000),
        SourcePoint2(0, 20000),
        SourcePoint2(40000, 0),
        SourcePoint2(57647, 5882),
        SourcePoint2(60000, -20000),
      ],
    );
  });

  test('mixed five-sided six-crossing oracle stays exact', () {
    _expectUnion(
      _poly([
        (0, 30000),
        (60000, -30000),
        (140000, 20000),
        (110000, 110000),
        (20000, 120000),
      ]),
      _poly([
        (30000, -50000),
        (130000, -10000),
        (160000, 60000),
        (80000, 130000),
        (-10000, 70000),
      ]),
      const [
        SourcePoint2(130000, -10000),
        SourcePoint2(160000, 60000),
        SourcePoint2(112941, 101176),
        SourcePoint2(110000, 110000),
        SourcePoint2(101818, 110909),
        SourcePoint2(80000, 130000),
        SourcePoint2(58571, 115714),
        SourcePoint2(20000, 120000),
        SourcePoint2(12174, 84783),
        SourcePoint2(-10000, 70000),
        SourcePoint2(1333, 36000),
        SourcePoint2(0, 30000),
        SourcePoint2(5000, 25000),
        SourcePoint2(30000, -50000),
      ],
    );
  });

  test('Arachne exact zero offset routes proper convex union off fallback', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [
        _poly([(0, 0), (100000, 0), (50000, 100000)]),
        _poly([(25000, 25000), (125000, 25000), (75000, 125000)]),
      ],
      0,
    );

    expect(result, hasLength(1));
    expect(
      result.single.points,
      const [
        SourcePoint2(87500, 25000),
        SourcePoint2(125000, 25000),
        SourcePoint2(75000, 125000),
        SourcePoint2(56250, 87500),
        SourcePoint2(50000, 100000),
        SourcePoint2(0, 0),
        SourcePoint2(100000, 0),
      ],
    );
  });

  test('touching convex paths stay outside proper-intersection subset', () {
    expect(
      SourceClipper1TwoConvexUnion2.supports([
        _poly([(0, 0), (100000, 0), (50000, 100000)]),
        _poly([(100000, 0), (150000, -50000), (200000, 50000)]),
      ]),
      isFalse,
    );
  });

  test('contained convex path stays on noninteracting winding helper', () {
    expect(
      SourceClipper1TwoConvexUnion2.supports([
        _poly([(0, 0), (200000, 0), (100000, 200000)]),
        _poly([(75000, 50000), (125000, 50000), (100000, 100000)]),
      ]),
      isFalse,
    );
  });
}
