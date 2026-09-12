import 'source_arachne_skeletal_graph.dart';

/// Direct initialization helpers from pinned
/// `SkeletalTrapezoidation::constructFromPolygons()`.
///
/// This scope intentionally starts after Voronoi edges already exist in the
/// skeletal graph; it does not claim the still-open Voronoi-to-graph transfer.
extension SourceArachneSkeletalInitialization2
    on SourceArachneSkeletalTrapezoidationGraph2 {
  /// Port of pinned `separatePointyQuadEndNodes()`.
  ///
  /// Source duplicates a node when more than one quad start (`prev == nullptr`)
  /// shares the same `from` pointer. `HalfEdgeNode` copy construction copies
  /// the Joint payload, including the shared_ptr to `BeadingPropagation`, then
  /// source overwrites only `incident_edge` on the clone.
  void separatePointyQuadEndNodes() {
    final startingNodes = <SourceArachneSTHalfEdgeNode2>{};

    // Source range-for walks the edge list while appending only to nodes, so a
    // stable snapshot of current edge identity exactly matches that boundary.
    final currentEdges = List<SourceArachneSTHalfEdge2>.of(edges);
    for (final edge in currentEdges) {
      if (edge.prev != null) continue;
      final from = edge.from ??
          (throw StateError('Pointy quad start has no from node'));
      if (startingNodes.add(from)) continue;

      final twin = edge.twin ??
          (throw StateError('Pointy quad start has no twin'));
      final clonedJoint = SourceArachneSkeletalJoint2(
        distanceToBoundary: from.data.distanceToBoundary,
        beadCount: from.data.beadCount,
        transitionRatio: from.data.transitionRatio,
      );
      final beading = from.data.beading;
      if (beading != null) clonedJoint.setBeading(beading);

      final newNode = SourceArachneSTHalfEdgeNode2(
        p: from.p,
        data: clonedJoint,
      )..incidentEdge = edge;
      nodes.add(newNode);
      edge.from = newNode;
      twin.to = newNode;
    }
  }

  /// Literal final source loop after `graph.collapseSmallEdges()`:
  /// every chain-start edge becomes the incident edge of its `from` node.
  void normalizeStartIncidentEdges() {
    for (final edge in edges) {
      if (edge.prev != null) continue;
      final from = edge.from ??
          (throw StateError('Chain-start edge has no from node'));
      from.incidentEdge = edge;
    }
  }
}
