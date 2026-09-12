import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/medial_axis_core.dart';
import 'package:qidi_flow_flutter/core/geometry/point.dart';
import 'package:qidi_flow_flutter/core/geometry/voronoi_topology.dart';

const facingSegments = [
  BoundarySegment2(Point2(0, 0), Point2(0, 10)),
  BoundarySegment2(Point2(2, 10), Point2(2, 0)),
];

VoronoiTopology2 oneEdgeTopology({
  List<BoundarySegment2> segments = facingSegments,
}) {
  return VoronoiTopology2(
    vertices: const [
      VoronoiVertex2(
        point: Point2(1, 2),
        category: VoronoiVertexCategory.inside,
      ),
      VoronoiVertex2(
        point: Point2(1, 8),
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
      minWidth: 1,
      maxWidth: 3,
      boundarySegments: facingSegments,
    );
    final result = core.buildFromTopology(oneEdgeTopology());

    expect(result, hasLength(1));
    expect(result.single.width, [2, 2]);
    expect(result.single.startIsEndpoint, true);
    expect(result.single.endIsEndpoint, true);
  });

  test('validate_edge rejects non-facing long segment pair using PI/8 rule', () {
    const sameDirection = [
      BoundarySegment2(Point2(0, 0), Point2(0, 10)),
      BoundarySegment2(Point2(2, 0), Point2(2, 10)),
    ];
    final core = MedialAxisCore(
      minWidth: 1,
      maxWidth: 3,
      boundarySegments: sameDirection,
    );

    expect(core.buildFromTopology(oneEdgeTopology()), isEmpty);
  });

  test('validate_edge rejects edges with both endpoint widths above max', () {
    final core = MedialAxisCore(
      minWidth: 0.5,
      maxWidth: 1.5,
      boundarySegments: facingSegments,
    );
    expect(core.buildFromTopology(oneEdgeTopology()), isEmpty);
  });

  test('process_edge_neighbors chains a single active neighbor', () {
    final topology = VoronoiTopology2(
      vertices: const [
        VoronoiVertex2(
          point: Point2(1, 1),
          category: VoronoiVertexCategory.inside,
        ),
        VoronoiVertex2(
          point: Point2(1, 4),
          category: VoronoiVertexCategory.inside,
        ),
        VoronoiVertex2(
          point: Point2(1, 8),
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
      minWidth: 1,
      maxWidth: 3,
      boundarySegments: facingSegments,
    ).buildFromTopology(topology);

    expect(result, hasLength(1));
    expect(result.single.points.map((p) => p.y).toList(), [1, 4, 8]);
    expect(result.single.width, [2, 2, 2, 2]);
    expect(result.single.startIsEndpoint, true);
    expect(result.single.endIsEndpoint, true);
  });

  test('Voronoi vertices are quantized like source double -> coord_t cast', () {
    final topology = VoronoiTopology2(
      vertices: const [
        VoronoiVertex2(
          point: Point2(1.000019, 2.000019),
          category: VoronoiVertexCategory.inside,
        ),
        VoronoiVertex2(
          point: Point2(1.000019, 8.000019),
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
      minWidth: 1,
      maxWidth: 3,
      boundarySegments: facingSegments,
    ).buildFromTopology(topology);

    expect(result.single.firstPoint.x, 1.00001);
    expect(result.single.firstPoint.y, 2.00001);
  });
}
