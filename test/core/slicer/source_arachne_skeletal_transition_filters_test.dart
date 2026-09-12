import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_beading_strategy.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_graph.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_transition_filters.dart';

class _Strategy extends SourceArachneBeadingStrategy2 {
  _Strategy({int transitionLength = 30})
      : super(
          optimalWidth: 100,
          wallSplitMiddleThreshold: 0.5,
          wallAddMiddleThreshold: 0.5,
          defaultTransitionLength: transitionLength,
          transitioningAngle: 1,
          name: 'transition-filter-fixture',
        );

  @override
  SourceArachneBeading2 compute(int thickness, int beadCount) =>
      SourceArachneBeading2(totalThickness: thickness, leftOver: thickness);

  @override
  int getOptimalBeadCount(int thickness) => thickness ~/ 100;
}

SourceArachneSTHalfEdgeNode2 _node(
  int x,
  int beadCount, {
  int? radius,
}) =>
    SourceArachneSTHalfEdgeNode2(
      p: SourcePoint2(x, 0),
      data: SourceArachneSkeletalJoint2(
        distanceToBoundary: radius ?? x.abs(),
        beadCount: beadCount,
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

SourceArachneTransitionMiddle2 _mid(
  int pos,
  int lowerBeadCount,
  int featureRadius,
) =>
    SourceArachneTransitionMiddle2(
      pos: pos,
      lowerBeadCount: lowerBeadCount,
      featureRadius: featureRadius,
    );

void main() {
  test('dissolveBeadCountRegion changes matching central fan recursively', () {
    final center = _node(0, 3);
    final incoming = _pair(_node(-10, 1), center);
    final matching = _pair(center, _node(10, 3));
    final different = _pair(center, _node(20, 4));
    final noncentral = _pair(center, _node(30, 3), central: false);
    _radialFan(incoming, [matching, different, noncentral]);
    final graph = SourceArachneSkeletalTrapezoidationGraph2();

    graph.dissolveBeadCountRegion(incoming.$1, 3, 2);

    expect(center.data.beadCount, 2);
    expect(matching.$1.to!.data.beadCount, 2);
    expect(different.$1.to!.data.beadCount, 4);
    expect(noncentral.$1.to!.data.beadCount, 3);
  });

  test('dissolveBeadCountRegion returns immediately on start-count mismatch', () {
    final center = _node(0, 4);
    final incoming = _pair(_node(-10, 1), center);
    final matching = _pair(center, _node(10, 3));
    _radialFan(incoming, [matching]);
    final graph = SourceArachneSkeletalTrapezoidationGraph2();

    graph.dissolveBeadCountRegion(incoming.$1, 3, 2);

    expect(center.data.beadCount, 4);
    expect(matching.$1.to!.data.beadCount, 3);
  });

  test('dissolveBeadCountRegion rejects identical source counts', () {
    final incoming = _pair(_node(-10, 1), _node(0, 3));
    final graph = SourceArachneSkeletalTrapezoidationGraph2();

    expect(
      () => graph.dissolveBeadCountRegion(incoming.$1, 3, 3),
      throwsStateError,
    );
  });

  test('filterEndOfCentralTransition dissolves boundary strictly inside range', () {
    final end = _pair(_node(-10, 1), _node(0, 3));
    final graph = SourceArachneSkeletalTrapezoidationGraph2();

    final dissolved = graph.filterEndOfCentralTransition(end.$1, 9, 10, 2);

    expect(dissolved, isTrue);
    expect(end.$1.to!.data.beadCount, 2);
  });

  test('filterEndOfCentralTransition keeps exact max-distance boundary', () {
    final end = _pair(_node(-10, 1), _node(0, 3));
    final graph = SourceArachneSkeletalTrapezoidationGraph2();

    final dissolved = graph.filterEndOfCentralTransition(end.$1, 10, 10, 2);

    expect(dissolved, isFalse);
    expect(end.$1.to!.data.beadCount, 3);
  });

  test('filterEndOfCentralTransition rejects already-over-range traversal', () {
    final end = _pair(_node(-10, 1), _node(0, 3));
    final graph = SourceArachneSkeletalTrapezoidationGraph2();

    final dissolved = graph.filterEndOfCentralTransition(end.$1, 11, 10, 2);

    expect(dissolved, isFalse);
    expect(end.$1.to!.data.beadCount, 3);
  });

  test('filterEndOfCentralTransition propagates dissolve back through branch', () {
    final center = _node(0, 3);
    final incoming = _pair(_node(-10, 1), center);
    final branch = _pair(center, _node(4, 3));
    _radialFan(incoming, [branch]);
    final graph = SourceArachneSkeletalTrapezoidationGraph2();

    final dissolved = graph.filterEndOfCentralTransition(
      incoming.$1,
      2,
      10,
      2,
    );

    expect(dissolved, isTrue);
    expect(branch.$1.to!.data.beadCount, 2);
    expect(center.data.beadCount, 2);
  });

  test('dissolveNearbyTransitions returns aligned transition by identity', () {
    final center = _node(0, 2, radius: 100);
    final incoming = _pair(_node(-10, 1, radius: 50), center);
    final candidate = _pair(center, _node(100, 3, radius: 200));
    _radialFan(incoming, [candidate]);
    final target = _mid(20, 2, 150);
    candidate.$1.data.setTransitions([target]);
    final origin = _mid(50, 2, 100);
    final graph = SourceArachneSkeletalTrapezoidationGraph2();

    final refs = graph.dissolveNearbyTransitions(
      incoming.$1,
      origin,
      10,
      100,
      false,
      100,
      _Strategy(),
    );

    expect(refs, hasLength(1));
    expect(identical(refs.single.edge, candidate.$1), isTrue);
    expect(identical(refs.single.transition, target), isTrue);
  });

  test('nearby transition uses strict traveled plus pos less-than max', () {
    final center = _node(0, 2, radius: 100);
    final incoming = _pair(_node(-10, 1, radius: 50), center);
    final candidate = _pair(center, _node(100, 3, radius: 200));
    _radialFan(incoming, [candidate]);
    candidate.$1.data.setTransitions([_mid(20, 2, 150)]);
    final graph = SourceArachneSkeletalTrapezoidationGraph2();

    final refs = graph.dissolveNearbyTransitions(
      incoming.$1,
      _mid(50, 2, 100),
      80,
      100,
      false,
      100,
      _Strategy(),
    );

    expect(refs, isEmpty);
  });

  test('downward candidate resolves storage and reversed pos on upward twin', () {
    final center = _node(0, 3, radius: 200);
    final incoming = _pair(_node(-10, 4, radius: 250), center);
    final downward = _pair(center, _node(100, 2, radius: 100));
    _radialFan(incoming, [downward]);
    final target = _mid(30, 2, 150);
    downward.$2.data.setTransitions([target]);
    final graph = SourceArachneSkeletalTrapezoidationGraph2();

    final refs = graph.dissolveNearbyTransitions(
      incoming.$1,
      _mid(50, 2, 200),
      10,
      100,
      true,
      100,
      _Strategy(),
    );

    // Downward travel sees upward pos=30 as 100-30=70; 10+70 < 100.
    expect(refs, hasLength(1));
    expect(identical(refs.single.edge, downward.$2), isTrue);
    expect(identical(refs.single.transition, target), isTrue);
  });

  test('line-width deviation parity controls nearby dissolve eligibility', () {
    final center = _node(0, 2, radius: 100);
    final incoming = _pair(_node(-10, 1, radius: 50), center);
    final candidate = _pair(center, _node(100, 3, radius: 200));
    _radialFan(incoming, [candidate]);
    candidate.$1.data.setTransitions([_mid(50, 1, 150)]);
    final graph = SourceArachneSkeletalTrapezoidationGraph2();

    final refs = graph.dissolveNearbyTransitions(
      incoming.$1,
      _mid(0, 1, 120),
      20,
      100,
      true,
      39,
      _Strategy(transitionLength: 10),
    );

    // lower count 1 is odd and going_up=true => full width deviation:
    // abs(120-100)*2 = 40 > allowed 39.
    expect(refs, isEmpty);
  });

  test('nearby transition search recurses through central edge without mids', () {
    final center = _node(0, 2, radius: 100);
    final incoming = _pair(_node(-10, 1, radius: 50), center);
    final first = _pair(center, _node(40, 2, radius: 140));
    final second = _pair(first.$1.to!, _node(80, 3, radius: 180));
    _radialFan(incoming, [first]);
    _radialFan(first, [second]);
    final target = _mid(10, 2, 160);
    second.$1.data.setTransitions([target]);
    final graph = SourceArachneSkeletalTrapezoidationGraph2();

    final refs = graph.dissolveNearbyTransitions(
      incoming.$1,
      _mid(0, 2, 100),
      0,
      100,
      false,
      100,
      _Strategy(),
    );

    expect(refs, hasLength(1));
    expect(identical(refs.single.transition, target), isTrue);
  });

  test('filterTransitionMids removes back transition near central end', () {
    final edge = _pair(
      _node(0, 1, radius: 50),
      _node(100, 2, radius: 100),
    );
    edge.$1.data.setTransitions([_mid(90, 1, 95)]);
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..edges.add(edge.$1);

    graph.filterTransitionMids(
      _Strategy(transitionLength: 30),
      transitionFilterDistance: 1000,
      allowedFilterDeviation: 1000,
    );

    expect(edge.$1.data.transitions, isEmpty);
    expect(edge.$1.to!.data.beadCount, 1);
  });

  test('filterTransitionMids removes front transition near central end', () {
    final edge = _pair(
      _node(0, 1, radius: 50),
      _node(100, 2, radius: 100),
    );
    edge.$1.data.setTransitions([_mid(10, 1, 55)]);
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..edges.add(edge.$1);

    graph.filterTransitionMids(
      _Strategy(transitionLength: 30),
      transitionFilterDistance: 1000,
      allowedFilterDeviation: 1000,
    );

    expect(edge.$1.data.transitions, isEmpty);
    expect(edge.$1.from!.data.beadCount, 2);
  });

  test('filterTransitionMids erases neighbor by identity before origin pop', () {
    final edge = _pair(
      _node(0, 1, radius: 50),
      _node(100, 2, radius: 100),
    );
    final origin = _mid(50, 1, 100);
    edge.$1.data.setTransitions([origin]);

    final neighbor = _pair(
      edge.$1.to!,
      _node(200, 2, radius: 150),
    );
    final nearby = _mid(20, 1, 120);
    neighbor.$1.data.setTransitions([nearby]);
    _radialFan(edge, [neighbor]);

    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..edges.addAll([edge.$1, neighbor.$1]);

    graph.filterTransitionMids(
      _Strategy(transitionLength: 30),
      transitionFilterDistance: 200,
      allowedFilterDeviation: 1000,
    );

    expect(edge.$1.data.transitions, isEmpty);
    expect(neighbor.$1.data.transitions, isEmpty);
    expect(edge.$1.to!.data.beadCount, 1);
    expect(neighbor.$1.to!.data.beadCount, 1);
  });
}
