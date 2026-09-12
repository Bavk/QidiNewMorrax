import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_beading_strategy.dart';

SourceArachneDistributedBeadingStrategy2 strategy({
  int radius = 3,
}) =>
    SourceArachneDistributedBeadingStrategy2(
      optimalWidth: 45000,
      defaultTransitionLength: 12000,
      transitioningAngle: 0.1745329350233078,
      wallSplitMiddleThreshold: 0.4,
      wallAddMiddleThreshold: 0.5,
      distributionRadius: radius,
    );

void main() {
  test('BeadingStrategy base transition helpers preserve source casts', () {
    final value = strategy();

    expect(value.getOptimalThickness(3), 135000);
    expect(value.getTransitionThickness(0), 22500);
    expect(value.getTransitionThickness(1), 63000);
    expect(value.getTransitionThickness(2), 112500);
    expect(value.getTransitioningLength(0), 999);
    expect(value.getTransitioningLength(1), 12000);
    expect(value.getTransitionAnchorPos(0), 0.5);
    expect(value.getTransitionAnchorPos(1), 0.6000000238418579);
    expect(value.getNonlinearThicknesses(3), isEmpty);
    expect(value.toString(), 'DistributedBeadingStrategy');
  });

  test('Distributed optimal count switches on odd split threshold inclusively', () {
    final value = strategy();

    expect(value.getOptimalBeadCount(62999), 1);
    expect(value.getOptimalBeadCount(63000), 2);
    expect(value.getOptimalBeadCount(112499), 2);
    expect(value.getOptimalBeadCount(112500), 3);
  });

  test('Distributed zero and one bead cases preserve source leftover semantics', () {
    final value = strategy();

    final zero = value.compute(90000, 0);
    expect(zero.totalThickness, 90000);
    expect(zero.beadWidths, isEmpty);
    expect(zero.toolpathLocations, isEmpty);
    expect(zero.leftOver, 90000);

    final one = value.compute(90000, 1);
    expect(one.beadWidths, const [90000]);
    expect(one.toolpathLocations, const [45000]);
    expect(one.leftOver, 0);
  });

  test('Distributed two-bead branch uses integer half widths', () {
    final result = strategy().compute(100000, 2);

    expect(result.beadWidths, const [50000, 50000]);
    expect(result.toolpathLocations, const [25000, 75000]);
    expect(result.leftOver, 0);
  });

  test('Distributed three-bead float weights match source truncation', () {
    final result = strategy().compute(140003, 3);

    expect(result.beadWidths, const [46500, 47001, 46502]);
    expect(result.toolpathLocations, const [23250, 70000, 116751]);
    expect(result.leftOver, 0);
    expect(result.beadWidths.reduce((a, b) => a + b), 140003);
  });

  test('distribution radius below two collapses discrepancy into middle bead', () {
    final result = strategy(radius: 1).compute(140003, 3);

    expect(result.beadWidths, const [45000, 50003, 45000]);
    expect(result.toolpathLocations, const [22500, 70001, 117502]);
    expect(result.leftOver, 0);
  });
}
