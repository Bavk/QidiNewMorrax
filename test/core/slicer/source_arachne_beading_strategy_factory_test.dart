import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_beading_strategy_factory.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths_beading_inputs.dart';

SourceArachneWallToolPathsState2 factoryState({int wall0Inset = 123}) =>
    SourceArachneWallToolPathsState2(
      outline: const [],
      beadWidth0: 40000,
      beadWidthX: 45000,
      insetCount: 2,
      wall0Inset: wall0Inset,
      layerHeightMm: 0.2,
      params: SourceArachneWallToolPathsParams2(
        minBeadWidthMm: 0.1,
        minFeatureSizeMm: 0.2,
        wallTransitionLengthMm: 0.12,
        wallTransitionAngleDeg: 10,
        wallTransitionFilterDeviationMm: 0.02,
        wallDistributionCount: 3,
      ),
    );

void main() {
  test('factory composes pinned wrapper order and preserves Ofset typo', () {
    final strategy = SourceArachneBeadingStrategyFactory2.makeStrategy(
      SourceArachneWallToolPathsBeadingInputs2.fromState(factoryState()),
    );

    expect(
      strategy.toString(),
      'LimitedBeadingStrategy+OuterWallOfsetBeadingStrategy+'
      'Widening+RedistributeBeadingStrategy+DistributedBeadingStrategy',
    );
  });

  test('factory omits outer-wall inset wrapper only when source offset is zero', () {
    final strategy = SourceArachneBeadingStrategyFactory2.makeStrategy(
      SourceArachneWallToolPathsBeadingInputs2.fromState(
        factoryState(wall0Inset: 0),
      ),
    );

    expect(
      strategy.toString(),
      'LimitedBeadingStrategy+Widening+'
      'RedistributeBeadingStrategy+DistributedBeadingStrategy',
    );
  });

  test('factory chain reaches exact four-wall marker geometry', () {
    final strategy = SourceArachneBeadingStrategyFactory2.makeStrategy(
      SourceArachneWallToolPathsBeadingInputs2.fromState(factoryState()),
    );
    final result = strategy.compute(170000, 4);

    expect(result.beadWidths, const [40000, 45000, 0, 45000, 40000]);
    expect(result.toolpathLocations,
        const [20123, 62500, 85000, 107500, 150000]);
    expect(result.leftOver, 0);
    expect(result.totalThickness, 170000);
  });
}
