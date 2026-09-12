import 'dart:math' as math;

import 'source_geometry.dart';
import 'thick_polyline.dart';
import 'voronoi_topology.dart';

class _MedialEdgeData {
  bool active = false;
  double widthStart = 0;
  double widthEnd = 0;
}

class _EdgeDataView {
  const _EdgeDataView(this.data, this.reversed);
  final _MedialEdgeData data;
  final bool reversed;
}

class _ReverseGrowth {
  final List<SourcePoint2> points = [];
  final List<double> width = [];
  bool endIsEndpoint = false;
}

/// Port of the application-owned logic in `Geometry/MedialAxis.cpp`:
/// `validate_edge()`, valid-edge selection and `process_edge_neighbors()`.
///
/// All widths and coordinates use the original scaled source coordinate domain.
/// Voronoi vertex coordinates are doubles in that same domain, exactly as in
/// Boost.Polygon. Conversion back to `Point(coord_t)` uses an lrint-compatible
/// nearest-even conversion below.
///
/// The Boost-compatible segment Voronoi constructor, repair pass and
/// inside/outside annotation are separate mandatory migration layers. This
/// class deliberately does not call a substitute skeletonizer.
class MedialAxisCore {
  MedialAxisCore({
    required this.minWidth,
    required this.maxWidth,
    required List<BoundarySegment2> boundarySegments,
  }) : boundarySegments = List.unmodifiable(boundarySegments) {
    if (minWidth < 0 || maxWidth < minWidth) {
      throw ArgumentError('Require 0 <= minWidth <= maxWidth');
    }
  }

  final double minWidth;
  final double maxWidth;
  final List<BoundarySegment2> boundarySegments;

  final Map<int, _MedialEdgeData> _edgeData = {};
  late VoronoiTopology2 _diagram;

  List<ThickPolyline2> buildFromTopology(VoronoiTopology2 diagram) {
    _diagram = diagram;
    _edgeData.clear();

    for (final edge in diagram.canonicalHalfEdges) {
      _edgeData[_pairKey(edge)] = _MedialEdgeData();
    }

    // Source iterates one half-edge per twin pair and retains only primary,
    // finite edges with at least one vertex annotated Inside.
    for (final edge in diagram.canonicalHalfEdges) {
      final v0 = diagram.vertex(edge.vertex0);
      final v1 = diagram.vertex(edge.vertex1);
      if (edge.primary &&
          edge.finite &&
          (v0.category == VoronoiVertexCategory.inside ||
              v1.category == VoronoiVertexCategory.inside) &&
          validateEdge(edge)) {
        _edgeView(edge).data.active = true;
      }
    }

    final result = <ThickPolyline2>[];
    for (final seed in diagram.canonicalHalfEdges) {
      final seedView = _edgeView(seed);
      if (!seedView.data.active) continue;
      seedView.data.active = false;

      final v0 = _sourcePoint(diagram.vertex(seed.vertex0).point);
      final v1 = _sourcePoint(diagram.vertex(seed.vertex1).point);
      final polyline = ThickPolyline2(
        points: [v0, v1],
        width: [seedView.data.widthStart, seedView.data.widthEnd],
      );

      _growForward(seed, polyline);

      final reverse = _ReverseGrowth();
      _growReverse(diagram.edge(seed.twinId), reverse);
      if (reverse.points.isNotEmpty) {
        polyline.points.insertAll(0, reverse.points.reversed);
        polyline.width.insertAll(0, reverse.width.reversed);
      }
      polyline.startIsEndpoint = reverse.endIsEndpoint;

      if (polyline.firstPoint == polyline.lastPoint) {
        polyline.startIsEndpoint = false;
        polyline.endIsEndpoint = false;
      }

      polyline.thickLines(); // assert source cardinality invariant
      result.add(polyline);
    }

    return List.unmodifiable(result);
  }

  /// Exact branch structure of source `MedialAxis::validate_edge()`.
  bool validateEdge(VoronoiHalfEdge2 edge) {
    final twin = _diagram.edge(edge.twinId);
    final cellL = _diagram.cell(edge.cellIndex);
    final cellR = _diagram.cell(twin.cellIndex);
    final segmentL = _segmentFor(cellL);
    final segmentR = _segmentFor(cellR);

    final a = _sourcePoint(_diagram.vertex(edge.vertex0).point);
    final b = _sourcePoint(_diagram.vertex(edge.vertex1).point);
    final edgeLine = SourceLine2(a, b);

    var w0 = cellR.containsSegment
        ? _asLine(segmentR).distanceTo(a) * 2
        : (_endpointFor(cellR) - a).length * 2;
    var w1 = cellL.containsSegment
        ? _asLine(segmentL).distanceTo(b) * 2
        : (_endpointFor(cellL) - b).length * 2;

    if (cellL.containsSegment && cellR.containsSegment) {
      var angle = (_asLine(segmentR).orientation -
              _asLine(segmentL).orientation)
          .abs();
      if (angle > math.pi) angle = 2 * math.pi - angle;

      if (math.pi - angle > math.pi / 8) {
        if (w0 < Slic3rUnits.scaledEpsilon ||
            w1 < Slic3rUnits.scaledEpsilon ||
            edgeLine.length >= minWidth) {
          return false;
        }
      }
    } else {
      if (w0 < Slic3rUnits.scaledEpsilon ||
          w1 < Slic3rUnits.scaledEpsilon) {
        return false;
      }
    }

    if ((w0 >= minWidth || w1 >= minWidth) &&
        (w0 <= maxWidth || w1 <= maxWidth)) {
      final view = _edgeView(edge);
      if (view.reversed) {
        final tmp = w0;
        w0 = w1;
        w1 = tmp;
      }
      view.data.widthStart = w0;
      view.data.widthEnd = w1;
      return true;
    }

    return false;
  }

  void _growForward(VoronoiHalfEdge2 startingEdge, ThickPolyline2 polyline) {
    var edge = startingEdge;
    while (true) {
      final step = _singleActiveNeighborAtTarget(edge);
      if (step.neighbor == null) {
        if (step.activeNeighborCount == 0) polyline.endIsEndpoint = true;
        return;
      }

      final neighbor = step.neighbor!;
      final view = _edgeView(neighbor);
      if (!view.data.active) return;
      view.data.active = false;

      polyline.points.add(
        _sourcePoint(_diagram.vertex(neighbor.vertex1).point),
      );
      if (view.reversed) {
        polyline.width
          ..add(view.data.widthEnd)
          ..add(view.data.widthStart);
      } else {
        polyline.width
          ..add(view.data.widthStart)
          ..add(view.data.widthEnd);
      }
      edge = neighbor;
    }
  }

  void _growReverse(VoronoiHalfEdge2 startingEdge, _ReverseGrowth growth) {
    var edge = startingEdge;
    while (true) {
      final step = _singleActiveNeighborAtTarget(edge);
      if (step.neighbor == null) {
        if (step.activeNeighborCount == 0) growth.endIsEndpoint = true;
        return;
      }

      final neighbor = step.neighbor!;
      final view = _edgeView(neighbor);
      if (!view.data.active) return;
      view.data.active = false;

      growth.points.add(
        _sourcePoint(_diagram.vertex(neighbor.vertex1).point),
      );
      if (view.reversed) {
        growth.width
          ..add(view.data.widthEnd)
          ..add(view.data.widthStart);
      } else {
        growth.width
          ..add(view.data.widthStart)
          ..add(view.data.widthEnd);
      }
      edge = neighbor;
    }
  }

  _NeighborStep _singleActiveNeighborAtTarget(VoronoiHalfEdge2 edge) {
    final twin = _diagram.edge(edge.twinId);
    var neighbor = _diagram.edge(twin.rotNextId);
    var count = 0;
    VoronoiHalfEdge2? first;
    var guard = 0;

    while (neighbor.id != twin.id) {
      if (_edgeView(neighbor).data.active) {
        if (count == 0) first = neighbor;
        count++;
      }
      neighbor = _diagram.edge(neighbor.rotNextId);
      if (++guard > _diagram.edges.length) {
        throw StateError('Invalid Voronoi rotNext cycle at edge ${twin.id}');
      }
    }

    return _NeighborStep(
      activeNeighborCount: count,
      neighbor: count == 1 ? first : null,
    );
  }

  _EdgeDataView _edgeView(VoronoiHalfEdge2 edge) {
    final key = _pairKey(edge);
    final data = _edgeData[key];
    if (data == null) {
      throw StateError('Missing edge data for Voronoi pair $key');
    }
    return _EdgeDataView(data, edge.id > edge.twinId);
  }

  int _pairKey(VoronoiHalfEdge2 edge) => math.min(edge.id, edge.twinId);

  BoundarySegment2 _segmentFor(VoronoiCell2 cell) {
    if (cell.sourceIndex < 0 || cell.sourceIndex >= boundarySegments.length) {
      throw StateError('Voronoi cell has invalid source segment index');
    }
    return boundarySegments[cell.sourceIndex];
  }

  SourcePoint2 _endpointFor(VoronoiCell2 cell) {
    final segment = _segmentFor(cell);
    switch (cell.sourceCategory) {
      case VoronoiSourceCategory.segmentStartPoint:
        return segment.a;
      case VoronoiSourceCategory.segmentEndPoint:
        return segment.b;
      case VoronoiSourceCategory.segment:
        throw StateError('Segment cell does not identify a single endpoint');
    }
  }

  SourceLine2 _asLine(BoundarySegment2 segment) =>
      SourceLine2(segment.a, segment.b);

  SourcePoint2 _sourcePoint(VoronoiPoint2 point) =>
      SourcePoint2(_lrint(point.x), _lrint(point.y));

  /// C/C++ `lrint()` under the default FE_TONEAREST mode: nearest integer,
  /// halfway cases to even. Boost/POSIX builds use this when constructing a
  /// Slic3r `Point` from Voronoi double coordinates.
  int _lrint(double value) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'Voronoi coordinate', 'must be finite');
    }
    final lower = value.floor();
    final fraction = value - lower;
    if (fraction < 0.5) return lower;
    if (fraction > 0.5) return lower + 1;
    return lower.isEven ? lower : lower + 1;
  }
}

class _NeighborStep {
  const _NeighborStep({
    required this.activeNeighborCount,
    required this.neighbor,
  });

  final int activeNeighborCount;
  final VoronoiHalfEdge2? neighbor;
}
