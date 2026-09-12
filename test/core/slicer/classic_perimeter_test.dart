import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/expolygon.dart';
import 'package:qidi_flow_flutter/core/geometry/point.dart';
import 'package:qidi_flow_flutter/core/geometry/polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter.dart';
import 'package:qidi_flow_flutter/core/slicer/extrusion_entity.dart';
import 'package:qidi_flow_flutter/core/slicer/flow.dart';

Polygon2 rectangle(double width, double height) => Polygon2([
      const Point2(0, 0),
      Point2(width, 0),
      Point2(width, height),
      Point2(0, height),
    ]);

Polygon2 square(double size) => rectangle(size, size);

void main() {
  const generator = ClassicPerimeterShellGenerator();

  test('ports classic perimeter onion-shell inset distances for equal flows', () {
    final result = generator.generate(
      [ExPolygon2(contour: square(20))],
      const ClassicPerimeterSettings(
        wallLoops: 2,
        externalPerimeterWidth: 0.4,
        externalPerimeterSpacing: 0.4,
        perimeterWidth: 0.4,
        perimeterSpacing: 0.4,
      ),
      layerIndex: 0,
    );

    expect(result.effectiveLoopCount, 2);
    expect(result.loops, hasLength(2));
    expect(result.thinWalls, isEmpty);
    expect(result.thinWallExtrusions, isEmpty);

    final outerBounds = result.loops[0].expolygon.contour.bounds;
    expect(outerBounds.min.x, closeTo(0.2, 2e-5));
    expect(outerBounds.min.y, closeTo(0.2, 2e-5));
    expect(outerBounds.max.x, closeTo(19.8, 2e-5));
    expect(outerBounds.max.y, closeTo(19.8, 2e-5));

    final innerBounds = result.loops[1].expolygon.contour.bounds;
    expect(innerBounds.min.x, closeTo(0.6, 3e-5));
    expect(innerBounds.min.y, closeTo(0.6, 3e-5));
    expect(innerBounds.max.x, closeTo(19.4, 3e-5));
    expect(innerBounds.max.y, closeTo(19.4, 3e-5));
  });

  test('alternate extra wall increments requested loops on odd layers', () {
    const settings = ClassicPerimeterSettings(
      wallLoops: 2,
      externalPerimeterWidth: 0.4,
      externalPerimeterSpacing: 0.4,
      perimeterWidth: 0.4,
      perimeterSpacing: 0.4,
      alternateExtraWall: true,
    );

    final even = generator.generate(
      [ExPolygon2(contour: square(20))],
      settings,
      layerIndex: 0,
    );
    final odd = generator.generate(
      [ExPolygon2(contour: square(20))],
      settings,
      layerIndex: 1,
    );

    expect(even.effectiveLoopCount, 2);
    expect(odd.effectiveLoopCount, 3);
  });

  test('QIDI smaller-width outer loop is not fed into inner loop generation', () {
    final result = generator.generate(
      [ExPolygon2(contour: rectangle(10, 0.5))],
      const ClassicPerimeterSettings(
        wallLoops: 2,
        externalPerimeterWidth: 0.4,
        externalPerimeterSpacing: 0.4,
        perimeterWidth: 0.4,
        perimeterSpacing: 0.4,
      ),
      layerIndex: 0,
    );

    expect(result.effectiveLoopCount, 1);
    expect(result.loops, hasLength(1));
    expect(result.loops.single.depth, 0);
    expect(result.loops.single.usesSmallerExternalWidth, true);
    expect(result.innerRegion, isEmpty);
  });

  test('detect_thin_wall converts medial-axis output with ext perimeter flow', () {
    final externalFlow = Flow.nonBridging(
      width: 0.4,
      height: 0.2,
      nozzleDiameter: 0.4,
    );
    final result = generator.generate(
      [ExPolygon2(contour: rectangle(10, 0.3))],
      ClassicPerimeterSettings(
        wallLoops: 1,
        externalPerimeterWidth: 0.4,
        externalPerimeterSpacing: 0.4,
        perimeterWidth: 0.4,
        perimeterSpacing: 0.4,
        externalPerimeterFlow: externalFlow,
        detectThinWall: true,
      ),
      layerIndex: 0,
    );

    // The normal external shell collapses, exactly the case for which source
    // `process_classic()` extracts the remaining area and runs medial_axis().
    expect(result.loops, isEmpty);
    expect(result.effectiveLoopCount, 0);
    expect(result.thinWalls, isNotEmpty);
    expect(result.thinWallExtrusions, isNotEmpty);

    final sourceMinWidth = Slic3rUnits.scaleTruncated(0.4 / 3.0);
    final sourceMaxWidth = Slic3rUnits.scaleTruncated(0.8);
    for (final polyline in result.thinWalls) {
      expect(polyline.points.length, greaterThanOrEqualTo(2));
      expect(polyline.width.length, 2 * polyline.points.length - 2);
      for (final width in polyline.width) {
        expect(width, greaterThanOrEqualTo(sourceMinWidth.toDouble()));
        expect(width, lessThanOrEqualTo(sourceMaxWidth.toDouble()));
      }
    }

    for (final entity in result.thinWallExtrusions) {
      expect(entity.role, ExtrusionRole.externalPerimeter);
      expect(entity.length, greaterThan(0));
      expect(entity.minMm3PerMm, greaterThan(0));
      if (entity is ExtrusionPath2) {
        expect(entity.height, externalFlow.height);
        expect(entity.width, greaterThan(0));
      } else if (entity is ExtrusionLoop2) {
        expect(entity.paths, isNotEmpty);
        for (final path in entity.paths) {
          expect(path.role, ExtrusionRole.externalPerimeter);
          expect(path.height, externalFlow.height);
          expect(path.width, greaterThan(0));
        }
      }
    }
  });

  test('detect_thin_wall requires the source external perimeter Flow', () {
    expect(
      () => generator.generate(
        [ExPolygon2(contour: rectangle(10, 0.3))],
        const ClassicPerimeterSettings(
          wallLoops: 1,
          externalPerimeterWidth: 0.4,
          externalPerimeterSpacing: 0.4,
          perimeterWidth: 0.4,
          perimeterSpacing: 0.4,
          detectThinWall: true,
        ),
        layerIndex: 0,
      ),
      throwsArgumentError,
    );
  });
}
