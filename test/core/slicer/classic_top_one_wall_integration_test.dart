import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/expolygon.dart';
import 'package:qidi_flow_flutter/core/geometry/point.dart';
import 'package:qidi_flow_flutter/core/geometry/polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_top_one_wall_context.dart';
import 'package:qidi_flow_flutter/core/slicer/flow.dart';

Polygon2 rectangle(double minX, double minY, double maxX, double maxY) =>
    Polygon2([
      Point2(minX, minY),
      Point2(maxX, minY),
      Point2(maxX, maxY),
      Point2(minX, maxY),
    ]);

ExPolygon2 box(double size) => ExPolygon2(contour: rectangle(0, 0, size, size));

void expectBounds(
  ExPolygon2 value,
  double minX,
  double minY,
  double maxX,
  double maxY,
) {
  final bounds = value.contour.bounds;
  expect(bounds.min.x, closeTo(minX, 2e-5));
  expect(bounds.min.y, closeTo(minY, 2e-5));
  expect(bounds.max.x, closeTo(maxX, 2e-5));
  expect(bounds.max.y, closeTo(maxY, 2e-5));
}

const baseSettings = ClassicPerimeterSettings(
  wallLoops: 3,
  externalPerimeterWidth: 0.4,
  externalPerimeterSpacing: 0.4,
  perimeterWidth: 0.4,
  perimeterSpacing: 0.4,
);

void main() {
  const generator = ClassicPerimeterShellGenerator();

  test('TopOneWallType enum preserves pinned source order', () {
    expect(
      SourceTopOneWallType2.values,
      const [
        SourceTopOneWallType2.none,
        SourceTopOneWallType2.allTop,
        SourceTopOneWallType2.topmost,
      ],
    );
  });

  test('null upper_slices forces one wall before shell generation', () {
    final result = generator.generate(
      [box(20)],
      baseSettings,
      layerIndex: 2,
      topOneWall: const SourceClassicTopOneWallContext2(
        type: SourceTopOneWallType2.topmost,
        upperSlices: null,
      ),
    );

    expect(result.effectiveLoopCount, 1);
    expect(result.loops, hasLength(1));
    expect(result.loops.single.depth, 0);
    expect(result.innerRegion, hasLength(1));
    expectBounds(result.innerRegion.single, 0.2, 0.2, 19.8, 19.8);
    expect(result.topFillApplied, isFalse);
    expect(result.topFills, isEmpty);
    expect(result.fillClip, isEmpty);
  });

  test('only_one_wall_first_layer changes layer zero but not layer one', () {
    final context = SourceClassicTopOneWallContext2(
      type: SourceTopOneWallType2.none,
      onlyOneWallFirstLayer: true,
      upperSlices: [rectangle(0, 0, 20, 20)],
    );

    final first = generator.generate(
      [box(20)],
      baseSettings,
      layerIndex: 0,
      topOneWall: context,
    );
    final second = generator.generate(
      [box(20)],
      baseSettings,
      layerIndex: 1,
      topOneWall: context,
    );

    expect(first.effectiveLoopCount, 1);
    expect(first.loops, hasLength(1));
    expect(second.effectiveLoopCount, 3);
    expect(second.loops, hasLength(3));
  });

  test('non-null empty upper slices run Alltop inside first shell iteration', () {
    final result = generator.generate(
      [box(20)],
      const ClassicPerimeterSettings(
        wallLoops: 2,
        externalPerimeterWidth: 0.4,
        externalPerimeterSpacing: 0.4,
        perimeterWidth: 0.4,
        perimeterSpacing: 0.4,
      ),
      layerIndex: 3,
      topOneWall: const SourceClassicTopOneWallContext2(
        type: SourceTopOneWallType2.allTop,
        upperSlices: [],
        sparseInfillLineWidthMm: 0.4,
      ),
    );

    // Source first emits the external wall, then Alltop replaces `last` with
    // the non-top region. With no upper coverage that region is empty, so the
    // following i=1 iteration collapses and reduces loop_number to zero.
    expect(result.effectiveLoopCount, 1);
    expect(result.loops, hasLength(1));
    expect(result.topFillApplied, isTrue);
    expect(result.innerRegion, isEmpty);
    expect(result.topFills, hasLength(1));
    expectBounds(result.topFills.single, 0.6, 0.6, 19.4, 19.4);
    expect(result.fillClip, hasLength(1));
    expectBounds(result.fillClip.single, 0.2, 0.2, 19.8, 19.8);
  });

  test('full upper coverage keeps the second wall after Alltop producer', () {
    final result = generator.generate(
      [box(20)],
      const ClassicPerimeterSettings(
        wallLoops: 2,
        externalPerimeterWidth: 0.4,
        externalPerimeterSpacing: 0.4,
        perimeterWidth: 0.4,
        perimeterSpacing: 0.4,
      ),
      layerIndex: 3,
      topOneWall: SourceClassicTopOneWallContext2(
        type: SourceTopOneWallType2.allTop,
        upperSlices: [rectangle(0, 0, 20, 20)],
        sparseInfillLineWidthMm: 0.4,
      ),
    );

    expect(result.topFillApplied, isTrue);
    expect(result.topFills, isEmpty);
    expect(result.effectiveLoopCount, 2);
    expect(result.loops, hasLength(2));
    expect(result.loops[1].depth, 1);
    expect(result.innerRegion, hasLength(1));
    expectBounds(result.innerRegion.single, 0.6, 0.6, 19.4, 19.4);
  });

  test('zero sparse infill density skips source gap-discovery iteration', () {
    final solidFlow = Flow.nonBridging(
      width: 0.4,
      height: 0.2,
      nozzleDiameter: 0.4,
    );
    final result = generator.generate(
      [box(20)],
      ClassicPerimeterSettings(
        wallLoops: 1,
        externalPerimeterWidth: 0.4,
        externalPerimeterSpacing: 0.4,
        perimeterWidth: 0.4,
        perimeterSpacing: 0.4,
        solidInfillFlow: solidFlow,
        hasGapFill: true,
        sparseInfillDensityPercent: 0,
      ),
      layerIndex: 2,
    );

    // Pinned source breaks at i == loop_number here, before the extra i=1
    // iteration that exists only to collect gap-fill candidates.
    expect(result.effectiveLoopCount, 1);
    expect(result.loops, hasLength(1));
    expect(result.innerRegion, hasLength(1));
    expectBounds(result.innerRegion.single, 0.2, 0.2, 19.8, 19.8);
    expect(result.gapFillPolylines, isEmpty);
    expect(result.gapFillExtrusions, isEmpty);
  });
}
