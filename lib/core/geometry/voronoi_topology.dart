import 'source_geometry.dart';

enum VoronoiVertexCategory { onContour, inside, outside, unknown }
enum VoronoiEdgeCategory { pointsInside, pointsOutside, pointsToContour, unknown }
enum VoronoiCellCategory { inside, outside, boundary, unknown }
enum VoronoiSourceCategory { segmentStartPoint, segmentEndPoint, segment }

class BoundarySegment2 {
  const BoundarySegment2(this.a, this.b);
  final SourcePoint2 a;
  final SourcePoint2 b;
}

class VoronoiPoint2 {
  const VoronoiPoint2(this.x, this.y);
  final double x;
  final double y;
}

class VoronoiVertex2 {
  const VoronoiVertex2({
    required this.point,
    this.incidentEdgeId,
    this.category = VoronoiVertexCategory.unknown,
  });

  final VoronoiPoint2 point;
  final int? incidentEdgeId;
  final VoronoiVertexCategory category;

  VoronoiVertex2 withPoint(VoronoiPoint2 value) => VoronoiVertex2(
        point: value,
        incidentEdgeId: incidentEdgeId,
        category: category,
      );

  VoronoiVertex2 withCategory(VoronoiVertexCategory value) => VoronoiVertex2(
        point: point,
        incidentEdgeId: incidentEdgeId,
        category: value,
      );
}

class VoronoiCell2 {
  const VoronoiCell2({
    required this.sourceIndex,
    required this.sourceCategory,
    this.incidentEdgeId,
    this.degenerate = false,
    this.category = VoronoiCellCategory.unknown,
  });

  final int sourceIndex;
  final VoronoiSourceCategory sourceCategory;
  final int? incidentEdgeId;
  final bool degenerate;
  final VoronoiCellCategory category;

  bool get containsSegment => sourceCategory == VoronoiSourceCategory.segment;
  bool get containsPoint => !containsSegment;

  VoronoiCell2 withCategory(VoronoiCellCategory value) => VoronoiCell2(
        sourceIndex: sourceIndex,
        sourceCategory: sourceCategory,
        incidentEdgeId: incidentEdgeId,
        degenerate: degenerate,
        category: value,
      );
}

/// Source-shaped Boost.Polygon half-edge representation.
class VoronoiHalfEdge2 {
  const VoronoiHalfEdge2({
    required this.id,
    required this.vertex0,
    required this.vertex1,
    required this.cellIndex,
    required this.twinId,
    required this.rotNextId,
    this.nextId,
    this.prevId,
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
  final int? nextId;
  final int? prevId;
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
        nextId: nextId,
        prevId: prevId,
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
      _requireEdge(edge.id, edge.twinId, 'twin');
      _requireEdge(edge.id, edge.rotNextId, 'rotNext');
      if (edge.nextId != null) _requireEdge(edge.id, edge.nextId!, 'next');
      if (edge.prevId != null) _requireEdge(edge.id, edge.prevId!, 'prev');

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
      if (edge.vertex0 != twin.vertex1 || edge.vertex1 != twin.vertex0) {
        throw StateError(
          'Voronoi edge ${edge.id} endpoints do not reverse across twin ${edge.twinId}',
        );
      }
      if (edge.nextId != null) {
        final next = _edgeById[edge.nextId!]!;
        if (next.prevId != null && next.prevId != edge.id) {
          throw StateError('Voronoi next/prev relation is not reciprocal');
        }
      }
      if (edge.prevId != null) {
        final prev = _edgeById[edge.prevId!]!;
        if (prev.nextId != null && prev.nextId != edge.id) {
          throw StateError('Voronoi prev/next relation is not reciprocal');
        }
      }
    }

    for (var i = 0; i < this.vertices.length; i++) {
      final incident = this.vertices[i].incidentEdgeId;
      if (incident != null) _requireEdgeForOwner('vertex', i, incident);
    }
    for (var i = 0; i < this.cells.length; i++) {
      final incident = this.cells[i].incidentEdgeId;
      if (incident != null) {
        _requireEdgeForOwner('cell', i, incident);
        if (_edgeById[incident]!.cellIndex != i) {
          throw StateError('Voronoi cell $i incident edge belongs to another cell');
        }
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

  Iterable<VoronoiHalfEdge2> orderedEdgesForCell(int cellIndex) sync* {
    final cell = cells[cellIndex];
    final startId = cell.incidentEdgeId;
    if (startId == null) {
      yield* edgesForCell(cellIndex);
      return;
    }

    var current = edge(startId);
    var guard = 0;
    do {
      if (current.cellIndex != cellIndex) {
        throw StateError('Voronoi cell boundary escaped cell $cellIndex');
      }
      yield current;
      final nextId = current.nextId;
      if (nextId == null) {
        throw StateError('Voronoi ordered cell traversal requires edge.next');
      }
      current = edge(nextId);
      if (++guard > edges.length) {
        throw StateError('Voronoi cell $cellIndex next cycle does not close');
      }
    } while (current.id != startId);
  }

  void _requireEdge(int ownerEdgeId, int edgeId, String relation) {
    if (!_edgeById.containsKey(edgeId)) {
      throw StateError(
        'Voronoi edge $ownerEdgeId has missing $relation edge $edgeId',
      );
    }
  }

  void _requireEdgeForOwner(String ownerType, int owner, int edgeId) {
    if (!_edgeById.containsKey(edgeId)) {
      throw StateError(
        'Voronoi $ownerType $owner has missing incident edge $edgeId',
      );
    }
  }

  void _validateVertexIndex(int edgeId, int? index, String label) {
    if (index != null && (index < 0 || index >= vertices.length)) {
      throw StateError('Voronoi edge $edgeId has invalid $label index');
    }
  }
}
