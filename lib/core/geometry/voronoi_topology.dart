import 'source_geometry.dart';

enum VoronoiVertexCategory { onContour, inside, outside, unknown }
enum VoronoiSourceCategory { segmentStartPoint, segmentEndPoint, segment }

/// Boundary segment in original integer `coord_t` units.
class BoundarySegment2 {
  const BoundarySegment2(this.a, this.b);

  final SourcePoint2 a;
  final SourcePoint2 b;
}

/// Boost.Polygon stores Voronoi vertex coordinates as doubles while the source
/// boundary segments remain integer coord_t. Values here are therefore doubles
/// in **source coordinate units**, not millimeters.
class VoronoiPoint2 {
  const VoronoiPoint2(this.x, this.y);
  final double x;
  final double y;
}

class VoronoiVertex2 {
  const VoronoiVertex2({required this.point, required this.category});

  final VoronoiPoint2 point;
  final VoronoiVertexCategory category;
}

class VoronoiCell2 {
  const VoronoiCell2({
    required this.sourceIndex,
    required this.sourceCategory,
  });

  final int sourceIndex;
  final VoronoiSourceCategory sourceCategory;

  bool get containsSegment => sourceCategory == VoronoiSourceCategory.segment;
}

/// Half-edge topology required by `Geometry::MedialAxis`.
///
/// `rotNextId` is the Boost.Polygon `edge_type::rot_next()` relation. The
/// Boost-compatible segment Voronoi constructor and QIDI repair/annotation are
/// separate migration layers; this topology keeps the MedialAxis traversal
/// representation source-shaped instead of substituting another skeletonizer.
class VoronoiHalfEdge2 {
  const VoronoiHalfEdge2({
    required this.id,
    required this.vertex0,
    required this.vertex1,
    required this.cellIndex,
    required this.twinId,
    required this.rotNextId,
    this.primary = true,
    this.finite = true,
  });

  final int id;
  final int vertex0;
  final int vertex1;
  final int cellIndex;
  final int twinId;
  final int rotNextId;
  final bool primary;
  final bool finite;
}

class VoronoiTopology2 {
  VoronoiTopology2({
    required Iterable<VoronoiVertex2> vertices,
    required Iterable<VoronoiCell2> cells,
    required Iterable<VoronoiHalfEdge2> edges,
  })  : vertices = List.unmodifiable(vertices),
        cells = List.unmodifiable(cells),
        edges = List.unmodifiable(edges),
        _edgeById = {for (final edge in edges) edge.id: edge} {
    for (final edge in this.edges) {
      if (!_edgeById.containsKey(edge.twinId)) {
        throw StateError('Voronoi edge ${edge.id} has missing twin ${edge.twinId}');
      }
      if (!_edgeById.containsKey(edge.rotNextId)) {
        throw StateError(
          'Voronoi edge ${edge.id} has missing rotNext ${edge.rotNextId}',
        );
      }
      if (edge.vertex0 < 0 ||
          edge.vertex0 >= this.vertices.length ||
          edge.vertex1 < 0 ||
          edge.vertex1 >= this.vertices.length) {
        throw StateError('Voronoi edge ${edge.id} has invalid vertex index');
      }
      if (edge.cellIndex < 0 || edge.cellIndex >= this.cells.length) {
        throw StateError('Voronoi edge ${edge.id} has invalid cell index');
      }
      final twin = _edgeById[edge.twinId]!;
      if (twin.twinId != edge.id) {
        throw StateError('Voronoi edge ${edge.id} twin relation is not symmetric');
      }
    }
  }

  final List<VoronoiVertex2> vertices;
  final List<VoronoiCell2> cells;
  final List<VoronoiHalfEdge2> edges;
  final Map<int, VoronoiHalfEdge2> _edgeById;

  VoronoiHalfEdge2 edge(int id) => _edgeById[id]!;
  VoronoiVertex2 vertex(int index) => vertices[index];
  VoronoiCell2 cell(int index) => cells[index];

  Iterable<VoronoiHalfEdge2> get canonicalHalfEdges sync* {
    for (final edge in edges) {
      if (edge.id < edge.twinId) yield edge;
    }
  }
}
