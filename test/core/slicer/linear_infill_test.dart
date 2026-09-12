import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/point.dart';
import 'package:qidi_flow_flutter/core/geometry/polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/linear_infill.dart';

void main() {
  test('clips line infill to a square', () {
    final square = Polygon2(const [Point2(0, 0), Point2(10, 0), Point2(10, 10), Point2(0, 10)]);
    final lines = const LinearInfillGenerator().generate([square], spacing: 2, angleDegrees: 0);
    expect(lines, hasLength(4));
    for (final line in lines) {
      expect(line.a.x, closeTo(0, 1e-8));
      expect(line.b.x, closeTo(10, 1e-8));
      expect(line.length, closeTo(10, 1e-8));
    }
  });

  test('even-odd clipping preserves a nested hole', () {
    final outer = Polygon2(const [Point2(0, 0), Point2(10, 0), Point2(10, 10), Point2(0, 10)]);
    final hole = Polygon2(const [Point2(3, 3), Point2(7, 3), Point2(7, 7), Point2(3, 7)]);
    final lines = const LinearInfillGenerator().generate([outer, hole], spacing: 5, angleDegrees: 0);
    expect(lines, hasLength(2));
    expect(lines[0].a.x, closeTo(0, 1e-8));
    expect(lines[0].b.x, closeTo(3, 1e-8));
    expect(lines[1].a.x, closeTo(7, 1e-8));
    expect(lines[1].b.x, closeTo(10, 1e-8));
  });
}
