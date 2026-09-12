import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/expolygon.dart';
import 'package:qidi_flow_flutter/core/geometry/point.dart';
import 'package:qidi_flow_flutter/core/geometry/polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_fill_boundary.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_top_fill.dart';

ExPolygon2 rectangleEx(double minX, double minY, double maxX, double maxY) =>
    ExPolygon2(contour: rectangle(minX, minY, maxX, maxY));

Polygon2 rectangle(double minX, double minY, double maxX, double maxY) =>
    Polygon2([
      Point2(minX, minY),
      Point2(maxX, minY),
      Point2(maxX, maxY),
      Point2(minX, maxY),
    ]);

(int, int, int, int) boundsEx(Iterable<ExPolygon2> expolygons) {
  final points = [
    for (final expolygon in expolygons) ...[
      ...expolygon.contour.points,
      for (final hole in expolygon.holes) ...hole.points,
    ],
  ];
  expect(points, isNotEmpty);
  var minX = source(points.first.x);
  var minY = source(points.first.y);
  var maxX = minX;
  var maxY = minY;
  for (final point in points.skip(1)) {
    final x = source(point.x);
    final y = source(point.y);
    if (x < minX) minX = x;
    if (y < minY) minY = y;
    if (x > maxX) maxX = x;
    if (y > maxY) maxY = y;
  }
  return (minX, minY, maxX, maxY);
}

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

int source(double millimeters) => (millimeters / 0.00001).round();

SourceClassicTopFillSettings2 settings({
  double topAreaThresholdPercent = 0,
  bool hasGapFill = false,
}) =>
    SourceClassicTopFillSettings2(
      wallLoops: 2,
      externalPerimeterWidthMm: 0.45,
      externalPerimeterSpacingMm: 0.4,
      perimeterWidthMm: 0.45,
      perimeterSpacingMm: 0.45,
      sparseInfillLineWidthMm: 0.4,
      topAreaThresholdPercent: topAreaThresholdPercent,
      hasGapFill: hasGapFill,
    );

void main() {
  const producer = SourceClassicTopFillAllTop2();

  test('source gate skips Alltop producer when loop_number is zero', () {
    final input = [rectangleEx(0, 0, 20, 20)];
    final result = producer.produce(
      last: input,
      loopNumber: 0,
      settings: settings(),
      upperSlices: const [],
    );

    expect(result.applied, isFalse);
    expect(boundsEx(result.last), (0, 0, 2000000, 2000000));
    expect(result.topFills, isEmpty);
    expect(result.fillClip, isEmpty);
  });

  test('top-one-wall scalar math matches pinned C++ source order', () {
    final result = producer.produce(
      last: [rectangleEx(0, 0, 20, 20)],
      loopNumber: 1,
      settings: settings(topAreaThresholdPercent: 20),
      upperSlices: [rectangle(0, 0, 20, 20)],
    );

    // C++ oracle with SCALING_FACTOR=1e-5 and the literal source expression:
    // ext_width=45000, ext_spacing=40000, perimeter_width/spacing=45000;
    // offset_top_surface = 135000 - coord_t(0.9 * 45000) = 94500;
    // min_width_top_surface = 20% * max(20000, 22500) = 4500.
    expect(result.offsetTopSurfaceSource, 94500);
    expect(result.minWidthTopSurfaceSource, 4500);
    expect(result.finalFillClipDeltaSource, 0);
    expect(result.last, hasLength(1));
    expect(result.topFills, isEmpty);
    expect(boundsEx(result.fillClip), (0, 0, 2000000, 2000000));
  });

  test('empty non-null upper slices mark the represented island as all top', () {
    final result = producer.produce(
      last: [rectangleEx(0, 0, 20, 20)],
      loopNumber: 1,
      settings: settings(),
      upperSlices: const [],
    );

    expect(result.applied, isTrue);
    expect(result.last, isEmpty);
    expect(result.innerPolygons, isEmpty);
    expect(boundsEx(result.topFills), (40000, 40000, 1960000, 1960000));
    expect(boundsEx(result.fillClip), (0, 0, 2000000, 2000000));

    // `temp_gap = diff_ex(top_polygons, fill_clip)` is the 0.4 mm ring.
    expect(result.tempGap, hasLength(1));
    expect(result.tempGap.single.holes, hasLength(1));
    expect(boundsEx(result.tempGap), (0, 0, 2000000, 2000000));
  });

  test('gap-fill branch unions the source temp_gap back into last', () {
    final result = producer.produce(
      last: [rectangleEx(0, 0, 20, 20)],
      loopNumber: 1,
      settings: settings(hasGapFill: true),
      upperSlices: const [],
    );

    expect(result.last, hasLength(1));
    expect(result.last.single.holes, hasLength(1));
    expect(boundsEx(result.last), (0, 0, 2000000, 2000000));
    expect(boundsEx(result.tempGap), boundsEx(result.last));
  });

  test('non-null empty lower slices exercise source bridge merge', () {
    final result = producer.produce(
      last: [rectangleEx(0, 0, 20, 20)],
      loopNumber: 1,
      settings: settings(),
      upperSlices: [rectangle(0, 0, 20, 20)],
      lowerSlices: const [],
    );

    // bridge_offset=max(40000,45000)=45000; source offset is 1.5x.
    expect(result.bridgeMerged, isTrue);
    expect(boundsEx(result.bridgeChecker), (-67500, -67500, 2067500, 2067500));
    expect(boundsEx(result.last), (0, 0, 2000000, 2000000));
    expect(result.topFills, isEmpty);
  });

  test('bbox-pruned far upper polygon behaves like no upper coverage', () {
    final result = producer.produce(
      last: [rectangleEx(0, 0, 20, 20)],
      loopNumber: 1,
      settings: settings(),
      upperSlices: [rectangle(100, 100, 110, 110)],
    );

    expect(result.last, isEmpty);
    expect(boundsEx(result.topFills), (40000, 40000, 1960000, 1960000));
  });

  test('Alltop producer composes into final fill-surfaces boundary', () {
    final top = producer.produce(
      last: [rectangleEx(0, 0, 20, 20)],
      loopNumber: 1,
      settings: settings(),
      upperSlices: const [],
    );

    const boundary = SourceClassicFillBoundary2();
    final result = boundary.build(
      last: top.last,
      // After an all-top first iteration, the next source shell iteration may
      // collapse and reduce loop_number back to zero. This fixture exercises
      // the resulting one-loop boundary consumer explicitly.
      effectiveLoopCount: 1,
      settings: const SourceClassicFillBoundarySettings2(
        externalPerimeterSpacingMm: 0.4,
        perimeterSpacingMm: 0.45,
        solidInfillSpacingMm: 0.4,
        infillWallOverlap: SourceFloatOrPercent2.absolute(0),
      ),
      topFills: top.topFills,
      fillClip: top.fillClip,
    );

    expect(result.fillSurfaces, hasLength(1));
    expect(
      sourceBounds(result.fillSurfaces.single.expolygon),
      (20000, 20000, 1980000, 1980000),
    );
    expect(result.fillNoOverlap, hasLength(1));
    expect(
      sourceBounds(result.fillNoOverlap.single),
      (20000, 20000, 1980000, 1980000),
    );
  });
}
