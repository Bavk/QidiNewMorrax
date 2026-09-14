import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths_prepare_exact.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_two_convex_host_end_fixup_union.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_two_convex_host_start_fixup_union.dart';

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
          SourceClipper1TwoConvexHostStartFixupUnion2.supports(values),
          isTrue,
        );
        expect(
          SourceClipper1TwoConvexHostStartFixupUnion2.union(values).points,
          expected,
        );
      }
    }
  }
}

void main() {
  test('decreasing vertical host-start fixup starts at interior overlap', () {
    _expectFixupUnion(
      _poly([(0, 100000), (0, 0), (100000, 50000)]),
      _poly([(0, 60000), (0, 100000), (-100000, 150000)]),
      const [
        SourcePoint2(0, 60000),
        SourcePoint2(0, 0),
        SourcePoint2(100000, 50000),
        SourcePoint2(-100000, 150000),
      ],
    );
  });

  test('increasing vertical host-start fixup starts at host third', () {
    _expectFixupUnion(
      _poly([(0, 0), (0, 100000), (-60000, 30000)]),
      _poly([(0, 20000), (0, 0), (60000, -30000)]),
      const [
        SourcePoint2(-60000, 30000),
        SourcePoint2(60000, -30000),
        SourcePoint2(0, 20000),
        SourcePoint2(0, 100000),
      ],
    );
  });

  test('rightward horizontal host-start fixup starts at overlap', () {
    _expectFixupUnion(
      _poly([(0, 0), (80000, 0), (-60000, 50000)]),
      _poly([(20000, 0), (0, 0), (60000, -50000)]),
      const [
        SourcePoint2(20000, 0),
        SourcePoint2(80000, 0),
        SourcePoint2(-60000, 50000),
        SourcePoint2(60000, -50000),
      ],
    );
  });

  test('leftward horizontal host-start fixup starts at host third', () {
    _expectFixupUnion(
      _poly([(0, 0), (-80000, 0), (-60000, -50000)]),
      _poly([(-20000, 0), (0, 0), (60000, 50000)]),
      const [
        SourcePoint2(-60000, -50000),
        SourcePoint2(60000, 50000),
        SourcePoint2(-20000, 0),
        SourcePoint2(-80000, 0),
      ],
    );
  });

  test('fixup gateway delegates the host-start state exactly', () {
    final host = _poly([(0, 100000), (0, 0), (100000, 50000)]);
    final guest = _poly([(0, 60000), (0, 100000), (-100000, 150000)]);

    expect(
      SourceClipper1TwoConvexHostEndFixupUnion2.supports([host, guest]),
      isTrue,
    );
    expect(
      SourceClipper1TwoConvexHostEndFixupUnion2.union([host, guest]).points,
      const [
        SourcePoint2(0, 60000),
        SourcePoint2(0, 0),
        SourcePoint2(100000, 50000),
        SourcePoint2(-100000, 150000),
      ],
    );
  });

  test('Arachne zero offset routes the host-start fixup state', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [
        _poly([(0, 100000), (0, 0), (100000, 50000)]),
        _poly([(0, 60000), (0, 100000), (-100000, 150000)]),
      ],
      0,
    );

    expect(result, hasLength(1));
    expect(
      result.single.points,
      const [
        SourcePoint2(0, 60000),
        SourcePoint2(0, 0),
        SourcePoint2(100000, 50000),
        SourcePoint2(-100000, 150000),
      ],
    );
  });

  test('non-collinear host-start join stays outside fixup subset', () {
    expect(
      SourceClipper1TwoConvexHostStartFixupUnion2.supports([
        _poly([(0, 100000), (0, 0), (100000, 50000)]),
        _poly([(0, 60000), (0, 100000), (-100000, 140000)]),
      ]),
      isFalse,
    );
  });

  test('host-end fixup state is not owned by host-start helper', () {
    expect(
      SourceClipper1TwoConvexHostStartFixupUnion2.supports([
        _poly([(0, 100000), (0, 0), (100000, 50000)]),
        _poly([(0, 0), (0, 40000), (-80000, -40000)]),
      ]),
      isFalse,
    );
  });
}
