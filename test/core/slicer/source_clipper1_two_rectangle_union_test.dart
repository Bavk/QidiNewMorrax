import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths_prepare_exact.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_two_rectangle_union.dart';

SourcePolygon2 _rect(int minX, int minY, int maxX, int maxY) =>
    SourcePolygon2([
      SourcePoint2(minX, minY),
      SourcePoint2(maxX, minY),
      SourcePoint2(maxX, maxY),
      SourcePoint2(minX, maxY),
    ]);

void _expectUnion(
  SourcePolygon2 first,
  SourcePolygon2 second,
  List<SourcePoint2> expected,
) {
  expect(SourceClipper1TwoRectangleUnion2.supports([first, second]), isTrue);
  expect(
    SourceClipper1TwoRectangleUnion2.union([first, second]).points,
    expected,
  );
  // Pinned ELF calls proved input order does not alter these rectangle results.
  expect(
    SourceClipper1TwoRectangleUnion2.union([second, first]).points,
    expected,
  );
}

void _expectUnionAll(
  SourcePolygon2 first,
  SourcePolygon2 second,
  List<List<SourcePoint2>> expected,
) {
  expect(SourceClipper1TwoRectangleUnion2.supports([first, second]), isTrue);
  expect(
    SourceClipper1TwoRectangleUnion2.unionAll([first, second])
        .map((polygon) => polygon.points)
        .toList(),
    expected,
  );
  expect(
    SourceClipper1TwoRectangleUnion2.unionAll([second, first])
        .map((polygon) => polygon.points)
        .toList(),
    expected,
  );
}

void main() {
  test('horizontal touching rectangles match pinned BuildResult start', () {
    _expectUnion(
      _rect(0, 0, 100000, 100000),
      _rect(100000, 0, 200000, 100000),
      const [
        SourcePoint2(0, 0),
        SourcePoint2(200000, 0),
        SourcePoint2(200000, 100000),
        SourcePoint2(0, 100000),
      ],
    );
  });

  test('vertical touching rectangles match pinned BuildResult start', () {
    _expectUnion(
      _rect(0, 0, 100000, 100000),
      _rect(0, 100000, 100000, 200000),
      const [
        SourcePoint2(100000, 0),
        SourcePoint2(100000, 200000),
        SourcePoint2(0, 200000),
        SourcePoint2(0, 0),
      ],
    );
  });

  test('north-east diagonal overlap matches pinned eight-point result', () {
    _expectUnion(
      _rect(0, 0, 100000, 100000),
      _rect(50000, 50000, 150000, 150000),
      const [
        SourcePoint2(100000, 50000),
        SourcePoint2(150000, 50000),
        SourcePoint2(150000, 150000),
        SourcePoint2(50000, 150000),
        SourcePoint2(50000, 100000),
        SourcePoint2(0, 100000),
        SourcePoint2(0, 0),
        SourcePoint2(100000, 0),
      ],
    );
  });

  test('north-west diagonal overlap preserves pinned scanline start', () {
    _expectUnion(
      _rect(0, 0, 100000, 100000),
      _rect(-50000, 50000, 50000, 150000),
      const [
        SourcePoint2(100000, 100000),
        SourcePoint2(50000, 100000),
        SourcePoint2(50000, 150000),
        SourcePoint2(-50000, 150000),
        SourcePoint2(-50000, 50000),
        SourcePoint2(0, 50000),
        SourcePoint2(0, 0),
        SourcePoint2(100000, 0),
      ],
    );
  });

  test('south-east diagonal overlap preserves pinned scanline start', () {
    _expectUnion(
      _rect(0, 0, 100000, 100000),
      _rect(50000, -50000, 150000, 50000),
      const [
        SourcePoint2(150000, 50000),
        SourcePoint2(100000, 50000),
        SourcePoint2(100000, 100000),
        SourcePoint2(0, 100000),
        SourcePoint2(0, 0),
        SourcePoint2(50000, 0),
        SourcePoint2(50000, -50000),
        SourcePoint2(150000, -50000),
      ],
    );
  });

  test('south-west diagonal overlap preserves pinned scanline start', () {
    _expectUnion(
      _rect(0, 0, 100000, 100000),
      _rect(-50000, -50000, 50000, 50000),
      const [
        SourcePoint2(50000, 0),
        SourcePoint2(100000, 0),
        SourcePoint2(100000, 100000),
        SourcePoint2(0, 100000),
        SourcePoint2(0, 50000),
        SourcePoint2(-50000, 50000),
        SourcePoint2(-50000, -50000),
        SourcePoint2(50000, -50000),
      ],
    );
  });

  test('unequal east edge contact preserves pinned BuildResult start', () {
    _expectUnion(
      _rect(0, 0, 100000, 100000),
      _rect(100000, 25000, 200000, 75000),
      const [
        SourcePoint2(0, 100000),
        SourcePoint2(0, 0),
        SourcePoint2(100000, 0),
        SourcePoint2(100000, 25000),
        SourcePoint2(200000, 25000),
        SourcePoint2(200000, 75000),
        SourcePoint2(100000, 75000),
        SourcePoint2(100000, 100000),
      ],
    );
  });

  test('unequal north edge contact preserves pinned BuildResult start', () {
    _expectUnion(
      _rect(0, 0, 100000, 100000),
      _rect(25000, 100000, 75000, 200000),
      const [
        SourcePoint2(0, 0),
        SourcePoint2(100000, 0),
        SourcePoint2(100000, 100000),
        SourcePoint2(75000, 100000),
        SourcePoint2(75000, 200000),
        SourcePoint2(25000, 200000),
        SourcePoint2(25000, 100000),
        SourcePoint2(0, 100000),
      ],
    );
  });

  test('endpoint-aligned east edge contact matches pinned six-point result', () {
    _expectUnion(
      _rect(0, 0, 100000, 100000),
      _rect(100000, 0, 200000, 50000),
      const [
        SourcePoint2(0, 100000),
        SourcePoint2(0, 0),
        SourcePoint2(200000, 0),
        SourcePoint2(200000, 50000),
        SourcePoint2(100000, 50000),
        SourcePoint2(100000, 100000),
      ],
    );
  });

  test('endpoint-aligned north edge contact matches pinned six-point result', () {
    _expectUnion(
      _rect(0, 0, 100000, 100000),
      _rect(0, 100000, 50000, 200000),
      const [
        SourcePoint2(100000, 0),
        SourcePoint2(100000, 100000),
        SourcePoint2(50000, 100000),
        SourcePoint2(50000, 200000),
        SourcePoint2(0, 200000),
        SourcePoint2(0, 0),
      ],
    );
  });

  test('point-only contact preserves two pinned BuildResult contours', () {
    final first = _rect(0, 0, 100000, 100000);
    final second = _rect(100000, 100000, 200000, 200000);
    _expectUnionAll(
      first,
      second,
      const [
        [
          SourcePoint2(200000, 200000),
          SourcePoint2(100000, 200000),
          SourcePoint2(100000, 100000),
          SourcePoint2(200000, 100000),
        ],
        [
          SourcePoint2(100000, 100000),
          SourcePoint2(0, 100000),
          SourcePoint2(0, 0),
          SourcePoint2(100000, 0),
        ],
      ],
    );
    expect(
      () => SourceClipper1TwoRectangleUnion2.union([first, second]),
      throwsArgumentError,
    );
  });

  test('Arachne exact offset merges touching rectangles with pinned start', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [
        _rect(0, 0, 100000, 100000),
        _rect(100000, 0, 200000, 100000),
      ],
      10000,
    );

    // Exact direct pinned `Slic3r::offset(Polygons, 10000.f, jtMiter, 3.)`.
    expect(result, hasLength(1));
    expect(
      result.single.points,
      const [
        SourcePoint2(-10000, -10000),
        SourcePoint2(210000, -10000),
        SourcePoint2(210000, 110000),
        SourcePoint2(-10000, 110000),
      ],
    );
  });

  test('separated rectangles stay outside represented interacting subset', () {
    expect(
      SourceClipper1TwoRectangleUnion2.supports([
        _rect(0, 0, 100000, 100000),
        _rect(100001, 100001, 200000, 200000),
      ]),
      isFalse,
    );
  });
}
