import 'dart:typed_data';

import 'voronoi_topology.dart';

/// Port of the source classification phase in
/// `Geometry/VoronoiOffset.cpp::annotate_inside_outside()`.
///
/// The input topology must already have Boost-compatible half-edge/site
/// semantics. This unit resets all annotations, marks input-contour vertices,
/// seeds Outside from infinite edges, classifies Segment-site edges by the
/// source orientation rule, then propagates Point-site cell classifications.
/// It does not construct or repair the Voronoi diagram itself.
class SourceVoronoiAnnotator2 {
  const SourceVoronoiAnnotator2();

  VoronoiTopology2 annotate(
    VoronoiTopology2 topology,
    List<BoundarySegment2> lines,
  ) {
    final vertexCategories = List<VoronoiVertexCategory>.filled(
      topology.vertices.length,
      VoronoiVertexCategory.unknown,
    );
    final cellCategories = List<VoronoiCellCategory>.filled(
      topology.cells.length,
      VoronoiCellCategory.unknown,
    );
    final edgeCategories = <int, VoronoiEdgeCategory>{
      for (final edge in topology.edges) edge.id: VoronoiEdgeCategory.unknown,
    };

    void annotateVertex(int? index, VoronoiVertexCategory value) {
      if (index == null) return;
      final current = vertexCategories[index];
      if (current != VoronoiVertexCategory.unknown && current != value) {
        throw StateError(
          'Conflicting Voronoi vertex annotation at $index: $current -> $value',
        );
      }
      vertexCategories[index] = value;
    }

    void annotateEdge(int edgeId, VoronoiEdgeCategory value) {
      final current = edgeCategories[edgeId]!;
      if (current != VoronoiEdgeCategory.unknown && current != value) {
        throw StateError(
          'Conflicting Voronoi edge annotation at $edgeId: $current -> $value',
        );
      }
      edgeCategories[edgeId] = value;
    }

    bool annotateCell(int index, VoronoiCellCategory value) {
      final current = cellCategories[index];
      var next = value;
      switch (current) {
        case VoronoiCellCategory.unknown:
          break;
        case VoronoiCellCategory.outside:
          if (value == VoronoiCellCategory.inside) {
            next = VoronoiCellCategory.boundary;
          }
          break;
        case VoronoiCellCategory.inside:
          if (value == VoronoiCellCategory.outside) {
            next = VoronoiCellCategory.boundary;
          }
          break;
        case VoronoiCellCategory.boundary:
          return false;
      }
      if (current != next) {
        cellCategories[index] = next;
        return true;
      }
      return false;
    }

    // Source first marks all vertices that lie on either Voronoi site.
    for (final edge in topology.edges) {
      final vertexIndex = edge.vertex0;
      if (vertexIndex == null) continue;
      final point = topology.vertex(vertexIndex).point;
      if (_onSite(lines, topology.cell(edge.cellIndex), point)) {
        annotateVertex(vertexIndex, VoronoiVertexCategory.onContour);
      }
    }

    // One side of a secondary Point-Segment edge is always on the source
    // contour. Boost may merge nearby vertices, so source explicitly marks it.
    for (final edge in topology.edges) {
      if (!edge.secondary || edge.vertex0 == null) continue;
      if (!edge.linear) {
        throw StateError('Source secondary Voronoi edge must be linear');
      }
      final cell = topology.cell(edge.cellIndex);
      final twinCell = topology.cell(topology.edge(edge.twinId).cellIndex);
      if (cell.containsPoint == twinCell.containsPoint) {
        throw StateError(
          'Secondary edge ${edge.id} must separate a point and segment site',
        );
      }
      final pointCell = cell.containsPoint ? cell : twinCell;
      final contour = _contourPoint(pointCell, lines);

      if (edge.vertex1 == null) {
        if (!_vertexEqualToPoint(topology.vertex(edge.vertex0!).point, contour)) {
          throw StateError('Secondary infinite edge misses source contour point');
        }
        annotateVertex(edge.vertex0, VoronoiVertexCategory.onContour);
      } else if (_vertexEqualToPoint(
        topology.vertex(edge.vertex0!).point,
        contour,
      )) {
        annotateVertex(edge.vertex0, VoronoiVertexCategory.onContour);
      } else {
        if (!_vertexEqualToPoint(topology.vertex(edge.vertex1!).point, contour)) {
          throw StateError('Secondary edge has no endpoint on source contour');
        }
        annotateVertex(edge.vertex1, VoronoiVertexCategory.onContour);
      }
    }

    // Infinite edges are the guaranteed Outside seeds.
    for (final edge in topology.edges) {
      if (edge.vertex1 == null) {
        if (edge.vertex0 == null || edge.finite || !edge.linear) {
          throw StateError('Malformed source infinite Voronoi edge ${edge.id}');
        }
        final twin = topology.edge(edge.twinId);
        annotateEdge(edge.id, VoronoiEdgeCategory.pointsOutside);
        annotateEdge(
          twin.id,
          edge.secondary
              ? VoronoiEdgeCategory.pointsToContour
              : VoronoiEdgeCategory.pointsOutside,
        );
        annotateVertex(
          edge.vertex0,
          edge.secondary
              ? VoronoiVertexCategory.onContour
              : VoronoiVertexCategory.outside,
        );

        var cellIndex = edge.cellIndex;
        var cell2Index = twin.cellIndex;
        if (topology.cell(cellIndex).containsSegment) {
          final swap = cellIndex;
          cellIndex = cell2Index;
          cell2Index = swap;
        }
        final pointCell = topology.cell(cellIndex);
        if (!pointCell.containsPoint) {
          throw StateError('Infinite edge must reference at least one point site');
        }
        annotateCell(cellIndex, VoronoiCellCategory.outside);
        final cell2 = topology.cell(cell2Index);
        annotateCell(
          cell2Index,
          cell2.containsPoint
              ? VoronoiCellCategory.outside
              : VoronoiCellCategory.boundary,
        );
        continue;
      }

      if (edge.vertex0 == null) continue; // twin orientation of infinite edge.
      if (!edge.finite) {
        throw StateError('Finite annotation branch received infinite edge');
      }

      var segmentCellIndex = edge.cellIndex;
      var segmentCell = topology.cell(segmentCellIndex);
      if (!segmentCell.containsSegment) {
        segmentCellIndex = topology.edge(edge.twinId).cellIndex;
        segmentCell = topology.cell(segmentCellIndex);
      }
      if (!segmentCell.containsSegment) {
        // Point-Point edge: classified later by propagation.
        continue;
      }

      final twin = topology.edge(edge.twinId);
      final otherCellIndex = segmentCellIndex == edge.cellIndex
          ? twin.cellIndex
          : edge.cellIndex;
      final otherCell = topology.cell(otherCellIndex);
      final line = _lineFor(segmentCell, lines);
      final v0Category = vertexCategories[edge.vertex0!];
      final v1Category = vertexCategories[edge.vertex1!];
      final onContour = v0Category == VoronoiVertexCategory.onContour ||
          v1Category == VoronoiVertexCategory.onContour;

      if (onContour && v1Category == VoronoiVertexCategory.onContour) {
        annotateEdge(edge.id, VoronoiEdgeCategory.pointsToContour);
        continue;
      }

      final v1 = topology.vertex(edge.vertex1!).point;
      final lx = (line.b.x - line.a.x).toDouble();
      final ly = (line.b.y - line.a.y).toDouble();
      // Source: cross2(v1 - line.a, line.b - line.a).
      final side = (v1.x - line.a.x) * ly - (v1.y - line.a.y) * lx;
      if (side == 0) {
        throw StateError('Voronoi vertex unexpectedly lies on source segment');
      }
      final vertexCategory = side > 0
          ? VoronoiVertexCategory.outside
          : VoronoiVertexCategory.inside;
      final edgeCategory = vertexCategory == VoronoiVertexCategory.outside
          ? VoronoiEdgeCategory.pointsOutside
          : VoronoiEdgeCategory.pointsInside;

      annotateVertex(edge.vertex1, vertexCategory);
      annotateEdge(edge.id, edgeCategory);
      annotateVertex(
        edge.vertex0,
        onContour ? VoronoiVertexCategory.onContour : vertexCategory,
      );
      annotateEdge(
        twin.id,
        onContour ? VoronoiEdgeCategory.pointsToContour : edgeCategory,
      );
      annotateCell(
        segmentCellIndex,
        onContour
            ? VoronoiCellCategory.boundary
            : _cellCategoryFor(vertexCategory),
      );
      annotateCell(
        otherCellIndex,
        onContour && otherCell.containsSegment
            ? VoronoiCellCategory.boundary
            : _cellCategoryFor(vertexCategory),
      );
    }

    // First expansion round for finite Point-Point edges.
    final cellQueue = <int>[];
    for (final edge in topology.edges) {
      final twin = topology.edge(edge.twinId);
      final edgeCategory = edgeCategories[edge.id]!;
      final twinCategory = edgeCategories[twin.id]!;
      if ((edgeCategory == VoronoiEdgeCategory.unknown) !=
          (twinCategory == VoronoiEdgeCategory.unknown)) {
        throw StateError('Twin Point-Point edge categories disagree');
      }
      if (edgeCategory != VoronoiEdgeCategory.unknown) continue;
      if (!edge.finite) {
        throw StateError('Unannotated infinite Voronoi edge');
      }

      final cellIndex = edge.cellIndex;
      final cell2Index = twin.cellIndex;
      final cell = topology.cell(cellIndex);
      final cell2 = topology.cell(cell2Index);
      if (!cell.containsPoint || !cell2.containsPoint) {
        throw StateError('Unknown finite edge must separate Point sites');
      }

      final current = cellCategories[cellIndex];
      final current2 = cellCategories[cell2Index];
      if (current == VoronoiCellCategory.boundary ||
          current2 == VoronoiCellCategory.boundary) {
        throw StateError('Point site may not be a Boundary cell here');
      }
      var resolved = current;
      if (resolved == VoronoiCellCategory.unknown) {
        resolved = current2;
      } else if (current2 != VoronoiCellCategory.unknown &&
          current != current2) {
        throw StateError('Adjacent Point-site cells have conflicting seeds');
      }

      if (resolved == VoronoiCellCategory.unknown) {
        final v0 = vertexCategories[edge.vertex0!];
        if (v0 != VoronoiVertexCategory.onContour &&
            v0 != VoronoiVertexCategory.unknown) {
          resolved = _cellCategoryFor(v0);
        }
      }

      if (resolved != VoronoiCellCategory.unknown) {
        final vertexCategory = resolved == VoronoiCellCategory.outside
            ? VoronoiVertexCategory.outside
            : VoronoiVertexCategory.inside;
        annotateVertex(edge.vertex0, vertexCategory);
        annotateVertex(edge.vertex1, vertexCategory);
        final newEdgeCategory = resolved == VoronoiCellCategory.outside
            ? VoronoiEdgeCategory.pointsOutside
            : VoronoiEdgeCategory.pointsInside;
        annotateEdge(edge.id, newEdgeCategory);
        annotateEdge(twin.id, newEdgeCategory);
        if (current != resolved && annotateCell(cellIndex, resolved)) {
          cellQueue.add(cellIndex);
        }
        if (current2 != resolved && annotateCell(cell2Index, resolved)) {
          cellQueue.add(cell2Index);
        }
      }
    }

    // Final source seed fill over Point-site cells. Iterating all half-edges of
    // a cell is equivalent to walking Boost `edge->next()` for classification;
    // classification output is order-independent.
    while (cellQueue.isNotEmpty) {
      final cellIndex = cellQueue.removeLast();
      final category = cellCategories[cellIndex];
      if (category != VoronoiCellCategory.outside &&
          category != VoronoiCellCategory.inside) {
        throw StateError('Seed-fill queue contains unclassified cell');
      }
      final newEdgeCategory = category == VoronoiCellCategory.outside
          ? VoronoiEdgeCategory.pointsOutside
          : VoronoiEdgeCategory.pointsInside;

      for (final edge in topology.edgesForCell(cellIndex)) {
        if (edgeCategories[edge.id] != VoronoiEdgeCategory.unknown) continue;
        final twin = topology.edge(edge.twinId);
        final cell2Index = twin.cellIndex;
        final cell2 = topology.cell(cell2Index);
        if (!topology.cell(edge.cellIndex).containsPoint ||
            !cell2.containsPoint) {
          throw StateError('Seed fill may only cross Point-Point edges');
        }
        annotateEdge(edge.id, newEdgeCategory);
        annotateEdge(twin.id, newEdgeCategory);
        final otherCategory = cellCategories[cell2Index];
        if (otherCategory != VoronoiCellCategory.unknown &&
            otherCategory != category) {
          throw StateError('Voronoi Point-site seed fill reached conflict');
        }
        if (otherCategory != category &&
            annotateCell(cell2Index, category)) {
          cellQueue.add(cell2Index);
        }
      }
    }

    // Source debug verification expects the whole diagram to be annotated.
    for (var i = 0; i < vertexCategories.length; i++) {
      if (vertexCategories[i] == VoronoiVertexCategory.unknown) {
        throw StateError('Voronoi vertex $i remained unclassified');
      }
    }
    for (final edge in topology.edges) {
      if (edgeCategories[edge.id] == VoronoiEdgeCategory.unknown) {
        throw StateError('Voronoi edge ${edge.id} remained unclassified');
      }
    }
    for (var i = 0; i < cellCategories.length; i++) {
      if (cellCategories[i] == VoronoiCellCategory.unknown) {
        throw StateError('Voronoi cell $i remained unclassified');
      }
    }

    return VoronoiTopology2(
      vertices: [
        for (var i = 0; i < topology.vertices.length; i++)
          topology.vertices[i].withCategory(vertexCategories[i]),
      ],
      cells: [
        for (var i = 0; i < topology.cells.length; i++)
          topology.cells[i].withCategory(cellCategories[i]),
      ],
      edges: [
        for (final edge in topology.edges)
          edge.withCategory(edgeCategories[edge.id]!),
      ],
    );
  }

  BoundarySegment2 _lineFor(
    VoronoiCell2 cell,
    List<BoundarySegment2> lines,
  ) {
    if (cell.sourceIndex < 0 || cell.sourceIndex >= lines.length) {
      throw StateError('Voronoi cell source index is out of range');
    }
    return lines[cell.sourceIndex];
  }

  SourcePoint2 _contourPoint(
    VoronoiCell2 cell,
    List<BoundarySegment2> lines,
  ) {
    final line = _lineFor(cell, lines);
    switch (cell.sourceCategory) {
      case VoronoiSourceCategory.segmentStartPoint:
        return line.a;
      case VoronoiSourceCategory.segmentEndPoint:
        return line.b;
      case VoronoiSourceCategory.segment:
        throw StateError('Segment site does not identify one contour point');
    }
  }

  bool _onSite(
    List<BoundarySegment2> lines,
    VoronoiCell2 cell,
    VoronoiPoint2 point,
  ) {
    final line = _lineFor(cell, lines);
    if (cell.containsPoint) {
      return _vertexEqualToPoint(point, _contourPoint(cell, lines));
    }
    final onA = _vertexEqualToPoint(point, line.a);
    final onB = _vertexEqualToPoint(point, line.b);
    if (onA && onB) {
      throw StateError('Degenerate source segment is unsupported here');
    }
    return onA || onB;
  }

  bool _vertexEqualToPoint(VoronoiPoint2 vertex, SourcePoint2 point) =>
      _ulpEqual(vertex.x, point.x.toDouble(), 128) &&
      _ulpEqual(vertex.y, point.y.toDouble(), 128);

  /// Boost.Polygon `ulp_comparison<double>` mapping used by the source with
  /// `voronoi_diagram_traits<double>::...::ULPS == 128`.
  bool _ulpEqual(double a, double b, int maxUlps) {
    final bitsA = _mappedDoubleBits(a);
    final bitsB = _mappedDoubleBits(b);
    return (bitsA - bitsB).abs() <= maxUlps;
  }

  int _mappedDoubleBits(double value) {
    final bytes = ByteData(8)..setFloat64(0, value, Endian.host);
    var bits = bytes.getUint64(0, Endian.host);
    const signBit = 0x8000000000000000;
    if (bits < signBit) bits = signBit - bits;
    return bits;
  }

  VoronoiCellCategory _cellCategoryFor(VoronoiVertexCategory category) {
    switch (category) {
      case VoronoiVertexCategory.inside:
        return VoronoiCellCategory.inside;
      case VoronoiVertexCategory.outside:
        return VoronoiCellCategory.outside;
      case VoronoiVertexCategory.onContour:
      case VoronoiVertexCategory.unknown:
        throw StateError('Cannot derive cell category from $category');
    }
  }
}
