import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_beading_strategy.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_generate_toolpaths.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_graph.dart';

class _Strategy extends SourceArachneBeadingStrategy2 {
  _Strategy()
      : super(
          optimalWidth: 100,
          wallSplitMiddleThreshold: 0.5,
          wallAddMiddleThreshold: 0.5,
          defaultTransitionLength: 1000,
          transitioningAngle: math.pi,
          name: 'generate-toolpaths-compose-fixture',
        );

  final List<(int, int)> computeCalls = [];
  final List<int> optimalCountCalls = [];

  @override
  SourceArachneBeading2 compute(int thickness, int beadCount) {
    computeCalls.add((thickness, beadCount));
    return SourceArachneBeading2(
      totalThickness: thickness,
      leftOver: thickness,
    );
  }

  @override
  int getOptimalBeadCount(int thickness) {
    optimalCountCalls.add(thickness);
    return 1;
  }
}

({
  SourceArachneSkeletalTrapezoidationGraph2 graph,
  SourceArachneSTHalfEdgeNode2 boundaryA,
  SourceArachneSTHalfEdgeNode2 peak,
  SourceArachneSTHalfEdgeNode2 boundaryB,
}) _twoQuadDomain({required int initialBeadCount}) {
  SourceArachneSTHalfEdgeNode2 node(int x, int y, int radius) =>
      SourceArachneSTHalfEdgeNode2(
        p: SourcePoint2(x, y),
        data: SourceArachneSkeletalJoint2(
          distanceToBoundary: radius,
          beadCount: initialBeadCount,
          transitionRatio: 0,
        ),
      );

  final boundaryA = node(-10000, 0, 0);
  final peak = node(0, 5000, 5000);
  final boundaryB = node(10000, 0, 0);

  final a0 = SourceArachneSTHalfEdge2()
    ..from = boundaryA
    ..to = peak;
  final a1 = SourceArachneSTHalfEdge2()
    ..from = peak
    ..to = boundaryB
    ..prev = a0;
  a0.next = a1;

  final b0 = SourceArachneSTHalfEdge2()
    ..from = boundaryB
    ..to = peak;
  final b1 = SourceArachneSTHalfEdge2()
    ..from = peak
    ..to = boundaryA
    ..prev = b0;
  b0.next = b1;

  a0.twin = b1;
  b1.twin = a0;
  a1.twin = b0;
  b0.twin = a1;

  boundaryA.incidentEdge = a0;
  boundaryB.incidentEdge = b0;
  peak.incidentEdge = a1;

  final graph = SourceArachneSkeletalTrapezoidationGraph2()
    ..nodes.addAll([boundaryA, peak, boundaryB])
    ..edges.addAll([a0, a1, b0, b1]);
  return (
    graph: graph,
    boundaryA: boundaryA,
    peak: peak,
    boundaryB: boundaryB,
  );
}

void main() {
  test('generateToolpaths composes all runtime stages after graph construction', () {
    final fixture = _twoQuadDomain(initialBeadCount: -1);
    final strategy = _Strategy();

    final generated = fixture.graph.generateToolpaths(
      strategy,
      discretizationStepSize: 100,
      transitionFilterDistance: 1000,
      allowedFilterDeviation: 1000,
      beadingPropagationTransitionDistance: 1000,
    );

    expect(generated, isEmpty);
    expect(fixture.graph.edges.every((edge) => edge.data.isCentral), isTrue);
    expect(fixture.boundaryA.data.beadCount, 1);
    expect(fixture.peak.data.beadCount, 1);
    expect(fixture.boundaryB.data.beadCount, 1);
    // generateSegments materializes exactly the three positive-count nodes in
    // graph node order after all transitioning stages have completed.
    expect(strategy.computeCalls, [(0, 1), (10000, 1), (0, 1)]);
    expect(fixture.peak.data.hasBeading, isTrue);
  });

  test('filterOutermostCentralEdges runs between central filter and bead update', () {
    final fixture = _twoQuadDomain(initialBeadCount: 1);
    final strategy = _Strategy();

    final generated = fixture.graph.generateToolpaths(
      strategy,
      discretizationStepSize: 100,
      transitionFilterDistance: 1000,
      allowedFilterDeviation: 1000,
      beadingPropagationTransitionDistance: 1000,
      filterOutermostCentralEdges: true,
    );

    expect(generated, isEmpty);
    expect(fixture.graph.edges.every((edge) => !edge.data.isCentral), isTrue);
    expect(fixture.peak.data.beadCount, 1);
  });
}
