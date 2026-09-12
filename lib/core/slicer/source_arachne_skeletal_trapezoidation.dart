import '../geometry/source_polygon.dart';
import 'source_arachne_beading_strategy.dart';
import 'source_arachne_construct_from_polygons.dart';
import 'source_arachne_extrusion_line.dart';
import 'source_arachne_generate_toolpaths.dart';

class SourceArachneSkeletalTrapezoidationResult2 {
  const SourceArachneSkeletalTrapezoidationResult2({
    required this.constructed,
    required this.toolpaths,
  });

  final SourceArachneConstructedGraph2 constructed;
  final List<List<SourceArachneExtrusionLine2>> toolpaths;
}

/// Source-order composition of the pinned `SkeletalTrapezoidation`
/// constructor (`constructFromPolygons`) and its later `generateToolpaths()`
/// call. The algorithmic stages remain implemented by the independently
/// validated graph extensions; this wrapper freezes their real call boundary.
class SourceArachneSkeletalTrapezoidation2 {
  const SourceArachneSkeletalTrapezoidation2._();

  static SourceArachneSkeletalTrapezoidationResult2 generate(
    List<SourcePolygon2> polygons,
    SourceArachneBeadingStrategy2 beadingStrategy, {
    required double transitioningAngle,
    required int discretizationStepSize,
    required int transitionFilterDistance,
    required int allowedFilterDeviation,
    required int beadingPropagationTransitionDistance,
    required bool enableHoleCompensation,
    Iterable<int> holeIndices = const <int>[],
    bool filterOutermostCentralEdges = false,
  }) {
    final constructed = SourceArachneConstructFromPolygons2.construct(
      polygons,
      transitioningAngle: transitioningAngle,
      discretizationStepSize: discretizationStepSize,
      enableHoleCompensation: enableHoleCompensation,
      holeIndices: holeIndices,
    );
    final toolpaths = constructed.graph.generateToolpaths(
      beadingStrategy,
      discretizationStepSize: discretizationStepSize,
      transitionFilterDistance: transitionFilterDistance,
      allowedFilterDeviation: allowedFilterDeviation,
      beadingPropagationTransitionDistance:
          beadingPropagationTransitionDistance,
      filterOutermostCentralEdges: filterOutermostCentralEdges,
    );
    return SourceArachneSkeletalTrapezoidationResult2(
      constructed: constructed,
      toolpaths: toolpaths,
    );
  }
}
