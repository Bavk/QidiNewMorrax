import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import '../geometry/thick_polyline.dart';
import 'classic_perimeter.dart';
import 'classic_perimeter_loop_tree.dart';
import 'classic_perimeter_traversal.dart';
import 'extrusion_entity.dart';
import 'flow.dart';

/// Bridges the already-ported classic shell geometry to the source loop tree
/// and no-overhang `traverse_loops()` representation.
class SourceClassicPerimeterPipeline2 {
  const SourceClassicPerimeterPipeline2._();

  static List<SourcePerimeterLoop2> buildLoopTree(
    ClassicPerimeterResult result,
  ) {
    if (result.loops.isEmpty || result.effectiveLoopCount <= 0) {
      return const [];
    }

    final loopNumber = result.effectiveLoopCount - 1;
    final contours = List<List<SourcePerimeterLoop2>>.generate(
      loopNumber + 1,
      (_) => <SourcePerimeterLoop2>[],
    );
    final holes = List<List<SourcePerimeterLoop2>>.generate(
      loopNumber + 1,
      (_) => <SourcePerimeterLoop2>[],
    );

    for (final loop in result.loops) {
      if (loop.depth < 0 || loop.depth > loopNumber) continue;
      final expolygon = loop.expolygon;
      contours[loop.depth].add(SourcePerimeterLoop2(
        polygon: _toSourcePolygon(expolygon.contour),
        depth: loop.depth,
        isContour: true,
        isSmallerWidthPerimeter: loop.usesSmallerExternalWidth,
      ));
      for (final hole in expolygon.holes) {
        holes[loop.depth].add(SourcePerimeterLoop2(
          polygon: _toSourcePolygon(hole),
          depth: loop.depth,
          isContour: false,
          isSmallerWidthPerimeter: loop.usesSmallerExternalWidth,
        ));
      }
    }

    return SourceClassicPerimeterLoopNester2.nest(
      contoursByDepth: contours,
      holesByDepth: holes,
      loopNumber: loopNumber,
    );
  }

  static List<ExtrusionEntity2> buildNoOverhangExtrusions({
    required ClassicPerimeterResult result,
    required Flow externalPerimeterFlow,
    required Flow smallerExternalPerimeterFlow,
    required Flow perimeterFlow,
    required double layerHeight,
  }) {
    final thinWalls = <ThickPolyline2>[
      for (final value in result.thinWalls)
        ThickPolyline2(
          points: value.points,
          width: value.width,
          startIsEndpoint: value.startIsEndpoint,
          endIsEndpoint: value.endIsEndpoint,
        ),
    ];

    return SourceClassicPerimeterTraversal2.traverseNoOverhang(
      loops: buildLoopTree(result),
      thinWalls: thinWalls,
      settings: SourceClassicPerimeterTraversalSettings2(
        externalPerimeterFlow: externalPerimeterFlow,
        smallerExternalPerimeterFlow: smallerExternalPerimeterFlow,
        perimeterFlow: perimeterFlow,
        layerHeight: layerHeight,
      ),
    );
  }

  static SourcePolygon2 _toSourcePolygon(dynamic polygon) => SourcePolygon2(
        polygon.points.map<SourcePoint2>(
          (point) => SourcePoint2(
            _recoverCoordinate(point.x as double),
            _recoverCoordinate(point.y as double),
          ),
        ),
      );

  static int _recoverCoordinate(double millimeters) =>
      (millimeters / Slic3rUnits.scalingFactor).round();
}
