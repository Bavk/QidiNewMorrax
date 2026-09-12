import 'medial_axis_core.dart';
import 'medial_axis_postprocess.dart';
import 'source_polygon.dart';
import 'source_polyline.dart';
import 'source_voronoi_annotation.dart';
import 'source_voronoi_diagram.dart';
import 'thick_polyline.dart';
import 'voronoi_topology.dart';

class SourceMedialAxisRawResult2 {
  const SourceMedialAxisRawResult2({
    required this.lines,
    required this.diagram,
    required this.annotatedTopology,
    required this.polylines,
  });

  final List<BoundarySegment2> lines;
  final SourceVoronoiBuildResult2 diagram;
  final VoronoiTopology2 annotatedTopology;
  final List<ThickPolyline2> polylines;
}

/// Direct composition of source `Geometry::MedialAxis::MedialAxis()` and
/// `MedialAxis::build(ThickPolylines*)` around the already ported source units.
///
/// The only injected dependency is the still-pending exact Boost.Polygon
/// segment Voronoi constructor. No alternate skeletonizer is accepted here.
/// Just like the C++ source, [buildThick] does **not** abort when the QIDI
/// rotation repair state is unsuccessful: `construct_voronoi()` leaves its
/// last diagram installed and `MedialAxis::build()` proceeds to annotation.
class SourceMedialAxis2 {
  SourceMedialAxis2({
    required this.minWidth,
    required this.maxWidth,
    required this.expolygon,
    required this.voronoiBuilder,
  });

  final double minWidth;
  final double maxWidth;
  final SourceExPolygon2 expolygon;
  final SourceVoronoiTopologyBuilder2 voronoiBuilder;

  SourceMedialAxisRawResult2 buildThick() {
    final lines = <BoundarySegment2>[
      for (final line in expolygon.lines()) BoundarySegment2(line.a, line.b),
    ];

    final diagram = const SourceVoronoiDiagram2().construct(
      lines,
      builder: voronoiBuilder,
    );

    // Source intentionally performs this even after REPAIR_UNSUCCESSFUL.
    final annotated = const SourceVoronoiAnnotator2().annotate(
      diagram.topology,
      lines,
    );

    final polylines = MedialAxisCore(
      minWidth: minWidth,
      maxWidth: maxWidth,
      boundarySegments: lines,
    ).buildFromTopology(annotated);

    return SourceMedialAxisRawResult2(
      lines: List.unmodifiable(lines),
      diagram: diagram,
      annotatedTopology: annotated,
      polylines: List.unmodifiable(polylines),
    );
  }

  /// Port of the simple source `MedialAxis::build(Polylines*)` overload.
  List<SourcePolyline2> buildPolylines() => [
        for (final thick in buildThick().polylines)
          SourcePolyline2(thick.points),
      ];
}

class SourceExPolygonMedialAxisResult2 {
  const SourceExPolygonMedialAxisResult2({
    required this.raw,
    required this.polylines,
  });

  final SourceMedialAxisRawResult2 raw;
  final List<ThickPolyline2> polylines;
}

/// Port of `ExPolygon::medial_axis(min_width,max_width,ThickPolylines*)`.
///
/// Raw Voronoi/MedialAxis extraction belongs to [SourceMedialAxis2]. This
/// wrapper applies the source endpoint extension, short-branch filtering and
/// greedy reconnect phase from `ExPolygon.cpp` via [MedialAxisPostProcessor].
class SourceExPolygonMedialAxis2 {
  const SourceExPolygonMedialAxis2._();

  static SourceExPolygonMedialAxisResult2 buildThick({
    required SourceExPolygon2 expolygon,
    required double minWidth,
    required double maxWidth,
    required SourceVoronoiTopologyBuilder2 voronoiBuilder,
  }) {
    final raw = SourceMedialAxis2(
      minWidth: minWidth,
      maxWidth: maxWidth,
      expolygon: expolygon,
      voronoiBuilder: voronoiBuilder,
    ).buildThick();

    final processed = const MedialAxisPostProcessor().process(
      expolygon: expolygon,
      rawPolylines: raw.polylines,
      maxWidth: maxWidth,
    );

    return SourceExPolygonMedialAxisResult2(
      raw: raw,
      polylines: List.unmodifiable(processed),
    );
  }

  /// Port of `ExPolygon::medial_axis(..., Polylines*)`: run the ThickPolyline
  /// path first and then discard width/endpoints while retaining point order.
  static List<SourcePolyline2> buildPolylines({
    required SourceExPolygon2 expolygon,
    required double minWidth,
    required double maxWidth,
    required SourceVoronoiTopologyBuilder2 voronoiBuilder,
  }) =>
      [
        for (final thick in buildThick(
          expolygon: expolygon,
          minWidth: minWidth,
          maxWidth: maxWidth,
          voronoiBuilder: voronoiBuilder,
        ).polylines)
          SourcePolyline2(thick.points),
      ];
}
