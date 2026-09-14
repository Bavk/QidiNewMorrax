import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';

/// Exact pinned Clipper1 `ctUnion` + `pftNonZero` subset for the remaining
/// strict-contained shared-edge contact between two positive strict-convex
/// triangles when the longer host edge runs toward decreasing Y.
///
/// Both endpoints of the shorter guest edge lie strictly inside one host edge,
/// the shared interval is traversed in the opposite direction, and the host
/// edge has `dy < 0`. Direct raw-ELF differentials against the pinned
/// BambuStudio binary establish the exact merged-contour `BuildResult()` start:
///
/// - guest third vertex below the overlap endpoint nearer host start -> overlap
///   endpoint nearer host end;
/// - guest third vertex above that endpoint -> host third vertex;
/// - equal Y -> standalone pinned Clipper1 start of the host triangle.
///
/// The rule matched 30,600/30,600 full raw result paths: 25,200 broad cases
/// plus 5,400 targeted slope/vertical/equal-Y cases, with all 3x3 cyclic source
/// rotations and both input orders. Wider convex paths, endpoint-aligned joins,
/// and other contact topologies remain outside this helper.
class SourceClipper1TwoConvexDecreasingStrictContainedUnion2 {
  const SourceClipper1TwoConvexDecreasingStrictContainedUnion2._();

  static bool supports(Iterable<SourcePolygon2> polygons) =>
      _resultOrNull(List<SourcePolygon2>.of(polygons)) != null;

  static SourcePolygon2 union(Iterable<SourcePolygon2> polygons) {
    final result = _resultOrNull(List<SourcePolygon2>.of(polygons));
    if (result == null) {
      throw ArgumentError(
        'Pinned decreasing strict-contained two-triangle Clipper1 subset does not apply',
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

    final candidates = <_DecreasingStrictContainedContact2>[];
    _appendCandidates(first, second, candidates);
    _appendCandidates(second, first, candidates);
    if (candidates.length != 1) return null;

    final contact = candidates.single;
    final cycle = <SourcePoint2>[
      contact.hostStart,
      contact.overlapNearHostStart,
      contact.guestThird,
      contact.overlapNearHostEnd,
      contact.hostEnd,
      contact.hostThird,
    ];
    if (_needsFixup(cycle)) return null;

    final buildStart = contact.guestThird.y < contact.overlapNearHostStart.y
        ? contact.overlapNearHostEnd
        : contact.guestThird.y > contact.overlapNearHostStart.y
            ? contact.hostThird
            : _triangleBuildStart(contact.hostPolygon);

    final startIndex = cycle.indexOf(buildStart);
    if (startIndex < 0) return null;
    final result = SourcePolygon2(_rotated(cycle, startIndex));
    if (result.signedArea <= 0) return null;
    return result;
  }

  static void _appendCandidates(
    SourcePolygon2 host,
    SourcePolygon2 guest,
    List<_DecreasingStrictContainedContact2> output,
  ) {
    for (var hostIndex = 0; hostIndex < 3; hostIndex++) {
      final hostStart = host.points[hostIndex];
      final hostEnd = host.points[(hostIndex + 1) % 3];
      if (hostEnd.y >= hostStart.y) continue;

      for (var guestIndex = 0; guestIndex < 3; guestIndex++) {
        final guestStart = guest.points[guestIndex];
        final guestEnd = guest.points[(guestIndex + 1) % 3];
        if (!_strictlyInsideSegment(hostStart, hostEnd, guestStart) ||
            !_strictlyInsideSegment(hostStart, hostEnd, guestEnd)) {
          continue;
        }

        final hostDx = hostEnd.x - hostStart.x;
        final hostDy = hostEnd.y - hostStart.y;
        final guestDx = guestEnd.x - guestStart.x;
        final guestDy = guestEnd.y - guestStart.y;
        final directionDot = BigInt.from(hostDx) * BigInt.from(guestDx) +
            BigInt.from(hostDy) * BigInt.from(guestDy);
        if (directionDot >= BigInt.zero) continue;

        final ordered = _sortAlongHost(
          hostStart,
          hostEnd,
          guestStart,
          guestEnd,
        );
        final hostThird = host.points[(hostIndex + 2) % 3];
        final guestThird = guest.points[(guestIndex + 2) % 3];

        // Positive strict triangles plus opposite traversal place the two third
        // vertices in opposite open half-planes of the shared support line.
        // Assert that source-shaped topology explicitly rather than accepting a
        // geometry that reaches the same interval through another interaction.
        if (_orientation(hostStart, hostEnd, hostThird) <= 0 ||
            _orientation(hostStart, hostEnd, guestThird) >= 0) {
          continue;
        }

        output.add(
          _DecreasingStrictContainedContact2(
            hostPolygon: host,
            hostStart: hostStart,
            hostEnd: hostEnd,
            hostThird: hostThird,
            overlapNearHostStart: ordered.$1,
            overlapNearHostEnd: ordered.$2,
            guestThird: guestThird,
          ),
        );
      }
    }
  }

  static (SourcePoint2, SourcePoint2) _sortAlongHost(
    SourcePoint2 hostStart,
    SourcePoint2 hostEnd,
    SourcePoint2 first,
    SourcePoint2 second,
  ) {
    final dx = BigInt.from(hostEnd.x - hostStart.x);
    final dy = BigInt.from(hostEnd.y - hostStart.y);
    BigInt position(SourcePoint2 point) =>
        BigInt.from(point.x - hostStart.x) * dx +
        BigInt.from(point.y - hostStart.y) * dy;
    return position(first) <= position(second)
        ? (first, second)
        : (second, first);
  }

  static SourcePoint2 _triangleBuildStart(SourcePolygon2 polygon) {
    final maximumY = polygon.points
        .map((point) => point.y)
        .reduce((a, b) => a > b ? a : b);
    final bottoms =
        polygon.points.where((point) => point.y == maximumY).toList();
    if (bottoms.length >= 2) {
      return bottoms.reduce((a, b) => a.x >= b.x ? a : b);
    }

    final bottom = bottoms.single;
    final minimumY = polygon.points
        .map((point) => point.y)
        .reduce((a, b) => a < b ? a : b);
    final tops = polygon.points.where((point) => point.y == minimumY).toList();
    if (tops.length >= 2) return bottom;

    final top = tops.single;
    final middle = polygon.points.singleWhere(
      (point) => point != bottom && point != top,
    );
    return _orientation(bottom, top, middle) > 0 ? middle : bottom;
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

class _DecreasingStrictContainedContact2 {
  const _DecreasingStrictContainedContact2({
    required this.hostPolygon,
    required this.hostStart,
    required this.hostEnd,
    required this.hostThird,
    required this.overlapNearHostStart,
    required this.overlapNearHostEnd,
    required this.guestThird,
  });

  final SourcePolygon2 hostPolygon;
  final SourcePoint2 hostStart;
  final SourcePoint2 hostEnd;
  final SourcePoint2 hostThird;
  final SourcePoint2 overlapNearHostStart;
  final SourcePoint2 overlapNearHostEnd;
  final SourcePoint2 guestThird;
}
