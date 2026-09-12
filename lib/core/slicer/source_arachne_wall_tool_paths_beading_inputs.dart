import 'dart:math' as math;
import 'dart:typed_data';

import 'source_arachne_wall_tool_paths.dart';

/// Exact scalar payload prepared by pinned `WallToolPaths::generate()` before
/// `BeadingStrategyFactory::makeStrategy()` and `SkeletalTrapezoidation`.
///
/// This class deliberately does not implement either dependency. It freezes the
/// mixed float/double/coord_t conversion boundary so later strategy and
/// skeleton ports receive the same values as C++.
class SourceArachneWallToolPathsBeadingInputs2 {
  const SourceArachneWallToolPathsBeadingInputs2({
    required this.externalPerimeterExtrusionWidthMm,
    required this.perimeterExtrusionWidthMm,
    required this.preferredBeadWidthOuter,
    required this.preferredBeadWidthInner,
    required this.preferredTransitionLength,
    required this.transitioningAngleRadians,
    required this.printThinWalls,
    required this.minBeadWidth,
    required this.minFeatureSize,
    required this.wallSplitMiddleThreshold,
    required this.wallAddMiddleThreshold,
    required this.maxBeadCount,
    required this.outerWallOffset,
    required this.inwardDistributedCenterWallCount,
    required this.minimumVariableLineRatio,
    required this.discretizationStepSize,
    required this.transitionFilterDistance,
    required this.allowedFilterDeviation,
  });

  static const int coordMax = 0x7fffffff;
  static const double minimumVariableLineRatioDefault = 0.5;

  final double externalPerimeterExtrusionWidthMm;
  final double perimeterExtrusionWidthMm;

  // `BeadingStrategyFactory::makeStrategy()` arguments.
  final int preferredBeadWidthOuter;
  final int preferredBeadWidthInner;
  final int preferredTransitionLength;
  final double transitioningAngleRadians;
  final bool printThinWalls;
  final int minBeadWidth;
  final int minFeatureSize;
  final double wallSplitMiddleThreshold;
  final double wallAddMiddleThreshold;
  final int maxBeadCount;
  final int outerWallOffset;
  final int inwardDistributedCenterWallCount;
  final double minimumVariableLineRatio;

  // `SkeletalTrapezoidation` scalar arguments prepared in the same source
  // block after factory construction.
  final int discretizationStepSize;
  final int transitionFilterDistance;
  final int allowedFilterDeviation;

  factory SourceArachneWallToolPathsBeadingInputs2.fromState(
    SourceArachneWallToolPathsState2 state,
  ) {
    final layerHeight = _f32(state.layerHeightMm);
    final outerSpacing = _unscaleFloat(state.beadWidth0);
    final innerSpacing = _unscaleFloat(state.beadWidthX);

    final externalWidth = _roundedRectangleWidthFromSpacing(
      outerSpacing,
      layerHeight,
    );
    final perimeterWidth = _roundedRectangleWidthFromSpacing(
      innerSpacing,
      layerHeight,
    );

    final minBeadWidthMm = state.minBeadWidth * 0.00001;
    final splitThreshold = _clamp(
      2.0 * minBeadWidthMm / externalWidth - 1.0,
      0.01,
      0.99,
    );
    final addThreshold = _clamp(
      minBeadWidthMm / perimeterWidth,
      0.01,
      0.99,
    );

    return SourceArachneWallToolPathsBeadingInputs2(
      externalPerimeterExtrusionWidthMm: externalWidth,
      perimeterExtrusionWidthMm: perimeterWidth,
      preferredBeadWidthOuter: state.beadWidth0,
      preferredBeadWidthInner: state.beadWidthX,
      preferredTransitionLength: _scaleFloat(
        state.params.wallTransitionLengthMm,
      ),
      transitioningAngleRadians: _deg2RadFloat(
        state.params.wallTransitionAngleDeg,
      ),
      printThinWalls: state.printThinWalls,
      minBeadWidth: state.minBeadWidth,
      minFeatureSize: state.minFeatureSize,
      wallSplitMiddleThreshold: splitThreshold,
      wallAddMiddleThreshold: addThreshold,
      maxBeadCount: maxBeadCountForInsetCount(state.insetCount),
      outerWallOffset: state.wall0Inset,
      inwardDistributedCenterWallCount: state.params.wallDistributionCount,
      minimumVariableLineRatio: minimumVariableLineRatioDefault,
      discretizationStepSize:
          SourceArachneWallToolPathsPreprocess2.scaleDouble(0.8),
      transitionFilterDistance: _scaleFloat(100.0),
      allowedFilterDeviation: state.wallTransitionFilterDeviation,
    );
  }

  /// Literal source condition:
  /// `inset_count < numeric_limits<coord_t>::max() / 2 ? 2 * inset_count : max`.
  /// Integer division makes the first saturated input 1,073,741,823.
  static int maxBeadCountForInsetCount(int insetCount) {
    final threshold = coordMax ~/ 2;
    return insetCount < threshold ? 2 * insetCount : coordMax;
  }

  static double _unscaleFloat(int value) =>
      _mulF32(_f32(value.toDouble()), _f32(0.00001));

  /// Source signature takes two floats but the expression contains double
  /// constants, so both inputs are promoted for the expression and only the
  /// return is rounded back to float.
  static double _roundedRectangleWidthFromSpacing(
    double spacingFloat,
    double heightFloat,
  ) =>
      _f32(
        spacingFloat + heightFloat * (1.0 - 0.25 * math.pi),
      );

  /// `Geometry::deg2rad<T>` with `T == float` performs every arithmetic step
  /// in float before the result is widened into the source local `double`.
  static double _deg2RadFloat(double degreesFloat) =>
      _divF32(
        _mulF32(_f32(math.pi), _f32(degreesFloat)),
        _f32(180.0),
      );

  static int _scaleFloat(double millimetersFloat) =>
      _divF32(_f32(millimetersFloat), _f32(0.00001)).truncate();

  static double _mulF32(double left, double right) =>
      _f32(_f32(left) * _f32(right));

  static double _divF32(double left, double right) =>
      _f32(_f32(left) / _f32(right));

  static double _clamp(double value, double minimum, double maximum) =>
      value < minimum ? minimum : (value > maximum ? maximum : value);

  static double _f32(double value) {
    final slot = Float32List(1)..[0] = value;
    return slot[0];
  }
}
