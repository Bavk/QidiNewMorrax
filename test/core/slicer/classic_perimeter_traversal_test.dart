import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/thick_polyline.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_loop_tree.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_traversal.dart';
import 'package:qidi_flow_flutter/core/slicer/extrusion_entity.dart';
import 'package:qidi_flow_flutter/core/slicer/flow.dart';

SourcePolygon2 rectangle(
  int minX,
  int minY,
  int maxX,
  int maxY, {
  bool clockwise = false,
}) {
  final polygon = SourcePolygon2([
    SourcePoint2(minX, minY),
    SourcePoint2(maxX, minY),
    SourcePoint2(maxX, maxY),
    SourcePoint2(minX, maxY),
  ]);
  return clockwise ? polygon.reversed() : polygon;
}

SourcePolygon2 box(int min, int max, {bool clockwise = false}) =>
    rectangle(min, min, max, max, clockwise: clockwise);

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

ExtrusionLoop2 onlyLoop(List<ExtrusionEntity2> entities) =>
    entities.single as ExtrusionLoop2;

void main() {
  test('single external internal-contour uses external flow and source role', () {
    final node = SourcePerimeterLoop2(
      polygon: box(0, 100, clockwise: true),
      depth: 0,
      isContour: true,
      needCircleCompensation: true,
    );
    final output = SourceClassicPerimeterTraversal2.traverseNoOverhang(
      loops: [node],
      thinWalls: <ThickPolyline2>[],
      settings: settings,
    );

    final loop = onlyLoop(output);
    expect(loop.role, ExtrusionRole.externalPerimeter);
    expect(loop.loopRole, ExtrusionLoopRoles.contourInternalPerimeter);
    expect(loop.customizeFlag, CustomizeFlag.circleCompensation);
    expect(loop.isCounterClockwise, true);
    expect(loop.paths.single.width, extFlow.width);
    expect(loop.paths.single.mm3PerMm, closeTo(extFlow.mm3PerMm, 1e-12));
    expect(loop.paths.single.height, 0.2);
    expect(loop.paths.single.overhangDegree, 0);
    expect(loop.paths.single.curveDegree, 0);
    expect(loop.paths.single.polyline.firstPoint,
        loop.paths.single.polyline.lastPoint);
  });

  test('smaller external loop selects source smaller external Flow', () {
    final node = SourcePerimeterLoop2(
      polygon: box(0, 100),
      depth: 0,
      isContour: true,
      isSmallerWidthPerimeter: true,
    );
    final loop = onlyLoop(
      SourceClassicPerimeterTraversal2.traverseNoOverhang(
        loops: [node],
        thinWalls: <ThickPolyline2>[],
        settings: settings,
      ),
    );

    expect(loop.role, ExtrusionRole.externalPerimeter);
    expect(loop.paths.single.width, smallFlow.width);
    expect(loop.paths.single.mm3PerMm, closeTo(smallFlow.mm3PerMm, 1e-12));
  });

  test('contour children print before contour parent and carry second-wall bit', () {
    final child = SourcePerimeterLoop2(
      polygon: box(20, 80, clockwise: true),
      depth: 1,
      isContour: true,
    );
    final root = SourcePerimeterLoop2(
      polygon: box(0, 100, clockwise: true),
      depth: 0,
      isContour: true,
      children: [child],
    );

    final output = SourceClassicPerimeterTraversal2.traverseNoOverhang(
      loops: [root],
      thinWalls: <ThickPolyline2>[],
      settings: settings,
    );

    expect(output, hasLength(2));
    final childLoop = output[0] as ExtrusionLoop2;
    final rootLoop = output[1] as ExtrusionLoop2;
    expect(childLoop.role, ExtrusionRole.perimeter);
    expect(
      childLoop.loopRole,
      ExtrusionLoopRoles.contourInternalPerimeter |
          ExtrusionLoopRoles.secondPerimeter,
    );
    expect(childLoop.paths.single.width, perimeterFlow.width);
    expect(childLoop.isCounterClockwise, true);
    expect(rootLoop.loopRole, ExtrusionLoopRoles.defaultRole);
    expect(rootLoop.isCounterClockwise, true);
  });

  test('hole prints before its children and is forced clockwise', () {
    final innerContour = SourcePerimeterLoop2(
      polygon: box(40, 60, clockwise: true),
      depth: 1,
      isContour: true,
    );
    final hole = SourcePerimeterLoop2(
      polygon: box(20, 80),
      depth: 0,
      isContour: false,
      children: [innerContour],
    );
    final root = SourcePerimeterLoop2(
      polygon: box(0, 100),
      depth: 0,
      isContour: true,
      children: [hole],
    );

    final output = SourceClassicPerimeterTraversal2.traverseNoOverhang(
      loops: [root],
      thinWalls: <ThickPolyline2>[],
      settings: settings,
    );

    expect(output, hasLength(3));
    final holeLoop = output[0] as ExtrusionLoop2;
    final childLoop = output[1] as ExtrusionLoop2;
    final rootLoop = output[2] as ExtrusionLoop2;
    expect(holeLoop.loopRole, ExtrusionLoopRoles.perimeterHole);
    expect(holeLoop.isClockwise, true);
    expect(childLoop.isCounterClockwise, true);
    expect(rootLoop.isCounterClockwise, true);
  });

  test('thin walls join the same chain and are consumed at first recursion', () {
    final thinWalls = <ThickPolyline2>[
      ThickPolyline2(
        points: const [
          SourcePoint2(300, 0),
          SourcePoint2(400, 0),
        ],
        width: const [40000, 40000],
        startIsEndpoint: true,
        endIsEndpoint: true,
      ),
    ];
    final root = SourcePerimeterLoop2(
      polygon: box(0, 100),
      depth: 0,
      isContour: true,
    );

    final output = SourceClassicPerimeterTraversal2.traverseNoOverhang(
      loops: [root],
      thinWalls: thinWalls,
      settings: settings,
    );

    expect(thinWalls, isEmpty);
    expect(output, hasLength(2));
    expect(output.whereType<ExtrusionLoop2>(), hasLength(1));
    final thin = output.firstWhere((entity) => entity is! ExtrusionLoop2);
    expect(thin.role, ExtrusionRole.externalPerimeter);
    expect(thin.length, greaterThan(0));
  });

  test('active overhang detection splits paths before loop wrapping', () {
    final root = SourcePerimeterLoop2(
      polygon: box(0, 100),
      depth: 0,
      isContour: true,
      needCircleCompensation: true,
    );
    final lowerSeries = <List<SourcePolygon2>>[
      [rectangle(50, -50, 150, 150)],
    ];

    final output =
        SourceClassicPerimeterTraversal2.traverseWithoutSpeedGrading(
      loops: [root],
      thinWalls: <ThickPolyline2>[],
      settings: settings,
      overhangSettings: SourceClassicPerimeterOverhangSettings2(
        overhangFlow: overhangFlow,
        externalLowerPolygonsSeries: lowerSeries,
        smallerExternalLowerPolygonsSeries: lowerSeries,
        perimeterLowerPolygonsSeries: lowerSeries,
        layerId: 1,
      ),
    );

    final loop = onlyLoop(output);
    expect(loop.isCounterClockwise, true);
    expect(loop.paths, hasLength(3));
    expect(
      loop.paths.where((path) => path.role == ExtrusionRole.externalPerimeter),
      hasLength(1),
    );
    expect(
      loop.paths.where((path) => path.role == ExtrusionRole.overhangPerimeter),
      hasLength(2),
    );
    expect(
      loop.paths.map((path) => path.getOverhangDegree()).toSet(),
      {0, 5, 6},
    );
    expect(
      loop.paths.every(
        (path) => path.customizeFlag == CustomizeFlag.circleCompensation,
      ),
      true,
    );
  });

  test('raft-layer boundary bypasses overhang split like source condition', () {
    final root = SourcePerimeterLoop2(
      polygon: box(0, 100),
      depth: 0,
      isContour: true,
    );

    final output =
        SourceClassicPerimeterTraversal2.traverseWithoutSpeedGrading(
      loops: [root],
      thinWalls: <ThickPolyline2>[],
      settings: settings,
      overhangSettings: SourceClassicPerimeterOverhangSettings2(
        overhangFlow: overhangFlow,
        externalLowerPolygonsSeries: const [],
        smallerExternalLowerPolygonsSeries: const [],
        perimeterLowerPolygonsSeries: const [],
        layerId: 0,
        raftLayers: 0,
      ),
    );

    final loop = onlyLoop(output);
    expect(loop.paths, hasLength(1));
    expect(loop.paths.single.role, ExtrusionRole.externalPerimeter);
    expect(loop.paths.single.getOverhangDegree(), 0);
  });
}
