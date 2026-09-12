import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/medial_axis_core.dart';
import 'package:qidi_flow_flutter/core/geometry/voronoi_topology.dart';

const facingSegments = [
  BoundarySegment2(SourcePoint2(0, 0), SourcePoint2(0, 1000000)),
  BoundarySegment2(SourcePoint2(200000, 1000000), SourcePoint2(200000, 0)),
];

VoronoiTopology2 oneEdgeTopology() {
  return VoronoiTopology2(
    vertices: const [
      VoronoiVertex2(
        point: VoronoiPoint2(100000, 200000),
        category: VoronoiVertexCategory.inside,
      ),
      VoronoiVertex2(
        point: VoronoiPoint2(100000, 800000),
        category: VoronoiVertexCategory.inside,
      ),
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
}

void main() {
  test('validate_edge accepts facing segment cells and stores doubled width', () {
    final core = MedialAxisCore(
      minWidth: 100000,
      maxWidth: 300000,
      boundarySegments: facingSegments,
    );
    final result = core.buildFromTopology(oneEdgeTopology());

    expect(result, hasLength(1));
    expect(result.single.width, [200000, 200000]);
    expect(result.single.startIsEndpoint, true);
    expect(result.single.endIsEndpoint, true);
  });

  test('validate_edge rejects non-facing long segment pair using PI/8 rule', () {
    const sameDirection = [
      BoundarySegment2(SourcePoint2(0, 0), SourcePoint2(0, 1000000)),
      BoundarySegment2(SourcePoint2(200000, 0), SourcePoint2(200000, 1000000)),
    ];
    final core = MedialAxisCore(
      minWidth: 100000,
      maxWidth: 300000,
      boundarySegments: sameDirection,
    );

    expect(core.buildFromTopology(oneEdgeTopology()), isEmpty);
  });

  test('validate_edge rejects edges with both endpoint widths above max', () {
    final core = MedialAxisCore(
      minWidth: 50000,
      maxWidth: 150000,
      boundarySegments: facingSegments,
    );
    expect(core.buildFromTopology(oneEdgeTopology()), isEmpty);
  });

  test('process_edge_neighbors chains a single active neighbor', () {
    final topology = VoronoiTopology2(
      vertices: const [
        VoronoiVertex2(
          point: VoronoiPoint2(100000, 100000),
          category: VoronoiVertexCategory.inside,
        ),
        VoronoiVertex2(
          point: VoronoiPoint2(100000, 400000),
          category: VoronoiVertexCategory.inside,
        ),
        VoronoiVertex2(
          point: VoronoiPoint2(100000, 800000),
          category: VoronoiVertexCategory.inside,
        ),
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
          rotNextId: 2,
        ),
        VoronoiHalfEdge2(
          id: 2,
          vertex0: 1,
          vertex1: 2,
          cellIndex: 0,
          twinId: 3,
          rotNextId: 1,
        ),
        VoronoiHalfEdge2(
          id: 3,
          vertex0: 2,
          vertex1: 1,
          cellIndex: 1,
          twinId: 2,
          rotNextId: 3,
        ),
      ],
    );

    final result = MedialAxisCore(
      minWidth: 100000,
      maxWidth: 300000,
      boundarySegments: facingSegments,
    ).buildFromTopology(topology);

    expect(result, hasLength(1));
    expect(
      result.single.points.map((p) => p.y).toList(),
      [100000, 400000, 800000],
    );
    expect(result.single.width, [200000, 200000, 200000, 200000]);
    expect(result.single.startIsEndpoint, true);
    expect(result.single.endIsEndpoint, true);
  });

  test('Voronoi double vertices use source Point(double) lrint semantics', () {
    final topology = VoronoiTopology2(
      vertices: const [
        VoronoiVertex2(
          point: VoronoiPoint2(100001.5, 200002.5),
          category: VoronoiVertexCategory.inside,
        ),
        VoronoiVertex2(
          point: VoronoiPoint2(100001.5, 800002.5),
          category: VoronoiVertexCategory.inside,
        ),
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

    final result = MedialAxisCore(
      minWidth: 100000,
      maxWidth: 300000,
      boundarySegments: facingSegments,
    ).buildFromTopology(topology);

    // FE_TONEAREST: 100001.5 -> 100002 (even), 200002.5 -> 200002 (even).
    expect(result.single.firstPoint, const SourcePoint2(100002, 200002));
  });
}
