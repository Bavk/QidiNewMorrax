import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_top_one_wall_context.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_wall_sequence.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_extrusion_line.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_process_planning.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_process_surface.dart';
import 'package:qidi_flow_flutter/core/slicer/surface.dart';

Map<String, dynamic> _oracleRoot() =>
    jsonDecode(
      File(
        'test/fixtures/source_arachne_wedge_bambustudio_f2b55a5a.json',
      ).readAsStringSync(),
    ) as Map<String, dynamic>;

SourcePolygon2 _modelContour(Map<String, dynamic> root) => SourcePolygon2([
      for (final raw in
          (root['probe'] as Map<String, dynamic>)['model_contour_source']
              as List<dynamic>)
        SourcePoint2(
          (raw as List<dynamic>)[0] as int,
          raw[1] as int,
        ),
    ]);

SourceArachneSurfaceProcessSettings2 _settings() =>
    SourceArachneSurfaceProcessSettings2(
      planning: const SourceArachneProcessPlanningSettings2(
        wallLoops: 2,
        alternateExtraWall: false,
        spiralVase: false,
        preciseOuterWall: false,
        wallSequence: SourceWallSequence2.innerOuter,
        onlyOneWallFirstLayer: false,
        topOneWallType: SourceTopOneWallType2.none,
        upperSlices: <SourcePolygon2>[],
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
    );

List<SourceArachneExtrusionLine2> _generatedLines(
  SourceArachneProcessSurfaceResult2 result,
) => [
      for (final inset in result.totalPerimeters)
        for (final line in inset)
          if (line.isNotEmpty) line,
    ];

List<SourceArachneExtrusionJunction2> _sortedJunctions(
  SourceArachneExtrusionLine2 line,
) {
  final result = [for (final junction in line.junctions) junction];
  result.sort((a, b) {
    var cmp = a.p.x.compareTo(b.p.x);
    if (cmp != 0) return cmp;
    cmp = a.p.y.compareTo(b.p.y);
    if (cmp != 0) return cmp;
    cmp = a.w.compareTo(b.w);
    if (cmp != 0) return cmp;
    return a.perimeterIndex.compareTo(b.perimeterIndex);
  });
  return result;
}

List<List<int>> _sortedExpected(List<dynamic> encoded) {
  final result = [
    for (final raw in encoded)
      [
        (raw as List<dynamic>)[0] as int,
        raw[1] as int,
        raw[2] as int,
        raw[3] as int,
      ],
  ];
  result.sort((a, b) {
    for (var index = 0; index < 4; index++) {
      final cmp = a[index].compareTo(b[index]);
      if (cmp != 0) return cmp;
    }
    return 0;
  });
  return result;
}

SourceArachneExtrusionLine2 _matchLine(
  List<SourceArachneExtrusionLine2> actual,
  Map<String, dynamic> expected,
) {
  final candidates = actual.where(
    (line) =>
        line.insetIndex == expected['inset_idx'] &&
        line.isOdd == expected['odd'] &&
        line.isClosed == expected['closed'] &&
        line.junctions.length ==
            (expected['junctions'] as List<dynamic>).length,
  );
  expect(candidates, hasLength(1));
  return candidates.single;
}

void _expectLine(
  SourceArachneExtrusionLine2 actual,
  Map<String, dynamic> expected,
) {
  expect(actual.insetIndex, expected['inset_idx']);
  expect(actual.isOdd, expected['odd']);
  expect(actual.isClosed, expected['closed']);
  final actualJunctions = _sortedJunctions(actual);
  final expectedJunctions =
      _sortedExpected(expected['junctions'] as List<dynamic>);
  expect(actualJunctions, hasLength(expectedJunctions.length));

  final tolerance = Slic3rUnits.scaledEpsilon.toDouble();
  for (var index = 0; index < expectedJunctions.length; index++) {
    final actualJunction = actualJunctions[index];
    final expectedJunction = expectedJunctions[index];
    expect(
      actualJunction.p.x,
      closeTo(expectedJunction[0], tolerance),
      reason: 'junction $index x',
    );
    expect(
      actualJunction.p.y,
      closeTo(expectedJunction[1], tolerance),
      reason: 'junction $index y',
    );
    expect(
      actualJunction.w,
      closeTo(expectedJunction[2], tolerance),
      reason: 'junction $index width',
    );
    expect(
      actualJunction.perimeterIndex,
      expectedJunction[3],
      reason: 'junction $index perimeter index',
    );
    expect(actualJunction.holeCompensationFlag, isFalse);
  }
}

void main() {
  test('compiled pinned binary matches narrow wedge bead transition', () {
    final root = _oracleRoot();
    final interior = root['interior_layer'] as Map<String, dynamic>;
    final result = SourceArachneProcessSurface2.process(
      surface: Surface2(
        expolygon: SourceExPolygon2(contour: _modelContour(root)),
      ),
      settings: _settings(),
      layerIndex: 1,
    );
    final lines = _generatedLines(result);
    expect(lines, hasLength(interior['line_count'] as int));

    for (final encoded in interior['lines'] as List<dynamic>) {
      final expected = encoded as Map<String, dynamic>;
      _expectLine(_matchLine(lines, expected), expected);
    }

    // This single island must exercise all three structures observed in the
    // exact compiled process: a closed variable-width outer wall, an open odd
    // outer centerline and an open odd inner line.
    expect(
      lines.where((line) => line.isClosed && !line.isOdd && line.insetIndex == 0),
      hasLength(1),
    );
    expect(
      lines.where((line) => !line.isClosed && line.isOdd && line.insetIndex == 0),
      hasLength(1),
    );
    expect(
      lines.where((line) => !line.isClosed && line.isOdd && line.insetIndex == 1),
      hasLength(1),
    );
  });
}
