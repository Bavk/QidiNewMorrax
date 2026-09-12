import 'dart:math' as math;
import 'dart:typed_data';

import 'source_arachne_beading_strategy.dart';
import 'source_arachne_skeletal_graph.dart';

/// Direct port of pinned central-classification/filtering methods from
/// `SkeletalTrapezoidation`.
extension SourceArachneSkeletalCentral2
    on SourceArachneSkeletalTrapezoidationGraph2 {
  void updateIsCentral(SourceArachneBeadingStrategy2 beadingStrategy) {
    final outerEdgeFilterLength =
        beadingStrategy.getTransitionThickness(0) ~/ 2;

    // Source: `float cap = sin(float_angle * 0.5);`. The `0.5` literal makes
    // the sin call operate in double, then assignment rounds once to float.
    final cap = _f32(math.sin(beadingStrategy.transitioningAngle * 0.5));

    for (final edge in edges) {
      final twin = edge.twin;
      if (twin == null) {
        // Source asserts in debug, logs and continues in release. Keep the edge
        // state untouched instead of inventing a central classification.
        continue;
      }

      if (twin.data.centralIsSet) {
        edge.data.setIsCentral(twin.data.isCentral);
      } else if (edge.data.type == SourceArachneSkeletalEdgeType2.extraVd) {
        edge.data.setIsCentral(false);
      } else {
        final from = edge.from ??
            (throw StateError('Central edge has no from node'));
        final to = edge.to ??
            (throw StateError('Central edge has no to node'));
        final maxDistance = math.max(
          from.data.distanceToBoundary,
          to.data.distanceToBoundary,
        );
        if (maxDistance < outerEdgeFilterLength) {
          edge.data.setIsCentral(false);
        } else {
          final ab = to.p - from.p;
          final dR = (to.data.distanceToBoundary -
                  from.data.distanceToBoundary)
              .abs();
          final dD = math.sqrt(ab.squaredLength).truncate();

          // `coord_t * float` is evaluated as float in C++. Explicitly round
          // the integer-to-float conversion and multiplication here so large
          // source distances do not silently use Dart double precision.
          final cappedDistance = _mulF32(_f32(dD.toDouble()), cap);
          edge.data.setIsCentral(dR < cappedDistance);
        }
      }
    }
  }

  /// Literal pinned `SkeletalTrapezoidation::isEndOfCentral()`.
  bool isEndOfCentral(SourceArachneSTHalfEdge2 edgeTo) {
    if (!edgeTo.data.isCentral) {
      return false;
    }
    if (edgeTo.next == null) {
      return true;
    }

    var edge = edgeTo.next;
    while (edge != null && !identical(edge, edgeTo.twin)) {
      if (edge.data.isCentral) {
        return false;
      }
      final twin = edge.twin ??
          (throw StateError('isEndOfCentral radial edge has no twin'));
      edge = twin.next;
    }
    return true;
  }

  /// Direct port of pinned top-level `filterCentral(coord_t)`.
  ///
  /// The source predicate contains the literal contradiction
  /// `edge.to->isLocalMaximum() && !edge.to->isLocalMaximum()`. On a stable
  /// graph this makes the recursive filter unreachable. Keep that behavior
  /// rather than silently fixing the upstream quirk.
  void filterCentral(int maxLength) {
    for (final edge in edges) {
      if (!isEndOfCentral(edge)) {
        continue;
      }
      final to = edge.to ??
          (throw StateError('filterCentral end edge has no to node'));
      if (to.isLocalMaximum() && !to.isLocalMaximum()) {
        final twin = edge.twin ??
            (throw StateError('filterCentral end edge has no twin'));
        _filterCentralFrom(twin, 0, maxLength);
      }
    }
  }

  /// Direct port of pinned `filterOuterCentral()`.
  void filterOuterCentral() {
    for (final edge in edges) {
      if (edge.prev != null) {
        continue;
      }
      edge.data.setIsCentral(false);
      final twin = edge.twin ??
          (throw StateError('filterOuterCentral edge has no twin'));
      twin.data.setIsCentral(false);
    }
  }
}

bool _filterCentralFrom(
  SourceArachneSTHalfEdge2 startingEdge,
  int traveledDistance,
  int maxLength,
) {
  final from = startingEdge.from ??
      (throw StateError('recursive filterCentral edge has no from node'));
  final to = startingEdge.to ??
      (throw StateError('recursive filterCentral edge has no to node'));
  final length = math.sqrt((from.p - to.p).squaredLength).truncate();
  if (traveledDistance + length > maxLength) {
    return false;
  }

  var shouldDissolve = true;
  var nextEdge = startingEdge.next;
  while (nextEdge != null && !identical(nextEdge, startingEdge.twin)) {
    if (nextEdge.data.isCentral) {
      // C++ uses boolean `&=` here, so the recursive call is evaluated even if
      // an earlier branch already made should_dissolve false.
      final branchDissolves = _filterCentralFrom(
        nextEdge,
        traveledDistance + length,
        maxLength,
      );
      shouldDissolve = shouldDissolve && branchDissolves;
    }
    final twin = nextEdge.twin ??
        (throw StateError('recursive filterCentral radial edge has no twin'));
    nextEdge = twin.next;
  }

  // Source again uses `&=`; evaluate local-maximum detection unconditionally.
  final isLocalMaximum = to.isLocalMaximum();
  shouldDissolve = shouldDissolve && !isLocalMaximum;
  if (shouldDissolve) {
    startingEdge.data.setIsCentral(false);
    final twin = startingEdge.twin ??
        (throw StateError('recursive filterCentral edge has no twin'));
    twin.data.setIsCentral(false);
  }
  return shouldDissolve;
}

double _mulF32(double left, double right) =>
    _f32(_f32(left) * _f32(right));

double _f32(double value) {
  final slot = Float32List(1)..[0] = value;
  return slot[0];
}
