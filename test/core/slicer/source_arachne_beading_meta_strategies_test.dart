import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_beading_meta_strategies.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_beading_strategy.dart';

SourceArachneDistributedBeadingStrategy2 distributed() =>
    SourceArachneDistributedBeadingStrategy2(
      optimalWidth: 45000,
      defaultTransitionLength: 12000,
      transitioningAngle: 0.1745329350233078,
      wallSplitMiddleThreshold: 0.4,
      wallAddMiddleThreshold: 0.5,
      distributionRadius: 3,
    );

SourceArachneRedistributeBeadingStrategy2 redistributed() =>
    SourceArachneRedistributeBeadingStrategy2(
      optimalWidthOuter: 40000,
      minimumVariableLineRatio: 0.5,
      parent: distributed(),
    );

void main() {
  test('Redistribute optimal thickness and transition cases match source', () {
    final value = redistributed();

    expect(value.getOptimalThickness(0), 0);
    expect(value.getOptimalThickness(1), 40000);
    expect(value.getOptimalThickness(2), 80000);
    expect(value.getOptimalThickness(3), 125000);
    expect(value.getOptimalThickness(4), 170000);
    expect(value.getTransitionThickness(0), 20000);
    expect(value.getTransitionThickness(1), 56000);
    expect(value.getTransitionThickness(2), 102500);
    expect(value.getTransitionThickness(3), 143000);
    expect(value.toString(),
        'RedistributeBeadingStrategy+DistributedBeadingStrategy');
  });

  test('Redistribute bead count uses strict one-to-two source threshold', () {
    final value = redistributed();

    expect(value.getOptimalBeadCount(19999), 0);
    expect(value.getOptimalBeadCount(20000), 1);
    expect(value.getOptimalBeadCount(56000), 1);
    expect(value.getOptimalBeadCount(56001), 2);
    expect(value.getOptimalBeadCount(102499), 2);
    expect(value.getOptimalBeadCount(102500), 3);
  });

  test('Redistribute compute keeps fixed outer walls around inner beading', () {
    final result = redistributed().compute(140003, 3);

    expect(result.beadWidths, const [40000, 60003, 40000]);
    expect(result.toolpathLocations, const [20000, 70001, 120003]);
    expect(result.leftOver, 0);
    expect(result.totalThickness, 140003);
  });

  test('Widening preserves source over-width thin-line behavior', () {
    final value = SourceArachneWideningBeadingStrategy2(
      parent: redistributed(),
      minInputWidth: 20000,
      minOutputWidth: 30000,
    );

    final dropped = value.compute(19999, 0);
    expect(dropped.beadWidths, isEmpty);
    expect(dropped.leftOver, 19999);

    final widened = value.compute(25000, 1);
    expect(widened.beadWidths, const [30000]);
    expect(widened.toolpathLocations, const [12500]);
    expect(widened.totalThickness, 25000);
    expect(widened.leftOver, 0);
    expect(value.getTransitionThickness(0), 20000);
    expect(value.getOptimalBeadCount(19999), 0);
    expect(value.getOptimalBeadCount(20000), 1);
    expect(value.getNonlinearThicknesses(0), const [30000]);
    expect(value.toString(),
        'Widening+RedistributeBeadingStrategy+DistributedBeadingStrategy');
  });

  test('OuterWallInset moves only first extant wall and keeps source typo', () {
    final parent = SourceArachneWideningBeadingStrategy2(
      parent: redistributed(),
      minInputWidth: 20000,
      minOutputWidth: 10000,
    );
    final value = SourceArachneOuterWallInsetBeadingStrategy2(
      outerWallOffset: 10000,
      parent: parent,
    );

    final two = value.compute(70000, 2);
    expect(two.beadWidths, const [35000, 35000]);
    expect(two.toolpathLocations, const [27500, 52500]);

    final one = value.compute(40000, 1);
    expect(one.toolpathLocations, const [20000]);
    expect(value.toString(), startsWith('OuterWallOfsetBeadingStrategy+'));
  });

  test('OuterWallInset clamps first wall to source middle line', () {
    final value = SourceArachneOuterWallInsetBeadingStrategy2(
      outerWallOffset: 50000,
      parent: redistributed(),
    );

    expect(value.compute(70000, 2).toolpathLocations, const [35000, 52500]);
  });

  test('Limited inserts single zero-width contour marker at even maximum', () {
    final value = SourceArachneLimitedBeadingStrategy2(
      maxBeadCount: 4,
      parent: distributed(),
    );
    final result = value.compute(180000, 4);

    expect(result.beadWidths, const [45000, 45000, 0, 45000, 45000]);
    expect(result.toolpathLocations,
        const [22500, 67500, 90000, 112500, 157500]);
    expect(result.leftOver, 0);
  });

  test('Limited over-limit branch adds symmetric contour marker pair', () {
    final value = SourceArachneLimitedBeadingStrategy2(
      maxBeadCount: 4,
      parent: distributed(),
    );
    final result = value.compute(230000, 5);

    expect(result.beadWidths,
        const [45000, 45000, 0, 0, 45000, 45000]);
    expect(result.toolpathLocations,
        const [22500, 67500, 90000, 140000, 162500, 207500]);
    expect(result.totalThickness, 230000);
    expect(result.leftOver, 50000);
  });

  test('Limited transition holds max count until source 0.01mm boundary', () {
    final value = SourceArachneLimitedBeadingStrategy2(
      maxBeadCount: 4,
      parent: distributed(),
    );

    expect(value.getTransitionThickness(4), 224001);
    expect(value.getOptimalBeadCount(224000), 4);
    expect(value.getOptimalBeadCount(224001), 5);
    expect(value.getOptimalBeadCount(270000), 5);
    expect(value.toString(),
        'LimitedBeadingStrategy+DistributedBeadingStrategy');
  });
}
