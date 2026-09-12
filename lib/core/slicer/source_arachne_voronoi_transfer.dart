import 'dart:math' as math;

import '../geometry/source_voronoi_utils.dart';
import '../geometry/voronoi_topology.dart';
import 'source_arachne_polygon_indices.dart';

class SourceArachnePointCellRange2 {
  const SourceArachnePointCellRange2({
    required this.sourcePoint,
    required this.sourcePointIndex,
    required this.startingVdEdgeId,
    required this.endingVdEdgeId,
  });

  final SourcePoint2 sourcePoint;
  final SourceArachnePolygonsPointIndex2 sourcePointIndex;
  final int startingVdEdgeId;
  final int endingVdEdgeId;
}

/// First Voronoi-transfer slice from pinned
/// `SkeletalTrapezoidation::constructFromPolygons()`.
class SourceArachneVoronoiTransfer2 {
  const SourceArachneVoronoiTransfer2._();

  /// Literal port of pinned `computePointCellRange()`.
  ///
  /// Source returns false through an out-parameter API; nullable result is the
  /// Dart compatibility seam for the same branch outcome.
  static SourceArachnePointCellRange2? computePointCellRange(
    VoronoiTopology2 topology,
    int cellIndex,
    SourceArachnePolygonSegments2 sourceSegments,
  ) {
    final cell = topology.cell(cellIndex);
    final incidentId = cell.incidentEdgeId;
    if (incidentId == null) return null;
    final incident = topology.edge(incidentId);
    if (incident.infinite) return null;

    final incidentVertex0 = topology.vertex(incident.vertex0!);
    const int64LimitAsDouble = 9223372036854775808.0;
    final vx = incidentVertex0.point.x;
    final vy = incidentVertex0.point.y;
    if (vx >= int64LimitAsDouble ||
        vx <= -int64LimitAsDouble ||
        vy >= int64LimitAsDouble ||
        vy <= -int64LimitAsDouble) {
      return null;
    }

    final sourcePoint = SourceVoronoiUtils2.getSourcePoint(
      cell,
      sourceSegments.boundarySegments,
    );
    final sourcePointIndex = sourceSegments.sourcePointIndex(cell);

    var somePoint = SourceVoronoiUtils2.toPoint(incidentVertex0.point);
    if (somePoint == sourcePoint) {
      somePoint = SourceVoronoiUtils2.toPoint(
        topology.vertex(incident.vertex1!).point,
      );
    }

    if (!_isInsideCorner(
      sourcePointIndex.prev().p,
      sourcePointIndex.p,
      sourcePointIndex.next().p,
      somePoint,
    )) {
      return null;
    }

    int? startingVdEdgeId;
    int? endingVdEdgeId;
    for (final edge in topology.orderedEdgesForCell(cellIndex)) {
      assert(edge.finite);
      if (!edge.finite) {
        throw StateError('Pinned point-cell traversal encountered infinite edge');
      }
      final vertex1 = SourceVoronoiUtils2.toPoint(
        topology.vertex(edge.vertex1!).point,
      );
      if (vertex1 == sourcePoint) {
        final nextId = edge.nextId;
        if (nextId == null) {
          throw StateError('Pinned point-cell edge has no next edge');
        }
        startingVdEdgeId = nextId;
        endingVdEdgeId = edge.id;
      } else {
        final vertex0 = SourceVoronoiUtils2.toPoint(
          topology.vertex(edge.vertex0!).point,
        );
        assert(vertex0 == sourcePoint || !edge.secondary);
      }
    }

    if (startingVdEdgeId == null || endingVdEdgeId == null) {
      throw StateError('Pinned point-cell range did not resolve both edges');
    }
    assert(startingVdEdgeId != endingVdEdgeId);
    if (startingVdEdgeId == endingVdEdgeId) {
      throw StateError('Pinned point-cell range collapsed to one edge');
    }

    return SourceArachnePointCellRange2(
      sourcePoint: sourcePoint,
      sourcePointIndex: sourcePointIndex,
      startingVdEdgeId: startingVdEdgeId,
      endingVdEdgeId: endingVdEdgeId,
    );
  }

  /// Literal `Arachne::LinearAlg2D::isInsideCorner()` helper used by the point
  /// cell gate. Exposed for direct source-oracle regression fixtures.
  static bool isInsideCorner(
    SourcePoint2 a,
    SourcePoint2 b,
    SourcePoint2 c,
    SourcePoint2 queryPoint,
  ) =>
      _isInsideCorner(a, b, c, queryPoint);
}

bool _isInsideCorner(
  SourcePoint2 a,
  SourcePoint2 b,
  SourcePoint2 c,
  SourcePoint2 queryPoint,
) {
  const normalLength = 10000;
  final ba = _normal(a - b, normalLength);
  final bc = _normal(c - b, normalLength);
  final bqx = queryPoint.x.toDouble() - b.x;
  final bqy = queryPoint.y.toDouble() - b.y;
  final perpendicularX = -bqy;
  final perpendicularY = bqx;

  final projectAPerpendicular =
      ba.x.toDouble() * perpendicularX + ba.y.toDouble() * perpendicularY;
  final projectCPerpendicular =
      bc.x.toDouble() * perpendicularX + bc.y.toDouble() * perpendicularY;
  if ((projectAPerpendicular > 0.0) != (projectCPerpendicular > 0.0)) {
    return projectAPerpendicular > 0.0;
  }

  final projectAParallel = ba.x.toDouble() * bqx + ba.y.toDouble() * bqy;
  final projectCParallel = bc.x.toDouble() * bqx + bc.y.toDouble() * bqy;
  return (projectCParallel < projectAParallel) ==
      (projectAPerpendicular > 0.0);
}

SourcePoint2 _normal(SourcePoint2 vector, int length) {
  final sourceLength = math.sqrt(vector.squaredLength).truncate();
  if (sourceLength < 1) return SourcePoint2(length, 0);
  return SourcePoint2(
    vector.x * length ~/ sourceLength,
    vector.y * length ~/ sourceLength,
  );
}
