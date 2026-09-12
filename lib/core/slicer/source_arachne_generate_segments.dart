import 'source_arachne_beading_strategy.dart';
import 'source_arachne_extrusion_line.dart';
import 'source_arachne_generate_segments_connect.dart';
import 'source_arachne_generate_segments_foundation.dart';
import 'source_arachne_generate_segments_junctions.dart';
import 'source_arachne_generate_segments_local_maxima.dart';
import 'source_arachne_generate_segments_propagation.dart';
import 'source_arachne_skeletal_graph.dart';
import 'source_arachne_wall_tool_paths.dart';

/// Direct source-order composition of pinned
/// `SkeletalTrapezoidation::generateSegments()`.
///
/// Source writes through `p_generated_toolpaths`; the Dart compatibility seam
/// returns the freshly owned nested list instead. Every mutation of the graph
/// and every ordering decision remains in the same source stage order.
extension SourceArachneGenerateSegments2
    on SourceArachneSkeletalTrapezoidationGraph2 {
  List<List<SourceArachneExtrusionLine2>> generateSegments(
    SourceArachneBeadingStrategy2 beadingStrategy, {
    required int beadingPropagationTransitionDistance,
    int? centralFilterDistance,
  }) {
    final upwardQuadMids = collectUpwardQuadMids();
    final nodeBeadings = storeNodeBeadings(beadingStrategy);

    propagateBeadingsUpward(
      upwardQuadMids,
      nodeBeadings,
      centralFilterDistance: centralFilterDistance ??
          SourceArachneWallToolPathsPreprocess2.scaleDouble(0.02),
    );
    propagateBeadingsDownward(
      upwardQuadMids,
      nodeBeadings,
      beadingStrategy,
      beadingPropagationTransitionDistance:
          beadingPropagationTransitionDistance,
    );

    final edgeJunctions = generateJunctions(nodeBeadings, beadingStrategy);
    final generatedToolpaths = <List<SourceArachneExtrusionLine2>>[];
    connectJunctions(edgeJunctions, generatedToolpaths);
    generateLocalMaximaSingleBeads(generatedToolpaths);
    return generatedToolpaths;
  }
}
