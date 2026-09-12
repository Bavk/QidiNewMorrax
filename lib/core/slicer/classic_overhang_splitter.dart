import '../geometry/clipper_geometry.dart';
import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import '../geometry/source_polyline.dart';
import 'classic_overhang_degree.dart';
import 'classic_overhang_support.dart';
import 'extrusion_entity.dart';
import 'flow.dart';
import 'source_shortest_path.dart';

/// Source constant from `OverhangDetector.hpp`.
const int sourceOverhangSamplingNumber = 6;

/// Ports the classic `traverse_loops()` overhang split.
///
/// Both source branches first split the perimeter against the widest/largest
/// lower-polygon sample (`back()`). The no-speed branch emits every supported
/// run at degree zero. The speed-graded branch splits those supported runs
/// again against `front()`: fully supported runs stay at zero while the middle
/// overhang band is graded by `detect_overhang_degree()`. Fully unsupported
/// runs always use `erOverhangPerimeter`, overhang flow, and source bridge-wall
/// degree 5/6 classification.
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
    final split = _splitAgainstLast(
      polygon: polygon,
      lowerPolygonsSeries: lowerPolygonsSeries,
    );
    final paths = <ExtrusionPath2>[];
    _append(
      paths,
      split.inside,
      overhangDegree: 0,
      role: supportedRole,
      mm3PerMm: supportedFlow.mm3PerMm,
      width: supportedFlow.width,
      height: layerHeight,
    );
    _appendUnsupported(
      paths,
      split.unsupported,
      overhangFlow: overhangFlow,
    );
    return _chain(paths);
  }

  /// Literal speed-enabled classic branch from `traverse_loops()`:
  ///
  /// 1. intersect/diff the source loop against `lower_series.back()`;
  /// 2. intersect supported runs against `front()` for degree zero;
  /// 3. diff supported runs against `front()` for intermediate grading;
  /// 4. grade that middle band against the `front()` polygon perimeter using
  ///    the source distance boundary;
  /// 5. append fully unsupported bridge-wall runs with overhang flow;
  /// 6. re-chain all generated paths from the first generated endpoint.
  List<ExtrusionPath2> splitWithSpeedGrading({
    required SourcePolygon2 polygon,
    required List<List<SourcePolygon2>> lowerPolygonsSeries,
    required SourceOverhangDistanceBoundary2 overhangDistBoundary,
    required ExtrusionRole supportedRole,
    required Flow supportedFlow,
    required Flow overhangFlow,
    required double layerHeight,
  }) {
    if (lowerPolygonsSeries.length < 2) {
      throw ArgumentError(
        'source speed grading requires front/back lower polygon samples',
      );
    }
    final split = _splitAgainstLast(
      polygon: polygon,
      lowerPolygonsSeries: lowerPolygonsSeries,
    );
    final zeroDegree = clipper.intersectionSourceOpenPolylines(
      split.inside,
      lowerPolygonsSeries.first,
    );
    final middleOverhang = clipper.differenceSourceOpenPolylines(
      split.inside,
      lowerPolygonsSeries.first,
    );

    final paths = <ExtrusionPath2>[];
    _append(
      paths,
      zeroDegree,
      overhangDegree: 0,
      role: supportedRole,
      mm3PerMm: supportedFlow.mm3PerMm,
      width: supportedFlow.width,
      height: layerHeight,
    );
    paths.addAll(SourceClassicOverhangDegree2.detect(
      lowerPolygons: lowerPolygonsSeries.first,
      middleOverhangPolylines: middleOverhang,
      role: supportedRole,
      extrusionMm3PerMm: supportedFlow.mm3PerMm,
      extrusionWidth: supportedFlow.width,
      layerHeight: layerHeight,
      lowerBound: overhangDistBoundary.first,
      upperBound: overhangDistBoundary.second,
    ));
    _appendUnsupported(
      paths,
      split.unsupported,
      overhangFlow: overhangFlow,
    );
    return _chain(paths);
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

  ({List<SourcePolyline2> inside, List<SourcePolyline2> unsupported})
      _splitAgainstLast({
    required SourcePolygon2 polygon,
    required List<List<SourcePolygon2>> lowerPolygonsSeries,
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
    return (
      inside: clipper.intersectionSourceOpenPolylines(
        [sourcePolyline],
        supportedClip,
      ),
      unsupported: clipper.differenceSourceOpenPolylines(
        [sourcePolyline],
        supportedClip,
      ),
    );
  }

  void _appendUnsupported(
    List<ExtrusionPath2> destination,
    List<SourcePolyline2> unsupported, {
    required Flow overhangFlow,
  }) {
    for (final polyline in unsupported) {
      destination.add(ExtrusionPath2(
        polyline: polyline,
        overhangDegree: unsupportedOverhangDegree(polyline).toDouble(),
        curveDegree: 0,
        role: ExtrusionRole.overhangPerimeter,
        mm3PerMm: overhangFlow.mm3PerMm,
        width: overhangFlow.width,
        height: overhangFlow.height,
      ));
    }
  }

  List<ExtrusionPath2> _chain(List<ExtrusionPath2> paths) {
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
