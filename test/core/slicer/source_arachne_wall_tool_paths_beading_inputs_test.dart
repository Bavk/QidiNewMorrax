import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths_beading_inputs.dart';

SourceArachneWallToolPathsState2 fixtureState({
  int insetCount = 2,
  double wallTransitionAngleDeg = 10,
}) =>
    SourceArachneWallToolPathsState2(
      outline: const [],
      beadWidth0: 40000,
      beadWidthX: 45000,
      insetCount: insetCount,
      wall0Inset: 123,
      layerHeightMm: 0.2,
      params: SourceArachneWallToolPathsParams2(
        minBeadWidthMm: 0.1,
        minFeatureSizeMm: 0.2,
        wallTransitionLengthMm: 0.12,
        wallTransitionAngleDeg: wallTransitionAngleDeg,
        wallTransitionFilterDeviationMm: 0.02,
        wallDistributionCount: 3,
      ),
    );

void main() {
  test('pre-beading widths preserve unscale<float> and Flow float return', () {
    final inputs = SourceArachneWallToolPathsBeadingInputs2.fromState(
      fixtureState(),
    );

    expect(inputs.externalPerimeterExtrusionWidthMm, 0.44292035698890686);
    expect(inputs.perimeterExtrusionWidthMm, 0.4929203689098358);
  });

  test('pre-beading thresholds use double unscale after float widths', () {
    final inputs = SourceArachneWallToolPathsBeadingInputs2.fromState(
      fixtureState(),
    );

    expect(inputs.wallSplitMiddleThreshold, 0.01);
    expect(inputs.wallAddMiddleThreshold, 0.20287252527454763);
  });

  test('factory payload preserves source float scaling and float deg2rad', () {
    final inputs = SourceArachneWallToolPathsBeadingInputs2.fromState(
      fixtureState(),
    );

    expect(inputs.preferredBeadWidthOuter, 40000);
    expect(inputs.preferredBeadWidthInner, 45000);
    expect(inputs.preferredTransitionLength, 12000);
    expect(inputs.transitioningAngleRadians, 0.1745329350233078);
    expect(inputs.printThinWalls, isTrue);
    expect(inputs.minBeadWidth, 10000);
    expect(inputs.minFeatureSize, 20000);
    expect(inputs.outerWallOffset, 123);
    expect(inputs.inwardDistributedCenterWallCount, 3);
    expect(inputs.minimumVariableLineRatio, 0.5);
  });

  test('SkeletalTrapezoidation scalar inputs preserve literal source casts', () {
    final inputs = SourceArachneWallToolPathsBeadingInputs2.fromState(
      fixtureState(),
    );

    expect(inputs.discretizationStepSize, 80000);
    expect(inputs.transitionFilterDistance, 10000000);
    expect(inputs.allowedFilterDeviation, 2000);
  });

  test('max bead count saturates at exact source int32 half boundary', () {
    expect(
      SourceArachneWallToolPathsBeadingInputs2.maxBeadCountForInsetCount(
        1073741822,
      ),
      2147483644,
    );
    expect(
      SourceArachneWallToolPathsBeadingInputs2.maxBeadCountForInsetCount(
        1073741823,
      ),
      2147483647,
    );
    expect(
      SourceArachneWallToolPathsBeadingInputs2.maxBeadCountForInsetCount(
        1073741824,
      ),
      2147483647,
    );
  });

  test('non-integer transition angle is rounded through float template', () {
    final inputs = SourceArachneWallToolPathsBeadingInputs2.fromState(
      fixtureState(wallTransitionAngleDeg: 10.1),
    );

    expect(inputs.transitioningAngleRadians, 0.1762782633304596);
  });
}
