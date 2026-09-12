import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/expolygon.dart';
import 'package:qidi_flow_flutter/core/geometry/point.dart';
import 'package:qidi_flow_flutter/core/geometry/polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_fill_boundary.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_fill_process.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_top_one_wall_context.dart';

Polygon2 rectangle(double minX, double minY, double maxX, double maxY) =>
    Polygon2([
      Point2(minX, minY),
      Point2(maxX, minY),
      Point2(maxX, maxY),
      Point2(minX, maxY),
    ]);

ExPolygon2 box(double size) => ExPolygon2(contour: rectangle(0, 0, size, size));

(int, int, int, int) sourceBounds(SourceExPolygon2 expolygon) {
  final points = [
    ...expolygon.contour.points,
    for (final hole in expolygon.holes) ...hole.points,
  ];
  expect(points, isNotEmpty);
  var minX = points.first.x;
  var minY = points.first.y;
  var maxX = minX;
  var maxY = minY;
  for (final point in points.skip(1)) {
    if (point.x < minX) minX = point.x;
    if (point.y < minY) minY = point.y;
    if (point.x > maxX) maxX = point.x;
    if (point.y > maxY) maxY = point.y;
  }
  return (minX, minY, maxX, maxY);
}

const twoWallSettings = SourceClassicPerimeterFillProcessSettings2(
  perimeter: ClassicPerimeterSettings(
    wallLoops: 2,
    externalPerimeterWidth: 0.4,
    externalPerimeterSpacing: 0.4,
    perimeterWidth: 0.4,
    perimeterSpacing: 0.4,
  ),
  solidInfillSpacingMm: 0.4,
  infillWallOverlap: SourceFloatOrPercent2.absolute(0),
);

void main() {
  const process = SourceClassicPerimeterFillProcess2();

  test('two-wall process feeds final shell last into fill boundary', () {
    final result = process.generate(
      [box(20)],
      twoWallSettings,
      layerIndex: 2,
    );

    expect(result.perimeter.effectiveLoopCount, 2);
    expect(result.perimeter.loops, hasLength(2));
    expect(result.perimeter.innerRegion, hasLength(1));
    expect(result.fillBoundary.fillSurfaces, hasLength(1));
    expect(
      sourceBounds(result.fillBoundary.fillSurfaces.single.expolygon),
      (80000, 80000, 1920000, 1920000),
    );
    expect(result.fillBoundary.fillNoOverlap, hasLength(1));
    expect(
      sourceBounds(result.fillBoundary.fillNoOverlap.single),
      (80000, 80000, 1920000, 1920000),
    );
  });

  test('topmost null upper slices flow through one-wall boundary', () {
    final result = process.generate(
      [box(20)],
      const SourceClassicPerimeterFillProcessSettings2(
        perimeter: ClassicPerimeterSettings(
          wallLoops: 3,
          externalPerimeterWidth: 0.4,
          externalPerimeterSpacing: 0.4,
          perimeterWidth: 0.4,
          perimeterSpacing: 0.4,
        ),
        solidInfillSpacingMm: 0.4,
        infillWallOverlap: SourceFloatOrPercent2.absolute(0),
      ),
      layerIndex: 3,
      topOneWall: const SourceClassicTopOneWallContext2(
        type: SourceTopOneWallType2.topmost,
        upperSlices: null,
      ),
    );

    expect(result.perimeter.effectiveLoopCount, 1);
    expect(result.perimeter.loops, hasLength(1));
    expect(result.perimeter.topFillApplied, isFalse);
    expect(
      sourceBounds(result.fillBoundary.fillSurfaces.single.expolygon),
      (40000, 40000, 1960000, 1960000),
    );
  });

  test('Alltop empty upper slices reach final top-fill-only output', () {
    final result = process.generate(
      [box(20)],
      twoWallSettings,
      layerIndex: 3,
      topOneWall: const SourceClassicTopOneWallContext2(
        type: SourceTopOneWallType2.allTop,
        upperSlices: [],
        sparseInfillLineWidthMm: 0.4,
      ),
    );

    expect(result.perimeter.topFillApplied, isTrue);
    expect(result.perimeter.effectiveLoopCount, 1);
    expect(result.perimeter.innerRegion, isEmpty);
    expect(result.perimeter.topFills, hasLength(1));
    expect(result.fillBoundary.fillSurfaces, hasLength(1));
    expect(
      sourceBounds(result.fillBoundary.fillSurfaces.single.expolygon),
      (40000, 40000, 1960000, 1960000),
    );
    expect(result.fillBoundary.fillNoOverlap, hasLength(1));
    expect(
      sourceBounds(result.fillBoundary.fillNoOverlap.single),
      (40000, 40000, 1960000, 1960000),
    );
  });

  test('percentage wall overlap keeps C++ 7999 quirk end-to-end', () {
    final result = process.generate(
      [box(20)],
      const SourceClassicPerimeterFillProcessSettings2(
        perimeter: ClassicPerimeterSettings(
          wallLoops: 1,
          externalPerimeterWidth: 0.4,
          externalPerimeterSpacing: 0.4,
          perimeterWidth: 0.4,
          perimeterSpacing: 0.4,
        ),
        solidInfillSpacingMm: 0.4,
        infillWallOverlap: SourceFloatOrPercent2.percent(20),
      ),
      layerIndex: 2,
    );

    expect(result.fillBoundary.infillPerimeterOverlapSource, 7999);
    expect(result.fillBoundary.insetSource, 12001);
    expect(
      sourceBounds(result.fillBoundary.fillSurfaces.single.expolygon),
      (32001, 32001, 1967999, 1967999),
    );
    expect(
      sourceBounds(result.fillBoundary.fillNoOverlap.single),
      (40000, 40000, 1960000, 1960000),
    );
  });

  test('zero wall loops leave the whole island for fill', () {
    final result = process.generate(
      [box(20)],
      const SourceClassicPerimeterFillProcessSettings2(
        perimeter: ClassicPerimeterSettings(
          wallLoops: 0,
          externalPerimeterWidth: 0.4,
          externalPerimeterSpacing: 0.4,
          perimeterWidth: 0.4,
          perimeterSpacing: 0.4,
        ),
        solidInfillSpacingMm: 0.4,
        infillWallOverlap: SourceFloatOrPercent2.absolute(0),
      ),
      layerIndex: 2,
    );

    expect(result.perimeter.loops, isEmpty);
    expect(result.perimeter.effectiveLoopCount, 0);
    expect(result.fillBoundary.insetSource, 0);
    expect(
      sourceBounds(result.fillBoundary.fillSurfaces.single.expolygon),
      (0, 0, 2000000, 2000000),
    );
    expect(
      sourceBounds(result.fillBoundary.fillNoOverlap.single),
      (0, 0, 2000000, 2000000),
    );
  });
}
