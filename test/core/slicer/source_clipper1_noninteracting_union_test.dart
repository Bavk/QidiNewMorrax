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
  test('NonZero subset rebases one contour plus direct hole like Clipper1', () {
    final outer = _ccwSquare(0, 0, 200000, 200000);
    final hole = _cwSquare(50000, 50000, 150000, 150000);

    expect(SourceClipper1NonInteractingUnion2.supports([outer, hole]), isTrue);
    final result = SourceClipper1NonInteractingUnion2.union([outer, hole]);

    // Exact pinned ELF union oracle: positive BuildResult starts at max-Y/max-X
    // and the direct CW hole starts at min-Y/min-X.
    expect(result, hasLength(2));
    expect(
      result[0].points,
      const [
        SourcePoint2(200000, 200000),
        SourcePoint2(0, 200000),
        SourcePoint2(0, 0),
        SourcePoint2(200000, 0),
      ],
    );
    expect(
      result[1].points,
      const [
        SourcePoint2(50000, 50000),
        SourcePoint2(50000, 150000),
        SourcePoint2(150000, 150000),
        SourcePoint2(150000, 50000),
      ],
    );
    expect(result[0].signedArea, greaterThan(0));
    expect(result[1].signedArea, lessThan(0));
  });

  test('disconnected positive roots follow pinned bottom-point result order', () {
    final left = _ccwSquare(0, 0, 50000, 50000);
    final right = _ccwSquare(100000, 0, 150000, 50000);

    expect(SourceClipper1NonInteractingUnion2.supports([left, right]), isTrue);
    final result = SourceClipper1NonInteractingUnion2.union([left, right]);

    // Exact pinned ELF union oracle emits the right root before the left one.
    expect(result, hasLength(2));
    expect(
      result[0].points,
      const [
        SourcePoint2(150000, 50000),
        SourcePoint2(100000, 50000),
        SourcePoint2(100000, 0),
        SourcePoint2(150000, 0),
      ],
    );
    expect(
      result[1].points,
      const [
        SourcePoint2(50000, 50000),
        SourcePoint2(0, 50000),
        SourcePoint2(0, 0),
        SourcePoint2(50000, 0),
      ],
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

  test('Arachne exact offset matches pinned nested-positive offset result', () {
    final outer = _ccwSquare(0, 0, 200000, 200000);
    final nested = _ccwSquare(50000, 50000, 150000, 150000);

    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [outer, nested],
      10000,
    );

    // Exact direct pinned `Slic3r::offset(Polygons, 10000.f, jtMiter, 3.)`
    // oracle: one survivor, rebased by Clipper1 BuildResult.
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