import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths_prepare_exact.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_miter_offset.dart';

SourcePolygon2 _narrowLNotch() => SourcePolygon2(const [
      SourcePoint2(0, 0),
      SourcePoint2(100000, 0),
      SourcePoint2(100000, 20000),
      SourcePoint2(40000, 20000),
      SourcePoint2(40000, 100000),
      SourcePoint2(0, 100000),
    ]);

Set<String> _pointSet(SourcePolygon2 polygon) => {
      for (final point in polygon.points) '${point.x},${point.y}',
    };

void main() {
  test('compiled topology-changing narrow L erosion matches compatibility path', () {
    final polygon = _narrowLNotch();

    // The exact local Clipper1 subset must reject this case: two unrelated
    // horizontal edges meet at the requested erosion distance, so source
    // Execute() boolean cleanup changes topology.
    expect(
      SourceClipper1MiterOffset2
          .supportsSimpleOrthogonalConcavePositiveContour(polygon, -10000),
      isFalse,
    );

    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [polygon],
      -10000,
    );

    // Exact pinned ELF oracle:
    // (30000,90000),(10000,90000),(10000,10000),(30000,10000).
    // This test validates the current compatibility fallback for this fixture;
    // it does not promote the generic Clipper2 fallback to Clipper1 parity.
    expect(result, hasLength(1));
    expect(result.single.points, hasLength(4));
    expect(
      _pointSet(result.single),
      const {
        '30000,90000',
        '10000,90000',
        '10000,10000',
        '30000,10000',
      },
    );
  });

  test('compiled narrow L expansion remains six-corner geometry', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [_narrowLNotch()],
      10000,
    );

    // Exact pinned ELF oracle. The conservative direct Clipper1 subset still
    // declines this geometry, so the source-compatible fallback is compared as
    // an independent differential instead of being mislabeled as a port.
    expect(result, hasLength(1));
    expect(result.single.points, hasLength(6));
    expect(
      _pointSet(result.single),
      const {
        '110000,30000',
        '50000,30000',
        '50000,110000',
        '-10000,110000',
        '-10000,-10000',
        '110000,-10000',
      },
    );
  });
}
