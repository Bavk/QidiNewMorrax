import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_miter_offset.dart';

SourcePolygon2 _base() => SourcePolygon2(const [
      SourcePoint2(0, 0),
      SourcePoint2(1000000, 0),
      SourcePoint2(1000000, 1000000),
      SourcePoint2(0, 1000000),
    ]);

SourcePolygon2 _withLeadingEdge(int length) => SourcePolygon2([
      const SourcePoint2(0, 0),
      SourcePoint2(length, 0),
      const SourcePoint2(1000000, 0),
      const SourcePoint2(1000000, 1000000),
      const SourcePoint2(0, 1000000),
    ]);

void main() {
  const delta = 13107201.0;

  test('source double shortest-edge product prunes 65536-unit edge', () {
    // Pinned source stores the caller offset in float, then multiplies by the
    // double ClipperOffsetShortestEdgeFactor. For this value the threshold is
    // 65536.005, not float32-rounded 65536.0. The strict `<` comparison must
    // therefore prune an edge whose squared length is exactly 65536^2.
    final expected = SourceClipper1MiterOffset2.rawOffsetPath(_base(), delta);
    final actual = SourceClipper1MiterOffset2.rawOffsetPath(
      _withLeadingEdge(65536),
      delta,
    );

    expect(actual.points, expected.points);
  });

  test('source double shortest-edge product keeps 65537-unit edge', () {
    final expected = SourceClipper1MiterOffset2.rawOffsetPath(_base(), delta);
    final actual = SourceClipper1MiterOffset2.rawOffsetPath(
      _withLeadingEdge(65537),
      delta,
    );

    expect(actual.points, isNot(expected.points));
    expect(actual.points.length, expected.points.length + 1);
  });
}
