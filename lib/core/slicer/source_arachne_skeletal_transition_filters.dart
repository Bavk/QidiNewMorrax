import 'dart:math' as math;
import 'dart:typed_data';

import 'source_arachne_beading_strategy.dart';
import 'source_arachne_skeletal_graph.dart';

/// Identity-safe representation of pinned `TransitionMidRef`.
///
/// C++ stores a `std::list` iterator, which stays valid while other list items
/// are erased. Dart `List` indexes do not have that stability, so keep the
/// transition object identity and resolve it only at erase time.
class SourceArachneTransitionMidRef2 {
  const SourceArachneTransitionMidRef2({
    required this.edge,
    required this.transition,
  });

  final SourceArachneSTHalfEdge2 edge;
  final SourceArachneTransitionMiddle2 transition;
}

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

  List<SourceArachneTransitionMidRef2> dissolveNearbyTransitions(
    SourceArachneSTHalfEdge2 edgeToStart,
    SourceArachneTransitionMiddle2 originTransition,
    int traveledDistance,
    int maxDistance,
    bool goingUp,
    int allowedFilterDeviation,
    SourceArachneBeadingStrategy2 beadingStrategy,
  ) {
    final toBeDissolved = <SourceArachneTransitionMidRef2>[];
    if (traveledDistance > maxDistance) {
      return toBeDissolved;
    }

    var shouldDissolve = true;
    var edge = edgeToStart.next;
    while (edge != null && !identical(edge, edgeToStart.twin)) {
      if (edge.data.isCentral) {
        final from = edge.from ??
            (throw StateError('Nearby-transition edge has no from node'));
        final to = edge.to ??
            (throw StateError('Nearby-transition edge has no to node'));
        final edgeSize = math.sqrt((to.p - from.p).squaredLength).truncate();
        final isAligned = edge.isUpward();
        final alignedEdge = isAligned
            ? edge
            : edge.twin ??
                (throw StateError('Nearby-transition edge has no twin'));
        var seenTransitionOnThisEdge = false;

        final originRadius = originTransition.featureRadius;
        final radiusHere = from.data.distanceToBoundary;
        final dissolveResultIsOdd =
            originTransition.lowerBeadCount.isOdd == goingUp;
        final widthDeviation = (originRadius - radiusHere).abs() * 2;
        final lineWidthDeviation =
            dissolveResultIsOdd ? widthDeviation : widthDeviation ~/ 2;
        if (lineWidthDeviation > allowedFilterDeviation) {
          shouldDissolve = false;
        }

        if (shouldDissolve && alignedEdge.data.hasTransitions()) {
          final transitions = alignedEdge.data.transitions ??
              (throw StateError('Transition storage disappeared'));
          for (final transition in transitions) {
            final pos = isAligned ? transition.pos : edgeSize - transition.pos;
            if (traveledDistance + pos < maxDistance &&
                transition.lowerBeadCount ==
                    originTransition.lowerBeadCount) {
              if (traveledDistance + pos <
                      beadingStrategy.getTransitioningLength(
                        transition.lowerBeadCount,
                      ) &&
                  goingUp == isAligned &&
                  transition.lowerBeadCount != 0) {
                throw StateError(
                  'Nearby same-direction transitions violate source spacing',
                );
              }
              toBeDissolved.add(
                SourceArachneTransitionMidRef2(
                  edge: alignedEdge,
                  transition: transition,
                ),
              );
              seenTransitionOnThisEdge = true;
            }
          }
        }

        if (shouldDissolve && !seenTransitionOnThisEdge) {
          final nested = dissolveNearbyTransitions(
            edge,
            originTransition,
            traveledDistance + edgeSize,
            maxDistance,
            goingUp,
            allowedFilterDeviation,
            beadingStrategy,
          );
          if (nested.isEmpty) {
            toBeDissolved.clear();
            return toBeDissolved;
          }
          toBeDissolved.addAll(nested);
          shouldDissolve = shouldDissolve && toBeDissolved.isNotEmpty;
        }
      }

      final twin = edge.twin ??
          (throw StateError('Nearby-transition radial edge has no twin'));
      edge = twin.next;
    }

    if (!shouldDissolve) {
      toBeDissolved.clear();
    }
    return toBeDissolved;
  }

  void filterTransitionMids(
    SourceArachneBeadingStrategy2 beadingStrategy, {
    required int transitionFilterDistance,
    required int allowedFilterDeviation,
  }) {
    for (final edge in edges) {
      if (!edge.data.hasTransitions()) {
        continue;
      }
      final transitions = edge.data.transitions ??
          (throw StateError('Transition storage disappeared'));
      if (transitions.first.lowerBeadCount >
          transitions.last.lowerBeadCount) {
        throw StateError('Transition middles are not source ordered');
      }
      final from = edge.from ??
          (throw StateError('Transition-filter edge has no from node'));
      final to = edge.to ??
          (throw StateError('Transition-filter edge has no to node'));
      if (from.data.distanceToBoundary > to.data.distanceToBoundary) {
        throw StateError('Transition middles are attached to downward edge');
      }

      final edgeSize = math.sqrt((to.p - from.p).squaredLength).truncate();

      var origin = transitions.last;
      final dissolveBack = dissolveNearbyTransitions(
        edge,
        origin,
        edgeSize - origin.pos,
        transitionFilterDistance,
        true,
        allowedFilterDeviation,
        beadingStrategy,
      );
      var shouldDissolveBack = dissolveBack.isNotEmpty;
      for (final ref in dissolveBack) {
        if (transitions.isEmpty) {
          throw StateError('Origin transition unexpectedly disappeared');
        }
        final currentBack = transitions.last;
        dissolveBeadCountRegion(
          edge,
          currentBack.lowerBeadCount + 1,
          currentBack.lowerBeadCount,
        );
        _eraseTransitionRef(ref);
      }

      if (transitions.isEmpty) {
        throw StateError('Nearby filtering erased the origin transition');
      }
      origin = transitions.last;
      final upperHalfLength = ((1.0 -
                  beadingStrategy.getTransitionAnchorPos(
                    origin.lowerBeadCount,
                  )) *
              beadingStrategy.getTransitioningLength(origin.lowerBeadCount))
          .truncate();
      // Source uses bool `|=`. Always evaluate the endpoint filter.
      final dissolveBackAtEnd = filterEndOfCentralTransition(
        edge,
        edgeSize - origin.pos,
        upperHalfLength,
        origin.lowerBeadCount,
      );
      shouldDissolveBack = shouldDissolveBack || dissolveBackAtEnd;
      if (shouldDissolveBack) {
        transitions.removeLast();
      }
      if (transitions.isEmpty) {
        continue;
      }

      origin = transitions.first;
      final twin = edge.twin ??
          (throw StateError('Transition-filter edge has no twin'));
      final dissolveFront = dissolveNearbyTransitions(
        twin,
        origin,
        origin.pos,
        transitionFilterDistance,
        false,
        allowedFilterDeviation,
        beadingStrategy,
      );
      var shouldDissolveFront = dissolveFront.isNotEmpty;
      for (final ref in dissolveFront) {
        if (transitions.isEmpty) {
          throw StateError('Origin transition unexpectedly disappeared');
        }
        final currentFront = transitions.first;
        dissolveBeadCountRegion(
          twin,
          currentFront.lowerBeadCount,
          currentFront.lowerBeadCount + 1,
        );
        _eraseTransitionRef(ref);
      }

      if (transitions.isEmpty) {
        throw StateError('Nearby filtering erased the origin transition');
      }
      origin = transitions.first;
      // Source expression is `float * coord_t`, so the integer is converted to
      // float and multiplication rounds at float32 before coord_t truncation.
      final lowerHalfLength = _mulF32(
        beadingStrategy.getTransitionAnchorPos(origin.lowerBeadCount),
        beadingStrategy.getTransitioningLength(origin.lowerBeadCount).toDouble(),
      ).truncate();
      final dissolveFrontAtEnd = filterEndOfCentralTransition(
        twin,
        origin.pos,
        lowerHalfLength,
        origin.lowerBeadCount + 1,
      );
      shouldDissolveFront = shouldDissolveFront || dissolveFrontAtEnd;
      if (shouldDissolveFront) {
        transitions.removeAt(0);
      }
    }
  }
}

void _eraseTransitionRef(SourceArachneTransitionMidRef2 ref) {
  final transitions = ref.edge.data.transitions ??
      (throw StateError('Referenced transition storage disappeared'));
  for (var index = 0; index < transitions.length; index++) {
    if (identical(transitions[index], ref.transition)) {
      transitions.removeAt(index);
      return;
    }
  }
  throw StateError('Pinned transition iterator target is missing');
}

double _mulF32(double left, double right) {
  final slot = Float32List(1)..[0] = left;
  final left32 = slot[0];
  slot[0] = right;
  final right32 = slot[0];
  slot[0] = left32 * right32;
  return slot[0];
}
