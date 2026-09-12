import '../geometry/source_polygon.dart';
import '../geometry/thick_polyline.dart';
import 'classic_fuzzy_perimeter_traversal.dart';
import 'classic_perimeter.dart';
import 'classic_perimeter_source_pipeline.dart';
import 'classic_perimeter_traversal.dart';
import 'classic_wall_sequence.dart';
import 'extrusion_entity.dart';
import 'flow.dart';
import 'source_fuzzy_skin_apply.dart';
import 'source_fuzzy_skin_geometry.dart';

/// End-to-end represented `process_classic()` loop-output branch for a single
/// region config with no painted/per-region fuzzy segmentation.
class SourceClassicFuzzyPerimeterPipeline2 {
  const SourceClassicFuzzyPerimeterPipeline2._();

  static List<ExtrusionEntity2> buildNoRegion({
    required ClassicPerimeterResult result,
    required Flow externalPerimeterFlow,
    required Flow smallerExternalPerimeterFlow,
    required Flow perimeterFlow,
    required Flow overhangFlow,
    required double layerHeight,
    required int layerId,
    required SourceFuzzySkinNoRegionConfig2 fuzzyConfig,
    SourceFuzzyUnitRandom2? random,
    required bool detectOverhangWall,
    required bool configuredOverhangSpeedEnabled,
    List<SourcePolygon2>? lowerSlices,
    double wallNozzleDiameter = 0.4,
    int raftLayers = 0,
    SourceWallSequence2 wallSequence = SourceWallSequence2.innerOuter,
    bool brimOuterOnly = false,
    double brimWidth = 0,
  }) {
    final traversalSettings = SourceClassicPerimeterTraversalSettings2(
      externalPerimeterFlow: externalPerimeterFlow,
      smallerExternalPerimeterFlow: smallerExternalPerimeterFlow,
      perimeterFlow: perimeterFlow,
      layerHeight: layerHeight,
    );

    final overhangSettings = detectOverhangWall
        ? SourceClassicPerimeterOverhangSettings2.fromLowerSlices(
            overhangFlow: overhangFlow,
            externalPerimeterFlow: externalPerimeterFlow,
            smallerExternalPerimeterFlow: smallerExternalPerimeterFlow,
            perimeterFlow: perimeterFlow,
            lowerSlices: lowerSlices,
            wallNozzleDiameter: wallNozzleDiameter,
            layerId: layerId,
            raftLayers: raftLayers,
          )
        : null;

    final traversed = SourceClassicFuzzyPerimeterTraversal2.traverseNoRegion(
      loops: SourceClassicPerimeterPipeline2.buildLoopTree(result),
      thinWalls: _cloneThinWalls(result),
      settings: traversalSettings,
      fuzzyConfig: fuzzyConfig,
      random: random ?? sourceFuzzyProductionRandom2(),
      layerId: layerId,
      configuredOverhangSpeedEnabled: configuredOverhangSpeedEnabled,
      overhangSettings: overhangSettings,
    );

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
}
