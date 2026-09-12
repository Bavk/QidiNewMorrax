import 'dart:math' as math;

import '../geometry/source_geometry.dart';
import 'source_arachne_skeletal_graph.dart';

/// Direct mutation subset from pinned `SkeletalTrapezoidationGraph.cpp`.
///
/// This intentionally stops before `collapseSmallEdges()` and before Voronoi
/// transfer / full `SkeletalTrapezoidation` construction.
extension SourceArachneSkeletalGraphMutations2
    on SourceArachneSkeletalTrapezoidationGraph2 {
  /// Pinned `SkeletalTrapezoidationGraph::getSource()`.
  SourceLine2 getSource(SourceArachneSTHalfEdge2 edge) {
    var fromEdge = edge;
    while (fromEdge.prev != null) {
      fromEdge = fromEdge.prev!;
    }

    var toEdge = edge;
    while (toEdge.next != null) {
      toEdge = toEdge.next!;
    }

    final from = fromEdge.from ??
        (throw StateError('Pinned getSource() reached a null from node'));
    final to = toEdge.to ??
        (throw StateError('Pinned getSource() reached a null to node'));
    return SourceLine2(from.p, to.p);
  }

  /// Pinned `makeRib(edge_t*&, Point, Point, bool)`.
  ///
  /// The source parameter `is_next_to_start_or_end` is unused and remains so.
  /// The returned edge is the source-mutated `prev_edge` (`back_edge`).
  SourceArachneSTHalfEdge2 makeRib(
    SourceArachneSTHalfEdge2 prevEdge,
    SourcePoint2 startSourcePoint,
    SourcePoint2 endSourcePoint, {
    required bool isNextToStartOrEnd,
  }) {
    final previousTo = prevEdge.to ??
        (throw StateError('Pinned makeRib() requires prev_edge->to'));
    final projected = _projectInfinite(
      previousTo.p,
      startSourcePoint,
      endSourcePoint,
    );
    final distance = _coordNorm(previousTo.p - projected);
    previousTo.data.distanceToBoundary = distance;

    final sourceNode = SourceArachneSTHalfEdgeNode2(
      p: projected,
      data: SourceArachneSkeletalJoint2(distanceToBoundary: 0),
    );
    nodes.insert(0, sourceNode);

    final forthEdge = SourceArachneSTHalfEdge2(
      SourceArachneSkeletalEdgeData2(
        type: SourceArachneSkeletalEdgeType2.extraVd,
      )..setHoleCompensationFlag(prevEdge.data.holeCompensationFlag),
    );
    // Source emplaces `forth_edge` at front, then `back_edge` at front.
    edges.insert(0, forthEdge);
    final backEdge = SourceArachneSTHalfEdge2(
      SourceArachneSkeletalEdgeData2(
        type: SourceArachneSkeletalEdgeType2.extraVd,
      )..setHoleCompensationFlag(prevEdge.data.holeCompensationFlag),
    );
    edges.insert(0, backEdge);

    prevEdge.next = forthEdge;
    forthEdge.prev = prevEdge;
    forthEdge.from = previousTo;
    forthEdge.to = sourceNode;
    forthEdge.twin = backEdge;
    backEdge.twin = forthEdge;
    backEdge.from = sourceNode;
    backEdge.to = previousTo;
    sourceNode.incidentEdge = backEdge;

    return backEdge;
  }

  /// Pinned `insertRib(edge_t&, node_t*)`.
  ({SourceArachneSTHalfEdge2 first, SourceArachneSTHalfEdge2 second}) insertRib(
    SourceArachneSTHalfEdge2 edge,
    SourceArachneSTHalfEdgeNode2 midNode,
  ) {
    final edgeBefore = edge.prev;
    final edgeAfter = edge.next;
    final nodeBefore = edge.from ??
        (throw StateError('Pinned insertRib() requires edge.from'));
    final nodeAfter = edge.to ??
        (throw StateError('Pinned insertRib() requires edge.to'));

    final sourceSegment = getSource(edge);
    final projected = _projectFinite(midNode.p, sourceSegment.a, sourceSegment.b);
    final distance = _coordNorm(midNode.p - projected);
    if (distance <= 0) {
      throw StateError('Pinned insertRib() requires positive rib distance');
    }
    midNode.data.distanceToBoundary = distance;
    midNode.data.transitionRatio = 0;

    final sourceNode = SourceArachneSTHalfEdgeNode2(
      p: projected,
      data: SourceArachneSkeletalJoint2(distanceToBoundary: 0),
    );
    nodes.add(sourceNode);

    final first = edge;
    final second = SourceArachneSTHalfEdge2();
    final outwardEdge = SourceArachneSTHalfEdge2(
      SourceArachneSkeletalEdgeData2(
        type: SourceArachneSkeletalEdgeType2.transitionEnd,
      ),
    );
    final inwardEdge = SourceArachneSTHalfEdge2(
      SourceArachneSkeletalEdgeData2(
        type: SourceArachneSkeletalEdgeType2.transitionEnd,
      ),
    );
    edges
      ..add(second)
      ..add(outwardEdge)
      ..add(inwardEdge);

    final applyHoleCompensation = edge.data.holeCompensationFlag;
    first.data.setHoleCompensationFlag(applyHoleCompensation);
    second.data.setHoleCompensationFlag(applyHoleCompensation);
    outwardEdge.data.setHoleCompensationFlag(applyHoleCompensation);
    inwardEdge.data.setHoleCompensationFlag(applyHoleCompensation);

    if (edgeBefore != null) edgeBefore.next = first;
    first.next = outwardEdge;
    outwardEdge.next = null;
    inwardEdge.next = second;
    second.next = edgeAfter;

    if (edgeAfter != null) edgeAfter.prev = second;
    second.prev = inwardEdge;
    inwardEdge.prev = null;
    outwardEdge.prev = first;
    first.prev = edgeBefore;

    first.to = midNode;
    outwardEdge.to = sourceNode;
    inwardEdge.to = midNode;
    second.to = nodeAfter;

    first.from = nodeBefore;
    outwardEdge.from = midNode;
    inwardEdge.from = sourceNode;
    second.from = midNode;

    nodeBefore.incidentEdge = first;
    midNode.incidentEdge = outwardEdge;
    sourceNode.incidentEdge = inwardEdge;
    if (edgeAfter != null) nodeAfter.incidentEdge = edgeAfter;

    first.data.setIsCentral(true);
    outwardEdge.data.setIsCentral(false);
    inwardEdge.data.setIsCentral(false);
    second.data.setIsCentral(true);

    outwardEdge.twin = inwardEdge;
    inwardEdge.twin = outwardEdge;
    first.twin = null;
    second.twin = null;

    return (first: first, second: second);
  }

  /// Pinned `insertNode(edge_t*, Point, coord_t)`.
  SourceArachneSTHalfEdge2 insertNode(
    SourceArachneSTHalfEdge2 edge,
    SourcePoint2 mid,
    int midNodeBeadCount,
  ) {
    final midNode = SourceArachneSTHalfEdgeNode2(p: mid);
    nodes.add(midNode);

    final twin = edge.twin ??
        (throw StateError('Pinned insertNode() requires an input twin'));
    edge.twin = null;
    twin.twin = null;

    final leftPair = insertRib(edge, midNode);
    final rightPair = insertRib(twin, midNode);

    leftPair.first.twin = rightPair.second;
    rightPair.second.twin = leftPair.first;
    leftPair.second.twin = rightPair.first;
    rightPair.first.twin = leftPair.second;

    midNode.data.beadCount = midNodeBeadCount;
    return leftPair.second;
  }
}

SourcePoint2 _projectFinite(
  SourcePoint2 point,
  SourcePoint2 a,
  SourcePoint2 b,
) {
  final vx = b.x - a.x;
  final vy = b.y - a.y;
  final vax = point.x - a.x;
  final vay = point.y - a.y;
  final lengthSquared = vx.toDouble() * vx + vy.toDouble() * vy;
  if (lengthSquared == 0) return a;

  final t = (vax.toDouble() * vx + vay.toDouble() * vy) / lengthSquared;
  if (t <= 0) return a;
  if (t >= 1) return b;
  return SourcePoint2(
    (a.x + t * vx).truncate(),
    (a.y + t * vy).truncate(),
  );
}

SourcePoint2 _projectInfinite(
  SourcePoint2 point,
  SourcePoint2 a,
  SourcePoint2 b,
) {
  final vx = b.x - a.x;
  final vy = b.y - a.y;
  final vax = point.x - a.x;
  final vay = point.y - a.y;
  final lengthSquared = vx.toDouble() * vx + vy.toDouble() * vy;
  if (lengthSquared == 0) return a;

  final t = (vax.toDouble() * vx + vay.toDouble() * vy) / lengthSquared;
  return SourcePoint2(
    (a.x + t * vx).truncate(),
    (a.y + t * vy).truncate(),
  );
}

int _coordNorm(SourcePoint2 vector) =>
    math.sqrt(vector.squaredLength).truncate();
