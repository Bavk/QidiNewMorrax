import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/expolygon.dart';
import 'package:qidi_flow_flutter/core/geometry/point.dart';
import 'package:qidi_flow_flutter/core/geometry/polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_fill_boundary.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_fill_process.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_island_process.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_ordered_pipeline.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_wall_sequence.dart';
import 'package:qidi_flow_flutter/core/slicer/extrusion_entity.dart';
import 'package:qidi_flow_flutter/core/slicer/flow.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_apply.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_policy.dart';
import 'package:qidi_flow_flutter/core/slicer/source_loop_node.dart';
import 'package:qidi_flow_flutter/core/slicer/surface.dart';

class EmptyRandom implements SourceFuzzyUnitRandom2 {
  @override
  double nextUnit() => throw StateError('identity branch consumed random');
}

class CountingZeroRandom implements SourceFuzzyUnitRandom2 {
  int calls = 0;

  @override
  double nextUnit() {
    calls++;
    return 0;
  }
}

SourcePolygon2 sourceRectangle(
  double minX,
  double minY,
  double maxX,
  double maxY,
) =>
    SourcePolygon2([
      SourcePoint2.fromMm(minX, minY),
      SourcePoint2.fromMm(maxX, minY),
      SourcePoint2.fromMm(maxX, maxY),
      SourcePoint2.fromMm(minX, maxY),
    ]);

Surface2 surfaceBox(
  double minX,
  double minY,
  double maxX,
  double maxY,
) =>
    Surface2(
      expolygon: SourceExPolygon2(
        contour: sourceRectangle(minX, minY, maxX, maxY),
      ),
    );

Surface2 surfaceWithHole() => Surface2(
      expolygon: SourceExPolygon2(
        contour: sourceRectangle(0, 0, 20, 20),
        holes: [sourceRectangle(8, 8, 12, 12).reversed()],
      ),
    );

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

SourceClassicPerimeterOrderedPipelineSettings2 settings({
  int wallLoops = 1,
  SourceFuzzySkinType2 fuzzyType = SourceFuzzySkinType2.none,
  bool detectOverhang = false,
  SourceWallSequence2 wallSequence = SourceWallSequence2.innerOuter,
  bool zContinuous = false,
}) =>
    SourceClassicPerimeterOrderedPipelineSettings2(
      islandProcess: SourceClassicPerimeterIslandProcessSettings2(
        fillProcess: SourceClassicPerimeterFillProcessSettings2(
          perimeter: ClassicPerimeterSettings(
            wallLoops: wallLoops,
            externalPerimeterWidth: 0.4,
            externalPerimeterSpacing: 0.356,
            perimeterWidth: 0.45,
            perimeterSpacing: 0.406,
          ),
          solidInfillSpacingMm: 0.4,
          infillWallOverlap: SourceFloatOrPercent2.absolute(0),
        ),
        resolutionMm: 0.05,
        enableArcFitting: false,
        fuzzySkinType: fuzzyType,
      ),
      externalPerimeterFlow: externalFlow,
      smallerExternalPerimeterFlow: smallerExternalFlow,
      perimeterFlow: perimeterFlow,
      overhangFlow: overhangFlow,
      layerHeight: 0.2,
      sliceZMm: 0.4,
      fuzzyConfig: SourceFuzzySkinNoRegionConfig2(
        type: fuzzyType,
        fuzzySkinFirstLayer: true,
        thicknessMm: 0.1,
        pointDistanceMm: 0.4,
        noiseType: SourceFuzzyNoiseType2.classic,
      ),
      detectOverhangWall: detectOverhang,
      configuredOverhangSpeedEnabled: true,
      wallNozzleDiameter: 0.4,
      wallSequence: wallSequence,
      zDirectionOutwallSpeedContinuous: zContinuous,
    );

int collectionCenterX(ExtrusionEntityCollection2 collection) {
  final points = <SourcePoint2>[];
  collection.collectPoints(points);
  var minX = points.first.x;
  var maxX = minX;
  for (final point in points.skip(1)) {
    if (point.x < minX) minX = point.x;
    if (point.x > maxX) maxX = point.x;
  }
  return (minX + maxX) ~/ 2;
}

void main() {
  const pipeline = SourceClassicPerimeterOrderedPipeline2();

  test('chain_expolygons order is preserved as nested island collections', () {
    final result = pipeline.generate(
      surfaces: [
        surfaceBox(-1, -1, 1, 1),
        surfaceBox(29, -1, 31, 1),
        surfaceBox(9, -1, 11, 1),
      ],
      settings: settings(),
      layerIndex: 1,
      random: EmptyRandom(),
    );

    expect(
      [for (final island in result.islands) island.processed.prepared.sourceIndex],
      [1, 2, 0],
    );
    expect(result.loops.entities, hasLength(3));
    final collections = result.loops.entities
        .map((entity) => entity as ExtrusionEntityCollection2)
        .toList();
    expect(collectionCenterX(collections[0]), closeTo(3000000, 5));
    expect(collectionCenterX(collections[1]), closeTo(1000000, 5));
    expect(collectionCenterX(collections[2]), closeTo(0, 5));
  });

  test('OuterInner wall sequence is applied separately inside every island', () {
    final result = pipeline.generate(
      surfaces: [
        surfaceBox(0, 0, 20, 20),
        surfaceBox(30, 0, 50, 20),
      ],
      settings: settings(
        wallLoops: 2,
        wallSequence: SourceWallSequence2.outerInner,
      ),
      layerIndex: 1,
      random: EmptyRandom(),
    );

    expect(result.loops.entities, hasLength(2));
    for (final entity in result.loops.entities) {
      final island = entity as ExtrusionEntityCollection2;
      expect(island.entities, hasLength(2));
      expect(island.entities.first.role, ExtrusionRole.externalPerimeter);
      expect(island.entities.last.role, ExtrusionRole.perimeter);
    }
  });

  test('non-null empty lower slices drive overhang traversal per ordered island', () {
    final result = pipeline.generate(
      surfaces: [
        surfaceBox(0, 0, 20, 20),
        surfaceBox(30, 0, 50, 20),
      ],
      lowerSlices: const <ExPolygon2>[],
      settings: settings(detectOverhang: true),
      layerIndex: 1,
      random: EmptyRandom(),
    );

    for (final islandResult in result.islands) {
      final loops = islandResult.collection.entities.whereType<ExtrusionLoop2>();
      expect(loops, isNotEmpty);
      expect(
        loops.any(
          (loop) => loop.paths.any(
            (path) => path.role == ExtrusionRole.overhangPerimeter,
          ),
        ),
        isTrue,
      );
    }
  });

  test('one shared fuzzy RNG stream is consumed across ordered islands', () {
    final random = CountingZeroRandom();
    final result = pipeline.generate(
      surfaces: [
        surfaceBox(0, 0, 20, 20),
        surfaceBox(30, 0, 50, 20),
      ],
      settings: settings(fuzzyType: SourceFuzzySkinType2.external),
      layerIndex: 1,
      random: random,
    );

    expect(random.calls, greaterThan(2));
    expect(result.islands, hasLength(2));
    for (final islandResult in result.islands) {
      final loop = islandResult.collection.entities.single as ExtrusionLoop2;
      expect(loop.polygon().points.length, greaterThan(4));
    }
  });

  test('single outwall path assigns sequential QIDI loop-node ranges', () {
    final result = pipeline.generate(
      surfaces: [
        surfaceBox(-1, -1, 1, 1),
        surfaceBox(29, -1, 31, 1),
        surfaceBox(9, -1, 11, 1),
      ],
      settings: settings(zContinuous: true),
      layerIndex: 1,
      random: EmptyRandom(),
    );

    expect(result.loopNodes, hasLength(3));
    expect(
      [for (final island in result.islands) island.collection.loopNodeRange],
      [(0, 1), (1, 2), (2, 3)],
    );
    expect([for (final node in result.loopNodes) node.nodeId], [0, 1, 2]);
    expect([for (final node in result.loopNodes) node.loopId], [0, 0, 0]);
    expect(
      result.loopNodes.every(
        (node) =>
            node.nodeContour.isLoop &&
            node.nodeContour.widths.single == externalFlow.scaledWidth,
      ),
      isTrue,
    );

    final nested = result.loops.entities
        .map((entity) => entity as ExtrusionEntityCollection2)
        .toList();
    expect(
      [for (final island in nested) island.loopNodeRange],
      [(0, 1), (1, 2), (2, 3)],
    );
  });

  test('multiple outwall paths match node ids after recursive traversal order', () {
    final result = pipeline.generate(
      surfaces: [surfaceWithHole()],
      settings: settings(zContinuous: true),
      layerIndex: 1,
      random: EmptyRandom(),
    );

    final island = result.islands.single;
    expect(island.outwallPaths, hasLength(2));
    expect(result.loopNodes, hasLength(2));
    expect(island.collection.loopNodeRange, (0, 2));
    expect([for (final node in result.loopNodes) node.loopId], [0, 1]);

    // `traverse_loops()` emits a hole before its contour parent. Node creation
    // follows entity order, even though raw outwall_paths stores contour first.
    final firstSpan = result.loopNodes[0].bounds.max.x -
        result.loopNodes[0].bounds.min.x;
    final secondSpan = result.loopNodes[1].bounds.max.x -
        result.loopNodes[1].bounds.min.x;
    expect(firstSpan, lessThan(secondSpan));
  });

  test('preexisting global loop nodes shift the next source range and node id', () {
    final seedContour = SourceNodeContour2(
      points: const [SourcePoint2(0, 0), SourcePoint2(10, 0)],
      widths: const [1],
      isLoop: false,
    );
    final loopNodes = <SourceLoopNode2>[
      SourceLoopNode2(
        nodeContour: seedContour,
        nodeId: 0,
        bounds: SourceLoopNodeBounds2.fromPoints(seedContour.points),
      ),
    ];

    final result = pipeline.generate(
      surfaces: [surfaceBox(0, 0, 20, 20)],
      settings: settings(zContinuous: true),
      layerIndex: 1,
      random: EmptyRandom(),
      loopNodes: loopNodes,
    );

    expect(loopNodes, hasLength(2));
    expect(result.islands.single.collection.loopNodeRange, (1, 2));
    expect(loopNodes.last.nodeId, 1);
    expect(loopNodes.last.loopId, 0);
  });
}
