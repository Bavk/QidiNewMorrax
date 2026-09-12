import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_loop_node.dart';

void main() {
  test('Point::is_in_lines preserves endpoint and axis-aligned source checks', () {
    final points = const [
      SourcePoint2(0, 0),
      SourcePoint2(100, 0),
      SourcePoint2(100, 100),
    ];

    expect(
      SourceLoopNodeGeometry2.pointIsInLines(
        const SourcePoint2(0, 0),
        points,
      ),
      isTrue,
    );
    expect(
      SourceLoopNodeGeometry2.pointIsInLines(
        const SourcePoint2(50, 0),
        points,
      ),
      isTrue,
    );
    expect(
      SourceLoopNodeGeometry2.pointIsInLines(
        const SourcePoint2(100, 50),
        points,
      ),
      isTrue,
    );
    expect(
      SourceLoopNodeGeometry2.pointIsInLines(
        const SourcePoint2(150, 0),
        points,
      ),
      isFalse,
    );
  });

  test('Point::is_in_lines uses strict SCALED_EPSILON diagonal distance', () {
    final points = const [SourcePoint2(0, 0), SourcePoint2(100, 100)];

    // Distances from y=x are 9.899... and 10.606... source units.
    expect(
      SourceLoopNodeGeometry2.pointIsInLines(
        const SourcePoint2(50, 64),
        points,
      ),
      isTrue,
    );
    expect(
      SourceLoopNodeGeometry2.pointIsInLines(
        const SourcePoint2(50, 65),
        points,
      ),
      isFalse,
    );
  });

  test('LoopNode bbox expands by exact SCALED_EPSILON', () {
    final bounds = SourceLoopNodeBounds2.fromPoints(const [
      SourcePoint2(-20, 30),
      SourcePoint2(100, 80),
      SourcePoint2(40, -50),
    ]);

    expect(bounds.min, const SourcePoint2(-30, -60));
    expect(bounds.max, const SourcePoint2(110, 90));
  });
}
