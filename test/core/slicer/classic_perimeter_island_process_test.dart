import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/expolygon.dart';
import 'package:qidi_flow_flutter/core/geometry/point.dart';
import 'package:qidi_flow_flutter/core/geometry/polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_fill_boundary.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_fill_process.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_island_process.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_no_bridge.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_top_one_wall_context.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_policy.dart';
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
}) =>
    Surface2(
      expolygon: SourceExPolygon2(
        contour: sourceRectangle(minX, minY, maxX, maxY),
      ),
      extraPerimeters: extraPerimeters,
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

const oneWallFill = SourceClassicPerimeterFillProcessSettings2(
  perimeter: ClassicPerimeterSettings(
    wallLoops: 1,
    externalPerimeterWidth: 0.4,
    externalPerimeterSpacing: 0.4,
    perimeterWidth: 0.4,
    perimeterSpacing: 0.4,
  ),
  solidInfillSpacingMm: 0.4,
  infillWallOverlap: SourceFloatOrPercent2.absolute(0),
);

const baseSettings = SourceClassicPerimeterIslandProcessSettings2(
  fillProcess: oneWallFill,
  resolutionMm: 0.05,
  enableArcFitting: false,
  fuzzySkinType: SourceFuzzySkinType2.none,
);

void main() {
  const process = SourceClassicPerimeterIslandProcess2();

  test('process_no_bridge feeds chain_expolygons ordered islands', () {
    final result = process.generate(
      surfaces: [
        surfaceBox(-1, -1, 1, 1),
        surfaceBox(29, -1, 31, 1),
        surfaceBox(9, -1, 11, 1),
      ],
      settings: baseSettings,
      layerIndex: 2,
    );

    expect(result.noBridge.detectorCalls, 0);
    expect(result.preparation.surfaceOrder, [1, 2, 0]);
    expect(
      [for (final island in result.islands) island.prepared.sourceIndex],
      [1, 2, 0],
    );
    expect(result.islands, hasLength(3));
    expect(
      result.islands.every(
        (island) => island.process.perimeter.effectiveLoopCount == 1,
      ),
      isTrue,
    );
    expect(result.fillSurfaces, hasLength(3));
    expect(result.fillNoOverlap, hasLength(3));
  });

  test('surface extra_perimeters reaches actual per-island shell count', () {
    final result = process.generate(
      surfaces: [surfaceBox(0, 0, 30, 30, extraPerimeters: 2)],
      settings: baseSettings,
      layerIndex: 2,
    );

    final island = result.islands.single;
    expect(island.prepared.loopNumber, 2);
    expect(island.process.perimeter.effectiveLoopCount, 3);
    expect(island.process.perimeter.loops, hasLength(3));
  });

  test('conditional shell resolution and base final-fill resolution stay distinct', () {
    final result = process.generate(
      surfaces: [surfaceBox(0, 0, 20, 20)],
      settings: const SourceClassicPerimeterIslandProcessSettings2(
        fillProcess: oneWallFill,
        resolutionMm: 0.05,
        enableArcFitting: true,
        fuzzySkinType: SourceFuzzySkinType2.none,
      ),
      layerIndex: 2,
    );

    expect(result.preparation.surfaceSimplifyResolutionMm, closeTo(0.01, 1e-12));
    expect(result.preparation.baseResolutionMm, closeTo(0.05, 1e-12));
    expect(result.islands.single.process.fillBoundary.fillSurfaces, isNotEmpty);
  });

  test('counterbore extraction is accumulated before per-island fills', () {
    final result = process.generate(
      surfaces: [surfaceBox(0, 0, 20, 10)],
      lowerSlices: [
        box(0, 0, 4, 10),
        box(16, 0, 20, 10),
      ],
      settings: const SourceClassicPerimeterIslandProcessSettings2(
        fillProcess: oneWallFill,
        resolutionMm: 0.05,
        enableArcFitting: false,
        fuzzySkinType: SourceFuzzySkinType2.none,
        counterboreHoleBridging: SourceCounterboreHoleBridging2.bridges,
      ),
      layerIndex: 2,
    );

    expect(result.noBridge.detectorCalls, greaterThan(0));
    expect(result.noBridge.fillSurfaces, isNotEmpty);
    expect(result.fillSurfaces.length,
        greaterThanOrEqualTo(result.noBridge.fillSurfaces.length));
    expect(
      identical(result.fillSurfaces.first, result.noBridge.fillSurfaces.first),
      isTrue,
    );
  });

  test('topmost one-wall gate is applied after per-surface wall accounting', () {
    final result = process.generate(
      surfaces: [surfaceBox(0, 0, 30, 30, extraPerimeters: 2)],
      settings: const SourceClassicPerimeterIslandProcessSettings2(
        fillProcess: SourceClassicPerimeterFillProcessSettings2(
          perimeter: ClassicPerimeterSettings(
            wallLoops: 2,
            externalPerimeterWidth: 0.4,
            externalPerimeterSpacing: 0.4,
            perimeterWidth: 0.4,
            perimeterSpacing: 0.4,
          ),
          solidInfillSpacingMm: 0.4,
          infillWallOverlap: SourceFloatOrPercent2.absolute(0),
        ),
        resolutionMm: 0.05,
        enableArcFitting: false,
        fuzzySkinType: SourceFuzzySkinType2.none,
      ),
      layerIndex: 3,
      topOneWall: const SourceClassicTopOneWallContext2(
        type: SourceTopOneWallType2.topmost,
        upperSlices: null,
      ),
    );

    final island = result.islands.single;
    // Before the gate source loop_number is 2 + 2 - 1 = 3 (four walls).
    expect(island.prepared.loopNumber, 3);
    expect(island.process.perimeter.effectiveLoopCount, 1);
    expect(island.process.perimeter.loops, hasLength(1));
  });

  test('source all_surfaces copy quirk precedes compensation metadata capture', () {
    final hole = sourceRectangle(4, 4, 6, 6).reversed();
    final input = Surface2(
      expolygon: SourceExPolygon2(
        contour: sourceRectangle(0, 0, 10, 10),
        holes: [hole],
      ),
      counterCircleCompensation: true,
      holesCircleCompensation: const [0],
    );

    final result = process.generate(
      surfaces: [input],
      settings: baseSettings,
      layerIndex: 2,
    );

    expect(result.noBridge.surfaces.single.counterCircleCompensation, isFalse);
    expect(result.noBridge.surfaces.single.holesCircleCompensation, isEmpty);
    expect(result.islands.single.prepared.counterCircleCompensation, isFalse);
    expect(result.islands.single.prepared.compensationHoleCenters, isEmpty);
  });
}
