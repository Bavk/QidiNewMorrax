import '../geometry/source_polygon.dart';
import '../geometry/voronoi_topology.dart';

/// Direct source-shaped index into one polygon point, matching
/// `Arachne::PolygonsPointIndex` for the represented immutable polygon list.
class SourceArachnePolygonsPointIndex2 {
  const SourceArachnePolygonsPointIndex2({
    required this.polygons,
    required this.polygonIndex,
    required this.pointIndex,
  });

  final List<SourcePolygon2> polygons;
  final int polygonIndex;
  final int pointIndex;

  SourcePolygon2 get polygon => polygons[polygonIndex];
  SourcePoint2 get p => polygon.points[pointIndex];

  SourceArachnePolygonsPointIndex2 next() => SourceArachnePolygonsPointIndex2(
        polygons: polygons,
        polygonIndex: polygonIndex,
        pointIndex: (pointIndex + 1) % polygon.points.length,
      );

  SourceArachnePolygonsPointIndex2 prev() => SourceArachnePolygonsPointIndex2(
        polygons: polygons,
        polygonIndex: polygonIndex,
        pointIndex:
            pointIndex == 0 ? polygon.points.length - 1 : pointIndex - 1,
      );
}

/// Direct source-shaped polygon edge index, matching
/// `Arachne::PolygonsSegmentIndex`.
class SourceArachnePolygonsSegmentIndex2 {
  const SourceArachnePolygonsSegmentIndex2({
    required this.pointIndex,
  });

  final SourceArachnePolygonsPointIndex2 pointIndex;

  int get polygonIndex => pointIndex.polygonIndex;
  int get localPointIndex => pointIndex.pointIndex;
  SourcePoint2 get from => pointIndex.p;
  SourcePoint2 get to => pointIndex.next().p;
  BoundarySegment2 get boundarySegment => BoundarySegment2(from, to);
}

/// Flattened source segment vector produced by
/// `SkeletalTrapezoidation::constructFromPolygons()`.
class SourceArachnePolygonSegments2 {
  SourceArachnePolygonSegments2(List<SourcePolygon2> sourcePolygons) {
    polygons = List<SourcePolygon2>.unmodifiable(sourcePolygons);
    indices = <SourceArachnePolygonsSegmentIndex2>[
      for (var polygonIndex = 0;
          polygonIndex < polygons.length;
          polygonIndex++)
        for (var pointIndex = 0;
            pointIndex < polygons[polygonIndex].points.length;
            pointIndex++)
          SourceArachnePolygonsSegmentIndex2(
            pointIndex: SourceArachnePolygonsPointIndex2(
              polygons: polygons,
              polygonIndex: polygonIndex,
              pointIndex: pointIndex,
            ),
          ),
    ];
    boundarySegments = List<BoundarySegment2>.unmodifiable(
      indices.map((index) => index.boundarySegment),
    );
  }

  late final List<SourcePolygon2> polygons;
  late final List<SourceArachnePolygonsSegmentIndex2> indices;
  late final List<BoundarySegment2> boundarySegments;

  SourceArachnePolygonsSegmentIndex2 segmentIndexForCell(VoronoiCell2 cell) {
    if (cell.sourceIndex < 0 || cell.sourceIndex >= indices.length) {
      throw RangeError.index(cell.sourceIndex, indices, 'sourceIndex');
    }
    return indices[cell.sourceIndex];
  }

  /// Literal `VoronoiUtils::get_source_point_index()` behavior for
  /// `PolygonsSegmentIndex` input.
  SourceArachnePolygonsPointIndex2 sourcePointIndex(VoronoiCell2 cell) {
    if (!cell.containsPoint) {
      throw ArgumentError('Voronoi cell does not contain a source point');
    }
    final segment = segmentIndexForCell(cell);
    switch (cell.sourceCategory) {
      case VoronoiSourceCategory.segmentStartPoint:
        return segment.pointIndex;
      case VoronoiSourceCategory.segmentEndPoint:
        return segment.pointIndex.next();
      case VoronoiSourceCategory.segment:
        throw ArgumentError('Segment category is not a point site');
    }
  }
}
