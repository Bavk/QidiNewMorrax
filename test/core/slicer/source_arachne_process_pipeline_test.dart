import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_fill_boundary.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_top_one_wall_context.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_wall_sequence.dart';
import 'package:qidi_flow_flutter/core/slicer/extrusion_entity.dart';
import 'package:qidi_flow_flutter/core/slicer/flow.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_extrusion_traversal.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_process_pipeline.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_process_planning.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_process_surface.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_apply.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_policy.dart';
import 'package:qidi_flow_flutter/core/slicer/source_loop_node.dart';
import 'package:qidi_flow_flutter/core/slicer/surface.dart';

class _NoRandom implements SourceFuzzyUnitRandom2 {
  @override
  double nextUnit() => throw StateError('identity Arachne process consumed RNG');
}

SourcePolygon2 _square(int min, int max) => SourcePolygon2([
      SourcePoint2(min, min),
      SourcePoint2(max, min),
      SourcePoint2(max, max),
      SourcePoint2(min, max),
    ]);

Surface2 _surface({int size = 1000000}) => Surface2(
      expolygon: SourceExPolygon2(contour: _square(0, size)),
    );

Flow _flow(double width) => Flow.nonBridging(
      width: width,
      height: 0.2,
      nozzleDiameter: 0.4,
    );

SourceArachneProcessPlanningSettings2 _planning({int wallLoops = 2}) =>
    SourceArachneProcessPlanningSettings2(
      wallLoops: wallLoops,
      alternateExtraWall: false,
      spiralVase: false,
      preciseOuterWall: false,
      wallSequence: SourceWallSequence2.innerOuter,
      onlyOneWallFirstLayer: false,
      topOneWallType: SourceTopOneWallType2.none,
      upperSlices: const <SourcePolygon2>[],
      extPerimeterWidth: 40000,
      extPerimeterSpacing: 38000,
      minNozzleDiameterMm: 0.4,
      minBeadWidthPercent: 50,
      minFeatureSizePercent: 25,
      wallTransitionLengthPercent: 100,
      wallTransitionAngleDeg: 10,
      wallTransitionFilterDeviationPercent: 10,
      wallDistributionCount: 3,
    );

SourceArachneProcessPipelineSettings2 _settings({
  int wallLoops = 2,
  List<SourceLoopNode2>? loopNodes,
  bool qidiLoopNodes = false,
}) {
  final surfaceSettings = SourceArachneSurfaceProcessSettings2(
    planning: _planning(wallLoops: wallLoops),
    surfaceSimplifyResolutionSource: 1,
    perimeterSpacing: 40000,
    layerHeightMm: 0.2,
  );
  return SourceArachneProcessPipelineSettings2(
    surfaceSettings: surfaceSettings,
    traversalSettings: SourceArachneExtrusionTraversalSettings2(
      perimeterFlow: _flow(0.45),
      externalPerimeterFlow: _flow(0.42),
      fuzzyConfig: const SourceFuzzySkinNoRegionConfig2(
        type: SourceFuzzySkinType2.none,
        fuzzySkinFirstLayer: true,
        thicknessMm: 0.1,
        pointDistanceMm: 0.4,
        noiseType: SourceFuzzyNoiseType2.classic,
      ),
      layerId: 1,
      sliceZMm: 0.2,
      zDirectionOutwallSpeedContinuous: qidiLoopNodes,
      loopNodes: loopNodes,
      outerWallLineWidthMm: 0.42,
    ),
    externalMixedSpacingSource: 39000,
    solidInfillSpacingSource: 40000,
    infillWallOverlap: const SourceFloatOrPercent2.percent(20),
  );
}

void main() {
  test('two-wall surface reaches loops and final Arachne fill boundaries', () {
    final loops = <ExtrusionEntityCollection2>[];
    final fillSurfaces = <Surface2>[];
    final fillNoOverlap = <SourceExPolygon2>[];

    final result = SourceArachneProcessPipeline2.processSurface(
      surface: _surface(),
      settings: _settings(wallLoops: 2),
      layerIndex: 1,
      random: _NoRandom(),
      loops: loops,
      fillSurfaces: fillSurfaces,
      fillNoOverlap: fillNoOverlap,
    );

    expect(result.surfaceResult.plan.loopNumber, 1);
    expect(result.surfaceResult.totalPerimeters, hasLength(2));
    expect(result.orderedExtrusions, isNotEmpty);
    expect(result.extrusionCollection.isEmpty, isFalse);
    expect(result.appendedLoopCollection, isTrue);
    expect(loops, hasLength(1));
    expect(loops.single.entities, isNotEmpty);
    expect(result.spacingSource, 40000);
    expect(fillSurfaces, isNotEmpty);
    expect(fillNoOverlap, isNotEmpty);
    expect(result.infillResult.resolvedInsertSource, 7999);
  });

  test('single generated wall uses pinned mixed spacing before fill filter', () {
    final loops = <ExtrusionEntityCollection2>[];
    final fillSurfaces = <Surface2>[];
    final fillNoOverlap = <SourceExPolygon2>[];

    final result = SourceArachneProcessPipeline2.processSurface(
      surface: _surface(),
      settings: _settings(wallLoops: 1),
      layerIndex: 1,
      random: _NoRandom(),
      loops: loops,
      fillSurfaces: fillSurfaces,
      fillNoOverlap: fillNoOverlap,
    );

    expect(result.surfaceResult.plan.loopNumber, 0);
    expect(result.surfaceResult.totalPerimeters, hasLength(1));
    expect(result.spacingSource, 39000);
    // `loops == 0` resolves percentage overlap against external spacing,
    // not the mixed spacing used only by the too-small infill probe.
    expect(result.infillResult.resolvedInsertSource, 7599);
    expect(loops, hasLength(1));
    expect(fillSurfaces, isNotEmpty);
    expect(fillNoOverlap, isNotEmpty);
  });

  test('zero walls skips loops append but still emits source fill boundary', () {
    final loops = <ExtrusionEntityCollection2>[];
    final fillSurfaces = <Surface2>[];
    final fillNoOverlap = <SourceExPolygon2>[];

    final result = SourceArachneProcessPipeline2.processSurface(
      surface: _surface(),
      settings: _settings(wallLoops: 0),
      layerIndex: 1,
      random: _NoRandom(),
      loops: loops,
      fillSurfaces: fillSurfaces,
      fillNoOverlap: fillNoOverlap,
    );

    expect(result.surfaceResult.plan.loopNumber, -1);
    expect(result.surfaceResult.totalPerimeters, isEmpty);
    expect(result.orderedExtrusions, isEmpty);
    expect(result.extrusionCollection.isEmpty, isTrue);
    expect(result.appendedLoopCollection, isFalse);
    expect(loops, isEmpty);
    expect(result.spacingSource, 40000);
    expect(result.infillResult.resolvedInsertSource, 0);
    expect(fillSurfaces, isNotEmpty);
    expect(fillNoOverlap, isNotEmpty);
  });

  test('final process carries Arachne QIDI loop-node range into appended loops', () {
    final globalNodes = <SourceLoopNode2>[];
    final loops = <ExtrusionEntityCollection2>[];
    final fillSurfaces = <Surface2>[];
    final fillNoOverlap = <SourceExPolygon2>[];

    final result = SourceArachneProcessPipeline2.processSurface(
      surface: _surface(),
      settings: _settings(
        wallLoops: 1,
        loopNodes: globalNodes,
        qidiLoopNodes: true,
      ),
      layerIndex: 1,
      random: _NoRandom(),
      loops: loops,
      fillSurfaces: fillSurfaces,
      fillNoOverlap: fillNoOverlap,
    );

    expect(result.appendedLoopCollection, isTrue);
    expect(globalNodes, isNotEmpty);
    expect(loops.single.loopNodeRange.$1, 0);
    expect(loops.single.loopNodeRange.$2, globalNodes.length);
    expect(
      globalNodes.every((node) => node.loopId >= 0),
      isTrue,
    );
  });
}
