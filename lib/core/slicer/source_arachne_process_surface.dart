import '../geometry/source_arc_fitter.dart';
import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import 'source_arachne_extrusion_line.dart';
import 'source_arachne_process_planning.dart';
import 'source_arachne_wall_tool_paths.dart';
import 'source_arachne_wall_tool_paths_facade.dart';
import 'source_arachne_wall_tool_paths_generate.dart';
import 'source_arachne_wall_tool_paths_prepare.dart';
import 'surface.dart';

class SourceArachneSurfaceProcessSettings2 {
  const SourceArachneSurfaceProcessSettings2({
    required this.planning,
    required this.surfaceSimplifyResolutionSource,
    required this.perimeterSpacing,
    required this.layerHeightMm,
  });

  final SourceArachneProcessPlanningSettings2 planning;
  final double surfaceSimplifyResolutionSource;
  final int perimeterSpacing;
  final double layerHeightMm;
}

class SourceArachneSurfaceProcessResult2 {
  const SourceArachneSurfaceProcessResult2({
    required this.plan,
    required this.lastPolygons,
    required this.wallInputPolygons,
    required this.applyCircleCompensation,
    required this.circlePolygonIndices,
    required this.totalPerimeters,
    required this.infillContour,
    this.wallToolPaths,
  });

  final SourceArachneSurfaceWallPlan2 plan;

  /// Flattened source `last` after simplify + external-wall offset.
  final List<SourcePolygon2> lastPolygons;

  /// Source `last_p`, ordered contour first then holes when the topology gate
  /// permits circle-compensation flags.
  final List<SourcePolygon2> wallInputPolygons;

  final bool applyCircleCompensation;
  final List<int> circlePolygonIndices;
  final List<List<SourceArachneExtrusionLine2>> totalPerimeters;
  final List<SourcePolygon2> infillContour;
  final SourceArachneWallToolPathsGenerated2? wallToolPaths;
}

/// Second high-level slice of pinned `PerimeterGenerator::process_arachne()`:
/// simplify/offset one surface, circle-compensation topology gate, then the
/// non-separated one-wall/normal `WallToolPaths` branches.
///
/// The `Alltop` separated-wall branch is intentionally rejected here and is
/// ported by the next source-order layer; silently treating it as a normal wall
/// pass would alter both top geometry and inset indices.
class SourceArachneProcessSurface2 {
  const SourceArachneProcessSurface2._();

  static SourceArachneSurfaceProcessResult2 process({
    required Surface2 surface,
    required SourceArachneSurfaceProcessSettings2 settings,
    required int layerIndex,
  }) {
    final plan = SourceArachneProcessPlanning2.planSurface(
      settings: settings.planning,
      extraPerimeters: surface.extraPerimeters,
      layerIndex: layerIndex,
    );

    final simplified = _simplifyExPolygon(
      surface.expolygon,
      settings.surfaceSimplifyResolutionSource,
    );
    final last = SourceArachneWallToolPathsPrepare2.offsetPolygons(
      simplified,
      plan.outerOffsetDelta,
    );

    final rootCount = _rootCount(last);
    final originalContourCount = surface.expolygon.holes.length + 1;
    final applyCircleCompensation =
        rootCount == 1 && last.length == originalContourCount;

    var wallInput = List<SourcePolygon2>.of(last);
    final circlePolygonIndices = <int>[];
    if (applyCircleCompensation) {
      wallInput = _orderSingleExPolygonLikeSource(last, surface.expolygon);
      if (surface.counterCircleCompensation) {
        circlePolygonIndices.add(0);
      }
      for (final holeIndex in surface.holesCircleCompensation) {
        circlePolygonIndices.add(holeIndex + 1);
      }
    }

    if (plan.loopNumber < 0) {
      return SourceArachneSurfaceProcessResult2(
        plan: plan,
        lastPolygons: List.unmodifiable(last),
        wallInputPolygons: List.unmodifiable(wallInput),
        applyCircleCompensation: applyCircleCompensation,
        circlePolygonIndices: List.unmodifiable(circlePolygonIndices),
        totalPerimeters: const [],
        infillContour: List.unmodifiable(last),
      );
    }

    if (plan.separateWallGenerationCandidate) {
      throw UnsupportedError(
        'Pinned Alltop separated-wall geometry must be processed by the '
        'dedicated source-order branch',
      );
    }

    final state = SourceArachneWallToolPathsState2(
      outline: wallInput,
      beadWidth0: settings.planning.extPerimeterSpacing,
      beadWidthX: settings.perimeterSpacing,
      insetCount: plan.initialInsetCount!,
      wall0Inset: plan.wall0Inset,
      layerHeightMm: settings.layerHeightMm,
      params: plan.params,
    );
    final facade = SourceArachneWallToolPathsFacade2(state);
    if (applyCircleCompensation) {
      facade.enableHoleCompensation(true, circlePolygonIndices);
    }

    final totalPerimeters = facade.getToolPaths();
    final infillContour = SourceArachneWallToolPathsPrepare2.unionNonZero(
      facade.getInnerContour(),
    );

    return SourceArachneSurfaceProcessResult2(
      plan: plan,
      lastPolygons: List.unmodifiable(last),
      wallInputPolygons: List.unmodifiable(wallInput),
      applyCircleCompensation: applyCircleCompensation,
      circlePolygonIndices: List.unmodifiable(circlePolygonIndices),
      totalPerimeters: totalPerimeters,
      infillContour: List.unmodifiable(infillContour),
      wallToolPaths: facade.latest,
    );
  }

  static List<SourcePolygon2> _simplifyExPolygon(
    SourceExPolygon2 expolygon,
    double toleranceSource,
  ) {
    final polygons = <SourcePolygon2>[
      _simplifyPolygon(expolygon.contour, toleranceSource),
      for (final hole in expolygon.holes)
        _simplifyPolygon(hole, toleranceSource),
    ];
    return SourceArachneWallToolPathsPrepare2.unionNonZero(polygons);
  }

  static SourcePolygon2 _simplifyPolygon(
    SourcePolygon2 polygon,
    double toleranceSource,
  ) {
    if (polygon.points.length < 3) return polygon;
    final closed = <SourcePoint2>[...polygon.points, polygon.points.first];
    final simplified = ArcFitter2.douglasPeucker(closed, toleranceSource);
    if (simplified.isNotEmpty) simplified.removeLast();
    return SourcePolygon2(simplified);
  }

  static int _rootCount(List<SourcePolygon2> polygons) {
    var roots = 0;
    for (var index = 0; index < polygons.length; index++) {
      final polygon = polygons[index];
      if (polygon.points.isEmpty) continue;
      final probe = polygon.points.first;
      var contained = false;
      for (var otherIndex = 0;
          otherIndex < polygons.length;
          otherIndex++) {
        if (otherIndex == index) continue;
        final other = polygons[otherIndex];
        if (other.area <= polygon.area) continue;
        if (other.contains(probe, borderResult: false)) {
          contained = true;
          break;
        }
      }
      if (!contained) roots++;
    }
    return roots;
  }

  static List<SourcePolygon2> _orderSingleExPolygonLikeSource(
    List<SourcePolygon2> polygons,
    SourceExPolygon2 original,
  ) {
    if (polygons.isEmpty) return const [];

    var contourIndex = 0;
    for (var index = 1; index < polygons.length; index++) {
      if (polygons[index].area > polygons[contourIndex].area) {
        contourIndex = index;
      }
    }
    final contour = polygons[contourIndex];
    final remaining = <SourcePolygon2>[
      for (var index = 0; index < polygons.length; index++)
        if (index != contourIndex) polygons[index],
    ];

    final orderedHoles = <SourcePolygon2>[];
    for (final originalHole in original.holes) {
      final probe = _centroidOrFirst(originalHole);
      var matchIndex = -1;
      for (var index = 0; index < remaining.length; index++) {
        if (remaining[index].contains(probe)) {
          matchIndex = index;
          break;
        }
      }
      if (matchIndex < 0) {
        // Topology count matched, so this is a Clipper ordering/geometry seam;
        // fall back to source/Clipper output order rather than inventing a hole.
        orderedHoles.addAll(remaining);
        remaining.clear();
        break;
      }
      orderedHoles.add(remaining.removeAt(matchIndex));
    }
    orderedHoles.addAll(remaining);
    return [contour, ...orderedHoles];
  }

  static SourcePoint2 _centroidOrFirst(SourcePolygon2 polygon) {
    if (polygon.points.length < 3) return polygon.points.first;
    var areaTwice = 0.0;
    var cx = 0.0;
    var cy = 0.0;
    var previous = polygon.points.last;
    for (final point in polygon.points) {
      final cross = previous.x.toDouble() * point.y -
          previous.y.toDouble() * point.x;
      areaTwice += cross;
      cx += (previous.x.toDouble() + point.x) * cross;
      cy += (previous.y.toDouble() + point.y) * cross;
      previous = point;
    }
    if (areaTwice == 0) return polygon.points.first;
    return SourcePoint2(
      (cx / (3.0 * areaTwice)).round(),
      (cy / (3.0 * areaTwice)).round(),
    );
  }
}
