import '../geometry/voronoi_topology.dart';
import 'source_arachne_polygon_indices.dart';
import 'source_arachne_skeletal_graph.dart';
import 'source_arachne_skeletal_graph_mutations.dart';
import 'source_arachne_voronoi_discretize.dart';

/// Stateful identity-map port of pinned
/// `SkeletalTrapezoidation::makeNode()` / `transferEdge()`.
///
/// Boost vertex indexes stand in for source vertex pointer identity and Voronoi
/// edge ids stand in for source edge pointer identity. The stored map value for
/// an edge is intentionally the final discretized half-edge, exactly matching
/// `vd_edge_to_he_edge.emplace(&vd_edge, prev_edge)`.
class SourceArachneVoronoiGraphTransfer2 {
  SourceArachneVoronoiGraphTransfer2({
    required this.graph,
    required this.topology,
    required this.sourceSegments,
    required this.discretizationStepSize,
    required this.transitioningAngle,
  });

  final SourceArachneSkeletalTrapezoidationGraph2 graph;
  final VoronoiTopology2 topology;
  final SourceArachnePolygonSegments2 sourceSegments;
  final int discretizationStepSize;
  final double transitioningAngle;

  final Map<int, SourceArachneSTHalfEdgeNode2> vdNodeToHeNode = {};
  final Map<int, SourceArachneSTHalfEdge2> vdEdgeToHeEdge = {};

  /// Literal source identity behavior: the first point used for a Voronoi
  /// vertex wins; later calls with the same vertex return the existing node.
  SourceArachneSTHalfEdgeNode2 makeNode(int vertexIndex, SourcePoint2 point) {
    final existing = vdNodeToHeNode[vertexIndex];
    if (existing != null) return existing;

    final node = SourceArachneSTHalfEdgeNode2(p: point);
    graph.nodes.insert(0, node);
    vdNodeToHeNode[vertexIndex] = node;
    return node;
  }

  /// Direct port of pinned `transferEdge(...)`.
  ///
  /// The returned edge is the source-mutated `prev_edge` reference.
  SourceArachneSTHalfEdge2 transferEdge({
    required int edgeId,
    required SourcePoint2 from,
    required SourcePoint2 to,
    required SourceArachneSTHalfEdge2? prevEdge,
    required SourcePoint2 startSourcePoint,
    required SourcePoint2 endSourcePoint,
    required bool holeCompensationFlag,
  }) {
    final vdEdge = topology.edge(edgeId);
    final mappedTwin = vdEdgeToHeEdge[vdEdge.twinId];
    if (mappedTwin != null) {
      return _reuseTransferredTwin(
        vdEdge: vdEdge,
        sourceTwin: mappedTwin,
        prevEdge: prevEdge,
        startSourcePoint: startSourcePoint,
        endSourcePoint: endSourcePoint,
        holeCompensationFlag: holeCompensationFlag,
      );
    }

    return _discretizeFirstSide(
      vdEdge: vdEdge,
      from: from,
      to: to,
      prevEdge: prevEdge,
      startSourcePoint: startSourcePoint,
      endSourcePoint: endSourcePoint,
      holeCompensationFlag: holeCompensationFlag,
    );
  }

  SourceArachneSTHalfEdge2 _reuseTransferredTwin({
    required VoronoiHalfEdge2 vdEdge,
    required SourceArachneSTHalfEdge2 sourceTwin,
    required SourceArachneSTHalfEdge2? prevEdge,
    required SourcePoint2 startSourcePoint,
    required SourcePoint2 endSourcePoint,
    required bool holeCompensationFlag,
  }) {
    final endVertex = vdEdge.vertex1;
    if (endVertex == null) {
      throw StateError('Pinned transferEdge twin branch requires vertex1');
    }
    final endNode = vdNodeToHeNode[endVertex];
    if (endNode == null) {
      throw StateError('Pinned transferEdge twin branch lost end vertex map');
    }

    var twin = sourceTwin;
    var currentPrev = prevEdge;
    while (true) {
      final twinFrom = twin.from;
      final twinTo = twin.to;
      if (twinFrom == null || twinTo == null) {
        throw StateError('Pinned transferred twin has a null endpoint');
      }

      final edge = SourceArachneSTHalfEdge2()
        ..from = twinTo
        ..to = twinFrom
        ..twin = twin;
      edge.data.setHoleCompensationFlag(holeCompensationFlag);
      twin.twin = edge;
      edge.from!.incidentEdge = edge;
      graph.edges.insert(0, edge);

      if (currentPrev != null) {
        edge.prev = currentPrev;
        currentPrev.next = edge;
      }
      currentPrev = edge;

      if (identical(currentPrev.to, endNode)) {
        return currentPrev;
      }

      final previousSegment = twin.prev?.twin?.prev;
      if (previousSegment == null) {
        // Source logs "Discretized segment behaves oddly!" and returns the
        // partially transferred chain through its mutable prev_edge reference.
        return currentPrev;
      }

      currentPrev = graph.makeRib(
        currentPrev,
        startSourcePoint,
        endSourcePoint,
        isNextToStartOrEnd: false,
      );
      twin = previousSegment;
    }
  }

  SourceArachneSTHalfEdge2 _discretizeFirstSide({
    required VoronoiHalfEdge2 vdEdge,
    required SourcePoint2 from,
    required SourcePoint2 to,
    required SourceArachneSTHalfEdge2? prevEdge,
    required SourcePoint2 startSourcePoint,
    required SourcePoint2 endSourcePoint,
    required bool holeCompensationFlag,
  }) {
    final discretized = SourceArachneVoronoiDiscretize2.discretize(
      topology,
      vdEdge.id,
      sourceSegments,
      discretizationStepSize: discretizationStepSize,
      transitioningAngle: transitioningAngle,
    );
    if (discretized.length < 2) {
      throw StateError('Pinned discretized Voronoi edge is degenerate');
    }

    final vertex0 = vdEdge.vertex0;
    final vertex1 = vdEdge.vertex1;
    if (vertex0 == null || vertex1 == null) {
      throw StateError('Pinned transferEdge first-side branch requires vertices');
    }

    var currentPrev = prevEdge;
    var v0 = currentPrev?.to ?? makeNode(vertex0, from);

    for (var pointIndex = 1;
        pointIndex < discretized.length;
        pointIndex++) {
      final isInterior = pointIndex < discretized.length - 1;
      final v1 = isInterior
          ? SourceArachneSTHalfEdgeNode2(p: discretized[pointIndex])
          : makeNode(vertex1, to);
      if (isInterior) {
        graph.nodes.insert(0, v1);
      }

      final edge = SourceArachneSTHalfEdge2()
        ..from = v0
        ..to = v1;
      edge.data.setHoleCompensationFlag(holeCompensationFlag);
      edge.from!.incidentEdge = edge;
      graph.edges.insert(0, edge);

      if (currentPrev != null) {
        edge.prev = currentPrev;
        currentPrev.next = edge;
      }

      currentPrev = edge;
      v0 = v1;

      if (isInterior) {
        currentPrev = graph.makeRib(
          currentPrev,
          startSourcePoint,
          endSourcePoint,
          isNextToStartOrEnd: false,
        );
      }
    }

    final finalEdge = currentPrev!;
    vdEdgeToHeEdge[vdEdge.id] = finalEdge;
    return finalEdge;
  }
}
