import 'dart:math' as math;
import 'dart:typed_data';

import 'source_arachne_beading_strategy.dart';
import 'source_arachne_skeletal_graph.dart';

/// First source-order slice of pinned `SkeletalTrapezoidation::generateSegments()`:
/// upward quad-middle selection/sort and node beading materialization.
extension SourceArachneGenerateSegmentsFoundation2
    on SourceArachneSkeletalTrapezoidationGraph2 {
  List<SourceArachneSTHalfEdge2> collectUpwardQuadMids() {
    final result = <SourceArachneSTHalfEdge2>[];
    for (final edge in edges) {
      if (edge.prev != null && edge.next != null && edge.isUpward()) {
        result.add(edge);
      }
    }

    result.sort((a, b) {
      final aFrom = a.from ??
          (throw StateError('generateSegments sort edge has no from node'));
      final aTo = a.to ??
          (throw StateError('generateSegments sort edge has no to node'));
      final bFrom = b.from ??
          (throw StateError('generateSegments sort edge has no from node'));
      final bTo = b.to ??
          (throw StateError('generateSegments sort edge has no to node'));

      if (aTo.data.distanceToBoundary == bTo.data.distanceToBoundary) {
        final aFlat = aFrom.data.distanceToBoundary ==
            aTo.data.distanceToBoundary;
        final bFlat = bFrom.data.distanceToBoundary ==
            bTo.data.distanceToBoundary;
        if (aFlat && bFlat) {
          const maxCoord = 0x7fffffff;
          final aTwin = a.twin ??
              (throw StateError('Flat sorted edge has no twin'));
          final bTwin = b.twin ??
              (throw StateError('Flat sorted edge has no twin'));
          final aLength = math.sqrt((aTo.p - aFrom.p).squaredLength).truncate();
          final bLength = math.sqrt((bTo.p - bFrom.p).squaredLength).truncate();
          final aDistanceFromUp = math.min(
                a.distToGoUp() ?? maxCoord,
                aTwin.distToGoUp() ?? maxCoord,
              ) -
              aLength;
          final bDistanceFromUp = math.min(
                b.distToGoUp() ?? maxCoord,
                bTwin.distToGoUp() ?? maxCoord,
              ) -
              bLength;
          return aDistanceFromUp.compareTo(bDistanceFromUp);
        }
        if (aFlat) return -1;
        if (bFlat) return 1;
        // Source explicitly states ordering is not important here.
        return 0;
      }
      // Higher distance-to-boundary first.
      return bTo.data.distanceToBoundary
          .compareTo(aTo.data.distanceToBoundary);
    });
    return result;
  }

  List<SourceArachneBeadingPropagation2> storeNodeBeadings(
    SourceArachneBeadingStrategy2 beadingStrategy,
  ) {
    final ownership = <SourceArachneBeadingPropagation2>[];
    for (final node in nodes) {
      if (node.data.beadCount <= 0) {
        continue;
      }

      SourceArachneBeading2 beading;
      if (node.data.transitionRatio == 0) {
        beading = beadingStrategy.compute(
          node.data.distanceToBoundary * 2,
          node.data.beadCount,
        );
      } else {
        final lowCountBeading = beadingStrategy.compute(
          node.data.distanceToBoundary * 2,
          node.data.beadCount,
        );
        final highCountBeading = beadingStrategy.compute(
          node.data.distanceToBoundary * 2,
          node.data.beadCount + 1,
        );
        beading = sourceInterpolateBeading(
          lowCountBeading,
          1.0 - node.data.transitionRatio,
          highCountBeading,
        );
      }

      final propagation = SourceArachneBeadingPropagation2(beading);
      ownership.add(propagation);
      node.data.setBeading(propagation);
      assert(beading.totalThickness == node.data.distanceToBoundary * 2);
    }
    return ownership;
  }
}

/// Direct port of pinned three-argument `SkeletalTrapezoidation::interpolate`.
SourceArachneBeading2 sourceInterpolateBeading(
  SourceArachneBeading2 left,
  double ratioLeftToWhole,
  SourceArachneBeading2 right,
) {
  assert(ratioLeftToWhole >= 0.0 && ratioLeftToWhole <= 1.0);
  // Source stores only the right ratio in a float local.
  final ratioRightToWhole = _f32(1.0 - ratioLeftToWhole);
  final selected =
      left.totalThickness > right.totalThickness ? left : right;
  final beadWidths = List<int>.of(selected.beadWidths);
  final toolpathLocations = List<int>.of(selected.toolpathLocations);

  final sharedCount = math.min(left.beadWidths.length, right.beadWidths.length);
  for (var insetIndex = 0; insetIndex < sharedCount; insetIndex++) {
    if (left.beadWidths[insetIndex] == 0 ||
        right.beadWidths[insetIndex] == 0) {
      beadWidths[insetIndex] = 0;
    } else {
      beadWidths[insetIndex] =
          (ratioLeftToWhole * left.beadWidths[insetIndex] +
                  ratioRightToWhole * right.beadWidths[insetIndex])
              .truncate();
    }
    toolpathLocations[insetIndex] =
        (ratioLeftToWhole * left.toolpathLocations[insetIndex] +
                ratioRightToWhole * right.toolpathLocations[insetIndex])
            .truncate();
  }

  return SourceArachneBeading2(
    totalThickness: selected.totalThickness,
    beadWidths: beadWidths,
    toolpathLocations: toolpathLocations,
    leftOver: selected.leftOver,
  );
}

double _f32(double value) {
  final slot = Float32List(1)..[0] = value;
  return slot[0];
}
