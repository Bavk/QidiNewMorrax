import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_surface_prepare.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_policy.dart';
import 'package:qidi_flow_flutter/core/slicer/surface.dart';

SourcePolygon2 rectangle(
  double minX,
  double minY,
  double maxX,
  double maxY,
) =>
    SourcePolygon2([
      SourcePoint2.fromMm(minX, minY),
      SourcePoint2.fromMm(maxX, minY),
      SourcePoint2.fromMm(maxX, maxY),
      SourcePoint2.fromMm(minX, maxY),
    ]);

Surface2 boxAt(
  double minX,
  double minY,
  double maxX,
  double maxY, {
  int extraPerimeters = 0,
}) =>
    Surface2(
      expolygon: SourceExPolygon2(
        contour: rectangle(minX, minY, maxX, maxY),
      ),
      extraPerimeters: extraPerimeters,
    );

const baseSettings = SourceClassicSurfacePrepareSettings2(
  resolutionMm: 0.05,
  enableArcFitting: false,
  fuzzySkinType: SourceFuzzySkinType2.none,
  wallLoops: 2,
);

void main() {
  const prepare = SourceClassicSurfacePrepare2();

  test('arc fitting plus fuzzy None uses source 0.2 resolution branch', () {
    final result = prepare.prepare(
      [boxAt(0, 0, 10, 10)],
      const SourceClassicSurfacePrepareSettings2(
        resolutionMm: 0.05,
        enableArcFitting: true,
        fuzzySkinType: SourceFuzzySkinType2.none,
        wallLoops: 2,
      ),
      layerIndex: 0,
    );

    expect(result.baseResolutionSource, closeTo(5000, 1e-9));
    expect(result.surfaceSimplifyResolutionSource, closeTo(1000, 1e-9));
    expect(result.surfaceSimplifyResolutionMm, closeTo(0.01, 1e-12));
  });

  test('non-None fuzzy skin keeps the full scaled resolution', () {
    final result = prepare.prepare(
      [boxAt(0, 0, 10, 10)],
      const SourceClassicSurfacePrepareSettings2(
        resolutionMm: 0.05,
        enableArcFitting: true,
        fuzzySkinType: SourceFuzzySkinType2.external,
        wallLoops: 2,
      ),
      layerIndex: 0,
    );

    expect(result.baseResolutionSource, closeTo(5000, 1e-9));
    expect(result.surfaceSimplifyResolutionSource, closeTo(5000, 1e-9));
  });

  test('zero configured resolution clamps to source EPSILON before 0.2', () {
    final result = prepare.prepare(
      [boxAt(0, 0, 10, 10)],
      const SourceClassicSurfacePrepareSettings2(
        resolutionMm: 0,
        enableArcFitting: true,
        fuzzySkinType: SourceFuzzySkinType2.none,
        wallLoops: 2,
      ),
      layerIndex: 0,
    );

    expect(result.baseResolutionSource, closeTo(10, 1e-12));
    expect(result.surfaceSimplifyResolutionSource, closeTo(2, 1e-12));
  });

  test('chain_expolygons uses bbox centers and source multi-fragment order', () {
    final result = prepare.prepare(
      [
        boxAt(-1, -1, 1, 1), // center x = 0
        boxAt(29, -1, 31, 1), // center x = 30
        boxAt(9, -1, 11, 1), // center x = 10
      ],
      baseSettings,
      layerIndex: 0,
    );

    // Pinned chain_points() builds the shortest 0-10-30 fragment and, without
    // start_near, walks it from the free endpoint at x=30.
    expect(result.surfaceOrder, [1, 2, 0]);
    expect(
      [for (final item in result.prepared) item.sourceIndex],
      [1, 2, 0],
    );
  });

  test('surface extra_perimeters and alternate-extra-wall precede one-wall gates', () {
    final even = prepare.prepare(
      [boxAt(0, 0, 30, 30, extraPerimeters: 2)],
      const SourceClassicSurfacePrepareSettings2(
        resolutionMm: 0.01,
        enableArcFitting: false,
        fuzzySkinType: SourceFuzzySkinType2.none,
        wallLoops: 1,
        alternateExtraWall: true,
      ),
      layerIndex: 2,
    );
    final odd = prepare.prepare(
      [boxAt(0, 0, 30, 30, extraPerimeters: 2)],
      const SourceClassicSurfacePrepareSettings2(
        resolutionMm: 0.01,
        enableArcFitting: false,
        fuzzySkinType: SourceFuzzySkinType2.none,
        wallLoops: 1,
        alternateExtraWall: true,
      ),
      layerIndex: 3,
    );
    final oddSpiral = prepare.prepare(
      [boxAt(0, 0, 30, 30, extraPerimeters: 2)],
      const SourceClassicSurfacePrepareSettings2(
        resolutionMm: 0.01,
        enableArcFitting: false,
        fuzzySkinType: SourceFuzzySkinType2.none,
        wallLoops: 1,
        alternateExtraWall: true,
        spiralVase: true,
      ),
      layerIndex: 3,
    );

    expect(even.prepared.single.loopNumber, 2);
    expect(odd.prepared.single.loopNumber, 3);
    expect(oddSpiral.prepared.single.loopNumber, 2);
  });

  test('circle-compensation metadata uses pre-simplified source hole centroids', () {
    final hole = rectangle(4, 4, 6, 6).reversed();
    final surface = Surface2(
      expolygon: SourceExPolygon2(
        contour: rectangle(0, 0, 10, 10),
        holes: [hole],
      ),
      counterCircleCompensation: true,
      holesCircleCompensation: const [0],
    );

    final result = prepare.prepare(
      [surface],
      baseSettings,
      layerIndex: 0,
    );
    final item = result.prepared.single;

    expect(item.counterCircleCompensation, isTrue);
    expect(item.compensationHoleCenters, hasLength(1));
    expect(
      item.compensationHoleCenters.single,
      SourcePoint2.fromMm(5, 5),
    );
    expect(item.isCompensationHole(hole), isTrue);
    expect(item.isCompensationHole(rectangle(7, 7, 8, 8).reversed()), isFalse);
    expect(item.simplified, hasLength(1));
  });
}
