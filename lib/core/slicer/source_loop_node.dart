import '../geometry/source_geometry.dart';

/// Source `NodeContour` used by QIDI's vertical outer-wall speed continuity
/// metadata.
class SourceNodeContour2 {
  SourceNodeContour2({
    required Iterable<SourcePoint2> points,
    required Iterable<int> widths,
    required this.isLoop,
  })  : points = List.unmodifiable(points),
        widths = List.unmodifiable(widths);

  final List<SourcePoint2> points;
  final List<int> widths;
  final bool isLoop;
}

/// Integer source bounding box after the literal `offset(SCALED_EPSILON)` used
/// when a classic `LoopNode` is emitted.
class SourceLoopNodeBounds2 {
  const SourceLoopNodeBounds2({required this.min, required this.max});

  final SourcePoint2 min;
  final SourcePoint2 max;

  factory SourceLoopNodeBounds2.fromPoints(
    Iterable<SourcePoint2> sourcePoints, {
    int offset = Slic3rUnits.scaledEpsilon,
  }) {
    final points = sourcePoints.toList(growable: false);
    if (points.isEmpty) {
      throw ArgumentError('source LoopNode contour must not be empty');
    }
    var minX = points.first.x;
    var minY = points.first.y;
    var maxX = minX;
    var maxY = minY;
    for (final point in points.skip(1)) {
      if (point.x < minX) minX = point.x;
      if (point.y < minY) minY = point.y;
      if (point.x > maxX) maxX = point.x;
      if (point.y > maxY) maxY = point.y;
    }
    return SourceLoopNodeBounds2(
      min: SourcePoint2(minX - offset, minY - offset),
      max: SourcePoint2(maxX + offset, maxY + offset),
    );
  }
}

/// Source `LoopNode` subset consumed by layer-to-layer outer-wall continuity.
class SourceLoopNode2 {
  SourceLoopNode2({
    required this.nodeContour,
    required this.nodeId,
    this.loopId = 0,
    required this.bounds,
    this.mergedId = -1,
    Iterable<int> upperNodeIds = const [],
    Iterable<int> lowerNodeIds = const [],
  })  : upperNodeIds = List<int>.of(upperNodeIds),
        lowerNodeIds = List<int>.of(lowerNodeIds);

  final SourceNodeContour2 nodeContour;
  final int nodeId;
  final int loopId;
  final SourceLoopNodeBounds2 bounds;
  int mergedId;
  final List<int> upperNodeIds;
  final List<int> lowerNodeIds;
}

/// Literal port of `Point::is_in_lines(const Points&)` from pinned `Point.cpp`.
class SourceLoopNodeGeometry2 {
  const SourceLoopNodeGeometry2._();

  static bool pointIsInLines(
    SourcePoint2 checkPoint,
    List<SourcePoint2> points,
  ) {
    for (var pointIndex = 1; pointIndex < points.length; pointIndex++) {
      final point = points[pointIndex];
      final previous = points[pointIndex - 1];

      if (checkPoint == point || checkPoint == previous) return true;

      final inXRange = !((checkPoint.x > point.x) ==
          (checkPoint.x > previous.x));
      final inYRange = !((checkPoint.y > point.y) ==
          (checkPoint.y > previous.y));

      if (point.x == previous.x) {
        if (inYRange && point.x == checkPoint.x) return true;
        continue;
      }
      if (point.y == previous.y) {
        if (inXRange && point.y == checkPoint.y) return true;
        continue;
      }
      if (!inXRange || !inYRange) continue;

      final distance = SourceLine2(previous, point).distanceTo(checkPoint);
      if (distance.abs() < Slic3rUnits.scaledEpsilon) return true;
    }
    return false;
  }
}
