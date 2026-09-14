import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths_prepare_exact.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_two_convex_nonhorizontal_staggered_union.dart';

SourcePolygon2 _poly(List<(int, int)> points) => SourcePolygon2([
      for (final point in points) SourcePoint2(point.$1, point.$2),
    ]);

SourcePolygon2 _rotated(SourcePolygon2 polygon, int start) => SourcePolygon2([
      for (var index = 0; index < polygon.points.length; index++)
        polygon.points[(start + index) % polygon.points.length],
    ]);

void _expectExact(
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
        expect(
          SourceClipper1TwoConvexNonHorizontalStaggeredUnion2.supports(
            values,
          ),
          isTrue,
        );
        expect(
          SourceClipper1TwoConvexNonHorizontalStaggeredUnion2.union(values)
              .points,
          expected,
        );
      }
    }
  }
}

void main() {
  test('positive-slope end-overlap starts at canonical edge start', () {
    _expectExact(
      _poly([(0, 0), (80000, 120000), (-20000, 100000)]),
      _poly([(120000, 180000), (40000, 60000), (140000, 80000)]),
      const [
        SourcePoint2(0, 0),
        SourcePoint2(40000, 60000),
        SourcePoint2(140000, 80000),
        SourcePoint2(120000, 180000),
        SourcePoint2(80000, 120000),
        SourcePoint2(-20000, 100000),
      ],
    );
  });

  test('positive-slope end-overlap may start at opposite third vertex', () {
    _expectExact(
      _poly([(0, 0), (80000, 120000), (0, 130000)]),
      _poly([(120000, 180000), (40000, 60000), (120000, 50000)]),
      const [
        SourcePoint2(120000, 50000),
        SourcePoint2(120000, 180000),
        SourcePoint2(80000, 120000),
        SourcePoint2(0, 130000),
        SourcePoint2(0, 0),
        SourcePoint2(40000, 60000),
      ],
    );
  });

  test('positive-slope start-overlap starts at canonical third vertex', () {
    _expectExact(
      _poly([(0, 0), (80000, 120000), (-20000, 100000)]),
      _poly([(40000, 60000), (-40000, -60000), (60000, -40000)]),
      const [
        SourcePoint2(-20000, 100000),
        SourcePoint2(0, 0),
        SourcePoint2(-40000, -60000),
        SourcePoint2(60000, -40000),
        SourcePoint2(40000, 60000),
        SourcePoint2(80000, 120000),
      ],
    );
  });

  test('equal-Y end-overlap can start at opposite edge end', () {
    _expectExact(
      _poly([(0, 0), (80000, 120000), (-20000, 120000)]),
      _poly([(120000, 180000), (40000, 60000), (140000, 80000)]),
      const [
        SourcePoint2(40000, 60000),
        SourcePoint2(140000, 80000),
        SourcePoint2(120000, 180000),
        SourcePoint2(80000, 120000),
        SourcePoint2(-20000, 120000),
        SourcePoint2(0, 0),
      ],
    );
  });

  test('equal-Y boundary can start at opposite edge start', () {
    _expectExact(
      _poly([(0, 0), (80000, 120000), (-20000, 120000)]),
      _poly([(120000, 180000), (40000, 60000), (200000, 0)]),
      const [
        SourcePoint2(120000, 180000),
        SourcePoint2(80000, 120000),
        SourcePoint2(-20000, 120000),
        SourcePoint2(0, 0),
        SourcePoint2(40000, 60000),
        SourcePoint2(200000, 0),
      ],
    );
  });

  test('previously rejected negative-slope staggered state is exact', () {
    _expectExact(
      _poly([(-63000, -14000), (-75000, 70000), (-162000, 79000)]),
      _poly([(-79000, 98000), (-69000, 28000), (102000, 31000)]),
      const [
        SourcePoint2(102000, 31000),
        SourcePoint2(-79000, 98000),
        SourcePoint2(-75000, 70000),
        SourcePoint2(-162000, 79000),
        SourcePoint2(-63000, -14000),
        SourcePoint2(-69000, 28000),
      ],
    );
  });

  test('Arachne zero offset routes positive-slope staggered state exactly', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [
        _poly([(0, 0), (80000, 120000), (-20000, 100000)]),
        _poly([(120000, 180000), (40000, 60000), (140000, 80000)]),
      ],
      0,
    );

    expect(result, hasLength(1));
    expect(
      result.single.points,
      const [
        SourcePoint2(0, 0),
        SourcePoint2(40000, 60000),
        SourcePoint2(140000, 80000),
        SourcePoint2(120000, 180000),
        SourcePoint2(80000, 120000),
        SourcePoint2(-20000, 100000),
      ],
    );
  });

  test('horizontal staggered contact stays owned by horizontal helper', () {
    expect(
      SourceClipper1TwoConvexNonHorizontalStaggeredUnion2.supports([
        _poly([(0, 0), (120000, 0), (60000, 60000)]),
        _poly([(180000, 0), (60000, 0), (120000, -60000)]),
      ]),
      isFalse,
    );
  });

  test('endpoint-contained overlap is not staggered', () {
    expect(
      SourceClipper1TwoConvexNonHorizontalStaggeredUnion2.supports([
        _poly([(0, 0), (80000, 120000), (-20000, 100000)]),
        _poly([(80000, 120000), (40000, 60000), (120000, 50000)]),
      ]),
      isFalse,
    );
  });

  test('proper crossing remains owned by proper-convex helper', () {
    expect(
      SourceClipper1TwoConvexNonHorizontalStaggeredUnion2.supports([
        _poly([(0, 0), (100000, 0), (50000, 100000)]),
        _poly([(25000, 25000), (125000, 25000), (75000, 125000)]),
      ]),
      isFalse,
    );
  });
}
