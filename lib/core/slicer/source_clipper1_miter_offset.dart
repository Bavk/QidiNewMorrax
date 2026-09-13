import 'dart:math' as math;
import 'dart:typed_data';

import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';

/// Exact numerical subset of the pinned Clipper 6.2.9 offsetter used by
/// BambuStudio's `offset(Polygons, float, jtMiter, 3.)`.
///
/// The final cleaned result is exact for a standalone simple convex path,
/// including the CW-path sign/orientation convention used by BambuStudio's
/// `raw_offset()`. The helper also exposes the exact pre-union closed-path
/// `ClipperOffset::DoOffset()` stage for positive-area contours, including the
/// source `AddPath()` short-edge pruning and the concave triplets emitted by
/// `OffsetPoint()`. The pinned boolean cleanup after that raw stage and the
/// final multi-path union remain the next dependencies for general concave and
/// multi-path parity.
class SourceClipper1MiterOffset2 {
  const SourceClipper1MiterOffset2._();

  static const double miterLimit = 3.0;
  static const double shortestEdgeFactor = 0.005;

  /// Whether the positive-area path can use the historical cleaned convex
  /// subset API retained for the existing Arachne exact adapter.
  static bool supports(SourcePolygon2 polygon, double delta) {
    if (polygon.signedArea <= 0) return false;
    return supportsConvexSourcePath(polygon, delta);
  }

  /// Whether one source path can execute the exact per-path BambuStudio
  /// `raw_offset()` convex path, including CW reorientation/sign reversal.
  static bool supportsConvexSourcePath(SourcePolygon2 polygon, double delta) {
    final points = _prepareClosedPath(polygon.points, delta);
    return points.length >= 3 && _isConvex(points);
  }

  /// Exact cleaned offset for one convex path using the pinned wrapper order:
  /// `AddPath()`, remember original orientation, `Execute(ccw ? offset :
  /// -offset)`, then reverse the result back for an original CW path.
  ///
  /// `Execute()` internally reorients a standalone CW closed polygon to CCW
  /// before `DoOffset()`. Positive execution deltas need no topology cleanup for
  /// a convex path; negative execution deltas are the represented exact convex
  /// erosion cleanup.
  static SourcePolygon2 offsetConvexSourcePath(
    SourcePolygon2 polygon,
    double delta,
  ) {
    final prepared = _prepareClosedPath(polygon.points, delta);
    if (prepared.length < 3 || !_isConvex(prepared)) {
      throw ArgumentError('Pinned convex Clipper1 source-path subset does not apply');
    }

    // ClipperLib::Orientation(path) is `Area(path) >= 0` in the pinned source.
    final ccw = polygon.signedArea >= 0;
    final oriented = ccw
        ? prepared
        : List<SourcePoint2>.of(prepared.reversed, growable: false);
    final executionDelta = _f32(ccw ? delta : -delta);
    final result = _offsetPreparedConvex(oriented, executionDelta);
    if (ccw || result.points.isEmpty) return result;
    return SourcePolygon2(
      List<SourcePoint2>.of(result.points.reversed, growable: false),
    );
  }

  /// Whether a standalone positive-area closed path survives the exact pinned
  /// `ClipperOffset::AddPath()` input pruning and can execute the represented
  /// raw `DoOffset()` arithmetic.
  static bool supportsRawClosedPath(SourcePolygon2 polygon, double delta) {
    if (polygon.signedArea <= 0) return false;
    return _prepareClosedPath(polygon.points, delta).length >= 3;
  }

  /// Exact pre-union `ClipperOffset::DoOffset()` result for one positive-area
  /// closed path using pinned jtMiter, miter limit 3, source `AddPath()` point
  /// pruning, double normals and half-away-from-zero `Round()` semantics.
  ///
  /// For concave vertices this intentionally returns the three source points
  /// (previous shifted point, original vertex, current shifted point). Pinned
  /// `Execute()` subsequently unions these raw polygons with positive/negative
  /// fill semantics; that cleanup is not approximated here.
  static SourcePolygon2 rawOffsetPath(SourcePolygon2 polygon, double delta) {
    if (polygon.signedArea <= 0) {
      throw ArgumentError('Pinned raw Clipper1 closed-path subset does not apply');
    }
    final points = _prepareClosedPath(polygon.points, delta);
    if (points.length < 3) {
      throw ArgumentError('Pinned raw Clipper1 closed path was pruned away');
    }
    if (delta == 0) return SourcePolygon2(points);

    return _rawOffsetPreparedPath(points, _f32(delta));
  }

  /// Historical positive-contour entry point used by the exact Arachne adapter.
  static SourcePolygon2 offset(SourcePolygon2 polygon, double delta) {
    if (!supports(polygon, delta)) {
      throw ArgumentError('Pinned convex Clipper1 miter subset does not apply');
    }
    return offsetConvexSourcePath(polygon, delta);
  }

  static SourcePolygon2 _offsetPreparedConvex(
    List<SourcePoint2> points,
    double sourceDelta,
  ) {
    if (sourceDelta == 0) return SourcePolygon2(points);
    if (sourceDelta > 0) {
      return _rawOffsetPreparedPath(points, sourceDelta);
    }

    final normals = <_SourceClipperNormal2>[
      for (var index = 0; index < points.length; index++)
        _unitNormal(points[index], points[(index + 1) % points.length]),
    ];
    final output = <SourcePoint2>[];

    for (var index = 0; index < points.length; index++) {
      final previous = (index - 1 + points.length) % points.length;
      final normalPrevious = normals[previous];
      final normalCurrent = normals[index];
      final dot = normalPrevious.x * normalCurrent.x +
          normalPrevious.y * normalCurrent.y;
      final r = 1.0 + dot;

      // The source first emits the two shifted edge points plus the original
      // vertex, then its negative-offset union resolves the convex triplets to
      // the adjacent shifted-line intersection. A non-positive `r` is the
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
    }

    if (!_insideEveryShiftedHalfPlane(
      points,
      normals,
      sourceDelta,
      output,
    )) {
      return SourcePolygon2(const <SourcePoint2>[]);
    }
    return SourcePolygon2(output);
  }

  static SourcePolygon2 _rawOffsetPreparedPath(
    List<SourcePoint2> points,
    double sourceDelta,
  ) {
    final normals = <_SourceClipperNormal2>[
      for (var index = 0; index < points.length; index++)
        _unitNormal(points[index], points[(index + 1) % points.length]),
    ];
    final output = <SourcePoint2>[];
    for (var index = 0; index < points.length; index++) {
      final previous = (index - 1 + points.length) % points.length;
      _appendOffsetPoint(
        output,
        points[index],
        normals[previous],
        normals[index],
        sourceDelta,
      );
    }
    return SourcePolygon2(output);
  }

  /// Literal closed-polygon point preparation from the pinned modified
  /// `ClipperOffset::AddPath()`.
  ///
  /// `ShortestEdgeLength` is assigned from `abs(offset * 0.005f)`. For a closed
  /// path source first removes trailing points strictly nearer than that value
  /// to the first point, then walks forward and compares each candidate against
  /// the last point actually retained. Equality is deliberately kept.
  static List<SourcePoint2> _prepareClosedPath(
    List<SourcePoint2> input,
    double delta,
  ) {
    if (input.isEmpty) return const <SourcePoint2>[];

    final sourceDelta = _f32(delta);
    final shortest = _f32(sourceDelta * _f32(shortestEdgeFactor)).abs();
    final hasShortest = shortest > 0.0;
    final shortestSquared = shortest * shortest;

    bool same(SourcePoint2 a, SourcePoint2 b) {
      if (!hasShortest) return a == b;
      final dx = (a.x - b.x).toDouble();
      final dy = (a.y - b.y).toDouble();
      return dx * dx + dy * dy < shortestSquared;
    }

    var highIndex = input.length - 1;
    while (highIndex > 0 && same(input[highIndex], input[0])) {
      highIndex--;
    }

    final result = <SourcePoint2>[input[0]];
    for (var index = 1; index <= highIndex; index++) {
      if (same(input[index], result.last)) continue;
      result.add(input[index]);
    }
    return result;
  }

  static void _appendOffsetPoint(
    List<SourcePoint2> output,
    SourcePoint2 point,
    _SourceClipperNormal2 previous,
    _SourceClipperNormal2 current,
    double delta,
  ) {
    var sinA = previous.x * current.y - current.x * previous.y;

    // Literal Clipper1 `OffsetPoint()` near-collinear branch. When the turn is
    // below one offset coordinate unit it keeps the previous shifted point and
    // returns before the concave/miter/square branches.
    if ((sinA * delta).abs() < 1.0) {
      final cosA = previous.x * current.x + current.y * previous.y;
      if (cosA > 0) {
        output.add(
          SourcePoint2(
            _clipperRound(point.x + previous.x * delta),
            _clipperRound(point.y + previous.y * delta),
          ),
        );
        return;
      }
      // Otherwise source treats the turn as approximately 180 degrees and
      // continues into the normal branch selection below.
    } else if (sinA > 1.0) {
      sinA = 1.0;
    } else if (sinA < -1.0) {
      sinA = -1.0;
    }

    if (sinA * delta < 0) {
      output
        ..add(
          SourcePoint2(
            _clipperRound(point.x + previous.x * delta),
            _clipperRound(point.y + previous.y * delta),
          ),
        )
        ..add(point)
        ..add(
          SourcePoint2(
            _clipperRound(point.x + current.x * delta),
            _clipperRound(point.y + current.y * delta),
          ),
        );
      return;
    }

    final dot = current.x * previous.x + current.y * previous.y;
    final r = 1.0 + dot;
    final miterLimitThreshold = 2.0 / (miterLimit * miterLimit);
    if (r >= miterLimitThreshold) {
      _appendMiter(output, point, previous, current, delta, r);
    } else {
      _appendSquare(output, point, previous, current, sinA, delta);
    }
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
