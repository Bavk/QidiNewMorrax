import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_apply_transitions.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_graph.dart';

SourceArachneSTHalfEdgeNode2 _node(
  int x,
  int y, {
  int beadCount = 1,
  double transitionRatio = 0.75,
}) =>
    SourceArachneSTHalfEdgeNode2(
      p: SourcePoint2(x, y),
      data: SourceArachneSkeletalJoint2(
        distanceToBoundary: y.abs(),
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
}) _splitReadyGraph({int fromBeadCount = 1, int toBeadCount = 1}) {
  final from = _node(0, 2, beadCount: fromBeadCount);
  final to = _node(100, 2, beadCount: toBeadCount);
  final pair = _centralPair(from, to);

  final upPrev = SourceArachneSTHalfEdge2()
    ..from = _node(0, 0)
    ..to = from
    ..next = pair.$1;
  final upNext = SourceArachneSTHalfEdge2()
    ..from = to
    ..to = _node(100, 0)
    ..prev = pair.$1;
  pair.$1
    ..prev = upPrev
    ..next = upNext;

  final downPrev = SourceArachneSTHalfEdge2()
    ..from = _node(100, 0)
    ..to = to
    ..next = pair.$2;
  final downNext = SourceArachneSTHalfEdge2()
    ..from = from
    ..to = _node(0, 0)
    ..prev = pair.$2;
  pair.$2
    ..prev = downPrev
    ..next = downNext;

  final graph = SourceArachneSkeletalTrapezoidationGraph2()
    // Put the downward twin first so the source mirror pass moves an existing
    // upward transition to the twin and then back to the upward edge.
    ..edges.addAll([pair.$2, pair.$1])
    ..nodes.addAll([from, to]);
  return (graph: graph, up: pair.$1, down: pair.$2, from: from, to: to);
}

SourceArachneTransitionEnd2 _end(
  int pos, {
  int lowerBeadCount = 1,
  bool isLowerEnd = true,
}) =>
    SourceArachneTransitionEnd2(
      pos: pos,
      lowerBeadCount: lowerBeadCount,
      isLowerEnd: isLowerEnd,
    );

void main() {
  test('twin transition ends mirror position and clear source storage', () {
    final from = _node(0, 0, beadCount: 1);
    final to = _node(100, 0, beadCount: 1);
    final pair = _centralPair(from, to);
    final twinEnds = <SourceArachneTransitionEnd2>[_end(20)];
    pair.$2.data.setTransitionEnds(twinEnds);
    final owners = <List<SourceArachneTransitionEnd2>>[twinEnds];
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..edges.add(pair.$1)
      ..nodes.addAll([from, to]);

    graph.applyTransitions(owners, snapDistance: 30);

    expect(twinEnds, isEmpty);
    expect(pair.$1.data.transitionEnds, hasLength(1));
    expect(pair.$1.data.transitionEnds!.single.pos, 80);
    expect(to.data.transitionRatio, 0);
    expect(owners, hasLength(2));
    expect(graph.edges, hasLength(1));
  });

  test('snap comparison is strict at exact snap-distance boundary', () {
    final fixture = _splitReadyGraph(fromBeadCount: 1, toBeadCount: 1);
    final initialEnds = <SourceArachneTransitionEnd2>[_end(30)];
    fixture.up.data.setTransitionEnds(initialEnds);
    final owners = <List<SourceArachneTransitionEnd2>>[initialEnds];

    fixture.graph.applyTransitions(owners, snapDistance: 30);

    // `end_pos < snap_dist` is false at equality, so source inserts a node.
    final mids = fixture.graph.nodes
        .where((node) => node.p.y == 2 && node.p.x != 0 && node.p.x != 100)
        .toList();
    expect(mids, hasLength(1));
    expect(mids.single.p, const SourcePoint2(30, 2));
    expect(mids.single.data.beadCount, 1);
    expect(fixture.graph.edges, hasLength(8));
  });

  test('matching bead count snaps near endpoint without graph mutation', () {
    final fixture = _splitReadyGraph(fromBeadCount: 1, toBeadCount: 2);
    final initialEnds = <SourceArachneTransitionEnd2>[_end(10)];
    fixture.up.data.setTransitionEnds(initialEnds);
    final owners = <List<SourceArachneTransitionEnd2>>[initialEnds];

    fixture.graph.applyTransitions(owners, snapDistance: 20);

    expect(fixture.from.data.transitionRatio, 0);
    expect(fixture.graph.nodes, hasLength(2));
    expect(fixture.graph.edges, hasLength(2));
  });

  test('mismatching endpoint bead count forces split inside snap zone', () {
    final fixture = _splitReadyGraph(fromBeadCount: 2, toBeadCount: 2);
    final initialEnds = <SourceArachneTransitionEnd2>[_end(10)];
    fixture.up.data.setTransitionEnds(initialEnds);
    final owners = <List<SourceArachneTransitionEnd2>>[initialEnds];

    fixture.graph.applyTransitions(owners, snapDistance: 20);

    final mid = fixture.graph.nodes.singleWhere(
      (node) => node.p == const SourcePoint2(10, 2),
    );
    expect(mid.data.beadCount, 1);
    expect(fixture.from.data.transitionRatio, 0.75);
  });

  test('transition ends are stably sorted before sequential source splits', () {
    final fixture = _splitReadyGraph(fromBeadCount: 1, toBeadCount: 1);
    final initialEnds = <SourceArachneTransitionEnd2>[
      _end(70, lowerBeadCount: 1, isLowerEnd: true),
      _end(30, lowerBeadCount: 1, isLowerEnd: false),
    ];
    fixture.up.data.setTransitionEnds(initialEnds);
    final owners = <List<SourceArachneTransitionEnd2>>[initialEnds];

    fixture.graph.applyTransitions(owners, snapDistance: 0);

    final mids = fixture.graph.nodes
        .where((node) => node.p.y == 2 && node.p.x != 0 && node.p.x != 100)
        .toList();
    expect(mids.map((node) => node.p.x), [30, 70]);
    expect(mids.map((node) => node.data.beadCount), [2, 1]);
  });

  test('upper transition end inserts lower bead count plus one', () {
    final fixture = _splitReadyGraph(fromBeadCount: 1, toBeadCount: 1);
    final initialEnds = <SourceArachneTransitionEnd2>[
      _end(40, lowerBeadCount: 3, isLowerEnd: false),
    ];
    fixture.up.data.setTransitionEnds(initialEnds);
    final owners = <List<SourceArachneTransitionEnd2>>[initialEnds];

    fixture.graph.applyTransitions(owners, snapDistance: 0);

    final mid = fixture.graph.nodes.singleWhere(
      (node) => node.p == const SourcePoint2(40, 2),
    );
    expect(mid.data.beadCount, 4);
  });
}
