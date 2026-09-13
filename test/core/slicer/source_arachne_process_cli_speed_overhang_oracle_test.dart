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

  final topY = wallOracle['top_y'] as int;
  final bottomY = wallOracle['bottom_y'] as int;
  final topBoundaries = (wallOracle['top_boundaries_x'] as List<dynamic>)
      .cast<int>();
  final bottomBoundaries =
      (wallOracle['bottom_boundaries_x'] as List<dynamic>).cast<int>();
  expect(topBoundaries, hasLength(20));
  expect(bottomBoundaries, hasLength(20));

  for (var index = 0; index < 19; index++) {
    expect(
      actual[index].polyline.points,
      [
        SourcePoint2(topBoundaries[index], topY),
        SourcePoint2(topBoundaries[index + 1], topY),
      ],
      reason: 'compiled upper grading segment $index',
    );
  }

  expect(
    actual[19].polyline.points,
    _points(wallOracle['degree_zero_points'] as List<dynamic>),
    reason: 'compiled degree-zero supported path',
  );

  for (var pathIndex = 20; pathIndex < 39; pathIndex++) {
    final boundaryIndex = pathIndex - 20;
    expect(
      actual[pathIndex].polyline.points,
      [
        SourcePoint2(bottomBoundaries[boundaryIndex], bottomY),
        SourcePoint2(bottomBoundaries[boundaryIndex + 1], bottomY),
      ],
      reason: 'compiled lower grading segment $pathIndex',
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
          if (!extrusion.isEmpty) extrusion,
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
