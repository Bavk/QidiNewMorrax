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
  double nextUnit() => throw StateError('identity Arachne oracle consumed RNG');
}

SourcePolygon2 _rect(int minX, int minY, int maxX, int maxY) =>
    SourcePolygon2([
      SourcePoint2(minX, minY),
      SourcePoint2(maxX, minY),
      SourcePoint2(maxX, maxY),
      SourcePoint2(minX, maxY),
    ]);

Flow _wallFlow() => Flow.nonBridging(
      width: 0.4,
      height: 0.2,
      nozzleDiameter: 0.4,
    );

Map<String, dynamic> _oracleRoot() =>
    jsonDecode(
      File(
        'test/fixtures/source_arachne_process_alltop_bambustudio_f2b55a5a.json',
      ).readAsStringSync(),
    ) as Map<String, dynamic>;

SourceArachneProcessPipelineSettings2 _settings() {
  final flow = _wallFlow();
  final spacing = flow.scaledSpacing;
  final current = _rect(0, 0, 2000000, 2000000);
  final upper = _rect(0, 0, 1000000, 2000000);
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
        extPerimeterWidth: flow.scaledWidth,
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
      perimeterWidth: flow.scaledWidth,
      layerHeightMm: 0.2,
      topAreaThresholdPercent: 200,
      lowerSlices: [current],
    ),
    traversalSettings: SourceArachneExtrusionTraversalSettings2(
      perimeterFlow: flow,
      externalPerimeterFlow: flow,
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
      overhangFlow: flow,
      nozzleDiameterMm: 0.4,
      enableOverhangSpeed: false,
      outerWallLineWidthMm: 0,
    ),
    externalMixedSpacingSource: spacing,
    solidInfillSpacingSource: spacing,
    infillWallOverlap: const SourceFloatOrPercent2.percent(15),
  );
}

(double, double, double, double) _boundsMm(ExtrusionEntity2 entity) {
  final points = <SourcePoint2>[];
  entity.collectPoints(points);
  if (points.isEmpty) throw StateError('partial Alltop wall has no points');
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
  return (
    Slic3rUnits.unscale(minX),
    Slic3rUnits.unscale(maxX),
    Slic3rUnits.unscale(minY),
    Slic3rUnits.unscale(maxY),
  );
}

void main() {
  test('pinned BambuStudio CLI matches partial Alltop wall recombination', () {
    final root = _oracleRoot();
    final oracle = root['oracle'] as Map<String, dynamic>;
    final innerOracle = oracle['inner_wall'] as Map<String, dynamic>;
    final outerOracle = oracle['outer_wall'] as Map<String, dynamic>;
    final tolerance =
        (root['gcode_serialization_tolerance_mm'] as num).toDouble();
    final flow = _wallFlow();
    expect(flow.scaledSpacing, 35707);

    final loops = <ExtrusionEntityCollection2>[];
    final fillSurfaces = <Surface2>[];
    final fillNoOverlap = <SourceExPolygon2>[];
    final surface = Surface2(
      expolygon: SourceExPolygon2(
        contour: _rect(0, 0, 2000000, 2000000),
      ),
    );

    final result = SourceArachneProcessPipeline2.processSurface(
      surface: surface,
      settings: _settings(),
      layerIndex: 1,
      random: _NoRandom(),
      loops: loops,
      fillSurfaces: fillSurfaces,
      fillNoOverlap: fillNoOverlap,
    );

    expect(result.surfaceResult.topOneWallEnabled, isTrue);
    expect(result.surfaceResult.remainingWallToolPaths, isNotNull);
    expect(result.extrusionCollection.entities, hasLength(2));
    expect(
      result.extrusionCollection.entities.map((entity) => entity.role).toList(),
      [ExtrusionRole.perimeter, ExtrusionRole.externalPerimeter],
    );

    final inner = result.extrusionCollection.entities[0];
    final outer = result.extrusionCollection.entities[1];
    final innerBounds = _boundsMm(inner);
    final outerBounds = _boundsMm(outer);

    expect(
      innerBounds.$2 - innerBounds.$1,
      closeTo((innerOracle['bbox_width_mm'] as num).toDouble(), tolerance),
    );
    expect(
      innerBounds.$4 - innerBounds.$3,
      closeTo((innerOracle['bbox_height_mm'] as num).toDouble(), tolerance),
    );
    expect(
      outerBounds.$2 - outerBounds.$1,
      closeTo((outerOracle['bbox_width_mm'] as num).toDouble(), tolerance),
    );
    expect(
      outerBounds.$4 - outerBounds.$3,
      closeTo((outerOracle['bbox_height_mm'] as num).toDouble(), tolerance),
    );

    // Compare placement relative to the full outer wall so the CLI's global
    // arrange translation is eliminated while retaining the Alltop side.
    expect(
      innerBounds.$1 - outerBounds.$1,
      closeTo(
        (innerOracle['min_x_from_outer_min_x_mm'] as num).toDouble(),
        tolerance,
      ),
    );
    expect(
      innerBounds.$2 - outerBounds.$1,
      closeTo(
        (innerOracle['max_x_from_outer_min_x_mm'] as num).toDouble(),
        tolerance,
      ),
    );
    expect(
      innerBounds.$3 - outerBounds.$3,
      closeTo(
        (innerOracle['min_y_from_outer_min_y_mm'] as num).toDouble(),
        tolerance,
      ),
    );
    expect(
      innerBounds.$4 - outerBounds.$3,
      closeTo(
        (innerOracle['max_y_from_outer_min_y_mm'] as num).toDouble(),
        tolerance,
      ),
    );

    expect(result.surfaceResult.totalPerimeters, hasLength(2));
    expect(fillSurfaces, isNotEmpty);
    expect(fillNoOverlap, isNotEmpty);
  });
}
