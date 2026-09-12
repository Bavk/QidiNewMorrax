import 'dart:math' as math;

import 'source_geometry.dart';
import 'voronoi_topology.dart';

class SourceSegmentCellRange2 {
  const SourceSegmentCellRange2({
    required this.segmentStartPoint,
    required this.segmentEndPoint,
    this.edgeBeginId,
    this.edgeEndId,
  });

  /// Source `compute_segment_cell_range()` intentionally constructs the range
  /// with `(to, from)` for these two fields.
  final SourcePoint2 segmentStartPoint;
  final SourcePoint2 segmentEndPoint;
  final int? edgeBeginId;
  final int? edgeEndId;

  bool get isValid =>
      edgeBeginId != null && edgeEndId != null && edgeBeginId != edgeEndId;
}

/// Port of the source helpers in `Geometry/VoronoiUtils.cpp` required by
/// MedialAxis construction and Voronoi issue detection/repair.
class SourceVoronoiUtils2 {
  const SourceVoronoiUtils2._();

  static BoundarySegment2 getSourceSegment(
    VoronoiCell2 cell,
    List<BoundarySegment2> segments,
  ) {
    if (!cell.containsSegment) {
      throw ArgumentError('Voronoi cell does not contain a source segment');
    }
    if (cell.sourceIndex < 0 || cell.sourceIndex >= segments.length) {
      throw RangeError.index(cell.sourceIndex, segments, 'sourceIndex');
    }
    return segments[cell.sourceIndex];
  }

  static SourcePoint2 getSourcePoint(
    VoronoiCell2 cell,
    List<BoundarySegment2> segments,
  ) {
    if (!cell.containsPoint) {
      throw ArgumentError('Voronoi cell does not contain a source point');
    }
    if (cell.sourceIndex < 0 || cell.sourceIndex >= segments.length) {
      throw RangeError.index(cell.sourceIndex, segments, 'sourceIndex');
    }
    final segment = segments[cell.sourceIndex];
    switch (cell.sourceCategory) {
      case VoronoiSourceCategory.segmentStartPoint:
        return segment.a;
      case VoronoiSourceCategory.segmentEndPoint:
        return segment.b;
      case VoronoiSourceCategory.segment:
        throw ArgumentError('Segment category is not a point site');
    }
  }

  /// Source `VoronoiUtils::to_point()` uses `std::llround`, i.e. nearest with
  /// halfway cases away from zero (different from the `lrint` conversion used
  /// by the older MedialAxis code path).
  static SourcePoint2 toPoint(VoronoiPoint2 point) {
    if (!isFinitePoint(point)) {
      throw ArgumentError('Voronoi vertex must be finite');
    }
    return SourcePoint2(_llround(point.x), _llround(point.y));
  }

  static bool isFinitePoint(VoronoiPoint2 point) =>
      point.x.isFinite && point.y.isFinite;

  static VoronoiVertex2 makeRotatedVertex(
    VoronoiVertex2 vertex,
    double angle,
  ) {
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    final x = cosA * vertex.point.x - sinA * vertex.point.y;
    final y = cosA * vertex.point.y + sinA * vertex.point.x;
    return VoronoiVertex2(
      point: VoronoiPoint2(x, y),
      incidentEdgeId: vertex.incidentEdgeId,
      category: vertex.category,
    );
  }

  /// Literal translation of `VoronoiUtils::compute_segment_cell_range()`.
  static SourceSegmentCellRange2 computeSegmentCellRange(
    VoronoiTopology2 topology,
    int cellIndex,
    List<BoundarySegment2> segments,
  ) {
    final cell = topology.cell(cellIndex);
    final source = getSourceSegment(cell, segments);
    final from = source.a;
    final to = source.b;

    var edgeBeginId = null as int?;
    var edgeEndId = null as int?;
    var seenPossibleStart = false;
    var afterStart = false;
    var endingEdgeIsSetBeforeStart = false;

    for (final edge in topology.orderedEdgesForCell(cellIndex)) {
      if (edge.infinite) continue;
      final v0 = toPoint(topology.vertex(edge.vertex0!).point);
      final v1 = toPoint(topology.vertex(edge.vertex1!).point);
      if (v0 == to && v1 == from) {
        throw StateError(
          'Source Segment-cell edge may not run directly from to -> from',
        );
      }

      if (v0 == to && !afterStart) {
        // Source deliberately keeps the last candidate starting at `to`.
        edgeBeginId = edge.id;
        seenPossibleStart = true;
      } else if (seenPossibleStart) {
        afterStart = true;
      }

      if (v1 == from &&
          (edgeEndId == null || endingEdgeIsSetBeforeStart)) {
        endingEdgeIsSetBeforeStart = !afterStart;
        edgeEndId = edge.id;
      }
    }

    return SourceSegmentCellRange2(
      segmentStartPoint: to,
      segmentEndPoint: from,
      edgeBeginId: edgeBeginId,
      edgeEndId: edgeEndId,
    );
  }

  static int _llround(double value) =>
      value >= 0 ? (value + 0.5).floor() : (value - 0.5).ceil();
}
