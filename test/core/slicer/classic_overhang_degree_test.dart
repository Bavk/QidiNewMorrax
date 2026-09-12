import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polyline.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_overhang_degree.dart';
import 'package:qidi_flow_flutter/core/slicer/extrusion_entity.dart';

SourcePolygon2 rectangle(int minX, int minY, int maxX, int maxY) =>
    SourcePolygon2([
      SourcePoint2(minX, minY),
      SourcePoint2(maxX, minY),
      SourcePoint2(maxX, maxY),
      SourcePoint2(minX, maxY),
    ]);

void main() {
  test('non-uniform source map interpolates overhang degree 0..5', () {
    expect(SourceClassicOverhangDegree2.mappedDegree(0, 0, 100), 0);
    expect(SourceClassicOverhangDegree2.mappedDegree(10, 0, 100), 1);
    expect(SourceClassicOverhangDegree2.mappedDegree(17.5, 0, 100), 1.5);
    expect(SourceClassicOverhangDegree2.mappedDegree(25, 0, 100), 2);
    expect(SourceClassicOverhangDegree2.mappedDegree(50, 0, 100), 3);
    expect(SourceClassicOverhangDegree2.mappedDegree(75, 0, 100), 4);
    expect(SourceClassicOverhangDegree2.mappedDegree(100, 0, 100), 5);
    expect(SourceClassicOverhangDegree2.mappedDegree(125, 0, 100), 5);
  });

  test('classic base degree preserves binary 0.1 terrace and caps at five', () {
    expect(
      SourceClassicOverhangDegree2.baseDegree(1.29, 0.1),
      1.2000000000000002,
    );
    expect(
      SourceClassicOverhangDegree2.baseDegree(2.99, 0.1),
      2.9000000000000004,
    );
    expect(SourceClassicOverhangDegree2.baseDegree(5.2, 0.1), 5);
  });

  test('short two-point line remains one unsplit middle section', () {
    final split = SourceClassicOverhangDegree2.prepareSplitPolylines(
      SourcePolyline2(const [
        SourcePoint2(0, 0),
        SourcePoint2(100000, 0),
      ]),
    ).single;

    expect(split.start, isEmpty);
    expect(split.end, isEmpty);
    expect(split.middle, hasLength(1));
    expect(split.middle.single.polyline.points, const [
      SourcePoint2(0, 0),
      SourcePoint2(100000, 0),
    ]);
  });

  test('long two-point line uses source 0.6 mm start/middle/end cuts', () {
    final split = SourceClassicOverhangDegree2.prepareSplitPolylines(
      SourcePolyline2(const [
        SourcePoint2(0, 0),
        SourcePoint2(180000, 0),
      ]),
    ).single;

    expect(split.start, hasLength(1));
    expect(split.middle, hasLength(1));
    expect(split.end, hasLength(1));
    expect(split.start.single.polyline.points, const [
      SourcePoint2(0, 0),
      SourcePoint2(60000, 0),
    ]);
    expect(split.middle.single.polyline.points, const [
      SourcePoint2(60000, 0),
      SourcePoint2(120000, 0),
    ]);
    expect(split.end.single.polyline.points, const [
      SourcePoint2(120000, 0),
      SourcePoint2(180000, 0),
    ]);
  });

  test('OverhangDistancer keeps source float query and return boundary', () {
    final distancer = SourceClassicOverhangDistancer2([
      rectangle(-1000000, -1000000, 1000000, 0),
    ]);

    expect(
      distancer.distanceFromPerimeter(const SourcePoint2(12345, 10000)),
      10000,
    );
  });

  test('short middle-overhang run gets midpoint degree then 0.1 terrace', () {
    final distancer = SourceClassicOverhangDistancer2([
      rectangle(-1000000, -1000000, 1000000, 0),
    ]);
    final graded = SourceClassicOverhangDegree2.gradePolyline(
      polyline: SourcePolyline2(const [
        SourcePoint2(0, 10000),
        SourcePoint2(50000, 10000),
      ]),
      distancer: distancer,
      lowerBound: 0,
      upperBound: 100000,
    );

    expect(graded, hasLength(1));
    expect(graded.single.degree, 1);
    expect(graded.single.polyline.points, const [
      SourcePoint2(0, 10000),
      SourcePoint2(50000, 10000),
    ]);
  });

  test('long line smooths between endpoint degrees before terracing', () {
    final distancer = SourceClassicOverhangDistancer2([
      rectangle(-1000000, -1000000, 0, 1000000),
    ]);
    final graded = SourceClassicOverhangDegree2.gradePolyline(
      polyline: SourcePolyline2(const [
        SourcePoint2(10000, 0),
        SourcePoint2(190000, 0),
      ]),
      distancer: distancer,
      lowerBound: 0,
      upperBound: 200000,
    );

    expect(graded, hasLength(3));
    expect(graded[0].degree, closeTo(1.6, 1e-12));
    expect(graded[1].degree, closeTo(2.9, 1e-12));
    expect(graded[2].degree, closeTo(4.2, 1e-12));
    expect(graded[0].polyline.points, const [
      SourcePoint2(10000, 0),
      SourcePoint2(70000, 0),
    ]);
    expect(graded[1].polyline.points, const [
      SourcePoint2(70000, 0),
      SourcePoint2(130000, 0),
    ]);
    expect(graded[2].polyline.points, const [
      SourcePoint2(130000, 0),
      SourcePoint2(190000, 0),
    ]);
  });

  test('detect emits source extrusion payload for each merged degree run', () {
    final paths = SourceClassicOverhangDegree2.detect(
      lowerPolygons: [
        rectangle(-1000000, -1000000, 1000000, 0),
      ],
      middleOverhangPolylines: [
        SourcePolyline2(const [
          SourcePoint2(0, 10000),
          SourcePoint2(50000, 10000),
        ]),
      ],
      role: ExtrusionRole.externalPerimeter,
      extrusionMm3PerMm: 0.08,
      extrusionWidth: 0.45,
      layerHeight: 0.2,
      lowerBound: 0,
      upperBound: 100000,
    );

    expect(paths, hasLength(1));
    expect(paths.single.role, ExtrusionRole.externalPerimeter);
    expect(paths.single.overhangDegree, 1);
    expect(paths.single.curveDegree, 0);
    expect(paths.single.mm3PerMm, 0.08);
    expect(paths.single.width, 0.45);
    expect(paths.single.height, 0.2);
  });
}
