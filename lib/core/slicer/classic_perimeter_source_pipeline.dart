import '../geometry/polygon.dart';
import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import '../geometry/thick_polyline.dart';
import 'classic_perimeter.dart';
import 'classic_perimeter_loop_tree.dart';
import 'classic_perimeter_traversal.dart';
import 'classic_wall_sequence.dart';
import 'extrusion_entity.dart';
import 'flow.dart';

/// Bridges the already-ported classic shell geometry to the source loop tree,
/// `traverse_loops()` representation and source wall-sequence adjustment.
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
    SourceWallSequence2 wallSequence = SourceWallSequence2.innerOuter,
    int layerId = 0,
    bool brimOuterOnly = false,
    double brimWidth = 0,
  }) {
    final traversalSettings = SourceClassicPerimeterTraversalSettings2(
      externalPerimeterFlow: externalPerimeterFlow,
      smallerExternalPerimeterFlow: smallerExternalPerimeterFlow,
      perimeterFlow: perimeterFlow,
      layerHeight: layerHeight,
    );
    final traversed = SourceClassicPerimeterTraversal2.traverseNoOverhang(
      loops: buildLoopTree(result),
      thinWalls: _cloneThinWalls(result),
      settings: traversalSettings,
    );
    return _applyWallSequence(
      traversed,
      wallSequence: wallSequence,
      layerId: layerId,
      brimOuterOnly: brimOuterOnly,
      brimWidth: brimWidth,
    );
  }

  /// End-to-end classic shell -> nesting -> overhang split -> recursive
  /// traversal -> wall-sequence pipeline for the source branch where overhang
  /// speed grading is disabled and prebuilt source lower-series are supplied.
  static List<ExtrusionEntity2> buildExtrusionsWithoutSpeedGrading({
    required ClassicPerimeterResult result,
    required Flow externalPerimeterFlow,
    required Flow smallerExternalPerimeterFlow,
    required Flow perimeterFlow,
    required double layerHeight,
    required SourceClassicPerimeterOverhangSettings2 overhangSettings,
    SourceWallSequence2 wallSequence = SourceWallSequence2.innerOuter,
    bool brimOuterOnly = false,
    double brimWidth = 0,
  }) {
    final traversalSettings = _traversalSettings(
      externalPerimeterFlow: externalPerimeterFlow,
      smallerExternalPerimeterFlow: smallerExternalPerimeterFlow,
      perimeterFlow: perimeterFlow,
      layerHeight: layerHeight,
    );
    final traversed =
        SourceClassicPerimeterTraversal2.traverseWithoutSpeedGrading(
      loops: buildLoopTree(result),
      thinWalls: _cloneThinWalls(result),
      settings: traversalSettings,
      overhangSettings: overhangSettings,
    );
    return _applyWallSequence(
      traversed,
      wallSequence: wallSequence,
      layerId: overhangSettings.layerId,
      brimOuterOnly: brimOuterOnly,
      brimWidth: brimWidth,
    );
  }

  /// Same source overhang path with the intermediate classic slowdown degrees
  /// enabled. [overhangSettings] must include the selected wall's source
  /// distance boundary; [SourceClassicPerimeterOverhangSettings2.fromLowerSlices]
  /// supplies all three automatically.
  static List<ExtrusionEntity2> buildExtrusionsWithSpeedGrading({
    required ClassicPerimeterResult result,
    required Flow externalPerimeterFlow,
    required Flow smallerExternalPerimeterFlow,
    required Flow perimeterFlow,
    required double layerHeight,
    required SourceClassicPerimeterOverhangSettings2 overhangSettings,
    SourceWallSequence2 wallSequence = SourceWallSequence2.innerOuter,
    bool brimOuterOnly = false,
    double brimWidth = 0,
  }) {
    final traversalSettings = _traversalSettings(
      externalPerimeterFlow: externalPerimeterFlow,
      smallerExternalPerimeterFlow: smallerExternalPerimeterFlow,
      perimeterFlow: perimeterFlow,
      layerHeight: layerHeight,
    );
    final traversed = SourceClassicPerimeterTraversal2.traverseWithSpeedGrading(
      loops: buildLoopTree(result),
      thinWalls: _cloneThinWalls(result),
      settings: traversalSettings,
      overhangSettings: overhangSettings,
    );
    return _applyWallSequence(
      traversed,
      wallSequence: wallSequence,
      layerId: overhangSettings.layerId,
      brimOuterOnly: brimOuterOnly,
      brimWidth: brimWidth,
    );
  }

  /// Constructs the three lower-polygon series and distance boundaries exactly
  /// where `PerimeterGenerator::process_classic()` does, then runs the no-speed
  /// overhang branch.
  static List<ExtrusionEntity2> buildExtrusionsFromLowerSlicesWithoutSpeedGrading({
    required ClassicPerimeterResult result,
    required Flow externalPerimeterFlow,
    required Flow smallerExternalPerimeterFlow,
    required Flow perimeterFlow,
    required Flow overhangFlow,
    required double layerHeight,
    required List<SourcePolygon2>? lowerSlices,
    required double wallNozzleDiameter,
    required int layerId,
    int raftLayers = 0,
    SourceWallSequence2 wallSequence = SourceWallSequence2.innerOuter,
    bool brimOuterOnly = false,
    double brimWidth = 0,
  }) {
    final overhangSettings = _overhangSettingsFromLowerSlices(
      overhangFlow: overhangFlow,
      externalPerimeterFlow: externalPerimeterFlow,
      smallerExternalPerimeterFlow: smallerExternalPerimeterFlow,
      perimeterFlow: perimeterFlow,
      lowerSlices: lowerSlices,
      wallNozzleDiameter: wallNozzleDiameter,
      layerId: layerId,
      raftLayers: raftLayers,
    );
    return buildExtrusionsWithoutSpeedGrading(
      result: result,
      externalPerimeterFlow: externalPerimeterFlow,
      smallerExternalPerimeterFlow: smallerExternalPerimeterFlow,
      perimeterFlow: perimeterFlow,
      layerHeight: layerHeight,
      overhangSettings: overhangSettings,
      wallSequence: wallSequence,
      brimOuterOnly: brimOuterOnly,
      brimWidth: brimWidth,
    );
  }

  /// Full represented classic overhang-speed branch from raw lower slices:
  /// source float lower-series generation, source distance boundaries,
  /// supported/zero/intermediate/unsupported splitting, degree terracing,
  /// recursive traversal, and final wall-sequence adjustment.
  static List<ExtrusionEntity2> buildExtrusionsFromLowerSlicesWithSpeedGrading({
    required ClassicPerimeterResult result,
    required Flow externalPerimeterFlow,
    required Flow smallerExternalPerimeterFlow,
    required Flow perimeterFlow,
    required Flow overhangFlow,
    required double layerHeight,
    required List<SourcePolygon2>? lowerSlices,
    required double wallNozzleDiameter,
    required int layerId,
    int raftLayers = 0,
    SourceWallSequence2 wallSequence = SourceWallSequence2.innerOuter,
    bool brimOuterOnly = false,
    double brimWidth = 0,
  }) {
    final overhangSettings = _overhangSettingsFromLowerSlices(
      overhangFlow: overhangFlow,
      externalPerimeterFlow: externalPerimeterFlow,
      smallerExternalPerimeterFlow: smallerExternalPerimeterFlow,
      perimeterFlow: perimeterFlow,
      lowerSlices: lowerSlices,
      wallNozzleDiameter: wallNozzleDiameter,
      layerId: layerId,
      raftLayers: raftLayers,
    );
    return buildExtrusionsWithSpeedGrading(
      result: result,
      externalPerimeterFlow: externalPerimeterFlow,
      smallerExternalPerimeterFlow: smallerExternalPerimeterFlow,
      perimeterFlow: perimeterFlow,
      layerHeight: layerHeight,
      overhangSettings: overhangSettings,
      wallSequence: wallSequence,
      brimOuterOnly: brimOuterOnly,
      brimWidth: brimWidth,
    );
  }

  static SourceClassicPerimeterTraversalSettings2 _traversalSettings({
    required Flow externalPerimeterFlow,
    required Flow smallerExternalPerimeterFlow,
    required Flow perimeterFlow,
    required double layerHeight,
  }) =>
      SourceClassicPerimeterTraversalSettings2(
        externalPerimeterFlow: externalPerimeterFlow,
        smallerExternalPerimeterFlow: smallerExternalPerimeterFlow,
        perimeterFlow: perimeterFlow,
        layerHeight: layerHeight,
      );

  static SourceClassicPerimeterOverhangSettings2 _overhangSettingsFromLowerSlices({
    required Flow overhangFlow,
    required Flow externalPerimeterFlow,
    required Flow smallerExternalPerimeterFlow,
    required Flow perimeterFlow,
    required List<SourcePolygon2>? lowerSlices,
    required double wallNozzleDiameter,
    required int layerId,
    required int raftLayers,
  }) =>
      SourceClassicPerimeterOverhangSettings2.fromLowerSlices(
        overhangFlow: overhangFlow,
        externalPerimeterFlow: externalPerimeterFlow,
        smallerExternalPerimeterFlow: smallerExternalPerimeterFlow,
        perimeterFlow: perimeterFlow,
        lowerSlices: lowerSlices,
        wallNozzleDiameter: wallNozzleDiameter,
        layerId: layerId,
        raftLayers: raftLayers,
      );

  static List<ThickPolyline2> _cloneThinWalls(ClassicPerimeterResult result) =>
      <ThickPolyline2>[
        for (final value in result.thinWalls)
          ThickPolyline2(
            points: value.points,
            width: value.width,
            startIsEndpoint: value.startIsEndpoint,
            endIsEndpoint: value.endIsEndpoint,
          ),
      ];

  static List<ExtrusionEntity2> _applyWallSequence(
    List<ExtrusionEntity2> traversed, {
    required SourceWallSequence2 wallSequence,
    required int layerId,
    required bool brimOuterOnly,
    required double brimWidth,
  }) {
    // Keep the same owned entity instances produced by traversal. Constructing
    // ExtrusionEntityCollection2 from [traversed] would clone them, while the
    // C++ classic path reorders the existing pointer collection in place.
    final collection = ExtrusionEntityCollection2();
    collection.entities.addAll(traversed);
    SourceClassicWallSequence2.adjust(
      collection,
      wallSequence: wallSequence,
      layerId: layerId,
      brimOuterOnly: brimOuterOnly,
      brimWidth: brimWidth,
    );
    return List.unmodifiable(collection.entities);
  }

  static SourcePolygon2 _toSourcePolygon(Polygon2 polygon) => SourcePolygon2(
        polygon.points.map(
          (point) => SourcePoint2(
            _recoverCoordinate(point.x),
            _recoverCoordinate(point.y),
          ),
        ),
      );

  static int _recoverCoordinate(double millimeters) =>
      (millimeters / Slic3rUnits.scalingFactor).round();
}
