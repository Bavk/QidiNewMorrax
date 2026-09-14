import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';

/// Exact conservative subset of pinned Clipper1 `ctUnion` + `pftNonZero` for
/// already-offset closed paths whose boundaries do not intersect.
///
/// When boundaries are pairwise disjoint, a path survives the NonZero union iff
/// crossing that boundary changes the accumulated winding from zero to nonzero
/// (outer contour) or nonzero to zero (hole). This helper accepts only the
/// unambiguous one-level cases used by current Arachne consumers:
///
/// - disconnected positive contours (`0 -> +1`), and
/// - clockwise holes directly inside positive material (`+1 -> 0`).
///
/// Nested same-sign paths, orphan negative paths, intersecting/touching paths,
/// and deeper alternating nesting are deliberately rejected so callers can keep
/// the compatibility boolean executor until those Clipper1 cases have their own
/// oracle coverage.
class SourceClipper1NonInteractingUnion2 {
  const SourceClipper1NonInteractingUnion2._();

  static bool supports(Iterable<SourcePolygon2> polygons) {
    final values = List<SourcePolygon2>.of(polygons);
    if (values.isEmpty) return true;
    if (values.any((polygon) => polygon.points.length < 3 || polygon.signedArea == 0)) {
      return false;
    }

    for (var first = 0; first < values.length; first++) {
      for (var second = first + 1; second < values.length; second++) {
        if (_boundariesIntersect(values[first], values[second])) return false;
      }
    }

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

      if (sign > 0) {
        // A represented material island must be entered from zero winding.
        if (outsideWinding != 0 || insideWinding != 1) return false;
      } else {
        // A represented hole must directly cancel exactly one positive contour.
        if (outsideWinding != 1 || insideWinding != 0) return false;
      }
    }
    return true;
  }

  /// Returns the exact surviving geometry for [supports] inputs.
  ///
  /// The source union does not alter coordinates when no boundaries interact.
  /// Keeping the per-path order is intentional: the current Arachne caller feeds
  /// the already-source-shaped per-path results in source input order, and the
  /// independent through-hole process oracle verifies the resulting downstream
  /// wall geometry after this seam.
  static List<SourcePolygon2> union(Iterable<SourcePolygon2> polygons) {
    final values = List<SourcePolygon2>.of(polygons);
    if (!supports(values)) {
      throw ArgumentError(
        'Pinned noninteracting Clipper1 NonZero union subset does not apply',
      );
    }
    return List<SourcePolygon2>.unmodifiable(values);
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
