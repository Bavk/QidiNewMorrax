import 'dart:convert';
import 'dart:io';

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
  double nextUnit() => throw StateError('identity LoopNode oracle consumed RNG');
}

SourcePolygon2 _rect(int minX, int minY, int maxX, int maxY) =>
    SourcePolygon2([
      SourcePoint2(minX, minY),
      SourcePoint2(maxX, minY),
      SourcePoint2(maxX, maxY),
      SourcePoint2(minX, maxY),
    ]);

Flow _flow(double width) => Flow.nonBridging(
      width: width,
      height: 0.2,
      nozzleDiameter: 0.4,
    );

Map<String, dynamic> _oracleRoot() =>
    jsonDecode(
      File(
        'test/fixtures/source_arachne_loop_node_bambustudio_f2b55a5a.json',
      ).readAsStringSync(),
    ) as Map<String, dynamic>;

SourceArachneProcessPipelineSettings2 _settings({
  required int layerId,
  required List<SourcePolygon2>? upperSlices,
  required List<SourceLoopNode2> loopNodes,
}) {
  const spacing = 35707;
  final wallFlow = _flow(0.4);
  return SourceArachneProcessPipelineSettings2(
    surfaceSettings: SourceArachneSurfaceProcessSettings2(
      planning: SourceArachneProcessPlanningSettings2(
        wallLoops: 2,
        alternateExtraWall: false,
        spiralVase: false,
        preciseOuterWall: false,
        wallSequence: SourceWallSequence2.innerOuter,
        onlyOneWallFirstLayer: false,
        topOneWallType: SourceTopOneWallType2.allTop,
        upperSlices: upperSlices,
        extPerimeterWidth: 40000,
        extPerimeterSpacing: spacing,
        minNozzleDiameterMm: 0.4,
        minBeadWidthPercent: 85,
        minFeatureSizePercent: 25,
        wallTransitionLengthPercent: 100,
        wallTransitionAngleDeg: 10,
        wallTransitionFilterDeviationPercent: 25,
        wallDistributionCount: 1,
      ),
      surfaceSimplifyResolutionSource: 1000,
      perimeterSpacing: spacing,
      perimeterWidth: 40000,
      layerHeightMm: 0.2,
      topAreaThresholdPercent: 200,
      lowerSlices: [_rect(0, 0, 2000000, 2000000)],
    ),
    traversalSettings: SourceArachneExtrusionTraversalSettings2(
      perimeterFlow: wallFlow,
      externalPerimeterFlow: wallFlow,
      fuzzyConfig: const SourceFuzzySkinNoRegionConfig2(
        type: SourceFuzzySkinType2.none,
        fuzzySkinFirstLayer: true,
        thicknessMm: 0.1,
        pointDistanceMm: 0.4,
        noiseType: SourceFuzzyNoiseType2.classic,
      ),
      layerId: layerId,
      sliceZMm: (layerId + 1) * 0.2,
      detectOverhangWall: false,
      zDirectionOutwallSpeedContinuous: true,
      loopNodes: loopNodes,
      outerWallLineWidthMm: 0.4,
    ),
    externalMixedSpacingSource: spacing,
    solidInfillSpacingSource: spacing,
    infillWallOverlap: const SourceFloatOrPercent2.percent(15),
  );
}

List<SourcePoint2> _decodedPoints(List<dynamic> values) => [
      for (final raw in values)
        SourcePoint2(
          (raw as List<dynamic>)[0] as int,
          raw[1] as int,
        ),
    ];

void _expectCoordinateClose(int actual, int expected, String reason) {
  expect(
    actual,
    closeTo(expected, Slic3rUnits.scaledEpsilon.toDouble()),
    reason: reason,
  );
}

void _expectCompiledNode(
  SourceLoopNode2 actual,
  Map<String, dynamic> expected,
) {
  expect(actual.nodeId, expected['node_id']);
  expect(actual.loopId, expected['loop_id']);
  expect(actual.nodeContour.isLoop, expected['is_loop']);
  expect(actual.nodeContour.widths, expected['widths']);
  expect(actual.mergedId, expected['merged_id']);
  expect(actual.upperNodeIds, expected['upper_node_ids']);
  expect(actual.lowerNodeIds, expected['lower_node_ids']);

  final expectedBbox = (expected['bbox'] as List<dynamic>).cast<int>();
  final expectedMin = SourcePoint2(expectedBbox[0], expectedBbox[1]);
  final expectedMax = SourcePoint2(expectedBbox[2], expectedBbox[3]);
  final expectedSpan = expectedMax - expectedMin;
  final actualSpan = actual.bounds.max - actual.bounds.min;
  _expectCoordinateClose(actualSpan.x, expectedSpan.x, 'LoopNode bbox width');
  _expectCoordinateClose(actualSpan.y, expectedSpan.y, 'LoopNode bbox height');

  final expectedPoints = _decodedPoints(expected['points'] as List<dynamic>);
  expect(actual.nodeContour.points, hasLength(expectedPoints.length));

  // The exact compiled probe is plate-arranged before slicing. Translation is
  // not part of the perimeter producer, so compare every raw Arachne junction
  // relative to that node's own bbox minimum. No seam/reversal normalization
  // is applied here; source ordering and widths remain part of the oracle.
  for (var index = 0; index < expectedPoints.length; index++) {
    final actualRelative = actual.nodeContour.points[index] - actual.bounds.min;
    final expectedRelative = expectedPoints[index] - expectedMin;
    _expectCoordinateClose(
      actualRelative.x,
      expectedRelative.x,
      'LoopNode point $index x',
    );
    _expectCoordinateClose(
      actualRelative.y,
      expectedRelative.y,
      'LoopNode point $index y',
    );
  }
}

void _runOracleCase(
  Map<String, dynamic> oracle, {
  required List<SourcePolygon2>? upperSlices,
}) {
  final layerId = oracle['layer_id'] as int;
  final globalNodes = <SourceLoopNode2>[];
  final loops = <ExtrusionEntityCollection2>[];
  final fillSurfaces = <Surface2>[];
  final fillNoOverlap = <SourceExPolygon2>[];

  final result = SourceArachneProcessPipeline2.processSurface(
    surface: Surface2(
      expolygon: SourceExPolygon2(
        contour: _rect(500000, 0, 2500000, 2000000),
      ),
    ),
    settings: _settings(
      layerId: layerId,
      upperSlices: upperSlices,
      loopNodes: globalNodes,
    ),
    layerIndex: layerId,
    random: _NoRandom(),
    loops: loops,
    fillSurfaces: fillSurfaces,
    fillNoOverlap: fillNoOverlap,
  );

  final expectedRange =
      (oracle['loop_node_range'] as List<dynamic>).cast<int>();
  expect(
    result.extrusionCollection.loopNodeRange,
    (expectedRange[0], expectedRange[1]),
  );
  expect(globalNodes, hasLength(oracle['global_node_count'] as int));
  _expectCompiledNode(
    globalNodes.single,
    oracle['node'] as Map<String, dynamic>,
  );
}

void main() {
  test('compiled pinned binary matches two-wall Arachne LoopNode payload', () {
    final root = _oracleRoot();
    final oracle = (root['oracles'] as Map<String, dynamic>)[
        'interior_two_wall'] as Map<String, dynamic>;
    _runOracleCase(
      oracle,
      upperSlices: [_rect(500000, 0, 2500000, 2000000)],
    );
  });

  test('compiled pinned binary matches topmost LoopNode loop id and range', () {
    final root = _oracleRoot();
    final oracle = (root['oracles'] as Map<String, dynamic>)[
        'topmost_one_wall'] as Map<String, dynamic>;
    _runOracleCase(oracle, upperSlices: null);
  });
}
