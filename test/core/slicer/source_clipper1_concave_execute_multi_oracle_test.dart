import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_miter_offset.dart';

SourcePolygon2 _uNotch() => SourcePolygon2(const [
      SourcePoint2(0, 0),
      SourcePoint2(120000, 0),
      SourcePoint2(120000, 100000),
      SourcePoint2(80000, 100000),
      SourcePoint2(80000, 40000),
      SourcePoint2(40000, 40000),
      SourcePoint2(40000, 100000),
      SourcePoint2(0, 100000),
    ]);

void main() {
  test('compiled pinned Clipper1 positive U-notch execute is exact', () {
    final polygon = _uNotch();
    expect(
      SourceClipper1MiterOffset2
          .supportsSimpleOrthogonalConcavePositiveContour(polygon, 10000),
      isTrue,
    );

    final result = SourceClipper1MiterOffset2
        .offsetSimpleOrthogonalConcavePositiveContour(polygon, 10000);

    // Captured directly from the exact pinned upstream ELF by calling
    // Slic3r::offset(Polygon const&, 10000.f, jtMiter, 3.). This fixture has
    // two reflex corners, so it verifies more than the one-notch L contour.
    expect(
      result.points,
      const [
        SourcePoint2(130000, 110000),
        SourcePoint2(70000, 110000),
        SourcePoint2(70000, 50000),
        SourcePoint2(50000, 50000),
        SourcePoint2(50000, 110000),
        SourcePoint2(-10000, 110000),
        SourcePoint2(-10000, -10000),
        SourcePoint2(130000, -10000),
      ],
    );
  });

  test('compiled pinned Clipper1 negative U-notch execute is exact', () {
    final polygon = _uNotch();
    expect(
      SourceClipper1MiterOffset2
          .supportsSimpleOrthogonalConcavePositiveContour(polygon, -10000),
      isTrue,
    );

    final result = SourceClipper1MiterOffset2
        .offsetSimpleOrthogonalConcavePositiveContour(polygon, -10000);

    expect(
      result.points,
      const [
        SourcePoint2(110000, 90000),
        SourcePoint2(90000, 90000),
        SourcePoint2(90000, 30000),
        SourcePoint2(30000, 30000),
        SourcePoint2(30000, 90000),
        SourcePoint2(10000, 90000),
        SourcePoint2(10000, 10000),
        SourcePoint2(110000, 10000),
      ],
    );
  });
}
