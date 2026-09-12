import '../geometry/source_geometry.dart';
import '../geometry/source_polyline.dart';
import '../geometry/thick_polyline.dart';
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

/// Source `traverse_loops()` subset before fuzzy-skin / overhang splitting.
///
/// This class intentionally models only the exact no-overhang branch. It still
/// preserves source loop roles, flow selection, thin-wall insertion into the
/// same nearest-neighbor chain, recursive contour/hole ordering and winding.
class SourceClassicPerimeterTraversal2 {
  const SourceClassicPerimeterTraversal2._();

  static List<ExtrusionEntity2> traverseNoOverhang({
    required List<SourcePerimeterLoop2> loops,
    required List<ThickPolyline2> thinWalls,
    required SourceClassicPerimeterTraversalSettings2 settings,
  }) {
    final coll = <ExtrusionEntity2>[];

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
      final path = ExtrusionPath2(
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
      );
      coll.add(ExtrusionLoop2(
        paths: [path],
        loopRole: loopRole,
        customizeFlag: flag,
      ));
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

    final chain = SourceShortestPath2.chainExtrusionEntities(
      coll,
      startNear: zeroPoint,
    );
    final output = <ExtrusionEntity2>[];

    for (final entry in chain) {
      final entity = coll[entry.index];
      if (entry.index >= loops.length) {
        if (entry.reversed) entity.reverse();
        output.add(entity);
        continue;
      }

      final loop = loops[entry.index];
      final children = traverseNoOverhang(
        loops: loop.children,
        thinWalls: thinWalls,
        settings: settings,
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
