import 'dart:math' as math;
import 'dart:typed_data';

import 'source_arachne_beading_strategy.dart';
import 'source_arachne_skeletal_graph.dart';

/// Direct port of pinned `SkeletalTrapezoidation::updateIsCentral()`.
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
}

double _mulF32(double left, double right) =>
    _f32(_f32(left) * _f32(right));

double _f32(double value) {
  final slot = Float32List(1)..[0] = value;
  return slot[0];
}
