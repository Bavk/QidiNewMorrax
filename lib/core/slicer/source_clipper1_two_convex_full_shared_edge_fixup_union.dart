import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';

/// Exact pinned Clipper1 `ctUnion` + `pftNonZero` subset for two positive
/// strict-convex triangles that share one complete edge and where
/// `FixupOutPolygon()` removes exactly one shared endpoint.
///
/// This helper deliberately represents only the raw-state branch where the
/// removed endpoint is *not* the ordinary full-shared-edge `BuildResult()`
/// start. Direct pinned-ELF differentials matched 64800/64800 raw paths across
/// 3600 randomized base geometries, all 3x3 cyclic source rotations and both
/// polygon input orders. In this branch the post-fixup raw start remains the
/// ordinary full-edge start: lower Y endpoint, or the greater X endpoint on a
/// horizontal tie.
///
/// When cleanup removes that ordinary start itself, Clipper's `OutRec::Pts`
/// pointer state becomes acceptance-relevant and is intentionally left on the
/// compatibility seam until independently proved.
class SourceClipper1TwoConvexFullSharedEdgeFixupUnion2 {
  const SourceClipper1TwoConvexFullSharedEdgeFixupUnion2._();

  static bool supports(Iterable<SourcePolygon2> polygons) =>
      _resultOrNull(List<SourcePolygon2>.of(polygons)) != null;

  static SourcePolygon2 union(Iterable<SourcePolygon2> polygons) {
    final result = _resultOrNull(List<SourcePolygon2>.of(polygons));
    if (result == null) {
      throw ArgumentError(
        'Pinned full-shared-edge fixup two-triangle Clipper1 subset does not apply',
      );
    }
    return result;
  }

  static SourcePolygon2? _resultOrNull(List<SourcePolygon2> polygons) {
    if (polygons.length != 2) return null;
    final first = polygons[0];
    final second = polygons[1];
    if (!_isStrictPositiveTriangle(first) ||
        !_isStrictPositiveTriangle(second)) {
      return null;
    }

    final candidates = <_FullSharedEdge2>[];
    for (var firstIndex = 0; firstIndex < 3; firstIndex++) {
      final firstStart = first.points[firstIndex];
      final firstEnd = first.points[(firstIndex + 1) % 3];
      for (var secondIndex = 0; secondIndex < 3; secondIndex++) {
        final secondStart = second.points[secondIndex];
        final secondEnd = second.points[(secondIndex + 1) % 3];
        if (firstStart == secondEnd && firstEnd == secondStart) {
          candidates.add(
            _FullSharedEdge2(
              firstStart: firstStart,
              firstEnd: firstEnd,
              firstThird: first.points[(firstIndex + 2) % 3],
              secondThird: second.points[(secondIndex + 2) % 3],
            ),
          );
        }
      }
    }
    if (candidates.length != 1) return null;

    final shared = candidates.single;
    if (_hasUnexpectedInteraction(
      first,
      second,
      shared.firstStart,
      shared.firstEnd,
    )) {
      return null;
    }

    final removable = <SourcePoint2>[];
    for (final endpoint in [shared.firstStart, shared.firstEnd]) {
      if (_strictlyInsideSegment(
        shared.firstThird,
        shared.secondThird,
        endpoint,
      )) {
        removable.add(endpoint);
      }
    }
    if (removable.length != 1) return null;

    final buildStart = _fullSharedEdgeBuildStart(
      shared.firstStart,
      shared.firstEnd,
    );
    final removed = removable.single;
    if (removed == buildStart) return null;

    // Following the first positive triangle after dropping the shared edge
    // gives the positive merged boundary. Reversing polygon input order only
    // cyclically rotates this same boundary.
    final cycle = <SourcePoint2>[
      shared.firstEnd,
      shared.firstThird,
      shared.firstStart,
      shared.secondThird,
    ]..remove(removed);
    if (cycle.length != 3 || _needsFixup(cycle)) return null;

    final startIndex = cycle.indexOf(buildStart);
    if (startIndex < 0) return null;
    final result = SourcePolygon2(_rotated(cycle, startIndex));
    if (result.signedArea <= 0) return null;
    return result;
  }

  static SourcePoint2 _fullSharedEdgeBuildStart(
    SourcePoint2 first,
    SourcePoint2 second,
  ) {
    if (first.y < second.y) return first;
    if (second.y < first.y) return second;
    return first.x >= second.x ? first : second;
  }

  static bool _hasUnexpectedInteraction(
    SourcePolygon2 first,
    SourcePolygon2 second,
    SourcePoint2 sharedStart,
    SourcePoint2 sharedEnd,
  ) {
    final allowed = <SourcePoint2>{sharedStart, sharedEnd};
    final touches = <SourcePoint2>{};
    for (var firstIndex = 0; firstIndex < 3; firstIndex++) {
      final a = first.points[firstIndex];
      final b = first.points[(firstIndex + 1) % 3];
      for (var secondIndex = 0; secondIndex < 3; secondIndex++) {
        final c = second.points[secondIndex];
        final d = second.points[(secondIndex + 1) % 3];
        if (_segmentsProperlyIntersect(a, b, c, d)) return true;
        _appendTouchPoint(a, b, c, touches);
        _appendTouchPoint(a, b, d, touches);
        _appendTouchPoint(c, d, a, touches);
        _appendTouchPoint(c, d, b, touches);
      }
    }
    if (touches.any((point) => !allowed.contains(point))) return true;
    return _hasStrictInteriorVertex(first, second) ||
        _hasStrictInteriorVertex(second, first);
  }

  static bool _hasStrictInteriorVertex(
    SourcePolygon2 source,
    SourcePolygon2 other,
  ) =>
      source.points.any((point) => _locateInConvex(point, other) == 1);

  static int _locateInConvex(SourcePoint2 point, SourcePolygon2 polygon) {
    var boundary = false;
    for (var index = 0; index < polygon.points.length; index++) {
      final a = polygon.points[index];
      final b = polygon.points[(index + 1) % polygon.points.length];
      final side = _orientation(a, b, point);
      if (side < 0) return -1;
      if (side == 0 && _onSegment(a, b, point)) boundary = true;
    }
    return boundary ? 0 : 1;
  }

  static bool _needsFixup(List<SourcePoint2> cycle) {
    for (var index = 0; index < cycle.length; index++) {
      final previous = cycle[(index - 1 + cycle.length) % cycle.length];
      final point = cycle[index];
      final next = cycle[(index + 1) % cycle.length];
      if (point == previous || point == next) return true;
      if (_orientation(previous, point, next) == 0) return true;
    }
    return false;
  }

  static bool _isStrictPositiveTriangle(SourcePolygon2 polygon) {
    if (polygon.points.length != 3 || polygon.signedArea <= 0) return false;
    for (var index = 0; index < 3; index++) {
      final previous = polygon.points[(index + 2) % 3];
      final point = polygon.points[index];
      final next = polygon.points[(index + 1) % 3];
      if (_orientation(previous, point, next) <= 0) return false;
    }
    return true;
  }

  static bool _strictlyInsideSegment(
    SourcePoint2 start,
    SourcePoint2 end,
    SourcePoint2 point,
  ) =>
      point != start && point != end && _onSegment(start, end, point);

  static void _appendTouchPoint(
    SourcePoint2 a,
    SourcePoint2 b,
    SourcePoint2 point,
    Set<SourcePoint2> output,
  ) {
    if (_orientation(a, b, point) == 0 && _onSegment(a, b, point)) {
      output.add(point);
    }
  }

  static bool _segmentsProperlyIntersect(
    SourcePoint2 a,
    SourcePoint2 b,
    SourcePoint2 c,
    SourcePoint2 d,
  ) {
    final abC = _orientation(a, b, c);
    final abD = _orientation(a, b, d);
    final cdA = _orientation(c, d, a);
    final cdB = _orientation(c, d, b);
    return abC != 0 &&
        abD != 0 &&
        cdA != 0 &&
        cdB != 0 &&
        abC.sign != abD.sign &&
        cdA.sign != cdB.sign;
  }

  static bool _onSegment(SourcePoint2 a, SourcePoint2 b, SourcePoint2 point) {
    if (_orientation(a, b, point) != 0) return false;
    final minX = a.x < b.x ? a.x : b.x;
    final maxX = a.x > b.x ? a.x : b.x;
    final minY = a.y < b.y ? a.y : b.y;
    final maxY = a.y > b.y ? a.y : b.y;
    return point.x >= minX &&
        point.x <= maxX &&
        point.y >= minY &&
        point.y <= maxY;
  }

  static int _orientation(SourcePoint2 a, SourcePoint2 b, SourcePoint2 c) {
    final cross = BigInt.from(b.x - a.x) * BigInt.from(c.y - a.y) -
        BigInt.from(b.y - a.y) * BigInt.from(c.x - a.x);
    return cross.sign;
  }

  static List<SourcePoint2> _rotated(
    List<SourcePoint2> points,
    int start,
  ) =>
      List<SourcePoint2>.generate(
        points.length,
        (index) => points[(start + index) % points.length],
        growable: false,
      );
}

class _FullSharedEdge2 {
  const _FullSharedEdge2({
    required this.firstStart,
    required this.firstEnd,
    required this.firstThird,
    required this.secondThird,
  });

  final SourcePoint2 firstStart;
  final SourcePoint2 firstEnd;
  final SourcePoint2 firstThird;
  final SourcePoint2 secondThird;
}
