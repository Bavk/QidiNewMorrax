import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/voronoi_topology.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_polygon_indices.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_voronoi_transfer.dart';

SourcePolygon2 _square() => SourcePolygon2(const [
      SourcePoint2(0, 0),
      SourcePoint2(10000, 0),
      SourcePoint2(10000, 10000),
      SourcePoint2(0, 10000),
    ]);

VoronoiTopology2 _pointCellTopology(
  SourcePoint2 query, {
  bool middlePrimary = true,
}) {
  final vertices = <VoronoiVertex2>[
    const VoronoiVertex2(point: VoronoiPoint2(0, 0)),
    VoronoiVertex2(
      point: VoronoiPoint2(query.x.toDouble(), query.y.toDouble()),
    ),
    const VoronoiVertex2(point: VoronoiPoint2(10000, 10000)),
  ];
  return VoronoiTopology2(
    vertices: vertices,
    cells: const [
      VoronoiCell2(
        sourceIndex: 0,
        sourceCategory: VoronoiSourceCategory.segmentStartPoint,
        incidentEdgeId: 0,
      ),
      VoronoiCell2(
        sourceIndex: 0,
        sourceCategory: VoronoiSourceCategory.segment,
      ),
      VoronoiCell2(
        sourceIndex: 1,
        sourceCategory: VoronoiSourceCategory.segment,
      ),
      VoronoiCell2(
        sourceIndex: 3,
        sourceCategory: VoronoiSourceCategory.segment,
      ),
    ],
    edges: [
      const VoronoiHalfEdge2(
        id: 0,
        vertex0: 0,
        vertex1: 1,
        cellIndex: 0,
        twinId: 3,
        rotNextId: 0,
        nextId: 1,
        prevId: 2,
      ),
      VoronoiHalfEdge2(
        id: 1,
        vertex0: 1,
        vertex1: 2,
        cellIndex: 0,
        twinId: 4,
        rotNextId: 1,
        nextId: 2,
        prevId: 0,
        primary: middlePrimary,
      ),
      const VoronoiHalfEdge2(
        id: 2,
        vertex0: 2,
        vertex1: 0,
        cellIndex: 0,
        twinId: 5,
        rotNextId: 2,
        nextId: 0,
        prevId: 1,
      ),
      const VoronoiHalfEdge2(
        id: 3,
        vertex0: 1,
        vertex1: 0,
        cellIndex: 1,
        twinId: 0,
        rotNextId: 3,
      ),
      VoronoiHalfEdge2(
        id: 4,
        vertex0: 2,
        vertex1: 1,
        cellIndex: 2,
        twinId: 1,
        rotNextId: 4,
        primary: middlePrimary,
      ),
      const VoronoiHalfEdge2(
        id: 5,
        vertex0: 0,
        vertex1: 2,
        cellIndex: 3,
        twinId: 2,
        rotNextId: 5,
      ),
    ],
  );
}

VoronoiTopology2 _infiniteIncidentTopology() => VoronoiTopology2(
      vertices: const [],
      cells: const [
        VoronoiCell2(
          sourceIndex: 0,
          sourceCategory: VoronoiSourceCategory.segmentStartPoint,
          incidentEdgeId: 0,
        ),
        VoronoiCell2(
          sourceIndex: 0,
          sourceCategory: VoronoiSourceCategory.segment,
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
          rotNextId: 0,
          finite: false,
        ),
        VoronoiHalfEdge2(
          id: 1,
          vertex0: null,
          vertex1: null,
          cellIndex: 1,
          twinId: 0,
          rotNextId: 1,
          finite: false,
        ),
      ],
    );

VoronoiTopology2 _hugeIncidentTopology() => VoronoiTopology2(
      vertices: const [
        VoronoiVertex2(
          point: VoronoiPoint2(9223372036854775808.0, 0),
        ),
        VoronoiVertex2(point: VoronoiPoint2(0, 0)),
      ],
      cells: const [
        VoronoiCell2(
          sourceIndex: 0,
          sourceCategory: VoronoiSourceCategory.segmentStartPoint,
          incidentEdgeId: 0,
        ),
        VoronoiCell2(
          sourceIndex: 0,
          sourceCategory: VoronoiSourceCategory.segment,
          incidentEdgeId: 1,
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
          nextId: 0,
          prevId: 0,
        ),
        VoronoiHalfEdge2(
          id: 1,
          vertex0: 1,
          vertex1: 0,
          cellIndex: 1,
          twinId: 0,
          rotNextId: 1,
          nextId: 1,
          prevId: 1,
        ),
      ],
    );

void main() {
  test('polygon segment indexes flatten source polygon/point order exactly', () {
    final square = _square();
    final triangle = SourcePolygon2(const [
      SourcePoint2(20000, 0),
      SourcePoint2(30000, 0),
      SourcePoint2(25000, 10000),
    ]);
    final source = SourceArachnePolygonSegments2([square, triangle]);

    expect(source.indices, hasLength(7));
    expect(source.boundarySegments, hasLength(7));
    expect(source.indices[0].polygonIndex, 0);
    expect(source.indices[0].localPointIndex, 0);
    expect(source.indices[0].from, const SourcePoint2(0, 0));
    expect(source.indices[0].to, const SourcePoint2(10000, 0));
    expect(source.indices[3].from, const SourcePoint2(0, 10000));
    expect(source.indices[3].to, const SourcePoint2(0, 0));
    expect(source.indices[4].polygonIndex, 1);
    expect(source.indices[4].localPointIndex, 0);
    expect(source.indices[4].pointIndex.polygons, same(source.polygons));
  });

  test('get_source_point_index maps start and end categories through segment', () {
    final source = SourceArachnePolygonSegments2([_square()]);
    final start = source.sourcePointIndex(const VoronoiCell2(
      sourceIndex: 0,
      sourceCategory: VoronoiSourceCategory.segmentStartPoint,
    ));
    final end = source.sourcePointIndex(const VoronoiCell2(
      sourceIndex: 3,
      sourceCategory: VoronoiSourceCategory.segmentEndPoint,
    ));

    expect((start.polygonIndex, start.pointIndex), (0, 0));
    expect(start.p, const SourcePoint2(0, 0));
    expect((end.polygonIndex, end.pointIndex), (0, 0));
    expect(end.p, const SourcePoint2(0, 0));
    expect(end.prev().p, const SourcePoint2(0, 10000));
    expect(end.next().p, const SourcePoint2(10000, 0));
  });

  test('isInsideCorner matches pinned convex-corner orientation', () {
    const a = SourcePoint2(0, 10000);
    const b = SourcePoint2(0, 0);
    const c = SourcePoint2(10000, 0);

    expect(
      SourceArachneVoronoiTransfer2.isInsideCorner(
        a,
        b,
        c,
        const SourcePoint2(5000, 5000),
      ),
      isTrue,
    );
    expect(
      SourceArachneVoronoiTransfer2.isInsideCorner(
        a,
        b,
        c,
        const SourcePoint2(-5000, -5000),
      ),
      isFalse,
    );
  });

  test('point cell range returns next edge after edge ending at source point', () {
    final source = SourceArachnePolygonSegments2([_square()]);
    final result = SourceArachneVoronoiTransfer2.computePointCellRange(
      _pointCellTopology(const SourcePoint2(5000, 5000)),
      0,
      source,
    );

    expect(result, isNotNull);
    expect(result!.sourcePoint, const SourcePoint2(0, 0));
    expect(result.sourcePointIndex.polygonIndex, 0);
    expect(result.sourcePointIndex.pointIndex, 0);
    expect(result.startingVdEdgeId, 0);
    expect(result.endingVdEdgeId, 2);
  });

  test('point cell assertion rejects secondary edge not starting at source', () {
    final source = SourceArachnePolygonSegments2([_square()]);

    expect(
      () => SourceArachneVoronoiTransfer2.computePointCellRange(
        _pointCellTopology(
          const SourcePoint2(5000, 5000),
          middlePrimary: false,
        ),
        0,
        source,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('point cell outside source corner is rejected before edge transfer', () {
    final source = SourceArachnePolygonSegments2([_square()]);

    expect(
      SourceArachneVoronoiTransfer2.computePointCellRange(
        _pointCellTopology(const SourcePoint2(-5000, -5000)),
        0,
        source,
      ),
      isNull,
    );
  });

  test('point cell with infinite incident edge is rejected immediately', () {
    final source = SourceArachnePolygonSegments2([_square()]);

    expect(
      SourceArachneVoronoiTransfer2.computePointCellRange(
        _infiniteIncidentTopology(),
        0,
        source,
      ),
      isNull,
    );
  });

  test('point cell rejects incident vertex at int64 positive limit', () {
    final source = SourceArachnePolygonSegments2([_square()]);

    expect(
      SourceArachneVoronoiTransfer2.computePointCellRange(
        _hugeIncidentTopology(),
        0,
        source,
      ),
      isNull,
    );
  });
}
