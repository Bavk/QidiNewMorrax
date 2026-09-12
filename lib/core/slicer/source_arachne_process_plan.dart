import '../geometry/source_polygon.dart';
import 'classic_top_one_wall_context.dart';
import 'source_arachne_wall_tool_paths.dart';
import 'source_arachne_wall_tool_paths_generate.dart';

class SourceArachneProcessPlan2 {
  const SourceArachneProcessPlan2({
    required this.isOneWall,
    required this.separateWallGeneration,
    required this.wall0Inset,
    required this.insetCount,
    this.generated,
  });

  final bool isOneWall;
  final bool separateWallGeneration;
  final int wall0Inset;
  final int insetCount;
  final SourceArachneWallToolPathsGenerated2? generated;
}

/// First orchestration slice of pinned `PerimeterGenerator::process_arachne()`.
///
/// The input polygons correspond to source `last_p`, after surface simplify,
/// outer-wall offset and optional circle-compensation flag construction. This
/// helper freezes the exact one-wall / normal-wall branch and constructor
/// payload that follows. The `Alltop` separate-wall geometry branch deliberately
/// stops before generation because its `should_enable_top_one_wall()` clipping
/// and recombination is a distinct source seam.
class SourceArachneProcessPlanner2 {
  const SourceArachneProcessPlanner2._();

  static SourceArachneProcessPlan2 planAndGenerate({
    required List<SourcePolygon2> lastPolygons,
    required int loopNumber,
    required int layerId,
    required SourceTopOneWallType2 topOneWallType,
    required bool onlyOneWallFirstLayer,
    required bool upperSlicesIsNull,
    required bool applyPreciseOuterWall,
    required int extPerimeterWidth,
    required int extPerimeterSpacing,
    required int perimeterSpacing,
    required double layerHeightMm,
    required SourceArachneWallToolPathsParams2 params,
    bool applyCircleCompensation = false,
    Iterable<int> circlePolygonIndices = const <int>[],
  }) {
    final generateOneWallByFirstLayer = onlyOneWallFirstLayer && layerId == 0;
    final generateOneWallByTopMost =
        topOneWallType != SourceTopOneWallType2.none && upperSlicesIsNull;
    final generateOneWallByTop =
        topOneWallType == SourceTopOneWallType2.allTop && !upperSlicesIsNull;

    final isOneWall = loopNumber == 0 ||
        generateOneWallByFirstLayer ||
        generateOneWallByTopMost;
    final separateWallGeneration = !isOneWall && generateOneWallByTop;

    final wall0Inset = applyPreciseOuterWall
        ? -(extPerimeterWidth ~/ 2 - extPerimeterSpacing ~/ 2)
        : 0;

    if (loopNumber < 0) {
      return SourceArachneProcessPlan2(
        isOneWall: isOneWall,
        separateWallGeneration: separateWallGeneration,
        wall0Inset: wall0Inset,
        insetCount: 0,
      );
    }

    if (separateWallGeneration) {
      return SourceArachneProcessPlan2(
        isOneWall: isOneWall,
        separateWallGeneration: true,
        wall0Inset: wall0Inset,
        insetCount: 1,
      );
    }

    final insetCount = isOneWall ? 1 : loopNumber + 1;
    final state = SourceArachneWallToolPathsState2(
      outline: lastPolygons,
      beadWidth0: extPerimeterSpacing,
      beadWidthX: perimeterSpacing,
      insetCount: insetCount,
      wall0Inset: wall0Inset,
      layerHeightMm: layerHeightMm,
      params: params,
    );
    final generated = SourceArachneWallToolPathsGenerate2.generate(
      state,
      enableHoleCompensation: applyCircleCompensation,
      holeIndices: circlePolygonIndices,
    );

    return SourceArachneProcessPlan2(
      isOneWall: isOneWall,
      separateWallGeneration: false,
      wall0Inset: wall0Inset,
      insetCount: insetCount,
      generated: generated,
    );
  }
}
