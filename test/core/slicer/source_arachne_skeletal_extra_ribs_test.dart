import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_beading_strategy.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_extra_ribs.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_graph.dart';

class _Strategy extends SourceArachneBeadingStrategy2 {
  _Strategy(this.nonlinear)
      : super(
          optimalWidth: 10000,
          wallSplitMiddleThreshold: 0.5,
          wallAddMiddleThreshold: 0.5,
          defaultTransitionLength: 10000,
          transitioningAngle: 1,
          name: 'extra-rib-fixture',
        );

  final List<int> nonlinear;
  final List<int> nonlinearCalls = [];

  @override
  SourceArachneBeading2 compute(int thickness, int beadCount) =>
      SourceArachneBeading2(totalThickness: thickness, leftOver: thickness);

  @override
  int getOptimalBeadCount(int thickness) => thickness ~/ 10000;

  @override
  List<int> getNonlinearThicknesses(int lowerBeadCount) {
    nonlinearCalls.add(lowerBeadCount);
    return nonlinear;
  }
}

SourceArachneSTHalfEdgeNode2 _node(
  int x,
  int y, {
  required int radius,
  required int beadCount,
  double transitionRatio = 0.75,
}) =>
    SourceArachneSTHalfEdgeNode2(
      p: SourcePoint2(x, y),
      data: SourceArachneSkeletalJoint2(
        distanceToBoundary: radius,
        beadCount: beadCount,
        transitionRatio: transitionRatio,
      ),
    );

(SourceArachneSTHalfEdge2, SourceArachneSTHalfEdge2) _centralPair(
  SourceArachneSTHalfEdgeNode2 from,
  SourceArachneSTHalfEdgeNode2 to,
) {
  final up = SourceArachneSTHalfEdge2()
    ..from = from
    ..to = to;
  final down = SourceArachneSTHalfEdge2()
    ..from = to
    ..to = from;
  up.twin = down;
  down.twin = up;
  up.data.setIsCentral(true);
  down.data.setIsCentral(true);
  return (up, down);
}

({
  SourceArachneSkeletalTrapezoidationGraph2 graph,
  SourceArachneSTHalfEdge2 up,
  SourceArachneSTHalfEdge2 down,
  SourceArachneSTHalfEdgeNode2 from,
  SourceArachneSTHalfEdgeNode2 to,
}) _splitReadyGraph({
  int fromRadius = 10000,
  int toRadius = 40000,
  int fromBeadCount = 2,
  int toBeadCount = 3,
}) {
  final from = _node(
    0,
    fromRadius,
    radius: fromRadius,
    beadCount: fromBeadCount,
  );
  final to = _node(
    100000,
    toRadius,
    radius: toRadius,
    beadCount: toBeadCount,
  );
  final pair = _centralPair(from, to);

  final sourceA = _node(0, 0, radius: 0, beadCount: fromBeadCount);
  final sourceB = _node(100000, 0, radius: 0, beadCount: toBeadCount);
  final upPrev = SourceArachneSTHalfEdge2()
    ..from = sourceA
    ..to = from
    ..next = pair.$1;
  final upNext = SourceArachneSTHalfEdge2()
    ..from = to
    ..to = sourceB
    ..prev = pair.$1;
  pair.$1
    ..prev = upPrev
    ..next = upNext;

  final downPrev = SourceArachneSTHalfEdge2()
    ..from = sourceB
    ..to = to
    ..next = pair.$2;
  final downNext = SourceArachneSTHalfEdge2()
    ..from = from
    ..to = sourceA
    ..prev = pair.$2;
  pair.$2
    ..prev = downPrev
    ..next = downNext;

  final graph = SourceArachneSkeletalTrapezoidationGraph2()
    ..nodes.addAll([from, to])
    ..edges.addAll([pair.$1, pair.$2]);
  return (graph: graph, up: pair.$1, down: pair.$2, from: from, to: to);
}

void main() {
  test('nonlinear ribs skip lower threshold, insert interiors and break at top', () {
    final fixture = _splitReadyGraph();
    final strategy = _Strategy([20000, 40000, 60000, 80000, 100000]);

    fixture.graph.generateExtraRibs(
      strategy,
      discretizationStepSize: 40000,
      snapDistance: 0,
    );

    final inserted = fixture.graph.nodes
        .where((node) =>
            !identical(node, fixture.from) &&
            !identical(node, fixture.to) &&
            node.data.beadCount == 2)
        .toList();
    expect(inserted, hasLength(2));
    expect(inserted[0].p.x, lessThan(inserted[1].p.x));
    expect(inserted[0].data.transitionRatio, 0);
    expect(inserted[1].data.transitionRatio, 0);
    expect(fixture.graph.nodes, hasLength(8));
    expect(strategy.nonlinearCalls, isNotEmpty);
  });

  test('shorter_then treats exact discretization length as inclusive', () {
    final from = _node(0, 0, radius: 10, beadCount: 1);
    final to = _node(3000, 4000, radius: 20, beadCount: 2);
    final pair = _centralPair(from, to);
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..edges.addAll([pair.$1, pair.$2]);
    final strategy = _Strategy([30000]);

    graph.generateExtraRibs(
      strategy,
      discretizationStepSize: 5000,
      snapDistance: 0,
    );

    expect(strategy.nonlinearCalls, isEmpty);
    expect(graph.nodes, isEmpty);
  });

  test('flat and downward central edges are skipped before strategy lookup', () {
    final flat = _centralPair(
      _node(0, 0, radius: 20, beadCount: 2),
      _node(10000, 0, radius: 20, beadCount: 2),
    );
    final down = _centralPair(
      _node(20000, 0, radius: 30, beadCount: 3),
      _node(30000, 0, radius: 10, beadCount: 1),
    );
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..edges.addAll([flat.$1, down.$1]);
    final strategy = _Strategy([30000]);

    graph.generateExtraRibs(
      strategy,
      discretizationStepSize: 1,
      snapDistance: 0,
    );

    expect(strategy.nonlinearCalls, isEmpty);
  });

  test('noncentral edge is skipped before nonlinear strategy lookup', () {
    final pair = _centralPair(
      _node(0, 0, radius: 10, beadCount: 1),
      _node(10000, 0, radius: 20, beadCount: 2),
    );
    pair.$1.data.setIsCentral(false);
    final graph = SourceArachneSkeletalTrapezoidationGraph2()..edges.add(pair.$1);
    final strategy = _Strategy([30000]);

    graph.generateExtraRibs(
      strategy,
      discretizationStepSize: 1,
      snapDistance: 0,
    );

    expect(strategy.nonlinearCalls, isEmpty);
  });

  test('snap comparison stays strict at exact computed end position', () {
    final fixture = _splitReadyGraph(
      fromRadius: 10000,
      toRadius: 30000,
      fromBeadCount: 2,
      toBeadCount: 3,
    );
    final strategy = _Strategy([22000]);
    final ab = fixture.to.p - fixture.from.p;
    final abSize = math.sqrt(ab.squaredLength).truncate();
    final endPos = abSize * 1000 ~/ 20000;

    fixture.graph.generateExtraRibs(
      strategy,
      discretizationStepSize: 10000,
      snapDistance: endPos,
    );

    final inserted = fixture.graph.nodes.where(
      (node) =>
          !identical(node, fixture.from) &&
          !identical(node, fixture.to) &&
          node.data.beadCount == 2,
    );
    expect(inserted, isNotEmpty);
  });

  test('one unit inside snap distance reuses matching endpoint bead count', () {
    final fixture = _splitReadyGraph(
      fromRadius: 10000,
      toRadius: 30000,
      fromBeadCount: 2,
      toBeadCount: 3,
    );
    final strategy = _Strategy([22000]);
    final ab = fixture.to.p - fixture.from.p;
    final abSize = math.sqrt(ab.squaredLength).truncate();
    final endPos = abSize * 1000 ~/ 20000;

    fixture.graph.generateExtraRibs(
      strategy,
      discretizationStepSize: 10000,
      snapDistance: endPos + 1,
    );

    expect(fixture.from.data.transitionRatio, 0);
    expect(fixture.graph.nodes, hasLength(2));
  });
}
