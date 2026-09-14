import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';

/// Exact pinned Clipper1 `ctUnion` + `pftNonZero` subset for two positive
/// strict-convex triangles that share one complete edge and where
/// `FixupOutPolygon()` removes exactly one shared endpoint.
///
/// Direct pinned-ELF differentials cover both pointer-state branches:
///
/// - removed endpoint is not the ordinary full-edge `BuildResult()` start:
///   64800/64800 raw paths;
/// - removed endpoint is that ordinary start: 64800/64800 classification paths,
///   97200/97200 independent unequal-third-distance paths and 108/108 targeted
///   equal-Y boundaries.
///
/// Every matrix includes all 3x3 cyclic source rotations and both polygon input
/// orders. The removed-start branch intentionally preserves the observed
/// `OutRec::Pts`/AddPath-order rule rather than canonicalizing the output.
/// Wider convex paths and any cleanup that removes more than one point remain
/// outside this helper.
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

    final ordinaryBuildStart = _fullSharedEdgeBuildStart(
      shared.firstStart,
      shared.firstEnd,
    );
    final removed = removable.single;

    // Following the first positive triangle after dropping the shared edge
    // gives the positive merged boundary. Reversing polygon input order only
    // cyclically rotates this same boundary before the source start rule is
    // applied.
    final cycle = <SourcePoint2>[
      shared.firstEnd,
      shared.firstThird,
      shared.firstStart,
      shared.secondThird,
    ]..remove(removed);
    if (cycle.length != 3 || _needsFixup(cycle)) return null;

    final buildStart = removed == ordinaryBuildStart
        ? _removedOrdinaryStartBuildStart(shared, removed)
        : ordinaryBuildStart;
    final startIndex = cycle.indexOf(buildStart);
    if (startIndex < 0) return null;

    final result = SourcePolygon2(_rotated(cycle, startIndex));
    if (result.signedArea <= 0) return null;
    return result;
  }

  /// Pinned `FixupOutPolygon()` / `OutRec::Pts` rule when the point removed by
  /// cleanup was itself the ordinary full-shared-edge `BuildResult()` start.
  ///
  /// `endThird` belongs to the source triangle whose directed shared edge ends
  /// at [removed]. `otherThird` belongs to the other triangle. If [removed] is
  /// `firstEnd`, that end-triangle is the first AddPath input; otherwise it is
  /// the second input. The asymmetric equal-Y comparisons are source-state
  /// behavior and are intentionally preserved literally.
  static SourcePoint2 _removedOrdinaryStartBuildStart(
    _FullSharedEdge2 shared,
    SourcePoint2 removed,
  ) {
    final removedIsFirstEnd = removed == shared.firstEnd;
    final surviving = removedIsFirstEnd
        ? shared.firstStart
        : shared.firstEnd;
    final endThird = removedIsFirstEnd
        ? shared.firstThird
        : shared.secondThird;
    final otherThird = removedIsFirstEnd
        ? shared.secondThird
        : shared.firstThird;
    final endTriangleIsFirstInput = removedIsFirstEnd;

    final dy = shared.firstEnd.y - shared.firstStart.y;
    if (dy == 0) return endThird;

    if (endTriangleIsFirstInput) {
      return endThird.y > surviving.y ? surviving : endThird;
    }

    if (endThird.y >= surviving.y) return surviving;
    if (otherThird.y < surviving.y && endThird.y > otherThird.y) {
      return surviving;
    }
    return endThird;
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
