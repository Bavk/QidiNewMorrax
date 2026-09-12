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

SourcePolygon2 rectangle(int minX, int minY, int maxX, int maxY) =>
    SourcePolygon2([
      SourcePoint2(minX, minY),
      SourcePoint2(maxX, minY),
      SourcePoint2(maxX, maxY),
      SourcePoint2(minX, maxY),
    ]);

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
final traversalSettings = SourceClassicPerimeterTraversalSettings2(
  externalPerimeterFlow: externalFlow,
  smallerExternalPerimeterFlow: smallerExternalFlow,
  perimeterFlow: perimeterFlow,
  layerHeight: 0.2,
);

SourceFuzzySkinNoRegionConfig2 fuzzyConfig({
  SourceFuzzySkinType2 type = SourceFuzzySkinType2.external,
  SourceFuzzyNoiseType2 noise = SourceFuzzyNoiseType2.classic,
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
  test('Classic fuzzy geometry is applied before loop wrapping', () {
    final random = ZeroDisplacementRandom();
    final root = SourcePerimeterLoop2(
      polygon: rectangle(0, 0, 200000, 200000),
      depth: 0,
      isContour: true,
    );

    final output = SourceClassicFuzzyPerimeterTraversal2.traverseNoRegion(
      loops: [root],
      thinWalls: <ThickPolyline2>[],
      settings: traversalSettings,
      fuzzyConfig: fuzzyConfig(),
      random: random,
      configuredOverhangSpeedEnabled: true,
    );

    final loop = output.single as ExtrusionLoop2;
    expect(loop.polygon().points.length, greaterThan(4));
    expect(loop.isCounterClockwise, true);
    expect(random.calls, greaterThan(0));
  });

  test('actual fuzzy mode disables intermediate slowdown grading', () {
    final root = SourcePerimeterLoop2(
      polygon: rectangle(0, 0, 200000, 200000),
      depth: 0,
      isContour: true,
    );

    final output = SourceClassicFuzzyPerimeterTraversal2.traverseNoRegion(
      loops: [root],
      thinWalls: <ThickPolyline2>[],
      settings: traversalSettings,
      fuzzyConfig: fuzzyConfig(),
      random: ZeroDisplacementRandom(),
      configuredOverhangSpeedEnabled: true,
      overhangSettings: overhangSettings(),
    );

    final loop = output.single as ExtrusionLoop2;
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
  });

  test('None identity uses the same traversal but keeps speed grading', () {
    final root = SourcePerimeterLoop2(
      polygon: rectangle(0, 0, 200000, 200000),
      depth: 0,
      isContour: true,
    );

    final output = SourceClassicFuzzyPerimeterTraversal2.traverseNoRegion(
      loops: [root],
      thinWalls: <ThickPolyline2>[],
      settings: traversalSettings,
      fuzzyConfig: fuzzyConfig(type: SourceFuzzySkinType2.none),
      random: EmptyRandom(),
      configuredOverhangSpeedEnabled: true,
      overhangSettings: overhangSettings(),
    );

    final loop = output.single as ExtrusionLoop2;
    expect(
      loop.paths.any(
        (path) => path.overhangDegree > 0 && path.overhangDegree < 5,
      ),
      true,
    );
  });

  test('children fuzzify only when recursive traversal reaches them', () {
    final child = SourcePerimeterLoop2(
      polygon: rectangle(50000, 50000, 150000, 150000),
      depth: 1,
      isContour: true,
    );
    final root = SourcePerimeterLoop2(
      polygon: rectangle(0, 0, 200000, 200000),
      depth: 0,
      isContour: true,
      children: [child],
    );
    final random = ZeroDisplacementRandom();

    final output = SourceClassicFuzzyPerimeterTraversal2.traverseNoRegion(
      loops: [root],
      thinWalls: <ThickPolyline2>[],
      settings: traversalSettings,
      fuzzyConfig: fuzzyConfig(type: SourceFuzzySkinType2.allWalls),
      random: random,
      configuredOverhangSpeedEnabled: true,
    );

    expect(output, hasLength(2));
    final inner = output.first as ExtrusionLoop2;
    final outer = output.last as ExtrusionLoop2;
    expect(inner.polygon().points.length, greaterThan(4));
    expect(outer.polygon().points.length, greaterThan(4));
    expect(random.calls, greaterThan(0));
  });

  test('required non-Classic fuzzy noise still fails before traversal output', () {
    final root = SourcePerimeterLoop2(
      polygon: rectangle(0, 0, 200000, 200000),
      depth: 0,
      isContour: true,
    );

    expect(
      () => SourceClassicFuzzyPerimeterTraversal2.traverseNoRegion(
        loops: [root],
        thinWalls: <ThickPolyline2>[],
        settings: traversalSettings,
        fuzzyConfig: fuzzyConfig(noise: SourceFuzzyNoiseType2.perlin),
        random: EmptyRandom(),
        configuredOverhangSpeedEnabled: true,
        overhangSettings: overhangSettings(),
      ),
      throwsUnsupportedError,
    );
  });
}
