import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths_prepare_exact.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_orthogonal_execute.dart';

SourcePolygon2 _narrowLNotch() => SourcePolygon2(const [
      SourcePoint2(0, 0),
      SourcePoint2(100000, 0),
      SourcePoint2(100000, 20000),
      SourcePoint2(40000, 20000),
      SourcePoint2(40000, 100000),
      SourcePoint2(0, 100000),
    ]);

SourcePolygon2 _splitDumbbell() => SourcePolygon2(const [
      SourcePoint2(0, 0),
      SourcePoint2(40000, 0),
      SourcePoint2(40000, 41000),
      SourcePoint2(60000, 41000),
      SourcePoint2(60000, 0),
      SourcePoint2(100000, 0),
      SourcePoint2(100000, 100000),
      SourcePoint2(60000, 100000),
      SourcePoint2(60000, 59000),
      SourcePoint2(40000, 59000),
      SourcePoint2(40000, 100000),
      SourcePoint2(0, 100000),
    ]);

void main() {
  test('orthogonal Execute matches compiled narrow L expansion', () {
    final polygon = _narrowLNotch();
    expect(
      SourceClipper1OrthogonalExecute2.supportsSinglePositiveContour(
        polygon,
        10000,
      ),
      isTrue,
    );

    final result =
        SourceClipper1OrthogonalExecute2.offsetSinglePositiveContour(
      polygon,
      10000,
    );

    // Exact pinned BambuStudio ELF oracle for
    // Slic3r::offset(Polygon const&, 10000.f, jtMiter, 3.).
    expect(
      result.points,
      const [
        SourcePoint2(110000, 30000),
        SourcePoint2(50000, 30000),
        SourcePoint2(50000, 110000),
        SourcePoint2(-10000, 110000),
        SourcePoint2(-10000, -10000),
        SourcePoint2(110000, -10000),
      ],
    );
  });

  test('orthogonal Execute matches topology-changing narrow L erosion', () {
    final polygon = _narrowLNotch();
    expect(
      SourceClipper1OrthogonalExecute2.supportsSinglePositiveContour(
        polygon,
        -10000,
      ),
      isTrue,
    );

    final result =
        SourceClipper1OrthogonalExecute2.offsetSinglePositiveContour(
      polygon,
      -10000,
    );

    // Exact pinned ELF oracle. The 20k horizontal arm disappears at a 10k
    // erosion, so Clipper1 boolean cleanup reduces the six-corner input to one
    // four-corner contour.
    expect(
      result.points,
      const [
        SourcePoint2(30000, 90000),
        SourcePoint2(10000, 90000),
        SourcePoint2(10000, 10000),
        SourcePoint2(30000, 10000),
      ],
    );
  });

  test('compiled Clipper1 erosion splits dumbbell left then right', () {
    final polygon = _splitDumbbell();
    expect(
      SourceClipper1OrthogonalExecute2.supportsSinglePositiveContour(
        polygon,
        -10000,
      ),
      isFalse,
    );
    expect(
      SourceClipper1OrthogonalExecute2.supportsPositiveContours(
        polygon,
        -10000,
      ),
      isTrue,
    );

    final result = SourceClipper1OrthogonalExecute2.offsetPositiveContours(
      polygon,
      -10000,
    );

    // Exact result captured by directly invoking the pinned upstream ELF
    // Slic3r::offset(Polygons const&, -10000.f, jtMiter, 3.) at the
    // WallToolPaths call site. The two std::vector<Polygon> entries are emitted
    // left component first, then right component, with these exact starts.
    expect(result, hasLength(2));
    expect(
      result[0].points,
      const [
        SourcePoint2(30000, 90000),
        SourcePoint2(10000, 90000),
        SourcePoint2(10000, 10000),
        SourcePoint2(30000, 10000),
      ],
    );
    expect(
      result[1].points,
      const [
        SourcePoint2(90000, 90000),
        SourcePoint2(70000, 90000),
        SourcePoint2(70000, 10000),
        SourcePoint2(90000, 10000),
      ],
    );
  });

  test('Arachne exact prepare routes split dumbbell off Clipper2 fallback', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [_splitDumbbell()],
      -10000,
    );

    expect(result, hasLength(2));
    expect(result[0].points.first, const SourcePoint2(30000, 90000));
    expect(result[1].points.first, const SourcePoint2(90000, 90000));
  });

  test('Arachne exact prepare no longer falls back for narrow L cleanup', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [_narrowLNotch()],
      -10000,
    );

    expect(result, hasLength(1));
    expect(
      result.single.points,
      const [
        SourcePoint2(30000, 90000),
        SourcePoint2(10000, 90000),
        SourcePoint2(10000, 10000),
        SourcePoint2(30000, 10000),
      ],
    );
  });

  test('sub-coordinate delta remains outside the exact orthogonal subset', () {
    expect(
      SourceClipper1OrthogonalExecute2.supportsPositiveContours(
        _narrowLNotch(),
        10000.25,
      ),
      isFalse,
    );
  });
}
