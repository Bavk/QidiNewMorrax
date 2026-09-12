import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_voronoi_annotation.dart';
import 'package:qidi_flow_flutter/core/geometry/voronoi_topology.dart';

const boundary = [
  BoundarySegment2(SourcePoint2(0, 0), SourcePoint2(10, 0)),
];

void main() {
  const annotator = SourceVoronoiAnnotator2();

  test('topology represents source infinite twin endpoints explicitly', () {
    final topology = _secondaryInfiniteSeed();
    expect(topology.edge(0).finite, false);
    expect(topology.edge(0).vertex0, 0);
    expect(topology.edge(0).vertex1, isNull);
    expect(topology.edge(1).vertex0, isNull);
    expect(topology.edge(1).vertex1, 0);
  });

  test('secondary infinite edge seeds Outside/Boundary like source', () {
    final result = annotator.annotate(_secondaryInfiniteSeed(), boundary);

    expect(result.vertex(0).category, VoronoiVertexCategory.onContour);
    expect(result.edge(0).category, VoronoiEdgeCategory.pointsOutside);
    expect(result.edge(1).category, VoronoiEdgeCategory.pointsToContour);
    expect(result.cell(0).category, VoronoiCellCategory.outside);
    expect(result.cell(1).category, VoronoiCellCategory.boundary);
  });

  test('Boost ULPS=128 contour equality accepts a one-ULP coordinate merge', () {
    final nextAfterZero = _doubleFromBits(1);
    final topology = VoronoiTopology2(
      vertices: [
        VoronoiVertex2(point: VoronoiPoint2(nextAfterZero, 0)),
      ],
      cells: const [
        VoronoiCell2(
          sourceIndex: 0,
          sourceCategory: VoronoiSourceCategory.segmentStartPoint,
        ),
        VoronoiCell2(
          sourceIndex: 0,
          sourceCategory: VoronoiSourceCategory.segment,
        ),
      ],
      edges: const [
        VoronoiHalfEdge2(
          id: 0,
          vertex0: 0,
          vertex1: null,
          cellIndex: 0,
          twinId: 1,
          rotNextId: 0,
          primary: false,
        ),
        VoronoiHalfEdge2(
          id: 1,
          vertex0: null,
          vertex1: 0,
          cellIndex: 1,
          twinId: 0,
          rotNextId: 1,
          primary: false,
        ),
      ],
    );

    final result = annotator.annotate(topology, boundary);
    expect(result.vertex(0).category, VoronoiVertexCategory.onContour);
  });

  test('Segment-site orientation marks above a CCW bottom edge Inside', () {
    final result = annotator.annotate(
      _segmentToPointThenPointPropagation(inside: true),
      boundary,
    );

    expect(result.vertex(0).category, VoronoiVertexCategory.onContour);
    expect(result.vertex(1).category, VoronoiVertexCategory.inside);
    expect(result.vertex(2).category, VoronoiVertexCategory.inside);
    expect(result.edge(0).category, VoronoiEdgeCategory.pointsInside);
    expect(result.edge(1).category, VoronoiEdgeCategory.pointsToContour);
    expect(result.edge(2).category, VoronoiEdgeCategory.pointsInside);
    expect(result.edge(3).category, VoronoiEdgeCategory.pointsInside);
    expect(result.cell(0).category, VoronoiCellCategory.boundary);
    expect(result.cell(1).category, VoronoiCellCategory.inside);
    expect(result.cell(2).category, VoronoiCellCategory.inside);
  });

  test('Segment-site orientation and Point-cell propagation preserve Outside', () {
    final result = annotator.annotate(
      _segmentToPointThenPointPropagation(inside: false),
      boundary,
    );

    expect(result.vertex(1).category, VoronoiVertexCategory.outside);
    expect(result.vertex(2).category, VoronoiVertexCategory.outside);
    expect(result.edge(0).category, VoronoiEdgeCategory.pointsOutside);
    expect(result.edge(2).category, VoronoiEdgeCategory.pointsOutside);
    expect(result.cell(1).category, VoronoiCellCategory.outside);
    expect(result.cell(2).category, VoronoiCellCategory.outside);
  });
}

VoronoiTopology2 _secondaryInfiniteSeed() => VoronoiTopology2(
      vertices: const [
        VoronoiVertex2(point: VoronoiPoint2(0, 0)),
      ],
      cells: const [
        VoronoiCell2(
          sourceIndex: 0,
          sourceCategory: VoronoiSourceCategory.segmentStartPoint,
        ),
        VoronoiCell2(
          sourceIndex: 0,
          sourceCategory: VoronoiSourceCategory.segment,
        ),
      ],
      edges: const [
        VoronoiHalfEdge2(
          id: 0,
          vertex0: 0,
          vertex1: null,
          cellIndex: 0,
          twinId: 1,
          rotNextId: 0,
          primary: false,
        ),
        VoronoiHalfEdge2(
          id: 1,
          vertex0: null,
          vertex1: 0,
          cellIndex: 1,
          twinId: 0,
          rotNextId: 1,
          primary: false,
        ),
      ],
    );

VoronoiTopology2 _segmentToPointThenPointPropagation({required bool inside}) {
  final y1 = inside ? 5.0 : -5.0;
  final y2 = inside ? 8.0 : -8.0;
  return VoronoiTopology2(
    vertices: [
      const VoronoiVertex2(point: VoronoiPoint2(0, 0)),
      VoronoiVertex2(point: VoronoiPoint2(5, y1)),
      VoronoiVertex2(point: VoronoiPoint2(5, y2)),
    ],
    cells: const [
      VoronoiCell2(
        sourceIndex: 0,
        sourceCategory: VoronoiSourceCategory.segment,
      ),
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
        primary: false,
      ),
      VoronoiHalfEdge2(
        id: 1,
        vertex0: 1,
        vertex1: 0,
        cellIndex: 1,
        twinId: 0,
        rotNextId: 1,
        primary: false,
      ),
      VoronoiHalfEdge2(
        id: 2,
        vertex0: 1,
        vertex1: 2,
        cellIndex: 1,
        twinId: 3,
        rotNextId: 2,
      ),
      VoronoiHalfEdge2(
        id: 3,
        vertex0: 2,
        vertex1: 1,
        cellIndex: 2,
        twinId: 2,
        rotNextId: 3,
      ),
    ],
  );
}

double _doubleFromBits(int bits) {
  final data = ByteData(8)..setUint64(0, bits, Endian.host);
  return data.getFloat64(0, Endian.host);
}
