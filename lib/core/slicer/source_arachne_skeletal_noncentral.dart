import 'dart:math' as math;

import '../geometry/source_geometry.dart';
import 'source_arachne_beading_strategy.dart';
import 'source_arachne_skeletal_central.dart';
import 'source_arachne_skeletal_graph.dart';
import 'source_arachne_wall_tool_paths.dart';

/// Direct port of pinned
/// `SkeletalTrapezoidation::filterNoncentralRegions()`.
extension SourceArachneSkeletalNoncentral2
    on SourceArachneSkeletalTrapezoidationGraph2 {
  void filterNoncentralRegions(
    SourceArachneBeadingStrategy2 beadingStrategy,
  ) {
    final maxDist =
        SourceArachneWallToolPathsPreprocess2.scaleDouble(0.4);
    for (final edge in edges) {
      if (!isEndOfCentral(edge)) {
        continue;
      }
      final to = edge.to ??
          (throw StateError('filterNoncentralRegions end edge has no to node'));
      assert(to.data.beadCount >= 0 || to.data.distanceToBoundary == 0);
      _filterNoncentralFrom(
        edge,
        to.data.beadCount,
        0,
        maxDist,
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
  final end = toEdge.to ??
      (throw StateError('filterNoncentralRegions edge has no to node'));
  final radius = end.data.distanceToBoundary;
  final tinyEdgeLength =
      SourceArachneWallToolPathsPreprocess2.scaleDouble(0.01);

  var nextEdge = toEdge.next;
  while (nextEdge != null && !identical(nextEdge, toEdge.twin)) {
    final nextFrom = nextEdge.from ??
        (throw StateError('filterNoncentralRegions next edge has no from node'));
    final nextTo = nextEdge.to ??
        (throw StateError('filterNoncentralRegions next edge has no to node'));
    if (nextTo.data.distanceToBoundary >= radius ||
        _sourceShorterThen(nextTo.p - nextFrom.p, tinyEdgeLength)) {
      break;
    }
    final twin = nextEdge.twin ??
        (throw StateError('filterNoncentralRegions radial edge has no twin'));
    nextEdge = twin.next;
  }

  if (nextEdge == null || identical(nextEdge, toEdge.twin)) {
    return false;
  }

  final nextFrom = nextEdge.from ??
      (throw StateError('filterNoncentralRegions next edge has no from node'));
  final nextTo = nextEdge.to ??
      (throw StateError('filterNoncentralRegions next edge has no to node'));
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
        (throw StateError('filterNoncentralRegions dissolved edge has no twin'));
    twin.data.setIsCentral(true);
    nextTo.data.beadCount = beadingStrategy.getOptimalBeadCount(
      nextTo.data.distanceToBoundary * 2,
    );
    nextTo.data.transitionRatio = 0;
  }
  return dissolve;
}

/// Literal source `shorter_then(Point, coord_t)` comparison.
bool _sourceShorterThen(SourcePoint2 vector, int length) {
  if (vector.x > length ||
      vector.x < -length ||
      vector.y > length ||
      vector.y < -length) {
    return false;
  }
  return vector.squaredLength <= length * length;
}
