import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/thick_polyline.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_fuzzy_perimeter_traversal_exact.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_overhang_support.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_loop_tree.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_traversal.dart';
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

SourcePolygon2 rectangle(int minX, int minY, int maxX, int maxY) =>
    SourcePolygon2([
      SourcePoint2(minX, minY),
      SourcePoint2(maxX, minY),
      SourcePoint2(maxX, maxY),
      SourcePoint2(minX, maxY),
    ]);

final extFlow = Flow.nonBridging(
  width: 0.45,
  height: 0.2,
  nozzleDiameter: 0.4,
);
final smallFlow = extFlow.withWidth(0.35);
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
  externalPerimeterFlow: extFlow,
  smallerExternalPerimeterFlow: smallFlow,
  perimeterFlow: perimeterFlow,
  layerHeight: 0.2,
);

SourceFuzzySkinNoRegionExactConfig2 fuzzyConfig({
  SourceFuzzySkinType2 type = SourceFuzzySkinType2.external,
  bool firstLayer = true,
  SourceFuzzyNoiseTypeExact2 noise = SourceFuzzyNoiseTypeExact2.classic,
}) =>
    SourceFuzzySkinNoRegionExactConfig2(
      type: type,
      fuzzySkinFirstLayer: firstLayer,
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
  test('Classic fuzzy loop consumes both independent rng streams', () {
    final spacing = ZeroSpacing();
    final displacement = PositiveDisplacement();
    final root = SourcePerimeterLoop2(
      polygon: rectangle(0, 0, 200000, 200000),
      depth: 0,
      isContour: true,
    );

    final output = SourceClassicFuzzyPerimeterTraversalExact2.traverseNoRegion(
      loops: [root],
      thinWalls: <ThickPolyline2>[],
      settings: settings,
      fuzzyConfig: fuzzyConfig(),
      spacingRandom: spacing,
      displacementRandom: displacement,
      layerId: 1,
      configuredOverhangSpeedEnabled: true,
    );

    final loop = output.single as ExtrusionLoop2;
    expect(loop.polygon().points.length, greaterThan(4));
    expect(loop.isCounterClockwise, true);
    expect(spacing.calls, displacement.calls + 1);
    expect(spacing.calls, greaterThan(0));
  });

  test('actual fuzzy mode disables intermediate slowdown after fuzzy geometry', () {
    final root = SourcePerimeterLoop2(
      polygon: rectangle(0, 0, 200000, 200000),
      depth: 0,
      isContour: true,
    );

    final output = SourceClassicFuzzyPerimeterTraversalExact2.traverseNoRegion(
      loops: [root],
      thinWalls: <ThickPolyline2>[],
      settings: settings,
      fuzzyConfig: fuzzyConfig(),
      spacingRandom: ZeroSpacing(),
      displacementRandom: PositiveDisplacement(),
      layerId: 1,
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

  test('None identity consumes neither rng and preserves speed grading', () {
    final root = SourcePerimeterLoop2(
      polygon: rectangle(0, 0, 200000, 200000),
      depth: 0,
      isContour: true,
    );

    final output = SourceClassicFuzzyPerimeterTraversalExact2.traverseNoRegion(
      loops: [root],
      thinWalls: <ThickPolyline2>[],
      settings: settings,
      fuzzyConfig: fuzzyConfig(type: SourceFuzzySkinType2.none),
      spacingRandom: NoSpacing(),
      displacementRandom: NoDisplacement(),
      layerId: 1,
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

  test('first-layer suppression uses explicit layerId without overhang state', () {
    final root = SourcePerimeterLoop2(
      polygon: rectangle(0, 0, 200000, 200000),
      depth: 0,
      isContour: true,
    );

    final output = SourceClassicFuzzyPerimeterTraversalExact2.traverseNoRegion(
      loops: [root],
      thinWalls: <ThickPolyline2>[],
      settings: settings,
      fuzzyConfig: fuzzyConfig(firstLayer: false),
      spacingRandom: NoSpacing(),
      displacementRandom: NoDisplacement(),
      layerId: 0,
      configuredOverhangSpeedEnabled: true,
    );

    final loop = output.single as ExtrusionLoop2;
    expect(loop.polygon().points, hasLength(4));
  });

  test('required non-Classic fuzzy noise stays explicit unsupported', () {
    final root = SourcePerimeterLoop2(
      polygon: rectangle(0, 0, 200000, 200000),
      depth: 0,
      isContour: true,
    );

    expect(
      () => SourceClassicFuzzyPerimeterTraversalExact2.traverseNoRegion(
        loops: [root],
        thinWalls: <ThickPolyline2>[],
        settings: settings,
        fuzzyConfig: fuzzyConfig(noise: SourceFuzzyNoiseTypeExact2.perlin),
        spacingRandom: NoSpacing(),
        displacementRandom: NoDisplacement(),
        layerId: 1,
        configuredOverhangSpeedEnabled: true,
      ),
      throwsUnsupportedError,
    );
  });
}
