import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths_prepare_exact.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_two_convex_decreasing_host_end_union.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_two_convex_host_end_fixup_union.dart';

SourcePolygon2 _poly(List<(int, int)> points) => SourcePolygon2([
      for (final point in points) SourcePoint2(point.$1, point.$2),
    ]);

SourcePolygon2 _rotate(SourcePolygon2 polygon, int amount) => SourcePolygon2([
      ...polygon.points.skip(amount),
      ...polygon.points.take(amount),
    ]);

void _expectFixupUnion(
  SourcePolygon2 first,
  SourcePolygon2 second,
  List<SourcePoint2> expected,
) {
  for (var firstRotation = 0; firstRotation < 3; firstRotation++) {
    for (var secondRotation = 0; secondRotation < 3; secondRotation++) {
      final rotatedFirst = _rotate(first, firstRotation);
      final rotatedSecond = _rotate(second, secondRotation);
      for (final values in [
        [rotatedFirst, rotatedSecond],
        [rotatedSecond, rotatedFirst],
      ]) {
        expect(
          SourceClipper1TwoConvexHostEndFixupUnion2.supports(values),
          isTrue,
        );
        expect(
          SourceClipper1TwoConvexHostEndFixupUnion2.union(values).points,
          expected,
        );
      }
    }
  }
}

void main() {
  test('decreasing vertical host-end fixup removes shared endpoint', () {
    _expectFixupUnion(
      _poly([(0, 100000), (0, 0), (100000, 50000)]),
      _poly([(0, 0), (0, 40000), (-80000, -40000)]),
      const [
        SourcePoint2(0, 100000),
        SourcePoint2(0, 40000),
        SourcePoint2(-80000, -40000),
        SourcePoint2(100000, 50000),
      ],
    );
  });

  test('sheared decreasing host edge keeps opposite host endpoint start', () {
    _expectFixupUnion(
      _poly([(100000, 100000), (0, 0), (150000, 50000)]),
      _poly([(0, 0), (40000, 40000), (-120000, -40000)]),
      const [
        SourcePoint2(100000, 100000),
        SourcePoint2(40000, 40000),
        SourcePoint2(-120000, -40000),
        SourcePoint2(150000, 50000),
      ],
    );
  });

  test('increasing vertical host-end fixup has the same host-start rule', () {
    _expectFixupUnion(
      _poly([(0, 0), (0, 100000), (-60000, 70000)]),
      _poly([(0, 100000), (0, 20000), (60000, 130000)]),
      const [
        SourcePoint2(0, 0),
        SourcePoint2(0, 20000),
        SourcePoint2(60000, 130000),
        SourcePoint2(-60000, 70000),
      ],
    );
  });

  test('rightward horizontal host-end fixup starts at guest third', () {
    _expectFixupUnion(
      _poly([(0, 0), (80000, 0), (20000, 50000)]),
      _poly([(80000, 0), (20000, 0), (140000, -50000)]),
      const [
        SourcePoint2(140000, -50000),
        SourcePoint2(20000, 50000),
        SourcePoint2(0, 0),
        SourcePoint2(20000, 0),
      ],
    );
  });

  test('leftward horizontal host-end fixup starts at host start', () {
    _expectFixupUnion(
      _poly([(0, 0), (-80000, 0), (-140000, -50000)]),
      _poly([(-80000, 0), (-20000, 0), (-20000, 50000)]),
      const [
        SourcePoint2(0, 0),
        SourcePoint2(-20000, 0),
        SourcePoint2(-20000, 50000),
        SourcePoint2(-140000, -50000),
      ],
    );
  });

  test('Arachne zero offset routes the pinned fixup counterexample', () {
    final host = _poly([(0, 100000), (0, 0), (100000, 50000)]);
    final guest = _poly([(0, 0), (0, 40000), (-80000, -40000)]);

    expect(
      SourceClipper1TwoConvexDecreasingHostEndUnion2.supports([host, guest]),
      isFalse,
    );

    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [host, guest],
      0,
    );
    expect(result, hasLength(1));
    expect(
      result.single.points,
      const [
        SourcePoint2(0, 100000),
        SourcePoint2(0, 40000),
        SourcePoint2(-80000, -40000),
        SourcePoint2(100000, 50000),
      ],
    );
  });

  test('non-collinear host-end join stays with non-fixup helpers', () {
    expect(
      SourceClipper1TwoConvexHostEndFixupUnion2.supports([
        _poly([(0, 100000), (0, 0), (100000, 50000)]),
        _poly([(0, 0), (0, 40000), (-80000, -30000)]),
      ]),
      isFalse,
    );
  });

  test('strict-contained shared edge is not a host-end fixup state', () {
    expect(
      SourceClipper1TwoConvexHostEndFixupUnion2.supports([
        _poly([(0, 0), (100000, 0), (50000, 100000)]),
        _poly([(12500, 25000), (37500, 75000), (-40000, 50000)]),
      ]),
      isFalse,
    );
  });
}
