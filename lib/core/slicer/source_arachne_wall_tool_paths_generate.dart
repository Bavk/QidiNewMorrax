import '../geometry/source_polygon.dart';
import 'source_arachne_beading_strategy_factory.dart';
import 'source_arachne_extrusion_line.dart';
import 'source_arachne_polyline_stitcher.dart';
import 'source_arachne_skeletal_trapezoidation.dart';
import 'source_arachne_wall_tool_paths.dart';
import 'source_arachne_wall_tool_paths_beading_inputs.dart';
import 'source_arachne_wall_tool_paths_postprocess.dart';
import 'source_arachne_wall_tool_paths_prepare.dart';
import 'source_arachne_wall_tool_paths_prepare_exact.dart';

class SourceArachneWallToolPathsGenerated2 {
  const SourceArachneWallToolPathsGenerated2({
    required this.toolpaths,
    required this.innerContour,
    required this.firstWallContour,
    required this.toolpathsGenerated,
    this.prepared,
    this.skeletal,
  });

  final List<List<SourceArachneExtrusionLine2>> toolpaths;
  final List<SourcePolygon2> innerContour;
  final List<SourcePolygon2> firstWallContour;
  final bool toolpathsGenerated;
  final SourceArachnePreparedOutline2? prepared;
  final SourceArachneSkeletalTrapezoidationResult2? skeletal;
}

/// Source-order composition of pinned `Arachne::WallToolPaths::generate()`.
///
/// All algorithmic pieces are kept in their independently testable source
/// ports; this class freezes the real call order and the early-return state.
class SourceArachneWallToolPathsGenerate2 {
  const SourceArachneWallToolPathsGenerate2._();

  static SourceArachneWallToolPathsGenerated2 generate(
    SourceArachneWallToolPathsState2 state, {
    bool enableHoleCompensation = false,
    Iterable<int> holeIndices = const <int>[],
  }) {
    if (state.insetCount < 1) {
      return const SourceArachneWallToolPathsGenerated2(
        toolpaths: [],
        innerContour: [],
        firstWallContour: [],
        toolpathsGenerated: false,
      );
    }

    final prepared = SourceArachneWallToolPathsPrepareExact2.prepare(
      state,
      enableHoleCompensation: enableHoleCompensation,
      holeIndices: holeIndices,
    );
    if (prepared.isEmptyArea) {
      return SourceArachneWallToolPathsGenerated2(
        toolpaths: const [],
        innerContour: const [],
        firstWallContour: const [],
        toolpathsGenerated: false,
        prepared: prepared,
      );
    }

    final inputs = SourceArachneWallToolPathsBeadingInputs2.fromState(state);
    final strategy = SourceArachneBeadingStrategyFactory2.makeStrategy(inputs);
    final skeletal = SourceArachneSkeletalTrapezoidation2.generate(
      prepared.preparedOutline,
      strategy,
      transitioningAngle: strategy.transitioningAngle,
      discretizationStepSize: inputs.discretizationStepSize,
      transitionFilterDistance: inputs.transitionFilterDistance,
      allowedFilterDeviation: inputs.allowedFilterDeviation,
      beadingPropagationTransitionDistance: inputs.preferredTransitionLength,
      enableHoleCompensation: prepared.applyHoleCompensation,
      holeIndices: prepared.holeIndices,
    );

    final rawToolpaths = skeletal.toolpaths;
    SourceArachnePolylineStitcher2.stitchToolPaths(
      rawToolpaths,
      state.beadWidthX,
    );
    SourceArachneWallToolPathsPostprocess2.removeSmallLines(rawToolpaths);
    final separated =
        SourceArachneWallToolPathsPostprocess2.separateOutInnerContour(
      rawToolpaths,
    );
    final toolpaths = separated.toolpaths;
    SourceArachneWallToolPathsPostprocess2.simplifyToolPaths(toolpaths);
    SourceArachneWallToolPathsPostprocess2.removeEmptyToolPaths(toolpaths);

    assert(_sortedOuterToInner(toolpaths));
    return SourceArachneWallToolPathsGenerated2(
      toolpaths: toolpaths,
      innerContour: separated.innerContour,
      firstWallContour: separated.firstWallContour,
      toolpathsGenerated: true,
      prepared: prepared,
      skeletal: skeletal,
    );
  }

  static bool _sortedOuterToInner(
    List<List<SourceArachneExtrusionLine2>> toolpaths,
  ) {
    for (var index = 1; index < toolpaths.length; index++) {
      if (toolpaths[index - 1].isEmpty || toolpaths[index].isEmpty) {
        return false;
      }
      if (toolpaths[index - 1].first.insetIndex >
          toolpaths[index].first.insetIndex) {
        return false;
      }
    }
    return true;
  }
}
