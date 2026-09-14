import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths_prepare_exact.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_positive_concave_execute.dart';

SourcePolygon2 _vNotch() => SourcePolygon2(const [
      SourcePoint2(0, 0),
      SourcePoint2(100000, 0),
      SourcePoint2(100000, 100000),
      SourcePoint2(60000, 100000),
      SourcePoint2(50000, 70000),
      SourcePoint2(40000, 100000),
      SourcePoint2(0, 100000),
    ]);

void main() {
  test('positive V-notch Execute matches exact pinned ELF output', () {
    final polygon = _vNotch();
    expect(SourceClipper1PositiveConcaveExecute2.supports(polygon, 10000), isTrue);

    final result = SourceClipper1PositiveConcaveExecute2.offset(polygon, 10000);

    // Captured by invoking the exact pinned upstream
    // Slic3r::offset(Polygons const&, 10000.f, jtMiter, 3.) directly in LLDB.
    expect(
      result.points,
      const [
        SourcePoint2(110000, 110000),
        SourcePoint2(52792, 110000),
        SourcePoint2(50000, 101624),
        SourcePoint2(47208, 110000),
        SourcePoint2(-10000, 110000),
        SourcePoint2(-10000, -10000),
        SourcePoint2(110000, -10000),
      ],
    );
  });

  test('negative V-notch remains on full pftNegative cleanup seam', () {
    expect(
      SourceClipper1PositiveConcaveExecute2.supports(_vNotch(), -10000),
      isFalse,
    );
  });

  test('Arachne exact prepare routes positive V-notch off Clipper2 fallback', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [_vNotch()],
      10000,
    );

    expect(result, hasLength(1));
    expect(
      result.single.points,
      const [
        SourcePoint2(110000, 110000),
        SourcePoint2(52792, 110000),
        SourcePoint2(50000, 101624),
        SourcePoint2(47208, 110000),
        SourcePoint2(-10000, 110000),
        SourcePoint2(-10000, -10000),
        SourcePoint2(110000, -10000),
      ],
    );
  });
}
