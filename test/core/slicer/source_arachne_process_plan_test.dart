import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_top_one_wall_context.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_process_plan.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths.dart';

SourcePolygon2 _square() => SourcePolygon2(const [
      SourcePoint2(0, 0),
      SourcePoint2(1000000, 0),
      SourcePoint2(1000000, 1000000),
      SourcePoint2(0, 1000000),
    ]);

SourceArachneWallToolPathsParams2 _params() =>
    SourceArachneWallToolPathsParams2(
      minBeadWidthMm: 0.2,
      minFeatureSizeMm: 0.1,
      wallTransitionLengthMm: 0.4,
      wallTransitionAngleDeg: 10.0,
      wallTransitionFilterDeviationMm: 0.05,
      wallDistributionCount: 3,
    );

SourceArachneProcessPlan2 _plan({
  int loopNumber = 2,
  int layerId = 2,
  SourceTopOneWallType2 topOneWallType = SourceTopOneWallType2.none,
  bool onlyOneWallFirstLayer = false,
  bool upperSlicesIsNull = false,
  bool applyPreciseOuterWall = false,
  int extPerimeterWidth = 40001,
  int extPerimeterSpacing = 38001,
}) =>
    SourceArachneProcessPlanner2.planAndGenerate(
      lastPolygons: [_square()],
      loopNumber: loopNumber,
      layerId: layerId,
      topOneWallType: topOneWallType,
      onlyOneWallFirstLayer: onlyOneWallFirstLayer,
      upperSlicesIsNull: upperSlicesIsNull,
      applyPreciseOuterWall: applyPreciseOuterWall,
      extPerimeterWidth: extPerimeterWidth,
      extPerimeterSpacing: extPerimeterSpacing,
      perimeterSpacing: 40000,
      layerHeightMm: 0.2,
      params: _params(),
    );

void main() {
  test('normal process branch passes loop_number plus one to WallToolPaths', () {
    final result = _plan(loopNumber: 2);

    expect(result.isOneWall, isFalse);
    expect(result.separateWallGeneration, isFalse);
    expect(result.insetCount, 3);
    expect(result.generated, isNotNull);
    expect(result.generated!.toolpathsGenerated, isTrue);
  });

  test('first-layer one-wall gate wins over requested loop count', () {
    final result = _plan(
      loopNumber: 3,
      layerId: 0,
      onlyOneWallFirstLayer: true,
    );

    expect(result.isOneWall, isTrue);
    expect(result.separateWallGeneration, isFalse);
    expect(result.insetCount, 1);
    expect(result.generated, isNotNull);
  });

  test('topmost null upper slices selects one-wall source branch', () {
    final result = _plan(
      loopNumber: 3,
      topOneWallType: SourceTopOneWallType2.topmost,
      upperSlicesIsNull: true,
    );

    expect(result.isOneWall, isTrue);
    expect(result.separateWallGeneration, isFalse);
    expect(result.insetCount, 1);
  });

  test('Alltop with non-null upper slices exposes separate-wall seam', () {
    final result = _plan(
      loopNumber: 3,
      topOneWallType: SourceTopOneWallType2.allTop,
      upperSlicesIsNull: false,
    );

    expect(result.isOneWall, isFalse);
    expect(result.separateWallGeneration, isTrue);
    expect(result.insetCount, 1);
    expect(result.generated, isNull);
  });

  test('precise outer wall inset keeps coord_t integer division order', () {
    final result = _plan(
      applyPreciseOuterWall: true,
      extPerimeterWidth: 40001,
      extPerimeterSpacing: 38000,
    );

    // Source: -coord_t(ext_perimeter_width / 2 - ext_perimeter_spacing / 2).
    expect(result.wall0Inset, -1000);
  });

  test('negative loop count skips WallToolPaths generation', () {
    final result = _plan(loopNumber: -1);

    expect(result.insetCount, 0);
    expect(result.generated, isNull);
  });
}
