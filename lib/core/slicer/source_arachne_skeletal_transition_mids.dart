import 'dart:math' as math;

import 'source_arachne_beading_strategy.dart';
import 'source_arachne_skeletal_graph.dart';

/// Direct port of pinned `SkeletalTrapezoidation::generateTransitionMids()`.
extension SourceArachneSkeletalTransitionMids2
    on SourceArachneSkeletalTrapezoidationGraph2 {
  /// Generates transition-middle storage on upward central half-edges.
  ///
  /// The returned outer list mirrors the source `edge_transitions` ownership
  /// vector: each newly-created per-edge transition list is retained there and
  /// the same list object is attached to the edge data.
  List<List<SourceArachneTransitionMiddle2>> generateTransitionMids(
    SourceArachneBeadingStrategy2 beadingStrategy,
  ) {
    final edgeTransitions = <List<SourceArachneTransitionMiddle2>>[];

    for (final edge in edges) {
      if (!edge.data.centralIsSet) {
        throw StateError('generateTransitionMids central state is UNKNOWN');
      }
      if (!edge.data.isCentral) {
        continue;
      }

      final from = edge.from ??
          (throw StateError('Transition edge has no from node'));
      final to = edge.to ??
          (throw StateError('Transition edge has no to node'));
      final startRadius = from.data.distanceToBoundary;
      final endRadius = to.data.distanceToBoundary;
      final startBeadCount = from.data.beadCount;
      final endBeadCount = to.data.beadCount;

      if (startRadius == endRadius) {
        if (startBeadCount != endBeadCount) {
          // Pinned debug source asserts here before logging/continuing.
          throw StateError(
            'Equal-radius transition edge has different bead counts',
          );
        }
        continue;
      } else if (startRadius > endRadius) {
        // The twin/upward half is responsible for storage.
        continue;
      }

      if (startBeadCount == endBeadCount) {
        continue;
      }

      if (startBeadCount >
              beadingStrategy.getOptimalBeadCount(startRadius * 2) ||
          endBeadCount >
              beadingStrategy.getOptimalBeadCount(endRadius * 2)) {
        // Pinned source only logs "transitioning segment overlap! (?)" and
        // continues. Keep the C++ short-circuit call order and do not alter the
        // enforced bead counts.
      }

      final edgeSize = math.sqrt((from.p - to.p).squaredLength).truncate();
      for (var lowerBeadCount = startBeadCount;
          lowerBeadCount < endBeadCount;
          lowerBeadCount++) {
        var midRadius =
            beadingStrategy.getTransitionThickness(lowerBeadCount) ~/ 2;
        if (midRadius > endRadius) {
          midRadius = endRadius;
        }
        if (midRadius < startRadius) {
          midRadius = startRadius;
        }

        final midPos = edgeSize * (midRadius - startRadius) ~/
            (endRadius - startRadius);
        if (midPos < 0 || midPos > edgeSize) {
          throw StateError('Transition middle lies outside source edge');
        }

        var transitions = edge.data.transitions;
        const ignoreEmpty = true;
        if (edge.data.hasTransitions(ignoreEmpty: ignoreEmpty) &&
            transitions != null &&
            transitions.isNotEmpty &&
            midPos < transitions.last.pos) {
          throw StateError('Transition middle ordering assertion failed');
        }

        if (!edge.data.hasTransitions(ignoreEmpty: ignoreEmpty)) {
          transitions = <SourceArachneTransitionMiddle2>[];
          edgeTransitions.add(transitions);
          edge.data.setTransitions(transitions);
        }
        transitions ??=
            (throw StateError('Transition storage disappeared after setup'));
        transitions.add(
          SourceArachneTransitionMiddle2(
            pos: midPos,
            lowerBeadCount: lowerBeadCount,
            featureRadius: midRadius,
          ),
        );
      }

      if (startBeadCount != endBeadCount && !edge.data.hasTransitions()) {
        throw StateError('Changed bead count produced no transition middles');
      }
    }

    return edgeTransitions;
  }
}
