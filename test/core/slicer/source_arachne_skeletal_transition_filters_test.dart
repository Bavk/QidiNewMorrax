import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_graph.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_transition_filters.dart';

SourceArachneSTHalfEdgeNode2 _node(int x, int beadCount) =>
    SourceArachneSTHalfEdgeNode2(
      p: SourcePoint2(x, 0),
      data: SourceArachneSkeletalJoint2(
        distanceToBoundary: x.abs(),
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

    // Branch recursion reaches 2 + length(4) = 6 < 10 and dissolves. The
    // result propagates back and replaces the incoming target count as well.
    expect(dissolved, isTrue);
    expect(branch.$1.to!.data.beadCount, 2);
    expect(center.data.beadCount, 2);
  });
}
