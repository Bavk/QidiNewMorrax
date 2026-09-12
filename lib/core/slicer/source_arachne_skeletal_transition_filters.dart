import 'dart:math' as math;

import 'source_arachne_skeletal_graph.dart';

/// Direct ports of pinned transition-filter graph mutations used by
/// `SkeletalTrapezoidation::filterTransitionMids()`.
extension SourceArachneSkeletalTransitionFilters2
    on SourceArachneSkeletalTrapezoidationGraph2 {
  void dissolveBeadCountRegion(
    SourceArachneSTHalfEdge2 edgeToStart,
    int fromBeadCount,
    int toBeadCount,
  ) {
    if (fromBeadCount == toBeadCount) {
      throw StateError('dissolveBeadCountRegion counts must differ');
    }

    final startTo = edgeToStart.to ??
        (throw StateError('Dissolve region start edge has no to node'));
    if (startTo.data.beadCount != fromBeadCount) {
      return;
    }

    startTo.data.beadCount = toBeadCount;
    var edge = edgeToStart.next;
    while (edge != null && !identical(edge, edgeToStart.twin)) {
      if (edge.data.isCentral) {
        dissolveBeadCountRegion(edge, fromBeadCount, toBeadCount);
      }
      final twin = edge.twin ??
          (throw StateError('Dissolve region radial edge has no twin'));
      edge = twin.next;
    }
  }

  bool filterEndOfCentralTransition(
    SourceArachneSTHalfEdge2 edgeToStart,
    int traveledDistance,
    int maxDistance,
    int replacingBeadCount,
  ) {
    if (traveledDistance > maxDistance) {
      return false;
    }

    var isEndOfCentral = true;
    var shouldDissolve = false;
    var nextEdge = edgeToStart.next;
    while (nextEdge != null && !identical(nextEdge, edgeToStart.twin)) {
      if (nextEdge.data.isCentral) {
        final from = nextEdge.from ??
            (throw StateError('Central-filter branch has no from node'));
        final to = nextEdge.to ??
            (throw StateError('Central-filter branch has no to node'));
        final length = math.sqrt((to.p - from.p).squaredLength).truncate();

        // Source uses bool `|=`. Evaluate every recursive branch even if one
        // branch has already requested dissolution.
        final branchDissolves = filterEndOfCentralTransition(
          nextEdge,
          traveledDistance + length,
          maxDistance,
          replacingBeadCount,
        );
        shouldDissolve = shouldDissolve || branchDissolves;
        isEndOfCentral = false;
      }
      final twin = nextEdge.twin ??
          (throw StateError('Central-filter radial edge has no twin'));
      nextEdge = twin.next;
    }

    if (isEndOfCentral && traveledDistance < maxDistance) {
      shouldDissolve = true;
    }

    if (shouldDissolve) {
      final to = edgeToStart.to ??
          (throw StateError('Central-filter start edge has no to node'));
      to.data.beadCount = replacingBeadCount;
    }
    return shouldDissolve;
  }
}
