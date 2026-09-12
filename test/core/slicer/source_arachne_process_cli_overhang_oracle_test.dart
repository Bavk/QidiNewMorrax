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

Flow _flow(double width) => Flow.nonBridging(
      width: width,
      height: 0.2,
      nozzleDiameter: 0.4,
    );

Map<String, dynamic> _oracleRoot() =>
    jsonDecode(
      File(
        'test/fixtures/source_arachne_process_bambustudio_f2b55a5a.json',
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
      enableOverhangSpeed: false,
      outerWallLineWidthMm: 0,
    ),
    externalMixedSpacingSource: spacing,
    solidInfillSpacingSource: spacing,
    infillWallOverlap: const SourceFloatOrPercent2.percent(15),
  );
}

(double, double, double, double) _boundsMm(Iterable<SourcePoint2> points) {
  final values = points.toList(growable: false);
  if (values.isEmpty) throw StateError('oracle path has no points');
  var minX = values.first.x;
  var maxX = values.first.x;
  var minY = values.first.y;
  var maxY = values.first.y;
  for (final point in values.skip(1)) {
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

List<ExtrusionRole> _compressedRoles(ExtrusionLoop2 loop) {
  final roles = <ExtrusionRole>[];
  for (final path in loop.paths) {
    if (roles.isEmpty || roles.last != path.role) roles.add(path.role);
  }
  return roles;
}

Iterable<SourcePoint2> _pointsForRole(
  ExtrusionLoop2 loop,
  ExtrusionRole role,
) sync* {
  for (final path in loop.paths) {
    if (path.role == role) yield* path.polyline.points;
  }
}

void _expectWallBounds(
  ExtrusionLoop2 loop,
  Map<String, dynamic> oracle,
  double tolerance,
) {
  final bounds = _boundsMm(loop.paths.expand((path) => path.polyline.points));
  expect(
    bounds.$2 - bounds.$1,
    closeTo((oracle['bbox_width_mm'] as num).toDouble(), tolerance),
  );
  expect(
    bounds.$4 - bounds.$3,
    closeTo((oracle['bbox_height_mm'] as num).toDouble(), tolerance),
  );
}

void main() {
  test('pinned BambuStudio CLI matches non-speed Arachne overhang split', () {
    final root = _oracleRoot();
    final oracle = (root['oracles'] as Map<String, dynamic>)[
        'non_speed_overhang'] as Map<String, dynamic>;
    final tolerance =
        (root['gcode_serialization_tolerance_mm'] as num).toDouble();
    final loops = <ExtrusionEntityCollection2>[];
    final fillSurfaces = <Surface2>[];
    final fillNoOverlap = <SourceExPolygon2>[];
    final surface = Surface2(
      expolygon: SourceExPolygon2(
        contour: _rect(500000, 0, 2500000, 2000000),
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

    expect(result.extrusionCollection.entities, hasLength(2));
    final inner = result.extrusionCollection.entities[0] as ExtrusionLoop2;
    final outer = result.extrusionCollection.entities[1] as ExtrusionLoop2;

    expect(
      _compressedRoles(inner),
      [
        ExtrusionRole.perimeter,
        ExtrusionRole.overhangPerimeter,
        ExtrusionRole.perimeter,
      ],
    );
    expect(
      _compressedRoles(outer),
      [
        ExtrusionRole.externalPerimeter,
        ExtrusionRole.overhangPerimeter,
        ExtrusionRole.externalPerimeter,
      ],
    );

    final innerOracle = oracle['inner_wall'] as Map<String, dynamic>;
    final outerOracle = oracle['outer_wall'] as Map<String, dynamic>;
    _expectWallBounds(inner, innerOracle, tolerance);
    _expectWallBounds(outer, outerOracle, tolerance);

    final innerOverhang = _boundsMm(
      _pointsForRole(inner, ExtrusionRole.overhangPerimeter),
    );
    final outerOverhang = _boundsMm(
      _pointsForRole(outer, ExtrusionRole.overhangPerimeter),
    );
    final splitX =
        (oracle['grown_lower_support_edge_model_x_mm'] as num).toDouble();
    expect(innerOverhang.$1, closeTo(splitX, tolerance));
    expect(outerOverhang.$1, closeTo(splitX, tolerance));
    expect(
      innerOverhang.$2 - innerOverhang.$1,
      closeTo(
        (innerOracle['overhang_region_width_mm'] as num).toDouble(),
        tolerance,
      ),
    );
    expect(
      outerOverhang.$2 - outerOverhang.$1,
      closeTo(
        (outerOracle['overhang_region_width_mm'] as num).toDouble(),
        tolerance,
      ),
    );
    expect(
      innerOverhang.$4 - innerOverhang.$3,
      closeTo((innerOracle['bbox_height_mm'] as num).toDouble(), tolerance),
    );
    expect(
      outerOverhang.$4 - outerOverhang.$3,
      closeTo((outerOracle['bbox_height_mm'] as num).toDouble(), tolerance),
    );
  });
}
