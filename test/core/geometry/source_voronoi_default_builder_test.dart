import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_voronoi_diagram.dart';
import 'package:qidi_flow_flutter/core/geometry/voronoi_topology.dart';

void main() {
  test('QIDI Voronoi wrapper defaults to direct Boost builder on square', () {
    final result = const SourceVoronoiDiagram2().construct(const [
      BoundarySegment2(SourcePoint2(0, 0), SourcePoint2(100, 0)),
      BoundarySegment2(SourcePoint2(100, 0), SourcePoint2(100, 100)),
      BoundarySegment2(SourcePoint2(100, 100), SourcePoint2(0, 100)),
      BoundarySegment2(SourcePoint2(0, 100), SourcePoint2(0, 0)),
    ]);

    expect(result.state, SourceVoronoiState2.repairNotNeeded);
    expect(result.issueType, SourceVoronoiIssueType2.noIssueDetected);
    expect(result.topology.vertices, hasLength(5));
    expect(result.topology.cells, hasLength(8));
    expect(result.topology.edges, hasLength(24));
    expect(result.topology.vertex(3).point.x, 50);
    expect(result.topology.vertex(3).point.y, 50);
  });

  test('repairs-disabled direct builder preserves source UNKNOWN contract', () {
    final result = const SourceVoronoiDiagram2().construct(
      const [
        BoundarySegment2(SourcePoint2(0, 0), SourcePoint2(100, 0)),
        BoundarySegment2(SourcePoint2(100, 0), SourcePoint2(100, 100)),
        BoundarySegment2(SourcePoint2(100, 100), SourcePoint2(0, 100)),
        BoundarySegment2(SourcePoint2(0, 100), SourcePoint2(0, 0)),
      ],
      tryToRepairIfNeeded: false,
    );

    expect(result.state, SourceVoronoiState2.unknown);
    expect(result.issueType, SourceVoronoiIssueType2.unknown);
    expect(result.topology.edges, hasLength(24));
  });
}
