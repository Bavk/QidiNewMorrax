import 'dart:math' as math;

import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import '../geometry/thick_polyline.dart';
import 'source_arachne_extrusion_line.dart';

/// Remaining pinned `Arachne::ExtrusionLine` helpers consumed by
/// `PerimeterGenerator::traverse_extrusions()`.
extension SourceArachneExtrusionLineVariableWidth2
    on SourceArachneExtrusionLine2 {
  /// Direct `Arachne::to_thick_polyline(const ExtrusionLine&)`.
  ThickPolyline2 toThickPolylineSource() {
    if (junctions.length < 2) {
      throw StateError('Pinned to_thick_polyline requires at least 2 junctions');
    }

    final points = <SourcePoint2>[];
    final widths = <double>[];
    points.add(junctions[0].p);
    widths.add(junctions[0].w.toDouble());
    points.add(junctions[1].p);
    widths.add(junctions[1].w.toDouble());

    var previous = junctions[1];
    for (var index = 2; index < junctions.length; index++) {
      final current = junctions[index];
      points.add(current.p);
      widths
        ..add(previous.w.toDouble())
        ..add(current.w.toDouble());
      previous = current;
    }

    return ThickPolyline2(
      points: points,
      width: widths,
      startIsEndpoint: true,
      endIsEndpoint: true,
    );
  }

  /// Direct `ExtrusionLine::shouldApplyHoleCompensation()`.
  bool shouldApplyHoleCompensationSource({double threshold = 0.8}) {
    var totalLength = 0;
    var markedLength = 0;
    for (var index = 1; index < junctions.length; index++) {
      final vector = junctions[index].p - junctions[index - 1].p;
      final length = math.sqrt(vector.squaredLength.toDouble()).truncate();
      totalLength += length;
      final markedRate =
          (junctions[index].holeCompensationFlag ? 1 : 0) +
              (junctions[index - 1].holeCompensationFlag ? 1 : 0);
      markedLength += (length * markedRate) ~/ 2;
    }
    final rate = markedLength.toDouble() / totalLength.toDouble();
    return rate > threshold;
  }

  /// Direct `ExtrusionLine::is_contour()`.
  bool isContourSource() {
    if (!isClosed) return false;
    return SourcePolygon2([
      for (final junction in junctions) junction.p,
    ]).isClockwise;
  }
}
