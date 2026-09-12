import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_medial_axis.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/source_voronoi_diagram.dart';
import 'package:qidi_flow_flutter/core/geometry/voronoi_topology.dart';

void main() {
  final expolygon = SourceExPolygon2(
    contour: SourcePolygon2(const [
      SourcePoint2(0, 0),
      SourcePoint2(1000, 0),
      SourcePoint2(1000, 1000),
      SourcePoint2(0, 1000),
    ]),
  );

  test('MedialAxis::build composes construct, annotate, validate and traversal', () {
    final result = SourceMedialAxis2(
      minWidth: 100,
      maxWidth: 2000,
      expolygon: expolygon,
      voronoiBuilder: _syntheticRectangleBisector,
    ).buildThick();

    expect(result.diagram.state, SourceVoronoiState2.repairNotNeeded);
    expect(result.lines, hasLength(4));
    expect(result.annotatedTopology.vertex(0).category,
        VoronoiVertexCategory.inside);
    expect(result.annotatedTopology.vertex(1).category,
        VoronoiVertexCategory.inside);
    expect(result.polylines, hasLength(1));
    expect(
      result.polylines.single.points,
      const [SourcePoint2(500, 300), SourcePoint2(500, 700)],
    );
    expect(result.polylines.single.width, [1400, 1400]);
    expect(result.polylines.single.startIsEndpoint, true);
    expect(result.polylines.single.endIsEndpoint, true);
  });

  test('MedialAxis::build(Polylines*) drops ThickPolyline metadata only', () {
    final result = SourceMedialAxis2(
      minWidth: 100,
      maxWidth: 2000,
      expolygon: expolygon,
      voronoiBuilder: _syntheticRectangleBisector,
    ).buildPolylines();

    expect(result, hasLength(1));
    expect(
      result.single.points,
      const [SourcePoint2(500, 300), SourcePoint2(500, 700)],
    );
  });

  test('ExPolygon::medial_axis applies source endpoint/pruning postprocess', () {
    final result = SourceExPolygonMedialAxis2.buildThick(
      expolygon: expolygon,
      minWidth: 100,
      maxWidth: 2000,
      voronoiBuilder: _syntheticRectangleBisector,
    );

    // Raw MedialAxis extraction produced the branch, then ExPolygon.cpp extends
    // it to y=0..1000 and removes it because 1000 < 2*max_returned_width(1400).
    expect(result.raw.polylines, hasLength(1));
    expect(result.polylines, isEmpty);
  });

  test('ExPolygon Polylines overload runs ThickPolyline postprocess first', () {
    final result = SourceExPolygonMedialAxis2.buildPolylines(
      expolygon: expolygon,
      minWidth: 100,
      maxWidth: 2000,
      voronoiBuilder: _syntheticRectangleBisector,
    );
    expect(result, isEmpty);
  });
}

VoronoiTopology2 _syntheticRectangleBisector(
  List<BoundarySegment2> segments,
) {
  // Segment cells are marked degenerate only to isolate this composition test
  // from the already separately-tested QIDI repair detector. Annotation and
  // MedialAxis still consume their real source-site indexes (bottom=0, top=2).
  return VoronoiTopology2(
    vertices: const [
      VoronoiVertex2(
        point: VoronoiPoint2(500, 300),
        incidentEdgeId: 0,
      ),
      VoronoiVertex2(
        point: VoronoiPoint2(500, 700),
        incidentEdgeId: 0,
      ),
    ],
    cells: const [
      VoronoiCell2(
        sourceIndex: 0,
        sourceCategory: VoronoiSourceCategory.segment,
        incidentEdgeId: 0,
        degenerate: true,
      ),
      VoronoiCell2(
        sourceIndex: 2,
        sourceCategory: VoronoiSourceCategory.segment,
        incidentEdgeId: 1,
        degenerate: true,
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
}
