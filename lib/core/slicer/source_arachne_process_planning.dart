import 'dart:typed_data';

import '../geometry/source_polygon.dart';
import 'classic_top_one_wall_context.dart';
import 'classic_wall_sequence.dart';
import 'source_arachne_wall_tool_paths.dart';

class SourceArachneProcessPlanningSettings2 {
  const SourceArachneProcessPlanningSettings2({
    required this.wallLoops,
    required this.alternateExtraWall,
    required this.spiralVase,
    required this.preciseOuterWall,
    required this.wallSequence,
    required this.onlyOneWallFirstLayer,
    required this.topOneWallType,
    required this.upperSlices,
    required this.extPerimeterWidth,
    required this.extPerimeterSpacing,
    required this.minNozzleDiameterMm,
    required this.minBeadWidthPercent,
    required this.minFeatureSizePercent,
    required this.wallTransitionLengthPercent,
    required this.wallTransitionAngleDeg,
    required this.wallTransitionFilterDeviationPercent,
    required this.wallDistributionCount,
  });

  final int wallLoops;
  final bool alternateExtraWall;
  final bool spiralVase;
  final bool preciseOuterWall;
  final SourceWallSequence2 wallSequence;
  final bool onlyOneWallFirstLayer;
  final SourceTopOneWallType2 topOneWallType;

  /// Nullability is source-significant: nullptr means top-most layer, while a
  /// non-null empty list is an Alltop candidate with no upper coverage.
  final List<SourcePolygon2>? upperSlices;

  final int extPerimeterWidth;
  final int extPerimeterSpacing;

  final double minNozzleDiameterMm;
  final double minBeadWidthPercent;
  final double minFeatureSizePercent;
  final double wallTransitionLengthPercent;
  final double wallTransitionAngleDeg;
  final double wallTransitionFilterDeviationPercent;
  final int wallDistributionCount;
}

class SourceArachneSurfaceWallPlan2 {
  const SourceArachneSurfaceWallPlan2({
    required this.loopNumber,
    required this.applyPreciseOuterWall,
    required this.outerOffsetDelta,
    required this.wall0Inset,
    required this.generateOneWallByFirstLayer,
    required this.generateOneWallByTopMost,
    required this.generateOneWallByTop,
    required this.isOneWall,
    required this.separateWallGenerationCandidate,
    required this.initialInsetCount,
    required this.params,
  });

  /// 0-indexed source wall-loop count; -1 means no generated walls.
  final int loopNumber;
  final bool applyPreciseOuterWall;

  /// Source-unit offset delta after the literal `float(...)` cast in
  /// `process_arachne()`.
  final double outerOffsetDelta;

  /// Source `coord_t` value passed into `WallToolPaths`.
  final int wall0Inset;

  final bool generateOneWallByFirstLayer;
  final bool generateOneWallByTopMost;
  final bool generateOneWallByTop;
  final bool isOneWall;
  final bool separateWallGenerationCandidate;

  /// Count used by the first `WallToolPaths` invocation. Null means source
  /// takes the `loop_number < 0` branch and does not construct WallToolPaths.
  final int? initialInsetCount;

  final SourceArachneWallToolPathsParams2 params;
}

/// First high-level source slice of `PerimeterGenerator::process_arachne()`:
/// per-surface wall count, precise-outer-wall numeric boundary, one-wall gates,
/// and `WallToolPathsParams` construction.
class SourceArachneProcessPlanning2 {
  const SourceArachneProcessPlanning2._();

  static SourceArachneSurfaceWallPlan2 planSurface({
    required SourceArachneProcessPlanningSettings2 settings,
    required int extraPerimeters,
    required int layerIndex,
  }) {
    var loopNumber = settings.wallLoops + extraPerimeters - 1;
    if (settings.alternateExtraWall &&
        layerIndex.isOdd &&
        !settings.spiralVase) {
      loopNumber++;
    }

    final applyPreciseOuterWall = settings.preciseOuterWall &&
        settings.wallSequence == SourceWallSequence2.innerOuter;

    final offsetMagnitude = applyPreciseOuterWall
        ? settings.extPerimeterWidth - settings.extPerimeterSpacing
        : settings.extPerimeterWidth / 2.0 -
            settings.extPerimeterSpacing / 2.0;
    final outerOffsetDelta = -_f32(offsetMagnitude.toDouble());

    // Pinned source uses integer `/ 2` here (not `/ 2.`), so odd coord_t values
    // are truncated independently before subtraction.
    final wall0Inset = applyPreciseOuterWall
        ? -((settings.extPerimeterWidth ~/ 2) -
            (settings.extPerimeterSpacing ~/ 2))
        : 0;

    final hasWallGeneration = loopNumber >= 0;
    final generateOneWallByFirstLayer = hasWallGeneration &&
        settings.onlyOneWallFirstLayer &&
        layerIndex == 0;
    final generateOneWallByTopMost = hasWallGeneration &&
        settings.topOneWallType != SourceTopOneWallType2.none &&
        settings.upperSlices == null;
    final generateOneWallByTop = hasWallGeneration &&
        settings.topOneWallType == SourceTopOneWallType2.allTop &&
        settings.upperSlices != null;

    final isOneWall = hasWallGeneration &&
        (loopNumber == 0 ||
            generateOneWallByFirstLayer ||
            generateOneWallByTopMost);
    final separateWallGenerationCandidate =
        hasWallGeneration && !isOneWall && generateOneWallByTop;

    final initialInsetCount = !hasWallGeneration
        ? null
        : (separateWallGenerationCandidate
            ? 1
            : (isOneWall ? 1 : loopNumber + 1));

    final params = SourceArachneWallToolPathsParams2.fromProcessConfig(
      minNozzleDiameterMm: settings.minNozzleDiameterMm,
      minBeadWidthPercent: settings.minBeadWidthPercent,
      minFeatureSizePercent: settings.minFeatureSizePercent,
      wallTransitionLengthPercent: settings.wallTransitionLengthPercent,
      wallTransitionAngleDeg: settings.wallTransitionAngleDeg,
      wallTransitionFilterDeviationPercent:
          settings.wallTransitionFilterDeviationPercent,
      wallDistributionCount: settings.wallDistributionCount,
    );

    return SourceArachneSurfaceWallPlan2(
      loopNumber: loopNumber,
      applyPreciseOuterWall: applyPreciseOuterWall,
      outerOffsetDelta: outerOffsetDelta,
      wall0Inset: wall0Inset,
      generateOneWallByFirstLayer: generateOneWallByFirstLayer,
      generateOneWallByTopMost: generateOneWallByTopMost,
      generateOneWallByTop: generateOneWallByTop,
      isOneWall: isOneWall,
      separateWallGenerationCandidate: separateWallGenerationCandidate,
      initialInsetCount: initialInsetCount,
      params: params,
    );
  }

  static double _f32(double value) {
    final slot = Float32List(1)..[0] = value;
    return slot[0];
  }
}
