import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_top_one_wall_context.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_wall_sequence.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_process_planning.dart';

SourceArachneProcessPlanningSettings2 _settings({
  int wallLoops = 3,
  bool alternateExtraWall = false,
  bool spiralVase = false,
  bool preciseOuterWall = false,
  SourceWallSequence2 wallSequence = SourceWallSequence2.innerOuter,
  bool onlyOneWallFirstLayer = false,
  SourceTopOneWallType2 topOneWallType = SourceTopOneWallType2.none,
  List<SourcePolygon2>? upperSlices = const <SourcePolygon2>[],
  int extWidth = 5,
  int extSpacing = 2,
}) =>
    SourceArachneProcessPlanningSettings2(
      wallLoops: wallLoops,
      alternateExtraWall: alternateExtraWall,
      spiralVase: spiralVase,
      preciseOuterWall: preciseOuterWall,
      wallSequence: wallSequence,
      onlyOneWallFirstLayer: onlyOneWallFirstLayer,
      topOneWallType: topOneWallType,
      upperSlices: upperSlices,
      extPerimeterWidth: extWidth,
      extPerimeterSpacing: extSpacing,
      minNozzleDiameterMm: 0.4,
      minBeadWidthPercent: 50,
      minFeatureSizePercent: 25,
      wallTransitionLengthPercent: 100,
      wallTransitionAngleDeg: 11.25,
      wallTransitionFilterDeviationPercent: 10,
      wallDistributionCount: 3,
    );

void main() {
  test('loop_number is wall loops plus surface extra minus one', () {
    final plan = SourceArachneProcessPlanning2.planSurface(
      settings: _settings(wallLoops: 3),
      extraPerimeters: 2,
      layerIndex: 2,
    );

    expect(plan.loopNumber, 4);
    expect(plan.initialInsetCount, 5);
  });

  test('alternate extra wall increments odd non-spiral layer only', () {
    final settings = _settings(
      wallLoops: 2,
      alternateExtraWall: true,
    );

    expect(
      SourceArachneProcessPlanning2.planSurface(
        settings: settings,
        extraPerimeters: 0,
        layerIndex: 1,
      ).loopNumber,
      2,
    );
    expect(
      SourceArachneProcessPlanning2.planSurface(
        settings: settings,
        extraPerimeters: 0,
        layerIndex: 2,
      ).loopNumber,
      1,
    );
    expect(
      SourceArachneProcessPlanning2.planSurface(
        settings: _settings(
          wallLoops: 2,
          alternateExtraWall: true,
          spiralVase: true,
        ),
        extraPerimeters: 0,
        layerIndex: 1,
      ).loopNumber,
      1,
    );
  });

  test('precise outer wall is gated by InnerOuter sequence', () {
    final precise = SourceArachneProcessPlanning2.planSurface(
      settings: _settings(preciseOuterWall: true),
      extraPerimeters: 0,
      layerIndex: 2,
    );
    final wrongSequence = SourceArachneProcessPlanning2.planSurface(
      settings: _settings(
        preciseOuterWall: true,
        wallSequence: SourceWallSequence2.outerInner,
      ),
      extraPerimeters: 0,
      layerIndex: 2,
    );

    expect(precise.applyPreciseOuterWall, isTrue);
    expect(wrongSequence.applyPreciseOuterWall, isFalse);
  });

  test('normal offset uses double halves then float while wall0 uses integer halves', () {
    final normal = SourceArachneProcessPlanning2.planSurface(
      settings: _settings(extWidth: 5, extSpacing: 2),
      extraPerimeters: 0,
      layerIndex: 2,
    );
    final precise = SourceArachneProcessPlanning2.planSurface(
      settings: _settings(
        preciseOuterWall: true,
        extWidth: 5,
        extSpacing: 2,
      ),
      extraPerimeters: 0,
      layerIndex: 2,
    );

    expect(normal.outerOffsetDelta, -1.5);
    expect(normal.wall0Inset, 0);
    expect(precise.outerOffsetDelta, -3.0);
    // -(5/2 - 2/2) with integer coord_t division = -(2 - 1).
    expect(precise.wall0Inset, -1);
  });

  test('first-layer gate forces one wall only when walls already exist', () {
    final oneWall = SourceArachneProcessPlanning2.planSurface(
      settings: _settings(
        wallLoops: 3,
        onlyOneWallFirstLayer: true,
      ),
      extraPerimeters: 0,
      layerIndex: 0,
    );
    final zeroConfigured = SourceArachneProcessPlanning2.planSurface(
      settings: _settings(
        wallLoops: 0,
        onlyOneWallFirstLayer: true,
      ),
      extraPerimeters: 0,
      layerIndex: 0,
    );

    expect(oneWall.generateOneWallByFirstLayer, isTrue);
    expect(oneWall.isOneWall, isTrue);
    expect(oneWall.initialInsetCount, 1);
    expect(zeroConfigured.loopNumber, -1);
    expect(zeroConfigured.generateOneWallByFirstLayer, isFalse);
    expect(zeroConfigured.initialInsetCount, isNull);
  });

  test('nonnull Alltop requests separated one-wall first pass', () {
    final plan = SourceArachneProcessPlanning2.planSurface(
      settings: _settings(
        wallLoops: 3,
        topOneWallType: SourceTopOneWallType2.allTop,
        upperSlices: const <SourcePolygon2>[],
      ),
      extraPerimeters: 0,
      layerIndex: 2,
    );

    expect(plan.generateOneWallByTop, isTrue);
    expect(plan.generateOneWallByTopMost, isFalse);
    expect(plan.isOneWall, isFalse);
    expect(plan.separateWallGenerationCandidate, isTrue);
    expect(plan.initialInsetCount, 1);
  });

  test('null upper slices force topmost one wall for either enabled top mode', () {
    for (final type in [
      SourceTopOneWallType2.allTop,
      SourceTopOneWallType2.topmost,
    ]) {
      final plan = SourceArachneProcessPlanning2.planSurface(
        settings: _settings(
          wallLoops: 3,
          topOneWallType: type,
          upperSlices: null,
        ),
        extraPerimeters: 0,
        layerIndex: 4,
      );

      expect(plan.generateOneWallByTopMost, isTrue);
      expect(plan.generateOneWallByTop, isFalse);
      expect(plan.isOneWall, isTrue);
      expect(plan.separateWallGenerationCandidate, isFalse);
      expect(plan.initialInsetCount, 1);
    }
  });

  test('process config creates float32 WallToolPathsParams payload', () {
    final plan = SourceArachneProcessPlanning2.planSurface(
      settings: _settings(),
      extraPerimeters: 0,
      layerIndex: 2,
    );

    expect(plan.params.minBeadWidthMm, closeTo(0.2, 1e-7));
    expect(plan.params.minFeatureSizeMm, closeTo(0.1, 1e-7));
    expect(plan.params.wallTransitionLengthMm, closeTo(0.4, 1e-7));
    expect(plan.params.wallTransitionAngleDeg, closeTo(11.25, 1e-7));
    expect(
      plan.params.wallTransitionFilterDeviationMm,
      closeTo(0.04, 1e-7),
    );
    expect(plan.params.wallDistributionCount, 3);
  });
}
