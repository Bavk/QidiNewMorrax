import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polyline.dart';
import 'package:qidi_flow_flutter/core/slicer/extrusion_covered_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/extrusion_entity.dart';

({int minX, int minY, int maxX, int maxY}) boundsOf(
  Iterable<SourcePoint2> points,
) {
  final values = points.toList(growable: false);
  var minX = values.first.x;
  var minY = values.first.y;
  var maxX = values.first.x;
  var maxY = values.first.y;
  for (final point in values.skip(1)) {
    if (point.x < minX) minX = point.x;
    if (point.y < minY) minY = point.y;
    if (point.x > maxX) maxX = point.x;
    if (point.y > maxY) maxY = point.y;
  }
  return (minX: minX, minY: minY, maxX: maxX, maxY: maxY);
}

ExtrusionPath2 coveredPath(int start, int end) => ExtrusionPath2(
      role: ExtrusionRole.gapFill,
      mm3PerMm: 0.08,
      width: 0.4,
      height: 0.2,
      polyline: SourcePolyline2([
        SourcePoint2(start, 0),
        SourcePoint2(end, 0),
      ]),
    );

void main() {
  test('ExtrusionPath polygons_covered_by_width uses source square/butt offset', () {
    final polygons = coveredPath(0, 100000).polygonsCoveredByWidth(
      scaledEpsilon: 10,
    );

    expect(polygons, hasLength(1));
    final polygon = polygons.single;
    expect(
      boundsOf(polygon.points),
      (minX: 0, minY: -20010, maxX: 100000, maxY: 20010),
    );
    expect(polygon.area, 4002000000);
  });

  test('collection and iterable covered-width dispatch append child polygons', () {
    final first = coveredPath(0, 100000);
    final second = coveredPath(300000, 400000);
    final collection = ExtrusionEntityCollection2(entities: [first, second]);

    final fromCollection = collection.polygonsCoveredByWidth();
    expect(fromCollection, hasLength(2));

    final fromIterable = <ExtrusionEntity2>[first, second]
        .polygonsCoveredByWidth();
    expect(fromIterable, hasLength(2));
    expect(
      fromIterable.map((polygon) => boundsOf(polygon.points)).toList(),
      [
        (minX: 0, minY: -20000, maxX: 100000, maxY: 20000),
        (minX: 300000, minY: -20000, maxX: 400000, maxY: 20000),
      ],
    );
  });
}
