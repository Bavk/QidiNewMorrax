import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths_prepare_exact.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_two_convex_decreasing_host_end_union.dart';

SourcePolygon2 _poly(List<(int, int)> points) => SourcePolygon2([
      for (final point in points) SourcePoint2(point.$1, point.$2),
    ]);

SourcePolygon2 _rotated(SourcePolygon2 polygon, int start) => SourcePolygon2([
      for (var index = 0; index < polygon.points.length; index++)
        polygon.points[(start + index) % polygon.points.length],
    ]);

void _expectExact(
  SourcePolygon2 host,
  SourcePolygon2 guest,
  List<SourcePoint2> expected,
) {
  for (var hostRotation = 0; hostRotation < 3; hostRotation++) {
    for (var guestRotation = 0; guestRotation < 3; guestRotation++) {
      final rotatedHost = _rotated(host, hostRotation);
      final rotatedGuest = _rotated(guest, guestRotation);
      for (final values in [
        [rotatedHost, rotatedGuest],
        [rotatedGuest, rotatedHost],
      ]) {
        expect(
          SourceClipper1TwoConvexDecreasingHostEndUnion2.supports(values),
          isTrue,
        );
        expect(
          SourceClipper1TwoConvexDecreasingHostEndUnion2.union(values).points,
          expected,
        );
      }
    }
  }
}

void main() {
  final verticalHost = _poly([
    (0, 100000),
    (0, 0),
    (100000, 50000),
  ]);

  test('guest third below overlap endpoint starts at shared host end', () {
    _expectExact(
      verticalHost,
      _poly([
        (0, 0),
        (0, 40000),
        (-80000, 20000),
      ]),
      const [
        SourcePoint2(0, 0),
        SourcePoint2(100000, 50000),
        SourcePoint2(0, 100000),
        SourcePoint2(0, 40000),
        SourcePoint2(-80000, 20000),
      ],
    );
  });

  test('guest third above overlap endpoint starts at host edge start', () {
    _expectExact(
      verticalHost,
      _poly([
        (0, 0),
        (0, 40000),
        (-80000, 60000),
      ]),
      const [
        SourcePoint2(0, 100000),
        SourcePoint2(0, 40000),
        SourcePoint2(-80000, 60000),
        SourcePoint2(0, 0),
        SourcePoint2(100000, 50000),
      ],
    );
  });

  test('equal guest and overlap Y uses standalone host triangle start', () {
    _expectExact(
      verticalHost,
      _poly([
        (0, 0),
        (0, 40000),
        (-80000, 40000),
      ]),
      const [
        SourcePoint2(100000, 50000),
        SourcePoint2(0, 100000),
        SourcePoint2(0, 40000),
        SourcePoint2(-80000, 40000),
        SourcePoint2(0, 0),
      ],
    );
  });

  test('previous unrepresented vertical host-end state is exact', () {
    _expectExact(
      _poly([
        (56000, 107000),
        (104000, 113000),
        (56000, 119000),
      ]),
      _poly([
        (20000, 115000),
        (56000, 107000),
        (56000, 113000),
      ]),
      const [
        SourcePoint2(56000, 119000),
        SourcePoint2(56000, 113000),
        SourcePoint2(20000, 115000),
        SourcePoint2(56000, 107000),
        SourcePoint2(104000, 113000),
      ],
    );
  });

  test('Arachne zero offset routes remaining decreasing host-end state exactly', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [
        verticalHost,
        _poly([
          (0, 0),
          (0, 40000),
          (-80000, 60000),
        ]),
      ],
      0,
    );

    expect(result, hasLength(1));
    expect(
      result.single.points,
      const [
        SourcePoint2(0, 100000),
        SourcePoint2(0, 40000),
        SourcePoint2(-80000, 60000),
        SourcePoint2(0, 0),
        SourcePoint2(100000, 50000),
      ],
    );
  });

  test('post-join collinear fixup state remains on compatibility seam', () {
    expect(
      SourceClipper1TwoConvexDecreasingHostEndUnion2.supports([
        verticalHost,
        _poly([
          (0, 0),
          (0, 40000),
          (-80000, -40000),
        ]),
      ]),
      isFalse,
    );
  });
}
