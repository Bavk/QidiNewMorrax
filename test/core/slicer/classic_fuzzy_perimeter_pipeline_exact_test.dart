import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/expolygon.dart';
import 'package:qidi_flow_flutter/core/geometry/point.dart';
import 'package:qidi_flow_flutter/core/geometry/polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_fuzzy_perimeter_pipeline_exact.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter.dart';
import 'package:qidi_flow_flutter/core/slicer/extrusion_entity.dart';
import 'package:qidi_flow_flutter/core/slicer/flow.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_apply_exact.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_geometry_exact.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_policy.dart';

class ZeroSpacing implements SourceFuzzySpacingRandom2 {
  int calls = 0;
  @override
  double nextUnit() {
    calls++;
    return 0;
  }
}

class PositiveDisplacement implements SourceFuzzyClassicDisplacementRandom2 {
  int calls = 0;
  @override
  double nextSignedUnit() {
    calls++;
    return 0.5;
  }
}

class NoSpacing implements SourceFuzzySpacingRandom2 {
  @override
  double nextUnit() => throw StateError('identity branch consumed spacing rng');
}

class NoDisplacement implements SourceFuzzyClassicDisplacementRandom2 {
  @override
  double nextSignedUnit() =>
      throw StateError('identity branch consumed displacement rng');
}

Polygon2 rectangle(double minX, double minY, double maxX, double maxY) =>
    Polygon2([
      Point2(minX, minY),
      Point2(maxX, minY),
      Point2(maxX, maxY),
      Point2(minX, maxY),
    ]);

SourcePolygon2 sourceRectangle(int minX, int minY, int maxX, int maxY) =>
    SourcePolygon2([
      SourcePoint2(minX, minY),
      SourcePoint2(maxX, minY),
      SourcePoint2(maxX, maxY),
      SourcePoint2(minX, maxY),
    ]);

final externalFlow = Flow.nonBridging(
  width: 0.4,
  height: 0.2,
  nozzleDiameter: 0.4,
);
final smallerExternalFlow = externalFlow.withWidth(0.356);
final perimeterFlow = Flow.nonBridging(
  width: 0.45,
  height: 0.2,
  nozzleDiameter: 0.4,
);
final overhangFlow = Flow.bridging(
  diameter: 0.4,
  nozzleDiameter: 0.4,
);

ClassicPerimeterResult shell(int layerId) =>
    const ClassicPerimeterShellGenerator().generate(
      [ExPolygon2(contour: rectangle(0, 0, 20, 20))],
      ClassicPerimeterSettings(
        wallLoops: 1,
        externalPerimeterWidth: 0.4,
        externalPerimeterSpacing: 0.356,
        perimeterWidth: 0.45,
        perimeterSpacing: 0.406,
      ),
      layerIndex: layerId,
    );

SourceFuzzySkinNoRegionExactConfig2 fuzzyConfig({
  SourceFuzzySkinType2 type = SourceFuzzySkinType2.external,
  bool firstLayer = true,
}) =>
    SourceFuzzySkinNoRegionExactConfig2(
      type: type,
      fuzzySkinFirstLayer: firstLayer,
      thicknessMm: 0.1,
      pointDistanceMm: 0.4,
      noiseType: SourceFuzzyNoiseTypeExact2.classic,
    );

List<ExtrusionEntity2> run({
  required int layerId,
  required SourceFuzzySkinNoRegionExactConfig2 config,
  required SourceFuzzySpacingRandom2 spacingRandom,
  required SourceFuzzyClassicDisplacementRandom2 displacementRandom,
  required bool detectOverhang,
  bool overhangSpeed = true,
}) =>
    SourceClassicFuzzyPerimeterPipelineExact2.buildNoRegion(
      result: shell(layerId),
      externalPerimeterFlow: externalFlow,
      smallerExternalPerimeterFlow: smallerExternalFlow,
      perimeterFlow: perimeterFlow,
      overhangFlow: overhangFlow,
      layerHeight: 0.2,
      layerId: layerId,
      fuzzyConfig: config,
      spacingRandom: spacingRandom,
      displacementRandom: displacementRandom,
      detectOverhangWall: detectOverhang,
      configuredOverhangSpeedEnabled: overhangSpeed,
      lowerSlices: detectOverhang
          ? [sourceRectangle(1000000, -100000, 2100000, 2100000)]
          : null,
      wallNozzleDiameter: 0.4,
    );

void main() {
  test('non-first layer fuzzifies without requiring overhang state', () {
    final spacing = ZeroSpacing();
    final displacement = PositiveDisplacement();
    final entities = run(
      layerId: 1,
      config: fuzzyConfig(firstLayer: false),
      spacingRandom: spacing,
      displacementRandom: displacement,
      detectOverhang: false,
    );

    final loop = entities.single as ExtrusionLoop2;
    expect(loop.polygon().points.length, greaterThan(4));
    expect(spacing.calls, displacement.calls + 1);
  });

  test('first-layer suppression consumes neither independent rng', () {
    final entities = run(
      layerId: 0,
      config: fuzzyConfig(firstLayer: false),
      spacingRandom: NoSpacing(),
      displacementRandom: NoDisplacement(),
      detectOverhang: false,
    );

    final loop = entities.single as ExtrusionLoop2;
    expect(loop.polygon().points, hasLength(4));
  });

  test('actual Classic fuzzy geometry disables speed grading end-to-end', () {
    final entities = run(
      layerId: 1,
      config: fuzzyConfig(),
      spacingRandom: ZeroSpacing(),
      displacementRandom: PositiveDisplacement(),
      detectOverhang: true,
    );

    final loop = entities.single as ExtrusionLoop2;
    expect(
      loop.paths
          .where((path) => path.role == ExtrusionRole.externalPerimeter)
          .every((path) => path.overhangDegree == 0),
      true,
    );
    expect(
      loop.paths.any(
        (path) => path.overhangDegree > 0 && path.overhangDegree < 5,
      ),
      false,
    );
    expect(
      loop.paths.any((path) => path.role == ExtrusionRole.overhangPerimeter),
      true,
    );
  });

  test('None identity keeps speed grading and consumes neither rng', () {
    final entities = run(
      layerId: 1,
      config: fuzzyConfig(type: SourceFuzzySkinType2.none),
      spacingRandom: NoSpacing(),
      displacementRandom: NoDisplacement(),
      detectOverhang: true,
    );

    final loop = entities.single as ExtrusionLoop2;
    expect(
      loop.paths.any(
        (path) =>
            path.role == ExtrusionRole.externalPerimeter &&
            path.overhangDegree > 0 &&
            path.overhangDegree < 5,
      ),
      true,
    );
    expect(
      loop.paths.any((path) => path.role == ExtrusionRole.overhangPerimeter),
      true,
    );
  });
}
