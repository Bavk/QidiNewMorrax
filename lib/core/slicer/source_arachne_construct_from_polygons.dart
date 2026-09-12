import '../geometry/source_boost_topology_adapter.dart';
import '../geometry/source_polygon.dart';
import '../geometry/source_voronoi_utils.dart';
import '../geometry/voronoi_topology.dart';
import 'source_arachne_polygon_indices.dart';
import 'source_arachne_skeletal_graph.dart';
import 'source_arachne_skeletal_graph_collapse.dart';
import 'source_arachne_skeletal_graph_mutations.dart';
import 'source_arachne_skeletal_initialization.dart';
import 'source_arachne_voronoi_graph_transfer.dart';
import 'source_arachne_voronoi_transfer.dart';

class SourceArachneConstructedGraph2 {
  const SourceArachneConstructedGraph2({
    required this.graph,
    required this.topology,
    required this.sourceSegments,
    required this.transfer,
  });

  final SourceArachneSkeletalTrapezoidationGraph2 graph;
  final VoronoiTopology2 topology;
  final SourceArachnePolygonSegments2 sourceSegments;
  final SourceArachneVoronoiGraphTransfer2 transfer;
}

/// Literal represented composition of pinned
/// `SkeletalTrapezoidation::constructFromPolygons()`.
class SourceArachneConstructFromPolygons2 {
  const SourceArachneConstructFromPolygons2._();

  static SourceArachneConstructedGraph2 construct(
    List<SourcePolygon2> polygons, {
    required double transitioningAngle,
    required int discretizationStepSize,
    required bool enableHoleCompensation,
    Iterable<int> holeIndices = const <int>[],
  }) {
    final sourceSegments = SourceArachnePolygonSegments2(polygons);
    final topology = SourceBoostSegmentVoronoiBuilder2.build(
      sourceSegments.boundarySegments,
    );
    final graph = SourceArachneSkeletalTrapezoidationGraph2();
    final transfer = SourceArachneVoronoiGraphTransfer2(
      graph: graph,
      topology: topology,
      sourceSegments: sourceSegments,
      discretizationStepSize: discretizationStepSize,
      transitioningAngle: transitioningAngle,
    );
    final holeIndexSet = holeIndices.toSet();

    for (var cellIndex = 0; cellIndex < topology.cells.length; cellIndex++) {
      final cell = topology.cell(cellIndex);
      if (cell.incidentEdgeId == null) {
        continue;
      }

      late SourcePoint2 startSourcePoint;
      late SourcePoint2 endSourcePoint;
      late int startingVoronoiEdgeId;
      late int endingVoronoiEdgeId;
      var applyHoleCompensation = enableHoleCompensation;

      if (cell.containsPoint) {
        final pointRange = SourceArachneVoronoiTransfer2.computePointCellRange(
          topology,
          cellIndex,
          sourceSegments,
        );
        if (pointRange == null) {
          continue;
        }
        startSourcePoint = pointRange.sourcePoint;
        endSourcePoint = pointRange.sourcePoint;
        startingVoronoiEdgeId = pointRange.startingVdEdgeId;
        endingVoronoiEdgeId = pointRange.endingVdEdgeId;
        applyHoleCompensation = applyHoleCompensation &&
            holeIndexSet.contains(pointRange.sourcePointIndex.polygonIndex);
      } else {
        final segmentRange = SourceVoronoiUtils2.computeSegmentCellRange(
          topology,
          cellIndex,
          sourceSegments.boundarySegments,
        );
        if (!segmentRange.isValid) {
          throw StateError('Pinned segment cell range is invalid');
        }
        startSourcePoint = segmentRange.segmentStartPoint;
        endSourcePoint = segmentRange.segmentEndPoint;
        startingVoronoiEdgeId = segmentRange.edgeBeginId!;
        endingVoronoiEdgeId = segmentRange.edgeEndId!;
        final sourceSegment = sourceSegments.segmentIndexForCell(cell);
        applyHoleCompensation = applyHoleCompensation &&
            holeIndexSet.contains(sourceSegment.polygonIndex);
      }

      final startingVoronoiEdge = topology.edge(startingVoronoiEdgeId);
      final endingVoronoiEdge = topology.edge(endingVoronoiEdgeId);
      _requireFiniteCoordEdge(topology, startingVoronoiEdge);

      var previous = transfer.transferEdge(
        edgeId: startingVoronoiEdge.id,
        from: startSourcePoint,
        to: _coordVertex(topology, startingVoronoiEdge.vertex1),
        prevEdge: null,
        startSourcePoint: startSourcePoint,
        endSourcePoint: endSourcePoint,
        holeCompensationFlag: applyHoleCompensation,
      );

      final startingVertex = startingVoronoiEdge.vertex0;
      if (startingVertex == null) {
        throw StateError('Pinned starting Voronoi edge has no vertex0');
      }
      final startingNode = transfer.vdNodeToHeNode[startingVertex];
      if (startingNode == null) {
        throw StateError('Pinned starting Voronoi node was not transferred');
      }
      startingNode.data.distanceToBoundary = 0;

      previous = graph.makeRib(
        previous,
        startSourcePoint,
        endSourcePoint,
        isNextToStartOrEnd: true,
      );

      var nextEdgeId = startingVoronoiEdge.nextId;
      if (nextEdgeId == null) {
        throw StateError('Pinned starting Voronoi edge has no next edge');
      }
      var traversalGuard = 0;
      while (nextEdgeId != endingVoronoiEdge.id) {
        final edge = topology.edge(nextEdgeId);
        _requireFiniteCoordEdge(topology, edge);
        final edgeNextId = edge.nextId;
        if (edgeNextId == null) {
          throw StateError('Pinned middle Voronoi edge has no next edge');
        }

        previous = transfer.transferEdge(
          edgeId: edge.id,
          from: _coordVertex(topology, edge.vertex0),
          to: _coordVertex(topology, edge.vertex1),
          prevEdge: previous,
          startSourcePoint: startSourcePoint,
          endSourcePoint: endSourcePoint,
          holeCompensationFlag: applyHoleCompensation,
        );
        previous = graph.makeRib(
          previous,
          startSourcePoint,
          endSourcePoint,
          isNextToStartOrEnd: edgeNextId == endingVoronoiEdge.id,
        );

        nextEdgeId = edgeNextId;
        traversalGuard++;
        if (traversalGuard > topology.edges.length) {
          throw StateError('Pinned Voronoi cell traversal did not reach end');
        }
      }

      previous = transfer.transferEdge(
        edgeId: endingVoronoiEdge.id,
        from: _coordVertex(topology, endingVoronoiEdge.vertex0),
        to: endSourcePoint,
        prevEdge: previous,
        startSourcePoint: startSourcePoint,
        endSourcePoint: endSourcePoint,
        holeCompensationFlag: applyHoleCompensation,
      );
      final endingNode = previous.to;
      if (endingNode == null) {
        throw StateError('Pinned ending transferred edge has no target node');
      }
      endingNode.data.distanceToBoundary = 0;
    }

    graph.separatePointyQuadEndNodes();
    graph.collapseSmallEdges();
    graph.normalizeStartIncidentEdges();

    return SourceArachneConstructedGraph2(
      graph: graph,
      topology: topology,
      sourceSegments: sourceSegments,
      transfer: transfer,
    );
  }
}

SourcePoint2 _coordVertex(VoronoiTopology2 topology, int? vertexIndex) {
  if (vertexIndex == null) {
    throw StateError('Pinned finite Voronoi edge has no vertex');
  }
  return SourceVoronoiUtils2.toPoint(topology.vertex(vertexIndex).point);
}

void _requireFiniteCoordEdge(
  VoronoiTopology2 topology,
  VoronoiHalfEdge2 edge,
) {
  if (!edge.finite || edge.vertex0 == null || edge.vertex1 == null) {
    throw StateError('Pinned construct edge is not finite');
  }
  _requireCoordVertex(topology.vertex(edge.vertex0!));
  _requireCoordVertex(topology.vertex(edge.vertex1!));
}

void _requireCoordVertex(VoronoiVertex2 vertex) {
  const minCoord = -2147483648.0;
  const maxCoord = 2147483647.0;
  final x = vertex.point.x;
  final y = vertex.point.y;
  if (!x.isFinite ||
      !y.isFinite ||
      x < minCoord ||
      x > maxCoord ||
      y < minCoord ||
      y > maxCoord) {
    throw StateError('Pinned construct Voronoi vertex is outside coord_t range');
  }
}
