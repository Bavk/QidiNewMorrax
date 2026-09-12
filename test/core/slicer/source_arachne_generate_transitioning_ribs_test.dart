import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_beading_strategy.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_generate_transitioning_ribs.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_graph.dart';

class _Strategy extends SourceArachneBeadingStrategy2 {
  _Strategy()
      : super(
          optimalWidth: 100,
          wallSplitMiddleThreshold: 0.5,
          wallAddMiddleThreshold: 0.5,
          defaultTransitionLength: 20,
          transitioningAngle: 1,
          name: 'transitioning-ribs-fixture',
        );

  @override
  SourceArachneBeading2 compute(int thickness, int beadCount) =>
      SourceArachneBeading2(totalThickness: thickness, leftOver: thickness);

  @override
  int getOptimalBeadCount(int thickness) => thickness ~/ 100;

  @override
  int getTransitionThickness(int lowerBeadCount) => 200;

  @override
  double getTransitionAnchorPos(int lowerBeadCount) => 0.5;
}

SourceArachneSTHalfEdgeNode2 _node(
  int x,
  int y, {
  required int radius,
  required int beadCount,
}) =>
    SourceArachneSTHalfEdgeNode2(
      p: SourcePoint2(x, y),
      data: SourceArachneSkeletalJoint2(
        distanceToBoundary: radius,
        beadCount: beadCount,
      ),
    );

void main() {
  test('generateTransitioningRibs composes source four-stage order', () {
    final from = _node(0, 2, radius: 50, beadCount: 1);
    final to = _node(100, 2, radius: 150, beadCount: 2);
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

    // Keep the central edge 2 source units above its source contour so the
    // final transition ends exercise real insertNode()/insertRib() geometry.
    final upPrev = SourceArachneSTHalfEdge2()
      ..from = _node(0, 0, radius: 0, beadCount: 1)
      ..to = from
      ..next = up;
    final upNext = SourceArachneSTHalfEdge2()
      ..from = to
      ..to = _node(100, 0, radius: 0, beadCount: 2)
      ..prev = up;
    up
      ..prev = upPrev
      ..next = upNext;

    final downPrev = SourceArachneSTHalfEdge2()
      ..from = _node(100, 0, radius: 0, beadCount: 2)
      ..to = to
      ..next = down;
    final downNext = SourceArachneSTHalfEdge2()
      ..from = from
      ..to = _node(0, 0, radius: 0, beadCount: 1)
      ..prev = down;
    down
      ..prev = downPrev
      ..next = downNext;

    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      // This order also exercises the transition-end mirror pass twice, like
      // the source std::list half-edge graph can.
      ..edges.addAll([down, up])
      ..nodes.addAll([from, to]);

    graph.generateTransitioningRibs(
      _Strategy(),
      transitionFilterDistance: 0,
      allowedFilterDeviation: 1000,
      snapDistance: 0,
    );

    // Radius 100 is halfway between 50 and 150 => transition mid at x=50.
    // With length 20 and anchor 0.5, source ends are x=40 and x=60, and
    // applyTransitions inserts both nodes in sorted order.
    final splitNodes = graph.nodes
        .where((node) => node.p.y == 2 && node.p.x != 0 && node.p.x != 100)
        .toList();
    expect(splitNodes.map((node) => node.p.x), [40, 60]);
    expect(splitNodes.map((node) => node.data.beadCount), [1, 2]);
    expect(up.data.transitions, hasLength(1));
    expect(up.data.transitions!.single.pos, 50);
    expect(up.data.transitionEnds, hasLength(2));
  });
}
