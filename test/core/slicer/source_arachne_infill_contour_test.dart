import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_fill_boundary.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_infill_contour.dart';

SourceExPolygon2 _box(int minX, int minY, int maxX, int maxY) =>
    SourceExPolygon2(
      contour: SourcePolygon2([
        SourcePoint2(minX, minY),
        SourcePoint2(maxX, minY),
        SourcePoint2(maxX, maxY),
        SourcePoint2(minX, maxY),
      ]),
    );

(int, int, int, int) _bounds(SourceExPolygon2 value) {
  final points = value.contour.points;
  return (
    points.map((point) => point.x).reduce((a, b) => a < b ? a : b),
    points.map((point) => point.y).reduce((a, b) => a < b ? a : b),
    points.map((point) => point.x).reduce((a, b) => a > b ? a : b),
    points.map((point) => point.y).reduce((a, b) => a > b ? a : b),
  );
}

SourceArachneInfillContourSettings2 _settings(
  SourceFloatOrPercent2 overlap, {
  int spacing = 40000,
}) =>
    SourceArachneInfillContourSettings2(
      externalPerimeterSpacingSource: 40000,
      perimeterSpacingSource: 50000,
      solidInfillSpacingSource: 40000,
      spacingSource: spacing,
      surfaceSimplifyResolutionSource: 0,
      infillWallOverlap: overlap,
    );

void main() {
  test('single-wall percent overlap keeps pinned 7999 truncation quirk', () {
    final result = const SourceArachneInfillContour2().build(
      infillContour: [_box(0, 0, 1000000, 1000000)],
      loops: 0,
      isInnerPart: false,
      settings: _settings(const SourceFloatOrPercent2.percent(20)),
    );

    expect(result.resolvedInsertSource, 7999);
    expect(result.minPerimeterInfillSpacingSource, 24000);
    expect(result.filteredOutAsTooSmall, isFalse);
    expect(result.fillSurfaces, hasLength(1));
    expect(result.fillNoOverlap, hasLength(1));
    expect(_bounds(result.fillSurfaces.single.expolygon),
        (-7999, -7999, 1007999, 1007999));
    expect(_bounds(result.fillNoOverlap.single), (0, 0, 1000000, 1000000));
  });

  test('multiple walls resolve overlap against regular perimeter spacing', () {
    final result = const SourceArachneInfillContour2().build(
      infillContour: [_box(0, 0, 1000000, 1000000)],
      loops: 1,
      isInnerPart: false,
      settings: _settings(const SourceFloatOrPercent2.percent(20)),
    );

    expect(result.resolvedInsertSource, 10000);
    expect(_bounds(result.fillSurfaces.single.expolygon),
        (-10000, -10000, 1010000, 1010000));
    expect(_bounds(result.fillNoOverlap.single), (0, 0, 1000000, 1000000));
  });

  test('inner part uses perimeter spacing even at source loop zero', () {
    final result = const SourceArachneInfillContour2().build(
      infillContour: [_box(0, 0, 1000000, 1000000)],
      loops: 0,
      isInnerPart: true,
      settings: _settings(const SourceFloatOrPercent2.percent(20)),
    );

    expect(result.resolvedInsertSource, 10000);
  });

  test('negative loop count resolves zero overlap basis like source', () {
    final result = const SourceArachneInfillContour2().build(
      infillContour: [_box(0, 0, 1000000, 1000000)],
      loops: -1,
      isInnerPart: false,
      settings: _settings(const SourceFloatOrPercent2.percent(20)),
    );

    expect(result.resolvedInsertSource, 0);
    expect(_bounds(result.fillSurfaces.single.expolygon),
        (0, 0, 1000000, 1000000));
  });

  test('spacing-half probe clears an infill region that is too narrow', () {
    final result = const SourceArachneInfillContour2().build(
      infillContour: [_box(0, 0, 30000, 100000)],
      loops: 0,
      isInnerPart: false,
      settings: _settings(
        const SourceFloatOrPercent2.absolute(0),
        spacing: 40000,
      ),
    );

    expect(result.filteredOutAsTooSmall, isTrue);
    expect(result.fillSurfaces, isEmpty);
    expect(result.fillNoOverlap, isEmpty);
  });

  test('absolute overlap ignores spacing basis after source branch selection', () {
    final result = const SourceArachneInfillContour2().build(
      infillContour: [_box(0, 0, 1000000, 1000000)],
      loops: 3,
      isInnerPart: true,
      settings: _settings(const SourceFloatOrPercent2.absolute(0.125)),
    );

    expect(result.resolvedInsertSource, 12499);
    expect(_bounds(result.fillSurfaces.single.expolygon),
        (-12499, -12499, 1012499, 1012499));
  });
}
