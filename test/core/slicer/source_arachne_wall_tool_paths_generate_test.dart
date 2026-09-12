import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths_generate.dart';

SourceArachneWallToolPathsParams2 _params() =>
    SourceArachneWallToolPathsParams2(
      minBeadWidthMm: 0.2,
      minFeatureSizeMm: 0.1,
      wallTransitionLengthMm: 0.4,
      wallTransitionAngleDeg: 10.0,
      wallTransitionFilterDeviationMm: 0.05,
      wallDistributionCount: 3,
    );

SourcePolygon2 _square() => SourcePolygon2(const [
      SourcePoint2(0, 0),
      SourcePoint2(1000000, 0),
      SourcePoint2(1000000, 1000000),
      SourcePoint2(0, 1000000),
    ]);

SourceArachneWallToolPathsState2 _state({
  int insetCount = 3,
  List<SourcePolygon2>? outline,
}) =>
    SourceArachneWallToolPathsState2(
      outline: outline ?? [_square()],
      beadWidth0: 40000,
      beadWidthX: 40000,
      insetCount: insetCount,
      wall0Inset: 0,
      layerHeightMm: 0.2,
      params: _params(),
    );

void main() {
  test('inset_count below one returns before prepared-outline work', () {
    final result = SourceArachneWallToolPathsGenerate2.generate(
      _state(insetCount: 0),
    );

    expect(result.toolpaths, isEmpty);
    expect(result.innerContour, isEmpty);
    expect(result.firstWallContour, isEmpty);
    expect(result.prepared, isNull);
    expect(result.skeletal, isNull);
    expect(result.toolpathsGenerated, isFalse);
  });

  test('nonpositive prepared area returns before skeletal construction', () {
    final result = SourceArachneWallToolPathsGenerate2.generate(
      _state(outline: const []),
    );

    expect(result.prepared, isNotNull);
    expect(result.prepared!.isEmptyArea, isTrue);
    expect(result.skeletal, isNull);
    expect(result.toolpaths, isEmpty);
    expect(result.toolpathsGenerated, isFalse);
  });

  test('real square executes complete WallToolPaths source order', () {
    final result = SourceArachneWallToolPathsGenerate2.generate(_state());

    expect(result.prepared, isNotNull);
    expect(result.prepared!.isEmptyArea, isFalse);
    expect(result.skeletal, isNotNull);
    expect(result.toolpathsGenerated, isTrue);
    expect(result.toolpaths, isNotEmpty);
    expect(result.toolpaths.every((inset) => inset.isNotEmpty), isTrue);

    var previousInset = -1;
    for (final inset in result.toolpaths) {
      final currentInset = inset.first.insetIndex;
      expect(currentInset, greaterThanOrEqualTo(previousInset));
      previousInset = currentInset;
      for (final line in inset) {
        expect(line.junctions, isNotEmpty);
        expect(line.insetIndex, currentInset);
        for (final junction in line.junctions) {
          expect(junction.perimeterIndex, currentInset);
        }
      }
    }
  });

  test('unchanged prepared outline preserves hole-compensation enable gate', () {
    final result = SourceArachneWallToolPathsGenerate2.generate(
      _state(),
      enableHoleCompensation: true,
    );

    expect(result.prepared, isNotNull);
    expect(result.prepared!.outlineSizeChange, isFalse);
    expect(result.prepared!.applyHoleCompensation, isTrue);
    expect(result.toolpathsGenerated, isTrue);
  });
}
