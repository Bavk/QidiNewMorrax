import 'point.dart';

class ThickLine2 {
  const ThickLine2({
    required this.a,
    required this.b,
    required this.aWidth,
    required this.bWidth,
  });

  final Point2 a;
  final Point2 b;
  final double aWidth;
  final double bWidth;
}

/// Pure-Dart counterpart of `Slic3r::ThickPolyline` from `Polyline.hpp/.cpp`.
///
/// Source invariant: for N points (N >= 2), `width.length == 2 * N - 2`.
/// Each segment i stores its start/end width at indexes `2*i` and `2*i+1`.
class ThickPolyline2 {
  ThickPolyline2({
    Iterable<Point2> points = const [],
    Iterable<double> width = const [],
    this.startIsEndpoint = false,
    this.endIsEndpoint = false,
  })  : points = List<Point2>.of(points),
        width = List<double>.of(width) {
    _assertInvariant(allowEmpty: true);
  }

  final List<Point2> points;
  final List<double> width;
  bool startIsEndpoint;
  bool endIsEndpoint;

  bool get isEmpty => points.isEmpty;
  bool get isClosed =>
      points.length >= 2 && _samePoint(points.first, points.last);
  Point2 get firstPoint => points.first;
  Point2 get lastPoint => points.last;

  double get length {
    var result = 0.0;
    for (var i = 0; i + 1 < points.length; i++) {
      result += points[i].distanceTo(points[i + 1]);
    }
    return result;
  }

  List<ThickLine2> thickLines() {
    _assertInvariant();
    if (points.length < 2) return const [];
    return List<ThickLine2>.generate(
      points.length - 1,
      (i) => ThickLine2(
        a: points[i],
        b: points[i + 1],
        aWidth: width[2 * i],
        bWidth: width[2 * i + 1],
      ),
      growable: false,
    );
  }

  /// Exact `ThickPolyline::reverse()` semantics: reverse points and the whole
  /// per-segment endpoint width vector, then swap endpoint flags.
  void reverse() {
    points.setAll(0, points.reversed.toList(growable: false));
    width.setAll(0, width.reversed.toList(growable: false));
    final oldStart = startIsEndpoint;
    startIsEndpoint = endIsEndpoint;
    endIsEndpoint = oldStart;
    _assertInvariant(allowEmpty: true);
  }

  void clear() {
    points.clear();
    width.clear();
  }

  /// Exact port of `ThickPolyline::rebase_at(size_t idx)`.
  /// Returns an empty polyline when the source polyline is not closed.
  ThickPolyline2 rebaseAt(int idx) {
    _assertInvariant();
    if (!isClosed) return ThickPolyline2();
    if (idx < 0) throw RangeError.index(idx, points, 'idx');

    final n = points.length;
    final uniqueCount = n - 1;
    final normalizedIdx = idx % uniqueCount;

    final rebasedPoints = List<Point2>.filled(n, points.first);
    for (var j = 0; j < n - 1; j++) {
      rebasedPoints[j] = points[(normalizedIdx + j) % uniqueCount];
    }
    rebasedPoints[n - 1] = rebasedPoints.first;

    double getInWidth(int i) {
      if (i == 0) return width[0];
      if (i == n - 1) return width.last;
      return width[2 * i - 1];
    }

    double getOutWidth(int i) {
      if (i == 0) return width[0];
      if (i == n - 1) return width.last;
      return width[2 * i];
    }

    final rebasedWidth = List<double>.filled(2 * n - 2, 0);
    rebasedWidth[0] = getOutWidth(normalizedIdx);
    for (var j = 1; j < n - 1; j++) {
      final i = (normalizedIdx + j) % uniqueCount;
      rebasedWidth[2 * j - 1] = getInWidth(i);
      rebasedWidth[2 * j] = getOutWidth(i);
    }
    rebasedWidth[2 * n - 3] = rebasedWidth.first;

    return ThickPolyline2(
      points: rebasedPoints,
      width: rebasedWidth,
      startIsEndpoint: startIsEndpoint,
      endIsEndpoint: endIsEndpoint,
    );
  }

  /// Exact source indexing from `ThickPolyline::get_width_at()`.
  double getWidthAt(int pointIndex) {
    _assertInvariant();
    if (pointIndex < 0 || pointIndex >= points.length) {
      throw RangeError.index(pointIndex, points, 'pointIndex');
    }
    if (pointIndex < 2) return width[pointIndex];
    return width[2 * pointIndex - 1];
  }

  void appendContinuation(ThickPolyline2 other) {
    _assertInvariant();
    other._assertInvariant();
    if (other.points.isEmpty) return;
    if (points.isEmpty) {
      points.addAll(other.points);
      width.addAll(other.width);
      startIsEndpoint = other.startIsEndpoint;
      endIsEndpoint = other.endIsEndpoint;
      return;
    }
    if (!_samePoint(lastPoint, other.firstPoint)) {
      throw ArgumentError(
        'ThickPolyline continuation must start at the current last point',
      );
    }
    points.addAll(other.points.skip(1));
    width.addAll(other.width);
    endIsEndpoint = other.endIsEndpoint;
    _assertInvariant();
  }

  void _assertInvariant({bool allowEmpty = false}) {
    if (points.isEmpty && allowEmpty) {
      if (width.isNotEmpty) {
        throw StateError('Empty ThickPolyline must have empty width data');
      }
      return;
    }
    if (points.length < 2) {
      throw StateError('ThickPolyline requires at least two points');
    }
    final expected = 2 * points.length - 2;
    if (width.length != expected) {
      throw StateError(
        'ThickPolyline width invariant violated: expected $expected, '
        'got ${width.length}',
      );
    }
  }

  static bool _samePoint(Point2 a, Point2 b) => a.x == b.x && a.y == b.y;
}
