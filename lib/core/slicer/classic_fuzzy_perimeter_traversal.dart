import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import '../geometry/source_polyline.dart';
import '../geometry/thick_polyline.dart';
import 'classic_overhang_splitter.dart';
import 'classic_overhang_support.dart';
import 'classic_perimeter_loop_tree.dart';
import 'classic_perimeter_traversal.dart';
import 'extrusion_entity.dart';
import 'source_fuzzy_skin_apply.dart';
import 'source_fuzzy_skin_geometry.dart';
import 'source_fuzzy_skin_policy.dart';
import 'source_shortest_path.dart';
import 'variable_width.dart';

/// Classic `traverse_loops()` branch with no painted/per-region fuzzy segments.
///
/// This class exists separately from the already-verified non-fuzzy traversal
/// so source random-stream consumption stays in the correct recursion order:
/// each call fuzzifies its sibling loops, chains them, and only then fuzzifies
/// children when recursion reaches the chosen parent. Pre-fuzzifying the whole
/// tree would change the single thread-local source random stream.
class SourceClassicFuzzyPerimeterTraversal2 {
  const SourceClassicFuzzyPerimeterTraversal2._();

  static List<ExtrusionEntity2> traverseNoRegion({
    required List<SourcePerimeterLoop2> loops,
    required List<ThickPolyline2> thinWalls,
    required SourceClassicPerimeterTraversalSettings2 settings,
    required SourceFuzzySkinNoRegionConfig2 fuzzyConfig,
    required SourceFuzzyUnitRandom2 random,
    required int layerId,
    required bool configuredOverhangSpeedEnabled,
    SourceClassicPerimeterOverhangSettings2? overhangSettings,
  }) {
    final speedGrading = SourceFuzzySkinPolicy2.enablesOverhangSpeed(
      configuredOverhangSpeedEnabled: configuredOverhangSpeedEnabled,
      type: fuzzyConfig.type,
      perimeterRegionsEmpty: true,
    );
    return _traverse(
      loops: loops,
      thinWalls: thinWalls,
      settings: settings,
      fuzzyConfig: fuzzyConfig,
      random: random,
      layerId: layerId,
      speedGrading: speedGrading,
      overhangSettings: overhangSettings,
    );
  }

  static List<ExtrusionEntity2> _traverse({
    required List<SourcePerimeterLoop2> loops,
    required List<ThickPolyline2> thinWalls,
    required SourceClassicPerimeterTraversalSettings2 settings,
    required SourceFuzzySkinNoRegionConfig2 fuzzyConfig,
    required SourceFuzzyUnitRandom2 random,
    required int layerId,
    required bool speedGrading,
    required SourceClassicPerimeterOverhangSettings2? overhangSettings,
  }) {
    final coll = <ExtrusionEntity2>[];
    final structuralLoops = <SourcePerimeterLoop2>[];

    for (final loop in loops) {
      final polygon = SourceFuzzySkinNoRegionApply2.applyPolygon(
        polygon: loop.polygon,
        config: fuzzyConfig,
        layerIndex: layerId,
        perimeterIndex: loop.depth,
        isContour: loop.isContour,
        random: random,
      );
      final isExternal = loop.isExternal;
      final role = isExternal
          ? ExtrusionRole.externalPerimeter
          : ExtrusionRole.perimeter;
      var loopRole = loop.isInternalContour
          ? ExtrusionLoopRoles.contourInternalPerimeter
          : (loop.isContour
              ? ExtrusionLoopRoles.defaultRole
              : ExtrusionLoopRoles.perimeterHole);
      if (loop.depth == 1) {
        loopRole = loopRole == ExtrusionLoopRoles.defaultRole
            ? ExtrusionLoopRoles.secondPerimeter
            : loopRole | ExtrusionLoopRoles.secondPerimeter;
      }

      final flow = isExternal
          ? (loop.isSmallerWidthPerimeter
              ? settings.smallerExternalPerimeterFlow
              : settings.externalPerimeterFlow)
          : settings.perimeterFlow;
      final flag = loop.needCircleCompensation
          ? CustomizeFlag.circleCompensation
          : CustomizeFlag.none;

      final paths = _pathsForLoop(
        polygon: polygon,
        loop: loop,
        role: role,
        flowMm3PerMm: flow.mm3PerMm,
        flowWidth: flow.width,
        flowHeight: settings.layerHeight,
        flag: flag,
        settings: settings,
        overhangSettings: overhangSettings,
        speedGrading: speedGrading,
      );
      if (paths.isEmpty) continue;

      coll.add(ExtrusionLoop2(
        paths: paths,
        loopRole: loopRole,
        customizeFlag: flag,
      ));
      structuralLoops.add(loop);
    }

    var zeroPoint = const SourcePoint2(0, 0);
    if (thinWalls.isNotEmpty) {
      final bounds = _FuzzySourceBounds2();
      for (final entity in coll) {
        bounds.merge(entity.asPolyline().points);
      }
      for (final thinWall in thinWalls) {
        var farCorner = bounds.min;
        if (_squaredDistance(farCorner, thinWall.firstPoint) <
            _squaredDistance(bounds.max, thinWall.firstPoint)) {
          farCorner = bounds.max;
        }
        zeroPoint = farCorner;
      }

      const SourceVariableWidth2().variableWidth(
        thinWalls,
        ExtrusionRole.externalPerimeter,
        settings.externalPerimeterFlow,
        coll,
      );
      thinWalls.clear();
    }

    final structuralCount = structuralLoops.length;
    final chain = SourceShortestPath2.chainExtrusionEntities(
      coll,
      startNear: zeroPoint,
    );
    final output = <ExtrusionEntity2>[];

    for (final entry in chain) {
      final entity = coll[entry.index];
      if (entry.index >= structuralCount) {
        if (entry.reversed) entity.reverse();
        output.add(entity);
        continue;
      }

      final loop = structuralLoops[entry.index];
      final children = _traverse(
        loops: loop.children,
        thinWalls: thinWalls,
        settings: settings,
        fuzzyConfig: fuzzyConfig,
        random: random,
        layerId: layerId,
        speedGrading: speedGrading,
        overhangSettings: overhangSettings,
      );
      final extrusionLoop = entity as ExtrusionLoop2;
      if (loop.isContour) {
        extrusionLoop.makeCounterClockwise();
        output
          ..addAll(children)
          ..add(extrusionLoop);
      } else {
        extrusionLoop.makeClockwise();
        output
          ..add(extrusionLoop)
          ..addAll(children);
      }
    }
    return output;
  }

  static List<ExtrusionPath2> _pathsForLoop({
    required SourcePolygon2 polygon,
    required SourcePerimeterLoop2 loop,
    required ExtrusionRole role,
    required double flowMm3PerMm,
    required double flowWidth,
    required double flowHeight,
    required CustomizeFlag flag,
    required SourceClassicPerimeterTraversalSettings2 settings,
    required SourceClassicPerimeterOverhangSettings2? overhangSettings,
    required bool speedGrading,
  }) {
    if (polygon.points.length < 3) {
      throw StateError('fuzzy perimeter polygon must have >= 3 points');
    }

    if (overhangSettings != null &&
        overhangSettings.layerId > overhangSettings.raftLayers) {
      late final List<List<SourcePolygon2>> lowerSeries;
      late final SourceOverhangDistanceBoundary2? boundary;
      if (loop.isExternal) {
        if (loop.isSmallerWidthPerimeter) {
          lowerSeries = overhangSettings.smallerExternalLowerPolygonsSeries;
          boundary = overhangSettings.smallerExternalOverhangDistBoundary;
        } else {
          lowerSeries = overhangSettings.externalLowerPolygonsSeries;
          boundary = overhangSettings.externalOverhangDistBoundary;
        }
      } else {
        lowerSeries = overhangSettings.perimeterLowerPolygonsSeries;
        boundary = overhangSettings.perimeterOverhangDistBoundary;
      }

      final supportedFlow = loop.isExternal
          ? (loop.isSmallerWidthPerimeter
              ? settings.smallerExternalPerimeterFlow
              : settings.externalPerimeterFlow)
          : settings.perimeterFlow;
      final splitter = const SourceClassicOverhangSplitter2();
      final paths = speedGrading
          ? splitter.splitWithSpeedGrading(
              polygon: polygon,
              lowerPolygonsSeries: lowerSeries,
              overhangDistBoundary: boundary ??
                  (throw StateError(
                    'source fuzzy speed grading requires selected boundary',
                  )),
              supportedRole: role,
              supportedFlow: supportedFlow,
              overhangFlow: overhangSettings.overhangFlow,
              layerHeight: flowHeight,
            )
          : splitter.splitWithoutSpeedGrading(
              polygon: polygon,
              lowerPolygonsSeries: lowerSeries,
              supportedRole: role,
              supportedFlow: supportedFlow,
              overhangFlow: overhangSettings.overhangFlow,
              layerHeight: flowHeight,
            );
      for (final path in paths) {
        path.customizeFlag = flag;
      }
      return paths;
    }

    return [
      ExtrusionPath2(
        polyline: SourcePolyline2([
          ...polygon.points,
          polygon.points.first,
        ]),
        overhangDegree: 0,
        curveDegree: 0,
        mm3PerMm: flowMm3PerMm,
        width: flowWidth,
        height: flowHeight,
        role: role,
        customizeFlag: flag,
      ),
    ];
  }

  static double _squaredDistance(SourcePoint2 a, SourcePoint2 b) {
    final dx = a.x.toDouble() - b.x.toDouble();
    final dy = a.y.toDouble() - b.y.toDouble();
    return dx * dx + dy * dy;
  }
}

class _FuzzySourceBounds2 {
  SourcePoint2 min = const SourcePoint2(0, 0);
  SourcePoint2 max = const SourcePoint2(0, 0);
  bool _defined = false;

  void merge(Iterable<SourcePoint2> points) {
    for (final point in points) {
      if (!_defined) {
        min = point;
        max = point;
        _defined = true;
      } else {
        min = SourcePoint2(
          point.x < min.x ? point.x : min.x,
          point.y < min.y ? point.y : min.y,
        );
        max = SourcePoint2(
          point.x > max.x ? point.x : max.x,
          point.y > max.y ? point.y : max.y,
        );
      }
    }
  }
}
