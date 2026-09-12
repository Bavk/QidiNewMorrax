import 'dart:math' as math;
import 'dart:typed_data';

import '../geometry/source_geometry.dart';
import 'source_arachne_beading_strategy.dart';
import 'source_arachne_generate_segments_foundation.dart';
import 'source_arachne_skeletal_graph.dart';
import 'source_arachne_wall_tool_paths.dart';

const int _beadSearchMax = 1000;
const int _sourceCoordMax = 0x7fffffff;

/// Second source-order slice of pinned
/// `SkeletalTrapezoidation::generateSegments()`: beading propagation and lazy
/// beading lookup/creation.
extension SourceArachneGenerateSegmentsPropagation2
    on SourceArachneSkeletalTrapezoidationGraph2 {
  void propagateBeadingsUpward(
    List<SourceArachneSTHalfEdge2> upwardQuadMids,
    List<SourceArachneBeadingPropagation2> nodeBeadings, {
    required int centralFilterDistance,
  }) {
    for (final upwardEdge in upwardQuadMids.reversed) {
      final from = upwardEdge.from ??
          (throw StateError('Upward propagation edge has no from node'));
      final to = upwardEdge.to ??
          (throw StateError('Upward propagation edge has no to node'));
      if (to.data.beadCount >= 0) {
        continue;
      }
      if (!from.data.hasBeading) {
        continue;
      }
      final lowerBeading = from.data.beading!;
      if (to.data.hasBeading) {
        continue;
      }

      assert(from.data.distanceToBoundary != to.data.distanceToBoundary ||
          _sourceShorterThen(to.p - from.p, centralFilterDistance));
      final length = _edgeLength(upwardEdge);
      final upperBeading = _copyPropagation(lowerBeading)
        ..distToBottomSource += length
        ..isUpwardPropagatedOnly = true;
      nodeBeadings.add(upperBeading);
      to.data.setBeading(upperBeading);
      assert(upperBeading.beading.totalThickness <=
          to.data.distanceToBoundary * 2);
    }
  }

  void propagateBeadingsDownward(
    List<SourceArachneSTHalfEdge2> upwardQuadMids,
    List<SourceArachneBeadingPropagation2> nodeBeadings,
    SourceArachneBeadingStrategy2 beadingStrategy, {
    required int beadingPropagationTransitionDistance,
  }) {
    for (final upwardQuadMid in upwardQuadMids) {
      if (upwardQuadMid.data.isCentral) {
        continue;
      }
      final from = upwardQuadMid.from ??
          (throw StateError('Downward propagation edge has no from node'));
      final to = upwardQuadMid.to ??
          (throw StateError('Downward propagation edge has no to node'));
      if (from.data.distanceToBoundary == to.data.distanceToBoundary &&
          from.data.hasBeading &&
          !to.data.hasBeading) {
        final twin = upwardQuadMid.twin ??
            (throw StateError('Equidistant propagation edge has no twin'));
        _propagateBeadingsDownwardFrom(
          twin,
          nodeBeadings,
          beadingStrategy,
          beadingPropagationTransitionDistance,
        );
      } else {
        _propagateBeadingsDownwardFrom(
          upwardQuadMid,
          nodeBeadings,
          beadingStrategy,
          beadingPropagationTransitionDistance,
        );
      }
    }
  }

  SourceArachneBeadingPropagation2 getOrCreateBeading(
    SourceArachneSTHalfEdgeNode2 node,
    List<SourceArachneBeadingPropagation2> nodeBeadings,
    SourceArachneBeadingStrategy2 beadingStrategy,
  ) {
    if (!node.data.hasBeading) {
      if (node.data.beadCount == -1) {
        final nearbyDistance =
            SourceArachneWallToolPathsPreprocess2.scaleDouble(0.1);
        final nearest = getNearestBeading(node, nearbyDistance);
        if (nearest != null) {
          // Literal source behavior: return the nearby shared_ptr directly;
          // the queried node itself remains without a beading pointer.
          return nearest;
        }

        var hasCentralEdge = false;
        var first = true;
        var distance = _sourceCoordMax;
        var edge = node.incidentEdge;
        while (edge != null && (first || !identical(edge, node.incidentEdge))) {
          if (edge.data.isCentral) {
            hasCentralEdge = true;
          }
          final edgeFrom = edge.from ??
              (throw StateError('Lazy beading edge has no from node'));
          final edgeTo = edge.to ??
              (throw StateError('Lazy beading edge has no to node'));
          assert(edgeTo.data.distanceToBoundary >= 0);
          distance = math.min(
            distance,
            edgeTo.data.distanceToBoundary + _edgeLengthBetween(edgeFrom, edgeTo),
          );
          first = false;
          final twin = edge.twin ??
              (throw StateError('Lazy beading radial edge has no twin'));
          edge = twin.next;
        }
        // Source only logs if the node is unexpectedly non-central.
        if (!hasCentralEdge) {
          // Keep release behavior; bead count is still synthesized below.
        }
        if (distance == _sourceCoordMax) {
          throw StateError('Lazy beading could not determine nearby radius');
        }
        node.data.beadCount =
            beadingStrategy.getOptimalBeadCount(distance * 2);
      }

      assert(node.data.beadCount != -1);
      final propagation = SourceArachneBeadingPropagation2(
        beadingStrategy.compute(
          node.data.distanceToBoundary * 2,
          node.data.beadCount,
        ),
      );
      nodeBeadings.add(propagation);
      node.data.setBeading(propagation);
    }
    return node.data.beading!;
  }

  SourceArachneBeadingPropagation2? getNearestBeading(
    SourceArachneSTHalfEdgeNode2 node,
    int maxDistance,
  ) {
    final furtherEdges = <_DistEdge>[];
    var first = true;
    var outgoing = node.incidentEdge;
    while (outgoing != null &&
        (first || !identical(outgoing, node.incidentEdge))) {
      final from = outgoing.from ??
          (throw StateError('Nearest-beading edge has no from node'));
      final to = outgoing.to ??
          (throw StateError('Nearest-beading edge has no to node'));
      furtherEdges.add(_DistEdge(outgoing, _edgeLengthBetween(from, to)));
      first = false;
      final twin = outgoing.twin ??
          (throw StateError('Nearest-beading radial edge has no twin'));
      outgoing = twin.next;
    }

    for (var counter = 0; counter < _beadSearchMax; counter++) {
      if (furtherEdges.isEmpty) return null;
      var nearestIndex = 0;
      for (var index = 1; index < furtherEdges.length; index++) {
        if (furtherEdges[index].distance <
            furtherEdges[nearestIndex].distance) {
          nearestIndex = index;
        }
      }
      final here = furtherEdges.removeAt(nearestIndex);
      if (here.distance > maxDistance) return null;
      final to = here.edgeTo.to ??
          (throw StateError('Nearest-beading queued edge has no to node'));
      if (to.data.hasBeading) {
        return to.data.beading;
      }

      var furtherEdge = here.edgeTo.next;
      while (furtherEdge != null &&
          !identical(furtherEdge, here.edgeTo.twin)) {
        final from = furtherEdge.from ??
            (throw StateError('Nearest-beading recurse edge has no from node'));
        final nextTo = furtherEdge.to ??
            (throw StateError('Nearest-beading recurse edge has no to node'));
        furtherEdges.add(
          _DistEdge(
            furtherEdge,
            here.distance + _edgeLengthBetween(from, nextTo),
          ),
        );
        final twin = furtherEdge.twin ??
            (throw StateError('Nearest-beading recurse edge has no twin'));
        furtherEdge = twin.next;
      }
    }
    return null;
  }

  void _propagateBeadingsDownwardFrom(
    SourceArachneSTHalfEdge2 edgeToPeak,
    List<SourceArachneBeadingPropagation2> nodeBeadings,
    SourceArachneBeadingStrategy2 beadingStrategy,
    int beadingPropagationTransitionDistance,
  ) {
    final from = edgeToPeak.from ??
        (throw StateError('Downward source edge has no from node'));
    final to = edgeToPeak.to ??
        (throw StateError('Downward source edge has no to node'));
    final length = _edgeLength(edgeToPeak);
    final topBeading = getOrCreateBeading(
      to,
      nodeBeadings,
      beadingStrategy,
    );
    assert(topBeading.beading.totalThickness >=
        to.data.distanceToBoundary * 2);
    assert(!topBeading.isUpwardPropagatedOnly);

    if (!from.data.hasBeading) {
      final propagatedBeading = _copyPropagation(topBeading)
        ..distFromTopSource += length;
      nodeBeadings.add(propagatedBeading);
      from.data.setBeading(propagatedBeading);
      assert(propagatedBeading.beading.totalThickness >=
          from.data.distanceToBoundary * 2);
      return;
    }

    final bottomBeading = from.data.beading!;
    final totalDistance = topBeading.distFromTopSource +
        length +
        bottomBeading.distToBottomSource;
    final denominator = math.min(
      totalDistance,
      beadingPropagationTransitionDistance,
    );
    // Source: static_cast<float>(bottom_dist) / integer denominator. Both
    // operands therefore meet at float precision before assignment to double.
    var ratioOfTop = denominator == 0
        ? double.infinity
        : _f32(
            _f32(bottomBeading.distToBottomSource.toDouble()) /
                _f32(denominator.toDouble()),
          );
    ratioOfTop = math.max(0.0, ratioOfTop);

    if (ratioOfTop >= 1.0) {
      // Source assigns through a BeadingPropagation& reference. Preserve the
      // object identity so every shared_ptr alias observes the same mutation.
      bottomBeading
        ..beading = topBeading.beading
        ..distToBottomSource = topBeading.distToBottomSource
        ..distFromTopSource = topBeading.distFromTopSource + length
        ..isUpwardPropagatedOnly = topBeading.isUpwardPropagatedOnly;
    } else {
      final mergedBeading = sourceInterpolateBeadingAtRadius(
        topBeading.beading,
        ratioOfTop,
        bottomBeading.beading,
        from.data.distanceToBoundary,
      );
      // `bottom_beading = BeadingPropagation(merged_beading)` also assigns
      // into the existing shared object and resets propagation metadata.
      bottomBeading
        ..beading = mergedBeading
        ..distToBottomSource = 0
        ..distFromTopSource = 0
        ..isUpwardPropagatedOnly = false;
      assert(mergedBeading.totalThickness >=
          from.data.distanceToBoundary * 2);
    }
  }
}

SourceArachneBeading2 sourceInterpolateBeadingAtRadius(
  SourceArachneBeading2 left,
  double ratioLeftToWhole,
  SourceArachneBeading2 right,
  int switchingRadius,
) {
  assert(ratioLeftToWhole >= 0.0 && ratioLeftToWhole <= 1.0);
  var result = sourceInterpolateBeading(left, ratioLeftToWhole, right);

  var nextInsetIndex = left.toolpathLocations.length - 1;
  for (; nextInsetIndex >= 0; nextInsetIndex--) {
    if (switchingRadius > left.toolpathLocations[nextInsetIndex]) {
      break;
    }
  }
  if (nextInsetIndex < 0) {
    return result;
  }
  if (nextInsetIndex + 1 == left.toolpathLocations.length) {
    return result;
  }

  if (result.toolpathLocations[nextInsetIndex] > switchingRadius) {
    final numerator = _f32(
      (switchingRadius - right.toolpathLocations[nextInsetIndex]).toDouble(),
    );
    final denominator = _f32(
      (left.toolpathLocations[nextInsetIndex] -
              right.toolpathLocations[nextInsetIndex])
          .toDouble(),
    );
    var newRatio = _f32(numerator / denominator);
    newRatio = _f32(math.min(1.0, newRatio + 0.1));
    result = sourceInterpolateBeading(left, newRatio, right);
  }
  return result;
}

class _DistEdge {
  const _DistEdge(this.edgeTo, this.distance);

  final SourceArachneSTHalfEdge2 edgeTo;
  final int distance;
}

SourceArachneBeadingPropagation2 _copyPropagation(
  SourceArachneBeadingPropagation2 source,
) =>
    SourceArachneBeadingPropagation2(source.beading)
      ..distToBottomSource = source.distToBottomSource
      ..distFromTopSource = source.distFromTopSource
      ..isUpwardPropagatedOnly = source.isUpwardPropagatedOnly;

int _edgeLength(SourceArachneSTHalfEdge2 edge) {
  final from = edge.from ??
      (throw StateError('Propagation edge has no from node'));
  final to = edge.to ??
      (throw StateError('Propagation edge has no to node'));
  return _edgeLengthBetween(from, to);
}

int _edgeLengthBetween(
  SourceArachneSTHalfEdgeNode2 from,
  SourceArachneSTHalfEdgeNode2 to,
) =>
    math.sqrt((to.p - from.p).squaredLength).truncate();

bool _sourceShorterThen(SourcePoint2 vector, int length) {
  if (vector.x > length || vector.x < -length) return false;
  if (vector.y > length || vector.y < -length) return false;
  return vector.x * vector.x + vector.y * vector.y <= length * length;
}

double _f32(double value) {
  final slot = Float32List(1)..[0] = value;
  return slot[0];
}
