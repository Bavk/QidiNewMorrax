import 'dart:typed_data';

import 'package:clipper2/clipper2.dart' as c2;

import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';

class SourceOverhangDistanceBoundary2 {
  const SourceOverhangDistanceBoundary2(this.first, this.second);

  final double first;
  final double second;
}

/// Source-compatible lower-layer support geometry used by classic perimeter
/// overhang detection.
///
/// This ports `PerimeterGenerator::generate_lower_polygons_series()` and
/// `dist_boundary()` at their source float boundaries. QIDI stores Flow width
/// and nozzle diameter as `float`, computes the two offset samples from those
/// float values, then casts `scale_(offset)` back to `float` before invoking
/// the Clipper1 polygon offset wrapper.
class SourceClassicOverhangSupport2 {
  const SourceClassicOverhangSupport2._();

  static const int overhangSamplingNumber = 6;
  static const double _clipperOffsetShortestEdgeFactor = 0.005;
  static const double _sourceMiterLimit = 3.0;

  /// Returns the two `float(scale_(offset_series[i]))` values that the source
  /// passes to `offset(Polygons, delta)`.
  static List<double> scaledLowerPolygonOffsets({
    required double width,
    required double nozzleDiameter,
  }) {
    final widthF = _f32(width);
    final nozzleF = _f32(nozzleDiameter);
    final startOffset = _f32(-0.5 * widthF);
    final endOffset = _f32(0.5 * nozzleF);
    final delta = _f32(endOffset - startOffset);

    // The expression contains the double literal `0.5`, then push_back casts
    // the result to float. Preserve both stages explicitly.
    final firstOffset = _f32(
      startOffset + 0.5 * delta / (overhangSamplingNumber - 1),
    );
    final firstScaled = _f32(firstOffset / Slic3rUnits.scalingFactor);
    final secondScaled = _f32(endOffset / Slic3rUnits.scalingFactor);
    return List.unmodifiable([firstScaled, secondScaled]);
  }

  /// Literal arithmetic shape of `PerimeterGenerator::dist_boundary()` for
  /// its actual callers (`Flow::width()` is a source float promoted to double).
  static SourceOverhangDistanceBoundary2 distBoundary({
    required double width,
    required double nozzleDiameter,
  }) {
    final widthF = _f32(width);
    final nozzleF = _f32(nozzleDiameter);
    final startOffset = _f32(-0.5 * widthF);
    final endOffset = _f32(0.5 * nozzleF);
    final delta = _f32(endOffset - startOffset);

    // Unlike generate_lower_polygons_series(), source does not store the first
    // sample in a float vector before scale_ here. The 0.5 expression remains
    // double through division by SCALING_FACTOR.
    final degree0 =
        (startOffset + 0.5 * delta / (overhangSamplingNumber - 1)) /
            Slic3rUnits.scalingFactor;
    final endScaled = endOffset / Slic3rUnits.scalingFactor;
    return SourceOverhangDistanceBoundary2(0, endScaled - degree0);
  }

  /// Port of `generate_lower_polygons_series(float width)` for the represented
  /// closed-polygon offset domain.
  ///
  /// A null lower-slice pointer produces an empty vector exactly like source.
  /// The source Clipper1 wrapper offsets each polygon independently, reverses
  /// the delta for clockwise holes, restores hole winding, and unions the raw
  /// results. The Dart port mirrors that structure in source integer units.
  static List<List<SourcePolygon2>> generateLowerPolygonsSeries({
    required double width,
    required double nozzleDiameter,
    required List<SourcePolygon2>? lowerSlices,
  }) {
    if (lowerSlices == null) return const [];
    final offsets = scaledLowerPolygonOffsets(
      width: width,
      nozzleDiameter: nozzleDiameter,
    );
    return List.unmodifiable([
      for (final delta in offsets) _offsetSourcePolygons(lowerSlices, delta),
    ]);
  }

  static List<SourcePolygon2> _offsetSourcePolygons(
    List<SourcePolygon2> polygons,
    double delta,
  ) {
    if (polygons.isEmpty) return const [];
    if (!delta.isFinite) {
      throw ArgumentError.value(delta, 'delta', 'must be finite');
    }

    final raw = <c2.Path64>[];
    final shortestEdgeLength =
        (delta * _clipperOffsetShortestEdgeFactor).abs();

    for (final polygon in polygons) {
      if (polygon.points.length < 3) continue;
      final originalCcw = !polygon.isClockwise;
      final prepared = _stripSourceOffsetShortEdges(
        polygon.points,
        shortestEdgeLength,
      );
      if (prepared.length < 3) continue;

      // Clipper1 raw_offset() runs one path at a time. Its AddPath/FixOrientations
      // normalizes a standalone closed polygon before Execute; for an original
      // clockwise hole QIDI flips the delta and reverses the result back.
      final normalized = originalCcw ? prepared : prepared.reversed.toList();
      final offsetter = c2.ClipperOffset(miterLimit: _sourceMiterLimit);
      offsetter.addPath(
        [for (final point in normalized) c2.Point64(point.x, point.y)],
        joinType: c2.JoinType.miter,
        endType: c2.EndType.polygon,
      );
      var paths = offsetter.execute(delta: originalCcw ? delta : -delta);
      if (!originalCcw) {
        paths = [for (final path in paths) path.reversed.toList()];
      }
      raw.addAll(paths);
    }

    if (raw.isEmpty) return const [];

    // QIDI expands with clipper_union(raw_offset(...)). For negative deltas
    // Clipper1 uses its historical outer-rectangle/negative-fill cleanup. The
    // normalized raw outer/hole winding above lets Clipper2 NonZero union yield
    // the same represented polygon set without a millimeter conversion.
    final unioned = c2.Clipper.union(
      subject: raw,
      fillRule: c2.FillRule.nonZero,
    );
    return List.unmodifiable([
      for (final path in unioned)
        if (path.length >= 3)
          SourcePolygon2([
            for (final point in path) SourcePoint2(point.x, point.y),
          ]),
    ]);
  }

  /// Exact point stripping performed by the QIDI-patched Clipper1
  /// `ClipperOffset::AddPath()` when `ShortestEdgeLength > 0`.
  static List<SourcePoint2> _stripSourceOffsetShortEdges(
    List<SourcePoint2> path,
    double shortestEdgeLength,
  ) {
    if (path.isEmpty) return const [];
    final threshold2 = shortestEdgeLength * shortestEdgeLength;
    var high = path.length - 1;
    while (high > 0 && _distanceSquared(path[high], path[0]) < threshold2) {
      high--;
    }

    final contour = <SourcePoint2>[path[0]];
    for (var i = 1; i <= high; i++) {
      if (_distanceSquared(path[i], contour.last) < threshold2) continue;
      contour.add(path[i]);
    }
    return contour;
  }

  static double _distanceSquared(SourcePoint2 a, SourcePoint2 b) {
    final dx = a.x.toDouble() - b.x.toDouble();
    final dy = a.y.toDouble() - b.y.toDouble();
    return dx * dx + dy * dy;
  }

  static double _f32(double value) {
    final storage = Float32List(1)..[0] = value;
    return storage[0];
  }
}
