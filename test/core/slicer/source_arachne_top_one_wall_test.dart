import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_top_one_wall.dart';

SourcePolygon2 _rect(int minX, int minY, int maxX, int maxY) =>
    SourcePolygon2([
      SourcePoint2(minX, minY),
      SourcePoint2(maxX, minY),
      SourcePoint2(maxX, maxY),
      SourcePoint2(minX, maxY),
    ]);

void main() {
  test('bbox helper inflates in source coord_t units', () {
    final bounds = SourceArachneTopOneWall2.bounds([
      _rect(10, 20, 30, 50),
    ]).inflated(Slic3rUnits.scaledEpsilon);

    expect(bounds.minX, 0);
    expect(bounds.minY, 10);
    expect(bounds.maxX, 40);
    expect(bounds.maxY, 60);
  });

  test('bbox clipper drops polygon wholly beyond the same side', () {
    final clipped = SourceArachneTopOneWall2.clipWithSubjectBounds(
      [_rect(1000, 1000, 2000, 2000)],
      const SourceArachneBounds2(
        minX: 0,
        minY: 0,
        maxX: 100,
        maxY: 100,
      ),
    );

    expect(clipped, isEmpty);
  });

  test('bbox clipper is vertex pruning rather than rectangle intersection', () {
    final source = SourcePolygon2(const [
      SourcePoint2(-100, 50),
      SourcePoint2(50, 50),
      SourcePoint2(200, 50),
      SourcePoint2(50, 80),
    ]);
    final clipped = SourceArachneTopOneWall2.clipWithSubjectBounds(
      [source],
      const SourceArachneBounds2(
        minX: 0,
        minY: 0,
        maxX: 100,
        maxY: 100,
      ),
    );

    expect(clipped, hasLength(1));
    // Outside vertices whose neighbours could cross the bbox are retained;
    // no synthetic rectangle-intersection coordinates are introduced.
    expect(clipped.single.points, contains(const SourcePoint2(-100, 50)));
    expect(clipped.single.points, contains(const SourcePoint2(200, 50)));
  });

  test('difference and intersection retain source integer polygon domain', () {
    final a = _rect(0, 0, 200000, 100000);
    final b = _rect(100000, 0, 300000, 100000);

    final difference = SourceArachneTopOneWall2.difference([a], [b]);
    final intersection = SourceArachneTopOneWall2.intersection([a], [b]);

    expect(
      difference.fold<double>(0, (sum, polygon) => sum + polygon.signedArea),
      100000 * 100000,
    );
    expect(
      intersection.fold<double>(0, (sum, polygon) => sum + polygon.signedArea),
      100000 * 100000,
    );
  });

  test('large top survives source area-ratio gate and expands by wall width', () {
    final original = [_rect(0, 0, 1000000, 1000000)];
    final top = [_rect(100000, 100000, 900000, 900000)];

    final result = SourceArachneTopOneWall2.shouldEnable(
      originalPolygons: original,
      top: top,
      perimeterWidth: 40000,
      extPerimeterSpacing: 40000,
      topAreaThresholdPercent: 100,
    );

    expect(result.minimumTopWidth, 20000);
    expect(result.enabled, isTrue);
    expect(result.top, isNotEmpty);
    expect(result.shrunkArea / result.originalArea, greaterThan(0.1));
  });

  test('original area below one square millimeter clears top', () {
    final tiny = [_rect(0, 0, 50000, 50000)];

    final result = SourceArachneTopOneWall2.shouldEnable(
      originalPolygons: tiny,
      top: tiny,
      perimeterWidth: 40000,
      extPerimeterSpacing: 40000,
      topAreaThresholdPercent: 0,
    );

    expect(result.enabled, isFalse);
    expect(result.top, isEmpty);
  });

  test('narrow top cleared when shrunken area ratio falls below 0.1', () {
    final original = [_rect(0, 0, 1000000, 1000000)];
    final narrowTop = [_rect(0, 0, 30000, 1000000)];

    final result = SourceArachneTopOneWall2.shouldEnable(
      originalPolygons: original,
      top: narrowTop,
      perimeterWidth: 40000,
      extPerimeterSpacing: 40000,
      topAreaThresholdPercent: 100,
    );

    expect(result.enabled, isFalse);
    expect(result.top, isEmpty);
  });
}
