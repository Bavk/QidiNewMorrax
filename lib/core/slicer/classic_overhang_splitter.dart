import '../geometry/clipper_geometry.dart';
import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import '../geometry/source_polyline.dart';
import 'extrusion_entity.dart';
import 'flow.dart';
import 'source_shortest_path.dart';

/// Source constant from `OverhangDetector.hpp`.
const int sourceOverhangSamplingNumber = 6;

/// Ports the classic `traverse_loops()` overhang branch for the configuration
/// where overhang-speed grading is disabled.
///
/// QIDI still splits the loop against the last lower-polygon sample in this
/// mode. Supported runs keep the perimeter role/flow at degree zero, while
/// unsupported runs are emitted as `erOverhangPerimeter` with overhang flow.
/// `detect_bridge_wall()` then marks bent unsupported runs as degree 5 and
/// straight bridge runs as degree 6.
class SourceClassicOverhangSplitter2 {
  const SourceClassicOverhangSplitter2({
    this.clipper = const ClipperGeometry(),
  });

  final ClipperGeometry clipper;

  List<ExtrusionPath2> splitWithoutSpeedGrading({
    required SourcePolygon2 polygon,
    required List<List<SourcePolygon2>> lowerPolygonsSeries,
    required ExtrusionRole supportedRole,
    required Flow supportedFlow,
    required Flow overhangFlow,
    required double layerHeight,
  }) {
    if (polygon.points.length < 3) {
      throw StateError('overhang perimeter polygon must have >= 3 points');
    }
    if (lowerPolygonsSeries.isEmpty) {
      throw ArgumentError(
        'source overhang branch requires a non-empty lower polygon series',
      );
    }

    final sourcePolyline = SourcePolyline2([
      ...polygon.points,
      polygon.points.first,
    ]);
    final supportedClip = lowerPolygonsSeries.last;
    final inside = clipper.intersectionSourceOpenPolylines(
      [sourcePolyline],
      supportedClip,
    );
    final unsupported = clipper.differenceSourceOpenPolylines(
      [sourcePolyline],
      supportedClip,
    );

    final paths = <ExtrusionPath2>[];
    _append(
      paths,
      inside,
      overhangDegree: 0,
      role: supportedRole,
      mm3PerMm: supportedFlow.mm3PerMm,
      width: supportedFlow.width,
      height: layerHeight,
    );

    for (final polyline in unsupported) {
      paths.add(ExtrusionPath2(
        polyline: polyline,
        overhangDegree: unsupportedOverhangDegree(polyline).toDouble(),
        curveDegree: 0,
        role: ExtrusionRole.overhangPerimeter,
        mm3PerMm: overhangFlow.mm3PerMm,
        width: overhangFlow.width,
        height: overhangFlow.height,
      ));
    }

    if (paths.isEmpty) return const [];

    // Source reapplies nearest-point ordering because Clipper may reverse open
    // runs. `chain_extrusion_paths()` uses the same greedy constrained-reversal
    // primitive as the already-ported entity chain, with every path reversible.
    final entities = <ExtrusionEntity2>[...paths];
    final chain = SourceShortestPath2.chainExtrusionEntities(
      entities,
      startNear: paths.first.firstPoint,
    );
    final reordered = <ExtrusionPath2>[];
    for (final entry in chain) {
      final path = paths[entry.index];
      if (entry.reversed) path.reverse();
      reordered.add(path);
    }
    return reordered;
  }

  /// Literal `detect_bridge_wall()` degree classification.
  int unsupportedOverhangDegree(SourcePolyline2 polyline) {
    if (!polyline.isValid) {
      throw StateError('unsupported overhang polyline must be valid');
    }
    final chord = SourceLine2(polyline.firstPoint, polyline.lastPoint).length;
    return chord < polyline.length
        ? sourceOverhangSamplingNumber - 1
        : sourceOverhangSamplingNumber;
  }

  static void _append(
    List<ExtrusionPath2> destination,
    List<SourcePolyline2> polylines, {
    required int overhangDegree,
    required ExtrusionRole role,
    required double mm3PerMm,
    required double width,
    required double height,
  }) {
    for (final polyline in polylines) {
      destination.add(ExtrusionPath2(
        polyline: polyline,
        overhangDegree: overhangDegree.toDouble(),
        curveDegree: 0,
        role: role,
        mm3PerMm: mm3PerMm,
        width: width,
        height: height,
      ));
    }
  }
}
