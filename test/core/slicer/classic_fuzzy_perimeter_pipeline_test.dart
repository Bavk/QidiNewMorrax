import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/expolygon.dart';
import 'package:qidi_flow_flutter/core/geometry/point.dart';
import 'package:qidi_flow_flutter/core/geometry/polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_fuzzy_perimeter_pipeline.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter.dart';
import 'package:qidi_flow_flutter/core/slicer/extrusion_entity.dart';
import 'package:qidi_flow_flutter/core/slicer/flow.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_apply.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_policy.dart';

class ZeroDisplacementRandom implements SourceFuzzyUnitRandom2 {
  int calls = 0;

  @override
  double nextUnit() {
    final call = calls++;
    if (call == 0) return 0;
    return call.isOdd ? 0.5 : 0;
  }
}

class EmptyRandom implements SourceFuzzyUnitRandom2 {
  @override
  double nextUnit() => throw StateError('identity branch consumed random');
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

SourceFuzzySkinNoRegionConfig2 fuzzyConfig({
  SourceFuzzySkinType2 type = SourceFuzzySkinType2.external,
  bool firstLayer = true,
}) =>
    SourceFuzzySkinNoRegionConfig2(
      type: type,
      fuzzySkinFirstLayer: firstLayer,
      thicknessMm: 0.1,
      pointDistanceMm: 0.4,
      noiseType: SourceFuzzyNoiseType2.classic,
    );

List<ExtrusionEntity2> run({
  required int layerId,
  required SourceFuzzySkinNoRegionConfig2 config,
  required SourceFuzzyUnitRandom2 random,
  required bool detectOverhang,
  bool overhangSpeed = true,
}) =>
    SourceClassicFuzzyPerimeterPipeline2.buildNoRegion(
      result: shell(layerId),
      externalPerimeterFlow: externalFlow,
      smallerExternalPerimeterFlow: smallerExternalFlow,
      perimeterFlow: perimeterFlow,
      overhangFlow: overhangFlow,
      layerHeight: 0.2,
      layerId: layerId,
      fuzzyConfig: config,
      random: random,
      detectOverhangWall: detectOverhang,
      configuredOverhangSpeedEnabled: overhangSpeed,
      lowerSlices: detectOverhang
          ? [sourceRectangle(1000000, -100000, 2100000, 2100000)]
          : null,
      wallNozzleDiameter: 0.4,
    );

void main() {
  test('non-first layer fuzzifies even when overhang detection is disabled', () {
    final random = ZeroDisplacementRandom();
    final entities = run(
      layerId: 1,
      config: fuzzyConfig(firstLayer: false),
      random: random,
      detectOverhang: false,
    );

    final loop = entities.single as ExtrusionLoop2;
    expect(loop.polygon().points.length, greaterThan(4));
    expect(random.calls, greaterThan(0));
  });

  test('first-layer suppression remains identity without consuming RNG', () {
    final entities = run(
      layerId: 0,
      config: fuzzyConfig(firstLayer: false),
      random: EmptyRandom(),
      detectOverhang: false,
    );

    final loop = entities.single as ExtrusionLoop2;
    expect(loop.polygon().points, hasLength(4));
  });

  test('actual Classic fuzzy skin disables speed grading end-to-end', () {
    final entities = run(
      layerId: 1,
      config: fuzzyConfig(),
      random: ZeroDisplacementRandom(),
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

  test('None identity leaves speed grading enabled end-to-end', () {
    final entities = run(
      layerId: 1,
      config: fuzzyConfig(type: SourceFuzzySkinType2.none),
      random: EmptyRandom(),
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
