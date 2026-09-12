import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_extrusion_line.dart';
import 'package:qidi_flow_flutter/core/slicer/source_line_segmentation.dart';

SourceExPolygon2 stripe(int minX, int maxX) => SourceExPolygon2(
      contour: SourcePolygon2([
        SourcePoint2(minX, -10000),
        SourcePoint2(maxX, -10000),
        SourcePoint2(maxX, 10000),
        SourcePoint2(minX, 10000),
      ]),
    );

SourceArachneExtrusionLine2 varyingLine({bool closed = false}) =>
    SourceArachneExtrusionLine2(
      insetIndex: 4,
      isOdd: true,
      isClosed: closed,
      junctions: [
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(0, 0),
          w: 1000,
          perimeterIndex: 5,
          holeCompensationFlag: true,
        ),
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(100000, 0),
          w: 2000,
          perimeterIndex: 5,
          holeCompensationFlag: true,
        ),
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(200000, 0),
          w: 3000,
          perimeterIndex: 5,
          holeCompensationFlag: true,
        ),
      ],
    );

void main() {
  test('Arachne stripe splits width-interpolated source segments', () {
    final result = SourceLineSegmentation2.extrusionSegmentation(
      subject: varyingLine(),
      clipGroups: [
        [stripe(50000, 150000)],
      ],
    );

    expect(result.map((segment) => segment.clipIndex), [0, 1, 0]);
    expect(
      result.map((segment) => segment.extrusion.junctions.first.p.x),
      [0, 50000, 150000],
    );
    expect(
      result.map((segment) => segment.extrusion.junctions.last.p.x),
      [50000, 150000, 200000],
    );
    expect(result[0].extrusion.junctions.last.w, 1500);
    expect(result[1].extrusion.junctions.first.w, 1500);
    expect(result[1].extrusion.junctions.last.w, 2500);
    expect(result[2].extrusion.junctions.first.w, 2500);

    for (final segment in result) {
      expect(segment.extrusion.insetIndex, 4);
      expect(segment.extrusion.isOdd, true);
      expect(segment.extrusion.isClosed, false);
    }
    expect(result[1].extrusion.junctions.first.holeCompensationFlag, false);
  });

  test('Arachne width lerp truncates only final scalar result', () {
    final line = SourceArachneExtrusionLine2(
      insetIndex: 0,
      isOdd: false,
      junctions: [
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(11, 0),
          w: 1000,
          perimeterIndex: 1,
        ),
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(100012, 0),
          w: 1001,
          perimeterIndex: 1,
        ),
      ],
    );
    final result = SourceLineSegmentation2.extrusionSegmentation(
      subject: line,
      clipGroups: [
        [stripe(50011, 110000)],
      ],
    );

    expect(result, hasLength(2));
    expect(result[0].extrusion.junctions.last.p, const SourcePoint2(50010, 0));
    expect(result[0].extrusion.junctions.last.w, 1000);
    expect(result[1].extrusion.junctions.first.w, 1000);
  });

  test('single full-cover range returns whole Arachne line metadata', () {
    final source = SourceArachneExtrusionLine2(
      insetIndex: 3,
      isOdd: false,
      isClosed: true,
      junctions: [
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(0, 0),
          w: 1000,
          perimeterIndex: 2,
          holeCompensationFlag: true,
        ),
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(100000, 0),
          w: 2000,
          perimeterIndex: 2,
          holeCompensationFlag: true,
        ),
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(0, 0),
          w: 1000,
          perimeterIndex: 2,
          holeCompensationFlag: true,
        ),
      ],
    );
    final result = SourceLineSegmentation2.extrusionSegmentation(
      subject: source,
      clipGroups: [
        [stripe(-10000, 110000)],
      ],
    );

    expect(result, hasLength(1));
    expect(result.single.clipIndex, 1);
    expect(result.single.extrusion.isClosed, true);
    expect(result.single.extrusion.insetIndex, 3);
    expect(result.single.extrusion.junctions, source.junctions);
    expect(identical(result.single.extrusion, source), false);
  });

  test('Arachne region wrapper maps clip indexes to supplied values', () {
    final result = SourceLineSegmentation2.extrusionRegionSegmentation<String>(
      subject: varyingLine(),
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
}
