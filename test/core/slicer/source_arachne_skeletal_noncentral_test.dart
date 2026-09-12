import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_beading_strategy.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_graph.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_noncentral.dart';

class _Strategy extends SourceArachneBeadingStrategy2 {
  _Strategy()
      : super(
          optimalWidth: 10,
          wallSplitMiddleThreshold: 0.4,
          wallAddMiddleThreshold: 0.5,
          defaultTransitionLength: 10,
          transitioningAngle: 1,
          name: 'noncentral-fixture',
        );

  final List<int> calls = [];

  @override
  SourceArachneBeading2 compute(int thickness, int beadCount) =>
      SourceArachneBeading2(totalThickness: thickness, leftOver: thickness);

  @override
  int getOptimalBeadCount(int thickness) {
    calls.add(thickness);
    return thickness ~/ 10;
  }
}

SourceArachneSTHalfEdgeNode2 _node(
  int x,
  int y,
  int radius, {
  int beadCount = -1,
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

(SourceArachneSTHalfEdge2, SourceArachneSTHalfEdge2) _pair(
  SourceArachneSTHalfEdgeNode2 from,
  SourceArachneSTHalfEdgeNode2 to, {
  bool central = false,
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

SourceArachneSkeletalTrapezoidationGraph2 _singleEndGraph(
  (SourceArachneSTHalfEdge2, SourceArachneSTHalfEdge2) end,
) =>
    SourceArachneSkeletalTrapezoidationGraph2()..edges.add(end.$1);

void _attachCandidate(
  (SourceArachneSTHalfEdge2, SourceArachneSTHalfEdge2) end,
  (SourceArachneSTHalfEdge2, SourceArachneSTHalfEdge2) candidate,
) {
  end.$1.next = candidate.$1;
  candidate.$2.next = end.$2;
}

void main() {
  test('same bead count dissolves first upward noncentral edge', () {
    final a = _node(0, 0, 100000, beadCount: 2);
    final b = _node(100000, 0, 200000, beadCount: 2);
    final end = _pair(_node(-100000, 0, 50000), a, central: true);
    final candidate = _pair(a, b);
    _attachCandidate(end, candidate);
    final graph = _singleEndGraph(end);
    final strategy = _Strategy();

    graph.filterNoncentralRegions(strategy);

    expect(candidate.$1.data.isCentral, isTrue);
    expect(candidate.$2.data.isCentral, isTrue);
    expect(b.data.beadCount, 40000);
    expect(b.data.transitionRatio, 0);
    expect(strategy.calls, [400000]);
  });

  test('adjacent bead count dissolves only strictly inside 0.4mm', () {
    final a = _node(0, 0, 100000, beadCount: 2);
    final b = _node(399999, 0, 200000, beadCount: 3);
    final end = _pair(_node(-1, 0, 50000), a, central: true);
    final candidate = _pair(a, b);
    _attachCandidate(end, candidate);
    final strategy = _Strategy();

    _singleEndGraph(end).filterNoncentralRegions(strategy);

    expect(candidate.$1.data.isCentral, isTrue);
    expect(b.data.beadCount, 40000);
  });

  test('0.4mm transition-distance boundary is strict and does not dissolve', () {
    final a = _node(0, 0, 100000, beadCount: 2);
    final b = _node(400000, 0, 200000, beadCount: 3);
    final end = _pair(_node(-1, 0, 50000), a, central: true);
    final candidate = _pair(a, b);
    _attachCandidate(end, candidate);
    final strategy = _Strategy();

    _singleEndGraph(end).filterNoncentralRegions(strategy);

    expect(candidate.$1.data.isCentral, isFalse);
    expect(candidate.$2.data.isCentral, isFalse);
    expect(b.data.beadCount, 3);
    expect(b.data.transitionRatio, 0.75);
    expect(strategy.calls, isEmpty);
  });

  test('unknown bead count recurses and dissolves the whole upward chain', () {
    final a = _node(0, 0, 100000, beadCount: 2);
    final b = _node(100000, 0, 150000);
    final c = _node(200000, 0, 200000, beadCount: 2);
    final end = _pair(_node(-1, 0, 50000), a, central: true);
    final first = _pair(a, b);
    final second = _pair(b, c);
    end.$1.next = first.$1;
    first.$2.next = end.$2;
    first.$1.next = second.$1;
    second.$2.next = first.$2;
    final strategy = _Strategy();

    _singleEndGraph(end).filterNoncentralRegions(strategy);

    expect(first.$1.data.isCentral, isTrue);
    expect(first.$2.data.isCentral, isTrue);
    expect(second.$1.data.isCentral, isTrue);
    expect(second.$2.data.isCentral, isTrue);
    expect(b.data.beadCount, 30000);
    expect(c.data.beadCount, 40000);
    expect(b.data.transitionRatio, 0);
    expect(c.data.transitionRatio, 0);
    expect(strategy.calls, [400000, 300000]);
  });

  test('radial scan skips a longer downward edge before the upward branch', () {
    final a = _node(0, 0, 100000, beadCount: 2);
    final down = _node(20000, 0, 50000, beadCount: 9);
    final up = _node(100000, 0, 200000, beadCount: 2);
    final end = _pair(_node(-1, 0, 50000), a, central: true);
    final downward = _pair(a, down);
    final upward = _pair(a, up);
    end.$1.next = downward.$1;
    downward.$2.next = upward.$1;
    upward.$2.next = end.$2;
    final strategy = _Strategy();

    _singleEndGraph(end).filterNoncentralRegions(strategy);

    expect(downward.$1.data.isCentral, isFalse);
    expect(upward.$1.data.isCentral, isTrue);
    expect(up.data.beadCount, 40000);
  });

  test('exact 0.01mm short downward edge is selected by inclusive helper', () {
    final a = _node(0, 0, 100000, beadCount: 2);
    final shortDown = _node(10000, 0, 50000, beadCount: 2);
    final end = _pair(_node(-1, 0, 50000), a, central: true);
    final candidate = _pair(a, shortDown);
    _attachCandidate(end, candidate);
    final strategy = _Strategy();

    _singleEndGraph(end).filterNoncentralRegions(strategy);

    expect(candidate.$1.data.isCentral, isTrue);
    expect(shortDown.data.beadCount, 10000);
  });

  test('positive-radius central end with unknown bead count hits source assert', () {
    final a = _node(0, 0, 100000);
    final end = _pair(_node(-1, 0, 50000), a, central: true);
    final graph = _singleEndGraph(end);

    expect(
      () => graph.filterNoncentralRegions(_Strategy()),
      throwsStateError,
    );
  });
}
