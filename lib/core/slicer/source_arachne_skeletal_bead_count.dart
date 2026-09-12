import 'dart:math' as math;

import 'source_arachne_beading_strategy.dart';
import 'source_arachne_skeletal_graph.dart';

const int _sourceCoordMax = 0x7fffffff;

/// Direct port of pinned `SkeletalTrapezoidation::updateBeadCount()`.
extension SourceArachneSkeletalBeadCount2
    on SourceArachneSkeletalTrapezoidationGraph2 {
  void updateBeadCount(SourceArachneBeadingStrategy2 beadingStrategy) {
    for (final edge in edges) {
      if (edge.data.isCentral) {
        final to = edge.to ??
            (throw StateError('Central bead-count edge has no to node'));
        to.data.beadCount = beadingStrategy.getOptimalBeadCount(
          to.data.distanceToBoundary * 2,
        );
      }
    }

    // Source fixes bead count at local maxima a second time, including inside
    // central regions. This pass intentionally overwrites any value assigned by
    // the central-edge loop above.
    for (final node in nodes) {
      if (!node.isLocalMaximum()) {
        continue;
      }

      if (node.data.distanceToBoundary < 0) {
        node.data.distanceToBoundary = _sourceCoordMax;
        var edge = node.incidentEdge ??
            (throw StateError('Local maximum has no incident edge'));
        do {
          final from = edge.from ??
              (throw StateError('Local-maximum edge has no from node'));
          final to = edge.to ??
              (throw StateError('Local-maximum edge has no to node'));
          final candidate = to.data.distanceToBoundary +
              math.sqrt((from.p - to.p).squaredLength).truncate();
          node.data.distanceToBoundary = math.min(
            node.data.distanceToBoundary,
            candidate,
          );

          final twin = edge.twin ??
              (throw StateError('Local-maximum edge has no twin'));
          edge = twin.next ??
              (throw StateError('Local-maximum radial fan is open'));
        } while (!identical(edge, node.incidentEdge));
      }

      node.data.beadCount = beadingStrategy.getOptimalBeadCount(
        node.data.distanceToBoundary * 2,
      );
    }
  }
}
