import 'dart:typed_data';

import 'source_arachne_wall_tool_paths.dart';

/// Pinned `Arachne::BeadingStrategy::Beading` value object.
class SourceArachneBeading2 {
  SourceArachneBeading2({
    required this.totalThickness,
    Iterable<int> beadWidths = const <int>[],
    Iterable<int> toolpathLocations = const <int>[],
    required this.leftOver,
  })  : beadWidths = List.unmodifiable(beadWidths),
        toolpathLocations = List.unmodifiable(toolpathLocations);

  final int totalThickness;
  final List<int> beadWidths;
  final List<int> toolpathLocations;
  final int leftOver;
}

/// Direct represented subset of pinned `Arachne::BeadingStrategy`.
abstract class SourceArachneBeadingStrategy2 {
  SourceArachneBeadingStrategy2({
    required this.optimalWidth,
    required this.wallSplitMiddleThreshold,
    required this.wallAddMiddleThreshold,
    required this.defaultTransitionLength,
    required double transitioningAngle,
    this.name = 'Unknown',
  }) : transitioningAngle = _f32(transitioningAngle);

  final int optimalWidth;
  final double wallSplitMiddleThreshold;
  final double wallAddMiddleThreshold;
  final int defaultTransitionLength;
  final double transitioningAngle;
  final String name;

  SourceArachneBeading2 compute(int thickness, int beadCount);

  int getOptimalBeadCount(int thickness);

  int getOptimalThickness(int beadCount) => optimalWidth * beadCount;

  int getTransitionThickness(int lowerBeadCount) {
    final lowerIdealWidth = getOptimalThickness(lowerBeadCount);
    final higherIdealWidth = getOptimalThickness(lowerBeadCount + 1);
    final threshold = lowerBeadCount.isOdd
        ? wallSplitMiddleThreshold
        : wallAddMiddleThreshold;
    return (lowerIdealWidth +
            threshold * (higherIdealWidth - lowerIdealWidth))
        .truncate();
  }

  int getTransitioningLength(int lowerBeadCount) => lowerBeadCount == 0
      ? SourceArachneWallToolPathsPreprocess2.scaleDouble(0.01)
      : defaultTransitionLength;

  double getTransitionAnchorPos(int lowerBeadCount) {
    final lowerOptimum = getOptimalThickness(lowerBeadCount);
    final transitionPoint = getTransitionThickness(lowerBeadCount);
    final upperOptimum = getOptimalThickness(lowerBeadCount + 1);
    final ratio = _divF32(
      _f32((transitionPoint - lowerOptimum).toDouble()),
      _f32((upperOptimum - lowerOptimum).toDouble()),
    );
    return _f32(1.0 - ratio);
  }

  List<int> getNonlinearThicknesses(int lowerBeadCount) => const <int>[];

  double get splitMiddleThreshold => wallSplitMiddleThreshold;
  double get transitioningAngleValue => transitioningAngle;

  @override
  String toString() => name;
}

/// Direct port of pinned `DistributedBeadingStrategy`.
class SourceArachneDistributedBeadingStrategy2
    extends SourceArachneBeadingStrategy2 {
  SourceArachneDistributedBeadingStrategy2({
    required int optimalWidth,
    required int defaultTransitionLength,
    required double transitioningAngle,
    required double wallSplitMiddleThreshold,
    required double wallAddMiddleThreshold,
    required this.distributionRadius,
  })  : oneOverDistributionRadiusSquared =
            _distributionWeightScale(distributionRadius),
        super(
          optimalWidth: optimalWidth,
          defaultTransitionLength: defaultTransitionLength,
          transitioningAngle: transitioningAngle,
          wallSplitMiddleThreshold: wallSplitMiddleThreshold,
          wallAddMiddleThreshold: wallAddMiddleThreshold,
          name: 'DistributedBeadingStrategy',
        );

  final int distributionRadius;
  final double oneOverDistributionRadiusSquared;

  @override
  SourceArachneBeading2 compute(int thickness, int beadCount) {
    final beadWidths = <int>[];
    final toolpathLocations = <int>[];
    var leftOver = 0;

    if (beadCount > 2) {
      final toBeDivided = thickness - beadCount * optimalWidth;
      final middle = _divF32(_f32((beadCount - 1).toDouble()), _f32(2));
      final weights = <double>[];
      for (var beadIndex = 0; beadIndex < beadCount; beadIndex++) {
        final deviation = _subF32(_f32(beadIndex.toDouble()), middle);
        final weightedDeviation = _mulF32(
          _mulF32(oneOverDistributionRadiusSquared, deviation),
          deviation,
        );
        final weight = _subF32(_f32(1), weightedDeviation);
        weights.add(weight < 0 ? _f32(0) : weight);
      }

      var totalWeight = _f32(0);
      for (final weight in weights) {
        totalWeight = _addF32(totalWeight, weight);
      }

      var accumulatedWidth = 0;
      for (var beadIndex = 0; beadIndex < beadCount; beadIndex++) {
        final weightFraction = _divF32(weights[beadIndex], totalWeight);
        final splitLeftOverWeight = _mulF32(
          _f32(toBeDivided.toDouble()),
          weightFraction,
        ).truncate();
        final width = beadIndex == beadCount - 1
            ? thickness - accumulatedWidth
            : optimalWidth + splitLeftOverWeight;

        if (beadIndex == 0) {
          toolpathLocations.add(width ~/ 2);
        } else {
          toolpathLocations.add(
            toolpathLocations.last + (beadWidths.last + width) ~/ 2,
          );
        }
        beadWidths.add(width);
        accumulatedWidth += width;
      }
      leftOver = 0;
      assert(accumulatedWidth + leftOver == thickness);
    } else if (beadCount == 2) {
      final outerWidth = thickness ~/ 2;
      beadWidths
        ..add(outerWidth)
        ..add(outerWidth);
      toolpathLocations
        ..add(outerWidth ~/ 2)
        ..add(thickness - outerWidth ~/ 2);
      leftOver = 0;
    } else if (beadCount == 1) {
      final outerWidth = thickness;
      beadWidths.add(outerWidth);
      toolpathLocations.add(outerWidth ~/ 2);
      leftOver = 0;
    } else {
      leftOver = thickness;
    }

    assert(beadWidths.fold<int>(0, (sum, width) => sum + width) + leftOver ==
        thickness);
    return SourceArachneBeading2(
      totalThickness: thickness,
      beadWidths: beadWidths,
      toolpathLocations: toolpathLocations,
      leftOver: leftOver,
    );
  }

  @override
  int getOptimalBeadCount(int thickness) {
    final naiveCount = thickness ~/ optimalWidth;
    final remainder = thickness - naiveCount * optimalWidth;
    final threshold = naiveCount.isOdd
        ? wallSplitMiddleThreshold
        : wallAddMiddleThreshold;
    final minimumLineWidth = (optimalWidth * threshold).truncate();
    return naiveCount + (remainder >= minimumLineWidth ? 1 : 0);
  }

  static double _distributionWeightScale(int distributionRadius) {
    if (distributionRadius >= 2) {
      final divisor = _f32((distributionRadius - 1).toDouble());
      return _mulF32(
        _divF32(_f32(1), divisor),
        _divF32(_f32(1), divisor),
      );
    }
    return _f32(1);
  }
}

double _addF32(double left, double right) =>
    _f32(_f32(left) + _f32(right));

double _subF32(double left, double right) =>
    _f32(_f32(left) - _f32(right));

double _mulF32(double left, double right) =>
    _f32(_f32(left) * _f32(right));

double _divF32(double left, double right) =>
    _f32(_f32(left) / _f32(right));

double _f32(double value) {
  final slot = Float32List(1)..[0] = value;
  return slot[0];
}
