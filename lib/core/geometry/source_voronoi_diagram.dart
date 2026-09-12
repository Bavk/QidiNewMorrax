import 'dart:math' as math;

import 'source_geometry.dart';
import 'source_voronoi_utils.dart';
import 'voronoi_topology.dart';

enum SourceVoronoiIssueType2 {
  noIssueDetected,
  finiteEdgeWithNonFiniteVertex,
  missingVoronoiVertex,
  nonPlanarVoronoiDiagram,
  voronoiEdgeIntersectingInputSegment,
  unknown,
}

enum SourceVoronoiState2 {
  repairNotNeeded,
  repairSuccessful,
  repairUnsuccessful,
  unknown,
}

typedef SourceVoronoiTopologyBuilder2 = VoronoiTopology2 Function(
  List<BoundarySegment2> segments,
);

class SourceVoronoiBuildResult2 {
  const SourceVoronoiBuildResult2({
    required this.topology,
    required this.issueType,
    required this.state,
  });

  final VoronoiTopology2 topology;
  final SourceVoronoiIssueType2 issueType;
  final SourceVoronoiState2 state;

  bool get isValid => state != SourceVoronoiState2.repairUnsuccessful;
}

/// Application-owned wrapper logic from `Geometry/Voronoi.cpp`.
///
/// The exact Boost.Polygon segment Fortune builder is intentionally injected;
/// this class ports QIDI issue detection, repair scheduling and the rotate-
/// back endpoint remapping around it without substituting a different Voronoi
/// implementation.
class SourceVoronoiDiagram2 {
  const SourceVoronoiDiagram2();

  static const List<double> repairAngles = [
    math.pi / 6,
    math.pi / 5,
    math.pi / 7,
    math.pi / 11,
  ];

  SourceVoronoiBuildResult2 construct(
    List<BoundarySegment2> segments, {
    required SourceVoronoiTopologyBuilder2 builder,
    bool tryToRepairIfNeeded = true,
  }) {
    var topology = builder(List<BoundarySegment2>.of(segments));
    if (!tryToRepairIfNeeded) {
      return SourceVoronoiBuildResult2(
        topology: topology,
        issueType: SourceVoronoiIssueType2.unknown,
        state: SourceVoronoiState2.unknown,
      );
    }

    var issue = detectKnownIssues(topology, segments);
    if (issue == SourceVoronoiIssueType2.noIssueDetected) {
      return SourceVoronoiBuildResult2(
        topology: topology,
        issueType: SourceVoronoiIssueType2.noIssueDetected,
        state: SourceVoronoiState2.repairNotNeeded,
      );
    }

    for (final angle in repairAngles) {
      final rotatedSegments = [
        for (final segment in segments)
          BoundarySegment2(
            segment.a.rotated(angle),
            segment.b.rotated(angle),
          ),
      ];
      final rotatedTopology = builder(rotatedSegments);
      issue = detectKnownIssues(rotatedTopology, rotatedSegments);
      topology = _rotateBackAndRemapEndpoints(
        rotatedTopology,
        rotatedSegments,
        segments,
        angle,
      );
      if (issue == SourceVoronoiIssueType2.noIssueDetected) {
        return SourceVoronoiBuildResult2(
          topology: topology,
          issueType: issue,
          state: SourceVoronoiState2.repairSuccessful,
        );
      }
    }

    return SourceVoronoiBuildResult2(
      topology: topology,
      issueType: issue,
      state: SourceVoronoiState2.repairUnsuccessful,
    );
  }

  SourceVoronoiIssueType2 detectKnownIssues(
    VoronoiTopology2 topology,
    List<BoundarySegment2> segments,
  ) {
    if (_hasFiniteEdgeWithNonFiniteVertex(topology)) {
      return SourceVoronoiIssueType2.finiteEdgeWithNonFiniteVertex;
    }

    final cellIssue = _detectKnownVoronoiCellIssues(topology, segments);
    if (cellIssue != SourceVoronoiIssueType2.noIssueDetected) {
      return cellIssue;
    }

    // QIDI source explicitly disables the CGAL planar-angle test in this
    // function, so NON_PLANAR is retained in the enum but not produced here.
    return SourceVoronoiIssueType2.noIssueDetected;
  }

  bool _hasFiniteEdgeWithNonFiniteVertex(VoronoiTopology2 topology) {
    for (final edge in topology.edges) {
      if (!edge.finite) continue;
      final v0 = topology.vertex(edge.vertex0!).point;
      final v1 = topology.vertex(edge.vertex1!).point;
      if (!SourceVoronoiUtils2.isFinitePoint(v0) ||
          !SourceVoronoiUtils2.isFinitePoint(v1)) {
        return true;
      }
    }
    return false;
  }

  SourceVoronoiIssueType2 _detectKnownVoronoiCellIssues(
    VoronoiTopology2 topology,
    List<BoundarySegment2> segments,
  ) {
    for (var cellIndex = 0; cellIndex < topology.cells.length; cellIndex++) {
      final cell = topology.cell(cellIndex);
      if (cell.degenerate || !cell.containsSegment) continue;

      final range = SourceVoronoiUtils2.computeSegmentCellRange(
        topology,
        cellIndex,
        segments,
      );
      if (!range.isValid) {
        return SourceVoronoiIssueType2.missingVoronoiVertex;
      }

      final source = SourceVoronoiUtils2.getSourceSegment(cell, segments);
      final sx = (source.b.x - source.a.x).toDouble();
      final sy = (source.b.y - source.a.y).toDouble();

      var edge = topology.edge(range.edgeBeginId!);
      var guard = 0;
      while (edge.id != range.edgeEndId) {
        if (edge.infinite) {
          return SourceVoronoiIssueType2.missingVoronoiVertex;
        }
        final vertex1 = topology.vertex(edge.vertex1!).point;
        final vx = vertex1.x - source.a.x;
        final vy = vertex1.y - source.a.y;
        final cross = sx * vy - sy * vx;
        if (cross < 0) {
          return SourceVoronoiIssueType2.voronoiEdgeIntersectingInputSegment;
        }
        final nextId = edge.nextId;
        if (nextId == null) {
          return SourceVoronoiIssueType2.missingVoronoiVertex;
        }
        edge = topology.edge(nextId);
        if (++guard > topology.edges.length) {
          return SourceVoronoiIssueType2.missingVoronoiVertex;
        }
      }
    }
    return SourceVoronoiIssueType2.noIssueDetected;
  }

  VoronoiTopology2 _rotateBackAndRemapEndpoints(
    VoronoiTopology2 rotatedTopology,
    List<BoundarySegment2> rotatedSegments,
    List<BoundarySegment2> originalSegments,
    double angle,
  ) {
    // Source encodes input segment endpoints into vertex.color() before
    // rotating back. A map gives the same first-write-wins behavior here.
    final endpointMapping = <int, SourcePoint2>{};

    for (var cellIndex = 0;
        cellIndex < rotatedTopology.cells.length;
        cellIndex++) {
      final cell = rotatedTopology.cell(cellIndex);
      if (cell.degenerate || !cell.containsSegment) continue;
      final range = SourceVoronoiUtils2.computeSegmentCellRange(
        rotatedTopology,
        cellIndex,
        rotatedSegments,
      );
      if (!range.isValid) continue;

      final original = originalSegments[cell.sourceIndex];
      final edgeEnd = rotatedTopology.edge(range.edgeEndId!);
      final edgeBegin = rotatedTopology.edge(range.edgeBeginId!);
      if (edgeEnd.vertex1 != null) {
        endpointMapping.putIfAbsent(edgeEnd.vertex1!, () => original.a);
      }
      if (edgeBegin.vertex0 != null) {
        endpointMapping.putIfAbsent(edgeBegin.vertex0!, () => original.b);
      }
    }

    final vertices = <VoronoiVertex2>[];
    for (var index = 0; index < rotatedTopology.vertices.length; index++) {
      final vertex = rotatedTopology.vertex(index);
      final mapped = endpointMapping[index];
      if (mapped != null) {
        vertices.add(VoronoiVertex2(
          point: VoronoiPoint2(mapped.x.toDouble(), mapped.y.toDouble()),
          incidentEdgeId: vertex.incidentEdgeId,
        ));
      } else {
        final rotatedBack = SourceVoronoiUtils2.makeRotatedVertex(
          vertex,
          -angle,
        );
        vertices.add(VoronoiVertex2(
          point: rotatedBack.point,
          incidentEdgeId: rotatedBack.incidentEdgeId,
        ));
      }
    }

    return VoronoiTopology2(
      vertices: vertices,
      cells: [
        for (final cell in rotatedTopology.cells)
          VoronoiCell2(
            sourceIndex: cell.sourceIndex,
            sourceCategory: cell.sourceCategory,
            incidentEdgeId: cell.incidentEdgeId,
            degenerate: cell.degenerate,
          ),
      ],
      edges: [
        for (final edge in rotatedTopology.edges)
          VoronoiHalfEdge2(
            id: edge.id,
            vertex0: edge.vertex0,
            vertex1: edge.vertex1,
            cellIndex: edge.cellIndex,
            twinId: edge.twinId,
            rotNextId: edge.rotNextId,
            nextId: edge.nextId,
            prevId: edge.prevId,
            primary: edge.primary,
            linear: edge.linear,
            finite: edge.finite,
          ),
      ],
    );
  }
}
