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
  double nextUnit() => throw StateError('identity fill oracle consumed RNG');
}

SourcePolygon2 _square(int min, int max) => SourcePolygon2([
      SourcePoint2(min, min),
      SourcePoint2(max, min),
      SourcePoint2(max, max),
      SourcePoint2(min, max),
    ]);

Flow _flow(double width) => Flow.nonBridging(
      width: width,
      height: 0.2,
      nozzleDiameter: 0.4,
    );

Map<String, dynamic> _oracleRoot() =>
    jsonDecode(
      File(
        'test/fixtures/source_arachne_fill_boundary_bambustudio_f2b55a5a.json',
      ).readAsStringSync(),
    ) as Map<String, dynamic>;

SourceArachneProcessPipelineSettings2 _settings(
  Map<String, dynamic> oracle,
) {
  final helper = oracle['helper_args'] as Map<String, dynamic>;
  final outerWidth = oracle['outer_wall_width_source'] as int;
  final innerWidth = oracle['inner_wall_width_source'] as int;
  final externalSpacing = helper['external_spacing_source'] as int;
  final perimeterSpacing = helper['perimeter_spacing_source'] as int;
  final mixedOrRegularSpacing = helper['spacing_source'] as int;

  return SourceArachneProcessPipelineSettings2(
    surfaceSettings: SourceArachneSurfaceProcessSettings2(
      planning: SourceArachneProcessPlanningSettings2(
        wallLoops: oracle['wall_loops'] as int,
        alternateExtraWall: false,
        spiralVase: false,
        preciseOuterWall: false,
        wallSequence: SourceWallSequence2.innerOuter,
        onlyOneWallFirstLayer: false,
        topOneWallType: SourceTopOneWallType2.none,
        upperSlices: const <SourcePolygon2>[],
        extPerimeterWidth: outerWidth,
        extPerimeterSpacing: externalSpacing,
        minNozzleDiameterMm: 0.4,
        minBeadWidthPercent: 85,
        minFeatureSizePercent: 25,
        wallTransitionLengthPercent: 100,
        wallTransitionAngleDeg: 10,
        wallTransitionFilterDeviationPercent: 25,
        wallDistributionCount: 1,
      ),
      surfaceSimplifyResolutionSource: 1000,
      perimeterSpacing: perimeterSpacing,
      perimeterWidth: innerWidth,
      layerHeightMm: 0.2,
    ),
    traversalSettings: SourceArachneExtrusionTraversalSettings2(
      perimeterFlow: _flow(innerWidth * Slic3rUnits.scalingFactor),
      externalPerimeterFlow: _flow(outerWidth * Slic3rUnits.scalingFactor),
      fuzzyConfig: const SourceFuzzySkinNoRegionConfig2(
        type: SourceFuzzySkinType2.none,
        fuzzySkinFirstLayer: true,
        thicknessMm: 0.1,
        pointDistanceMm: 0.4,
        noiseType: SourceFuzzyNoiseType2.classic,
      ),
      layerId: 1,
      sliceZMm: 0.4,
      detectOverhangWall: false,
      outerWallLineWidthMm: outerWidth * Slic3rUnits.scalingFactor,
    ),
    externalMixedSpacingSource: mixedOrRegularSpacing,
    // The exact compiled helper call reports
    // min_perimeter_infill_spacing=21424, which is the pinned 0.6 factor
    // applied to the 0.4mm solid-infill Flow spacing 35707.
    solidInfillSpacingSource: 35707,
    infillWallOverlap: const SourceFloatOrPercent2.percent(15),
  );
}

(int, int) _span(SourcePolygon2 polygon) {
  final points = polygon.points;
  if (points.isEmpty) return (0, 0);
  var minX = points.first.x;
  var maxX = points.first.x;
  var minY = points.first.y;
  var maxY = points.first.y;
  for (final point in points.skip(1)) {
    if (point.x < minX) minX = point.x;
    if (point.x > maxX) maxX = point.x;
    if (point.y < minY) minY = point.y;
    if (point.y > maxY) maxY = point.y;
  }
  return (maxX - minX, maxY - minY);
}

void _expectSpan(
  SourcePolygon2 actual,
  List<dynamic> expected, {
  required String reason,
}) {
  final span = _span(actual);
  final tolerance = Slic3rUnits.scaledEpsilon.toDouble();
  expect(span.$1, closeTo(expected[0] as int, tolerance), reason: '$reason x');
  expect(span.$2, closeTo(expected[1] as int, tolerance), reason: '$reason y');
}

void _runCase(Map<String, dynamic> oracle) {
  final helper = oracle['helper_args'] as Map<String, dynamic>;
  final fillOracle = oracle['fill_surfaces'] as Map<String, dynamic>;
  final noOverlapOracle = oracle['fill_no_overlap'] as Map<String, dynamic>;
  final loops = <ExtrusionEntityCollection2>[];
  final fillSurfaces = <Surface2>[];
  final fillNoOverlap = <SourceExPolygon2>[];

  final result = SourceArachneProcessPipeline2.processSurface(
    surface: Surface2(
      expolygon: SourceExPolygon2(contour: _square(0, 2000000)),
    ),
    settings: _settings(oracle),
    layerIndex: 1,
    random: _NoRandom(),
    loops: loops,
    fillSurfaces: fillSurfaces,
    fillNoOverlap: fillNoOverlap,
  );

  expect(result.surfaceResult.plan.loopNumber, helper['loops']);
  expect(result.spacingSource, helper['spacing_source']);
  expect(
    result.infillResult.minPerimeterInfillSpacingSource,
    helper['min_perimeter_infill_spacing_source'],
  );
  expect(result.infillResult.filteredOutAsTooSmall, isFalse);

  expect(fillSurfaces, hasLength(fillOracle['count'] as int));
  final fill = fillSurfaces.single;
  expect(fill.surfaceType.index, fillOracle['surface_type']);
  expect(fill.expolygon.holes, hasLength(fillOracle['holes'] as int));
  expect(
    fill.expolygon.contour.points,
    hasLength(fillOracle['contour_points'] as int),
  );
  _expectSpan(
    fill.expolygon.contour,
    fillOracle['span_source'] as List<dynamic>,
    reason: 'fill_surfaces span',
  );

  expect(fillNoOverlap, hasLength(noOverlapOracle['count'] as int));
  final noOverlap = fillNoOverlap.single;
  expect(noOverlap.holes, hasLength(noOverlapOracle['holes'] as int));
  expect(
    noOverlap.contour.points,
    hasLength(noOverlapOracle['contour_points'] as int),
  );
  _expectSpan(
    noOverlap.contour,
    noOverlapOracle['span_source'] as List<dynamic>,
    reason: 'fill_no_overlap span',
  );
}

void main() {
  test('compiled pinned binary matches no-wall Arachne fill outputs', () {
    final oracles = _oracleRoot()['oracles'] as Map<String, dynamic>;
    _runCase(oracles['no_wall'] as Map<String, dynamic>);
  });

  test('compiled pinned binary matches one-wall mixed-spacing fill outputs', () {
    final oracles = _oracleRoot()['oracles'] as Map<String, dynamic>;
    final oracle = oracles['one_wall_mixed_spacing'] as Map<String, dynamic>;
    final helper = oracle['helper_args'] as Map<String, dynamic>;

    // Direct compiled entry capture proves this is the mixed-spacing branch,
    // not a value inferred from its final geometry.
    expect(helper['external_spacing_source'], 37707);
    expect(helper['perimeter_spacing_source'], 40707);
    expect(helper['spacing_source'], 39207);
    _runCase(oracle);
  });

  test('compiled pinned binary matches two-wall Arachne fill outputs', () {
    final oracles = _oracleRoot()['oracles'] as Map<String, dynamic>;
    _runCase(oracles['two_wall'] as Map<String, dynamic>);
  });
}
