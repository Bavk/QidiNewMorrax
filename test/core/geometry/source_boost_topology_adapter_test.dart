import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_boost_topology_adapter.dart';
import 'package:qidi_flow_flutter/core/geometry/voronoi_topology.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';

void main() {
  test('square segment topology keeps Boost order and maps 8/9 to Segment', () {
    final topology = SourceBoostSegmentVoronoiBuilder2.build(const [
      BoundarySegment2(SourcePoint2(0, 0), SourcePoint2(100, 0)),
      BoundarySegment2(SourcePoint2(100, 0), SourcePoint2(100, 100)),
      BoundarySegment2(SourcePoint2(100, 100), SourcePoint2(0, 100)),
      BoundarySegment2(SourcePoint2(0, 100), SourcePoint2(0, 0)),
    ]);

    expect(topology.vertices, hasLength(5));
    expect(topology.cells, hasLength(8));
    expect(topology.edges, hasLength(24));
    expect(
      topology.cells.map((cell) => cell.sourceCategory).toList(),
      const [
        VoronoiSourceCategory.segmentStartPoint,
        VoronoiSourceCategory.segment,
        VoronoiSourceCategory.segmentEndPoint,
        VoronoiSourceCategory.segment,
        VoronoiSourceCategory.segment,
        VoronoiSourceCategory.segmentEndPoint,
        VoronoiSourceCategory.segment,
        VoronoiSourceCategory.segmentEndPoint,
      ],
    );
    expect(
      topology.cells.map((cell) => cell.sourceIndex).toList(),
      [0, 3, 2, 0, 2, 0, 1, 1],
    );
    expect(topology.vertex(3).point.x, 50);
    expect(topology.vertex(3).point.y, 50);
    expect(topology.edge(6).finite, true);
    expect(topology.edge(6).twinId, 7);
    expect(topology.edge(6).rotNextId, 16);
  });

  test('VoronoiTopology accepts Boost line edge with both endpoints infinite', () {
    final topology = VoronoiTopology2(
      vertices: const [],
      cells: const [
        VoronoiCell2(
          sourceIndex: 0,
          sourceCategory: VoronoiSourceCategory.segmentStartPoint,
          incidentEdgeId: 0,
        ),
        VoronoiCell2(
          sourceIndex: 1,
          sourceCategory: VoronoiSourceCategory.segmentEndPoint,
          incidentEdgeId: 1,
        ),
      ],
      edges: const [
        VoronoiHalfEdge2(
          id: 0,
          vertex0: null,
          vertex1: null,
          cellIndex: 0,
          twinId: 1,
          rotNextId: 1,
          nextId: 0,
          prevId: 0,
          finite: false,
        ),
        VoronoiHalfEdge2(
          id: 1,
          vertex0: null,
          vertex1: null,
          cellIndex: 1,
          twinId: 0,
          rotNextId: 0,
          nextId: 1,
          prevId: 1,
          finite: false,
        ),
      ],
    );

    expect(topology.edge(0).infinite, true);
    expect(topology.edge(0).vertex0, isNull);
    expect(topology.edge(0).vertex1, isNull);
  });
}
