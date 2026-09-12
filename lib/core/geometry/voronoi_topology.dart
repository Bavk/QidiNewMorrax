import 'source_geometry.dart';

enum VoronoiVertexCategory { onContour, inside, outside, unknown }
enum VoronoiEdgeCategory { pointsInside, pointsOutside, pointsToContour, unknown }
enum VoronoiCellCategory { inside, outside, boundary, unknown }
enum VoronoiSourceCategory { segmentStartPoint, segmentEndPoint, segment }

/// Boundary segment in original integer `coord_t` units.
class BoundarySegment2 {
  const BoundarySegment2(this.a, this.b);

  final SourcePoint2 a;
  final SourcePoint2 b;
}

/// Boost.Polygon stores Voronoi vertex coordinates as doubles while the source
/// boundary segments remain integer coord_t. Values here are doubles in
/// **source coordinate units**, not millimeters.
class VoronoiPoint2 {
  const VoronoiPoint2(this.x, this.y);
  final double x;
  final double y;
}

class VoronoiVertex2 {
  const VoronoiVertex2({
    required this.point,
    this.category = VoronoiVertexCategory.unknown,
  });

  final VoronoiPoint2 point;
  final VoronoiVertexCategory category;

  VoronoiVertex2 withCategory(VoronoiVertexCategory value) => VoronoiVertex2(
        point: point,
        category: value,
      );
}

class VoronoiCell2 {
  const VoronoiCell2({
    required this.sourceIndex,
    required this.sourceCategory,
    this.category = VoronoiCellCategory.unknown,
  });

  final int sourceIndex;
  final VoronoiSourceCategory sourceCategory;
  final VoronoiCellCategory category;

  bool get containsSegment => sourceCategory == VoronoiSourceCategory.segment;
  bool get containsPoint => !containsSegment;

  VoronoiCell2 withCategory(VoronoiCellCategory value) => VoronoiCell2(
        sourceIndex: sourceIndex,
        sourceCategory: sourceCategory,
        category: value,
      );
}

/// Source-shaped Boost.Polygon half-edge representation.
///
/// Infinite Boost edges have one null endpoint in each oriented half-edge;
/// supporting that is required by `annotate_inside_outside()` because those
/// edges seed the Outside classification. `rotNextId` is Boost
/// `edge_type::rot_next()`. `primary=false` represents a secondary edge.
class VoronoiHalfEdge2 {
  const VoronoiHalfEdge2({
    required this.id,
    required this.vertex0,
    required this.vertex1,
    required this.cellIndex,
    required this.twinId,
    required this.rotNextId,
    this.primary = true,
    this.linear = true,
    bool? finite,
    this.category = VoronoiEdgeCategory.unknown,
  }) : finite = finite ?? (vertex0 != null && vertex1 != null);

  final int id;
  final int? vertex0;
  final int? vertex1;
  final int cellIndex;
  final int twinId;
  final int rotNextId;
  final bool primary;
  final bool linear;
  final bool finite;
  final VoronoiEdgeCategory category;

  bool get secondary => !primary;
  bool get infinite => !finite;

  VoronoiHalfEdge2 withCategory(VoronoiEdgeCategory value) =>
      VoronoiHalfEdge2(
        id: id,
        vertex0: vertex0,
        vertex1: vertex1,
        cellIndex: cellIndex,
        twinId: twinId,
        rotNextId: rotNextId,
        primary: primary,
        linear: linear,
        finite: finite,
        category: value,
      );
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
      _validateVertexIndex(edge.id, edge.vertex0, 'vertex0');
      _validateVertexIndex(edge.id, edge.vertex1, 'vertex1');
      if (edge.finite != (edge.vertex0 != null && edge.vertex1 != null)) {
        throw StateError(
          'Voronoi edge ${edge.id} finite flag disagrees with nullable endpoints',
        );
      }
      if (!edge.finite && edge.vertex0 == null && edge.vertex1 == null) {
        throw StateError(
          'Voronoi infinite edge ${edge.id} must retain one finite vertex',
        );
      }
      if (edge.cellIndex < 0 || edge.cellIndex >= this.cells.length) {
        throw StateError('Voronoi edge ${edge.id} has invalid cell index');
      }
      final twin = _edgeById[edge.twinId]!;
      if (twin.twinId != edge.id) {
        throw StateError('Voronoi edge ${edge.id} twin relation is not symmetric');
      }
      // Boost half-edge endpoints are reversed across twins, including the
      // null endpoint of infinite edges.
      if (edge.vertex0 != twin.vertex1 || edge.vertex1 != twin.vertex0) {
        throw StateError(
          'Voronoi edge ${edge.id} endpoints do not reverse across twin ${edge.twinId}',
        );
      }
    }
  }

  final List<VoronoiVertex2> vertices;
  final List<VoronoiCell2> cells;
  final List<VoronoiHalfEdge2> edges;
  final Map<int, VoronoiHalfEdge2> _edgeById;

  VoronoiHalfEdge2 edge(int id) => _edgeById[id]!;
  VoronoiVertex2 vertex(int index) => vertices[index];
  VoronoiVertex2? vertexOrNull(int? index) =>
      index == null ? null : vertices[index];
  VoronoiCell2 cell(int index) => cells[index];

  Iterable<VoronoiHalfEdge2> get canonicalHalfEdges sync* {
    for (final edge in edges) {
      if (edge.id < edge.twinId) yield edge;
    }
  }

  Iterable<VoronoiHalfEdge2> edgesForCell(int cellIndex) sync* {
    for (final edge in edges) {
      if (edge.cellIndex == cellIndex) yield edge;
    }
  }

  void _validateVertexIndex(int edgeId, int? index, String label) {
    if (index != null && (index < 0 || index >= vertices.length)) {
      throw StateError('Voronoi edge $edgeId has invalid $label index');
    }
  }
}
