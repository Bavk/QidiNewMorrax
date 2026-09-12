import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polyline.dart';
import 'package:qidi_flow_flutter/core/slicer/source_line_segmentation.dart';

SourceExPolygon2 stripe(int minX, int maxX) => SourceExPolygon2(
      contour: SourcePolygon2([
        SourcePoint2(minX, -10000),
        SourcePoint2(maxX, -10000),
        SourcePoint2(maxX, 10000),
        SourcePoint2(minX, 10000),
      ]),
    );

void main() {
  test('empty clip groups preserve subject with default clip index', () {
    final subject = SourcePolyline2(const [
      SourcePoint2(0, 0),
      SourcePoint2(100000, 0),
    ]);
    final result = SourceLineSegmentation2.polylineSegmentation(
      subject: subject,
      clipGroups: const [],
      defaultClipIndex: 7,
    );

    expect(result, hasLength(1));
    expect(result.single.clipIndex, 7);
    expect(result.single.polyline.points, subject.points);
    expect(identical(result.single.polyline, subject), false);
  });

  test('single stripe creates default-region-default source ranges', () {
    final subject = SourcePolyline2(const [
      SourcePoint2(0, 0),
      SourcePoint2(100000, 0),
      SourcePoint2(200000, 0),
    ]);
    final result = SourceLineSegmentation2.polylineSegmentation(
      subject: subject,
      clipGroups: [
        [stripe(50000, 150000)],
      ],
    );

    expect(result.map((segment) => segment.clipIndex), [0, 1, 0]);
    expect(result[0].polyline.points, const [
      SourcePoint2(0, 0),
      SourcePoint2(50000, 0),
    ]);
    expect(result[1].polyline.points, const [
      SourcePoint2(50000, 0),
      SourcePoint2(100000, 0),
      SourcePoint2(150000, 0),
    ]);
    expect(result[2].polyline.points, const [
      SourcePoint2(150000, 0),
      SourcePoint2(200000, 0),
    ]);
  });

  test('disjoint clip groups retain source-order default gaps', () {
    final subject = SourcePolyline2(const [
      SourcePoint2(0, 0),
      SourcePoint2(100000, 0),
      SourcePoint2(200000, 0),
    ]);
    final result = SourceLineSegmentation2.polylineSegmentation(
      subject: subject,
      clipGroups: [
        [stripe(25000, 75000)],
        [stripe(125000, 175000)],
      ],
    );

    expect(result.map((segment) => segment.clipIndex), [0, 1, 0, 2, 0]);
    expect(result.map((segment) => segment.polyline.points.first.x),
        [0, 25000, 75000, 125000, 175000]);
    expect(result.map((segment) => segment.polyline.points.last.x),
        [25000, 75000, 125000, 175000, 200000]);
  });

  test('one full-region range returns the original subject geometry', () {
    final subject = SourcePolyline2(const [
      SourcePoint2(0, 0),
      SourcePoint2(100000, 0),
      SourcePoint2(200000, 0),
    ]);
    final result = SourceLineSegmentation2.polylineSegmentation(
      subject: subject,
      clipGroups: [
        [stripe(-10000, 210000)],
      ],
    );

    expect(result, hasLength(1));
    expect(result.single.clipIndex, 1);
    expect(result.single.polyline.points, subject.points);
  });

  test('segment lerp preserves QIDI Point scalar-truncation quirk', () {
    final subject = SourcePolyline2(const [
      SourcePoint2(11, 0),
      SourcePoint2(100012, 0),
    ]);
    final result = SourceLineSegmentation2.polylineSegmentation(
      subject: subject,
      clipGroups: [
        [stripe(50011, 110000)],
      ],
    );

    final snapshot = [
      for (final segment in result)
        '${segment.clipIndex}:${segment.polyline.points}',
    ];
    expect(result, hasLength(2), reason: snapshot.join(' | '));
    expect(result[0].clipIndex, 0);
    expect(result[0].polyline.points.last, const SourcePoint2(50010, 0));
    expect(result[1].clipIndex, 1);
    expect(result[1].polyline.points.first, const SourcePoint2(50010, 0));
    expect(result[1].polyline.points.sublist(1), const [
      SourcePoint2(100012, 0),
      SourcePoint2(100012, 0),
    ]);
  });

  test('region wrapper maps clip indexes back to supplied config values', () {
    final subject = SourcePolyline2(const [
      SourcePoint2(0, 0),
      SourcePoint2(100000, 0),
      SourcePoint2(200000, 0),
    ]);
    final result = SourceLineSegmentation2.polylineRegionSegmentation<String>(
      subject: subject,
      baseValue: 'base',
      regions: [
        SourceLineSegmentationRegion2(
          expolygons: [stripe(50000, 150000)],
          value: 'painted',
        ),
      ],
    );

    expect(result.map((segment) => segment.value), [
      'base',
      'painted',
      'base',
    ]);
  });

  test('polygon segmentation closes source polygon before clipping', () {
    final polygon = SourcePolygon2(const [
      SourcePoint2(0, 0),
      SourcePoint2(100000, 0),
      SourcePoint2(100000, 100000),
      SourcePoint2(0, 100000),
    ]);
    final result = SourceLineSegmentation2.polygonSegmentation(
      subject: polygon,
      clipGroups: const [],
    );

    expect(result, hasLength(1));
    expect(result.single.polyline.points, const [
      SourcePoint2(0, 0),
      SourcePoint2(100000, 0),
      SourcePoint2(100000, 100000),
      SourcePoint2(0, 100000),
      SourcePoint2(0, 0),
    ]);
  });

  test('full polygon cover preserves distinct closing source index', () {
    final polygon = SourcePolygon2(const [
      SourcePoint2(0, 0),
      SourcePoint2(100000, 0),
      SourcePoint2(100000, 100000),
      SourcePoint2(0, 100000),
    ]);
    final cover = SourceExPolygon2(
      contour: SourcePolygon2(const [
        SourcePoint2(-10000, -10000),
        SourcePoint2(110000, -10000),
        SourcePoint2(110000, 110000),
        SourcePoint2(-10000, 110000),
      ]),
    );
    final result = SourceLineSegmentation2.polygonSegmentation(
      subject: polygon,
      clipGroups: [
        [cover],
      ],
    );

    expect(result, hasLength(1));
    expect(result.single.clipIndex, 1);
    expect(result.single.polyline.points, const [
      SourcePoint2(0, 0),
      SourcePoint2(100000, 0),
      SourcePoint2(100000, 100000),
      SourcePoint2(0, 100000),
      SourcePoint2(0, 0),
    ]);
  });
}
