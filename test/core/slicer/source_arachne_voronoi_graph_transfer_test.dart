import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/voronoi_topology.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_polygon_indices.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_graph.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_voronoi_graph_transfer.dart';

SourcePolygon2 _square() => SourcePolygon2(const [
      SourcePoint2(0, 0),
      SourcePoint2(10000, 0),
      SourcePoint2(10000, 10000),
      SourcePoint2(0, 10000),
    ]);

SourceArachnePolygonSegments2 _segments() =>
    SourceArachnePolygonSegments2([_square()]);

VoronoiTopology2 _segmentSegmentTopology() => VoronoiTopology2(
      vertices: const [
        VoronoiVertex2(point: VoronoiPoint2(0, 0)),
        VoronoiVertex2(point: VoronoiPoint2(10000, 0)),
      ],
      cells: const [
        VoronoiCell2(
          sourceIndex: 0,
          sourceCategory: VoronoiSourceCategory.segment,
        ),
        VoronoiCell2(
          sourceIndex: 1,
          sourceCategory: VoronoiSourceCategory.segment,
        ),
      ],
      edges: const [
        VoronoiHalfEdge2(
          id: 0,
          vertex0: 0,
          vertex1: 1,
          cellIndex: 0,
          twinId: 1,
          rotNextId: 0,
        ),
        VoronoiHalfEdge2(
          id: 1,
          vertex0: 1,
          vertex1: 0,
          cellIndex: 1,
          twinId: 0,
          rotNextId: 1,
        ),
      ],
    );

VoronoiTopology2 _pointPointTopology() => VoronoiTopology2(
      vertices: const [
        VoronoiVertex2(point: VoronoiPoint2(5000, -12000)),
        VoronoiVertex2(point: VoronoiPoint2(5000, 12000)),
      ],
      cells: const [
        VoronoiCell2(
          sourceIndex: 0,
          sourceCategory: VoronoiSourceCategory.segmentStartPoint,
        ),
        VoronoiCell2(
          sourceIndex: 0,
          sourceCategory: VoronoiSourceCategory.segmentEndPoint,
        ),
      ],
      edges: const [
        VoronoiHalfEdge2(
          id: 0,
          vertex0: 0,
          vertex1: 1,
          cellIndex: 0,
          twinId: 1,
          rotNextId: 0,
        ),
        VoronoiHalfEdge2(
          id: 1,
          vertex0: 1,
          vertex1: 0,
          cellIndex: 1,
          twinId: 0,
          rotNextId: 1,
        ),
      ],
    );

SourceArachneVoronoiGraphTransfer2 _transfer(
  VoronoiTopology2 topology,
  SourceArachneSkeletalTrapezoidationGraph2 graph, {
  int step = 4000,
}) =>
    SourceArachneVoronoiGraphTransfer2(
      graph: graph,
      topology: topology,
      sourceSegments: _segments(),
      discretizationStepSize: step,
      transitioningAngle: 1.0,
    );

void main() {
  test('makeNode reuses Voronoi vertex identity and first point wins', () {
    final graph = SourceArachneSkeletalTrapezoidationGraph2();
    final transfer = _transfer(_segmentSegmentTopology(), graph);

    final first = transfer.makeNode(0, const SourcePoint2(1, 2));
    final reused = transfer.makeNode(0, const SourcePoint2(9, 9));

    expect(reused, same(first));
    expect(first.p, const SourcePoint2(1, 2));
    expect(graph.nodes, hasLength(1));
    expect(graph.nodes.single, same(first));
    expect(transfer.vdNodeToHeNode[0], same(first));
  });

  test('first transfer stores final half-edge and preserves source metadata', () {
    final topology = _segmentSegmentTopology();
    final graph = SourceArachneSkeletalTrapezoidationGraph2();
    final transfer = _transfer(topology, graph);

    final edge = transfer.transferEdge(
      edgeId: 0,
      from: const SourcePoint2(0, 0),
      to: const SourcePoint2(10000, 0),
      prevEdge: null,
      startSourcePoint: const SourcePoint2(0, 0),
      endSourcePoint: const SourcePoint2(10000, 0),
      holeCompensationFlag: true,
    );

    expect(graph.nodes, hasLength(2));
    expect(graph.edges, hasLength(1));
    expect(graph.edges.single, same(edge));
    expect(edge.from, same(transfer.vdNodeToHeNode[0]));
    expect(edge.to, same(transfer.vdNodeToHeNode[1]));
    expect(edge.from!.incidentEdge, same(edge));
    expect(edge.data.holeCompensationFlag, isTrue);
    expect(edge.twin, isNull);
    expect(transfer.vdEdgeToHeEdge[0], same(edge));
  });

  test('already transferred twin creates reverse half-edge without remapping', () {
    final topology = _segmentSegmentTopology();
    final graph = SourceArachneSkeletalTrapezoidationGraph2();
    final transfer = _transfer(topology, graph);

    final first = transfer.transferEdge(
      edgeId: 0,
      from: const SourcePoint2(0, 0),
      to: const SourcePoint2(10000, 0),
      prevEdge: null,
      startSourcePoint: const SourcePoint2(0, 0),
      endSourcePoint: const SourcePoint2(10000, 0),
      holeCompensationFlag: true,
    );
    final reverse = transfer.transferEdge(
      edgeId: 1,
      from: const SourcePoint2(10000, 0),
      to: const SourcePoint2(0, 0),
      prevEdge: null,
      startSourcePoint: const SourcePoint2(10000, 0),
      endSourcePoint: const SourcePoint2(0, 0),
      holeCompensationFlag: false,
    );

    expect(reverse.from, same(first.to));
    expect(reverse.to, same(first.from));
    expect(reverse.twin, same(first));
    expect(first.twin, same(reverse));
    expect(reverse.data.holeCompensationFlag, isFalse);
    expect(first.data.holeCompensationFlag, isTrue);
    expect(graph.edges, hasLength(2));
    // Pinned twin-reuse branch does not emplace the current VD edge in the map.
    expect(transfer.vdEdgeToHeEdge.containsKey(1), isFalse);
  });

  test('discretized twin chain is reconstructed segment-for-segment', () {
    final topology = _pointPointTopology();
    final graph = SourceArachneSkeletalTrapezoidationGraph2();
    final transfer = _transfer(topology, graph);

    transfer.transferEdge(
      edgeId: 0,
      from: const SourcePoint2(5000, -12000),
      to: const SourcePoint2(5000, 12000),
      prevEdge: null,
      // Point-cell source range is degenerate at its source point.
      startSourcePoint: const SourcePoint2(0, 0),
      endSourcePoint: const SourcePoint2(0, 0),
      holeCompensationFlag: true,
    );

    final originalNormals = graph.edges
        .where((edge) => edge.data.type == SourceArachneSkeletalEdgeType2.normal)
        .toList();
    expect(originalNormals.length, greaterThan(1));
    expect(originalNormals.every((edge) => edge.twin == null), isTrue);
    expect(
      graph.edges.any(
        (edge) => edge.data.type == SourceArachneSkeletalEdgeType2.extraVd,
      ),
      isTrue,
    );

    transfer.transferEdge(
      edgeId: 1,
      from: const SourcePoint2(5000, 12000),
      to: const SourcePoint2(5000, -12000),
      prevEdge: null,
      startSourcePoint: const SourcePoint2(10000, 0),
      endSourcePoint: const SourcePoint2(10000, 0),
      holeCompensationFlag: false,
    );

    final allNormals = graph.edges
        .where((edge) => edge.data.type == SourceArachneSkeletalEdgeType2.normal)
        .toList();
    expect(allNormals, hasLength(originalNormals.length * 2));
    for (final edge in originalNormals) {
      expect(edge.twin, isNotNull);
      expect(edge.twin!.twin, same(edge));
      expect(edge.data.holeCompensationFlag, isTrue);
      expect(edge.twin!.data.holeCompensationFlag, isFalse);
    }
    expect(
      transfer.vdEdgeToHeEdge[0]!.to,
      same(transfer.vdNodeToHeNode[1]),
    );
    expect(transfer.vdEdgeToHeEdge.containsKey(1), isFalse);
  });
}
