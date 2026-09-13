import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths_prepare_exact.dart';

SourcePolygon2 _outerSquare() => SourcePolygon2(const [
      SourcePoint2(0, 0),
      SourcePoint2(200000, 0),
      SourcePoint2(200000, 200000),
      SourcePoint2(0, 200000),
    ]);

SourcePolygon2 _clockwiseHole() => SourcePolygon2(const [
      SourcePoint2(50000, 50000),
      SourcePoint2(50000, 150000),
      SourcePoint2(150000, 150000),
      SourcePoint2(150000, 50000),
    ]);

int _xSpan(SourcePolygon2 polygon) {
  var minX = polygon.points.first.x;
  var maxX = minX;
  for (final point in polygon.points.skip(1)) {
    if (point.x < minX) minX = point.x;
    if (point.x > maxX) maxX = point.x;
  }
  return maxX - minX;
}

void _expectContourAndHoleSpans(
  List<SourcePolygon2> polygons,
  List<int> expectedSpans,
) {
  expect(polygons, hasLength(2));
  final spans = polygons.map(_xSpan).toList()..sort();
  final expected = [...expectedSpans]..sort();
  expect(spans, expected);
  expect(polygons.where((polygon) => polygon.signedArea > 0), hasLength(1));
  expect(polygons.where((polygon) => polygon.signedArea < 0), hasLength(1));
}

void main() {
  test('convex multipath positive offset expands contour and shrinks hole', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [_outerSquare(), _clockwiseHole()],
      10000,
    );

    _expectContourAndHoleSpans(result, const [80000, 220000]);
  });

  test('convex multipath negative offset shrinks contour and expands hole', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [_outerSquare(), _clockwiseHole()],
      -10000,
    );

    _expectContourAndHoleSpans(result, const [120000, 180000]);
  });
}
