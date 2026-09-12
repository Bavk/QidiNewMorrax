import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/expolygon.dart';
import 'package:qidi_flow_flutter/core/geometry/point.dart';
import 'package:qidi_flow_flutter/core/geometry/polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_overhang_support.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_source_pipeline.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_traversal.dart';
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

ClassicPerimeterSettings settings() => ClassicPerimeterSettings(
      wallLoops: 1,
      externalPerimeterWidth: externalFlow.width,
      externalPerimeterSpacing: externalFlow.spacing,
      perimeterWidth: perimeterFlow.width,
      perimeterSpacing: perimeterFlow.spacing,
    );

void main() {
  const generator = ClassicPerimeterShellGenerator();

  test('prebuilt speed state reaches graded paths through full pipeline', () {
    final result = generator.generate(
      [ExPolygon2(contour: rectangle(0, 0, 20, 20))],
      settings(),
      layerIndex: 1,
    );
    final lowerSeries = <List<SourcePolygon2>>[
      [sourceRectangle(-100000, -100000, 1000000, 2100000)],
      [sourceRectangle(-100000, -100000, 2100000, 2100000)],
    ];

    final entities = SourceClassicPerimeterPipeline2.buildExtrusionsWithSpeedGrading(
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
        externalOverhangDistBoundary:
            const SourceOverhangDistanceBoundary2(0, 200000),
        layerId: 1,
      ),
    );

    expect(entities, hasLength(1));
    final loop = entities.single as ExtrusionLoop2;
    expect(loop.isCounterClockwise, true);
    expect(
      loop.paths.every((path) => path.role == ExtrusionRole.externalPerimeter),
      true,
    );
    expect(loop.paths.any((path) => path.overhangDegree == 0), true);
    expect(
      loop.paths.any((path) => path.overhangDegree > 0 && path.overhangDegree < 5),
      true,
    );
    expect(
      loop.paths.every(
        (path) => path.mm3PerMm == externalFlow.mm3PerMm,
      ),
      true,
    );
  });

  test('raw lower slices produce zero graded and unsupported source bands', () {
    final result = generator.generate(
      [ExPolygon2(contour: rectangle(0, 0, 20, 20))],
      settings(),
      layerIndex: 1,
    );

    final entities = SourceClassicPerimeterPipeline2
        .buildExtrusionsFromLowerSlicesWithSpeedGrading(
      result: result,
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
      loop.paths.any(
        (path) =>
            path.role == ExtrusionRole.externalPerimeter &&
            path.overhangDegree > 0 &&
            path.overhangDegree < 5,
      ),
      true,
    );
    for (final path in loop.paths) {
      if (path.role == ExtrusionRole.overhangPerimeter) {
        expect(path.mm3PerMm, closeTo(overhangFlow.mm3PerMm, 1e-12));
        expect(path.width, overhangFlow.width);
        expect(path.height, overhangFlow.height);
      } else {
        expect(path.mm3PerMm, closeTo(externalFlow.mm3PerMm, 1e-12));
        expect(path.width, externalFlow.width);
        expect(path.height, 0.2);
      }
    }
  });
}
