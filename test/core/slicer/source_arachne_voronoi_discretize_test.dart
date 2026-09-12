import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/voronoi_topology.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_polygon_indices.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_voronoi_discretize.dart';

VoronoiTopology2 _twoCellEdge({
  required VoronoiCell2 left,
  required VoronoiCell2 right,
  required SourcePoint2 start,
  required SourcePoint2 end,
  bool primary = true,
}) =>
    VoronoiTopology2(
      vertices: [
        VoronoiVertex2(
          point: VoronoiPoint2(start.x.toDouble(), start.y.toDouble()),
        ),
        VoronoiVertex2(
          point: VoronoiPoint2(end.x.toDouble(), end.y.toDouble()),
        ),
      ],
      cells: [left, right],
      edges: [
        VoronoiHalfEdge2(
          id: 0,
          vertex0: 0,
          vertex1: 1,
          cellIndex: 0,
          twinId: 1,
          rotNextId: 0,
          primary: primary,
        ),
        VoronoiHalfEdge2(
          id: 1,
          vertex0: 1,
          vertex1: 0,
          cellIndex: 1,
          twinId: 0,
          rotNextId: 1,
          primary: primary,
        ),
      ],
    );

SourceArachnePolygonSegments2 _pointPairSegments() =>
    SourceArachnePolygonSegments2([
      SourcePolygon2(const [
        SourcePoint2(-1000, 0),
        SourcePoint2(1000, 0),
        SourcePoint2(0, 10000),
      ]),
    ]);

SourceArachnePolygonSegments2 _parabolaSegments() =>
    SourceArachnePolygonSegments2([
      SourcePolygon2(const [
        SourcePoint2(0, 0),
        SourcePoint2(1000, -1000),
        SourcePoint2(-1000, -1000),
      ]),
      SourcePolygon2(const [
        SourcePoint2(-4000, 2000),
        SourcePoint2(4000, 2000),
        SourcePoint2(0, 5000),
      ]),
    ]);

void main() {
  test('segment-segment Voronoi edge remains a source two-point line', () {
    final source = _pointPairSegments();
    final topology = _twoCellEdge(
      left: const VoronoiCell2(
        sourceIndex: 0,
        sourceCategory: VoronoiSourceCategory.segment,
      ),
      right: const VoronoiCell2(
        sourceIndex: 1,
        sourceCategory: VoronoiSourceCategory.segment,
      ),
      start: const SourcePoint2(0, -2000),
      end: const SourcePoint2(0, 2000),
    );

    expect(
      SourceArachneVoronoiDiscretize2.discretize(
        topology,
        0,
        source,
        discretizationStepSize: 1000,
        transitioningAngle: math.pi / 2,
      ),
      const [SourcePoint2(0, -2000), SourcePoint2(0, 2000)],
    );
  });

  test('secondary point-point edge bypasses source discretization', () {
    final source = _pointPairSegments();
    final topology = _twoCellEdge(
      left: const VoronoiCell2(
        sourceIndex: 0,
        sourceCategory: VoronoiSourceCategory.segmentStartPoint,
      ),
      right: const VoronoiCell2(
        sourceIndex: 0,
        sourceCategory: VoronoiSourceCategory.segmentEndPoint,
      ),
      start: const SourcePoint2(0, -2000),
      end: const SourcePoint2(0, 2000),
      primary: false,
    );

    expect(
      SourceArachneVoronoiDiscretize2.discretize(
        topology,
        0,
        source,
        discretizationStepSize: 1000,
        transitioningAngle: math.pi / 2,
      ),
      const [SourcePoint2(0, -2000), SourcePoint2(0, 2000)],
    );
  });

  test('point-point branch matches standalone C++ oracle including duplicates', () {
    final source = _pointPairSegments();
    final topology = _twoCellEdge(
      left: const VoronoiCell2(
        sourceIndex: 0,
        sourceCategory: VoronoiSourceCategory.segmentStartPoint,
      ),
      right: const VoronoiCell2(
        sourceIndex: 0,
        sourceCategory: VoronoiSourceCategory.segmentEndPoint,
      ),
      start: const SourcePoint2(0, -2000),
      end: const SourcePoint2(0, 2000),
    );

    expect(
      SourceArachneVoronoiDiscretize2.discretize(
        topology,
        0,
        source,
        discretizationStepSize: 1000,
        transitioningAngle: math.pi / 2,
      ),
      const [
        SourcePoint2(0, -2000),
        SourcePoint2(0, -1000),
        SourcePoint2(0, -1000),
        SourcePoint2(0, 0),
        SourcePoint2(0, 1000),
        SourcePoint2(0, 1000),
        SourcePoint2(0, 2000),
      ],
    );
  });

  test('reversed point-point edge preserves reversed C++ oracle order', () {
    final source = _pointPairSegments();
    final topology = _twoCellEdge(
      left: const VoronoiCell2(
        sourceIndex: 0,
        sourceCategory: VoronoiSourceCategory.segmentStartPoint,
      ),
      right: const VoronoiCell2(
        sourceIndex: 0,
        sourceCategory: VoronoiSourceCategory.segmentEndPoint,
      ),
      start: const SourcePoint2(0, 2000),
      end: const SourcePoint2(0, -2000),
    );

    expect(
      SourceArachneVoronoiDiscretize2.discretize(
        topology,
        0,
        source,
        discretizationStepSize: 1000,
        transitioningAngle: math.pi / 2,
      ),
      const [
        SourcePoint2(0, 2000),
        SourcePoint2(0, 1000),
        SourcePoint2(0, 1000),
        SourcePoint2(0, 0),
        SourcePoint2(0, -1000),
        SourcePoint2(0, -1000),
        SourcePoint2(0, -2000),
      ],
    );
  });

  test('point-line parabola matches standalone C++ float-angle oracle', () {
    final source = _parabolaSegments();
    final topology = _twoCellEdge(
      left: const VoronoiCell2(
        sourceIndex: 0,
        sourceCategory: VoronoiSourceCategory.segmentStartPoint,
      ),
      right: const VoronoiCell2(
        sourceIndex: 3,
        sourceCategory: VoronoiSourceCategory.segment,
      ),
      start: const SourcePoint2(2000, 0),
      end: const SourcePoint2(-2000, 0),
    );

    expect(
      SourceArachneVoronoiDiscretize2.discretize(
        topology,
        0,
        source,
        discretizationStepSize: 2000,
        transitioningAngle: 1.0,
      ),
      const [
        SourcePoint2(2000, 0),
        SourcePoint2(-927, 786),
        SourcePoint2(0, 1000),
        SourcePoint2(0, 1000),
        SourcePoint2(927, 786),
        SourcePoint2(-2000, 0),
      ],
    );
  });

  test('parabola denser step fixture matches standalone C++ oracle', () {
    final source = _parabolaSegments();
    final topology = _twoCellEdge(
      left: const VoronoiCell2(
        sourceIndex: 0,
        sourceCategory: VoronoiSourceCategory.segmentStartPoint,
      ),
      right: const VoronoiCell2(
        sourceIndex: 3,
        sourceCategory: VoronoiSourceCategory.segment,
      ),
      start: const SourcePoint2(2000, 0),
      end: const SourcePoint2(-2000, 0),
    );

    expect(
      SourceArachneVoronoiDiscretize2.discretize(
        topology,
        0,
        source,
        discretizationStepSize: 1000,
        transitioningAngle: 1.0,
      ),
      const [
        SourcePoint2(2000, 0),
        SourcePoint2(-1000, 750),
        SourcePoint2(-927, 786),
        SourcePoint2(0, 1000),
        SourcePoint2(0, 1000),
        SourcePoint2(927, 786),
        SourcePoint2(1000, 750),
        SourcePoint2(-2000, 0),
      ],
    );
  });

  test('coord_t range guard rejects finite Voronoi vertex beyond int32', () {
    final source = _pointPairSegments();
    final topology = VoronoiTopology2(
      vertices: const [
        VoronoiVertex2(point: VoronoiPoint2(2147483648.0, 0)),
        VoronoiVertex2(point: VoronoiPoint2(0, 0)),
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

    expect(
      () => SourceArachneVoronoiDiscretize2.discretize(
        topology,
        0,
        source,
        discretizationStepSize: 1000,
        transitioningAngle: 1.0,
      ),
      throwsStateError,
    );
  });
}
