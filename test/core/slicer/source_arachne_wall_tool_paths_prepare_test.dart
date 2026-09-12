import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths_prepare.dart';

SourcePolygon2 polygon(List<(int, int)> points) => SourcePolygon2([
      for (final (x, y) in points) SourcePoint2(x, y),
    ]);

SourceArachneWallToolPathsState2 stateFor(
  List<SourcePolygon2> outline, {
  int beadWidth0 = 40000,
}) =>
    SourceArachneWallToolPathsState2(
      outline: outline,
      beadWidth0: beadWidth0,
      beadWidthX: 45000,
      insetCount: 2,
      wall0Inset: 0,
      layerHeightMm: 0.2,
      params: SourceArachneWallToolPathsParams2(
        minBeadWidthMm: 0.1,
        minFeatureSizeMm: 0.2,
        wallTransitionLengthMm: 0.12,
        wallTransitionAngleDeg: 10,
        wallTransitionFilterDeviationMm: 0.02,
        wallDistributionCount: 3,
      ),
    );

void main() {
  test('SquareGrid source 2mm cell preserves scaled truncation quirk', () {
    expect(SourceArachneWallToolPathsPrepare2.sourceGridSize, 199999);
  });

  test('source-unit miter offset stays in integer coordinate domain', () {
    final result = SourceArachneWallToolPathsPrepare2.offsetPolygons([
      polygon([(0, 0), (100000, 0), (100000, 100000), (0, 100000)]),
    ], 100);

    expect(result, hasLength(1));
    expect(result.single.points.toSet(), const {
      SourcePoint2(-100, -100),
      SourcePoint2(100100, -100),
      SourcePoint2(100100, 100100),
      SourcePoint2(-100, 100100),
    });
  });

  test('fixSelfIntersections epsilon below one keeps discarded simplify quirk', () {
    final input = polygon([(0, 0), (100, 100), (0, 100), (100, 0)]);
    final result = SourceArachneWallToolPathsPrepare2.fixSelfIntersections(
      [input],
      0,
    );

    expect(result.single.points, input.points);
  });

  test('fixSelfIntersections moves near point by source half-epsilon vector', () {
    final result = SourceArachneWallToolPathsPrepare2.fixSelfIntersections(
      [
        polygon([
          (50000, 5),
          (50000, 100000),
          (150000, 100000),
        ]),
        polygon([
          (0, 0),
          (100000, 0),
          (100000, -100000),
          (0, -100000),
        ]),
      ],
      SourceArachneWallToolPathsPreprocess2.epsilonOffset,
    );

    // epsilon=1249 -> half_epsilon=625 -> move_dist=623. The external
    // horizontal segment points right and the triangle's next point is left of
    // that line, so the source normal moves the query point upward by 623.
    expect(result.first.points.first, const SourcePoint2(50000, 628));
  });

  test('removeDegenerateVerts erases exact backtracking spike', () {
    final result =
        SourceArachneWallToolPathsPrepare2.removeDegenerateVertices([
      polygon([
        (0, 0),
        (100, 0),
        (0, 0),
        (0, 100),
        (-100, 100),
        (-100, 0),
      ]),
    ]);

    expect(result, hasLength(1));
    expect(result.single.points, const [
      SourcePoint2(0, 0),
      SourcePoint2(0, 100),
      SourcePoint2(-100, 100),
      SourcePoint2(-100, 0),
    ]);
  });

  test('removeColinearEdges removes source straight middle vertex', () {
    final result = SourceArachneWallToolPathsPrepare2.removeColinearEdges(
      [
        polygon([
          (0, 0),
          (50000, 0),
          (100000, 0),
          (100000, 100000),
          (0, 100000),
        ]),
      ],
      maxDeviationAngle: 0.005,
    );

    expect(result.single.points, const [
      SourcePoint2(0, 0),
      SourcePoint2(100000, 0),
      SourcePoint2(100000, 100000),
      SourcePoint2(0, 100000),
    ]);
  });

  test('removeSmallAreas preserves pinned copied-small-hole bookkeeping', () {
    final result = SourceArachneWallToolPathsPrepare2.removeSmallAreas(
      [
        polygon([(0, 0), (100, 0), (100, 100), (0, 100)]),
        polygon([(200, 0), (205, 0), (205, 5), (200, 5)]),
        // Clockwise six-unit-area hole inside the small removed outline.
        polygon([(202, 1), (202, 4), (204, 4), (204, 1)]),
      ],
      100,
      removeHoles: false,
    );

    expect(result, hasLength(1));
    expect(result.single.points, const [
      SourcePoint2(0, 0),
      SourcePoint2(100, 0),
      SourcePoint2(100, 100),
      SourcePoint2(0, 100),
    ]);
  });

  test('prepared-outline source chain keeps a clean square and compensation', () {
    final input = polygon([
      (0, 0),
      (1000000, 0),
      (1000000, 1000000),
      (0, 1000000),
    ]);
    final result = SourceArachneWallToolPathsPrepare2.prepare(
      stateFor([input]),
      enableHoleCompensation: true,
      holeIndices: const [2, 5],
    );

    expect(result.isEmptyArea, isFalse);
    expect(result.outlineSizeChange, isFalse);
    expect(result.applyHoleCompensation, isTrue);
    expect(result.holeIndices, const [2, 5]);
    expect(result.preparedOutline, hasLength(1));
    expect(result.preparedOutline.single.points.toSet(), input.points.toSet());
  });

  test('prepared-outline size change disables source hole compensation', () {
    final tiny = polygon([
      (0, 0),
      (10000, 0),
      (10000, 10000),
      (0, 10000),
    ]);
    final result = SourceArachneWallToolPathsPrepare2.prepare(
      stateFor([tiny]),
      enableHoleCompensation: true,
      holeIndices: const [0],
    );

    expect(result.preparedOutline, isEmpty);
    expect(result.isEmptyArea, isTrue);
    expect(result.outlineSizeChange, isTrue);
    expect(result.applyHoleCompensation, isFalse);
  });
}
