import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_beading_strategy.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_graph.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_transition_ends.dart';

class _Strategy extends SourceArachneBeadingStrategy2 {
  _Strategy({int transitionLength = 20})
      : super(
          optimalWidth: 100,
          wallSplitMiddleThreshold: 0.5,
          wallAddMiddleThreshold: 0.5,
          defaultTransitionLength: transitionLength,
          transitioningAngle: 1,
          name: 'transition-end-fixture',
        );

  @override
  SourceArachneBeading2 compute(int thickness, int beadCount) =>
      SourceArachneBeading2(totalThickness: thickness, leftOver: thickness);

  @override
  int getOptimalBeadCount(int thickness) => thickness ~/ 100;

  @override
  double getTransitionAnchorPos(int lowerBeadCount) => 0.5;
}

SourceArachneSTHalfEdgeNode2 _node(
  int x,
  int beadCount, {
  required int radius,
  double transitionRatio = 0,
}) =>
    SourceArachneSTHalfEdgeNode2(
      p: SourcePoint2(x, 0),
      data: SourceArachneSkeletalJoint2(
        distanceToBoundary: radius,
        beadCount: beadCount,
        transitionRatio: transitionRatio,
      ),
    );

(SourceArachneSTHalfEdge2, SourceArachneSTHalfEdge2) _pair(
  SourceArachneSTHalfEdgeNode2 from,
  SourceArachneSTHalfEdgeNode2 to, {
  bool central = true,
}) {
  final first = SourceArachneSTHalfEdge2()
    ..from = from
    ..to = to;
  final second = SourceArachneSTHalfEdge2()
    ..from = to
    ..to = from;
  first.twin = second;
  second.twin = first;
  first.data.setIsCentral(central);
  second.data.setIsCentral(central);
  return (first, second);
}

void _radialFan(
  (SourceArachneSTHalfEdge2, SourceArachneSTHalfEdge2) incoming,
  List<(SourceArachneSTHalfEdge2, SourceArachneSTHalfEdge2)> outgoing,
) {
  if (outgoing.isEmpty) return;
  incoming.$1.next = outgoing.first.$1;
  for (var index = 0; index + 1 < outgoing.length; index++) {
    outgoing[index].$2.next = outgoing[index + 1].$1;
  }
  outgoing.last.$2.next = incoming.$2;
}

void main() {
  test('generateTransitionEnds stores lower and upper ends on upward edge', () {
    final edge = _pair(
      _node(0, 1, radius: 50),
      _node(100, 2, radius: 100),
    );
    final graph = SourceArachneSkeletalTrapezoidationGraph2();
    final owners = <List<SourceArachneTransitionEnd2>>[];

    graph.generateTransitionEnds(
      edge.$1,
      50,
      1,
      owners,
      _Strategy(transitionLength: 20),
    );

    expect(owners, hasLength(1));
    expect(identical(owners.single, edge.$1.data.transitionEnds), isTrue);
    expect(edge.$2.data.hasTransitionEnds(), isFalse);
    final ends = edge.$1.data.transitionEnds!;
    expect(ends.map((end) => end.pos), [40, 60]);
    expect(ends.map((end) => end.lowerBeadCount), [1, 1]);
    expect(ends.map((end) => end.isLowerEnd), [true, false]);
  });

  test('generateAllTransitionEnds consumes every ordered transition middle', () {
    final edge = _pair(
      _node(0, 1, radius: 50),
      _node(200, 3, radius: 150),
    );
    edge.$1.data.setTransitions([
      const SourceArachneTransitionMiddle2(
        pos: 50,
        lowerBeadCount: 1,
        featureRadius: 75,
      ),
      const SourceArachneTransitionMiddle2(
        pos: 150,
        lowerBeadCount: 2,
        featureRadius: 125,
      ),
    ]);
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..edges.add(edge.$1);

    final owners = graph.generateAllTransitionEnds(
      _Strategy(transitionLength: 20),
    );

    expect(owners, hasLength(1));
    final ends = edge.$1.data.transitionEnds!;
    expect(ends.map((end) => end.pos), [40, 60, 140, 160]);
    expect(ends.map((end) => end.lowerBeadCount), [1, 1, 2, 2]);
  });

  test('local end on downward half is stored on upward twin with reversed pos', () {
    final edge = _pair(
      _node(0, 2, radius: 100),
      _node(100, 1, radius: 50),
    );
    final graph = SourceArachneSkeletalTrapezoidationGraph2();
    final owners = <List<SourceArachneTransitionEnd2>>[];

    final result = graph.generateTransitionEnd(
      edge.$1,
      10,
      20,
      10,
      0.5,
      0,
      1,
      owners,
      _Strategy(),
    );

    expect(result, isFalse);
    expect(edge.$1.data.hasTransitionEnds(), isFalse);
    expect(edge.$2.data.transitionEnds!.single.pos, 80);
    expect(edge.$2.data.transitionEnds!.single.isLowerEnd, isTrue);
  });

  test('recursive transition end carries float32 rest into junction node', () {
    final edge = _pair(
      _node(0, 1, radius: 50),
      _node(50, 2, radius: 100),
    );
    final continuation = _pair(
      edge.$1.to!,
      _node(150, 2, radius: 150),
    );
    _radialFan(edge, [continuation]);
    final graph = SourceArachneSkeletalTrapezoidationGraph2();
    final owners = <List<SourceArachneTransitionEnd2>>[];

    final onlyGoingDown = graph.generateTransitionEnd(
      edge.$1,
      40,
      70,
      30,
      0.5,
      1.0,
      1,
      owners,
      _Strategy(),
    );

    expect(onlyGoingDown, isFalse);
    expect(continuation.$1.data.transitionEnds!.single.pos, 20);
    expect(edge.$1.to!.data.beadCount, 1);
    expect(
      edge.$1.to!.data.transitionRatio,
      closeTo(0.6666666865348816, 1e-12),
    );
  });

  test('noncentral transition end follows pinned release false path', () {
    final edge = _pair(
      _node(0, 1, radius: 50),
      _node(100, 2, radius: 100),
      central: false,
    );
    final graph = SourceArachneSkeletalTrapezoidationGraph2();

    final result = graph.generateTransitionEnd(
      edge.$1,
      10,
      20,
      10,
      0.5,
      1,
      1,
      <List<SourceArachneTransitionEnd2>>[],
      _Strategy(),
    );

    expect(result, isFalse);
    expect(edge.$1.data.hasTransitionEnds(), isFalse);
  });

  test('transition start beyond edge hits pinned debug assertion seam', () {
    final edge = _pair(
      _node(0, 1, radius: 50),
      _node(100, 2, radius: 100),
    );
    final graph = SourceArachneSkeletalTrapezoidationGraph2();

    expect(
      () => graph.generateTransitionEnd(
        edge.$1,
        101,
        110,
        9,
        0.5,
        1,
        1,
        <List<SourceArachneTransitionEnd2>>[],
        _Strategy(),
      ),
      throwsStateError,
    );
  });

  test('isGoingDown returns true at source boundary radius zero', () {
    final edge = _pair(
      _node(0, 2, radius: 50),
      _node(100, 1, radius: 0),
    );
    final graph = SourceArachneSkeletalTrapezoidationGraph2();

    expect(graph.isGoingDown(edge.$1, 0, 1000, 1), isTrue);
  });

  test('isGoingDown transition-middle distance uses strict less-than', () {
    final edge = _pair(
      _node(0, 1, radius: 50),
      _node(100, 2, radius: 100),
    );
    edge.$1.data.setTransitions([
      const SourceArachneTransitionMiddle2(
        pos: 20,
        lowerBeadCount: 1,
        featureRadius: 75,
      ),
    ]);
    final graph = SourceArachneSkeletalTrapezoidationGraph2();

    expect(graph.isGoingDown(edge.$1, 79, 100, 1), isTrue);
    expect(graph.isGoingDown(edge.$1, 80, 100, 1), isFalse);
  });

  test('isGoingDown equal lower count is blocked by positive transition ratio', () {
    final plain = _pair(
      _node(0, 2, radius: 50),
      _node(10, 1, radius: 60),
    );
    final transitioning = _pair(
      _node(20, 2, radius: 50),
      _node(30, 1, radius: 60, transitionRatio: 0.5),
    );
    final graph = SourceArachneSkeletalTrapezoidationGraph2();

    expect(graph.isGoingDown(plain.$1, 0, 100, 1), isTrue);
    expect(graph.isGoingDown(transitioning.$1, 0, 100, 1), isFalse);
  });

  test('large downward bead-count jump requires transition middle', () {
    final edge = _pair(
      _node(0, 1, radius: 50),
      _node(10, 4, radius: 60),
    );
    final graph = SourceArachneSkeletalTrapezoidationGraph2();

    expect(
      () => graph.isGoingDown(edge.$1, 0, 100, 1),
      throwsStateError,
    );
  });
}
