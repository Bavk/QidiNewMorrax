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

SourcePolygon2 _clockwiseRect(int minX, int minY, int maxX, int maxY) =>
    SourcePolygon2([
      SourcePoint2(minX, minY),
      SourcePoint2(minX, maxY),
      SourcePoint2(maxX, maxY),
      SourcePoint2(maxX, minY),
    ]);

Flow _wallFlow() => Flow.nonBridging(
      width: 0.4,
      height: 0.2,
      nozzleDiameter: 0.4,
    );

Map<String, dynamic> _oracleRoot() =>
    jsonDecode(
      File(
        'test/fixtures/source_arachne_process_hole_bambustudio_f2b55a5a.json',
      ).readAsStringSync(),
    ) as Map<String, dynamic>;

SourceArachneProcessPipelineSettings2 _settings() {
  final flow = _wallFlow();
  final spacing = flow.scaledSpacing;
  final contour = _rect(0, 0, 2000000, 2000000);
  final hole = _clockwiseRect(500000, 500000, 1500000, 1500000);
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
        upperSlices: [contour, hole],
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
      lowerSlices: [contour, hole],
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
      detectOverhangWall: false,
      nozzleDiameterMm: 0.4,
      outerWallLineWidthMm: 0,
    ),
    externalMixedSpacingSource: spacing,
    solidInfillSpacingSource: spacing,
    infillWallOverlap: const SourceFloatOrPercent2.percent(15),
  );
}

(double, double) _spanMm(ExtrusionEntity2 entity) {
  final points = <SourcePoint2>[];
  entity.collectPoints(points);
  if (points.isEmpty) throw StateError('Arachne hole oracle wall has no points');
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
    Slic3rUnits.unscale(maxX - minX),
    Slic3rUnits.unscale(maxY - minY),
  );
}

void _expectRoleSpans(
  List<ExtrusionEntity2> entities,
  ExtrusionRole role,
  List<double> expected,
  double tolerance,
) {
  final spans = entities
      .where((entity) => entity.role == role)
      .map((entity) => _spanMm(entity).$1)
      .toList()
    ..sort();
  final sortedExpected = [...expected]..sort();
  expect(spans, hasLength(sortedExpected.length));
  for (var i = 0; i < spans.length; i++) {
    expect(spans[i], closeTo(sortedExpected[i], tolerance));
  }

  for (final entity in entities.where((entity) => entity.role == role)) {
    final span = _spanMm(entity);
    expect(span.$1, closeTo(span.$2, tolerance));
  }
}

void main() {
  test('pinned BambuStudio CLI matches square Arachne through-hole walls', () {
    final root = _oracleRoot();
    final oracle = root['oracle'] as Map<String, dynamic>;
    final outer = oracle['outer_contour'] as Map<String, dynamic>;
    final hole = oracle['hole_contour'] as Map<String, dynamic>;
    final tolerance =
        (root['gcode_serialization_tolerance_mm'] as num).toDouble();
    final contour = _rect(0, 0, 2000000, 2000000);
    final holePolygon = _clockwiseRect(500000, 500000, 1500000, 1500000);
    final loops = <ExtrusionEntityCollection2>[];
    final fillSurfaces = <Surface2>[];
    final fillNoOverlap = <SourceExPolygon2>[];

    final result = SourceArachneProcessPipeline2.processSurface(
      surface: Surface2(
        expolygon: SourceExPolygon2(
          contour: contour,
          holes: [holePolygon],
        ),
      ),
      settings: _settings(),
      layerIndex: 1,
      random: _NoRandom(),
      loops: loops,
      fillSurfaces: fillSurfaces,
      fillNoOverlap: fillNoOverlap,
    );

    expect(result.surfaceResult.totalPerimeters, hasLength(2));
    expect(result.extrusionCollection.entities, hasLength(4));
    expect(
      result.extrusionCollection.entities.every((entity) => entity is ExtrusionLoop2),
      isTrue,
    );

    _expectRoleSpans(
      result.extrusionCollection.entities,
      ExtrusionRole.perimeter,
      [
        (outer['inner_wall_bbox_width_mm'] as num).toDouble(),
        (hole['inner_wall_bbox_width_mm'] as num).toDouble(),
      ],
      tolerance,
    );
    _expectRoleSpans(
      result.extrusionCollection.entities,
      ExtrusionRole.externalPerimeter,
      [
        (outer['outer_wall_bbox_width_mm'] as num).toDouble(),
        (hole['outer_wall_bbox_width_mm'] as num).toDouble(),
      ],
      tolerance,
    );

    final expectedWidth = (oracle['line_width_mm'] as num).toDouble();
    for (final entity in result.extrusionCollection.entities) {
      final loop = entity as ExtrusionLoop2;
      for (final path in loop.paths) {
        expect(path.width, closeTo(expectedWidth, 0.00002));
      }
    }

    expect(loops, hasLength(1));
    expect(fillSurfaces, isNotEmpty);
    expect(fillNoOverlap, isNotEmpty);
  });
}
