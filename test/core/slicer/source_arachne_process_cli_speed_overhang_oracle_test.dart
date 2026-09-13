import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_top_one_wall_context.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_wall_sequence.dart';
import 'package:qidi_flow_flutter/core/slicer/extrusion_entity.dart';
import 'package:qidi_flow_flutter/core/slicer/flow.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_overhang_speed.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_process_planning.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_process_surface.dart';
import 'package:qidi_flow_flutter/core/slicer/surface.dart';

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

SourceArachneSurfaceProcessSettings2 _surfaceSettings() {
  const spacing = 35707;
  final upper = _rect(500000, 0, 2500000, 2000000);
  final rawLower = _rect(0, 0, 2000000, 2000000);
  return SourceArachneSurfaceProcessSettings2(
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
  );
}

List<SourcePoint2> _points(List<dynamic> encoded) => [
      for (final raw in encoded)
        SourcePoint2(
          (raw as List<dynamic>)[0] as int,
          raw[1] as int,
        ),
    ];

List<List<SourcePoint2>> _compiledPaths(Map<String, dynamic> wallOracle) {
  final topY = wallOracle['top_y'] as int;
  final bottomY = wallOracle['bottom_y'] as int;
  final topBoundaries =
      (wallOracle['top_boundaries_x'] as List<dynamic>).cast<int>();
  final bottomBoundaries =
      (wallOracle['bottom_boundaries_x'] as List<dynamic>).cast<int>();
  expect(topBoundaries, hasLength(20));
  expect(bottomBoundaries, hasLength(20));

  return [
    for (var index = 0; index < 19; index++)
      [
        SourcePoint2(topBoundaries[index], topY),
        SourcePoint2(topBoundaries[index + 1], topY),
      ],
    _points(wallOracle['degree_zero_points'] as List<dynamic>),
    for (var index = 0; index < 19; index++)
      [
        SourcePoint2(bottomBoundaries[index], bottomY),
        SourcePoint2(bottomBoundaries[index + 1], bottomY),
      ],
  ];
}

int _pointError(
  SourcePoint2 actual,
  SourcePoint2 expected, {
  required bool reflectY,
  required int ySum,
}) {
  final actualY = reflectY ? ySum - actual.y : actual.y;
  return (actual.x - expected.x).abs() + (actualY - expected.y).abs();
}

void _expectPointListClose(
  List<SourcePoint2> actual,
  List<SourcePoint2> expected, {
  required bool reflectY,
  required int ySum,
  required String reason,
}) {
  expect(actual, hasLength(expected.length), reason: reason);

  // The compiled oracle starts from STL slicing while this Dart fixture starts
  // from the already-sliced source polygon. Keep roles and overhang degrees
  // exact, but compare integer geometry within the pinned source
  // SCALED_EPSILON (EPSILON=1e-4 / SCALING_FACTOR=1e-5 => 10 units).
  final coordinateTolerance = Slic3rUnits.scaledEpsilon.toDouble();
  for (var index = 0; index < expected.length; index++) {
    final actualY = reflectY ? ySum - actual[index].y : actual[index].y;
    expect(
      actual[index].x,
      closeTo(expected[index].x, coordinateTolerance),
      reason: '$reason x[$index]',
    );
    expect(
      actualY,
      closeTo(expected[index].y, coordinateTolerance),
      reason: '$reason y[$index]',
    );
  }
}

void _expectCompiledDetectOverhangDegree(
  List<ExtrusionPath2> actual,
  Map<String, dynamic> wallOracle,
  List<dynamic> degreeOracle,
  ExtrusionRole expectedRole,
) {
  final pathCount = wallOracle['path_count'] as int;
  expect(actual, hasLength(pathCount));
  expect(wallOracle['role'], expectedRole.index);
  expect(degreeOracle, hasLength(pathCount));

  for (var index = 0; index < pathCount; index++) {
    expect(actual[index].role, expectedRole, reason: 'role at path $index');
    expect(
      actual[index].overhangDegree,
      (degreeOracle[index] as num).toDouble(),
      reason: 'degree at path $index',
    );
  }

  final expectedPaths = _compiledPaths(wallOracle);
  final ySum =
      (wallOracle['top_y'] as int) + (wallOracle['bottom_y'] as int);

  // The stepped-solid probe is exactly symmetric in Y. Clipper is permitted
  // to return the closed subject from the opposite horizontal side, and the
  // source immediately re-chains clipped paths for that reason. Normalize one
  // global Y reflection for the whole returned vector, never per-path.
  final directError = _pointError(
    actual.first.polyline.points.first,
    expectedPaths.first.first,
    reflectY: false,
    ySum: ySum,
  );
  final reflectedError = _pointError(
    actual.first.polyline.points.first,
    expectedPaths.first.first,
    reflectY: true,
    ySum: ySum,
  );
  final reflectY = reflectedError < directError;

  for (var index = 0; index < pathCount; index++) {
    _expectPointListClose(
      actual[index].polyline.points,
      expectedPaths[index],
      reflectY: reflectY,
      ySum: ySum,
      reason: 'compiled graded path $index',
    );
  }
}

void main() {
  test('compiled pinned BambuStudio matches process Arachne degree paths', () {
    final root = _oracleRoot();
    final debuggerOracle = root['debugger_oracle'] as Map<String, dynamic>;
    final degrees = debuggerOracle['degrees'] as List<dynamic>;
    final innerOracle =
        debuggerOracle['inner_wall'] as Map<String, dynamic>;
    final outerOracle =
        debuggerOracle['outer_wall'] as Map<String, dynamic>;

    final surfaceResult = SourceArachneProcessSurface2.process(
      surface: Surface2(
        expolygon: SourceExPolygon2(
          contour: _rect(500000, 0, 2500000, 2000000),
        ),
      ),
      settings: _surfaceSettings(),
      layerIndex: 1,
    );

    final generated = [
      for (final inset in surfaceResult.totalPerimeters)
        for (final extrusion in inset)
          if (extrusion.isNotEmpty) extrusion,
    ];
    final inner = generated.singleWhere((line) => line.insetIndex == 1);
    final outer = generated.singleWhere((line) => line.insetIndex == 0);
    final grownLower = _rect(-20000, -20000, 2020000, 2020000);
    final flow = _flow(0.4);

    final innerPaths = SourceArachneOverhangSpeed2.gradeSupported(
      extrusion: inner,
      lowerLayerPolygons: [grownLower],
      nozzleDiameterMm: 0.4,
      role: ExtrusionRole.perimeter,
      flow: flow,
    );
    final outerPaths = SourceArachneOverhangSpeed2.gradeSupported(
      extrusion: outer,
      lowerLayerPolygons: [grownLower],
      nozzleDiameterMm: 0.4,
      role: ExtrusionRole.externalPerimeter,
      flow: flow,
    );

    _expectCompiledDetectOverhangDegree(
      innerPaths,
      innerOracle,
      degrees,
      ExtrusionRole.perimeter,
    );
    _expectCompiledDetectOverhangDegree(
      outerPaths,
      outerOracle,
      degrees,
      ExtrusionRole.externalPerimeter,
    );
  });
}
