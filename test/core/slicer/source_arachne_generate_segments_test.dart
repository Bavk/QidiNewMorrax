import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_beading_strategy.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_generate_segments.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_graph.dart';

class _Strategy extends SourceArachneBeadingStrategy2 {
  _Strategy()
      : super(
          optimalWidth: 800,
          wallSplitMiddleThreshold: 0.5,
          wallAddMiddleThreshold: 0.5,
          defaultTransitionLength: 1000,
          transitioningAngle: 1,
          name: 'generate-segments-compose-fixture',
        );

  final List<(int, int)> computeCalls = [];

  @override
  SourceArachneBeading2 compute(int thickness, int beadCount) {
    computeCalls.add((thickness, beadCount));
    return SourceArachneBeading2(
      totalThickness: thickness,
      beadWidths: const [800],
      toolpathLocations: const [2500],
      leftOver: 0,
    );
  }

  @override
  int getOptimalBeadCount(int thickness) => 2;
}

SourceArachneSTHalfEdgeNode2 _node(
  int x,
  int y,
  int radius, {
  required int beadCount,
}) =>
    SourceArachneSTHalfEdgeNode2(
      p: SourcePoint2(x, y),
      data: SourceArachneSkeletalJoint2(
        distanceToBoundary: radius,
        beadCount: beadCount,
        transitionRatio: 0,
      ),
    );

void main() {
  test('generateSegments composes source stages into an even closed-by-points wall', () {
    final boundaryA = _node(-10000, 0, 0, beadCount: 0);
    final peak = _node(0, 5000, 5000, beadCount: 2);
    final boundaryB = _node(10000, 0, 0, beadCount: 0);

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
    for (final edge in [a0, a1, b0, b1]) {
      edge.data.setIsCentral(true);
    }
    peak.incidentEdge = a1;

    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..nodes.addAll([boundaryA, peak, boundaryB])
      ..edges.addAll([a0, a1, b0, b1]);
    final strategy = _Strategy();

    final generated = graph.generateSegments(
      strategy,
      beadingPropagationTransitionDistance: 10000,
    );

    // Boundary nodes are skipped by storeNodeBeadings; the peak is materialized
    // exactly once before propagation/junction generation.
    expect(strategy.computeCalls, [(10000, 2)]);
    expect(peak.data.hasBeading, isTrue);
    expect(generated, hasLength(1));
    expect(generated.single, hasLength(1));
    final line = generated.single.single;
    expect(line.insetIndex, 0);
    expect(line.isOdd, isFalse);
    expect(line.isClosed, isFalse);
    expect(line.junctions.map((junction) => junction.p), const [
      SourcePoint2(-5000, 2500),
      SourcePoint2(5000, 2500),
      SourcePoint2(-5000, 2500),
    ]);
    expect(line.junctions.map((junction) => junction.w),
        everyElement(800));
  });
}
