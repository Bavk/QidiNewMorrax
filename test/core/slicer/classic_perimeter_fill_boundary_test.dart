import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/expolygon.dart';
import 'package:qidi_flow_flutter/core/geometry/point.dart';
import 'package:qidi_flow_flutter/core/geometry/polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_fill_boundary.dart';
import 'package:qidi_flow_flutter/core/slicer/surface.dart';

ExPolygon2 rectangle(double minX, double minY, double maxX, double maxY) =>
    ExPolygon2(
      contour: Polygon2([
        Point2(minX, minY),
        Point2(maxX, minY),
        Point2(maxX, maxY),
        Point2(minX, maxY),
      ]),
    );

(int, int, int, int) bounds(Iterable<SourceExPolygon2> expolygons) {
  final points = [
    for (final expolygon in expolygons) ...[
      ...expolygon.contour.points,
      for (final hole in expolygon.holes) ...hole.points,
    ],
  ];
  expect(points, isNotEmpty);
  var minX = points.first.x;
  var minY = points.first.y;
  var maxX = points.first.x;
  var maxY = points.first.y;
  for (final point in points.skip(1)) {
    if (point.x < minX) minX = point.x;
    if (point.y < minY) minY = point.y;
    if (point.x > maxX) maxX = point.x;
    if (point.y > maxY) maxY = point.y;
  }
  return (minX, minY, maxX, maxY);
}

SourceClassicFillBoundarySettings2 settings({
  SourceFloatOrPercent2 overlap = const SourceFloatOrPercent2.absolute(0),
  double solidSpacing = 0.4,
}) =>
    SourceClassicFillBoundarySettings2(
      externalPerimeterSpacingMm: 0.4,
      perimeterSpacingMm: 0.45,
      solidInfillSpacingMm: solidSpacing,
      infillWallOverlap: overlap,
    );

void main() {
  const builder = SourceClassicFillBoundary2();

  test('one-loop zero-overlap boundary shrinks by external spacing half', () {
    final result = builder.build(
      last: [rectangle(0, 0, 20, 20)],
      effectiveLoopCount: 1,
      settings: settings(),
    );

    expect(result.insetSource, 20000);
    expect(result.infillPerimeterOverlapSource, 0);
    expect(result.minPerimeterInfillSpacingSource, 24000);
    expect(result.fillSurfaces, hasLength(1));
    expect(result.fillSurfaces.single.surfaceType, SurfaceType.internal);
    expect(
      bounds(result.fillSurfaces.map((surface) => surface.expolygon)),
      (20000, 20000, 1980000, 1980000),
    );
    expect(
      bounds(result.fillNoOverlap),
      (20000, 20000, 1980000, 1980000),
    );
  });

  test('absolute overlap expands fill but keeps no-overlap at wall boundary', () {
    final result = builder.build(
      last: [rectangle(0, 0, 20, 20)],
      effectiveLoopCount: 1,
      settings: settings(
        overlap: const SourceFloatOrPercent2.absolute(0.05),
      ),
    );

    expect(result.infillPerimeterOverlapSource, 5000);
    expect(result.insetSource, 15000);
    expect(
      bounds(result.fillSurfaces.map((surface) => surface.expolygon)),
      (15000, 15000, 1985000, 1985000),
    );
    expect(
      bounds(result.fillNoOverlap),
      (20000, 20000, 1980000, 1980000),
    );
  });

  test('percent overlap preserves source double-to-coord truncation', () {
    final result = builder.build(
      last: [rectangle(0, 0, 20, 20)],
      effectiveLoopCount: 1,
      settings: settings(
        overlap: const SourceFloatOrPercent2.percent(20),
      ),
    );

    // C++ oracle for pinned Config.hpp order `ratio_over * value / 100`:
    // ratio_over = 0.40000000000000002, scaled result =
    // 7999.9999999999991, then coord_t truncates to 7999.
    expect(result.infillPerimeterOverlapSource, 7999);
    expect(result.insetSource, 12001);
    expect(
      bounds(result.fillSurfaces.map((surface) => surface.expolygon)),
      (12001, 12001, 1987999, 1987999),
    );
    expect(
      bounds(result.fillNoOverlap),
      (20000, 20000, 1980000, 1980000),
    );
  });

  test('large overlap selects source single-offset no-overlap branch', () {
    final result = builder.build(
      last: [rectangle(0, 0, 20, 20)],
      effectiveLoopCount: 1,
      settings: settings(
        overlap: const SourceFloatOrPercent2.absolute(0.2),
      ),
    );

    expect(result.infillPerimeterOverlapSource, 20000);
    expect(result.insetSource, 0);
    expect(
      bounds(result.fillSurfaces.map((surface) => surface.expolygon)),
      (0, 0, 2000000, 2000000),
    );
    expect(
      bounds(result.fillNoOverlap),
      (20000, 20000, 1980000, 1980000),
    );
  });

  test('no-perimeter branch does not apply configured wall overlap', () {
    final result = builder.build(
      last: [rectangle(0, 0, 20, 20)],
      effectiveLoopCount: 0,
      settings: settings(
        overlap: const SourceFloatOrPercent2.percent(50),
      ),
    );

    expect(result.insetSource, 0);
    expect(result.infillPerimeterOverlapSource, 0);
    expect(
      bounds(result.fillSurfaces.map((surface) => surface.expolygon)),
      (0, 0, 2000000, 2000000),
    );
    expect(
      bounds(result.fillNoOverlap),
      (0, 0, 2000000, 2000000),
    );
  });

  test('two-or-more loops use internal perimeter spacing half', () {
    final result = builder.build(
      last: [rectangle(0, 0, 20, 20)],
      effectiveLoopCount: 2,
      settings: settings(),
    );

    expect(result.insetSource, 22500);
    expect(
      bounds(result.fillSurfaces.map((surface) => surface.expolygon)),
      (22500, 22500, 1977500, 1977500),
    );
  });

  test('top fill grows fill surface by overlap but no-overlap uses raw top clip', () {
    final result = builder.build(
      last: [rectangle(0, 0, 20, 20)],
      effectiveLoopCount: 1,
      settings: settings(
        overlap: const SourceFloatOrPercent2.absolute(0.05),
      ),
      topFills: [rectangle(0, 0, 5, 5)],
      fillClip: [rectangle(0, 0, 5, 5)],
    );

    expect(
      bounds(result.fillSurfaces.map((surface) => surface.expolygon)),
      (-5000, -5000, 1985000, 1985000),
    );
    expect(
      bounds(result.fillNoOverlap),
      (0, 0, 1980000, 1980000),
    );
  });

  test('odd minimum spacing preserves source coord_t truncation', () {
    final result = builder.build(
      last: [rectangle(0, 0, 20, 20)],
      effectiveLoopCount: 1,
      settings: settings(solidSpacing: 0.40003),
    );

    // scaled solid spacing = 40003; coord_t(40003 * 0.6) = 24001.
    expect(result.minPerimeterInfillSpacingSource, 24001);
  });
}
