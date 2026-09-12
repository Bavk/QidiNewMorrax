import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/clipper_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/expolygon.dart';
import 'package:qidi_flow_flutter/core/geometry/point.dart';
import 'package:qidi_flow_flutter/core/geometry/polygon.dart';

Polygon2 box(double minX, double minY, double maxX, double maxY) => Polygon2([
      Point2(minX, minY),
      Point2(maxX, minY),
      Point2(maxX, maxY),
      Point2(minX, maxY),
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
}
