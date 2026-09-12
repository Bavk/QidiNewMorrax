import 'source_boost_voronoi_predicates.dart';
import 'source_boost_voronoi_structures.dart';

class BoostRawVoronoiCell2 {
  BoostRawVoronoiCell2(this.sourceIndex, this.sourceCategory);

  final int sourceIndex;
  final int sourceCategory;
  BoostRawVoronoiEdge2? incidentEdge;

  bool get containsPoint => BoostSourceCategory2.belongs(
        sourceCategory,
        BoostGeometryCategory2.point,
      );
  bool get containsSegment => BoostSourceCategory2.belongs(
        sourceCategory,
        BoostGeometryCategory2.segment,
      );
  bool get isDegenerate => incidentEdge == null;
}

class BoostRawVoronoiVertex2 {
  BoostRawVoronoiVertex2(this.x, this.y);

  final double x;
  final double y;
  BoostRawVoronoiEdge2? incidentEdge;

  bool get isDegenerate => incidentEdge == null;
}

class BoostRawVoronoiEdge2 {
  BoostRawVoronoiEdge2({
    required this.isLinear,
    required this.isPrimary,
  });

  final bool isLinear;
  final bool isPrimary;
  BoostRawVoronoiCell2? cell;
  BoostRawVoronoiVertex2? vertex0;
  BoostRawVoronoiEdge2? twin;
  BoostRawVoronoiEdge2? next;
  BoostRawVoronoiEdge2? prev;

  BoostRawVoronoiVertex2? get vertex1 => twin?.vertex0;
  bool get isFinite => vertex0 != null && vertex1 != null;
  bool get isInfinite => !isFinite;
  bool get isSecondary => !isPrimary;
  bool get isCurved => !isLinear;

  BoostRawVoronoiEdge2 get rotNext {
    final previous = prev;
    if (previous == null || previous.twin == null) {
      throw StateError('Boost rot_next requires prev->twin');
    }
    return previous.twin!;
  }

  BoostRawVoronoiEdge2 get rotPrev {
    final t = twin;
    if (t == null || t.next == null) {
      throw StateError('Boost rot_prev requires twin->next');
    }
    return t.next!;
  }
}

class BoostRawVoronoiEdgePair2 {
  const BoostRawVoronoiEdgePair2(this.first, this.second);
  final BoostRawVoronoiEdge2 first;
  final BoostRawVoronoiEdge2 second;
}

class BoostVoronoiVertexSnapshot2 {
  const BoostVoronoiVertexSnapshot2({
    required this.x,
    required this.y,
    required this.incidentEdge,
  });
  final double x;
  final double y;
  final int incidentEdge;
}

class BoostVoronoiCellSnapshot2 {
  const BoostVoronoiCellSnapshot2({
    required this.sourceIndex,
    required this.sourceCategory,
    required this.incidentEdge,
    required this.degenerate,
  });
  final int sourceIndex;
  final int sourceCategory;
  final int incidentEdge;
  final bool degenerate;
}

class BoostVoronoiEdgeSnapshot2 {
  const BoostVoronoiEdgeSnapshot2({
    required this.vertex0,
    required this.vertex1,
    required this.cell,
    required this.twin,
    required this.next,
    required this.prev,
    required this.rotNext,
    required this.primary,
    required this.linear,
    required this.finite,
  });
  final int vertex0;
  final int vertex1;
  final int cell;
  final int twin;
  final int next;
  final int prev;
  final int rotNext;
  final bool primary;
  final bool linear;
  final bool finite;
}

class BoostVoronoiSnapshot2 {
  const BoostVoronoiSnapshot2({
    required this.vertices,
    required this.cells,
    required this.edges,
  });

  final List<BoostVoronoiVertexSnapshot2> vertices;
  final List<BoostVoronoiCellSnapshot2> cells;
  final List<BoostVoronoiEdgeSnapshot2> edges;
}

/// Port of Boost.Polygon 1.83 `voronoi_diagram<double>`'s private builder
/// contract (`_process_single_site`, both `_insert_new_edge` overloads and
/// `_build`). The Fortune sweep writes into this mutable object.
class BoostRawVoronoiDiagram2 {
  final List<BoostRawVoronoiCell2> _cells = [];
  final List<BoostRawVoronoiVertex2> _vertices = [];
  final List<BoostRawVoronoiEdge2> _edges = [];

  List<BoostRawVoronoiCell2> get cells => List.unmodifiable(_cells);
  List<BoostRawVoronoiVertex2> get vertices => List.unmodifiable(_vertices);
  List<BoostRawVoronoiEdge2> get edges => List.unmodifiable(_edges);

  /// `std::vector::reserve()` has no observable equivalent in Dart; capacity
  /// does not affect object identity here, so this is intentionally a no-op.
  void reserve(int numSites) {}

  void processSingleSite(BoostSiteEvent2 site) {
    _cells.add(BoostRawVoronoiCell2(site.initialIndex, site.sourceCategory));
  }

  BoostRawVoronoiEdgePair2 insertNewEdge(
    BoostSiteEvent2 site1,
    BoostSiteEvent2 site2,
  ) {
    final siteIndex1 = site1.sortedIndex;
    final siteIndex2 = site2.sortedIndex;
    final linear = _isLinearEdge(site1, site2);
    final primary = _isPrimaryEdge(site1, site2);

    final edge1 = BoostRawVoronoiEdge2(
      isLinear: linear,
      isPrimary: primary,
    );
    final edge2 = BoostRawVoronoiEdge2(
      isLinear: linear,
      isPrimary: primary,
    );
    _edges
      ..add(edge1)
      ..add(edge2);

    if (_cells.isEmpty) {
      _cells.add(BoostRawVoronoiCell2(
        site1.initialIndex,
        site1.sourceCategory,
      ));
    }
    _cells.add(BoostRawVoronoiCell2(
      site2.initialIndex,
      site2.sourceCategory,
    ));

    edge1.cell = _cells[siteIndex1];
    edge2.cell = _cells[siteIndex2];
    edge1.twin = edge2;
    edge2.twin = edge1;
    return BoostRawVoronoiEdgePair2(edge1, edge2);
  }

  BoostRawVoronoiEdgePair2 insertNewEdgeAtCircle(
    BoostSiteEvent2 site1,
    BoostSiteEvent2 site3,
    BoostCircleEvent2 circle,
    BoostRawVoronoiEdge2 edge12,
    BoostRawVoronoiEdge2 edge23,
  ) {
    final vertex = BoostRawVoronoiVertex2(circle.x, circle.y);
    _vertices.add(vertex);
    edge12.vertex0 = vertex;
    edge23.vertex0 = vertex;

    final linear = _isLinearEdge(site1, site3);
    final primary = _isPrimaryEdge(site1, site3);
    final newEdge1 = BoostRawVoronoiEdge2(
      isLinear: linear,
      isPrimary: primary,
    )..cell = _cells[site1.sortedIndex];
    final newEdge2 = BoostRawVoronoiEdge2(
      isLinear: linear,
      isPrimary: primary,
    )
      ..cell = _cells[site3.sortedIndex]
      ..vertex0 = vertex;
    _edges
      ..add(newEdge1)
      ..add(newEdge2);
    newEdge1.twin = newEdge2;
    newEdge2.twin = newEdge1;

    edge12.prev = newEdge1;
    newEdge1.next = edge12;
    edge12.twin!.next = edge23;
    edge23.prev = edge12.twin;
    edge23.twin!.next = newEdge2;
    newEdge2.prev = edge23.twin;

    return BoostRawVoronoiEdgePair2(newEdge1, newEdge2);
  }

  /// Boost `_build()` finalization. Dart object references remain stable while
  /// vectors are compacted, so filtering survivor objects gives the same final
  /// order without needing C++'s pointer-repair assignments after vector moves.
  void build() {
    final survivingEdges = <BoostRawVoronoiEdge2>[];
    for (var index = 0; index < _edges.length; index += 2) {
      final edge = _edges[index];
      final twin = _edges[index + 1];
      final v1 = edge.vertex0;
      final v2 = edge.vertex1;
      if (v1 != null && v2 != null && _verticesEqual(v1, v2)) {
        _removeEdge(edge);
      } else {
        survivingEdges
          ..add(edge)
          ..add(twin);
      }
    }
    _edges
      ..clear()
      ..addAll(survivingEdges);

    for (final edge in _edges) {
      edge.cell!.incidentEdge = edge;
      edge.vertex0?.incidentEdge = edge;
    }

    _vertices.removeWhere((vertex) => vertex.incidentEdge == null);

    if (_vertices.isEmpty) {
      _closeLineEdgesWithoutVertices();
    } else {
      _closeInfiniteRayEdgesPerCell();
    }
  }

  BoostVoronoiSnapshot2 snapshot() {
    final edgeIndex = <BoostRawVoronoiEdge2, int>{
      for (var i = 0; i < _edges.length; i++) _edges[i]: i,
    };
    final vertexIndex = <BoostRawVoronoiVertex2, int>{
      for (var i = 0; i < _vertices.length; i++) _vertices[i]: i,
    };
    final cellIndex = <BoostRawVoronoiCell2, int>{
      for (var i = 0; i < _cells.length; i++) _cells[i]: i,
    };

    int e(BoostRawVoronoiEdge2? value) =>
        value == null ? -1 : edgeIndex[value] ?? -1;
    int v(BoostRawVoronoiVertex2? value) =>
        value == null ? -1 : vertexIndex[value] ?? -1;

    return BoostVoronoiSnapshot2(
      vertices: [
        for (final vertex in _vertices)
          BoostVoronoiVertexSnapshot2(
            x: vertex.x,
            y: vertex.y,
            incidentEdge: e(vertex.incidentEdge),
          ),
      ],
      cells: [
        for (final cell in _cells)
          BoostVoronoiCellSnapshot2(
            sourceIndex: cell.sourceIndex,
            sourceCategory: cell.sourceCategory,
            incidentEdge: e(cell.incidentEdge),
            degenerate: cell.isDegenerate,
          ),
      ],
      edges: [
        for (final edge in _edges)
          BoostVoronoiEdgeSnapshot2(
            vertex0: v(edge.vertex0),
            vertex1: v(edge.vertex1),
            cell: cellIndex[edge.cell] ?? -1,
            twin: e(edge.twin),
            next: e(edge.next),
            prev: e(edge.prev),
            rotNext: edge.prev == null ? -1 : e(edge.rotNext),
            primary: edge.isPrimary,
            linear: edge.isLinear,
            finite: edge.isFinite,
          ),
      ],
    );
  }

  void clear() {
    _cells.clear();
    _vertices.clear();
    _edges.clear();
  }

  bool _isPrimaryEdge(BoostSiteEvent2 site1, BoostSiteEvent2 site2) {
    final segment1 = site1.isSegment;
    final segment2 = site2.isSegment;
    if (segment1 && !segment2) {
      return site1.point0 != site2.point0 && site1.point1 != site2.point0;
    }
    if (!segment1 && segment2) {
      return site2.point0 != site1.point0 && site2.point1 != site1.point0;
    }
    return true;
  }

  bool _isLinearEdge(BoostSiteEvent2 site1, BoostSiteEvent2 site2) {
    if (!_isPrimaryEdge(site1, site2)) return true;
    return site1.isSegment == site2.isSegment;
  }

  bool _verticesEqual(
    BoostRawVoronoiVertex2 a,
    BoostRawVoronoiVertex2 b,
  ) =>
      BoostVoronoiPredicates2.ulpCompare(a.x, b.x, 128) ==
          BoostUlpResult2.equal &&
      BoostVoronoiPredicates2.ulpCompare(a.y, b.y, 128) ==
          BoostUlpResult2.equal;

  void _removeEdge(BoostRawVoronoiEdge2 edge) {
    final vertex = edge.vertex0;
    var updated = edge.twin!.rotNext;
    while (!identical(updated, edge.twin)) {
      updated.vertex0 = vertex;
      updated = updated.rotNext;
    }

    final edge1 = edge;
    final edge2 = edge.twin!;
    final edge1RotPrev = edge1.rotPrev;
    final edge1RotNext = edge1.rotNext;
    final edge2RotPrev = edge2.rotPrev;
    final edge2RotNext = edge2.rotNext;

    edge1RotNext.twin!.next = edge2RotPrev;
    edge2RotPrev.prev = edge1RotNext.twin;
    edge1RotPrev.prev = edge2RotNext.twin;
    edge2RotNext.twin!.next = edge1RotPrev;
  }

  void _closeLineEdgesWithoutVertices() {
    if (_edges.isEmpty) return;
    var edgeIndex = 0;
    var edge1 = _edges[edgeIndex];
    edge1.next = edge1;
    edge1.prev = edge1;
    edgeIndex++;
    edge1 = _edges[edgeIndex];
    edgeIndex++;

    while (edgeIndex < _edges.length) {
      final edge2 = _edges[edgeIndex];
      edgeIndex++;
      edge1.next = edge2;
      edge1.prev = edge2;
      edge2.next = edge1;
      edge2.prev = edge1;
      edge1 = _edges[edgeIndex];
      edgeIndex++;
    }
    edge1.next = edge1;
    edge1.prev = edge1;
  }

  void _closeInfiniteRayEdgesPerCell() {
    for (final cell in _cells) {
      if (cell.isDegenerate) continue;
      final incident = cell.incidentEdge!;
      var left = incident;
      var guard = 0;
      while (left.prev != null) {
        left = left.prev!;
        if (identical(left, incident)) break;
        if (++guard > _edges.length) {
          throw StateError('Boost cell prev chain failed to terminate');
        }
      }
      if (left.prev != null) continue;

      var right = incident;
      guard = 0;
      while (right.next != null) {
        right = right.next!;
        if (++guard > _edges.length) {
          throw StateError('Boost cell next chain failed to terminate');
        }
      }
      left.prev = right;
      right.next = left;
    }
  }
}
