import 'dart:math' as math;

import '../geometry/source_geometry.dart';
import 'source_arachne_beading_strategy.dart';
import 'source_arachne_skeletal_central.dart';
import 'source_arachne_skeletal_graph.dart';

const int _sourceShortEdge = 10000; // scaled<coord_t>(0.01)
const int _sourceMaxNoncentralDistance = 400000; // scaled<coord_t>(0.4)

/// Direct port of pinned `SkeletalTrapezoidation::filterNoncentralRegions()`.
extension SourceArachneSkeletalNoncentral2
    on SourceArachneSkeletalTrapezoidationGraph2 {
  void filterNoncentralRegions(SourceArachneBeadingStrategy2 beadingStrategy) {
    for (final edge in edges) {
      if (!isEndOfCentral(edge)) {
        continue;
      }

      final to = edge.to ??
          (throw StateError('Noncentral filter end edge has no to node'));
      if (to.data.beadCount < 0 && to.data.distanceToBoundary != 0) {
        // Pinned source logs a warning and asserts immediately afterward.
        throw StateError(
          'Noncentral filter encountered an uninitialized boundary bead',
        );
      }

      _filterNoncentralFrom(
        edge,
        to.data.beadCount,
        0,
        _sourceMaxNoncentralDistance,
        beadingStrategy,
      );
    }
  }
}

bool _filterNoncentralFrom(
  SourceArachneSTHalfEdge2 toEdge,
  int beadCount,
  int traveledDistance,
  int maxDistance,
  SourceArachneBeadingStrategy2 beadingStrategy,
) {
  final toNode = toEdge.to ??
      (throw StateError('Noncentral recursive edge has no to node'));
  final radius = toNode.data.distanceToBoundary;

  var nextEdge = toEdge.next;
  while (nextEdge != null && !identical(nextEdge, toEdge.twin)) {
    final nextFrom = nextEdge.from ??
        (throw StateError('Noncentral candidate edge has no from node'));
    final nextTo = nextEdge.to ??
        (throw StateError('Noncentral candidate edge has no to node'));
    if (nextTo.data.distanceToBoundary >= radius ||
        _sourceShorterThen(nextTo.p - nextFrom.p, _sourceShortEdge)) {
      break;
    }
    final twin = nextEdge.twin ??
        (throw StateError('Noncentral radial edge has no twin'));
    nextEdge = twin.next;
  }

  if (nextEdge == null || identical(nextEdge, toEdge.twin)) {
    return false;
  }

  final nextFrom = nextEdge.from ??
      (throw StateError('Selected noncentral edge has no from node'));
  final nextTo = nextEdge.to ??
      (throw StateError('Selected noncentral edge has no to node'));
  final length = math.sqrt((nextTo.p - nextFrom.p).squaredLength).truncate();

  bool dissolve;
  if (nextTo.data.beadCount == beadCount) {
    dissolve = true;
  } else if (nextTo.data.beadCount < 0) {
    dissolve = _filterNoncentralFrom(
      nextEdge,
      beadCount,
      traveledDistance + length,
      maxDistance,
      beadingStrategy,
    );
  } else {
    dissolve = traveledDistance + length < maxDistance &&
        (nextTo.data.beadCount - beadCount).abs() == 1;
  }

  if (dissolve) {
    nextEdge.data.setIsCentral(true);
    final twin = nextEdge.twin ??
        (throw StateError('Dissolved noncentral edge has no twin'));
    twin.data.setIsCentral(true);
    nextTo.data.beadCount = beadingStrategy.getOptimalBeadCount(
      nextTo.data.distanceToBoundary * 2,
    );
    nextTo.data.transitionRatio = 0;
  }
  return dissolve;
}

bool _sourceShorterThen(SourcePoint2 vector, int length) {
  if (vector.x > length || vector.x < -length) return false;
  if (vector.y > length || vector.y < -length) return false;
  return vector.x * vector.x + vector.y * vector.y <= length * length;
}
