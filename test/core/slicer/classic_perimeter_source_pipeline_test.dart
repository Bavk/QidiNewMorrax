import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/expolygon.dart';
import 'package:qidi_flow_flutter/core/geometry/point.dart';
import 'package:qidi_flow_flutter/core/geometry/polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_source_pipeline.dart';
import 'package:qidi_flow_flutter/core/slicer/extrusion_entity.dart';
import 'package:qidi_flow_flutter/core/slicer/flow.dart';

Polygon2 rectangle(double minX, double minY, double maxX, double maxY) =>
    Polygon2([
      Point2(minX, minY),
      Point2(maxX, minY),
      Point2(maxX, maxY),
      Point2(minX, maxY),
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
    expect(entities.every((entity) => entity.role == ExtrusionRole.externalPerimeter), true);
    expect(entities.every((entity) => entity.length > 0), true);
    expect(result.thinWalls, hasLength(evidenceCount));
    expect(result.thinWalls.first.firstPoint, evidenceFirst);
  });
}
