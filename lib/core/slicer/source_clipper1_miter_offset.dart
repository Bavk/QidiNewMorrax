import 'dart:math' as math;
import 'dart:typed_data';

import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';

/// Exact numerical subset of the pinned Clipper 6.2.9 offsetter used by
/// BambuStudio's `offset(Polygons, float, jtMiter, 3.)`.
///
/// This helper intentionally handles only a single simple convex closed path.
/// That subset is enough to avoid Clipper2 rounding drift on ordinary convex
/// Arachne outlines while leaving concave/multi-path boolean cleanup to the
/// existing compatibility path until the complete Clipper1 offset executor is
/// ported.
class SourceClipper1MiterOffset2 {
  const SourceClipper1MiterOffset2._();

  static const double miterLimit = 3.0;
  static const double shortestEdgeFactor = 0.005;

  /// Whether the path can be offset without invoking Clipper1's post-offset
  /// boolean cleanup. The source sets `ShortestEdgeLength` to
  /// `abs(delta * 0.005f)`; paths at/below that seam deliberately stay on the
  /// compatibility fallback until `ClipperOffset::AddPath` is fully ported.
  static bool supports(SourcePolygon2 polygon, double delta) {
    final points = _withoutClosingDuplicate(polygon.points);
    if (points.length < 3) return false;
    if (!_isConvex(points)) return false;

    final sourceDelta = _f32(delta);
    final shortest = _f32(sourceDelta * _f32(shortestEdgeFactor)).abs();
    final shortestSquared = shortest * shortest;
    for (var index = 0; index < points.length; index++) {
      final a = points[index];
      final b = points[(index + 1) % points.length];
      final dx = (b.x - a.x).toDouble();
      final dy = (b.y - a.y).toDouble();
      if (dx * dx + dy * dy <= shortestSquared) return false;
    }
    return true;
  }

  /// Closed convex `ClipperOffset` miter result using the pinned Clipper1
  /// double normals and half-away-from-zero `Round()` semantics.
  static SourcePolygon2 offset(SourcePolygon2 polygon, double delta) {
    final points = _withoutClosingDuplicate(polygon.points);
    if (!supports(polygon, delta)) {
      throw ArgumentError('Pinned convex Clipper1 miter subset does not apply');
    }
    if (delta == 0) return SourcePolygon2(points);

    final sourceDelta = _f32(delta);
    final normals = <_SourceClipperNormal2>[
      for (var index = 0; index < points.length; index++)
        _unitNormal(points[index], points[(index + 1) % points.length]),
    ];
    final miterLimitThreshold = 2.0 / (miterLimit * miterLimit);
    final output = <SourcePoint2>[];

    for (var index = 0; index < points.length; index++) {
      final previous = (index - 1 + points.length) % points.length;
      final normalPrevious = normals[previous];
      final normalCurrent = normals[index];
      final sinA = normalPrevious.x * normalCurrent.y -
          normalCurrent.x * normalPrevious.y;
      final dot = normalPrevious.x * normalCurrent.x +
          normalPrevious.y * normalCurrent.y;
      final r = 1.0 + dot;

      // A convex polygon reaches the source jtMiter / jtSquare branch for an
      // outward offset. For an inward offset Clipper1 emits a concave triplet
      // and its Execute() boolean pass resolves it to the same two-line
      // intersection. Computing that intersection directly keeps the exact
      // Clipper1 normal/rounding arithmetic without introducing Clipper2's
      // different offset construction.
      if (r >= miterLimitThreshold) {
        final q = sourceDelta / r;
        output.add(
          SourcePoint2(
            _clipperRound(
              points[index].x +
                  (normalPrevious.x + normalCurrent.x) * q,
            ),
            _clipperRound(
              points[index].y +
                  (normalPrevious.y + normalCurrent.y) * q,
            ),
          ),
        );
      } else {
        _appendSquare(
          output,
          points[index],
          normalPrevious,
          normalCurrent,
          sinA,
          sourceDelta,
        );
      }
    }

    return SourcePolygon2(output);
  }

  static void _appendSquare(
    List<SourcePoint2> output,
    SourcePoint2 point,
    _SourceClipperNormal2 previous,
    _SourceClipperNormal2 current,
    double sinA,
    double delta,
  ) {
    final dot = previous.x * current.x + previous.y * current.y;
    final dx = math.tan(math.atan2(sinA, dot) / 4.0);
    output
      ..add(
        SourcePoint2(
          _clipperRound(point.x + delta * (previous.x + previous.y * dx)),
          _clipperRound(point.y + delta * (previous.y - previous.x * dx)),
        ),
      )
      ..add(
        SourcePoint2(
          _clipperRound(point.x + delta * (current.x - current.y * dx)),
          _clipperRound(point.y + delta * (current.y + current.x * dx)),
        ),
      );
  }

  static _SourceClipperNormal2 _unitNormal(SourcePoint2 first, SourcePoint2 second) {
    var dx = (second.x - first.x).toDouble();
    var dy = (second.y - first.y).toDouble();
    if (dx == 0 && dy == 0) return const _SourceClipperNormal2(0, 0);
    final factor = 1.0 / math.sqrt(dx * dx + dy * dy);
    dx *= factor;
    dy *= factor;
    return _SourceClipperNormal2(dy, -dx);
  }

  static bool _isConvex(List<SourcePoint2> points) {
    var sign = 0;
    for (var index = 0; index < points.length; index++) {
      final a = points[index];
      final b = points[(index + 1) % points.length];
      final c = points[(index + 2) % points.length];
      final cross = (b.x - a.x) * (c.y - b.y) -
          (b.y - a.y) * (c.x - b.x);
      if (cross == 0) continue;
      final currentSign = cross > 0 ? 1 : -1;
      if (sign == 0) {
        sign = currentSign;
      } else if (sign != currentSign) {
        return false;
      }
    }
    return sign != 0;
  }

  static List<SourcePoint2> _withoutClosingDuplicate(List<SourcePoint2> input) {
    if (input.isEmpty) return const <SourcePoint2>[];
    final result = <SourcePoint2>[];
    for (final point in input) {
      if (result.isEmpty || result.last != point) result.add(point);
    }
    if (result.length > 1 && result.first == result.last) result.removeLast();
    return result;
  }

  static int _clipperRound(double value) =>
      value < 0 ? (value - 0.5).truncate() : (value + 0.5).truncate();

  static double _f32(double value) {
    final slot = Float32List(1)..[0] = value;
    return slot[0];
  }
}

class _SourceClipperNormal2 {
  const _SourceClipperNormal2(this.x, this.y);

  final double x;
  final double y;
}
