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
/// Result rebasing/order is also source-shaped for the independently captured
/// noninteracting scopes: positive contours start at max-Y/max-X, a direct hole
/// starts at min-Y/min-X, disconnected positive roots are emitted by descending
/// positive start point, and a single direct hole follows its parent. Multiple
/// holes, deeper alternating surviving boundaries, orphan-negative/reversed
/// survivors and intersecting/touching paths remain on the full Clipper1 boolean
/// executor seam.
class SourceClipper1NonInteractingUnion2 {
  const SourceClipper1NonInteractingUnion2._();

  static bool supports(Iterable<SourcePolygon2> polygons) =>
      _resultOrNull(List<SourcePolygon2>.of(polygons)) != null;

  /// Returns the exact represented Clipper1 NonZero result.
  static List<SourcePolygon2> union(Iterable<SourcePolygon2> polygons) {
    final values = List<SourcePolygon2>.of(polygons);
    final result = _resultOrNull(values);
    if (result == null) {
      throw ArgumentError(
        'Pinned noninteracting Clipper1 NonZero union subset does not apply',
      );
    }
    return List<SourcePolygon2>.unmodifiable(result);
  }

  static List<SourcePolygon2>? _resultOrNull(
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
        // Exact pinned nested-positive oracle: +1 -> +2 does not change NonZero
        // fill state, so the inner boundary disappears from the result.
        continue;
      }

      if (!outsideFilled && insideFilled) {
        if (sign != 1 || outsideWinding != 0 || insideWinding != 1) return null;
        survivors.add(_rebasePositive(polygon));
        continue;
      }

      if (sign != -1 || outsideWinding != 1 || insideWinding != 0) return null;
      survivors.add(_rebaseNegative(polygon));
    }

    final positives = survivors.where((polygon) => polygon.signedArea > 0).toList();
    final negatives = survivors.where((polygon) => polygon.signedArea < 0).toList();
    if (positives.isEmpty && survivors.isNotEmpty) return null;

    // Keep the exact order scope narrow. The pinned direct-hole oracle proves
    // parent then hole for one root/one hole. Multiple roots are independently
    // captured only when they have no surviving holes and are emitted by
    // descending positive BuildResult start point.
    if (negatives.isNotEmpty) {
      if (positives.length != 1 || negatives.length != 1) return null;
      final parent = positives.single;
      final hole = negatives.single;
      if (!parent.contains(hole.points.first, borderResult: false)) return null;
      return [parent, hole];
    }

    positives.sort((first, second) {
      final a = first.points.first;
      final b = second.points.first;
      final byY = b.y.compareTo(a.y);
      return byY != 0 ? byY : b.x.compareTo(a.x);
    });
    return positives;
  }

  static SourcePolygon2 _rebasePositive(SourcePolygon2 polygon) {
    var start = 0;
    for (var index = 1; index < polygon.points.length; index++) {
      final point = polygon.points[index];
      final best = polygon.points[start];
      if (point.y > best.y || (point.y == best.y && point.x > best.x)) {
        start = index;
      }
    }
    return SourcePolygon2(_rotated(polygon.points, start));
  }

  static SourcePolygon2 _rebaseNegative(SourcePolygon2 polygon) {
    var start = 0;
    for (var index = 1; index < polygon.points.length; index++) {
      final point = polygon.points[index];
      final best = polygon.points[start];
      if (point.y < best.y || (point.y == best.y && point.x < best.x)) {
        start = index;
      }
    }
    return SourcePolygon2(_rotated(polygon.points, start));
  }

  static List<SourcePoint2> _rotated(List<SourcePoint2> points, int start) =>
      List<SourcePoint2>.generate(
        points.length,
        (index) => points[(start + index) % points.length],
        growable: false,
      );

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