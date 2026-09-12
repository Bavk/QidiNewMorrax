import 'dart:math' as math;
import 'dart:typed_data';

import '../geometry/source_voronoi_utils.dart';
import '../geometry/voronoi_topology.dart';
import 'source_arachne_polygon_indices.dart';

/// Literal branch port of pinned `SkeletalTrapezoidation::discretize()` plus
/// its `VoronoiUtils::discretize_parabola()` dependency.
class SourceArachneVoronoiDiscretize2 {
  const SourceArachneVoronoiDiscretize2._();

  static List<SourcePoint2> discretize(
    VoronoiTopology2 topology,
    int edgeId,
    SourceArachnePolygonSegments2 sourceSegments, {
    required int discretizationStepSize,
    required double transitioningAngle,
  }) {
    if (discretizationStepSize <= 0) {
      throw ArgumentError.value(
        discretizationStepSize,
        'discretizationStepSize',
      );
    }
    final edge = topology.edge(edgeId);
    final twin = topology.edge(edge.twinId);
    if (!_edgeFitsCoord(topology, edge)) {
      throw StateError('Pinned discretize edge is outside coord_t range');
    }

    final leftCell = topology.cell(edge.cellIndex);
    final rightCell = topology.cell(twin.cellIndex);
    final start = _coordPoint(topology, edge.vertex0!);
    final end = _coordPoint(topology, edge.vertex1!);
    final pointLeft = leftCell.containsPoint;
    final pointRight = rightCell.containsPoint;

    if ((!pointLeft && !pointRight) || edge.secondary) {
      return [start, end];
    }

    if (pointLeft != pointRight) {
      final pointCell = pointLeft ? leftCell : rightCell;
      final segmentCell = pointLeft ? rightCell : leftCell;
      final sourcePoint = SourceVoronoiUtils2.getSourcePoint(
        pointCell,
        sourceSegments.boundarySegments,
      );
      final sourceSegment = SourceVoronoiUtils2.getSourceSegment(
        segmentCell,
        sourceSegments.boundarySegments,
      );
      return _discretizeParabola(
        sourcePoint,
        sourceSegment,
        start,
        end,
        discretizationStepSize,
        _f32(transitioningAngle),
      );
    }

    final leftPoint = SourceVoronoiUtils2.getSourcePoint(
      leftCell,
      sourceSegments.boundarySegments,
    );
    final rightPoint = SourceVoronoiUtils2.getSourcePoint(
      rightCell,
      sourceSegments.boundarySegments,
    );
    return _discretizePointPoint(
      start,
      end,
      leftPoint,
      rightPoint,
      discretizationStepSize,
      transitioningAngle,
    );
  }
}

List<SourcePoint2> _discretizePointPoint(
  SourcePoint2 start,
  SourcePoint2 end,
  SourcePoint2 leftPoint,
  SourcePoint2 rightPoint,
  int discretizationStepSize,
  double transitioningAngle,
) {
  final sourceDelta = rightPoint - leftPoint;
  final distance = _coordNorm(sourceDelta);
  final middle = SourcePoint2(
    (leftPoint.x + rightPoint.x) ~/ 2,
    (leftPoint.y + rightPoint.y) ~/ 2,
  );
  final xAxisDirection = SourcePoint2(-sourceDelta.y, sourceDelta.x);
  final xAxisLength = _coordNorm(xAxisDirection);
  if (xAxisLength == 0) {
    throw StateError('Pinned point-point Voronoi sites coincide');
  }

  int projectedX(SourcePoint2 from) {
    final vector = from - middle;
    return (vector.x * xAxisDirection.x + vector.y * xAxisDirection.y) ~/
        xAxisLength;
  }

  final startX = projectedX(start);
  final endX = projectedX(end);

  final bound = _f32(0.5 / math.tan((math.pi - transitioningAngle) * 0.5));
  var markingStartX = _f32(_f32(-distance.toDouble()) * bound).truncate();
  var markingEndX = _f32(_f32(distance.toDouble()) * bound).truncate();

  SourcePoint2 markingPoint(int x) => SourcePoint2(
        middle.x + xAxisDirection.x * x ~/ xAxisLength,
        middle.y + xAxisDirection.y * x ~/ xAxisLength,
      );

  var markingStart = markingPoint(markingStartX);
  var markingEnd = markingPoint(markingEndX);
  var direction = 1;
  if (startX > endX) {
    direction = -1;
    final pointSwap = markingStart;
    markingStart = markingEnd;
    markingEnd = pointSwap;
    final xSwap = markingStartX;
    markingStartX = markingEndX;
    markingEndX = xSwap;
  }

  final result = <SourcePoint2>[start];
  var addMarkingStart = markingStartX * direction > startX * direction;
  var addMarkingEnd = markingEndX * direction > startX * direction;

  final ab = end - start;
  final abSize = _coordNorm(ab);
  var stepCount =
      (abSize + discretizationStepSize ~/ 2) ~/ discretizationStepSize;
  if (stepCount.isOdd) {
    stepCount++;
  }

  for (var step = 1; step < stepCount; step++) {
    final here = SourcePoint2(
      start.x + ab.x * step ~/ stepCount,
      start.y + ab.y * step ~/ stepCount,
    );
    final xHere = projectedX(here);
    if (addMarkingStart &&
        markingStartX * direction < xHere * direction) {
      result.add(markingStart);
      addMarkingStart = false;
    }
    if (addMarkingEnd && markingEndX * direction < xHere * direction) {
      result.add(markingEnd);
      addMarkingEnd = false;
    }
    result.add(here);
  }

  if (addMarkingEnd && markingEndX * direction < endX * direction) {
    result.add(markingEnd);
  }
  result.add(end);
  return result;
}

List<SourcePoint2> _discretizeParabola(
  SourcePoint2 sourcePoint,
  BoundarySegment2 sourceSegment,
  SourcePoint2 start,
  SourcePoint2 end,
  int approximateStepSize,
  double transitioningAngleFloat,
) {
  final a = sourceSegment.a;
  final b = sourceSegment.b;
  final ab = b - a;
  final fromStart = start - a;
  final fromEnd = end - a;
  final abSize = _coordNorm(ab);
  if (abSize == 0) {
    throw StateError('Pinned parabola source segment has zero length');
  }
  final startProjection =
      (fromStart.x * ab.x + fromStart.y * ab.y) ~/ abSize;
  final endProjection = (fromEnd.x * ab.x + fromEnd.y * ab.y) ~/ abSize;
  final projectionSpan = endProjection - startProjection;

  final fromPoint = sourcePoint - a;
  final pointProjection =
      (fromPoint.x * ab.x + fromPoint.y * ab.y) ~/ abSize;
  final projectedPoint = _projectInfinite(sourcePoint, a, b);
  final sourceToProjection = projectedPoint - sourcePoint;
  final distance = _coordNorm(sourceToProjection);
  if (distance == 0) {
    return [start, end];
  }

  final perpendicular = SourcePoint2(
    -sourceToProjection.y,
    sourceToProjection.x,
  );
  final perpendicularLength = math.sqrt(perpendicular.squaredLength);
  final rotateCos = perpendicular.x / perpendicularLength;
  final rotateSin = perpendicular.y / perpendicularLength;

  final markingBound = math.atan(transitioningAngleFloat * 0.5);
  var markingStartX = (-markingBound * distance).truncate();
  var markingEndX = (markingBound * distance).truncate();
  final markingHeight =
      markingStartX * markingStartX ~/ (2 * distance) + distance ~/ 2;
  var markingStart = _rotate(
        SourcePoint2(markingStartX, markingHeight),
        rotateCos,
        rotateSin,
      ) +
      projectedPoint;
  var markingEnd = _rotate(
        SourcePoint2(markingEndX, markingHeight),
        rotateCos,
        rotateSin,
      ) +
      projectedPoint;

  final direction = startProjection > endProjection ? -1 : 1;
  if (direction < 0) {
    final pointSwap = markingStart;
    markingStart = markingEnd;
    markingEnd = pointSwap;
    final xSwap = markingStartX;
    markingStartX = markingEndX;
    markingEndX = xSwap;
  }

  var addMarkingStart = markingStartX * direction >
          (startProjection - pointProjection) * direction &&
      markingStartX * direction <
          (endProjection - pointProjection) * direction;
  var addMarkingEnd = markingEndX * direction >
          (startProjection - pointProjection) * direction &&
      markingEndX * direction <
          (endProjection - pointProjection) * direction;

  final apex = _rotate(
        SourcePoint2(0, distance ~/ 2),
        rotateCos,
        rotateSin,
      ) +
      projectedPoint;
  var addApex = (startProjection - pointProjection) * direction < 0 &&
      (endProjection - pointProjection) * direction > 0;

  final stepCount = _lround(
    (endProjection - startProjection).abs() / approximateStepSize,
  );
  final result = <SourcePoint2>[start];
  for (var step = 1; step < stepCount; step++) {
    final x = startProjection +
        projectionSpan * step ~/ stepCount -
        pointProjection;
    final y = x * x ~/ (2 * distance) + distance ~/ 2;

    if (addMarkingStart && markingStartX * direction < x * direction) {
      result.add(markingStart);
      addMarkingStart = false;
    }
    if (addApex && x * direction > 0) {
      result.add(apex);
      addApex = false;
    }
    if (addMarkingEnd && markingEndX * direction < x * direction) {
      result.add(markingEnd);
      addMarkingEnd = false;
    }

    result.add(
      _rotate(SourcePoint2(x, y), rotateCos, rotateSin) + projectedPoint,
    );
  }

  if (addApex) result.add(apex);
  if (addMarkingEnd) result.add(markingEnd);
  result.add(end);
  return result;
}

bool _edgeFitsCoord(VoronoiTopology2 topology, VoronoiHalfEdge2 edge) {
  if (!edge.finite || edge.vertex0 == null || edge.vertex1 == null) return false;
  return _vertexFitsCoord(topology.vertex(edge.vertex0!)) &&
      _vertexFitsCoord(topology.vertex(edge.vertex1!));
}

bool _vertexFitsCoord(VoronoiVertex2 vertex) {
  const minCoord = -2147483648.0;
  const maxCoord = 2147483647.0;
  final x = vertex.point.x;
  final y = vertex.point.y;
  return x.isFinite &&
      y.isFinite &&
      x >= minCoord &&
      x <= maxCoord &&
      y >= minCoord &&
      y <= maxCoord;
}

SourcePoint2 _coordPoint(VoronoiTopology2 topology, int vertexIndex) =>
    SourceVoronoiUtils2.toPoint(topology.vertex(vertexIndex).point);

SourcePoint2 _projectInfinite(
  SourcePoint2 point,
  SourcePoint2 a,
  SourcePoint2 b,
) {
  final vx = b.x - a.x;
  final vy = b.y - a.y;
  final px = point.x - a.x;
  final py = point.y - a.y;
  final lengthSquared = vx.toDouble() * vx + vy.toDouble() * vy;
  if (lengthSquared == 0) return a;
  final t = (px.toDouble() * vx + py.toDouble() * vy) / lengthSquared;
  return SourcePoint2(
    (a.x + t * vx).truncate(),
    (a.y + t * vy).truncate(),
  );
}

SourcePoint2 _rotate(SourcePoint2 point, double cosAngle, double sinAngle) =>
    SourcePoint2(
      _roundAway(cosAngle * point.x - sinAngle * point.y),
      _roundAway(cosAngle * point.y + sinAngle * point.x),
    );

int _coordNorm(SourcePoint2 value) => math.sqrt(value.squaredLength).truncate();

int _lround(double value) => _roundAway(value);

int _roundAway(double value) =>
    value >= 0 ? (value + 0.5).floor() : (value - 0.5).ceil();

double _f32(double value) {
  final slot = Float32List(1)..[0] = value;
  return slot[0];
}
