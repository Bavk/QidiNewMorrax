import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_top_one_wall_context.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_wall_sequence.dart';
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

SourcePolygon2 _square(int min, int max) => _rect(min, min, max, max);

SourcePolygon2 _clockwiseHole(int min, int max) => SourcePolygon2([
      SourcePoint2(min, min),
      SourcePoint2(min, max),
      SourcePoint2(max, max),
      SourcePoint2(max, min),
    ]);

Surface2 _surface({
  int size = 1000000,
  int extraPerimeters = 0,
  bool counterCompensation = false,
  List<int> holeFlags = const [],
  bool withHole = false,
}) =>
    Surface2(
      expolygon: SourceExPolygon2(
        contour: _square(0, size),
        holes: withHole
            ? <SourcePolygon2>[_clockwiseHole(size ~/ 3, size * 2 ~/ 3)]
            : const <SourcePolygon2>[],
      ),
      extraPerimeters: extraPerimeters,
      counterCircleCompensation: counterCompensation,
      holesCircleCompensation: holeFlags,
    );

SourceArachneProcessPlanningSettings2 _planning({
  int wallLoops = 2,
  SourceTopOneWallType2 topType = SourceTopOneWallType2.none,
  List<SourcePolygon2>? upperSlices = const <SourcePolygon2>[],
  int extWidth = 40000,
  int extSpacing = 40000,
}) =>
    SourceArachneProcessPlanningSettings2(
      wallLoops: wallLoops,
      alternateExtraWall: false,
      spiralVase: false,
      preciseOuterWall: false,
      wallSequence: SourceWallSequence2.innerOuter,
      onlyOneWallFirstLayer: false,
      topOneWallType: topType,
      upperSlices: upperSlices,
      extPerimeterWidth: extWidth,
      extPerimeterSpacing: extSpacing,
      minNozzleDiameterMm: 0.4,
      minBeadWidthPercent: 50,
      minFeatureSizePercent: 25,
      wallTransitionLengthPercent: 100,
      wallTransitionAngleDeg: 10,
      wallTransitionFilterDeviationPercent: 10,
      wallDistributionCount: 3,
    );

SourceArachneSurfaceProcessSettings2 _settings({
  SourceArachneProcessPlanningSettings2? planning,
  int? perimeterWidth,
  double topAreaThresholdPercent = 0,
  List<SourcePolygon2>? lowerSlices,
}) =>
    SourceArachneSurfaceProcessSettings2(
      planning: planning ?? _planning(),
      surfaceSimplifyResolutionSource: 1,
      perimeterSpacing: 40000,
      layerHeightMm: 0.2,
      perimeterWidth: perimeterWidth,
      topAreaThresholdPercent: topAreaThresholdPercent,
      lowerSlices: lowerSlices,
    );

void main() {
  test('normal square reaches real WallToolPaths with two requested walls', () {
    final result = SourceArachneProcessSurface2.process(
      surface: _surface(),
      settings: _settings(),
      layerIndex: 2,
    );

    expect(result.plan.loopNumber, 1);
    expect(result.plan.initialInsetCount, 2);
    expect(result.wallToolPaths, isNotNull);
    expect(result.wallToolPaths!.toolpathsGenerated, isTrue);
    expect(result.totalPerimeters, isNotEmpty);
    expect(result.infillContour, isNotEmpty);
    expect(result.applyCircleCompensation, isTrue);
    expect(result.circlePolygonIndices, isEmpty);
  });

  test('topmost null upper slices uses one-wall WallToolPaths branch', () {
    final result = SourceArachneProcessSurface2.process(
      surface: _surface(),
      settings: _settings(
        planning: _planning(
          wallLoops: 3,
          topType: SourceTopOneWallType2.topmost,
          upperSlices: null,
        ),
      ),
      layerIndex: 3,
    );

    expect(result.plan.loopNumber, 2);
    expect(result.plan.isOneWall, isTrue);
    expect(result.plan.initialInsetCount, 1);
    expect(result.totalPerimeters, isNotEmpty);
    for (final inset in result.totalPerimeters) {
      for (final line in inset) {
        expect(line.insetIndex, 0);
      }
    }
  });

  test('zero configured walls preserves offset island as infill contour', () {
    final result = SourceArachneProcessSurface2.process(
      surface: _surface(),
      settings: _settings(planning: _planning(wallLoops: 0)),
      layerIndex: 2,
    );

    expect(result.plan.loopNumber, -1);
    expect(result.wallToolPaths, isNull);
    expect(result.totalPerimeters, isEmpty);
    expect(result.infillContour, result.lastPolygons);
  });

  test('unchanged contour plus hole maps QIDI compensation flags to 0/1', () {
    final result = SourceArachneProcessSurface2.process(
      surface: _surface(
        withHole: true,
        counterCompensation: true,
        holeFlags: const [0],
      ),
      settings: _settings(),
      layerIndex: 2,
    );

    expect(result.applyCircleCompensation, isTrue);
    expect(result.wallInputPolygons, hasLength(2));
    expect(result.wallInputPolygons.first.isClockwise, isFalse);
    expect(result.wallInputPolygons.last.isClockwise, isTrue);
    expect(result.circlePolygonIndices, [0, 1]);
    expect(
      result.wallToolPaths!.prepared!.applyHoleCompensation,
      isTrue,
    );
  });

  test('topology loss disables circle-compensation flags before wall generation', () {
    final result = SourceArachneProcessSurface2.process(
      surface: _surface(
        size: 10000,
        counterCompensation: true,
      ),
      settings: _settings(
        planning: _planning(
          wallLoops: 0,
          extWidth: 100000,
          extSpacing: 0,
        ),
      ),
      layerIndex: 2,
    );

    expect(result.lastPolygons, isEmpty);
    expect(result.applyCircleCompensation, isFalse);
    expect(result.circlePolygonIndices, isEmpty);
  });

  test('Alltop full supported top keeps only first wall around top area', () {
    final full = _square(0, 1000000);
    final result = SourceArachneProcessSurface2.process(
      surface: _surface(),
      settings: _settings(
        planning: _planning(
          wallLoops: 3,
          topType: SourceTopOneWallType2.allTop,
          upperSlices: const <SourcePolygon2>[],
        ),
        perimeterWidth: 40000,
        lowerSlices: [full],
      ),
      layerIndex: 2,
    );

    expect(result.topOneWallEnabled, isTrue);
    expect(result.topOneWallPolygons, isNotEmpty);
    expect(result.wallToolPaths, isNotNull);
    expect(result.totalPerimeters, isNotEmpty);
    expect(
      result.totalPerimeters
          .expand((inset) => inset)
          .every((line) => line.insetIndex == 0),
      isTrue,
    );
  });

  test('Alltop partial top runs remaining walls and shifts line inset only', () {
    final full = _square(0, 1000000);
    final upperRight = _rect(450000, 0, 1000000, 1000000);
    final result = SourceArachneProcessSurface2.process(
      surface: _surface(),
      settings: _settings(
        planning: _planning(
          wallLoops: 3,
          topType: SourceTopOneWallType2.allTop,
          upperSlices: [upperRight],
        ),
        perimeterWidth: 40000,
        lowerSlices: [full],
      ),
      layerIndex: 2,
    );

    expect(result.topOneWallEnabled, isTrue);
    expect(result.remainingWallToolPaths, isNotNull);
    final shifted = result.totalPerimeters
        .expand((inset) => inset)
        .where((line) => line.insetIndex > 0)
        .toList();
    expect(shifted, isNotEmpty);
    // Pinned source increments `ExtrusionLine::inset_idx` only. Junction
    // perimeter indexes stay in the second WallToolPaths local index domain.
    expect(
      shifted.any(
        (line) => line.insetIndex == 1 &&
            line.junctions.any((junction) => junction.perimeterIndex == 0),
      ),
      isTrue,
    );
    expect(result.infillContour, isNotEmpty);
  });

  test('Alltop without lower support disables feature and reruns normal walls', () {
    final result = SourceArachneProcessSurface2.process(
      surface: _surface(),
      settings: _settings(
        planning: _planning(
          wallLoops: 3,
          topType: SourceTopOneWallType2.allTop,
          upperSlices: const <SourcePolygon2>[],
        ),
        perimeterWidth: 40000,
        lowerSlices: const <SourcePolygon2>[],
      ),
      layerIndex: 2,
    );

    expect(result.topOneWallEnabled, isFalse);
    expect(result.topOneWallPolygons, isEmpty);
    expect(result.remainingWallToolPaths, isNull);
    expect(result.wallToolPaths, isNotNull);
    expect(result.wallToolPaths!.toolpathsGenerated, isTrue);
    expect(
      result.totalPerimeters
          .expand((inset) => inset)
          .map((line) => line.insetIndex)
          .toSet()
          .length,
      greaterThan(1),
    );
  });
}
