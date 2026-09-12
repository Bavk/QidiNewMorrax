import 'dart:math' as math;
import 'dart:typed_data';

import 'source_arachne_beading_strategy.dart';
import 'source_arachne_skeletal_graph.dart';

/// Direct port of pinned transition-end generation in
/// `SkeletalTrapezoidation`.
extension SourceArachneSkeletalTransitionEnds2
    on SourceArachneSkeletalTrapezoidationGraph2 {
  List<List<SourceArachneTransitionEnd2>> generateAllTransitionEnds(
    SourceArachneBeadingStrategy2 beadingStrategy,
  ) {
    final edgeTransitionEnds = <List<SourceArachneTransitionEnd2>>[];
    for (final edge in edges) {
      if (!edge.data.hasTransitions()) {
        continue;
      }
      final transitions = edge.data.transitions ??
          (throw StateError('Transition-middle storage disappeared'));
      final from = edge.from ??
          (throw StateError('Transition-middle edge has no from node'));
      final to = edge.to ??
          (throw StateError('Transition-middle edge has no to node'));
      if (from.data.distanceToBoundary > to.data.distanceToBoundary) {
        throw StateError('Transition middles are stored on downward edge');
      }

      for (final transition in transitions) {
        if (transition.pos < transitions.first.pos ||
            transition.pos > transitions.last.pos) {
          throw StateError('Transition middle lies outside source ordering');
        }
        generateTransitionEnds(
          edge,
          transition.pos,
          transition.lowerBeadCount,
          edgeTransitionEnds,
          beadingStrategy,
        );
      }
    }
    return edgeTransitionEnds;
  }

  void generateTransitionEnds(
    SourceArachneSTHalfEdge2 edge,
    int midPos,
    int lowerBeadCount,
    List<List<SourceArachneTransitionEnd2>> edgeTransitionEnds,
    SourceArachneBeadingStrategy2 beadingStrategy,
  ) {
    final from = edge.from ??
        (throw StateError('Transition-end edge has no from node'));
    final to = edge.to ??
        (throw StateError('Transition-end edge has no to node'));
    final edgeSize = math.sqrt((to.p - from.p).squaredLength).truncate();

    final transitionLength =
        beadingStrategy.getTransitioningLength(lowerBeadCount);
    final transitionMidPosition =
        beadingStrategy.getTransitionAnchorPos(lowerBeadCount);
    const innerBeadWidthRatioAfterTransition = 1.0;
    const startRest = 0.0;
    final midRest = _mulF32(
      transitionMidPosition,
      innerBeadWidthRatioAfterTransition,
    );
    const endRest = innerBeadWidthRatioAfterTransition;

    final twin = edge.twin ??
        (throw StateError('Transition-end edge has no twin'));

    // Lower bead-count transition end. Source expression is float * int64_t,
    // therefore multiplication rounds in float32 before coord_t truncation.
    final lowerStartPos = edgeSize - midPos;
    final lowerHalfLength = _mulF32(
      transitionMidPosition,
      transitionLength.toDouble(),
    ).truncate();
    generateTransitionEnd(
      twin,
      lowerStartPos,
      lowerStartPos + lowerHalfLength,
      lowerHalfLength,
      midRest,
      startRest,
      lowerBeadCount,
      edgeTransitionEnds,
      beadingStrategy,
    );

    // Upper bead-count transition end. Literal `1.0` promotes the expression
    // to double before coord_t truncation.
    final upperStartPos = midPos;
    final upperHalfLength =
        ((1.0 - transitionMidPosition) * transitionLength).truncate();
    generateTransitionEnd(
      edge,
      upperStartPos,
      upperStartPos + upperHalfLength,
      upperHalfLength,
      midRest,
      endRest,
      lowerBeadCount,
      edgeTransitionEnds,
      beadingStrategy,
    );
  }

  bool generateTransitionEnd(
    SourceArachneSTHalfEdge2 edge,
    int startPos,
    int endPos,
    int transitionHalfLength,
    double startRest,
    double endRest,
    int lowerBeadCount,
    List<List<SourceArachneTransitionEnd2>> edgeTransitionEnds,
    SourceArachneBeadingStrategy2 beadingStrategy,
  ) {
    final from = edge.from ??
        (throw StateError('Transition-end edge has no from node'));
    final to = edge.to ??
        (throw StateError('Transition-end edge has no to node'));
    final edgeSize = math.sqrt((to.p - from.p).squaredLength).truncate();

    if (startPos > edgeSize) {
      // Pinned debug build asserts here before its release warning path.
      throw StateError('Transition start position is beyond edge range');
    }

    final goingUp = endRest > startRest;
    if (!edge.data.isCentral) {
      // Pinned release path warns and returns false after its debug assert.
      return false;
    }

    if (endPos > edgeSize) {
      final rest = _f32(
        endRest -
            (startRest - endRest) *
                (endPos - edgeSize) /
                (startPos - endPos),
      );
      final maxRest = math.max(endRest, startRest);
      final minRest = math.min(endRest, startRest);
      if (rest < 0 || rest > maxRest || rest < minRest) {
        throw StateError('Transition rest interpolation left source range');
      }

      var centralEdgeCount = 0;
      var outgoing = edge.next;
      while (outgoing != null && !identical(outgoing, edge.twin)) {
        if (outgoing.data.isCentral) {
          centralEdgeCount++;
        }
        final twin = outgoing.twin ??
            (throw StateError('Transition-end radial edge has no twin'));
        outgoing = twin.next;
      }

      var isOnlyGoingDown = true;
      var hasRecursed = false;
      outgoing = edge.next;
      while (outgoing != null && !identical(outgoing, edge.twin)) {
        final outgoingTwin = outgoing.twin ??
            (throw StateError('Transition-end radial edge has no twin'));
        final next = outgoingTwin.next;
        if (!outgoing.data.isCentral) {
          outgoing = next;
          continue;
        }
        if (centralEdgeCount > 1 &&
            goingUp &&
            isGoingDown(
              outgoing,
              0,
              endPos - edgeSize + transitionHalfLength,
              lowerBeadCount,
            )) {
          outgoing = next;
          continue;
        }

        final isGoingDownResult = generateTransitionEnd(
          outgoing,
          0,
          endPos - edgeSize,
          transitionHalfLength,
          rest,
          endRest,
          lowerBeadCount,
          edgeTransitionEnds,
          beadingStrategy,
        );
        // Source uses bool `&=` and therefore evaluates every branch.
        isOnlyGoingDown = isOnlyGoingDown && isGoingDownResult;
        outgoing = next;
        hasRecursed = true;
      }

      if (!goingUp || (hasRecursed && !isOnlyGoingDown)) {
        to.data.transitionRatio = rest;
        to.data.beadCount = lowerBeadCount;
      }
      return isOnlyGoingDown;
    }

    final isLowerEnd = endRest == 0;
    late final SourceArachneSTHalfEdge2 upwardEdge;
    late final int pos;
    if (edge.isUpward()) {
      upwardEdge = edge;
      pos = endPos;
    } else {
      upwardEdge = edge.twin ??
          (throw StateError('Downward transition edge has no twin'));
      pos = edgeSize - endPos;
    }

    var transitions = upwardEdge.data.transitionEnds;
    if (!upwardEdge.data.hasTransitionEnds()) {
      transitions = <SourceArachneTransitionEnd2>[];
      edgeTransitionEnds.add(transitions);
      upwardEdge.data.setTransitionEnds(transitions);
    }
    transitions ??=
        (throw StateError('Transition-end storage disappeared after setup'));

    final sourceTwin = edge.twin ??
        (throw StateError('Transition-end edge has no twin'));
    final twinFrom = sourceTwin.from ??
        (throw StateError('Transition-end twin has no from node'));
    final twinTo = sourceTwin.to ??
        (throw StateError('Transition-end twin has no to node'));
    final twinSize =
        math.sqrt((twinFrom.p - twinTo.p).squaredLength).truncate();
    if (edgeSize != twinSize || pos > edgeSize) {
      throw StateError('Transition-end twin geometry assertion failed');
    }

    final transition = SourceArachneTransitionEnd2(
      pos: pos,
      lowerBeadCount: lowerBeadCount,
      isLowerEnd: isLowerEnd,
    );
    if (transitions.isEmpty || pos < transitions.first.pos) {
      transitions.insert(0, transition);
    } else {
      transitions.add(transition);
    }
    return false;
  }

  bool isGoingDown(
    SourceArachneSTHalfEdge2 outgoing,
    int traveledDistance,
    int maxDistance,
    int lowerBeadCount,
  ) {
    final from = outgoing.from ??
        (throw StateError('isGoingDown edge has no from node'));
    final to = outgoing.to ??
        (throw StateError('isGoingDown edge has no to node'));
    if (to.data.distanceToBoundary == 0) {
      return true;
    }

    final isUpward =
        to.data.distanceToBoundary >= from.data.distanceToBoundary;
    final upwardEdge = isUpward
        ? outgoing
        : outgoing.twin ??
            (throw StateError('isGoingDown edge has no twin'));

    if (to.data.beadCount > lowerBeadCount + 1) {
      if (!upwardEdge.data.hasTransitions()) {
        // Source asserts this invariant in debug, then warns/returns false.
        throw StateError('Descending bead-count jump has no transition middle');
      }
      return false;
    }

    final length = math.sqrt((to.p - from.p).squaredLength).truncate();
    if (upwardEdge.data.hasTransitions()) {
      final transitionMids = upwardEdge.data.transitions ??
          (throw StateError('Transition-middle storage disappeared'));
      final mid = isUpward ? transitionMids.first : transitionMids.last;
      final directionalDistance = isUpward ? mid.pos : length - mid.pos;
      if (mid.lowerBeadCount == lowerBeadCount &&
          directionalDistance + traveledDistance < maxDistance) {
        return true;
      }
    }

    if (traveledDistance + length > maxDistance) {
      return false;
    }
    if (to.data.beadCount <= lowerBeadCount &&
        !(to.data.beadCount == lowerBeadCount &&
            to.data.transitionRatio > 0.0)) {
      return true;
    }

    var isOnlyGoingDown = true;
    var hasRecursed = false;
    var next = outgoing.next;
    while (next != null && !identical(next, outgoing.twin)) {
      if (next.data.isCentral) {
        final result = isGoingDown(
          next,
          traveledDistance + length,
          maxDistance,
          lowerBeadCount,
        );
        isOnlyGoingDown = isOnlyGoingDown && result;
        hasRecursed = true;
      }
      final twin = next.twin ??
          (throw StateError('isGoingDown radial edge has no twin'));
      next = twin.next;
    }
    return hasRecursed && isOnlyGoingDown;
  }
}

double _f32(double value) {
  final slot = Float32List(1)..[0] = value;
  return slot[0];
}

double _mulF32(double left, double right) {
  final slot = Float32List(1)..[0] = left;
  final left32 = slot[0];
  slot[0] = right;
  final right32 = slot[0];
  slot[0] = left32 * right32;
  return slot[0];
}
