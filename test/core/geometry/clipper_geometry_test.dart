import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/clipper_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/expolygon.dart';
import 'package:qidi_flow_flutter/core/geometry/point.dart';
import 'package:qidi_flow_flutter/core/geometry/polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polyline.dart';

Polygon2 box(double minX, double minY, double maxX, double maxY) => Polygon2([
      Point2(minX, minY),
      Point2(maxX, minY),
      Point2(maxX, maxY),
      Point2(minX, maxY),
    ]);

SourcePolygon2 sourceBox(int minX, int minY, int maxX, int maxY) =>
    SourcePolygon2([
      SourcePoint2(minX, minY),
      SourcePoint2(maxX, minY),
      SourcePoint2(maxX, maxY),
      SourcePoint2(minX, maxY),
    ]);

void main() {
  const clipper = ClipperGeometry();

  group('ported test_clipper_offset.cpp constant offset fixtures', () {
    test('20 mm box expands to 22 x 22 mm with miter join', () {
      final source = ExPolygon2(contour: box(0, 0, 20, 20));
      for (final miter in [2.0, 1.5, 1.2]) {
        final output = clipper.offsetExPolygon(
          source,
          1,
          joinType: PolygonJoinType.miter,
          miterLimit: miter,
        );
        expect(output, hasLength(1));
        expect(output.single.area, closeTo(22 * 22, 1e-6));
      }
    });

    test('20 mm box shrinks to 18 x 18 mm with miter join', () {
      final source = ExPolygon2(contour: box(0, 0, 20, 20));
      for (final miter in [2.0, 1.5, 1.2]) {
        final output = clipper.offsetExPolygon(
          source,
          -1,
          joinType: PolygonJoinType.miter,
          miterLimit: miter,
        );
        expect(output, hasLength(1));
        expect(output.single.area, closeTo(18 * 18, 1e-6));
      }
    });

    test('20 mm box with 10 mm hole expands as 22^2 - 8^2', () {
      final source = ExPolygon2(
        contour: box(0, 0, 20, 20),
        holes: [box(5, 5, 15, 15).reversed()],
      );
      final output = clipper.offsetExPolygon(source, 1);
      expect(output, hasLength(1));
      expect(output.single.area, closeTo(22 * 22 - 8 * 8, 1e-6));
    });

    test('20 mm box with 10 mm hole shrinks as 18^2 - 12^2', () {
      final source = ExPolygon2(
        contour: box(0, 0, 20, 20),
        holes: [box(5, 5, 15, 15).reversed()],
      );
      final output = clipper.offsetExPolygon(source, -1);
      expect(output, hasLength(1));
      expect(output.single.area, closeTo(18 * 18 - 12 * 12, 1e-6));
    });
  });

  group('ported test_clipper_utils.cpp boolean fixtures', () {
    test('intersection preserves a clockwise hole', () {
      final square = box(10, 10, 20, 20);
      final band = box(5, 12, 25, 18);
      final hole = box(14, 14, 16, 16).reversed();

      final result = clipper.intersectionEx([square, hole], [band]);
      expect(result, hasLength(1));
      expect(result.single.area, closeTo(10 * 6 - 2 * 2, 1e-9));
      expect(result.single.holes, hasLength(1));
    });

    test('union of nested positive contours and negative hole removes hole', () {
      final outer = box(0, 0, 40, 40);
      final innerPositive = box(10, 10, 30, 30);
      final hole = box(15, 15, 25, 25).reversed();

      final result = clipper.unionEx([outer, innerPositive, hole]);
      expect(result, hasLength(1));
      expect(result.single.holes, isEmpty);
      expect(result.single.area, closeTo(40 * 40, 1e-9));
    });

    test('difference creates a hole', () {
      final outer = box(0, 0, 40, 40);
      final nestedPositive = box(10, 10, 30, 30);
      final cut = box(15, 15, 25, 25);

      final result = clipper.differenceEx([outer, nestedPositive], [cut]);
      expect(result, hasLength(1));
      expect(result.single.holes, hasLength(1));
      expect(result.single.area, closeTo(40 * 40 - 10 * 10, 1e-9));
    });
  });

  group('ported Clipper2Utils.cpp open polyline clipping', () {
    test('intersection_pl_2 clips an open line in source integer units', () {
      final result = clipper.intersectionSourceOpenPolylines(
        [
          SourcePolyline2(const [
            SourcePoint2(-50, 50),
            SourcePoint2(50, 50),
          ]),
        ],
        [sourceBox(0, 0, 100, 100)],
      );

      expect(result, hasLength(1));
      expect(result.single.points, const [
        SourcePoint2(0, 50),
        SourcePoint2(50, 50),
      ]);
    });

    test('diff_pl_2 keeps the complementary open line segment', () {
      final result = clipper.differenceSourceOpenPolylines(
        [
          SourcePolyline2(const [
            SourcePoint2(-50, 50),
            SourcePoint2(50, 50),
          ]),
        ],
        [sourceBox(0, 0, 100, 100)],
      );

      expect(result, hasLength(1));
      expect(result.single.points, const [
        SourcePoint2(-50, 50),
        SourcePoint2(0, 50),
      ]);
    });

    test('closed perimeter polyline preserves Clipper2 open-subject seam', () {
      final perimeter = SourcePolyline2(const [
        SourcePoint2(0, 0),
        SourcePoint2(100, 0),
        SourcePoint2(100, 100),
        SourcePoint2(0, 100),
        SourcePoint2(0, 0),
      ]);
      final clip = sourceBox(50, -50, 150, 150);

      final inside = clipper.intersectionSourceOpenPolylines(
        [perimeter],
        [clip],
      );
      final outside = clipper.differenceSourceOpenPolylines(
        [perimeter],
        [clip],
      );

      // Temporary one-run diagnostic. Remove once exact seam paths are frozen.
      // ignore: avoid_print
      print('CLIPPER_OPEN_INSIDE=${inside.map((p) => p.points).toList()}');
      // ignore: avoid_print
      print('CLIPPER_OPEN_OUTSIDE=${outside.map((p) => p.points).toList()}');

      expect(inside, hasLength(1));
      expect(outside, hasLength(1));
    });
  });
}
