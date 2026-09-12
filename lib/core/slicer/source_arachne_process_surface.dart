import '../geometry/source_arc_fitter.dart';
import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import 'source_arachne_extrusion_line.dart';
import 'source_arachne_process_planning.dart';
import 'source_arachne_top_one_wall.dart';
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
    this.perimeterWidth,
    this.topAreaThresholdPercent = 0,
    this.lowerSlices,
  });

  final SourceArachneProcessPlanningSettings2 planning;
  final double surfaceSimplifyResolutionSource;
  final int perimeterSpacing;
  final double layerHeightMm;

  /// Required only by the separated `Alltop` branch, where pinned
  /// `should_enable_top_one_wall()` compares top area against internal wall
  /// width rather than spacing.
  final int? perimeterWidth;
  final double topAreaThresholdPercent;
  final List<SourcePolygon2>? lowerSlices;
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
    this.remainingWallToolPaths,
    this.topOneWallEnabled = false,
    this.topOneWallPolygons = const <SourcePolygon2>[],
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
  final SourceArachneWallToolPathsGenerated2? remainingWallToolPaths;
  final bool topOneWallEnabled;
  final List<SourcePolygon2> topOneWallPolygons;
}

/// Source-order per-surface wall generation from pinned
/// `PerimeterGenerator::process_arachne()` through the complete one-wall,
/// normal-wall and separated `TopOneWallType::Alltop` branches.
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
      return _processSeparatedTop(
        surface: surface,
        settings: settings,
        plan: plan,
        last: last,
        wallInput: wallInput,
        applyCircleCompensation: applyCircleCompensation,
        circlePolygonIndices: circlePolygonIndices,
      );
    }

    return _processStandardWalls(
      plan: plan,
      last: last,
      wallInput: wallInput,
      settings: settings,
      applyCircleCompensation: applyCircleCompensation,
      circlePolygonIndices: circlePolygonIndices,
      insetCount: plan.initialInsetCount!,
    );
  }

  static SourceArachneSurfaceProcessResult2 _processSeparatedTop({
    required Surface2 surface,
    required SourceArachneSurfaceProcessSettings2 settings,
    required SourceArachneSurfaceWallPlan2 plan,
    required List<SourcePolygon2> last,
    required List<SourcePolygon2> wallInput,
    required bool applyCircleCompensation,
    required List<int> circlePolygonIndices,
  }) {
    final perimeterWidth = settings.perimeterWidth;
    if (perimeterWidth == null || perimeterWidth <= 0) {
      throw ArgumentError.value(
        perimeterWidth,
        'perimeterWidth',
        'must be provided and > 0 for pinned Alltop separated generation',
      );
    }

    final firstFacade = _makeWallPaths(
      outline: wallInput,
      beadWidth0: settings.planning.extPerimeterSpacing,
      beadWidthX: settings.perimeterSpacing,
      insetCount: 1,
      plan: plan,
      settings: settings,
      applyCircleCompensation: applyCircleCompensation,
      circlePolygonIndices: circlePolygonIndices,
    );
    final firstPerimeters = firstFacade.getToolPaths();
    final infillContourByOneWall = SourceArachneTopOneWall2.union(
      firstFacade.getInnerContour(),
    );

    if (infillContourByOneWall.isEmpty) {
      // The pinned source immediately calls get_extents() here; represent that
      // invalid state explicitly rather than fabricating a bounding box.
      throw StateError(
        'Pinned separated Alltop branch requires non-empty one-wall inner contour',
      );
    }

    final infillBounds = SourceArachneTopOneWall2.bounds(
      infillContourByOneWall,
    ).inflated(Slic3rUnits.scaledEpsilon);
    final upperClipped = SourceArachneTopOneWall2.clipWithSubjectBounds(
      settings.planning.upperSlices ?? const <SourcePolygon2>[],
      infillBounds,
    );
    var top = SourceArachneTopOneWall2.difference(
      infillContourByOneWall,
      upperClipped,
    );

    final lowerClipped = SourceArachneTopOneWall2.clipWithSubjectBounds(
      settings.lowerSlices ?? const <SourcePolygon2>[],
      infillBounds,
    );
    final bottom = SourceArachneTopOneWall2.difference(top, lowerClipped);
    top = SourceArachneTopOneWall2.difference(top, bottom);

    final decision = SourceArachneTopOneWall2.shouldEnable(
      originalPolygons: last,
      top: top,
      perimeterWidth: perimeterWidth,
      extPerimeterSpacing: settings.planning.extPerimeterSpacing,
      topAreaThresholdPercent: settings.topAreaThresholdPercent,
    );

    if (!decision.enabled) {
      // Source discards the probe first wall and falls through to the normal
      // `loop_number + 1` WallToolPaths branch.
      return _processStandardWalls(
        plan: plan,
        last: last,
        wallInput: wallInput,
        settings: settings,
        applyCircleCompensation: applyCircleCompensation,
        circlePolygonIndices: circlePolygonIndices,
        insetCount: plan.loopNumber + 1,
      );
    }

    final totalPerimeters = <List<SourceArachneExtrusionLine2>>[
      for (final inset in firstPerimeters)
        [for (final line in inset) line.copy()],
    ];
    var infillContour = SourceArachneTopOneWall2.union(
      infillContourByOneWall,
    );
    SourceArachneWallToolPathsGenerated2? remainingGenerated;

    if (plan.loopNumber > 0) {
      final remainingLast = SourceArachneTopOneWall2.difference(
        infillContourByOneWall,
        decision.top,
      );
      final remainingFacade = _makeWallPaths(
        outline: remainingLast,
        beadWidth0: settings.perimeterSpacing,
        beadWidthX: settings.perimeterSpacing,
        insetCount: plan.loopNumber,
        plan: plan,
        settings: settings,
        // Source explicitly disables contour compensation for remaining walls.
        applyCircleCompensation: false,
        circlePolygonIndices: const <int>[],
      );
      final remainingPerimeters = remainingFacade.getToolPaths();
      for (final inset in remainingPerimeters) {
        if (inset.isEmpty) continue;
        final shifted = <SourceArachneExtrusionLine2>[];
        for (final sourceLine in inset) {
          final line = sourceLine.copy();
          line.insetIndex += 1;
          shifted.add(line);
        }
        totalPerimeters.add(shifted);
      }

      final remainingInner = SourceArachneTopOneWall2.union(
        remainingFacade.getInnerContour(),
      );
      infillContour = SourceArachneTopOneWall2.intersection(
        SourceArachneTopOneWall2.union([
          ...remainingInner,
          ...decision.top,
        ]),
        infillContourByOneWall,
      );
      remainingGenerated = remainingFacade.latest;
    }

    return SourceArachneSurfaceProcessResult2(
      plan: plan,
      lastPolygons: List.unmodifiable(last),
      wallInputPolygons: List.unmodifiable(wallInput),
      applyCircleCompensation: applyCircleCompensation,
      circlePolygonIndices: List.unmodifiable(circlePolygonIndices),
      totalPerimeters: List.unmodifiable(totalPerimeters),
      infillContour: List.unmodifiable(infillContour),
      wallToolPaths: firstFacade.latest,
      remainingWallToolPaths: remainingGenerated,
      topOneWallEnabled: true,
      topOneWallPolygons: List.unmodifiable(decision.top),
    );
  }

  static SourceArachneSurfaceProcessResult2 _processStandardWalls({
    required SourceArachneSurfaceWallPlan2 plan,
    required List<SourcePolygon2> last,
    required List<SourcePolygon2> wallInput,
    required SourceArachneSurfaceProcessSettings2 settings,
    required bool applyCircleCompensation,
    required List<int> circlePolygonIndices,
    required int insetCount,
  }) {
    final facade = _makeWallPaths(
      outline: wallInput,
      beadWidth0: settings.planning.extPerimeterSpacing,
      beadWidthX: settings.perimeterSpacing,
      insetCount: insetCount,
      plan: plan,
      settings: settings,
      applyCircleCompensation: applyCircleCompensation,
      circlePolygonIndices: circlePolygonIndices,
    );

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

  static SourceArachneWallToolPathsFacade2 _makeWallPaths({
    required List<SourcePolygon2> outline,
    required int beadWidth0,
    required int beadWidthX,
    required int insetCount,
    required SourceArachneSurfaceWallPlan2 plan,
    required SourceArachneSurfaceProcessSettings2 settings,
    required bool applyCircleCompensation,
    required Iterable<int> circlePolygonIndices,
  }) {
    final facade = SourceArachneWallToolPathsFacade2(
      SourceArachneWallToolPathsState2(
        outline: outline,
        beadWidth0: beadWidth0,
        beadWidthX: beadWidthX,
        insetCount: insetCount,
        wall0Inset: plan.wall0Inset,
        layerHeightMm: settings.layerHeightMm,
        params: plan.params,
      ),
    );
    if (applyCircleCompensation) {
      facade.enableHoleCompensation(true, circlePolygonIndices);
    }
    return facade;
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
