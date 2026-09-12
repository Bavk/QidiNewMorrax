import 'source_boost_voronoi_builder.dart';
import 'source_boost_voronoi_output.dart';
import 'source_boost_voronoi_structures.dart';
import 'voronoi_topology.dart';

/// Converts the directly ported Boost.Polygon raw diagram into the immutable
/// topology consumed by QIDI's `Geometry/Voronoi*` and `MedialAxis` ports.
///
/// This adapter is intentionally segment-oriented because QIDI's current
/// `SourceVoronoiDiagram2` wrapper receives `BoundarySegment2` input. Raw Boost
/// source categories 0x8/0x9 remain distinguishable until this boundary, then
/// both map to the source-level Segment site category used by QIDI helpers.
class SourceBoostTopologyAdapter2 {
  const SourceBoostTopologyAdapter2._();

  static VoronoiTopology2 fromSnapshot(BoostVoronoiSnapshot2 snapshot) {
    return VoronoiTopology2(
      vertices: [
        for (final vertex in snapshot.vertices)
          VoronoiVertex2(
            point: VoronoiPoint2(vertex.x, vertex.y),
            incidentEdgeId:
                vertex.incidentEdge < 0 ? null : vertex.incidentEdge,
          ),
      ],
      cells: [
        for (final cell in snapshot.cells)
          VoronoiCell2(
            sourceIndex: cell.sourceIndex,
            sourceCategory: _sourceCategory(cell.sourceCategory),
            incidentEdgeId: cell.incidentEdge < 0 ? null : cell.incidentEdge,
            degenerate: cell.degenerate,
          ),
      ],
      edges: [
        for (var id = 0; id < snapshot.edges.length; id++)
          VoronoiHalfEdge2(
            id: id,
            vertex0: snapshot.edges[id].vertex0 < 0
                ? null
                : snapshot.edges[id].vertex0,
            vertex1: snapshot.edges[id].vertex1 < 0
                ? null
                : snapshot.edges[id].vertex1,
            cellIndex: snapshot.edges[id].cell,
            twinId: snapshot.edges[id].twin,
            rotNextId: snapshot.edges[id].rotNext,
            nextId: snapshot.edges[id].next < 0
                ? null
                : snapshot.edges[id].next,
            prevId: snapshot.edges[id].prev < 0
                ? null
                : snapshot.edges[id].prev,
            primary: snapshot.edges[id].primary,
            linear: snapshot.edges[id].linear,
            finite: snapshot.edges[id].finite,
          ),
      ],
    );
  }

  static VoronoiSourceCategory _sourceCategory(int value) {
    switch (value) {
      case BoostSourceCategory2.segmentStartPoint:
        return VoronoiSourceCategory.segmentStartPoint;
      case BoostSourceCategory2.segmentEndPoint:
        return VoronoiSourceCategory.segmentEndPoint;
      case BoostSourceCategory2.initialSegment:
      case BoostSourceCategory2.reverseSegment:
        return VoronoiSourceCategory.segment;
      case BoostSourceCategory2.singlePoint:
        throw UnsupportedError(
          'QIDI segment-topology adapter cannot map a standalone Boost point '
          'site without a BoundarySegment2 source record.',
        );
      default:
        throw StateError('Unknown Boost source category $value');
    }
  }
}

/// Exact Boost.Polygon segment builder entry point for the QIDI wrapper layer.
class SourceBoostSegmentVoronoiBuilder2 {
  const SourceBoostSegmentVoronoiBuilder2._();

  static VoronoiTopology2 build(List<BoundarySegment2> segments) {
    final builder = SourceBoostVoronoiBuilder2();
    for (final segment in segments) {
      builder.insertSegment(
        segment.a.x,
        segment.a.y,
        segment.b.x,
        segment.b.y,
      );
    }
    return SourceBoostTopologyAdapter2.fromSnapshot(
      builder.constructSnapshot(),
    );
  }
}
