import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths_prepare_exact.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_noninteracting_union.dart';

SourcePolygon2 _ccwSquare(int minX, int minY, int maxX, int maxY) =>
    SourcePolygon2([
      SourcePoint2(minX, minY),
      SourcePoint2(maxX, minY),
      SourcePoint2(maxX, maxY),
      SourcePoint2(minX, maxY),
    ]);

SourcePolygon2 _sourceStartedCcwSquare(
  int minX,
  int minY,
  int maxX,
  int maxY,
) =>
    SourcePolygon2([
      SourcePoint2(maxX, maxY),
      SourcePoint2(minX, maxY),
      SourcePoint2(minX, minY),
      SourcePoint2(maxX, minY),
    ]);

SourcePolygon2 _cwSquare(int minX, int minY, int maxX, int maxY) =>
    _ccwSquare(minX, minY, maxX, maxY).reversed();

void main() {
  test('NonZero subset preserves one contour with one direct hole', () {
    final outer = _ccwSquare(0, 0, 200000, 200000);
    final hole = _cwSquare(50000, 50000, 150000, 150000);

    expect(SourceClipper1NonInteractingUnion2.supports([outer, hole]), isTrue);
    final result = SourceClipper1NonInteractingUnion2.union([outer, hole]);

    expect(result, hasLength(2));
    expect(result[0].points, outer.points);
    expect(result[1].points, hole.points);
    expect(result[0].signedArea, greaterThan(0));
    expect(result[1].signedArea, lessThan(0));
  });

  test('NonZero subset preserves disconnected positive islands', () {
    final left = _ccwSquare(0, 0, 50000, 50000);
    final right = _ccwSquare(100000, 0, 150000, 50000);

    expect(SourceClipper1NonInteractingUnion2.supports([left, right]), isTrue);
    expect(
      SourceClipper1NonInteractingUnion2.union([left, right])
          .map((polygon) => polygon.points)
          .toList(),
      [left.points, right.points],
    );
  });

  test('nested same-sign boundary is suppressed like pinned NonZero union', () {
    final outer = _sourceStartedCcwSquare(0, 0, 200000, 200000);
    final nested = _sourceStartedCcwSquare(50000, 50000, 150000, 150000);

    expect(
      SourceClipper1NonInteractingUnion2.supports([outer, nested]),
      isTrue,
    );
    final result = SourceClipper1NonInteractingUnion2.union([outer, nested]);

    // Exact pinned ELF `Slic3r::union_(..., pftNonZero)` oracle for these two
    // nested CCW squares returns one polygon and drops the +1 -> +2 boundary.
    expect(result, hasLength(1));
    expect(
      result.single.points,
      const [
        SourcePoint2(200000, 200000),
        SourcePoint2(0, 200000),
        SourcePoint2(0, 0),
        SourcePoint2(200000, 0),
      ],
    );
  });

  test('Arachne exact offset suppresses nested positive offset boundary', () {
    final outer = _ccwSquare(0, 0, 200000, 200000);
    final nested = _ccwSquare(50000, 50000, 150000, 150000);

    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [outer, nested],
      10000,
    );

    expect(result, hasLength(1));
    expect(
      result.single.points,
      const [
        SourcePoint2(210000, 210000),
        SourcePoint2(-10000, 210000),
        SourcePoint2(-10000, -10000),
        SourcePoint2(210000, -10000),
      ],
    );
  });

  test('orphan clockwise path is rejected instead of guessing output winding', () {
    final orphan = _cwSquare(0, 0, 100000, 100000);
    expect(SourceClipper1NonInteractingUnion2.supports([orphan]), isFalse);
  });

  test('touching path boundaries stay on full boolean compatibility seam', () {
    final left = _ccwSquare(0, 0, 100000, 100000);
    final right = _ccwSquare(100000, 0, 200000, 100000);

    expect(
      SourceClipper1NonInteractingUnion2.supports([left, right]),
      isFalse,
    );
  });
}