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
  double nextUnit() => throw StateError('identity circle-copy oracle consumed RNG');
}

SourcePolygon2 _square(int min, int max, {bool clockwise = false}) {
  final points = <SourcePoint2>[
    SourcePoint2(min, min),
    SourcePoint2(max, min),
    SourcePoint2(max, max),
    SourcePoint2(min, max),
  ];
  return SourcePolygon2(clockwise ? points.reversed.toList() : points);
}

Flow _flow(double width) => Flow.nonBridging(
      width: width,
      height: 0.2,
      nozzleDiameter: 0.4,
    );

SourceArachneProcessPipelineSettings2 _settings() {
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
        topOneWallType: SourceTopOneWallType2.none,
        upperSlices: const <SourcePolygon2>[],
        extPerimeterWidth: 40000,
        extPerimeterSpacing: 35707,
        minNozzleDiameterMm: 0.4,
        minBeadWidthPercent: 85,
        minFeatureSizePercent: 25,
        wallTransitionLengthPercent: 100,
        wallTransitionAngleDeg: 10,
        wallTransitionFilterDeviationPercent: 25,
        wallDistributionCount: 1,
      ),
      surfaceSimplifyResolutionSource: 1000,
      perimeterSpacing: 35707,
      perimeterWidth: 40000,
      layerHeightMm: 0.2,
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
      detectOverhangWall: false,
      outerWallLineWidthMm: 0.4,
    ),
    externalMixedSpacingSource: 35707,
    solidInfillSpacingSource: 35707,
    infillWallOverlap: const SourceFloatOrPercent2.percent(15),
  );
}

Map<String, dynamic> _oracle() =>
    jsonDecode(
      File(
        'test/fixtures/source_arachne_circle_compensation_bambustudio_f2b55a5a.json',
      ).readAsStringSync(),
    ) as Map<String, dynamic>;

void main() {
  test('compiled process resets contour/hole circle flags at Surface copy', () {
    final compiled = _oracle();
    final interior = compiled['interior_layer'] as Map<String, dynamic>;
    final calls = interior['calls'] as List<dynamic>;
    expect(calls, hasLength(4));
    expect(
      calls.every(
        (call) =>
            (call as Map<String, dynamic>)['should_apply_hole_compensation'] ==
            false,
      ),
      isTrue,
    );
    expect(
      calls.every(
        (call) => (call as Map<String, dynamic>)['marked_junctions'] == 0,
      ),
      isTrue,
    );

    final surface = Surface2(
      expolygon: SourceExPolygon2(
        contour: _square(0, 2000000),
        holes: [_square(500000, 1500000, clockwise: true)],
      ),
      counterCircleCompensation: true,
      holesCircleCompensation: const [0],
    );
    final loops = <ExtrusionEntityCollection2>[];
    final fillSurfaces = <Surface2>[];
    final fillNoOverlap = <SourceExPolygon2>[];

    final result = SourceArachneProcessPipeline2.processSurface(
      surface: surface,
      settings: _settings(),
      layerIndex: 1,
      random: _NoRandom(),
      loops: loops,
      fillSurfaces: fillSurfaces,
      fillNoOverlap: fillNoOverlap,
    );

    // Direct lower-level wall generation can consume these QIDI members, but
    // pinned process_arachne first copies Surface and the source copy ctor omits
    // both fields. The compiled ring probe independently reaches the same zero
    // marked-junction / false shouldApplyHoleCompensation state.
    expect(result.surfaceResult.applyCircleCompensation, isTrue);
    expect(result.surfaceResult.circlePolygonIndices, isEmpty);
    expect(result.extrusionCollection.entities, isNotEmpty);
    for (final entity in result.extrusionCollection.entities) {
      expect(entity.customizeFlag, CustomizeFlag.none);
      if (entity case ExtrusionLoop2 loop) {
        for (final path in loop.paths) {
          expect(path.customizeFlag, CustomizeFlag.none);
        }
      }
    }
  });

  test('compiled probe confirms compensation changes geometry before copy', () {
    final compiled = _oracle();
    final interior = compiled['interior_layer'] as Map<String, dynamic>;
    final enabled = interior['enabled_centerline_abs_max_x_source']
        as Map<String, dynamic>;
    final disabled = interior['disabled_centerline_abs_max_x_source']
        as Map<String, dynamic>;

    // Guard against a vacuous zero-flag oracle: the exact upstream binary did
    // execute auto circle compensation. The four centerline radii all changed
    // when only enable_circle_compensation was toggled.
    for (final key in enabled.keys) {
      expect(enabled[key], isNot(disabled[key]), reason: key);
    }
  });
}
