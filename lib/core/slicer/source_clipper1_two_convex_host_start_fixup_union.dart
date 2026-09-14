import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';

/// Exact pinned Clipper1 `ctUnion` + `pftNonZero` subset for two positive
/// strict-convex triangles whose endpoint-aligned partial shared edge reaches
/// the *start* of a longer host edge and creates exactly one collinear vertex
/// that `FixupOutPolygon()` removes.
///
/// The shared `hostStart` lies strictly between the two triangle third vertices,
/// so the pre-fixup merged cycle contains `hostThird -> hostStart -> guestThird`
/// on one straight line. Pinned Clipper1 removes `hostStart`.
///
/// Direct raw-ELF matrices matched 145800/145800 full result paths across both
/// non-horizontal Y directions, vertical edges, both horizontal directions,
/// integer shears, all 3x3 cyclic source rotations and both input orders. The
/// exact post-fixup `BuildResult()` start is the same source-state rule already
/// proved for the non-fixup host-start join:
///
/// - host edge `dy < 0` -> the interior overlap endpoint;
/// - host edge `dy > 0` -> the host triangle third vertex;
/// - horizontal rightward host edge -> the interior overlap endpoint;
/// - horizontal leftward host edge -> the host triangle third vertex.
///
/// Only this one-removed-endpoint state is represented. Other fixup-mutated
/// contacts, wider convex paths and mixed crossing/contact topologies remain on
/// the compatibility seam.
class SourceClipper1TwoConvexHostStartFixupUnion2 {
  const SourceClipper1TwoConvexHostStartFixupUnion2._();

  static bool supports(Iterable<SourcePolygon2> polygons) =>
      _resultOrNull(List<SourcePolygon2>.of(polygons)) != null;

  static SourcePolygon2 union(Iterable<SourcePolygon2> polygons) {
    final result = _resultOrNull(List<SourcePolygon2>.of(polygons));
    if (result == null) {
      throw ArgumentError(
        'Pinned host-start fixup two-triangle Clipper1 subset does not apply',
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

    final candidates = <_HostStartFixupContact2>[];
    _appendCandidates(first, second, candidates);
    _appendCandidates(second, first, candidates);
    if (candidates.length != 1) return null;

    final contact = candidates.single;
    if (!_strictlyInsideSegment(
      contact.guestThird,
      contact.hostThird,
      contact.hostStart,
    )) {
      return null;
    }

    // The pre-fixup merged cycle is:
    // interiorOverlap -> hostEnd -> hostThird -> hostStart -> guestThird.
    // hostStart is the one source point proved to be removed by FixupOutPolygon.
    final cycle = <SourcePoint2>[
      contact.interiorOverlap,
      contact.hostEnd,
      contact.hostThird,
      contact.guestThird,
    ];
    if (_needsFixup(cycle)) return null;

    final dx = contact.hostEnd.x - contact.hostStart.x;
    final dy = contact.hostEnd.y - contact.hostStart.y;
    final buildStart = dy < 0 || (dy == 0 && dx > 0)
        ? contact.interiorOverlap
        : contact.hostThird;
    final startIndex = cycle.indexOf(buildStart);
    if (startIndex < 0) return null;

    final result = SourcePolygon2(_rotated(cycle, startIndex));
    if (result.signedArea <= 0) return null;
    return result;
  }

  static void _appendCandidates(
    SourcePolygon2 host,
    SourcePolygon2 guest,
    List<_HostStartFixupContact2> output,
  ) {
    for (var hostIndex = 0; hostIndex < 3; hostIndex++) {
      final hostStart = host.points[hostIndex];
      final hostEnd = host.points[(hostIndex + 1) % 3];
      final hostThird = host.points[(hostIndex + 2) % 3];

      for (var guestIndex = 0; guestIndex < 3; guestIndex++) {
        final guestStart = guest.points[guestIndex];
        final guestEnd = guest.points[(guestIndex + 1) % 3];
        final guestThird = guest.points[(guestIndex + 2) % 3];

        final guestTouchesHostStart =
            guestStart == hostStart || guestEnd == hostStart;
        if (!guestTouchesHostStart) continue;
        final interiorOverlap =
            guestStart == hostStart ? guestEnd : guestStart;
        if (!_strictlyInsideSegment(hostStart, hostEnd, interiorOverlap)) {
          continue;
        }

        final hostDx = hostEnd.x - hostStart.x;
        final hostDy = hostEnd.y - hostStart.y;
        final guestDx = guestEnd.x - guestStart.x;
        final guestDy = guestEnd.y - guestStart.y;
        final directionDot = BigInt.from(hostDx) * BigInt.from(guestDx) +
            BigInt.from(hostDy) * BigInt.from(guestDy);
        if (directionDot >= BigInt.zero) continue;

        if (_orientation(hostStart, hostEnd, hostThird) <= 0 ||
            _orientation(hostStart, hostEnd, guestThird) >= 0) {
          continue;
        }

        if (_hasUnexpectedInteraction(
          host,
          guest,
          hostStart,
          hostEnd,
          interiorOverlap,
        )) {
          continue;
        }

        output.add(
          _HostStartFixupContact2(
            hostStart: hostStart,
            hostEnd: hostEnd,
            hostThird: hostThird,
            interiorOverlap: interiorOverlap,
            guestThird: guestThird,
          ),
        );
      }
    }
  }

  static bool _hasUnexpectedInteraction(
    SourcePolygon2 host,
    SourcePolygon2 guest,
    SourcePoint2 hostStart,
    SourcePoint2 hostEnd,
    SourcePoint2 interiorOverlap,
  ) {
    final allowed = <SourcePoint2>{hostStart, interiorOverlap};
    final touches = <SourcePoint2>{};
    for (var firstIndex = 0; firstIndex < 3; firstIndex++) {
      final a = host.points[firstIndex];
      final b = host.points[(firstIndex + 1) % 3];
      for (var secondIndex = 0; secondIndex < 3; secondIndex++) {
        final c = guest.points[secondIndex];
        final d = guest.points[(secondIndex + 1) % 3];
        if (_segmentsProperlyIntersect(a, b, c, d)) return true;
        _appendTouchPoint(a, b, c, touches);
        _appendTouchPoint(a, b, d, touches);
        _appendTouchPoint(c, d, a, touches);
        _appendTouchPoint(c, d, b, touches);
      }
    }
    if (touches.any((point) => !allowed.contains(point))) return true;
    if (!_onSegment(hostStart, hostEnd, interiorOverlap)) return true;
    return _hasStrictInteriorVertex(host, guest) ||
        _hasStrictInteriorVertex(guest, host);
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
      final b = polygon.points[(index + 1) % 3];
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

class _HostStartFixupContact2 {
  const _HostStartFixupContact2({
    required this.hostStart,
    required this.hostEnd,
    required this.hostThird,
    required this.interiorOverlap,
    required this.guestThird,
  });

  final SourcePoint2 hostStart;
  final SourcePoint2 hostEnd;
  final SourcePoint2 hostThird;
  final SourcePoint2 interiorOverlap;
  final SourcePoint2 guestThird;
}
