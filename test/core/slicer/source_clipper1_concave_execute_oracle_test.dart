import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_miter_offset.dart';

SourcePolygon2 _lNotch({int innerX = 40000}) => SourcePolygon2([
      const SourcePoint2(0, 0),
      const SourcePoint2(100000, 0),
      const SourcePoint2(100000, 40000),
      SourcePoint2(innerX, 40000),
      SourcePoint2(innerX, 100000),
      const SourcePoint2(0, 100000),
    ]);

void main() {
  test('compiled pinned Clipper1 positive L-notch execute is exact', () {
    final polygon = _lNotch();
    expect(
      SourceClipper1MiterOffset2
          .supportsSimpleOrthogonalConcavePositiveContour(polygon, 10000),
      isTrue,
    );

    final result = SourceClipper1MiterOffset2
        .offsetSimpleOrthogonalConcavePositiveContour(polygon, 10000);

    // Captured directly from the exact pinned upstream ELF by calling
    // Slic3r::offset(Polygon const&, 10000.f, jtMiter, 3.).
    expect(
      result.points,
      const [
        SourcePoint2(110000, 50000),
        SourcePoint2(50000, 50000),
        SourcePoint2(50000, 110000),
        SourcePoint2(-10000, 110000),
        SourcePoint2(-10000, -10000),
        SourcePoint2(110000, -10000),
      ],
    );
  });

  test('compiled pinned Clipper1 negative L-notch execute is exact', () {
    final polygon = _lNotch();
    expect(
      SourceClipper1MiterOffset2
          .supportsSimpleOrthogonalConcavePositiveContour(polygon, -10000),
      isTrue,
    );

    final result = SourceClipper1MiterOffset2
        .offsetSimpleOrthogonalConcavePositiveContour(polygon, -10000);

    // Same direct pinned-ELF oracle, now with -10000.f. This exercises the
    // source negative Execute() outer-rectangle / pftNegative cleanup seam.
    expect(
      result.points,
      const [
        SourcePoint2(90000, 30000),
        SourcePoint2(30000, 30000),
        SourcePoint2(30000, 90000),
        SourcePoint2(10000, 90000),
        SourcePoint2(10000, 10000),
        SourcePoint2(90000, 10000),
      ],
    );
  });

  test('concave execute subset rejects global topology interaction seam', () {
    // The bottom edge and notch edge are only 20k apart; a 10k offset can make
    // unrelated shifted edges meet. Full Clipper1 boolean execution is needed
    // there, so the exact local-intersection subset must not claim support.
    final narrow = SourcePolygon2(const [
      SourcePoint2(0, 0),
      SourcePoint2(100000, 0),
      SourcePoint2(100000, 20000),
      SourcePoint2(40000, 20000),
      SourcePoint2(40000, 100000),
      SourcePoint2(0, 100000),
    ]);

    expect(
      SourceClipper1MiterOffset2
          .supportsSimpleOrthogonalConcavePositiveContour(narrow, 10000),
      isFalse,
    );
  });
}
