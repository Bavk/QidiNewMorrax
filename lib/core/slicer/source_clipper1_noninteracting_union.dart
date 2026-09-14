import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';

/// Exact conservative subset of pinned Clipper1 `ctUnion` + `pftNonZero` for
/// already-offset closed paths whose boundaries do not intersect.
///
/// For pairwise-disjoint boundaries the NonZero result is determined entirely
/// by the winding number on both sides of each boundary. A boundary survives
/// iff crossing it changes filled state (`winding != 0`). The represented
/// subset keeps only source-shaped surviving transitions whose orientation is
/// already known exactly:
///
/// - positive material boundaries: `0 -> +1`;
/// - clockwise holes: `+1 -> 0`;
/// - any boundary with nonzero winding on both sides is suppressed, including
///   nested same-sign positive contours (`+1 -> +2`).
///
/// This also handles deeper noninteracting alternating nesting when each
/// surviving boundary still has one of the two canonical transitions above.
/// Orphan-negative/reversed surviving boundaries and intersecting/touching paths
/// are deliberately rejected for the full Clipper1 boolean executor.
class SourceClipper1NonInteractingUnion2 {
  const SourceClipper1NonInteractingUnion2._();

  static bool supports(Iterable<SourcePolygon2> polygons) =>
      _survivorsOrNull(List<SourcePolygon2>.of(polygons)) != null;

  /// Returns the exact surviving geometry for [supports] inputs.
  ///
  /// Input paths are already the source-shaped outputs of the represented
  /// per-path Clipper1 offsetters, including their source start vertex and
  /// orientation. With no boundary intersections, the NonZero union only
  /// removes boundaries whose filled state is unchanged; surviving coordinates
  /// and source order are retained literally.
  static List<SourcePolygon2> union(Iterable<SourcePolygon2> polygons) {
    final values = List<SourcePolygon2>.of(polygons);
    final survivors = _survivorsOrNull(values);
    if (survivors == null) {
      throw ArgumentError(
        'Pinned noninteracting Clipper1 NonZero union subset does not apply',
      );
    }
    return List<SourcePolygon2>.unmodifiable(survivors);
  }

  static List<SourcePolygon2>? _survivorsOrNull(
    List<SourcePolygon2> values,
  ) {
    if (values.isEmpty) return const <SourcePolygon2>[];
    if (values.any(
      (polygon) => polygon.points.length < 3 || polygon.signedArea == 0,
    )) {
      return null;
    }

    for (var first = 0; first < values.length; first++) {
      for (var second = first + 1; second < values.length; second++) {
        if (_boundariesIntersect(values[first], values[second])) return null;
      }
    }

    final survivors = <SourcePolygon2>[];
    for (var index = 0; index < values.length; index++) {
      final polygon = values[index];
      final sign = polygon.signedArea > 0 ? 1 : -1;
      var outsideWinding = 0;
      final probe = polygon.points.first;
      for (var otherIndex = 0; otherIndex < values.length; otherIndex++) {
        if (otherIndex == index) continue;
        final other = values[otherIndex];
        if (!other.contains(probe, borderResult: false)) continue;
        outsideWinding += other.signedArea > 0 ? 1 : -1;
      }
      final insideWinding = outsideWinding + sign;
      final outsideFilled = outsideWinding != 0;
      final insideFilled = insideWinding != 0;

      if (outsideFilled == insideFilled) {
        // The NonZero fill state does not change across this boundary. Pinned
        // Clipper1 therefore removes it from the union result. This is the
        // independently captured nested-positive `+1 -> +2` oracle seam.
        continue;
      }

      if (!outsideFilled && insideFilled) {
        // The only source-shaped outer transition represented here is 0 -> +1.
        // An orphan CW path would be 0 -> -1 and Clipper1 would have to rewrite
        // result orientation, which belongs to the general boolean executor.
        if (sign != 1 || outsideWinding != 0 || insideWinding != 1) return null;
        survivors.add(polygon);
        continue;
      }

      // Filled -> empty is represented only by a direct canonical hole 1 -> 0.
      if (sign != -1 || outsideWinding != 1 || insideWinding != 0) return null;
      survivors.add(polygon);
    }
    return survivors;
  }

  static bool _boundariesIntersect(SourcePolygon2 first, SourcePolygon2 second) {
    final firstPoints = first.points;
    final secondPoints = second.points;
    for (var firstIndex = 0; firstIndex < firstPoints.length; firstIndex++) {
      final a = firstPoints[firstIndex];
      final b = firstPoints[(firstIndex + 1) % firstPoints.length];
      for (var secondIndex = 0;
          secondIndex < secondPoints.length;
          secondIndex++) {
        final c = secondPoints[secondIndex];
        final d = secondPoints[(secondIndex + 1) % secondPoints.length];
        if (_segmentsIntersectOrTouch(a, b, c, d)) return true;
      }
    }
    return false;
  }

  static bool _segmentsIntersectOrTouch(
    SourcePoint2 a,
    SourcePoint2 b,
    SourcePoint2 c,
    SourcePoint2 d,
  ) {
    final abC = _orientation(a, b, c);
    final abD = _orientation(a, b, d);
    final cdA = _orientation(c, d, a);
    final cdB = _orientation(c, d, b);

    if (abC == 0 && _onSegment(a, b, c)) return true;
    if (abD == 0 && _onSegment(a, b, d)) return true;
    if (cdA == 0 && _onSegment(c, d, a)) return true;
    if (cdB == 0 && _onSegment(c, d, b)) return true;
    return (abC > 0) != (abD > 0) && (cdA > 0) != (cdB > 0);
  }

  static int _orientation(SourcePoint2 a, SourcePoint2 b, SourcePoint2 c) {
    final cross = BigInt.from(b.x - a.x) * BigInt.from(c.y - a.y) -
        BigInt.from(b.y - a.y) * BigInt.from(c.x - a.x);
    return cross.sign;
  }

  static bool _onSegment(SourcePoint2 a, SourcePoint2 b, SourcePoint2 point) {
    final minX = a.x < b.x ? a.x : b.x;
    final maxX = a.x > b.x ? a.x : b.x;
    final minY = a.y < b.y ? a.y : b.y;
    final maxY = a.y > b.y ? a.y : b.y;
    return point.x >= minX &&
        point.x <= maxX &&
        point.y >= minY &&
        point.y <= maxY;
  }
}