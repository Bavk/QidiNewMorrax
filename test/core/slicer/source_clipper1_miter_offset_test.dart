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

  test('Clipper1 sharp convex corner uses pinned DoSquare signs', () {
    final sharp = SourcePolygon2(const [
      SourcePoint2(0, 0),
      SourcePoint2(1000000, 0),
      SourcePoint2(1000000, 100000),
    ]);

    final result = SourceClipper1MiterOffset2.offset(sharp, 10000);
    expect(
      result.points,
      const [
        SourcePoint2(-10461, 9004),
        SourcePoint2(-9514, -10000),
        SourcePoint2(1010000, -10000),
        SourcePoint2(1010000, 111050),
      ],
    );
  });

  test('raw Clipper1 stage emits pinned concave OffsetPoint triplet', () {
    final concave = SourcePolygon2(const [
      SourcePoint2(0, 0),
      SourcePoint2(100000, 0),
      SourcePoint2(100000, 40000),
      SourcePoint2(40000, 40000),
      SourcePoint2(40000, 100000),
      SourcePoint2(0, 100000),
    ]);

    expect(
      SourceClipper1MiterOffset2.supportsRawClosedPath(concave, 10000),
      isTrue,
    );
    // Final concave cleanup is intentionally not claimed until Clipper1 union
    // semantics are ported; only the raw DoOffset stage is exact here.
    expect(SourceClipper1MiterOffset2.supports(concave, 10000), isFalse);

    final raw = SourceClipper1MiterOffset2.rawOffsetPath(concave, 10000);
    expect(
      raw.points,
      const [
        SourcePoint2(-10000, -10000),
        SourcePoint2(110000, -10000),
        SourcePoint2(110000, 50000),
        SourcePoint2(40000, 50000),
        SourcePoint2(40000, 40000),
        SourcePoint2(50000, 40000),
        SourcePoint2(50000, 110000),
        SourcePoint2(-10000, 110000),
      ],
    );
  });

  test('raw negative convex stage preserves source concave triplets', () {
    final raw = SourceClipper1MiterOffset2.rawOffsetPath(
      _square(100000),
      -10000,
    );

    expect(
      raw.points.take(3).toList(),
      const [
        SourcePoint2(10000, 0),
        SourcePoint2(0, 0),
        SourcePoint2(0, 10000),
      ],
    );
    expect(raw.points.length, 12);
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
