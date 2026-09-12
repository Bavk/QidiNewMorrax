import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/expolygon.dart';
import 'package:qidi_flow_flutter/core/geometry/point.dart';
import 'package:qidi_flow_flutter/core/geometry/polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_bridge_detector.dart';

Polygon2 polygon(List<(double, double)> points) => Polygon2([
      for (final point in points) Point2(point.$1, point.$2),
    ]);

ExPolygon2 transform(
  ExPolygon2 value, {
  double dx = 0,
  double dy = 0,
  double rotationDegrees = 0,
  Point2? center,
}) {
  final angle = rotationDegrees * math.pi / 180.0;
  final centerPoint = center ?? const Point2(0, 0);
  Polygon2 apply(Polygon2 input) => Polygon2([
        for (final point in input.points)
          _transformPoint(
            point,
            dx: dx,
            dy: dy,
            angle: angle,
            center: centerPoint,
          ),
      ]);
  return ExPolygon2(
    contour: apply(value.contour),
    holes: [for (final hole in value.holes) apply(hole)],
  );
}

Point2 _transformPoint(
  Point2 input, {
  required double dx,
  required double dy,
  required double angle,
  required Point2 center,
}) {
  final translated = Point2(input.x + dx, input.y + dy);
  if (angle == 0) return translated;

  final source = SourcePoint2.fromMm(translated.x, translated.y);
  final sourceCenter = SourcePoint2.fromMm(center.x + dx, center.y + dy);
  final rotated = source.rotated(angle, center: sourceCenter);
  return Point2(rotated.xMm, rotated.yMm);
}

ExPolygon2 oSupport(double width, double height) => ExPolygon2(
      contour: polygon([
        (-2, -2),
        (width + 2, -2),
        (width + 2, height + 2),
        (-2, height + 2),
      ]),
      holes: [
        polygon([
          (0, 0),
          (0, height),
          (width, height),
          (width, 0),
        ]),
      ],
    );

ExPolygon2 bridgeFromHole(ExPolygon2 support) => ExPolygon2(
      contour: support.holes.single.reversed(),
    );

double coverageArea(SourceBridgeDetector2 detector) =>
    detector.coverage().fold<double>(0, (sum, polygon) => sum + polygon.area);

void expectAngle(double actualRadians, double expectedDegrees,
    {double toleranceDegrees = 5.001}) {
  final actualDegrees = actualRadians * 180.0 / math.pi;
  var delta = actualDegrees - expectedDegrees;
  if (delta >= 180 - 1e-4) delta -= 180;
  if (delta <= -180 + 1e-4) delta += 180;
  expect(delta.abs(), lessThan(toleranceDegrees));
  expect(actualRadians, greaterThanOrEqualTo(0));
}

void verifyFixture({
  required ExPolygon2 bridge,
  required List<ExPolygon2> lower,
  required double expectedDegrees,
  double? expectedCoverage,
  double toleranceDegrees = 5.001,
}) {
  final detector = SourceBridgeDetector2(
    expolygon: bridge,
    lowerSlices: lower,
    spacingSource: Slic3rUnits.scaleTruncated(0.5),
  );

  expect(detector.resolution * 180.0 / math.pi, closeTo(5, 1e-12));
  expect(detector.detectAngle(), isTrue);
  expectAngle(
    detector.angle,
    expectedDegrees,
    toleranceDegrees: toleranceDegrees,
  );
  expect(
    coverageArea(detector),
    closeTo(expectedCoverage ?? bridge.area, 1e-6),
  );
}

void main() {
  group('translated pinned t/bridges.t BridgeDetector fixtures', () {
    test('wide O-shaped overhang bridges vertically', () {
      final lower = transform(oSupport(20, 10), dx: 20, dy: 20);
      verifyFixture(
        bridge: bridgeFromHole(lower),
        lower: [lower],
        expectedDegrees: 90,
      );
    });

    test('tall O-shaped overhang bridges horizontally', () {
      final lower = transform(oSupport(10, 20), dx: 20, dy: 20);
      verifyFixture(
        bridge: bridgeFromHole(lower),
        lower: [lower],
        expectedDegrees: 0,
      );
    });

    test('rotated O-shaped overhang keeps 45-degree source family', () {
      final lower = transform(
        oSupport(20, 10),
        dx: 20,
        dy: 20,
        rotationDegrees: 45,
        center: const Point2(10, 5),
      );
      verifyFixture(
        bridge: bridgeFromHole(lower),
        lower: [lower],
        expectedDegrees: 135,
        toleranceDegrees: 20,
      );
    });

    test('opposite rotated O-shaped overhang keeps source family', () {
      final lower = transform(
        oSupport(20, 10),
        dx: 20,
        dy: 20,
        rotationDegrees: 135,
        center: const Point2(10, 5),
      );
      verifyFixture(
        bridge: bridgeFromHole(lower),
        lower: [lower],
        expectedDegrees: 45,
        toleranceDegrees: 20,
      );
    });

    test('two-sided bridge chooses horizontal direction', () {
      final bridge = transform(
        ExPolygon2(
          contour: polygon([(0, 0), (20, 0), (20, 10), (0, 10)]),
        ),
        dx: 20,
        dy: 20,
      );
      final left = transform(
        ExPolygon2(
          contour: polygon([(-2, 0), (0, 0), (0, 10), (-2, 10)]),
        ),
        dx: 20,
        dy: 20,
      );
      final right = transform(left, dx: 22);
      verifyFixture(
        bridge: bridge,
        lower: [left, right],
        expectedDegrees: 0,
      );
    });

    test('C-shaped support chooses 135 degrees', () {
      final bridge = transform(
        ExPolygon2(
          contour: polygon([(0, 0), (20, 0), (10, 10), (0, 10)]),
        ),
        dx: 20,
        dy: 20,
      );
      final lower = transform(
        ExPolygon2(
          contour: polygon([
            (0, 0),
            (0, 10),
            (10, 10),
            (10, 12),
            (-2, 12),
            (-2, -2),
            (22, -2),
            (22, 0),
          ]),
        ),
        dx: 20,
        dy: 20,
      );
      verifyFixture(
        bridge: bridge,
        lower: [lower],
        expectedDegrees: 135,
      );
    });

    test('L-shaped anchors cover half of square bridge at 45 degrees', () {
      final bridge = transform(
        ExPolygon2(
          contour: polygon([(10, 10), (20, 10), (20, 20), (10, 20)]),
        ),
        dx: 20,
        dy: 20,
      );
      final lower = transform(
        ExPolygon2(
          contour: polygon([
            (10, 10),
            (10, 20),
            (20, 20),
            (30, 30),
            (0, 30),
            (0, 0),
          ]),
        ),
        dx: 20,
        dy: 20,
      );
      verifyFixture(
        bridge: bridge,
        lower: [lower],
        expectedDegrees: 45,
        expectedCoverage: bridge.area / 2,
      );
    });
  });

  test('fully airborne bridge has no detected angle', () {
    final detector = SourceBridgeDetector2(
      expolygon: ExPolygon2(
        contour: polygon([(0, 0), (10, 0), (10, 10), (0, 10)]),
      ),
      lowerSlices: const [],
      spacingSource: Slic3rUnits.scaleTruncated(0.5),
    );
    expect(detector.detectAngle(), isFalse);
    expect(detector.angle, -1);
    expect(detector.coverage(), isEmpty);
  });
}
