import '../geometry/expolygon.dart';
import '../geometry/polygon.dart';
import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import 'classic_fuzzy_perimeter_pipeline.dart';
import 'classic_perimeter.dart';
import 'classic_perimeter_island_process.dart';
import 'classic_top_one_wall_context.dart';
import 'classic_wall_sequence.dart';
import 'extrusion_entity.dart';
import 'flow.dart';
import 'source_fuzzy_skin_apply.dart';
import 'source_fuzzy_skin_geometry.dart';
import 'source_loop_node.dart';
import 'surface.dart';

class SourceClassicPerimeterOrderedPipelineSettings2 {
  const SourceClassicPerimeterOrderedPipelineSettings2({
    required this.islandProcess,
    required this.externalPerimeterFlow,
    required this.smallerExternalPerimeterFlow,
    required this.perimeterFlow,
    required this.overhangFlow,
    required this.layerHeight,
    required this.sliceZMm,
    required this.fuzzyConfig,
    required this.detectOverhangWall,
    required this.configuredOverhangSpeedEnabled,
    this.wallNozzleDiameter = 0.4,
    this.raftLayers = 0,
    this.wallSequence = SourceWallSequence2.innerOuter,
    this.brimOuterOnly = false,
    this.brimWidth = 0,
    this.zDirectionOutwallSpeedContinuous = false,
  });

  final SourceClassicPerimeterIslandProcessSettings2 islandProcess;
  final Flow externalPerimeterFlow;
  final Flow smallerExternalPerimeterFlow;
  final Flow perimeterFlow;
  final Flow overhangFlow;
  final double layerHeight;
  final double sliceZMm;
  final SourceFuzzySkinNoRegionConfig2 fuzzyConfig;
  final bool detectOverhangWall;
  final bool configuredOverhangSpeedEnabled;
  final double wallNozzleDiameter;
  final int raftLayers;
  final SourceWallSequence2 wallSequence;
  final bool brimOuterOnly;
  final double brimWidth;
  final bool zDirectionOutwallSpeedContinuous;
}

class SourceClassicExtrudedIsland2 {
  const SourceClassicExtrudedIsland2({
    required this.processed,
    required this.collection,
    required this.outwallPaths,
  });

  final SourceClassicProcessedIsland2 processed;

  /// Source per-island collection after `traverse_loops()` and wall-sequence
  /// adjustment. This is what the C++ source appends as one child of `loops`.
  final ExtrusionEntityCollection2 collection;
  final List<SourceNodeContour2> outwallPaths;
}

class SourceClassicPerimeterOrderedPipelineResult2 {
  const SourceClassicPerimeterOrderedPipelineResult2({
    required this.islandProcess,
    required this.islands,
    required this.loops,
    required this.gapFill,
    required this.loopNodes,
  });

  final SourceClassicPerimeterIslandProcessResult2 islandProcess;
  final List<SourceClassicExtrudedIsland2> islands;

  /// Source region `loops`: one nested collection per non-empty prepared island,
  /// preserved in `chain_expolygons()` order rather than globally flattened.
  final ExtrusionEntityCollection2 loops;

  /// Source global gap-fill collection, accumulated in island order.
  final ExtrusionEntityCollection2 gapFill;

  /// Snapshot of the shared QIDI loop-node vector after this batch. If a list
  /// was supplied to [SourceClassicPerimeterOrderedPipeline2.generate], that
  /// list is mutated in place before this snapshot is created.
  final List<SourceLoopNode2> loopNodes;
}

/// Composes the already verified classic preprocessing/fill path with the
/// existing classic fuzzy/overhang traversal at the source per-island boundary.
///
/// Pinned `process_classic()` calls `traverse_loops()` inside the
/// `chain_expolygons()` island loop, adjusts wall sequence, assigns QIDI
/// `loop_node_range`, and only then appends that entire island collection to
/// `loops`. This wrapper preserves that collection boundary and one shared
/// fuzzy RNG stream across all islands.
class SourceClassicPerimeterOrderedPipeline2 {
  const SourceClassicPerimeterOrderedPipeline2({
    this.islandProcess = const SourceClassicPerimeterIslandProcess2(),
  });

  final SourceClassicPerimeterIslandProcess2 islandProcess;

  SourceClassicPerimeterOrderedPipelineResult2 generate({
    required List<Surface2> surfaces,
    required SourceClassicPerimeterOrderedPipelineSettings2 settings,
    required int layerIndex,
    List<ExPolygon2>? lowerSlices,
    SourceClassicTopOneWallContext2? topOneWall,
    List<SourceFuzzySkinPerimeterRegion2> perimeterRegions = const [],
    SourceFuzzyUnitRandom2? random,
    List<SourceLoopNode2>? loopNodes,
  }) {
    _validate(settings, layerIndex);

    final processed = islandProcess.generate(
      surfaces: surfaces,
      settings: settings.islandProcess,
      layerIndex: layerIndex,
      lowerSlices: lowerSlices,
      topOneWall: topOneWall,
    );

    final sourceLowerSlices = _toSourcePolygons(lowerSlices);
    final sharedRandom = random ?? sourceFuzzyProductionRandom2();
    final nodes = loopNodes ?? <SourceLoopNode2>[];
    final outputLoops = ExtrusionEntityCollection2();
    final gapFill = ExtrusionEntityCollection2();
    final extrudedIslands = <SourceClassicExtrudedIsland2>[];

    for (final island in processed.islands) {
      final traversalResult = _sourceTraversalOrder(island.process.perimeter);
      final entities = SourceClassicFuzzyPerimeterPipeline2.build(
        result: traversalResult,
        externalPerimeterFlow: settings.externalPerimeterFlow,
        smallerExternalPerimeterFlow: settings.smallerExternalPerimeterFlow,
        perimeterFlow: settings.perimeterFlow,
        overhangFlow: settings.overhangFlow,
        layerHeight: settings.layerHeight,
        layerId: layerIndex,
        sliceZMm: settings.sliceZMm,
        fuzzyConfig: settings.fuzzyConfig,
        perimeterRegions: perimeterRegions,
        random: sharedRandom,
        detectOverhangWall: settings.detectOverhangWall,
        configuredOverhangSpeedEnabled:
            settings.configuredOverhangSpeedEnabled,
        lowerSlices: sourceLowerSlices,
        wallNozzleDiameter: settings.wallNozzleDiameter,
        raftLayers: settings.raftLayers,
        wallSequence: settings.wallSequence,
        brimOuterOnly: settings.brimOuterOnly,
        brimWidth: settings.brimWidth,
      );

      // Do not use the collection constructor here: it clones children. The
      // source wall-sequence step mutates the just-created entities in place.
      final collection = ExtrusionEntityCollection2();
      collection.entities.addAll(entities);

      final outwallPaths = settings.zDirectionOutwallSpeedContinuous
          ? _outwallPaths(
              traversalResult,
              externalPerimeterFlow: settings.externalPerimeterFlow,
              smallerExternalPerimeterFlow:
                  settings.smallerExternalPerimeterFlow,
            )
          : const <SourceNodeContour2>[];

      if (outwallPaths.isNotEmpty && layerIndex > 0) {
        _appendLoopNodes(
          collection: collection,
          outwallPaths: outwallPaths,
          loopNodes: nodes,
        );
      }

      extrudedIslands.add(
        SourceClassicExtrudedIsland2(
          processed: island,
          collection: collection,
          outwallPaths: List.unmodifiable(outwallPaths),
        ),
      );

      // Source `loops->append(entities)` keeps the island as a collection.
      if (!collection.isEmpty) outputLoops.append(collection);

      // Source gap-fill output is global rather than nested by island.
      for (final entity in island.process.perimeter.gapFillExtrusions) {
        gapFill.append(entity);
      }
    }

    return SourceClassicPerimeterOrderedPipelineResult2(
      islandProcess: processed,
      islands: List.unmodifiable(extrudedIslands),
      loops: outputLoops,
      gapFill: gapFill,
      loopNodes: List.unmodifiable(nodes),
    );
  }

  void _appendLoopNodes({
    required ExtrusionEntityCollection2 collection,
    required List<SourceNodeContour2> outwallPaths,
    required List<SourceLoopNode2> loopNodes,
  }) {
    final start = loopNodes.length;

    if (outwallPaths.length == 1) {
      loopNodes.add(_loopNode(
        outwallPaths.first,
        nodeId: loopNodes.length,
        loopId: 0,
      ));
    } else {
      final matched = List<bool>.filled(outwallPaths.length, false);
      for (var entityIndex = 0;
          entityIndex < collection.entities.length;
          entityIndex++) {
        final entity = collection.entities[entityIndex];
        // Literal source check: only exact `erPerimeter` is skipped.
        if (entity.role == ExtrusionRole.perimeter) continue;

        for (var linesIndex = 0;
            linesIndex < outwallPaths.length;
            linesIndex++) {
          if (matched[linesIndex]) continue;
          final outwall = outwallPaths[linesIndex];
          if (!SourceLoopNodeGeometry2.pointIsInLines(
            entity.firstPoint,
            outwall.points,
          )) {
            continue;
          }
          matched[linesIndex] = true;
          loopNodes.add(_loopNode(
            outwall,
            nodeId: loopNodes.length,
            loopId: entityIndex,
          ));
          break;
        }
      }
    }

    collection.loopNodeRange = (start, loopNodes.length);
  }

  SourceLoopNode2 _loopNode(
    SourceNodeContour2 contour, {
    required int nodeId,
    required int loopId,
  }) =>
      SourceLoopNode2(
        nodeContour: contour,
        nodeId: nodeId,
        loopId: loopId,
        bounds: SourceLoopNodeBounds2.fromPoints(contour.points),
      );

  List<SourceNodeContour2> _outwallPaths(
    ClassicPerimeterResult result, {
    required Flow externalPerimeterFlow,
    required Flow smallerExternalPerimeterFlow,
  }) {
    final output = <SourceNodeContour2>[];

    // Pinned i==0 block stores thin walls first.
    for (final thinWall in result.thinWalls) {
      output.add(SourceNodeContour2(
        points: thinWall.points,
        widths: [for (final width in thinWall.width) width.truncate()],
        isLoop: false,
      ));
    }

    // Source stores smaller-width outer loops before normal outer loops.
    for (final loop in result.loops.where(
      (loop) => loop.depth == 0 && loop.usesSmallerExternalWidth,
    )) {
      _appendClosedExPolygon(
        output,
        loop.expolygon,
        width: smallerExternalPerimeterFlow.scaledWidth,
      );
    }
    for (final loop in result.loops.where(
      (loop) => loop.depth == 0 && !loop.usesSmallerExternalWidth,
    )) {
      _appendClosedExPolygon(
        output,
        loop.expolygon,
        width: externalPerimeterFlow.scaledWidth,
      );
    }
    return output;
  }

  void _appendClosedExPolygon(
    List<SourceNodeContour2> output,
    ExPolygon2 expolygon, {
    required int width,
  }) {
    final polygons = <Polygon2>[expolygon.contour, ...expolygon.holes];
    for (final polygon in polygons) {
      if (polygon.points.isEmpty) continue;
      final points = [
        for (final point in polygon.points)
          SourcePoint2(
            _recoverCoordinate(point.x),
            _recoverCoordinate(point.y),
          ),
      ];
      points.add(points.first);
      output.add(SourceNodeContour2(
        points: points,
        widths: [width],
        isLoop: true,
      ));
    }
  }

  /// The shell helper historically emitted normal depth-zero offsets before
  /// smaller-width offsets. Pinned `process_classic()` inserts the smaller
  /// bucket first before nesting/traversal. Normalize that one ordering seam at
  /// this high-level source boundary without changing lower-level evidence.
  ClassicPerimeterResult _sourceTraversalOrder(ClassicPerimeterResult source) {
    final smaller = <ClassicPerimeterLoop>[];
    final normal = <ClassicPerimeterLoop>[];
    final deeper = <ClassicPerimeterLoop>[];
    for (final loop in source.loops) {
      if (loop.depth != 0) {
        deeper.add(loop);
      } else if (loop.usesSmallerExternalWidth) {
        smaller.add(loop);
      } else {
        normal.add(loop);
      }
    }
    final ordered = <ClassicPerimeterLoop>[...smaller, ...normal, ...deeper];
    return ClassicPerimeterResult(
      loops: List.unmodifiable(ordered),
      innerRegion: source.innerRegion,
      thinWalls: source.thinWalls,
      thinWallExtrusions: source.thinWallExtrusions,
      gapFillPolylines: source.gapFillPolylines,
      gapFillExtrusions: source.gapFillExtrusions,
      effectiveLoopCount: source.effectiveLoopCount,
      topFills: source.topFills,
      fillClip: source.fillClip,
      topFillApplied: source.topFillApplied,
    );
  }

  List<SourcePolygon2>? _toSourcePolygons(List<ExPolygon2>? expolygons) {
    if (expolygons == null) return null;
    final output = <SourcePolygon2>[];
    for (final expolygon in expolygons) {
      output.add(_toSourcePolygon(expolygon.contour));
      for (final hole in expolygon.holes) {
        output.add(_toSourcePolygon(hole));
      }
    }
    return List.unmodifiable(output);
  }

  SourcePolygon2 _toSourcePolygon(Polygon2 polygon) => SourcePolygon2([
        for (final point in polygon.points)
          SourcePoint2(
            _recoverCoordinate(point.x),
            _recoverCoordinate(point.y),
          ),
      ]);

  int _recoverCoordinate(double millimeters) =>
      (millimeters / Slic3rUnits.scalingFactor).round();

  void _validate(
    SourceClassicPerimeterOrderedPipelineSettings2 settings,
    int layerIndex,
  ) {
    if (layerIndex < 0) {
      throw ArgumentError.value(layerIndex, 'layerIndex', 'must be >= 0');
    }
    if (!settings.layerHeight.isFinite || settings.layerHeight <= 0) {
      throw ArgumentError.value(
        settings.layerHeight,
        'layerHeight',
        'must be finite and > 0',
      );
    }
    if (!settings.sliceZMm.isFinite || settings.sliceZMm < 0) {
      throw ArgumentError.value(
        settings.sliceZMm,
        'sliceZMm',
        'must be finite and >= 0',
      );
    }
    if (!settings.wallNozzleDiameter.isFinite ||
        settings.wallNozzleDiameter <= 0) {
      throw ArgumentError.value(
        settings.wallNozzleDiameter,
        'wallNozzleDiameter',
        'must be finite and > 0',
      );
    }
    if (settings.raftLayers < 0) {
      throw ArgumentError.value(settings.raftLayers, 'raftLayers', 'must be >= 0');
    }
    if (settings.fuzzyConfig.type != settings.islandProcess.fuzzySkinType) {
      throw ArgumentError(
        'fuzzyConfig.type must match islandProcess.fuzzySkinType because the '
        'pinned source uses one fuzzy-skin config for simplification and traversal',
      );
    }
  }
}
