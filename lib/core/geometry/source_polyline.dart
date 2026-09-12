import 'dart:math' as math;

import 'source_geometry.dart';

/// Integer-coordinate `Polyline` subset ported from `Polyline.hpp/.cpp`.
///
/// The supplied source stores optional QIDI arc-fitting metadata alongside the
/// point vector. This class currently ports the exact linear-point behavior
/// used by `ExtrusionEntity`; arc fitting remains a separately tracked source
/// unit and is never silently approximated.
class SourcePolyline2 {
  SourcePolyline2([Iterable<SourcePoint2> points = const []])
      : points = <SourcePoint2>[] {
    for (final point in points) {
      append(point);
    }
  }

  final List<SourcePoint2> points;

  int get lengthInPoints => points.length;
  bool get isEmpty => points.isEmpty;
  bool get isValid => points.length >= 2;
  bool get isClosed => points.isNotEmpty && points.first == points.last;
  SourcePoint2 get firstPoint => points.first;
  SourcePoint2 get lastPoint => points.last;

  void append(SourcePoint2 point) {
    // QIDI Polyline::append intentionally does not append an identical
    // consecutive endpoint.
    if (points.isNotEmpty && points.last == point) return;
    points.add(point);
  }

  void appendPoints(Iterable<SourcePoint2> source) {
    for (final point in source) {
      append(point);
    }
  }

  void appendPolyline(SourcePolyline2 source) => appendPoints(source.points);

  void reverse() => points.setAll(0, points.reversed.toList(growable: false));

  void clear() => points.clear();

  double get length {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += (points[i] - points[i - 1]).length;
    }
    return total;
  }

  List<SourceLine2> lines() {
    if (points.length < 2) return const [];
    return List<SourceLine2>.generate(
      points.length - 1,
      (i) => SourceLine2(points[i], points[i + 1]),
      growable: false,
    );
  }

  /// Exact linear-point behavior of `Polyline::clip_end()`.
  ///
  /// Source uses Eigen `cast<coord_t>()` for the inserted endpoint; Dart's
  /// `truncate()` reproduces that integer cast. QIDI arc fitting metadata is a
  /// separate pending unit, so this method refuses an arc-aware mode rather
  /// than pretending that metadata was updated.
  void clipEnd(double distance) {
    if (distance <= 0 || points.isEmpty) return;

    while (distance > 0) {
      final last = points.last;
      points.removeLast();
      if (points.isEmpty) return;

      final current = points.last;
      final dx = current.x - last.x;
      final dy = current.y - last.y;
      final lengthSquared = dx.toDouble() * dx + dy.toDouble() * dy;
      if (lengthSquared > distance * distance) {
        final segmentLength = math.sqrt(lengthSquared);
        final ratio = distance / segmentLength;
        points.add(SourcePoint2(
          (last.x + dx * ratio).truncate(),
          (last.y + dy * ratio).truncate(),
        ));
        break;
      }
      distance -= math.sqrt(lengthSquared);
    }
  }

  void clipStart(double distance) {
    reverse();
    clipEnd(distance);
    if (points.length >= 2) reverse();
  }

  /// QIDI source extension casts the normalized-vector displacement to
  /// `coord_t` before adding it to the endpoint.
  void extendEnd(double distance) {
    if (points.length < 2) {
      throw StateError('Polyline::extend_end requires at least two points');
    }
    final vector = points.last - points[points.length - 2];
    final norm = vector.length;
    if (norm == 0) return;
    final offset = SourcePoint2(
      (vector.x / norm * distance).truncate(),
      (vector.y / norm * distance).truncate(),
    );
    append(points.last + offset);
  }

  void extendStart(double distance) {
    reverse();
    extendEnd(distance);
    reverse();
  }

  SourcePolyline2 copy() => SourcePolyline2(points);

  /// Arc fitting (`PathFittingData`, ArcFitter and fitting-result mutation in
  /// reverse/clip/split) is mandatory for final parity but not yet ported.
  Never simplifyByFittingArc(double tolerance) => throw UnsupportedError(
        'Polyline::simplify_by_fitting_arc requires the source ArcFitter and '
        'PathFittingData port; no linear approximation is accepted.',
      );
}
