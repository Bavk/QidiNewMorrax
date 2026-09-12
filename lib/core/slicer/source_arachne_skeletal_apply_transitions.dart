import 'dart:math' as math;

import '../geometry/source_geometry.dart';
import 'source_arachne_skeletal_graph.dart';
import 'source_arachne_skeletal_graph_mutations.dart';

/// Direct port of pinned `SkeletalTrapezoidation::applyTransitions()`.
extension SourceArachneSkeletalApplyTransitions2
    on SourceArachneSkeletalTrapezoidationGraph2 {
  void applyTransitions(
    List<List<SourceArachneTransitionEnd2>> edgeTransitionEnds, {
    required int snapDistance,
  }) {
    // Mirror transition-end storage from each twin into the current half-edge.
    // This pass does not change graph.edges cardinality, so source list order is
    // preserved directly.
    for (final edge in edges) {
      final twin = edge.twin ??
          (throw StateError('applyTransitions edge has no twin'));
      if (!twin.data.hasTransitionEnds()) {
        continue;
      }

      final from = edge.from ??
          (throw StateError('applyTransitions edge has no from node'));
      final to = edge.to ??
          (throw StateError('applyTransitions edge has no to node'));
      final length = math.sqrt((from.p - to.p).squaredLength).truncate();
      final twinTransitionEnds = twin.data.transitionEnds ??
          (throw StateError('Twin transition-end storage disappeared'));

      var transitionEnds = edge.data.transitionEnds;
      if (!edge.data.hasTransitionEnds()) {
        transitionEnds = <SourceArachneTransitionEnd2>[];
        edgeTransitionEnds.add(transitionEnds);
        edge.data.setTransitionEnds(transitionEnds);
      }
      transitionEnds ??=
          (throw StateError('Transition-end storage disappeared after setup'));

      for (final end in twinTransitionEnds) {
        transitionEnds.add(
          SourceArachneTransitionEnd2(
            pos: length - end.pos,
            lowerBeadCount: end.lowerBeadCount,
            isLowerEnd: end.isLowerEnd,
          ),
        );
      }
      twinTransitionEnds.clear();
    }

    // Source uses std::list: insertNode() may append graph edges without
    // invalidating the current iterator. Dart List iteration would throw on
    // concurrent growth. Newly appended split edges have no transition ends
    // and source would only skip them, so a snapshot of the currently eligible
    // edges is the exact iterator-stability equivalent.
    final transitionEdges = edges
        .where((edge) => edge.data.hasTransitionEnds())
        .toList(growable: false);

    for (final edge in transitionEdges) {
      if (!edge.data.isCentral) {
        throw StateError('applyTransitions requires a central edge');
      }

      final transitions = edge.data.transitionEnds ??
          (throw StateError('Transition-end storage disappeared'));
      _stableSortTransitionEnds(transitions);

      final from = edge.from ??
          (throw StateError('applyTransitions edge has no from node'));
      final to = edge.to ??
          (throw StateError('applyTransitions edge has no to node'));
      final a = from.p;
      final b = to.p;
      final ab = b - a;
      final edgeSize = math.sqrt(ab.squaredLength).truncate();

      var lastEdgeReplacingInput = edge;
      for (final transitionEnd in transitions) {
        final newNodeBeadCount = transitionEnd.isLowerEnd
            ? transitionEnd.lowerBeadCount
            : transitionEnd.lowerBeadCount + 1;
        final endPos = transitionEnd.pos;
        final closeNode = endPos < edgeSize ~/ 2 ? from : to;

        if ((endPos < snapDistance || endPos > edgeSize - snapDistance) &&
            closeNode.data.beadCount == newNodeBeadCount) {
          if (endPos > edgeSize) {
            throw StateError('Snapped transition end lies beyond source edge');
          }
          closeNode.data.transitionRatio = 0;
          continue;
        }

        final mid = a + _sourceNormal(ab, endPos);
        if (!lastEdgeReplacingInput.data.isCentral ||
            lastEdgeReplacingInput.data.type ==
                SourceArachneSkeletalEdgeType2.extraVd) {
          throw StateError('Transition split reached invalid source edge type');
        }
        lastEdgeReplacingInput = insertNode(
          lastEdgeReplacingInput,
          mid,
          newNodeBeadCount,
        );
        if (!lastEdgeReplacingInput.data.isCentral ||
            lastEdgeReplacingInput.data.type ==
                SourceArachneSkeletalEdgeType2.extraVd) {
          throw StateError('Transition split produced invalid source edge type');
        }
      }
    }
  }
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

void _stableSortTransitionEnds(List<SourceArachneTransitionEnd2> transitions) {
  final indexed = <({int index, SourceArachneTransitionEnd2 end})>[
    for (var index = 0; index < transitions.length; index++)
      (index: index, end: transitions[index]),
  ];
  indexed.sort((left, right) {
    final byPosition = left.end.pos.compareTo(right.end.pos);
    return byPosition != 0 ? byPosition : left.index.compareTo(right.index);
  });
  transitions
    ..clear()
    ..addAll(indexed.map((entry) => entry.end));
}
