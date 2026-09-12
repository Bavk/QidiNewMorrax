import 'dart:math' as math;

import '../geometry/source_geometry.dart';
import 'source_arachne_beading_strategy.dart';
import 'source_arachne_skeletal_graph.dart';
import 'source_arachne_skeletal_graph_mutations.dart';

/// Direct port of pinned `SkeletalTrapezoidation::generateExtraRibs()`.
extension SourceArachneSkeletalExtraRibs2
    on SourceArachneSkeletalTrapezoidationGraph2 {
  void generateExtraRibs(
    SourceArachneBeadingStrategy2 beadingStrategy, {
    required int discretizationStepSize,
    required int snapDistance,
  }) {
    // Source iterates std::list until its dynamic end while insertNode() appends
    // new edges. A growing index loop preserves that iterator-stable behavior.
    var edgeIndex = 0;
    while (edgeIndex < edges.length) {
      final edge = edges[edgeIndex++];
      final fromNow = edge.from ??
          (throw StateError('generateExtraRibs edge has no from node'));
      final toNow = edge.to ??
          (throw StateError('generateExtraRibs edge has no to node'));

      if (!edge.data.isCentral ||
          _sourceShorterThen(
            toNow.p - fromNow.p,
            discretizationStepSize,
          ) ||
          fromNow.data.distanceToBoundary >=
              toNow.data.distanceToBoundary) {
        continue;
      }

      final ribThicknesses =
          beadingStrategy.getNonlinearThicknesses(fromNow.data.beadCount);
      if (ribThicknesses.isEmpty) {
        continue;
      }

      // Source preloads geometry/radii because [edge] is mutated by insertNode.
      final from = fromNow;
      final to = toNow;
      final a = from.p;
      final b = to.p;
      final ab = b - a;
      final abSize = math.sqrt(ab.squaredLength).truncate();
      final aRadius = from.data.distanceToBoundary;
      final bRadius = to.data.distanceToBoundary;

      var lastEdgeReplacingInput = edge;
      for (final ribThickness in ribThicknesses) {
        final halfThickness = ribThickness ~/ 2;
        if (halfThickness <= aRadius) {
          continue;
        }
        if (halfThickness >= bRadius) {
          break;
        }

        // Deliberately read the possibly mutated original edge, matching source
        // rather than the preloaded endpoint variables above.
        final currentFrom = edge.from ??
            (throw StateError('generateExtraRibs mutated edge has no from node'));
        final currentTo = edge.to ??
            (throw StateError('generateExtraRibs mutated edge has no to node'));
        final newNodeBeadCount = math.min(
          currentFrom.data.beadCount,
          currentTo.data.beadCount,
        );
        final endPos =
            abSize * (halfThickness - aRadius) ~/ (bRadius - aRadius);
        assert(endPos > 0);
        assert(endPos < abSize);

        final closeNode = endPos < abSize ~/ 2 ? from : to;
        if ((endPos < snapDistance || endPos > abSize - snapDistance) &&
            closeNode.data.beadCount == newNodeBeadCount) {
          assert(endPos <= abSize);
          closeNode.data.transitionRatio = 0;
          continue;
        }

        final mid = a + _sourceNormal(ab, endPos);
        assert(lastEdgeReplacingInput.data.isCentral);
        assert(lastEdgeReplacingInput.data.type !=
            SourceArachneSkeletalEdgeType2.extraVd);
        lastEdgeReplacingInput = insertNode(
          lastEdgeReplacingInput,
          mid,
          newNodeBeadCount,
        );
        assert(lastEdgeReplacingInput.data.type !=
            SourceArachneSkeletalEdgeType2.extraVd);
        assert(lastEdgeReplacingInput.data.isCentral);
      }
    }
  }
}

bool _sourceShorterThen(SourcePoint2 vector, int length) {
  if (vector.x > length ||
      vector.x < -length ||
      vector.y > length ||
      vector.y < -length) {
    return false;
  }
  return vector.squaredLength <= length * length;
}

SourcePoint2 _sourceNormal(SourcePoint2 vector, int length) {
  final sourceLength = math.sqrt(vector.squaredLength).truncate();
  if (sourceLength < 1) {
    return SourcePoint2(length, 0);
  }
  return SourcePoint2(
    vector.x * length ~/ sourceLength,
    vector.y * length ~/ sourceLength,
  );
}
