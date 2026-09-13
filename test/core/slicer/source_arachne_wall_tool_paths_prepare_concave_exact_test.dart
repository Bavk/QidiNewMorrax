import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths_prepare_exact.dart';

SourcePolygon2 _lNotch() => SourcePolygon2(const [
      SourcePoint2(0, 0),
      SourcePoint2(100000, 0),
      SourcePoint2(100000, 40000),
      SourcePoint2(40000, 40000),
      SourcePoint2(40000, 100000),
      SourcePoint2(0, 100000),
    ]);

void main() {
  test('Arachne exact prepare routes positive safe concave offset to Clipper1', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [_lNotch()],
      10000,
    );

    expect(result, hasLength(1));
    expect(
      result.single.points,
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

  test('Arachne exact prepare routes negative safe concave offset to Clipper1', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [_lNotch()],
      -10000,
    );

    expect(result, hasLength(1));
    expect(
      result.single.points,
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
}
