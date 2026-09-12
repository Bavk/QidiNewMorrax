import 'dart:math' as math;

import '../geometry/clipper_geometry.dart';
import '../geometry/expolygon.dart';
import '../geometry/point.dart';
import '../geometry/polygon.dart';
import '../geometry/source_arc_fitter.dart';
import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import '../geometry/source_polyline.dart';
import 'extrusion_entity.dart';
import 'source_fuzzy_skin_policy.dart';
import 'source_shortest_path.dart';
import 'surface.dart';

class SourceClassicSurfacePrepareSettings2 {
  const SourceClassicSurfacePrepareSettings2({
    required this.resolutionMm,
    required this.enableArcFitting,
    required this.fuzzySkinType,
    required this.wallLoops,
    this.alternateExtraWall = false,
    this.spiralVase = false,
  });

  /// Source `print_config->resolution.value` before the constructor's
  /// `max(resolution, EPSILON)` and `scaled<double>()` boundary.
  final double resolutionMm;
  final bool enableArcFitting;
  final SourceFuzzySkinType2 fuzzySkinType;
  final int wallLoops;
  final bool alternateExtraWall;
  final bool spiralVase;
}

class SourceClassicPreparedSurface2 {
  const SourceClassicPreparedSurface2({
    required this.sourceIndex,
    required this.surface,
    required this.simplified,
    required this.loopNumber,
    required this.counterCircleCompensation,
    required this.compensationHoleCenters,
  });

  /// Index in the source `all_surfaces` vector after `process_no_bridge()`.
  final int sourceIndex;
  final Surface2 surface;

  /// Exact represented `union_ex(surface.expolygon.simplify_p(...))` result.
  final List<ExPolygon2> simplified;

  /// Source zero-indexed `loop_number` before top-one-wall gates.
  final int loopNumber;

  /// Local source copy. It is disabled when simplification splits the island.
  final bool counterCircleCompensation;

  /// Centroids captured from the pre-simplified holes selected by QIDI's
  /// `holes_circle_compensation` indices.
  final List<SourcePoint2> compensationHoleCenters;

  /// Literal source `distance < 1000` compensation-hole lookup.
  bool isCompensationHole(SourcePolygon2 hole) {
    final center = SourceClassicSurfacePrepare2.sourceCentroid(hole);
    for (final expected in compensationHoleCenters) {
      final dx = center.x.toDouble() - expected.x;
      final dy = center.y.toDouble() - expected.y;
      if (math.sqrt(dx * dx + dy * dy) < 1000) return true;
    }
    return false;
  }
}

class SourceClassicSurfacePrepareResult2 {
  const SourceClassicSurfacePrepareResult2({
    required this.surfaceOrder,
    required this.surfaceSimplifyResolutionSource,
    required this.baseResolutionSource,
    required this.prepared,
  });

  final List<int> surfaceOrder;
  final double surfaceSimplifyResolutionSource;
  final double baseResolutionSource;
  final List<SourceClassicPreparedSurface2> prepared;

  double get surfaceSimplifyResolutionMm =>
      surfaceSimplifyResolutionSource * Slic3rUnits.scalingFactor;

  double get baseResolutionMm =>
      baseResolutionSource * Slic3rUnits.scalingFactor;
}

/// Ports the source block immediately following `process_no_bridge()` in
/// `PerimeterGenerator::process_classic()`:
///
/// * constructor `m_scaled_resolution` boundary;
/// * the arc-fitting + `FuzzySkinType::None` 0.2 simplification branch;
/// * `chain_expolygons()` ordering by source bbox centers;
/// * `wall_loops + surface.extra_perimeters - 1` and alternate-extra-wall;
/// * QIDI circle-compensation metadata capture;
/// * `union_ex(surface.expolygon.simplify_p(surface_simplify_resolution))`.
class SourceClassicSurfacePrepare2 {
  const SourceClassicSurfacePrepare2({this.clipper = const ClipperGeometry()});

  final ClipperGeometry clipper;

  SourceClassicSurfacePrepareResult2 prepare(
    List<Surface2> allSurfaces,
    SourceClassicSurfacePrepareSettings2 settings, {
    required int layerIndex,
  }) {
    _validate(settings, layerIndex);

    final baseResolutionSource =
        math.max(settings.resolutionMm, Slic3rUnits.epsilon) /
            Slic3rUnits.scalingFactor;
    final surfaceSimplifyResolutionSource =
        settings.enableArcFitting &&
                settings.fuzzySkinType == SourceFuzzySkinType2.none
            ? 0.2 * baseResolutionSource
            : baseResolutionSource;

    final surfaceOrder = _chainExPolygons([
      for (final surface in allSurfaces) surface.expolygon,
    ]);

    final prepared = <SourceClassicPreparedSurface2>[];
    for (final sourceIndex in surfaceOrder) {
      final surface = allSurfaces[sourceIndex];

      var loopNumber = settings.wallLoops + surface.extraPerimeters - 1;
      if (settings.alternateExtraWall && layerIndex.isOdd && !settings.spiralVase) {
        loopNumber++;
      }

      var counterCircleCompensation = surface.counterCircleCompensation;
      final compensationHoleCenters = <SourcePoint2>[];
      for (final holeIndex in surface.holesCircleCompensation) {
        compensationHoleCenters.add(
          sourceCentroid(surface.expolygon.holes[holeIndex]),
        );
      }

      final simplified = _simplifyAndUnion(
        surface.expolygon,
        surfaceSimplifyResolutionSource,
      );
      if (simplified.length != 1) counterCircleCompensation = false;

      prepared.add(
        SourceClassicPreparedSurface2(
          sourceIndex: sourceIndex,
          surface: surface,
          simplified: List.unmodifiable(simplified),
          loopNumber: loopNumber,
          counterCircleCompensation: counterCircleCompensation,
          compensationHoleCenters: List.unmodifiable(compensationHoleCenters),
        ),
      );
    }

    return SourceClassicSurfacePrepareResult2(
      surfaceOrder: List.unmodifiable(surfaceOrder),
      surfaceSimplifyResolutionSource: surfaceSimplifyResolutionSource,
      baseResolutionSource: baseResolutionSource,
      prepared: List.unmodifiable(prepared),
    );
  }

  List<int> _chainExPolygons(List<SourceExPolygon2> input) {
    if (input.isEmpty) return const [];

    // Pinned `chain_expolygons()` maps each ExPolygon to `get_extents(ex).center()`
    // and then delegates to `chain_points()`. Reuse the already-ported source
    // multi-fragment algorithm by representing each point as a degenerate path.
    final entities = <ExtrusionEntity2>[];
    for (final expolygon in input) {
      final center = _bboxCenter(expolygon);
      entities.add(
        ExtrusionPath2(
          polyline: SourcePolyline2([center, center]),
          canReverse: true,
        ),
      );
    }
    final chain = SourceShortestPath2.chainExtrusionEntities(entities);
    return [for (final entry in chain) entry.index];
  }

  SourcePoint2 _bboxCenter(SourceExPolygon2 expolygon) {
    final points = expolygon.contour.points;
    if (points.isEmpty) {
      throw ArgumentError('source ExPolygon contour must not be empty');
    }
    var minX = points.first.x;
    var minY = points.first.y;
    var maxX = minX;
    var maxY = minY;
    for (final point in points.skip(1)) {
      minX = math.min(minX, point.x);
      minY = math.min(minY, point.y);
      maxX = math.max(maxX, point.x);
      maxY = math.max(maxY, point.y);
    }
    // C++ integer vector division truncates toward zero.
    return SourcePoint2((minX + maxX) ~/ 2, (minY + maxY) ~/ 2);
  }

  List<ExPolygon2> _simplifyAndUnion(
    SourceExPolygon2 expolygon,
    double toleranceSource,
  ) {
    final polygons = <Polygon2>[];
    polygons.add(_simplifyPolygon(expolygon.contour, toleranceSource));
    for (final hole in expolygon.holes) {
      polygons.add(_simplifyPolygon(hole, toleranceSource));
    }
    return clipper.unionEx(polygons);
  }

  Polygon2 _simplifyPolygon(
    SourcePolygon2 polygon,
    double toleranceSource,
  ) {
    if (polygon.points.length < 3) {
      return _toMillimeterPolygon(polygon);
    }
    final closed = [...polygon.points, polygon.points.first];
    final simplified = ArcFitter2.douglasPeucker(closed, toleranceSource);
    if (simplified.isNotEmpty) simplified.removeLast();
    return _toMillimeterPolygon(SourcePolygon2(simplified));
  }

  Polygon2 _toMillimeterPolygon(SourcePolygon2 polygon) => Polygon2([
        for (final point in polygon.points)
          Point2(
            point.x * Slic3rUnits.scalingFactor,
            point.y * Slic3rUnits.scalingFactor,
          ),
      ]);

  /// Pinned `Polygon::centroid()` followed by `Point(Vec2d)`, whose supplied
  /// source uses C `lrint` nearest-even conversion.
  static SourcePoint2 sourceCentroid(SourcePolygon2 polygon) {
    final points = polygon.points;
    if (points.length < 3) {
      throw ArgumentError('source polygon centroid requires at least 3 points');
    }

    var areaSum = 0.0;
    var cx = 0.0;
    var cy = 0.0;
    var previous = points.last;
    for (final point in points) {
      final cross = previous.x.toDouble() * point.y -
          previous.y.toDouble() * point.x;
      areaSum += cross;
      cx += (previous.x.toDouble() + point.x) * cross;
      cy += (previous.y.toDouble() + point.y) * cross;
      previous = point;
    }
    if (areaSum == 0) {
      throw ArgumentError('source polygon centroid is undefined for zero area');
    }
    return SourcePoint2(
      _lrint(cx / (3.0 * areaSum)),
      _lrint(cy / (3.0 * areaSum)),
    );
  }

  static int _lrint(double value) {
    final lower = value.floor();
    final fraction = value - lower;
    if (fraction < 0.5) return lower;
    if (fraction > 0.5) return lower + 1;
    return lower.isEven ? lower : lower + 1;
  }

  void _validate(
    SourceClassicSurfacePrepareSettings2 settings,
    int layerIndex,
  ) {
    if (!settings.resolutionMm.isFinite || settings.resolutionMm < 0) {
      throw ArgumentError.value(
        settings.resolutionMm,
        'resolutionMm',
        'must be finite and >= 0',
      );
    }
    if (settings.wallLoops < 0) {
      throw ArgumentError.value(settings.wallLoops, 'wallLoops', 'must be >= 0');
    }
    if (layerIndex < 0) {
      throw ArgumentError.value(layerIndex, 'layerIndex', 'must be >= 0');
    }
  }
}
