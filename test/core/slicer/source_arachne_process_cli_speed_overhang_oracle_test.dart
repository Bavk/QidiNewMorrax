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
import 'package:qidi_flow_flutter/core/slicer/surface.dart';

class _NoRandom implements SourceFuzzyUnitRandom2 {
  @override
  double nextUnit() =>
      throw StateError('identity Arachne speed oracle consumed RNG');
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
        'test/fixtures/source_arachne_process_speed_bambustudio_f2b55a5a.json',
      ).readAsStringSync(),
    ) as Map<String, dynamic>;

SourceArachneProcessPipelineSettings2 _settings() {
  const spacing = 35707;
  final wallFlow = _flow(0.4);
  final upper = _rect(500000, 0, 2500000, 2000000);
  final rawLower = _rect(0, 0, 2000000, 2000000);
  final grownLower = _rect(-20000, -20000, 2020000, 2020000);
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
        upperSlices: [upper],
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
      lowerSlices: [rawLower],
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
      layerId: 1,
      sliceZMm: 0.4,
      detectOverhangWall: true,
      lowerLayerPolygons: [grownLower],
      overhangFlow: wallFlow,
      nozzleDiameterMm: 0.4,
      enableOverhangSpeed: true,
      outerWallLineWidthMm: 0,
    ),
    externalMixedSpacingSource: spacing,
    solidInfillSpacingSource: spacing,
    infillWallOverlap: const SourceFloatOrPercent2.percent(15),
  );
}

List<double> _edgeXsMm(
  ExtrusionLoop2 loop,
  ExtrusionRole role, {
  required bool top,
  required double minModelX,
  required double tolerance,
}) {
  final allPoints = <SourcePoint2>[
    for (final path in loop.paths) ...path.polyline.points,
  ];
  final edgeY = top
      ? allPoints.map((point) => point.y).reduce((a, b) => a > b ? a : b)
      : allPoints.map((point) => point.y).reduce((a, b) => a < b ? a : b);
  final threshold = minModelX - tolerance;
  final xs = <int>{};
  for (final path in loop.paths) {
    if (path.role != role) continue;
    for (final point in path.polyline.points) {
      if (point.y == edgeY && point.xMm >= threshold) xs.add(point.x);
    }
  }
  final sorted = xs.toList()..sort();
  return [for (final x in sorted) Slic3rUnits.unscale(x)];
}

void _expectCloseList(
  List<double> actual,
  List<dynamic> expected,
  double tolerance,
) {
  expect(actual, hasLength(expected.length));
  for (var index = 0; index < expected.length; index++) {
    expect(
      actual[index],
      closeTo((expected[index] as num).toDouble(), tolerance),
      reason: 'mismatch at grading point $index',
    );
  }
}

List<ExtrusionPath2> _gradedEdgePaths(
  ExtrusionLoop2 loop,
  ExtrusionRole role, {
  required double minModelX,
  required double tolerance,
}) {
  final allPoints = <SourcePoint2>[
    for (final path in loop.paths) ...path.polyline.points,
  ];
  final minY = allPoints.map((point) => point.y).reduce((a, b) => a < b ? a : b);
  final maxY = allPoints.map((point) => point.y).reduce((a, b) => a > b ? a : b);
  final threshold = minModelX - tolerance;
  return [
    for (final path in loop.paths)
      if (path.role == role &&
          path.polyline.points.any(
            (point) =>
                (point.y == minY || point.y == maxY) &&
                point.xMm >= threshold,
          ))
        path,
  ];
}

void _expectDegreeContract(
  ExtrusionLoop2 loop,
  ExtrusionRole supportedRole,
  Map<String, dynamic> contract, {
  required double minModelX,
  required double tolerance,
}) {
  final gap = (contract['min_degree_gap'] as num).toDouble();
  final degreeMin = (contract['supported_degree_min'] as num).toDouble();
  final degreeMax = (contract['supported_degree_max'] as num).toDouble();
  final graded = _gradedEdgePaths(
    loop,
    supportedRole,
    minModelX: minModelX,
    tolerance: tolerance,
  );
  expect(graded, isNotEmpty);
  expect(graded.any((path) => path.overhangDegree > degreeMin), isTrue);
  expect(graded.map((path) => path.overhangDegree).toSet().length, greaterThan(3));
  for (final path in graded) {
    expect(path.overhangDegree, inInclusiveRange(degreeMin, degreeMax));
    final bucket = path.overhangDegree / gap;
    expect(bucket, closeTo(bucket.roundToDouble(), 1e-9));
  }

  final unsupported = loop.paths.where(
    (path) => path.role == ExtrusionRole.overhangPerimeter,
  );
  expect(unsupported, isNotEmpty);
  final expectedUnsupported =
      (contract['bent_unsupported_degree'] as num).toDouble();
  for (final path in unsupported) {
    expect(path.overhangDegree, expectedUnsupported);
  }
}

void main() {
  test('pinned CLI matches process-level speed-graded Arachne segmentation', () {
    final root = _oracleRoot();
    final oracle = root['oracle'] as Map<String, dynamic>;
    final degreeContract = root['source_degree_contract'] as Map<String, dynamic>;
    final tolerance =
        (root['gcode_serialization_tolerance_mm'] as num).toDouble();
    final minModelX =
        (oracle['comparison_window_min_model_x_mm'] as num).toDouble();
    final supportEdge =
        (oracle['grown_lower_support_edge_model_x_mm'] as num).toDouble();

    final loops = <ExtrusionEntityCollection2>[];
    final fillSurfaces = <Surface2>[];
    final fillNoOverlap = <SourceExPolygon2>[];
    final result = SourceArachneProcessPipeline2.processSurface(
      surface: Surface2(
        expolygon: SourceExPolygon2(
          contour: _rect(500000, 0, 2500000, 2000000),
        ),
      ),
      settings: _settings(),
      layerIndex: 1,
      random: _NoRandom(),
      loops: loops,
      fillSurfaces: fillSurfaces,
      fillNoOverlap: fillNoOverlap,
    );

    expect(result.extrusionCollection.entities, hasLength(2));
    final inner = result.extrusionCollection.entities[0] as ExtrusionLoop2;
    final outer = result.extrusionCollection.entities[1] as ExtrusionLoop2;
    final innerOracle = oracle['inner_wall'] as Map<String, dynamic>;
    final outerOracle = oracle['outer_wall'] as Map<String, dynamic>;

    _expectCloseList(
      _edgeXsMm(
        inner,
        ExtrusionRole.perimeter,
        top: false,
        minModelX: minModelX,
        tolerance: tolerance,
      ),
      innerOracle['bottom_supported_x_model_mm'] as List<dynamic>,
      tolerance,
    );
    _expectCloseList(
      _edgeXsMm(
        inner,
        ExtrusionRole.perimeter,
        top: true,
        minModelX: minModelX,
        tolerance: tolerance,
      ),
      innerOracle['top_supported_x_model_mm'] as List<dynamic>,
      tolerance,
    );
    _expectCloseList(
      _edgeXsMm(
        outer,
        ExtrusionRole.externalPerimeter,
        top: false,
        minModelX: minModelX,
        tolerance: tolerance,
      ),
      outerOracle['bottom_supported_x_model_mm'] as List<dynamic>,
      tolerance,
    );
    _expectCloseList(
      _edgeXsMm(
        outer,
        ExtrusionRole.externalPerimeter,
        top: true,
        minModelX: minModelX,
        tolerance: tolerance,
      ),
      outerOracle['top_supported_x_model_mm'] as List<dynamic>,
      tolerance,
    );

    for (final loop in [inner, outer]) {
      final overhangXs = <double>[
        for (final path in loop.paths)
          if (path.role == ExtrusionRole.overhangPerimeter)
            for (final point in path.polyline.points) point.xMm,
      ];
      expect(overhangXs.reduce((a, b) => a < b ? a : b), closeTo(supportEdge, tolerance));
    }

    _expectDegreeContract(
      inner,
      ExtrusionRole.perimeter,
      degreeContract,
      minModelX: minModelX,
      tolerance: tolerance,
    );
    _expectDegreeContract(
      outer,
      ExtrusionRole.externalPerimeter,
      degreeContract,
      minModelX: minModelX,
      tolerance: tolerance,
    );
  });
}
