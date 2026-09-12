import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import '../geometry/source_polyline.dart';
import '../geometry/thick_polyline.dart';
import 'classic_overhang_splitter.dart';
import 'classic_perimeter_loop_tree.dart';
import 'extrusion_entity.dart';
import 'flow.dart';
import 'source_shortest_path.dart';
import 'variable_width.dart';

class SourceClassicPerimeterTraversalSettings2 {
  const SourceClassicPerimeterTraversalSettings2({
    required this.externalPerimeterFlow,
    required this.smallerExternalPerimeterFlow,
    required this.perimeterFlow,
    required this.layerHeight,
  });

  final Flow externalPerimeterFlow;
  final Flow smallerExternalPerimeterFlow;
  final Flow perimeterFlow;
  final double layerHeight;
}

/// Additional source state needed by the classic `detect_overhang_wall` branch
/// when overhang-speed grading is disabled.
///
/// Each lower-polygon series is already generated for the matching wall width,
/// exactly like `PerimeterGenerator::generate_lower_polygons_series()`. This
/// class deliberately does not claim the separate fuzzy-skin or degree-grading
/// branches.
class SourceClassicPerimeterOverhangSettings2 {
  const SourceClassicPerimeterOverhangSettings2({
    required this.overhangFlow,
    required this.externalLowerPolygonsSeries,
    required this.smallerExternalLowerPolygonsSeries,
    required this.perimeterLowerPolygonsSeries,
    required this.layerId,
    this.raftLayers = 0,
  });

  final Flow overhangFlow;
  final List<List<SourcePolygon2>> externalLowerPolygonsSeries;
  final List<List<SourcePolygon2>> smallerExternalLowerPolygonsSeries;
  final List<List<SourcePolygon2>> perimeterLowerPolygonsSeries;
  final int layerId;
  final int raftLayers;
}

/// Source classic `traverse_loops()` representation.
///
/// [traverseNoOverhang] preserves the already-verified branch where overhang
/// detection is not active. [traverseWithoutSpeedGrading] additionally ports
/// the exact `detect_overhang_wall` split for configurations where QIDI's
/// overhang-speed grading is disabled. Fuzzy-skin and degree grading remain
/// outside this class's parity scope.
class SourceClassicPerimeterTraversal2 {
  const SourceClassicPerimeterTraversal2._();

  static List<ExtrusionEntity2> traverseNoOverhang({
    required List<SourcePerimeterLoop2> loops,
    required List<ThickPolyline2> thinWalls,
    required SourceClassicPerimeterTraversalSettings2 settings,
  }) =>
      _traverse(
        loops: loops,
        thinWalls: thinWalls,
        settings: settings,
      );

  static List<ExtrusionEntity2> traverseWithoutSpeedGrading({
    required List<SourcePerimeterLoop2> loops,
    required List<ThickPolyline2> thinWalls,
    required SourceClassicPerimeterTraversalSettings2 settings,
    required SourceClassicPerimeterOverhangSettings2 overhangSettings,
  }) =>
      _traverse(
        loops: loops,
        thinWalls: thinWalls,
        settings: settings,
        overhangSettings: overhangSettings,
      );

  static List<ExtrusionEntity2> _traverse({
    required List<SourcePerimeterLoop2> loops,
    required List<ThickPolyline2> thinWalls,
    required SourceClassicPerimeterTraversalSettings2 settings,
    SourceClassicPerimeterOverhangSettings2? overhangSettings,
  }) {
    final coll = <ExtrusionEntity2>[];
    final structuralLoops = <SourcePerimeterLoop2>[];

    for (final loop in loops) {
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

      final polygonPoints = loop.polygon.points;
      if (polygonPoints.length < 3) {
        throw StateError('PerimeterGeneratorLoop polygon must have >= 3 points');
      }

      final paths = _pathsForLoop(
        loop: loop,
        role: role,
        flow: flow,
        flag: flag,
        settings: settings,
        overhangSettings: overhangSettings,
      );
      if (paths.isEmpty) {
        // Literal source branch: `if (paths.empty()) continue;`.
        continue;
      }

      coll.add(ExtrusionLoop2(
        paths: paths,
        loopRole: loopRole,
        customizeFlag: flag,
      ));
      structuralLoops.add(loop);
    }

    // Source initializes an undefined BoundingBox with min=max=(0,0), merges
    // all structural loop polylines, then for every thin wall overwrites
    // zero_point with whichever bbox corner (min/max) is farther from that
    // wall's first point. Therefore the last thin wall determines zero_point.
    var zeroPoint = const SourcePoint2(0, 0);
    if (thinWalls.isNotEmpty) {
      final bounds = _SourceBounds2();
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
    required SourcePerimeterLoop2 loop,
    required ExtrusionRole role,
    required Flow flow,
    required CustomizeFlag flag,
    required SourceClassicPerimeterTraversalSettings2 settings,
    required SourceClassicPerimeterOverhangSettings2? overhangSettings,
  }) {
    if (overhangSettings != null &&
        overhangSettings.layerId > overhangSettings.raftLayers) {
      final lowerSeries = loop.isExternal
          ? (loop.isSmallerWidthPerimeter
              ? overhangSettings.smallerExternalLowerPolygonsSeries
              : overhangSettings.externalLowerPolygonsSeries)
          : overhangSettings.perimeterLowerPolygonsSeries;
      final paths = const SourceClassicOverhangSplitter2()
          .splitWithoutSpeedGrading(
        polygon: loop.polygon,
        lowerPolygonsSeries: lowerSeries,
        supportedRole: role,
        supportedFlow: flow,
        overhangFlow: overhangSettings.overhangFlow,
        layerHeight: settings.layerHeight,
      );
      for (final path in paths) {
        path.customizeFlag = flag;
      }
      return paths;
    }

    final polygonPoints = loop.polygon.points;
    return [
      ExtrusionPath2(
        polyline: SourcePolyline2([
          ...polygonPoints,
          polygonPoints.first,
        ]),
        overhangDegree: 0,
        curveDegree: 0,
        mm3PerMm: flow.mm3PerMm,
        width: flow.width,
        height: settings.layerHeight,
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

class _SourceBounds2 {
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
