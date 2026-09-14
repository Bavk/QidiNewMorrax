import 'dart:math' as math;
import 'dart:typed_data';

import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import 'source_clipper1_miter_offset.dart';

/// Conservative exact subset of pinned Clipper 6.2.9 negative `Execute()` for
/// one simple non-orthogonal positive contour with exactly one reflex vertex.
///
/// With a negative delta every convex source turn is emitted by `DoOffset()` as
/// a three-point spike. The outer-rectangle / `pftNegative` cleanup collapses
/// each such spike to the rounded intersection of its two adjacent integer
/// offset segments. The single reflex turn keeps the source miter/square join
/// already present in the raw path. This behavior is independently captured
/// from the pinned BambuStudio ELF by the V-notch fixture.
///
/// Results that become non-simple, leave the source polygon, contain more than
/// one reflex turn, are orthogonal, or need `AddPath()` pruning are rejected for
/// the general Clipper1 boolean executor.
class SourceClipper1NegativeConcaveExecute2 {
  const SourceClipper1NegativeConcaveExecute2._();

  static bool supports(SourcePolygon2 polygon, double delta) =>
      _clean(polygon, delta) != null;

  static SourcePolygon2 offset(SourcePolygon2 polygon, double delta) {
    final result = _clean(polygon, delta);
    if (result == null) {
      throw ArgumentError(
        'Pinned safe negative concave Clipper1 Execute subset does not apply',
      );
    }
    return result;
  }

  static SourcePolygon2? _clean(SourcePolygon2 polygon, double delta) {
    if (polygon.signedArea <= 0) return null;
    final sourceDelta = _f32(delta);
    if (!sourceDelta.isFinite || sourceDelta >= 0) return null;

    final points = _withoutClosingDuplicate(polygon.points);
    if (points.length < 4 || !_inputSurvivesAddPathUnchanged(points, sourceDelta)) {
      return null;
    }
    if (_isOrthogonal(points)) return null;

    final convex = List<bool>.filled(points.length, false);
    var concaveCount = 0;
    for (var index = 0; index < points.length; index++) {
      final previous = points[(index - 1 + points.length) % points.length];
      final point = points[index];
      final next = points[(index + 1) % points.length];
      final cross = BigInt.from(point.x - previous.x) *
              BigInt.from(next.y - point.y) -
          BigInt.from(point.y - previous.y) *
              BigInt.from(next.x - point.x);
      if (cross == BigInt.zero) return null;
      if (cross.isNegative) {
        concaveCount++;
      } else {
        convex[index] = true;
      }
    }
    // Keep this first negative subset intentionally narrow. Multiple reflex
    // vertices may interact through the pftNegative boolean stage.
    if (concaveCount != 1) return null;

    final raw = SourceClipper1MiterOffset2.rawOffsetPath(polygon, sourceDelta);
    if (raw.points.length < points.length) return null;

    final middles = <int>[];
    for (var index = 0; index < points.length; index++) {
      final matches = <int>[];
      for (var rawIndex = 0; rawIndex < raw.points.length; rawIndex++) {
        if (raw.points[rawIndex] == points[index]) matches.add(rawIndex);
      }
      if (convex[index]) {
        if (matches.length != 1) return null;
        middles.add(matches.single);
      } else if (matches.isNotEmpty) {
        // A normal miter/square reflex join does not retain the original point.
        // Near-collinear or otherwise different source branches stay outside
        // this exact subset.
        return null;
      }
    }

    final removed = <int>{};
    final replacements = <int, SourcePoint2>{};
    final rawCount = raw.points.length;
    for (final middle in middles) {
      final before = (middle - 1 + rawCount) % rawCount;
      final beforeSegment = (middle - 2 + rawCount) % rawCount;
      final after = (middle + 1) % rawCount;
      final afterSegment = (middle + 2) % rawCount;
      if ({before, middle, after}.any(removed.contains)) return null;

      final intersection = _intersectRoundedSegments(
        raw.points[beforeSegment],
        raw.points[before],
        raw.points[after],
        raw.points[afterSegment],
      );
      if (intersection == null) return null;
      removed
        ..add(before)
        ..add(middle)
        ..add(after);
      replacements[middle] = intersection;
    }

    final cleaned = <SourcePoint2>[];
    for (var index = 0; index < rawCount; index++) {
      final replacement = replacements[index];
      if (replacement != null) {
        cleaned.add(replacement);
      } else if (!removed.contains(index)) {
        cleaned.add(raw.points[index]);
      }
    }
    if (cleaned.length < 3) return null;

    final candidate = SourcePolygon2(_rotateToClipperStart(cleaned));
    if (candidate.signedArea <= 0 ||
        candidate.signedArea >= polygon.signedArea ||
        !_isSimple(candidate.points) ||
        !_liesInsideSource(candidate, polygon)) {
      return null;
    }
    return candidate;
  }

  static SourcePoint2? _intersectRoundedSegments(
    SourcePoint2 firstStart,
    SourcePoint2 firstEnd,
    SourcePoint2 secondStart,
    SourcePoint2 secondEnd,
  ) {
    final rx = (firstEnd.x - firstStart.x).toDouble();
    final ry = (firstEnd.y - firstStart.y).toDouble();
    final sx = (secondEnd.x - secondStart.x).toDouble();
    final sy = (secondEnd.y - secondStart.y).toDouble();
    final denominator = rx * sy - ry * sx;
    if (denominator == 0 || !denominator.isFinite) return null;

    final qpx = (secondStart.x - firstStart.x).toDouble();
    final qpy = (secondStart.y - firstStart.y).toDouble();
    final t = (qpx * sy - qpy * sx) / denominator;
    final u = (qpx * ry - qpy * rx) / denominator;
    if (!(t > 0.0 && t < 1.0 && u > 0.0 && u < 1.0)) return null;

    final x = firstStart.x + t * rx;
    final y = firstStart.y + t * ry;
    if (!x.isFinite || !y.isFinite) return null;
    return SourcePoint2(_clipperRound(x), _clipperRound(y));
  }

  static bool _liesInsideSource(
    SourcePolygon2 candidate,
    SourcePolygon2 source,
  ) {
    for (var index = 0; index < candidate.points.length; index++) {
      final first = candidate.points[index];
      final second = candidate.points[(index + 1) % candidate.points.length];
      if (!source.contains(first)) return false;
      final midpoint = SourcePoint2(
        (first.x + second.x) ~/ 2,
        (first.y + second.y) ~/ 2,
      );
      if (!source.contains(midpoint)) return false;
    }
    return true;
  }

  static bool _inputSurvivesAddPathUnchanged(
    List<SourcePoint2> points,
    double sourceDelta,
  ) {
    final shortest =
        (sourceDelta * SourceClipper1MiterOffset2.shortestEdgeFactor).abs();
    final shortestSquared = shortest * shortest;
    for (var index = 0; index < points.length; index++) {
      final first = points[index];
      final second = points[(index + 1) % points.length];
      final dx = (second.x - first.x).toDouble();
      final dy = (second.y - first.y).toDouble();
      if (dx * dx + dy * dy < shortestSquared) return false;
    }
    return true;
  }

  static bool _isOrthogonal(List<SourcePoint2> points) {
    for (var index = 0; index < points.length; index++) {
      final first = points[index];
      final second = points[(index + 1) % points.length];
      if (first.x != second.x && first.y != second.y) return false;
    }
    return true;
  }

  static bool _isSimple(List<SourcePoint2> points) {
    for (var firstIndex = 0; firstIndex < points.length; firstIndex++) {
      final firstNext = (firstIndex + 1) % points.length;
      for (var secondIndex = firstIndex + 1;
          secondIndex < points.length;
          secondIndex++) {
        final secondNext = (secondIndex + 1) % points.length;
        if (secondIndex == firstNext || secondNext == firstIndex) continue;
        if (_segmentsIntersectOrTouch(
          points[firstIndex],
          points[firstNext],
          points[secondIndex],
          points[secondNext],
        )) {
          return false;
        }
      }
    }
    return true;
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
    return point.x >= math.min(a.x, b.x) &&
        point.x <= math.max(a.x, b.x) &&
        point.y >= math.min(a.y, b.y) &&
        point.y <= math.max(a.y, b.y);
  }

  static List<SourcePoint2> _withoutClosingDuplicate(List<SourcePoint2> input) {
    if (input.isEmpty) return const <SourcePoint2>[];
    final result = List<SourcePoint2>.of(input);
    while (result.length > 1 && result.last == result.first) {
      result.removeLast();
    }
    return result;
  }

  static List<SourcePoint2> _rotateToClipperStart(List<SourcePoint2> points) {
    var start = 0;
    for (var index = 1; index < points.length; index++) {
      final point = points[index];
      final best = points[start];
      if (point.x > best.x || (point.x == best.x && point.y > best.y)) {
        start = index;
      }
    }
    return List<SourcePoint2>.generate(
      points.length,
      (index) => points[(start + index) % points.length],
      growable: false,
    );
  }

  static int _clipperRound(double value) =>
      value < 0 ? (value - 0.5).truncate() : (value + 0.5).truncate();

  static double _f32(double value) {
    final slot = Float32List(1)..[0] = value;
    return slot[0];
  }
}
