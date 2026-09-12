import 'source_arachne_beading_strategy.dart';
import 'source_arachne_wall_tool_paths.dart';

/// Direct port of pinned `RedistributeBeadingStrategy`.
class SourceArachneRedistributeBeadingStrategy2
    extends SourceArachneBeadingStrategy2 {
  SourceArachneRedistributeBeadingStrategy2({
    required this.optimalWidthOuter,
    required this.minimumVariableLineRatio,
    required this.parent,
  }) : super(
          optimalWidth: parent.optimalWidth,
          wallSplitMiddleThreshold: parent.wallSplitMiddleThreshold,
          wallAddMiddleThreshold: parent.wallAddMiddleThreshold,
          defaultTransitionLength: parent.defaultTransitionLength,
          transitioningAngle: parent.transitioningAngle,
          name: 'RedistributeBeadingStrategy',
        );

  final SourceArachneBeadingStrategy2 parent;
  final int optimalWidthOuter;
  final double minimumVariableLineRatio;

  @override
  int getOptimalThickness(int beadCount) {
    final innerBeadCount = beadCount - 2 > 0 ? beadCount - 2 : 0;
    final outerBeadCount = beadCount - innerBeadCount;
    return parent.getOptimalThickness(innerBeadCount) +
        optimalWidthOuter * outerBeadCount;
  }

  @override
  int getTransitionThickness(int lowerBeadCount) {
    switch (lowerBeadCount) {
      case 0:
        return (minimumVariableLineRatio * optimalWidthOuter).truncate();
      case 1:
        return ((1.0 + parent.splitMiddleThreshold) * optimalWidthOuter)
            .truncate();
      default:
        return parent.getTransitionThickness(lowerBeadCount - 2) +
            2 * optimalWidthOuter;
    }
  }

  @override
  int getOptimalBeadCount(int thickness) {
    if (thickness < minimumVariableLineRatio * optimalWidthOuter) return 0;
    if (thickness <= 2 * optimalWidthOuter) {
      return thickness >
              (1.0 + parent.splitMiddleThreshold) * optimalWidthOuter
          ? 2
          : 1;
    }
    return parent.getOptimalBeadCount(thickness - 2 * optimalWidthOuter) + 2;
  }

  @override
  int getTransitioningLength(int lowerBeadCount) =>
      parent.getTransitioningLength(lowerBeadCount);

  @override
  double getTransitionAnchorPos(int lowerBeadCount) =>
      parent.getTransitionAnchorPos(lowerBeadCount);

  @override
  String toString() => 'RedistributeBeadingStrategy+$parent';

  @override
  SourceArachneBeading2 compute(int thickness, int beadCount) {
    if (beadCount == 0 ||
        thickness < minimumVariableLineRatio * optimalWidthOuter) {
      return SourceArachneBeading2(
        totalThickness: thickness,
        leftOver: thickness,
      );
    }

    final beadWidths = <int>[];
    final toolpathLocations = <int>[];
    final innerBeadCount = beadCount - 2;
    final innerThickness = thickness - 2 * optimalWidthOuter;
    if (innerBeadCount > 0 && innerThickness > 0) {
      final inner = parent.compute(innerThickness, innerBeadCount);
      beadWidths.addAll(inner.beadWidths);
      toolpathLocations.addAll(
        inner.toolpathLocations.map((location) => location + optimalWidthOuter),
      );
    }

    final actualOuterThickness = beadCount > 2
        ? ((thickness ~/ 2) < optimalWidthOuter
            ? thickness ~/ 2
            : optimalWidthOuter)
        : thickness ~/ beadCount;
    beadWidths.insert(0, actualOuterThickness);
    toolpathLocations.insert(0, actualOuterThickness ~/ 2);
    if (beadCount > 1) {
      beadWidths.add(actualOuterThickness);
      toolpathLocations.add(thickness - actualOuterThickness ~/ 2);
    }

    final beadWidthSum = beadWidths.fold<int>(0, (sum, width) => sum + width);
    return SourceArachneBeading2(
      totalThickness: thickness,
      beadWidths: beadWidths,
      toolpathLocations: toolpathLocations,
      leftOver: thickness - beadWidthSum,
    );
  }
}

/// Direct port of pinned `WideningBeadingStrategy`.
class SourceArachneWideningBeadingStrategy2
    extends SourceArachneBeadingStrategy2 {
  SourceArachneWideningBeadingStrategy2({
    required this.parent,
    required this.minInputWidth,
    required this.minOutputWidth,
  }) : super(
          optimalWidth: parent.optimalWidth,
          wallSplitMiddleThreshold: parent.wallSplitMiddleThreshold,
          wallAddMiddleThreshold: parent.wallAddMiddleThreshold,
          defaultTransitionLength: parent.defaultTransitionLength,
          transitioningAngle: parent.transitioningAngle,
          name: parent.name,
        );

  final SourceArachneBeadingStrategy2 parent;
  final int minInputWidth;
  final int minOutputWidth;

  @override
  String toString() => 'Widening+$parent';

  @override
  SourceArachneBeading2 compute(int thickness, int beadCount) {
    if (thickness < optimalWidth) {
      if (thickness >= minInputWidth) {
        final outputWidth = thickness > minOutputWidth
            ? thickness
            : minOutputWidth;
        return SourceArachneBeading2(
          totalThickness: thickness,
          beadWidths: [outputWidth],
          toolpathLocations: [thickness ~/ 2],
          leftOver: 0,
        );
      }
      return SourceArachneBeading2(
        totalThickness: thickness,
        leftOver: thickness,
      );
    }
    return parent.compute(thickness, beadCount);
  }

  @override
  int getOptimalThickness(int beadCount) => parent.getOptimalThickness(beadCount);

  @override
  int getTransitionThickness(int lowerBeadCount) => lowerBeadCount == 0
      ? minInputWidth
      : parent.getTransitionThickness(lowerBeadCount);

  @override
  int getOptimalBeadCount(int thickness) {
    if (thickness < minInputWidth) return 0;
    final result = parent.getOptimalBeadCount(thickness);
    return result < 1 ? 1 : result;
  }

  @override
  int getTransitioningLength(int lowerBeadCount) =>
      parent.getTransitioningLength(lowerBeadCount);

  @override
  double getTransitionAnchorPos(int lowerBeadCount) =>
      parent.getTransitionAnchorPos(lowerBeadCount);

  @override
  List<int> getNonlinearThicknesses(int lowerBeadCount) => [
        minOutputWidth,
        ...parent.getNonlinearThicknesses(lowerBeadCount),
      ];
}

/// Direct port of pinned `OuterWallInsetBeadingStrategy`.
///
/// The source spelling `Ofset` is intentionally retained in the strategy name
/// and `toString()` result.
class SourceArachneOuterWallInsetBeadingStrategy2
    extends SourceArachneBeadingStrategy2 {
  SourceArachneOuterWallInsetBeadingStrategy2({
    required this.outerWallOffset,
    required this.parent,
  }) : super(
          optimalWidth: parent.optimalWidth,
          wallSplitMiddleThreshold: parent.wallSplitMiddleThreshold,
          wallAddMiddleThreshold: parent.wallAddMiddleThreshold,
          defaultTransitionLength: parent.defaultTransitionLength,
          transitioningAngle: parent.transitioningAngle,
          name: 'OuterWallOfsetBeadingStrategy',
        );

  final SourceArachneBeadingStrategy2 parent;
  final int outerWallOffset;

  @override
  int getOptimalThickness(int beadCount) => parent.getOptimalThickness(beadCount);

  @override
  int getTransitionThickness(int lowerBeadCount) =>
      parent.getTransitionThickness(lowerBeadCount);

  @override
  int getOptimalBeadCount(int thickness) => parent.getOptimalBeadCount(thickness);

  @override
  int getTransitioningLength(int lowerBeadCount) =>
      parent.getTransitioningLength(lowerBeadCount);

  @override
  String toString() => 'OuterWallOfsetBeadingStrategy+$parent';

  @override
  SourceArachneBeading2 compute(int thickness, int beadCount) {
    final parentResult = parent.compute(thickness, beadCount);
    final actualBeadCount =
        parentResult.beadWidths.where((width) => width > 0).length;
    if (actualBeadCount < 2) return parentResult;

    final locations = List<int>.of(parentResult.toolpathLocations);
    final moved = locations[0] + outerWallOffset;
    final middle = thickness ~/ 2;
    locations[0] = moved < middle ? moved : middle;
    return SourceArachneBeading2(
      totalThickness: parentResult.totalThickness,
      beadWidths: parentResult.beadWidths,
      toolpathLocations: locations,
      leftOver: parentResult.leftOver,
    );
  }
}

/// Direct port of pinned `LimitedBeadingStrategy`.
class SourceArachneLimitedBeadingStrategy2
    extends SourceArachneBeadingStrategy2 {
  SourceArachneLimitedBeadingStrategy2({
    required this.maxBeadCount,
    required this.parent,
  }) : super(
          optimalWidth: parent.optimalWidth,
          wallSplitMiddleThreshold: parent.wallSplitMiddleThreshold,
          wallAddMiddleThreshold: parent.wallAddMiddleThreshold,
          defaultTransitionLength: parent.defaultTransitionLength,
          transitioningAngle: parent.transitioningAngle,
          name: parent.name,
        );

  static const int wallContourMarkedWidth = 0;

  final int maxBeadCount;
  final SourceArachneBeadingStrategy2 parent;

  @override
  String toString() => 'LimitedBeadingStrategy+$parent';

  @override
  int getTransitioningLength(int lowerBeadCount) =>
      parent.getTransitioningLength(lowerBeadCount);

  @override
  double getTransitionAnchorPos(int lowerBeadCount) =>
      parent.getTransitionAnchorPos(lowerBeadCount);

  @override
  SourceArachneBeading2 compute(int thickness, int beadCount) {
    if (beadCount <= maxBeadCount) {
      final parentResult = parent.compute(thickness, beadCount);
      final locations = List<int>.of(parentResult.toolpathLocations);
      final widths = List<int>.of(parentResult.beadWidths);
      final actualBeadCount = locations.length;
      if (actualBeadCount.isEven && actualBeadCount == maxBeadCount) {
        final index = maxBeadCount ~/ 2 - 1;
        final innermostLocation = locations[index];
        final innermostWidth = widths[index];
        locations.insert(
          maxBeadCount ~/ 2,
          innermostLocation + innermostWidth ~/ 2,
        );
        widths.insert(maxBeadCount ~/ 2, wallContourMarkedWidth);
      }
      return SourceArachneBeading2(
        totalThickness: parentResult.totalThickness,
        beadWidths: widths,
        toolpathLocations: locations,
        leftOver: parentResult.leftOver,
      );
    }

    assert(beadCount == maxBeadCount + 1);
    final optimalThickness = parent.getOptimalThickness(maxBeadCount);
    final parentResult = parent.compute(optimalThickness, maxBeadCount);
    final locations = List<int>.of(parentResult.toolpathLocations);
    final widths = List<int>.of(parentResult.beadWidths);
    final actualBeadCount = locations.length;
    var leftOver = parentResult.leftOver +
        thickness - parentResult.totalThickness;

    if (actualBeadCount.isOdd) {
      locations[actualBeadCount ~/ 2] = thickness ~/ 2;
      widths[actualBeadCount ~/ 2] = thickness - optimalThickness;
    }
    for (var beadIndex = 0;
        beadIndex < (actualBeadCount + 1) ~/ 2;
        beadIndex++) {
      locations[actualBeadCount - 1 - beadIndex] =
          thickness - locations[beadIndex];
    }

    var innermostLocation = locations[maxBeadCount ~/ 2 - 1];
    var innermostWidth = widths[maxBeadCount ~/ 2 - 1];
    locations.insert(
      maxBeadCount ~/ 2,
      innermostLocation + innermostWidth ~/ 2,
    );
    widths.insert(maxBeadCount ~/ 2, wallContourMarkedWidth);

    final oppositeBead = actualBeadCount - (maxBeadCount ~/ 2 - 1);
    innermostLocation = locations[oppositeBead];
    innermostWidth = widths[oppositeBead];
    locations.insert(
      oppositeBead,
      innermostLocation - innermostWidth ~/ 2,
    );
    widths.insert(oppositeBead, wallContourMarkedWidth);

    return SourceArachneBeading2(
      totalThickness: thickness,
      beadWidths: widths,
      toolpathLocations: locations,
      leftOver: leftOver,
    );
  }

  @override
  int getOptimalThickness(int beadCount) {
    if (beadCount <= maxBeadCount) {
      return parent.getOptimalThickness(beadCount);
    }
    assert(false, 'Pinned LimitedBeadingStrategy getOptimalThickness overflow');
    return SourceArachneWallToolPathsPreprocess2.scaleDouble(1000.0);
  }

  @override
  int getTransitionThickness(int lowerBeadCount) {
    if (lowerBeadCount < maxBeadCount) {
      return parent.getTransitionThickness(lowerBeadCount);
    }
    if (lowerBeadCount == maxBeadCount) {
      return parent.getOptimalThickness(lowerBeadCount + 1) -
          SourceArachneWallToolPathsPreprocess2.scaleDouble(0.01);
    }
    assert(false, 'Pinned LimitedBeadingStrategy transition overflow');
    return SourceArachneWallToolPathsPreprocess2.scaleDouble(900.0);
  }

  @override
  int getOptimalBeadCount(int thickness) {
    final parentBeadCount = parent.getOptimalBeadCount(thickness);
    if (parentBeadCount <= maxBeadCount) {
      // Source intentionally calls the parent a second time in this branch.
      return parent.getOptimalBeadCount(thickness);
    }
    if (parentBeadCount == maxBeadCount + 1) {
      final limit = parent.getOptimalThickness(maxBeadCount + 1) -
          SourceArachneWallToolPathsPreprocess2.scaleDouble(0.01);
      return thickness < limit ? maxBeadCount : maxBeadCount + 1;
    }
    return maxBeadCount + 1;
  }
}
