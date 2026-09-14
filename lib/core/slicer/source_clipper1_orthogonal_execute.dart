import 'dart:math' as math;
import 'dart:typed_data';

import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';

/// Exact rectilinear subset of pinned Clipper 6.2.9
/// `ClipperOffset::Execute()`.
///
/// The historical offsetter builds mitered axis-aligned boundaries and then
/// runs a boolean union (`pftPositive` for positive offsets, an outer rectangle
/// plus `pftNegative` for negative offsets). For a simple positive orthogonal
/// contour, the cleaned geometry is exactly the L-infinity dilation/erosion of
/// the input. This helper evaluates that integer arrangement directly, while
/// preserving source `AddPath()` shortest-edge pruning, float32 delta and
/// half-away coordinate boundaries.
///
/// The represented subset accepts positive-contour results, including the
/// source case where negative cleanup splits one input contour into multiple
/// disconnected positive contours. Hole-producing/point-touch ambiguity and
/// cross-path union remain separate Clipper1 seams.
class SourceClipper1OrthogonalExecute2 {
  const SourceClipper1OrthogonalExecute2._();

  static const double shortestEdgeFactor = 0.005;

  /// Whether [polygon] can use the exact represented positive-contour executor.
  static bool supportsPositiveContours(
    SourcePolygon2 polygon,
    double delta,
  ) {
    final prepared = _prepareInput(polygon, delta);
    if (prepared == null) return false;
    final contours = _offsetContours(prepared.points, prepared.delta);
    return contours.isNotEmpty &&
        contours.every((polygon) => polygon.signedArea > 0);
  }

  /// Execute the represented orthogonal cleanup, preserving compiled Clipper1
  /// result order for disconnected positive contours.
  static List<SourcePolygon2> offsetPositiveContours(
    SourcePolygon2 polygon,
    double delta,
  ) {
    final prepared = _prepareInput(polygon, delta);
    if (prepared == null) {
      throw ArgumentError(
        'Pinned positive orthogonal Clipper1 Execute subset does not apply',
      );
    }
    final contours = _offsetContours(prepared.points, prepared.delta);
    if (contours.isEmpty ||
        contours.any((polygon) => polygon.signedArea <= 0)) {
      throw ArgumentError(
        'Pinned orthogonal Execute result is outside positive-contour subset',
      );
    }
    return contours;
  }

  /// Whether [polygon] can use the exact represented single-contour executor.
  static bool supportsSinglePositiveContour(
    SourcePolygon2 polygon,
    double delta,
  ) {
    final prepared = _prepareInput(polygon, delta);
    if (prepared == null) return false;
    final contours = _offsetContours(prepared.points, prepared.delta);
    return contours.length == 1 && contours.single.signedArea > 0;
  }

  /// Execute the represented exact orthogonal cleanup when it stays connected.
  static SourcePolygon2 offsetSinglePositiveContour(
    SourcePolygon2 polygon,
    double delta,
  ) {
    final contours = offsetPositiveContours(polygon, delta);
    if (contours.length != 1) {
      throw ArgumentError(
        'Pinned orthogonal Execute result is not one positive contour',
      );
    }
    return contours.single;
  }

  static _PreparedOrthogonalInput2? _prepareInput(
    SourcePolygon2 polygon,
    double delta,
  ) {
    if (polygon.signedArea <= 0) return null;
    final sourceDelta = _f32(delta);
    if (!sourceDelta.isFinite || sourceDelta == 0) return null;
    // Arachne offsets reach Clipper1 in integer source units. Keeping this
    // boundary explicit avoids claiming parity for sub-coordinate level sets
    // before their source rounding has an independent oracle.
    if (sourceDelta != sourceDelta.truncateToDouble()) return null;

    final points = _prepareClosedPath(polygon.points, sourceDelta);
    if (points.length < 4 || !_isSimpleOrthogonal(points)) return null;
    return _PreparedOrthogonalInput2(points, sourceDelta.truncate());
  }

  static List<SourcePolygon2> _offsetContours(
    List<SourcePoint2> points,
    int delta,
  ) {
    final radius = delta.abs();
    final xs = <int>{};
    final ys = <int>{};
    for (final point in points) {
      xs
        ..add(point.x - radius)
        ..add(point.x)
        ..add(point.x + radius);
      ys
        ..add(point.y - radius)
        ..add(point.y)
        ..add(point.y + radius);
    }
    final xValues = xs.toList()..sort();
    final yValues = ys.toList()..sort();
    if (xValues.length < 2 || yValues.length < 2) {
      return const <SourcePolygon2>[];
    }

    final width = xValues.length - 1;
    final height = yValues.length - 1;
    final filled = List<List<bool>>.generate(
      width,
      (_) => List<bool>.filled(height, false),
      growable: false,
    );

    for (var xIndex = 0; xIndex < width; xIndex++) {
      final x = (xValues[xIndex] + xValues[xIndex + 1]) / 2.0;
      for (var yIndex = 0; yIndex < height; yIndex++) {
        final y = (yValues[yIndex] + yValues[yIndex + 1]) / 2.0;
        final inside = _contains(points, x, y);
        final distance = _chebyshevDistanceToBoundary(points, x, y);
        filled[xIndex][yIndex] = delta > 0
            ? inside || distance <= radius
            : inside && distance >= radius;
      }
    }

    final edges = <_DirectedEdge2>[];
    for (var xIndex = 0; xIndex < width; xIndex++) {
      for (var yIndex = 0; yIndex < height; yIndex++) {
        if (!filled[xIndex][yIndex]) continue;
        final x0 = xValues[xIndex];
        final x1 = xValues[xIndex + 1];
        final y0 = yValues[yIndex];
        final y1 = yValues[yIndex + 1];

        if (yIndex == 0 || !filled[xIndex][yIndex - 1]) {
          edges.add(
            _DirectedEdge2(SourcePoint2(x0, y0), SourcePoint2(x1, y0)),
          );
        }
        if (xIndex == width - 1 || !filled[xIndex + 1][yIndex]) {
          edges.add(
            _DirectedEdge2(SourcePoint2(x1, y0), SourcePoint2(x1, y1)),
          );
        }
        if (yIndex == height - 1 || !filled[xIndex][yIndex + 1]) {
          edges.add(
            _DirectedEdge2(SourcePoint2(x1, y1), SourcePoint2(x0, y1)),
          );
        }
        if (xIndex == 0 || !filled[xIndex - 1][yIndex]) {
          edges.add(
            _DirectedEdge2(SourcePoint2(x0, y1), SourcePoint2(x0, y0)),
          );
        }
      }
    }
    if (edges.isEmpty) return const <SourcePolygon2>[];

    final byStart = <String, List<_DirectedEdge2>>{};
    for (final edge in edges) {
      byStart.putIfAbsent(_key(edge.start), () => <_DirectedEdge2>[]).add(edge);
    }
    // A diagonal point-touch creates more than one outgoing contour edge. That
    // ordering is owned by the full Clipper1 boolean executor and is therefore
    // kept outside this exact subset.
    if (byStart.values.any((value) => value.length != 1)) {
      return const <SourcePolygon2>[];
    }

    final unused = <String, _DirectedEdge2>{
      for (final edge in edges) _edgeKey(edge): edge,
    };
    final contours = <SourcePolygon2>[];
    while (unused.isNotEmpty) {
      final first = unused.values.first;
      final start = first.start;
      var edge = first;
      final loop = <SourcePoint2>[];

      while (true) {
        final edgeId = _edgeKey(edge);
        if (unused.remove(edgeId) == null) {
          return const <SourcePolygon2>[];
        }
        loop.add(edge.start);
        if (edge.end == start) break;
        final next = byStart[_key(edge.end)];
        if (next == null || next.length != 1) {
          return const <SourcePolygon2>[];
        }
        edge = next.single;
        if (loop.length > edges.length) {
          return const <SourcePolygon2>[];
        }
      }

      var simplified = _removeCollinear(loop);
      if (simplified.length < 3) continue;
      var polygon = SourcePolygon2(simplified);
      if (polygon.signedArea < 0) {
        simplified = simplified.reversed.toList(growable: false);
        polygon = SourcePolygon2(simplified);
      }
      contours.add(SourcePolygon2(_rotateToClipperStart(polygon.points)));
    }

    // Do not sort: the pinned Clipper1 multi-result oracle for a split
    // orthogonal dumbbell returns the left component before the right component.
    // The x-major/y-major arrangement scan above reproduces that source order.
    return List<SourcePolygon2>.unmodifiable(contours);
  }

  static bool _contains(List<SourcePoint2> points, double x, double y) {
    var inside = false;
    var previous = points.last;
    for (final current in points) {
      if ((current.y > y) != (previous.y > y)) {
        final crossingX = current.x +
            (y - current.y) *
                (previous.x - current.x) /
                (previous.y - current.y);
        if (x < crossingX) inside = !inside;
      }
      previous = current;
    }
    return inside;
  }

  static double _chebyshevDistanceToBoundary(
    List<SourcePoint2> points,
    double x,
    double y,
  ) {
    var minimum = double.infinity;
    for (var index = 0; index < points.length; index++) {
      final first = points[index];
      final second = points[(index + 1) % points.length];
      double dx;
      double dy;
      if (first.x == second.x) {
        dx = (x - first.x).abs();
        final minY = math.min(first.y, second.y).toDouble();
        final maxY = math.max(first.y, second.y).toDouble();
        dy = y < minY
            ? minY - y
            : y > maxY
                ? y - maxY
                : 0.0;
      } else {
        dy = (y - first.y).abs();
        final minX = math.min(first.x, second.x).toDouble();
        final maxX = math.max(first.x, second.x).toDouble();
        dx = x < minX
            ? minX - x
            : x > maxX
                ? x - maxX
                : 0.0;
      }
      minimum = math.min(minimum, math.max(dx, dy));
    }
    return minimum;
  }

  static bool _isSimpleOrthogonal(List<SourcePoint2> points) {
    if (points.length < 4) return false;
    for (var index = 0; index < points.length; index++) {
      final first = points[index];
      final second = points[(index + 1) % points.length];
      if (first == second || (first.x != second.x && first.y != second.y)) {
        return false;
      }
    }

    final count = points.length;
    for (var firstIndex = 0; firstIndex < count; firstIndex++) {
      final firstNext = (firstIndex + 1) % count;
      for (var secondIndex = firstIndex + 1;
          secondIndex < count;
          secondIndex++) {
        final secondNext = (secondIndex + 1) % count;
        if (secondIndex == firstNext || secondNext == firstIndex) continue;
        if (_segmentsIntersect(
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

  static bool _segmentsIntersect(
    SourcePoint2 a0,
    SourcePoint2 a1,
    SourcePoint2 b0,
    SourcePoint2 b1,
  ) {
    final aVertical = a0.x == a1.x;
    final bVertical = b0.x == b1.x;
    if (aVertical && bVertical) {
      if (a0.x != b0.x) return false;
      final aMin = math.min(a0.y, a1.y);
      final aMax = math.max(a0.y, a1.y);
      final bMin = math.min(b0.y, b1.y);
      final bMax = math.max(b0.y, b1.y);
      return math.max(aMin, bMin) <= math.min(aMax, bMax);
    }
    if (!aVertical && !bVertical) {
      if (a0.y != b0.y) return false;
      final aMin = math.min(a0.x, a1.x);
      final aMax = math.max(a0.x, a1.x);
      final bMin = math.min(b0.x, b1.x);
      final bMax = math.max(b0.x, b1.x);
      return math.max(aMin, bMin) <= math.min(aMax, bMax);
    }

    final vertical0 = aVertical ? a0 : b0;
    final vertical1 = aVertical ? a1 : b1;
    final horizontal0 = aVertical ? b0 : a0;
    final horizontal1 = aVertical ? b1 : a1;
    final minVerticalY = math.min(vertical0.y, vertical1.y);
    final maxVerticalY = math.max(vertical0.y, vertical1.y);
    final minHorizontalX = math.min(horizontal0.x, horizontal1.x);
    final maxHorizontalX = math.max(horizontal0.x, horizontal1.x);
    return vertical0.x >= minHorizontalX &&
        vertical0.x <= maxHorizontalX &&
        horizontal0.y >= minVerticalY &&
        horizontal0.y <= maxVerticalY;
  }

  static List<SourcePoint2> _removeCollinear(List<SourcePoint2> input) {
    var points = List<SourcePoint2>.of(input);
    var changed = true;
    while (changed && points.length >= 3) {
      changed = false;
      final next = <SourcePoint2>[];
      for (var index = 0; index < points.length; index++) {
        final previous = points[(index - 1 + points.length) % points.length];
        final point = points[index];
        final following = points[(index + 1) % points.length];
        if ((previous.x == point.x && point.x == following.x) ||
            (previous.y == point.y && point.y == following.y)) {
          changed = true;
          continue;
        }
        next.add(point);
      }
      points = next;
    }
    return points;
  }

  static List<SourcePoint2> _rotateToClipperStart(List<SourcePoint2> points) {
    if (points.isEmpty) return const <SourcePoint2>[];
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

  static List<SourcePoint2> _prepareClosedPath(
    List<SourcePoint2> input,
    double sourceDelta,
  ) {
    if (input.isEmpty) return const <SourcePoint2>[];
    final shortest = (sourceDelta * shortestEdgeFactor).abs();
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
      if (!same(input[index], result.last)) result.add(input[index]);
    }
    return result;
  }

  static String _key(SourcePoint2 point) => '${point.x},${point.y}';

  static String _edgeKey(_DirectedEdge2 edge) =>
      '${_key(edge.start)}>${_key(edge.end)}';

  static double _f32(double value) {
    final slot = Float32List(1)..[0] = value;
    return slot[0];
  }
}

class _PreparedOrthogonalInput2 {
  const _PreparedOrthogonalInput2(this.points, this.delta);

  final List<SourcePoint2> points;
  final int delta;
}

class _DirectedEdge2 {
  const _DirectedEdge2(this.start, this.end);

  final SourcePoint2 start;
  final SourcePoint2 end;
}
