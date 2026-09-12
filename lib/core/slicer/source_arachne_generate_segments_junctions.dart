import 'dart:math' as math;

import '../geometry/source_geometry.dart';
import 'source_arachne_beading_strategy.dart';
import 'source_arachne_extrusion_line.dart';
import 'source_arachne_generate_segments_propagation.dart';
import 'source_arachne_skeletal_graph.dart';
import 'source_arachne_wall_tool_paths.dart';

/// Third source-order slice of pinned
/// `SkeletalTrapezoidation::generateSegments()`: convert propagated beadings
/// into per-half-edge extrusion junctions, ordered from high R toward low R.
extension SourceArachneGenerateSegmentsJunctions2
    on SourceArachneSkeletalTrapezoidationGraph2 {
  List<List<SourceArachneExtrusionJunction2>> generateJunctions(
    List<SourceArachneBeadingPropagation2> nodeBeadings,
    SourceArachneBeadingStrategy2 beadingStrategy,
  ) {
    final edgeJunctions = <List<SourceArachneExtrusionJunction2>>[];
    final snapEpsilon =
        SourceArachneWallToolPathsPreprocess2.scaleDouble(0.005);

    for (final edge in edges) {
      final from = edge.from ??
          (throw StateError('generateJunctions edge has no from node'));
      final to = edge.to ??
          (throw StateError('generateJunctions edge has no to node'));
      if (from.data.distanceToBoundary > to.data.distanceToBoundary) {
        continue;
      }

      final startRadius = to.data.distanceToBoundary;
      final endRadius = from.data.distanceToBoundary;
      if ((from.data.beadCount == to.data.beadCount &&
              from.data.beadCount >= 0) ||
          endRadius >= startRadius) {
        continue;
      }

      final applyHoleCompensation = edge.data.holeCompensationFlag;
      final beading = getOrCreateBeading(
        to,
        nodeBeadings,
        beadingStrategy,
      ).beading;
      final output = <SourceArachneExtrusionJunction2>[];
      edgeJunctions.add(output);
      edge.data.setExtrusionJunctions(output);

      assert(beading.totalThickness >= to.data.distanceToBoundary * 2);

      final a = to.p;
      final b = from.p;
      final ab = b - a;
      final count = beading.toolpathLocations.length;

      // Source uses size_t and intentionally relies on unsigned underflow to
      // terminate the reverse scan. A signed -1 has the same observable state
      // for the later `junction_idx + 1` robustness check.
      var junctionIndex = (math.max(1, count) - 1) ~/ 2;
      while (junctionIndex >= 0 && junctionIndex < count) {
        final beadRadius = beading.toolpathLocations[junctionIndex];
        if (beadRadius <= startRadius + 1) {
          break;
        }
        junctionIndex--;
      }

      if (junctionIndex + 1 < count &&
          beading.toolpathLocations[junctionIndex + 1] <=
              startRadius + snapEpsilon &&
          beading.totalThickness < startRadius + snapEpsilon) {
        junctionIndex++;
      }

      while (junctionIndex >= 0 && junctionIndex < count) {
        final beadRadius = beading.toolpathLocations[junctionIndex];
        assert(beadRadius >= 0);
        if (beadRadius < endRadius) {
          break;
        }

        final radiusDelta = beadRadius - startRadius;
        final radiusSpan = endRadius - startRadius;
        var junction = SourcePoint2(
          a.x + ab.x * radiusDelta ~/ radiusSpan,
          a.y + ab.y * radiusDelta ~/ radiusSpan,
        );
        if (beadRadius > startRadius - snapEpsilon) {
          junction = a;
        }
        output.add(
          SourceArachneExtrusionJunction2(
            p: junction,
            w: beading.beadWidths[junctionIndex],
            perimeterIndex: junctionIndex,
            holeCompensationFlag: applyHoleCompensation,
          ),
        );
        junctionIndex--;
      }
    }

    return edgeJunctions;
  }
}
