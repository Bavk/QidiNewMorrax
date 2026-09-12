import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_voronoi_diagram.dart';
import 'package:qidi_flow_flutter/core/geometry/source_voronoi_utils.dart';
import 'package:qidi_flow_flutter/core/geometry/voronoi_topology.dart';

void main() {
  const driver = SourceVoronoiDiagram2();
  const segment = BoundarySegment2(
    SourcePoint2(0, 0),
    SourcePoint2(10, 0),
  );

  test('VoronoiUtils::to_point uses source llround halfway-away semantics', () {
    expect(
      SourceVoronoiUtils2.toPoint(const VoronoiPoint2(0.5, -0.5)),
      const SourcePoint2(1, -1),
    );
  });

  test('detect_known_issues prioritizes finite edge with non-finite vertex', () {
    final topology = VoronoiTopology2(
      vertices: const [
        VoronoiVertex2(point: VoronoiPoint2(double.nan, 0)),
        VoronoiVertex2(point: VoronoiPoint2(1, 0)),
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

    expect(
      driver.detectKnownIssues(topology, const [segment]),
      SourceVoronoiIssueType2.finiteEdgeWithNonFiniteVertex,
    );
  });

  test('missing Segment-cell incident/range is MISSING_VORONOI_VERTEX', () {
    final topology = _missingSegmentRangeTopology();
    expect(
      driver.detectKnownIssues(topology, const [segment]),
      SourceVoronoiIssueType2.missingVoronoiVertex,
    );
  });

  test('cell-range edge on wrong side detects source-segment intersection', () {
    final topology = _segmentCellTopology(segment, leftSide: false);
    expect(
      driver.detectKnownIssues(topology, const [segment]),
      SourceVoronoiIssueType2.voronoiEdgeIntersectingInputSegment,
    );
  });

  test('valid Segment-cell range returns NO_ISSUE_DETECTED', () {
    final topology = _segmentCellTopology(segment, leftSide: true);
    expect(
      driver.detectKnownIssues(topology, const [segment]),
      SourceVoronoiIssueType2.noIssueDetected,
    );
  });

  test('repair uses source first angle and remaps endpoints exactly', () {
    var calls = 0;
    List<BoundarySegment2>? firstRepairInput;

    final result = driver.construct(
      const [segment],
      builder: (segments) {
        calls++;
        if (calls == 1) return _missingSegmentRangeTopology();
        firstRepairInput ??= List<BoundarySegment2>.of(segments);
        return _segmentCellTopology(segments.single, leftSide: true);
      },
    );

    expect(calls, 2);
    expect(result.state, SourceVoronoiState2.repairSuccessful);
    expect(result.issueType, SourceVoronoiIssueType2.noIssueDetected);
    expect(firstRepairInput!.single.a, segment.a.rotated(math.pi / 6));
    expect(firstRepairInput!.single.b, segment.b.rotated(math.pi / 6));

    // Range edge_begin.vertex0 maps to source HIGH (`to`) and
    // edge_end.vertex1 maps to source LOW (`from`) before rotate-back.
    expect(result.topology.vertex(0).point.x, 10);
    expect(result.topology.vertex(0).point.y, 0);
    expect(result.topology.vertex(2).point.x, 0);
    expect(result.topology.vertex(2).point.y, 0);
  });

  test('repair tries exactly PI/6, PI/5, PI/7, PI/11 then fails', () {
    var calls = 0;
    final seen = <BoundarySegment2>[];
    final result = driver.construct(
      const [segment],
      builder: (segments) {
        calls++;
        if (calls > 1) seen.add(segments.single);
        return _missingSegmentRangeTopology();
      },
    );

    expect(calls, 5);
    expect(seen, hasLength(4));
    expect(seen[0].b, segment.b.rotated(math.pi / 6));
    expect(seen[1].b, segment.b.rotated(math.pi / 5));
    expect(seen[2].b, segment.b.rotated(math.pi / 7));
    expect(seen[3].b, segment.b.rotated(math.pi / 11));
    expect(result.state, SourceVoronoiState2.repairUnsuccessful);
    expect(result.issueType, SourceVoronoiIssueType2.missingVoronoiVertex);
  });

  test('repairs-disabled source contract reports UNKNOWN state and issue', () {
    var calls = 0;
    final result = driver.construct(
      const [segment],
      tryToRepairIfNeeded: false,
      builder: (segments) {
        calls++;
        return _missingSegmentRangeTopology();
      },
    );
    expect(calls, 1);
    expect(result.state, SourceVoronoiState2.unknown);
    expect(result.issueType, SourceVoronoiIssueType2.unknown);
  });
}

VoronoiTopology2 _missingSegmentRangeTopology() => VoronoiTopology2(
      vertices: const [],
      cells: const [
        VoronoiCell2(
          sourceIndex: 0,
          sourceCategory: VoronoiSourceCategory.segment,
        ),
      ],
      edges: const [],
    );

VoronoiTopology2 _segmentCellTopology(
  BoundarySegment2 segment, {
  required bool leftSide,
}) {
  final from = segment.a;
  final to = segment.b;
  final dx = to.x - from.x;
  final dy = to.y - from.y;
  final midpoint = SourcePoint2(
    ((from.x + to.x) / 2).truncate(),
    ((from.y + to.y) / 2).truncate(),
  );
  final side = leftSide
      ? SourcePoint2(midpoint.x - dy, midpoint.y + dx)
      : SourcePoint2(midpoint.x + dy, midpoint.y - dx);

  return VoronoiTopology2(
    vertices: [
      VoronoiVertex2(
        point: VoronoiPoint2(to.x.toDouble(), to.y.toDouble()),
        incidentEdgeId: 0,
      ),
      VoronoiVertex2(
        point: VoronoiPoint2(side.x.toDouble(), side.y.toDouble()),
        incidentEdgeId: 0,
      ),
      VoronoiVertex2(
        point: VoronoiPoint2(from.x.toDouble(), from.y.toDouble()),
        incidentEdgeId: 2,
      ),
    ],
    cells: const [
      VoronoiCell2(
        sourceIndex: 0,
        sourceCategory: VoronoiSourceCategory.segment,
        incidentEdgeId: 0,
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
        nextId: 2,
        prevId: 2,
      ),
      VoronoiHalfEdge2(
        id: 1,
        vertex0: 1,
        vertex1: 0,
        cellIndex: 1,
        twinId: 0,
        rotNextId: 1,
      ),
      VoronoiHalfEdge2(
        id: 2,
        vertex0: 1,
        vertex1: 2,
        cellIndex: 0,
        twinId: 3,
        rotNextId: 2,
        nextId: 0,
        prevId: 0,
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
