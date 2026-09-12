import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_circle.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';

void main() {
  test('Circle::try_create_circle reconstructs a source-unit semicircle', () {
    final circle = SourceCircle2.tryCreateFromThree(
      const SourcePoint2(100000, 0),
      const SourcePoint2(0, 100000),
      const SourcePoint2(-100000, 0),
      SourceArcSegment2.defaultScaledMaxRadius,
    );

    expect(circle, isNotNull);
    expect(circle!.center, const SourcePoint2(0, 0));
    expect(circle.radius, closeTo(100000, 1e-6));
  });

  test('Circle source scaled-area collinearity guard rejects a line', () {
    final circle = SourceCircle2.tryCreateFromThree(
      const SourcePoint2(0, 0),
      const SourcePoint2(100000, 0),
      const SourcePoint2(200000, 0),
      SourceArcSegment2.defaultScaledMaxRadius,
    );
    expect(circle, isNull);
  });

  test('ArcSegment reverse swaps endpoints and flips signed angle/direction', () {
    final arc = SourceArcSegment2(
      center: const SourcePoint2(0, 0),
      radius: 100000,
      startPoint: const SourcePoint2(100000, 0),
      endPoint: const SourcePoint2(0, 100000),
      direction: ArcDirection2.ccw,
    );
    final originalLength = arc.length;

    expect(arc.reverse(), true);
    expect(arc.startPoint, const SourcePoint2(0, 100000));
    expect(arc.endPoint, const SourcePoint2(100000, 0));
    expect(arc.direction, ArcDirection2.cw);
    expect(arc.angleRadians, closeTo(-math.pi / 2, 1e-12));
    expect(arc.length, closeTo(originalLength, 1e-9));
  });

  test('ArcSegment clip_end projects an interior point onto the circle', () {
    final arc = SourceArcSegment2(
      center: const SourcePoint2(0, 0),
      radius: 100000,
      startPoint: const SourcePoint2(100000, 0),
      endPoint: const SourcePoint2(0, 100000),
      direction: ArcDirection2.ccw,
    );

    expect(arc.clipEnd(const SourcePoint2(70710, 70710)), true);
    expect(arc.endPoint.x, inInclusiveRange(70710, 70711));
    expect(arc.endPoint.y, inInclusiveRange(70710, 70711));
    expect(arc.angleRadians, closeTo(math.pi / 4, 2e-5));
  });

  test('ArcSegment::try_create_arc obeys source 5-percent length contract', () {
    const points = [
      SourcePoint2(100000, 0),
      SourcePoint2(86603, 50000),
      SourcePoint2(50000, 86603),
      SourcePoint2(0, 100000),
    ];
    var approximateLength = 0.0;
    for (var i = 1; i < points.length; i++) {
      approximateLength += (points[i] - points[i - 1]).length;
    }

    final arc = SourceArcSegment2.tryCreateArc(
      points,
      approximateLength: approximateLength,
      tolerance: SourceArcSegment2.defaultScaledResolution,
    );

    expect(arc, isNotNull);
    expect(arc!.direction, ArcDirection2.ccw);
    expect(arc.startPoint, points.first);
    expect(arc.endPoint, points.last);
    expect(
      ((arc.length - approximateLength) / approximateLength).abs(),
      lessThan(SourceArcSegment2.defaultArcLengthPercentTolerance),
    );
  });
}
