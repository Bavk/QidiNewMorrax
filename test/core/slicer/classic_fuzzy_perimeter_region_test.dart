import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/thick_polyline.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_fuzzy_perimeter_traversal.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_overhang_support.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_loop_tree.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_traversal.dart';
import 'package:qidi_flow_flutter/core/slicer/extrusion_entity.dart';
import 'package:qidi_flow_flutter/core/slicer/flow.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_apply.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_policy.dart';

class EmptyRandom implements SourceFuzzyUnitRandom2 {
  @override
  double nextUnit() => throw StateError('identity branch consumed random');
}

class ZeroRandom implements SourceFuzzyUnitRandom2 {
  int calls = 0;

  @override
  double nextUnit() {
    calls++;
    return 0;
  }
}

SourcePolygon2 rectangle(int minX, int minY, int maxX, int maxY) =>
    SourcePolygon2([
      SourcePoint2(minX, minY),
      SourcePoint2(maxX, minY),
      SourcePoint2(maxX, maxY),
      SourcePoint2(minX, maxY),
    ]);

SourceExPolygon2 regionBox(int minX, int minY, int maxX, int maxY) =>
    SourceExPolygon2(contour: rectangle(minX, minY, maxX, maxY));

final externalFlow = Flow.nonBridging(
  width: 0.45,
  height: 0.2,
  nozzleDiameter: 0.4,
);
final smallerExternalFlow = externalFlow.withWidth(0.35);
final perimeterFlow = Flow.nonBridging(
  width: 0.5,
  height: 0.2,
  nozzleDiameter: 0.4,
);
final overhangFlow = Flow.bridging(
  diameter: 0.4,
  nozzleDiameter: 0.4,
);
final settings = SourceClassicPerimeterTraversalSettings2(
  externalPerimeterFlow: externalFlow,
  smallerExternalPerimeterFlow: smallerExternalFlow,
  perimeterFlow: perimeterFlow,
  layerHeight: 0.2,
);

SourceFuzzySkinNoRegionConfig2 fuzzyConfig({
  SourceFuzzySkinType2 type = SourceFuzzySkinType2.none,
  SourceFuzzyNoiseType2 noise = SourceFuzzyNoiseType2.perlin,
}) =>
    SourceFuzzySkinNoRegionConfig2(
      type: type,
      fuzzySkinFirstLayer: true,
      thicknessMm: 0.1,
      pointDistanceMm: 0.4,
      noiseType: noise,
    );

SourceClassicPerimeterOverhangSettings2 overhangSettings() {
  final front = [rectangle(-50000, -50000, 100000, 250000)];
  final back = [rectangle(-50000, -50000, 250000, 250000)];
  final series = [front, back];
  return SourceClassicPerimeterOverhangSettings2(
    overhangFlow: overhangFlow,
    externalLowerPolygonsSeries: series,
    smallerExternalLowerPolygonsSeries: series,
    perimeterLowerPolygonsSeries: series,
    externalOverhangDistBoundary:
        const SourceOverhangDistanceBoundary2(0, 200000),
    smallerExternalOverhangDistBoundary:
        const SourceOverhangDistanceBoundary2(0, 200000),
    perimeterOverhangDistBoundary:
        const SourceOverhangDistanceBoundary2(0, 200000),
    layerId: 1,
  );
}

void main() {
  test('nonempty perimeter regions disable None overhang speed grading', () {
    final root = SourcePerimeterLoop2(
      polygon: rectangle(0, 0, 200000, 200000),
      depth: 0,
      isContour: true,
    );
    final output = SourceClassicFuzzyPerimeterTraversal2.traverse(
      loops: [root],
      thinWalls: <ThickPolyline2>[],
      settings: settings,
      fuzzyConfig: fuzzyConfig(),
      perimeterRegions: [
        SourceFuzzySkinPerimeterRegion2(
          expolygons: [regionBox(500000, 500000, 600000, 600000)],
          config: fuzzyConfig(),
        ),
      ],
      random: EmptyRandom(),
      layerId: 1,
      sliceZMm: 0.2,
      configuredOverhangSpeedEnabled: true,
      overhangSettings: overhangSettings(),
    );

    final loop = output.single as ExtrusionLoop2;
    expect(loop.paths, isNotEmpty);
    expect(
      loop.paths.any(
        (path) => path.overhangDegree > 0 && path.overhangDegree < 5,
      ),
      false,
    );
  });

  test('painted Perlin region is applied before classic loop wrapping', () {
    final root = SourcePerimeterLoop2(
      polygon: rectangle(0, 0, 200000, 100000),
      depth: 0,
      isContour: true,
    );
    final random = ZeroRandom();
    final output = SourceClassicFuzzyPerimeterTraversal2.traverse(
      loops: [root],
      thinWalls: <ThickPolyline2>[],
      settings: settings,
      fuzzyConfig: fuzzyConfig(),
      perimeterRegions: [
        SourceFuzzySkinPerimeterRegion2(
          expolygons: [regionBox(50000, -10000, 150000, 110000)],
          config: fuzzyConfig(type: SourceFuzzySkinType2.external),
        ),
      ],
      random: random,
      layerId: 1,
      sliceZMm: 0.2,
      configuredOverhangSpeedEnabled: true,
    );

    final loop = output.single as ExtrusionLoop2;
    expect(loop.polygon().points.length, greaterThan(4));
    expect(random.calls, greaterThan(0));
  });
}
