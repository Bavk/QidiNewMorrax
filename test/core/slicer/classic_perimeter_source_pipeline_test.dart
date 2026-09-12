import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/expolygon.dart';
import 'package:qidi_flow_flutter/core/geometry/point.dart';
import 'package:qidi_flow_flutter/core/geometry/polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_source_pipeline.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_traversal.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_wall_sequence.dart';
import 'package:qidi_flow_flutter/core/slicer/extrusion_entity.dart';
import 'package:qidi_flow_flutter/core/slicer/flow.dart';

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

ClassicPerimeterSettings settings({
  int wallLoops = 2,
  bool detectThinWall = false,
}) =>
    ClassicPerimeterSettings(
      wallLoops: wallLoops,
      externalPerimeterWidth: externalFlow.width,
      externalPerimeterSpacing: externalFlow.spacing,
      perimeterWidth: perimeterFlow.width,
      perimeterSpacing: perimeterFlow.spacing,
      externalPerimeterFlow: detectThinWall ? externalFlow : null,
      detectThinWall: detectThinWall,
    );

void main() {
  const generator = ClassicPerimeterShellGenerator();

  test('two-wall shell becomes nested source tree and inner-before-outer output', () {
    final result = generator.generate(
      [ExPolygon2(contour: rectangle(0, 0, 20, 20))],
      settings(),
      layerIndex: 0,
    );

    final roots = SourceClassicPerimeterPipeline2.buildLoopTree(result);
    expect(roots, hasLength(1));
    expect(roots.single.depth, 0);
    expect(roots.single.isContour, true);
    expect(roots.single.children, hasLength(1));
    expect(roots.single.children.single.depth, 1);
    expect(roots.single.children.single.isContour, true);

    final entities = SourceClassicPerimeterPipeline2.buildNoOverhangExtrusions(
      result: result,
      externalPerimeterFlow: externalFlow,
      smallerExternalPerimeterFlow: smallerExternalFlow,
      perimeterFlow: perimeterFlow,
      layerHeight: 0.2,
    );

    expect(entities, hasLength(2));
    final inner = entities[0] as ExtrusionLoop2;
    final outer = entities[1] as ExtrusionLoop2;
    expect(inner.role, ExtrusionRole.perimeter);
    expect(inner.paths.single.width, perimeterFlow.width);
    expect(inner.isCounterClockwise, true);
    expect(
      inner.loopRole,
      ExtrusionLoopRoles.contourInternalPerimeter |
          ExtrusionLoopRoles.secondPerimeter,
    );
    expect(outer.role, ExtrusionRole.externalPerimeter);
    expect(outer.paths.single.width, externalFlow.width);
    expect(outer.isCounterClockwise, true);
  });

  test('outer-inner wall sequence is applied after traversal', () {
    final result = generator.generate(
      [ExPolygon2(contour: rectangle(0, 0, 20, 20))],
      settings(),
      layerIndex: 1,
    );

    final entities = SourceClassicPerimeterPipeline2.buildNoOverhangExtrusions(
      result: result,
      externalPerimeterFlow: externalFlow,
      smallerExternalPerimeterFlow: smallerExternalFlow,
      perimeterFlow: perimeterFlow,
      layerHeight: 0.2,
      wallSequence: SourceWallSequence2.outerInner,
      layerId: 1,
    );

    expect(entities, hasLength(2));
    expect(entities[0].role, ExtrusionRole.externalPerimeter);
    expect(entities[1].role, ExtrusionRole.perimeter);
    expect((entities[0] as ExtrusionLoop2).isCounterClockwise, true);
    expect((entities[1] as ExtrusionLoop2).isCounterClockwise, true);
  });

  test('outer-only brim forces outer-first ordering on first layer', () {
    final result = generator.generate(
      [ExPolygon2(contour: rectangle(0, 0, 20, 20))],
      settings(),
      layerIndex: 0,
    );

    final entities = SourceClassicPerimeterPipeline2.buildNoOverhangExtrusions(
      result: result,
      externalPerimeterFlow: externalFlow,
      smallerExternalPerimeterFlow: smallerExternalFlow,
      perimeterFlow: perimeterFlow,
      layerHeight: 0.2,
      wallSequence: SourceWallSequence2.innerOuter,
      layerId: 0,
      brimOuterOnly: true,
      brimWidth: 5,
    );

    expect(entities, hasLength(2));
    expect(entities[0].role, ExtrusionRole.externalPerimeter);
    expect(entities[1].role, ExtrusionRole.perimeter);
  });

  test('inner-outer-inner places source second wall after external wall', () {
    final result = generator.generate(
      [ExPolygon2(contour: rectangle(0, 0, 30, 30))],
      settings(wallLoops: 3),
      layerIndex: 1,
    );

    final entities = SourceClassicPerimeterPipeline2.buildNoOverhangExtrusions(
      result: result,
      externalPerimeterFlow: externalFlow,
      smallerExternalPerimeterFlow: smallerExternalFlow,
      perimeterFlow: perimeterFlow,
      layerHeight: 0.2,
      wallSequence: SourceWallSequence2.innerOuterInner,
      layerId: 1,
    );

    expect(entities, hasLength(3));
    expect(entities.map((entity) => entity.role), [
      ExtrusionRole.perimeter,
      ExtrusionRole.externalPerimeter,
      ExtrusionRole.perimeter,
    ]);
    final secondWall = entities[2] as ExtrusionLoop2;
    expect(
      secondWall.loopRole & ExtrusionLoopRoles.secondPerimeter,
      ExtrusionLoopRoles.secondPerimeter,
    );
  });

  test('shell hole is reconstructed as child and prints before contour', () {
    final hole = rectangle(5, 5, 15, 15).reversed();
    final result = generator.generate(
      [
        ExPolygon2(
          contour: rectangle(0, 0, 20, 20),
          holes: [hole],
        ),
      ],
      settings(wallLoops: 1),
      layerIndex: 0,
    );

    final roots = SourceClassicPerimeterPipeline2.buildLoopTree(result);
    expect(roots, hasLength(1));
    expect(roots.single.children, hasLength(1));
    expect(roots.single.children.single.isContour, false);

    final entities = SourceClassicPerimeterPipeline2.buildNoOverhangExtrusions(
      result: result,
      externalPerimeterFlow: externalFlow,
      smallerExternalPerimeterFlow: smallerExternalFlow,
      perimeterFlow: perimeterFlow,
      layerHeight: 0.2,
    );

    expect(entities, hasLength(2));
    final holeLoop = entities[0] as ExtrusionLoop2;
    final contourLoop = entities[1] as ExtrusionLoop2;
    expect(holeLoop.loopRole, ExtrusionLoopRoles.perimeterHole);
    expect(holeLoop.isClockwise, true);
    expect(contourLoop.isCounterClockwise, true);
  });

  test('thin-wall-only pipeline consumes a clone and preserves raw evidence', () {
    final result = generator.generate(
      [ExPolygon2(contour: rectangle(0, 0, 10, 0.3))],
      settings(wallLoops: 1, detectThinWall: true),
      layerIndex: 0,
    );

    expect(result.loops, isEmpty);
    expect(result.thinWalls, isNotEmpty);
    final evidenceCount = result.thinWalls.length;
    final evidenceFirst = result.thinWalls.first.firstPoint;

    final entities = SourceClassicPerimeterPipeline2.buildNoOverhangExtrusions(
      result: result,
      externalPerimeterFlow: externalFlow,
      smallerExternalPerimeterFlow: smallerExternalFlow,
      perimeterFlow: perimeterFlow,
      layerHeight: 0.2,
    );

    expect(entities, isNotEmpty);
    expect(
      entities.every((entity) => entity.role == ExtrusionRole.externalPerimeter),
      true,
    );
    expect(entities.every((entity) => entity.length > 0), true);
    expect(result.thinWalls, hasLength(evidenceCount));
    expect(result.thinWalls.first.firstPoint, evidenceFirst);
  });

  test('overhang-aware pipeline carries split paths through shell traversal', () {
    final result = generator.generate(
      [ExPolygon2(contour: rectangle(0, 0, 20, 20))],
      settings(wallLoops: 1),
      layerIndex: 1,
    );
    final lowerSeries = <List<SourcePolygon2>>[
      [sourceRectangle(1000000, -100000, 2100000, 2100000)],
    ];

    final entities =
        SourceClassicPerimeterPipeline2.buildExtrusionsWithoutSpeedGrading(
      result: result,
      externalPerimeterFlow: externalFlow,
      smallerExternalPerimeterFlow: smallerExternalFlow,
      perimeterFlow: perimeterFlow,
      layerHeight: 0.2,
      overhangSettings: SourceClassicPerimeterOverhangSettings2(
        overhangFlow: overhangFlow,
        externalLowerPolygonsSeries: lowerSeries,
        smallerExternalLowerPolygonsSeries: lowerSeries,
        perimeterLowerPolygonsSeries: lowerSeries,
        layerId: 1,
      ),
    );

    expect(entities, hasLength(1));
    final loop = entities.single as ExtrusionLoop2;
    expect(loop.isCounterClockwise, true);
    expect(
      loop.paths.any((path) => path.role == ExtrusionRole.externalPerimeter),
      true,
    );
    expect(
      loop.paths.any((path) => path.role == ExtrusionRole.overhangPerimeter),
      true,
    );
    expect(
      loop.paths
          .where((path) => path.role == ExtrusionRole.overhangPerimeter)
          .every((path) => path.mm3PerMm == overhangFlow.mm3PerMm),
      true,
    );
  });
}
