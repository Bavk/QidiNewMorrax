import 'dart:math' as math;
import 'dart:typed_data';

import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';

/// Exact numerical subset of the pinned Clipper 6.2.9 offsetter used by
/// BambuStudio's `offset(Polygons, float, jtMiter, 3.)`.
///
/// This helper intentionally handles only a single simple convex positive
/// contour. That subset is enough to avoid Clipper2 rounding drift on ordinary
/// convex Arachne outlines while leaving holes, concave/multi-path boolean
/// cleanup and other orientation cases to the existing compatibility path until
/// the complete Clipper1 offset executor is ported.
class SourceClipper1MiterOffset2 {
  const SourceClipper1MiterOffset2._();

  static const double miterLimit = 3.0;
  static const double shortestEdgeFactor = 0.005;

  /// Whether the path can use the exact simple-convex arithmetic subset. The
  /// source sets `ShortestEdgeLength` to `abs(delta * 0.005f)` and `AddPath()`
  /// drops edges strictly shorter than that threshold.
  static bool supports(SourcePolygon2 polygon, double delta) {
    final points = _withoutClosingDuplicate(polygon.points);
    if (points.length < 3) return false;
    // Single clockwise paths have Clipper1 orientation/fill semantics that
    // belong to the full executor; do not approximate them here.
    if (polygon.signedArea <= 0) return false;
    if (!_isConvex(points)) return false;

    final sourceDelta = _f32(delta);
    final shortest = _f32(sourceDelta * _f32(shortestEdgeFactor)).abs();
    final shortestSquared = shortest * shortest;
    for (var index = 0; index < points.length; index++) {
      final a = points[index];
      final b = points[(index + 1) % points.length];
      final dx = (b.x - a.x).toDouble();
      final dy = (b.y - a.y).toDouble();
      if (dx * dx + dy * dy < shortestSquared) return false;
    }
    return true;
  }

  /// Closed convex `ClipperOffset` result using the pinned Clipper1 double
  /// normals and half-away-from-zero `Round()` semantics.
  ///
  /// Positive offsets execute the source jtMiter/jtSquare branch directly.
  /// Negative offsets hit Clipper1's concave-triplet branch at every convex
  /// vertex and are then resolved by the source negative-offset union. For a
  /// single convex contour that cleanup is exactly the intersection of the
  /// inward-shifted edge half-planes, so it either yields one mitered convex
  /// contour or no contour at all.
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

      if (sourceDelta < 0) {
        // The source first emits the two shifted edge points plus the original
        // vertex, then its negative-offset union resolves the convex triplets
        // to the adjacent shifted-line intersection. A non-positive `r` is the
        // degenerate 180-degree seam and cannot leave a convex erosion.
        if (r <= 0) return SourcePolygon2(const <SourcePoint2>[]);
        _appendMiter(
          output,
          points[index],
          normalPrevious,
          normalCurrent,
          sourceDelta,
          r,
        );
      } else if (r >= miterLimitThreshold) {
        _appendMiter(
          output,
          points[index],
          normalPrevious,
          normalCurrent,
          sourceDelta,
          r,
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

    if (sourceDelta < 0 &&
        !_insideEveryShiftedHalfPlane(
          points,
          normals,
          sourceDelta,
          output,
        )) {
      return SourcePolygon2(const <SourcePoint2>[]);
    }
    return SourcePolygon2(output);
  }

  static void _appendMiter(
    List<SourcePoint2> output,
    SourcePoint2 point,
    _SourceClipperNormal2 previous,
    _SourceClipperNormal2 current,
    double delta,
    double r,
  ) {
    final q = delta / r;
    output.add(
      SourcePoint2(
        _clipperRound(point.x + (previous.x + current.x) * q),
        _clipperRound(point.y + (previous.y + current.y) * q),
      ),
    );
  }

  static bool _insideEveryShiftedHalfPlane(
    List<SourcePoint2> points,
    List<_SourceClipperNormal2> normals,
    double delta,
    List<SourcePoint2> output,
  ) {
    // Clipper1 rounds each constructed offset vertex to coord_t before the
    // boolean cleanup. Allow one source unit of perpendicular rounding drift;
    // an exhausted erosion violates at least one shifted edge by the actual
    // over-inset amount, not by this rounding quantum.
    const perpendicularTolerance = 1.0;
    for (final candidate in output) {
      for (var index = 0; index < points.length; index++) {
        final a = points[index];
        final b = points[(index + 1) % points.length];
        final edgeX = (b.x - a.x).toDouble();
        final edgeY = (b.y - a.y).toDouble();
        final edgeLength = math.sqrt(edgeX * edgeX + edgeY * edgeY);
        final shiftedX = a.x + normals[index].x * delta;
        final shiftedY = a.y + normals[index].y * delta;
        final cross = edgeX * (candidate.y - shiftedY) -
            edgeY * (candidate.x - shiftedX);
        if (cross < -perpendicularTolerance * edgeLength) return false;
      }
    }
    return true;
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
    // Literal Clipper1 6.2.9 `DoSquare()` signs. These are intentionally not
    // the Clipper2 square-join construction.
    output
      ..add(
        SourcePoint2(
          _clipperRound(point.x + delta * (previous.x - previous.y * dx)),
          _clipperRound(point.y + delta * (previous.y + previous.x * dx)),
        ),
      )
      ..add(
        SourcePoint2(
          _clipperRound(point.x + delta * (current.x + current.y * dx)),
          _clipperRound(point.y + delta * (current.y - current.x * dx)),
        ),
      );
  }

  static _SourceClipperNormal2 _unitNormal(
    SourcePoint2 first,
    SourcePoint2 second,
  ) {
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
