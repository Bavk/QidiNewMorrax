import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_arc_math.dart';

void main() {
  test('calc_arc_radian returns source CCW and CW quarter-circle values', () {
    final start = SourceVec3f(1, 0, 0);
    final end = SourceVec3f(0, 1, 7); // source ignores Z
    final center = SourceVec3f(0, 0, 3);

    expect(
      SourceArcMath3.arcRadian(start, end, center, true),
      closeTo(math.pi / 2, 1e-6),
    );
    expect(
      SourceArcMath3.arcRadian(start, end, center, false),
      closeTo(3 * math.pi / 2, 1e-6),
    );
  });

  test('same XY start/end is treated as a full circle', () {
    final start = SourceVec3f(1, 0, 0);
    final end = SourceVec3f(1, 0, 100);
    final center = SourceVec3f(0, 0, -50);
    expect(
      SourceArcMath3.arcRadian(start, end, center, true),
      closeTo(2 * math.pi, 1e-6),
    );
  });

  test('calc_arc_radius and length are XY-only source helpers', () {
    final start = SourceVec3f(3, 4, 100);
    final center = SourceVec3f(0, 0, -100);
    expect(SourceArcMath3.arcRadius(start, center), closeTo(5, 1e-6));

    final end = SourceVec3f(-4, 3, 999);
    final length = SourceArcMath3.arcLength(start, end, center, true);
    expect(length, closeTo(5 * math.pi / 2, 2e-6));
  });

  test('calc_tangential_vector follows QIDI CCW/CW orientation', () {
    final position = SourceVec3f(1, 0, 9);
    final center = SourceVec3f(0, 0, 4);

    final ccw = SourceArcMath3.tangentialVector(position, center, true);
    expect(ccw.x, closeTo(0, 1e-7));
    expect(ccw.y, closeTo(1, 1e-7));
    expect(ccw.z, 0);

    final cw = SourceArcMath3.tangentialVector(position, center, false);
    expect(cw.x, closeTo(0, 1e-7));
    expect(cw.y, closeTo(-1, 1e-7));
    expect(cw.z, 0);
  });
}
