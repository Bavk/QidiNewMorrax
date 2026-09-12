import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_beading_strategy.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_graph.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_transition_mids.dart';

class _Strategy extends SourceArachneBeadingStrategy2 {
  _Strategy({
    this.optimalResult = 99,
    this.transitionThickness = const <int, int>{},
  }) : super(
          optimalWidth: 100,
          wallSplitMiddleThreshold: 0.5,
          wallAddMiddleThreshold: 0.5,
          defaultTransitionLength: 100,
          transitioningAngle: 1,
          name: 'transition-mid-fixture',
        );

  final int optimalResult;
  final Map<int, int> transitionThickness;
  final List<int> optimalCalls = [];

  @override
  SourceArachneBeading2 compute(int thickness, int beadCount) =>
      SourceArachneBeading2(totalThickness: thickness, leftOver: thickness);

  @override
  int getOptimalBeadCount(int thickness) {
    optimalCalls.add(thickness);
    return optimalResult;
  }

  @override
  int getTransitionThickness(int lowerBeadCount) =>
      transitionThickness[lowerBeadCount] ??
      super.getTransitionThickness(lowerBeadCount);
}

SourceArachneSTHalfEdgeNode2 _node(
  int x,
  int y,
  int radius,
  int beadCount,
) =>
    SourceArachneSTHalfEdgeNode2(
      p: SourcePoint2(x, y),
      data: SourceArachneSkeletalJoint2(
        distanceToBoundary: radius,
        beadCount: beadCount,
      ),
    );

(SourceArachneSTHalfEdge2, SourceArachneSTHalfEdge2) _pair(
  SourceArachneSTHalfEdgeNode2 from,
  SourceArachneSTHalfEdgeNode2 to, {
  bool central = true,
}) {
  final up = SourceArachneSTHalfEdge2()
    ..from = from
    ..to = to;
  final down = SourceArachneSTHalfEdge2()
    ..from = to
    ..to = from;
  up.twin = down;
  down.twin = up;
  up.data.setIsCentral(central);
  down.data.setIsCentral(central);
  return (up, down);
}

void main() {
  test('upward central edge stores ordered transition middles', () {
    final edges = _pair(
      _node(0, 0, 50, 1),
      _node(300, 0, 200, 3),
    );
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..edges.addAll([edges.$1, edges.$2]);
    final strategy = _Strategy();

    final owners = graph.generateTransitionMids(strategy);

    expect(owners, hasLength(1));
    expect(identical(owners.single, edges.$1.data.transitions), isTrue);
    expect(edges.$2.data.hasTransitions(), isFalse);
    expect(
      edges.$1.data.transitions!.map((transition) => transition.pos).toList(),
      [50, 150],
    );
    expect(
      edges.$1.data.transitions!
          .map((transition) => transition.lowerBeadCount)
          .toList(),
      [1, 2],
    );
    expect(
      edges.$1.data.transitions!
          .map((transition) => transition.featureRadius)
          .toList(),
      [75, 125],
    );
    expect(strategy.optimalCalls, [100, 400]);
  });

  test('transition thickness is clamped to source edge radius endpoints', () {
    final edges = _pair(
      _node(0, 0, 50, 1),
      _node(300, 0, 200, 3),
    );
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..edges.add(edges.$1);
    final strategy = _Strategy(
      transitionThickness: const <int, int>{1: 20, 2: 1000},
    );

    graph.generateTransitionMids(strategy);

    final transitions = edges.$1.data.transitions!;
    expect(transitions.map((transition) => transition.featureRadius), [50, 200]);
    expect(transitions.map((transition) => transition.pos), [0, 300]);
  });

  test('noncentral and equal-bead-count central edges create no storage', () {
    final noncentral = _pair(
      _node(0, 0, 50, 1),
      _node(100, 0, 100, 2),
      central: false,
    );
    final equalCount = _pair(
      _node(200, 0, 50, 2),
      _node(300, 0, 100, 2),
    );
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..edges.addAll([noncentral.$1, equalCount.$1]);

    final owners = graph.generateTransitionMids(_Strategy());

    expect(owners, isEmpty);
    expect(noncentral.$1.data.hasTransitions(), isFalse);
    expect(equalCount.$1.data.hasTransitions(), isFalse);
  });

  test('equal radius with different bead counts hits pinned assert seam', () {
    final edges = _pair(
      _node(0, 0, 50, 1),
      _node(100, 0, 50, 2),
    );
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..edges.add(edges.$1);

    expect(
      () => graph.generateTransitionMids(_Strategy()),
      throwsStateError,
    );
  });

  test('overlap check preserves source logical-or short circuit', () {
    final edges = _pair(
      _node(0, 0, 50, 1),
      _node(100, 0, 100, 2),
    );
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..edges.add(edges.$1);
    final strategy = _Strategy(optimalResult: 0);

    graph.generateTransitionMids(strategy);

    // start_bead_count > optimum is already true, so C++ never evaluates the
    // second side of `||`.
    expect(strategy.optimalCalls, [100]);
    expect(edges.$1.data.transitions, hasLength(1));
  });

  test('midpoint position uses integer truncation after int64 multiply', () {
    final edges = _pair(
      _node(0, 0, 10, 1),
      _node(7, 0, 13, 2),
    );
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..edges.add(edges.$1);
    final strategy = _Strategy(
      transitionThickness: const <int, int>{1: 22},
    );

    graph.generateTransitionMids(strategy);

    // mid_R=11, so source computes int64(7) * 1 / 3 => coord_t 2.
    expect(edges.$1.data.transitions!.single.pos, 2);
    expect(edges.$1.data.transitions!.single.featureRadius, 11);
  });
}
