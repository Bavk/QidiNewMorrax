import 'source_arachne_beading_meta_strategies.dart';
import 'source_arachne_beading_strategy.dart';
import 'source_arachne_wall_tool_paths_beading_inputs.dart';

/// Direct source-order composition of pinned `BeadingStrategyFactory::makeStrategy`.
class SourceArachneBeadingStrategyFactory2 {
  const SourceArachneBeadingStrategyFactory2._();

  static SourceArachneBeadingStrategy2 makeStrategy(
    SourceArachneWallToolPathsBeadingInputs2 inputs,
  ) {
    SourceArachneBeadingStrategy2 result =
        SourceArachneDistributedBeadingStrategy2(
      optimalWidth: inputs.preferredBeadWidthInner,
      defaultTransitionLength: inputs.preferredTransitionLength,
      transitioningAngle: inputs.transitioningAngleRadians,
      wallSplitMiddleThreshold: inputs.wallSplitMiddleThreshold,
      wallAddMiddleThreshold: inputs.wallAddMiddleThreshold,
      distributionRadius: inputs.inwardDistributedCenterWallCount,
    );

    result = SourceArachneRedistributeBeadingStrategy2(
      optimalWidthOuter: inputs.preferredBeadWidthOuter,
      minimumVariableLineRatio: inputs.minimumVariableLineRatio,
      parent: result,
    );

    if (inputs.printThinWalls) {
      result = SourceArachneWideningBeadingStrategy2(
        parent: result,
        minInputWidth: inputs.minFeatureSize,
        minOutputWidth: inputs.minBeadWidth,
      );
    }

    if (inputs.outerWallOffset != 0) {
      result = SourceArachneOuterWallInsetBeadingStrategy2(
        outerWallOffset: inputs.outerWallOffset,
        parent: result,
      );
    }

    // Pinned source keeps OuterWallContourStrategy behind `#if 0`.
    result = SourceArachneLimitedBeadingStrategy2(
      maxBeadCount: inputs.maxBeadCount,
      parent: result,
    );
    return result;
  }
}
