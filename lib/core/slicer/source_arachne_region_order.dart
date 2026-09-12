import 'dart:typed_data';

import 'source_arachne_extrusion_line.dart';

/// Identity-based ordering edge returned by pinned
/// `Arachne::WallToolPaths::getRegionOrder()`.
class SourceArachneRegionOrder2 {
  const SourceArachneRegionOrder2(this.before, this.after);

  final SourceArachneExtrusionLine2 before;
  final SourceArachneExtrusionLine2 after;

  @override
  bool operator ==(Object other) =>
      other is SourceArachneRegionOrder2 &&
      identical(other.before, before) &&
      identical(other.after, after);

  @override
  int get hashCode => Object.hash(identityHashCode(before), identityHashCode(after));
}

/// Source-equivalent ordering constraints for adjacent Arachne walls.
///
/// Pinned source uses `SparsePointGrid` only as a neighborhood acceleration
/// structure. The width-dependent final acceptance radius is never larger than
/// its global search radius, so exhaustive vertex pairs preserve the exact
/// returned set while avoiding a second grid implementation.
class SourceArachneRegionOrderBuilder2 {
  const SourceArachneRegionOrderBuilder2._();

  static Set<SourceArachneRegionOrder2> getRegionOrder(
    List<SourceArachneExtrusionLine2> input, {
    required bool outerToInner,
  }) {
    var maxLineWidth = 0;
    for (final line in input) {
      for (final junction in line.junctions) {
        if (junction.w > maxLineWidth) maxLineWidth = junction.w;
      }
    }
    if (maxLineWidth == 0) return <SourceArachneRegionOrder2>{};

    const diagonalExtensionLiteral = 1.9;
    final diagonalExtension = _f32(diagonalExtensionLiteral);
    final result = <SourceArachneRegionOrder2>{};

    for (final here in input) {
      for (final hereJunction in here.junctions) {
        for (final nearby in input) {
          if (identical(nearby, here)) continue;
          if (nearby.insetIndex == here.insetIndex) continue;
          if (nearby.insetIndex > here.insetIndex + 1) continue;
          if (here.insetIndex > nearby.insetIndex + 1) continue;

          for (final nearbyJunction in nearby.junctions) {
            // Source: `(w_here + w_nearby) / 2 * 1.9f`, then implicit
            // conversion to coord_t at the `shorter_then` call boundary.
            final averageWidth =
                (hereJunction.w + nearbyJunction.w) ~/ 2;
            final distanceLimit = _f32(
              _f32(averageWidth.toDouble()) * diagonalExtension,
            ).truncate();
            if (!_shorterThen(
              hereJunction.p.x - nearbyJunction.p.x,
              hereJunction.p.y - nearbyJunction.p.y,
              distanceLimit,
            )) {
              continue;
            }

            if (here.isOdd || nearby.isOdd) {
              if (here.isOdd &&
                  !nearby.isOdd &&
                  nearby.insetIndex < here.insetIndex) {
                result.add(SourceArachneRegionOrder2(nearby, here));
              }
              if (nearby.isOdd &&
                  !here.isOdd &&
                  here.insetIndex < nearby.insetIndex) {
                result.add(SourceArachneRegionOrder2(here, nearby));
              }
            } else if ((nearby.insetIndex < here.insetIndex) ==
                outerToInner) {
              result.add(SourceArachneRegionOrder2(nearby, here));
            } else {
              result.add(SourceArachneRegionOrder2(here, nearby));
            }
          }
        }
      }
    }
    return result;
  }

  static bool _shorterThen(int x, int y, int length) {
    if (x > length || x < -length) return false;
    if (y > length || y < -length) return false;
    return x * x + y * y <= length * length;
  }

  static double _f32(double value) {
    final slot = Float32List(1)..[0] = value;
    return slot[0];
  }
}
