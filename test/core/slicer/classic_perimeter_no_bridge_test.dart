import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/expolygon.dart';
import 'package:qidi_flow_flutter/core/geometry/point.dart';
import 'package:qidi_flow_flutter/core/geometry/polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_no_bridge.dart';
import 'package:qidi_flow_flutter/core/slicer/surface.dart';

SourcePolygon2 sourceRectangle(
  double minX,
  double minY,
  double maxX,
  double maxY,
) =>
    SourcePolygon2([
      SourcePoint2.fromMm(minX, minY),
      SourcePoint2.fromMm(maxX, minY),
      SourcePoint2.fromMm(maxX, maxY),
      SourcePoint2.fromMm(minX, maxY),
    ]);

Surface2 surfaceBox(
  double minX,
  double minY,
  double maxX,
  double maxY, {
  int extraPerimeters = 0,
  bool counterCircleCompensation = false,
}) =>
    Surface2(
      expolygon: SourceExPolygon2(
        contour: sourceRectangle(minX, minY, maxX, maxY),
      ),
      extraPerimeters: extraPerimeters,
      counterCircleCompensation: counterCircleCompensation,
    );

ExPolygon2 box(double minX, double minY, double maxX, double maxY) =>
    ExPolygon2(
      contour: Polygon2([
        Point2(minX, minY),
        Point2(maxX, minY),
        Point2(maxX, maxY),
        Point2(minX, maxY),
      ]),
    );

const bridgeSettings = SourceClassicNoBridgeSettings2(
  mode: SourceCounterboreHoleBridging2.bridges,
  perimeterSpacingMm: 0.5,
  externalPerimeterWidthMm: 0.4,
);

List<ExPolygon2> sideSupports() => [
      box(0, 0, 4, 10),
      box(16, 0, 20, 10),
    ];

double sourceAreaMm2(SourceExPolygon2 value) =>
    value.area * Slic3rUnits.scalingFactor * Slic3rUnits.scalingFactor;

void main() {
  const process = SourceClassicNoBridge2();

  test('CounterboreHoleBridging enum preserves pinned source order', () {
    expect(
      SourceCounterboreHoleBridging2.values,
      [
        SourceCounterboreHoleBridging2.none,
        SourceCounterboreHoleBridging2.bridges,
        SourceCounterboreHoleBridging2.filled,
      ],
    );
  });

  test('chbNone bypasses detector and preserves source vector-copy fields', () {
    final input = surfaceBox(
      0,
      0,
      20,
      10,
      extraPerimeters: 2,
      counterCircleCompensation: true,
    );
    final result = process.process(
      surfaces: [input],
      lowerSlices: sideSupports(),
      settings: const SourceClassicNoBridgeSettings2(
        mode: SourceCounterboreHoleBridging2.none,
        perimeterSpacingMm: 0.5,
        externalPerimeterWidthMm: 0.4,
      ),
    );

    expect(result.detectorCalls, 0);
    expect(result.fillSurfaces, isEmpty);
    expect(result.surfaces, hasLength(1));
    expect(result.surfaces.single.extraPerimeters, 2);
    // `Surfaces all_surfaces = slices->surfaces` invokes the supplied Surface
    // copy constructor, whose QIDI compensation members are omitted.
    expect(result.surfaces.single.counterCircleCompensation, isFalse);
    expect(sourceAreaMm2(result.surfaces.single.expolygon), closeTo(200, 1e-8));
  });

  test('null and non-null empty lower_slices both take source gate', () {
    final surface = surfaceBox(0, 0, 20, 10);
    final nullLower = process.process(
      surfaces: [surface],
      lowerSlices: null,
      settings: bridgeSettings,
    );
    final emptyLower = process.process(
      surfaces: [surface],
      lowerSlices: const [],
      settings: bridgeSettings,
    );

    expect(nullLower.detectorCalls, 0);
    expect(emptyLower.detectorCalls, 0);
    expect(nullLower.fillSurfaces, isEmpty);
    expect(emptyLower.fillSurfaces, isEmpty);
    expect(sourceAreaMm2(nullLower.surfaces.single.expolygon), closeTo(200, 1e-8));
    expect(sourceAreaMm2(emptyLower.surfaces.single.expolygon), closeTo(200, 1e-8));
  });

  test('chbBridges extracts the supported two-sided bridge into internal fill', () {
    final result = process.process(
      surfaces: [surfaceBox(0, 0, 20, 10)],
      lowerSlices: sideSupports(),
      settings: bridgeSettings,
    );

    expect(result.detectorCalls, greaterThan(0));
    expect(result.extractedBridgeRegions, greaterThan(0));
    expect(result.fillSurfaces, isNotEmpty);
    expect(
      result.fillSurfaces.every((surface) => surface.surfaceType == SurfaceType.internal),
      isTrue,
    );
    final fillArea = result.fillSurfaces.fold<double>(
      0,
      (sum, surface) => sum + sourceAreaMm2(surface.expolygon),
    );
    expect(fillArea, greaterThan(0));
    expect(fillArea, lessThanOrEqualTo(200.001));
  });

  test('chbFilled keeps the convex bridge path active for the same fixture', () {
    final result = process.process(
      surfaces: [surfaceBox(0, 0, 20, 10)],
      lowerSlices: sideSupports(),
      settings: const SourceClassicNoBridgeSettings2(
        mode: SourceCounterboreHoleBridging2.filled,
        perimeterSpacingMm: 0.5,
        externalPerimeterWidthMm: 0.4,
      ),
    );

    expect(result.detectorCalls, greaterThan(0));
    expect(result.extractedBridgeRegions, greaterThan(0));
    expect(result.fillSurfaces, isNotEmpty);
  });

  test('forced bridge angle is passed through the process_no_bridge detector', () {
    final result = process.process(
      surfaces: [surfaceBox(0, 0, 20, 10)],
      lowerSlices: sideSupports(),
      settings: const SourceClassicNoBridgeSettings2(
        mode: SourceCounterboreHoleBridging2.bridges,
        perimeterSpacingMm: 0.5,
        externalPerimeterWidthMm: 0.4,
        bridgeAngleDegrees: 90,
      ),
    );

    // A perpendicular forced direction cannot span both side anchors, so the
    // detector is called but the source leaves no extractable bridge region.
    expect(result.detectorCalls, greaterThan(0));
    expect(result.extractedBridgeRegions, 0);
    expect(result.fillSurfaces, isEmpty);
  });
}
