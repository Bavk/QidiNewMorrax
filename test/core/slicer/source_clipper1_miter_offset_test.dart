import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_miter_offset.dart';

SourcePolygon2 _square(int size) => SourcePolygon2([
      const SourcePoint2(0, 0),
      SourcePoint2(size, 0),
      SourcePoint2(size, size),
      SourcePoint2(0, size),
    ]);

void main() {
  test('Clipper1 convex square expansion keeps half-away source corners', () {
    final result = SourceClipper1MiterOffset2.offset(_square(1000000), 10000);

    expect(
      result.points,
      const [
        SourcePoint2(-10000, -10000),
        SourcePoint2(1010000, -10000),
        SourcePoint2(1010000, 1010000),
        SourcePoint2(-10000, 1010000),
      ],
    );
  });

  test('Clipper1 convex erosion intersects inward shifted half-planes', () {
    final result = SourceClipper1MiterOffset2.offset(_square(1000000), -10000);

    expect(
      result.points,
      const [
        SourcePoint2(10000, 10000),
        SourcePoint2(990000, 10000),
        SourcePoint2(990000, 990000),
        SourcePoint2(10000, 990000),
      ],
    );
  });

  test('Clipper1 negative cleanup drops an exhausted convex erosion', () {
    final tiny = _square(10000);
    expect(SourceClipper1MiterOffset2.supports(tiny, -50000), isTrue);

    final result = SourceClipper1MiterOffset2.offset(tiny, -50000);
    expect(result.points, isEmpty);
  });
}
