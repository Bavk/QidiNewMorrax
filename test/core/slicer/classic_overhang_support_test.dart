import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_overhang_support.dart';

SourcePolygon2 box(int minX, int minY, int maxX, int maxY) =>
    SourcePolygon2([
      SourcePoint2(minX, minY),
      SourcePoint2(maxX, minY),
      SourcePoint2(maxX, maxY),
      SourcePoint2(minX, maxY),
    ]);

({int minX, int minY, int maxX, int maxY}) bounds(SourcePolygon2 polygon) {
  var minX = polygon.points.first.x;
  var minY = polygon.points.first.y;
  var maxX = minX;
  var maxY = minY;
  for (final point in polygon.points.skip(1)) {
    if (point.x < minX) minX = point.x;
    if (point.y < minY) minY = point.y;
    if (point.x > maxX) maxX = point.x;
    if (point.y > maxY) maxY = point.y;
  }
  return (minX: minX, minY: minY, maxX: maxX, maxY: maxY);
}

void main() {
  test('lower-series offsets preserve source float32 then scale casts', () {
    final offsets = SourceClassicOverhangSupport2.scaledLowerPolygonOffsets(
      width: 0.45,
      nozzleDiameter: 0.4,
    );

    // Flow::width/nozzle are float. The first sample is stored in vector<float>
    // before scale_ and float(scale_(...)), so it is intentionally not -18250.
    expect(offsets, const [-18249.998046875, 20000.0]);
  });

  test('dist_boundary keeps its distinct source double scale expression', () {
    final boundary = SourceClassicOverhangSupport2.distBoundary(
      width: 0.45,
      nozzleDiameter: 0.4,
    );

    expect(boundary.first, 0);
    expect(boundary.second, closeTo(38249.99958276749, 1e-9));
  });

  test('null lower_slices returns an empty source series', () {
    final series = SourceClassicOverhangSupport2.generateLowerPolygonsSeries(
      width: 0.45,
      nozzleDiameter: 0.4,
      lowerSlices: null,
    );

    expect(series, isEmpty);
  });

  test('non-null empty lower_slices retains two empty offset samples', () {
    final series = SourceClassicOverhangSupport2.generateLowerPolygonsSeries(
      width: 0.45,
      nozzleDiameter: 0.4,
      lowerSlices: const [],
    );

    expect(series, hasLength(2));
    expect(series[0], isEmpty);
    expect(series[1], isEmpty);
  });

  test('1M source-unit box matches source rounded miter bounds', () {
    final series = SourceClassicOverhangSupport2.generateLowerPolygonsSeries(
      width: 0.45,
      nozzleDiameter: 0.4,
      lowerSlices: [box(0, 0, 1000000, 1000000)],
    );

    expect(series, hasLength(2));
    expect(series[0], hasLength(1));
    expect(series[1], hasLength(1));
    expect(
      bounds(series[0].single),
      (minX: 18250, minY: 18250, maxX: 981750, maxY: 981750),
    );
    expect(
      bounds(series[1].single),
      (minX: -20000, minY: -20000, maxX: 1020000, maxY: 1020000),
    );
    expect(series[0].single.isClockwise, false);
    expect(series[1].single.isClockwise, false);
  });

  test('opposite-winding hole expands/shrinks opposite to contour', () {
    final outer = box(0, 0, 1000000, 1000000);
    final hole = box(300000, 300000, 700000, 700000).reversed();
    final series = SourceClassicOverhangSupport2.generateLowerPolygonsSeries(
      width: 0.45,
      nozzleDiameter: 0.4,
      lowerSlices: [outer, hole],
    );

    for (final sample in series) {
      expect(sample, hasLength(2));
      expect(sample.where((polygon) => !polygon.isClockwise), hasLength(1));
      expect(sample.where((polygon) => polygon.isClockwise), hasLength(1));
    }

    final shrunkOuter = series[0].singleWhere((polygon) => !polygon.isClockwise);
    final expandedHole = series[0].singleWhere((polygon) => polygon.isClockwise);
    expect(
      bounds(shrunkOuter),
      (minX: 18250, minY: 18250, maxX: 981750, maxY: 981750),
    );
    expect(
      bounds(expandedHole),
      (minX: 281750, minY: 281750, maxX: 718250, maxY: 718250),
    );

    final expandedOuter = series[1].singleWhere((polygon) => !polygon.isClockwise);
    final shrunkHole = series[1].singleWhere((polygon) => polygon.isClockwise);
    expect(
      bounds(expandedOuter),
      (minX: -20000, minY: -20000, maxX: 1020000, maxY: 1020000),
    );
    expect(
      bounds(shrunkHole),
      (minX: 320000, minY: 320000, maxX: 680000, maxY: 680000),
    );
  });
}
