import 'source_arachne_beading_strategy.dart';
import 'source_arachne_extrusion_line.dart';
import 'source_arachne_generate_segments.dart';
import 'source_arachne_generate_transitioning_ribs.dart';
import 'source_arachne_skeletal_bead_count.dart';
import 'source_arachne_skeletal_central.dart';
import 'source_arachne_skeletal_extra_ribs.dart';
import 'source_arachne_skeletal_graph.dart';
import 'source_arachne_skeletal_noncentral.dart';
import 'source_arachne_wall_tool_paths.dart';

/// Direct source-order composition of pinned
/// `SkeletalTrapezoidation::generateToolpaths()` after graph construction.
///
/// The C++ object stores the scalar constructor arguments as members and writes
/// through an output reference. This Dart compatibility seam receives those
/// same scalar values explicitly and returns the generated toolpath list.
extension SourceArachneGenerateToolpaths2
    on SourceArachneSkeletalTrapezoidationGraph2 {
  List<List<SourceArachneExtrusionLine2>> generateToolpaths(
    SourceArachneBeadingStrategy2 beadingStrategy, {
    required int discretizationStepSize,
    required int transitionFilterDistance,
    required int allowedFilterDeviation,
    required int beadingPropagationTransitionDistance,
    bool filterOutermostCentralEdges = false,
  }) {
    final centralFilterDistance =
        SourceArachneWallToolPathsPreprocess2.scaleDouble(0.02);
    final snapDistance =
        SourceArachneWallToolPathsPreprocess2.scaleDouble(0.02);

    updateIsCentral(beadingStrategy);
    filterCentral(centralFilterDistance);
    if (filterOutermostCentralEdges) {
      filterOuterCentral();
    }

    updateBeadCount(beadingStrategy);
    filterNoncentralRegions(beadingStrategy);
    generateTransitioningRibs(
      beadingStrategy,
      transitionFilterDistance: transitionFilterDistance,
      allowedFilterDeviation: allowedFilterDeviation,
      snapDistance: snapDistance,
    );
    generateExtraRibs(
      beadingStrategy,
      discretizationStepSize: discretizationStepSize,
      snapDistance: snapDistance,
    );
    return generateSegments(
      beadingStrategy,
      beadingPropagationTransitionDistance:
          beadingPropagationTransitionDistance,
      centralFilterDistance: centralFilterDistance,
    );
  }
}
