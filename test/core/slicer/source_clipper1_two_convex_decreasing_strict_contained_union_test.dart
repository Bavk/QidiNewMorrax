import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths_prepare_exact.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_two_convex_contact_union.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_two_convex_decreasing_strict_contained_union.dart';

SourcePolygon2 _poly(List<(int, int)> points) => SourcePolygon2([
      for (final point in points) SourcePoint2(point.$1, point.$2),
    ]);

SourcePolygon2 _rotate(SourcePolygon2 polygon, int amount) => SourcePolygon2([
      ...polygon.points.skip(amount),
      ...polygon.points.take(amount),
    ]);

void _expectUnionForAllRotations(
  SourcePolygon2 host,
  SourcePolygon2 guest,
  List<SourcePoint2> expected,
) {
  for (var hostRotation = 0; hostRotation < 3; hostRotation++) {
    for (var guestRotation = 0; guestRotation < 3; guestRotation++) {
      final rotatedHost = _rotate(host, hostRotation);
      final rotatedGuest = _rotate(guest, guestRotation);
      for (final values in [
        [rotatedHost, rotatedGuest],
        [rotatedGuest, rotatedHost],
      ]) {
        expect(
          SourceClipper1TwoConvexDecreasingStrictContainedUnion2.supports(
            values,
          ),
          isTrue,
        );
        expect(
          SourceClipper1TwoConvexDecreasingStrictContainedUnion2.union(values)
              .points,
          expected,
        );
      }
    }
  }
}

void main() {
  final host = _poly([(0, 0), (100000, 0), (50000, 100000)]);

  test('guest third below near-host-start overlap begins at far overlap', () {
    _expectUnionForAllRotations(
      host,
      _poly([(12500, 25000), (37500, 75000), (-40000, 50000)]),
      const [
        SourcePoint2(12500, 25000),
        SourcePoint2(0, 0),
        SourcePoint2(100000, 0),
        SourcePoint2(50000, 100000),
        SourcePoint2(37500, 75000),
        SourcePoint2(-40000, 50000),
      ],
    );
  });

  test('guest third above near-host-start overlap begins at host third', () {
    _expectUnionForAllRotations(
      host,
      _poly([(12500, 25000), (37500, 75000), (-40000, 90000)]),
      const [
        SourcePoint2(100000, 0),
        SourcePoint2(50000, 100000),
        SourcePoint2(37500, 75000),
        SourcePoint2(-40000, 90000),
        SourcePoint2(12500, 25000),
        SourcePoint2(0, 0),
      ],
    );
  });

  test('equal-Y tie uses standalone host triangle BuildResult start', () {
    _expectUnionForAllRotations(
      host,
      _poly([(12500, 25000), (37500, 75000), (-40000, 75000)]),
      const [
        SourcePoint2(50000, 100000),
        SourcePoint2(37500, 75000),
        SourcePoint2(-40000, 75000),
        SourcePoint2(12500, 25000),
        SourcePoint2(0, 0),
        SourcePoint2(100000, 0),
      ],
    );
  });

  test('vertical decreasing host edge follows the same exact state rule', () {
    _expectUnionForAllRotations(
      _poly([(0, 100000), (0, 0), (100000, 50000)]),
      _poly([(0, 25000), (0, 75000), (-50000, 50000)]),
      const [
        SourcePoint2(0, 25000),
        SourcePoint2(0, 0),
        SourcePoint2(100000, 50000),
        SourcePoint2(0, 100000),
        SourcePoint2(0, 75000),
        SourcePoint2(-50000, 50000),
      ],
    );
  });

  test('Arachne zero offset routes decreasing strict-contained contact', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [
        host,
        _poly([(12500, 25000), (37500, 75000), (-40000, 50000)]),
      ],
      0,
    );

    expect(result, hasLength(1));
    expect(
      result.single.points,
      const [
        SourcePoint2(12500, 25000),
        SourcePoint2(0, 0),
        SourcePoint2(100000, 0),
        SourcePoint2(50000, 100000),
        SourcePoint2(37500, 75000),
        SourcePoint2(-40000, 50000),
      ],
    );
  });

  test('increasing-Y strict-contained state remains owned by old helper', () {
    final values = [
      _poly([(0, 0), (100000, 0), (50000, 100000)]),
      _poly([(87500, 25000), (140000, 50000), (62500, 75000)]),
    ];

    expect(
      SourceClipper1TwoConvexDecreasingStrictContainedUnion2.supports(values),
      isFalse,
    );
    expect(SourceClipper1TwoConvexContactUnion2.supports(values), isTrue);
  });

  test('endpoint-aligned overlap is not strict-contained contact', () {
    expect(
      SourceClipper1TwoConvexDecreasingStrictContainedUnion2.supports([
        _poly([(0, 0), (80000, -120000), (100000, -20000)]),
        _poly([(40000, -60000), (0, 0), (-40000, -70000)]),
      ]),
      isFalse,
    );
  });
}
