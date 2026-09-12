import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths.dart';

SourcePolygon2 polygon(List<(int, int)> points) => SourcePolygon2([
      for (final (x, y) in points) SourcePoint2(x, y),
    ]);

void main() {
  test('WallToolPaths constants preserve source double truncation quirks', () {
    expect(SourceArachneWallToolPathsPreprocess2.meshfixMaximumResolution, 49999);
    expect(SourceArachneWallToolPathsPreprocess2.meshfixMaximumDeviation, 2500);
    expect(
      SourceArachneWallToolPathsPreprocess2.meshfixMaximumExtrusionAreaDeviation,
      199999,
    );
    expect(SourceArachneWallToolPathsPreprocess2.epsilonOffset, 1249);
    expect(SourceArachneWallToolPathsPreprocess2.scaleDouble(0.01), 999);
    expect(SourceArachneWallToolPathsPreprocess2.scaleDouble(0.005), 499);
  });

  test('process_arachne params store percentage results at float32 boundary', () {
    final params = SourceArachneWallToolPathsParams2.fromProcessConfig(
      minNozzleDiameterMm: 0.4,
      minBeadWidthPercent: 25,
      minFeatureSizePercent: 50,
      wallTransitionLengthPercent: 30,
      wallTransitionAngleDeg: 10.1,
      wallTransitionFilterDeviationPercent: 5,
      wallDistributionCount: 3,
    );

    expect(params.minBeadWidthMm, 0.10000000149011612);
    expect(params.minFeatureSizeMm, 0.20000000298023224);
    expect(params.wallTransitionLengthMm, 0.11999999731779099);
    expect(params.wallTransitionFilterDeviationMm, 0.019999999552965164);
    expect(params.wallTransitionAngleDeg, 10.100000381469727);
    expect(params.wallDistributionCount, 3);
  });

  test('WallToolPaths constructor scales stored float params using float math', () {
    final params = SourceArachneWallToolPathsParams2.fromProcessConfig(
      minNozzleDiameterMm: 0.4,
      minBeadWidthPercent: 25,
      minFeatureSizePercent: 50,
      wallTransitionLengthPercent: 30,
      wallTransitionAngleDeg: 10,
      wallTransitionFilterDeviationPercent: 5,
      wallDistributionCount: 3,
    );
    final state = SourceArachneWallToolPathsState2(
      outline: [polygon([(0, 0), (100000, 0), (0, 100000)])],
      beadWidth0: 40000,
      beadWidthX: 45000,
      insetCount: 2,
      wall0Inset: 500,
      layerHeightMm: 0.2,
      params: params,
    );

    expect(state.printThinWalls, isTrue);
    expect(state.minBeadWidth, 10000);
    expect(state.minFeatureSize, 20000);
    expect(state.wallTransitionFilterDeviation, 2000);
    expect(state.smallAreaLength, 20000);
    expect(state.toolpathsGenerated, isFalse);
  });

  test('WallToolPaths simplify clears fewer than three vertices', () {
    final simplified = SourceArachneWallToolPathsPreprocess2.simplifyPolygon(
      polygon([(0, 0), (100, 0)]),
      smallestLineSegment:
          SourceArachneWallToolPathsPreprocess2.meshfixMaximumResolution,
      allowedErrorDistance:
          SourceArachneWallToolPathsPreprocess2.meshfixMaximumDeviation,
    );

    expect(simplified.points, isEmpty);
  });

  test('WallToolPaths simplify leaves a three-vertex polygon untouched', () {
    final input = polygon([(0, 0), (100000, 0), (0, 100000)]);
    final simplified = SourceArachneWallToolPathsPreprocess2.simplifyPolygon(
      input,
      smallestLineSegment:
          SourceArachneWallToolPathsPreprocess2.meshfixMaximumResolution,
      allowedErrorDistance:
          SourceArachneWallToolPathsPreprocess2.meshfixMaximumDeviation,
    );

    expect(simplified.points, input.points);
  });

  test('WallToolPaths simplify removes an exact collinear edge vertex', () {
    final simplified = SourceArachneWallToolPathsPreprocess2.simplifyPolygon(
      polygon([
        (0, 0),
        (50000, 0),
        (100000, 0),
        (100000, 100000),
        (0, 100000),
      ]),
      smallestLineSegment:
          SourceArachneWallToolPathsPreprocess2.meshfixMaximumResolution,
      allowedErrorDistance:
          SourceArachneWallToolPathsPreprocess2.meshfixMaximumDeviation,
    );

    expect(simplified.points, const [
      SourcePoint2(0, 0),
      SourcePoint2(100000, 0),
      SourcePoint2(100000, 100000),
      SourcePoint2(0, 100000),
    ]);
  });

  test('WallToolPaths 5-micron rule may delete a tiny corner deviation', () {
    final simplified = SourceArachneWallToolPathsPreprocess2.simplifyPolygon(
      polygon([
        (0, 0),
        (100, 0),
        (100000, 0),
        (100000, 100000),
        (0, 100000),
      ]),
      smallestLineSegment:
          SourceArachneWallToolPathsPreprocess2.meshfixMaximumResolution,
      allowedErrorDistance:
          SourceArachneWallToolPathsPreprocess2.meshfixMaximumDeviation,
    );

    // Pinned source treats the first 0.001 mm deviation as effectively
    // collinear and keeps the following point instead of idealizing the corner.
    expect(simplified.points, const [
      SourcePoint2(100, 0),
      SourcePoint2(100000, 0),
      SourcePoint2(100000, 100000),
      SourcePoint2(0, 100000),
    ]);
  });

  test('Polygons simplify drops paths that simplify below three points', () {
    final result = SourceArachneWallToolPathsPreprocess2.simplifyPolygons([
      polygon([(0, 0), (10, 0)]),
      polygon([(0, 0), (100000, 0), (0, 100000)]),
    ]);

    expect(result, hasLength(1));
    expect(result.single.points, const [
      SourcePoint2(0, 0),
      SourcePoint2(100000, 0),
      SourcePoint2(0, 100000),
    ]);
  });
}
