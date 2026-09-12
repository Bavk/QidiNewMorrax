import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/expolygon.dart';
import 'package:qidi_flow_flutter/core/geometry/point.dart';
import 'package:qidi_flow_flutter/core/geometry/polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_source_pipeline.dart';
import 'package:qidi_flow_flutter/core/slicer/extrusion_entity.dart';
import 'package:qidi_flow_flutter/core/slicer/flow.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_policy.dart';

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

ClassicPerimeterResult shell() => const ClassicPerimeterShellGenerator().generate(
      [ExPolygon2(contour: rectangle(0, 0, 20, 20))],
      ClassicPerimeterSettings(
        wallLoops: 1,
        externalPerimeterWidth: 0.4,
        externalPerimeterSpacing: 0.356,
        perimeterWidth: 0.45,
        perimeterSpacing: 0.406,
      ),
      layerIndex: 1,
    );

List<ExtrusionEntity2> runPolicy({
  required bool overhangSpeed,
  required SourceFuzzySkinType2 fuzzyType,
  bool firstLayer = true,
  bool regionsEmpty = true,
}) =>
    SourceClassicPerimeterPipeline2.buildExtrusionsFromLowerSlicesWithFuzzyPolicy(
      result: shell(),
      externalPerimeterFlow: externalFlow,
      smallerExternalPerimeterFlow: smallerExternalFlow,
      perimeterFlow: perimeterFlow,
      overhangFlow: overhangFlow,
      layerHeight: 0.2,
      lowerSlices: [
        sourceRectangle(1000000, -100000, 2100000, 2100000),
      ],
      wallNozzleDiameter: 0.4,
      layerId: 1,
      configuredOverhangSpeedEnabled: overhangSpeed,
      fuzzySkinType: fuzzyType,
      fuzzySkinFirstLayer: firstLayer,
      perimeterRegionsEmpty: regionsEmpty,
    );

void main() {
  test('None plus enabled slowdown selects graded source branch', () {
    final entities = runPolicy(
      overhangSpeed: true,
      fuzzyType: SourceFuzzySkinType2.none,
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

  test('None plus disabled process slowdown selects no-speed source branch', () {
    final entities = runPolicy(
      overhangSpeed: false,
      fuzzyType: SourceFuzzySkinType2.none,
    );

    final loop = entities.single as ExtrusionLoop2;
    final supported = loop.paths
        .where((path) => path.role == ExtrusionRole.externalPerimeter)
        .toList(growable: false);
    expect(supported, isNotEmpty);
    expect(supported.every((path) => path.overhangDegree == 0), true);
    expect(
      loop.paths.any((path) => path.role == ExtrusionRole.overhangPerimeter),
      true,
    );
  });

  test('Disabled_fuzzy identity can still select graded source branch', () {
    final entities = runPolicy(
      overhangSpeed: true,
      fuzzyType: SourceFuzzySkinType2.disabledFuzzy,
    );

    final loop = entities.single as ExtrusionLoop2;
    expect(
      loop.paths.any(
        (path) => path.overhangDegree > 0 && path.overhangDegree < 5,
      ),
      true,
    );
  });

  test('actual External fuzzy geometry is rejected until geometry port exists', () {
    expect(
      () => runPolicy(
        overhangSpeed: true,
        fuzzyType: SourceFuzzySkinType2.external,
      ),
      throwsUnsupportedError,
    );
  });

  test('painted perimeter regions are rejected until LineSegmentation exists', () {
    expect(
      () => runPolicy(
        overhangSpeed: true,
        fuzzyType: SourceFuzzySkinType2.none,
        regionsEmpty: false,
      ),
      throwsUnsupportedError,
    );
  });

  test('composed slowdown helper matches source boolean expression', () {
    expect(
      SourceFuzzySkinPolicy2.enablesOverhangSpeed(
        configuredOverhangSpeedEnabled: true,
        type: SourceFuzzySkinType2.none,
        perimeterRegionsEmpty: true,
      ),
      true,
    );
    expect(
      SourceFuzzySkinPolicy2.enablesOverhangSpeed(
        configuredOverhangSpeedEnabled: true,
        type: SourceFuzzySkinType2.none,
        perimeterRegionsEmpty: false,
      ),
      false,
    );
    expect(
      SourceFuzzySkinPolicy2.enablesOverhangSpeed(
        configuredOverhangSpeedEnabled: false,
        type: SourceFuzzySkinType2.disabledFuzzy,
        perimeterRegionsEmpty: false,
      ),
      false,
    );
  });
}
