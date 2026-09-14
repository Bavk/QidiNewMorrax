import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths_prepare_exact.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_two_convex_contact_union.dart';

SourcePolygon2 _poly(List<(int, int)> points) => SourcePolygon2([
      for (final point in points) SourcePoint2(point.$1, point.$2),
    ]);

void _expectUnionAll(
  SourcePolygon2 first,
  SourcePolygon2 second,
  List<List<SourcePoint2>> expected,
) {
  for (final values in [
    [first, second],
    [second, first],
  ]) {
    expect(SourceClipper1TwoConvexContactUnion2.supports(values), isTrue);
    final result = SourceClipper1TwoConvexContactUnion2.unionAll(values);
    expect(result, hasLength(expected.length));
    for (var index = 0; index < expected.length; index++) {
      expect(result[index].points, expected[index]);
    }
  }
}

void main() {
  test('single vertex contact keeps two pinned BuildResult contours', () {
    _expectUnionAll(
      _poly([(0, 0), (100000, 0), (50000, 100000)]),
      _poly([(50000, 100000), (100000, 200000), (0, 200000)]),
      const [
        [
          SourcePoint2(100000, 200000),
          SourcePoint2(0, 200000),
          SourcePoint2(50000, 100000),
        ],
        [
          SourcePoint2(50000, 100000),
          SourcePoint2(0, 0),
          SourcePoint2(100000, 0),
        ],
      ],
    );
  });

  test('vertex touching an opposite edge remains two contours', () {
    _expectUnionAll(
      _poly([(0, 0), (100000, 0), (50000, 100000)]),
      _poly([(0, 100000), (100000, 100000), (50000, 200000)]),
      const [
        [
          SourcePoint2(50000, 200000),
          SourcePoint2(0, 100000),
          SourcePoint2(100000, 100000),
        ],
        [
          SourcePoint2(50000, 100000),
          SourcePoint2(0, 0),
          SourcePoint2(100000, 0),
        ],
      ],
    );
  });

  test('whole non-horizontal shared edge merges exactly', () {
    _expectUnionAll(
      _poly([(0, 0), (100000, 0), (50000, 100000)]),
      _poly([(100000, 0), (150000, 100000), (50000, 100000)]),
      const [
        [
          SourcePoint2(100000, 0),
          SourcePoint2(150000, 100000),
          SourcePoint2(50000, 100000),
          SourcePoint2(0, 0),
        ],
      ],
    );
  });

  test('strictly contained slanted shared interval keeps pinned join start', () {
    _expectUnionAll(
      _poly([(0, 0), (100000, 0), (50000, 100000)]),
      _poly([(87500, 25000), (140000, 50000), (62500, 75000)]),
      const [
        [
          SourcePoint2(0, 0),
          SourcePoint2(100000, 0),
          SourcePoint2(87500, 25000),
          SourcePoint2(140000, 50000),
          SourcePoint2(62500, 75000),
          SourcePoint2(50000, 100000),
        ],
      ],
    );
  });

  test('strictly contained horizontal shared interval is exact', () {
    _expectUnionAll(
      _poly([(0, 0), (100000, 0), (50000, 100000)]),
      _poly([(25000, 0), (50000, -80000), (75000, 0)]),
      const [
        [
          SourcePoint2(75000, 0),
          SourcePoint2(100000, 0),
          SourcePoint2(50000, 100000),
          SourcePoint2(0, 0),
          SourcePoint2(25000, 0),
          SourcePoint2(50000, -80000),
        ],
      ],
    );
  });

  test('Arachne zero offset routes represented convex contact off fallback', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [
        _poly([(0, 0), (100000, 0), (50000, 100000)]),
        _poly([(87500, 25000), (140000, 50000), (62500, 75000)]),
      ],
      0,
    );

    expect(result, hasLength(1));
    expect(
      result.single.points,
      const [
        SourcePoint2(0, 0),
        SourcePoint2(100000, 0),
        SourcePoint2(87500, 25000),
        SourcePoint2(140000, 50000),
        SourcePoint2(62500, 75000),
        SourcePoint2(50000, 100000),
      ],
    );
  });

  test('endpoint-aligned partial overlap remains outside represented subset', () {
    expect(
      SourceClipper1TwoConvexContactUnion2.supports([
        _poly([(0, 0), (100000, 0), (50000, 100000)]),
        _poly([(100000, 0), (140000, 30000), (75000, 50000)]),
      ]),
      isFalse,
    );
  });

  test('proper area crossing remains owned by proper-convex helper', () {
    expect(
      SourceClipper1TwoConvexContactUnion2.supports([
        _poly([(0, 0), (100000, 0), (50000, 100000)]),
        _poly([(25000, 25000), (125000, 25000), (75000, 125000)]),
      ]),
      isFalse,
    );
  });
}
