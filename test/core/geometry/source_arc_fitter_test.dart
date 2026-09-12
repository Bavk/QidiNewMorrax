import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_arc_fitter.dart';
import 'package:qidi_flow_flutter/core/geometry/source_circle.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';

void main() {
  const quarterCircle = [
    SourcePoint2(100000, 0),
    SourcePoint2(86603, 50000),
    SourcePoint2(50000, 86603),
    SourcePoint2(0, 100000),
  ];

  test('ArcFitter emits one CCW arc for a valid quarter-circle stack', () {
    final result = ArcFitter2.doArcFitting(
      quarterCircle,
      SourceArcSegment2.defaultScaledResolution,
    );

    expect(result, hasLength(1));
    expect(result.single.startPointIndex, 0);
    expect(result.single.endPointIndex, 3);
    expect(result.single.pathType, MovePathType2.arcCcw);
    expect(result.single.arcData.direction, ArcDirection2.ccw);
  });

  test('ArcFitter merges a straight point stack into one linear range', () {
    const points = [
      SourcePoint2(0, 0),
      SourcePoint2(10000, 0),
      SourcePoint2(20000, 0),
      SourcePoint2(30000, 0),
    ];
    final result = ArcFitter2.doArcFitting(points, 5000);

    expect(result, hasLength(1));
    expect(result.single.pathType, MovePathType2.linear);
    expect(result.single.startPointIndex, 0);
    expect(result.single.endPointIndex, 3);
  });

  test('do_arc_fitting_and_simplify uses source DP on all-linear data', () {
    const points = [
      SourcePoint2(0, 0),
      SourcePoint2(10000, 10),
      SourcePoint2(20000, -10),
      SourcePoint2(30000, 0),
    ];
    final output = ArcFitter2.doArcFittingAndSimplify(points, 100);

    expect(
      output.points,
      const [SourcePoint2(0, 0), SourcePoint2(30000, 0)],
    );
    expect(output.result, hasLength(1));
    expect(output.result.single.pathType, MovePathType2.linear);
    expect(output.result.single.endPointIndex, 1);
  });

  test('PathFittingData reverse_arc_path follows ArcSegment direction', () {
    final data = PathFittingData2(
      startPointIndex: 0,
      endPointIndex: 2,
      pathType: MovePathType2.arcCcw,
      arcData: SourceArcSegment2(
        center: const SourcePoint2(0, 0),
        radius: 100000,
        startPoint: const SourcePoint2(100000, 0),
        endPoint: const SourcePoint2(0, 100000),
        direction: ArcDirection2.ccw,
      ),
    );

    expect(data.reverseArcPath(), true);
    expect(data.pathType, MovePathType2.arcCw);
    expect(data.arcData.direction, ArcDirection2.cw);
  });
}
