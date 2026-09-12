import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_beading_strategy.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_bead_count.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_graph.dart';

class _CountingStrategy extends SourceArachneBeadingStrategy2 {
  _CountingStrategy()
      : super(
          optimalWidth: 10,
          wallSplitMiddleThreshold: 0.4,
          wallAddMiddleThreshold: 0.5,
          defaultTransitionLength: 10,
          transitioningAngle: 1,
          name: 'counting-fixture',
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

SourceArachneSTHalfEdgeNode2 _node(int x, int y, int distance) =>
    SourceArachneSTHalfEdgeNode2(
      p: SourcePoint2(x, y),
      data: SourceArachneSkeletalJoint2(distanceToBoundary: distance),
    );

(SourceArachneSTHalfEdge2, SourceArachneSTHalfEdge2) _pair(
  SourceArachneSTHalfEdgeNode2 from,
  SourceArachneSTHalfEdgeNode2 to,
) {
  final first = SourceArachneSTHalfEdge2()
    ..from = from
    ..to = to;
  final second = SourceArachneSTHalfEdge2()
    ..from = to
    ..to = from;
  first.twin = second;
  second.twin = first;
  return (first, second);
}

void _setCentral(
  (SourceArachneSTHalfEdge2, SourceArachneSTHalfEdge2) pair,
  bool central,
) {
  pair.$1.data.setIsCentral(central);
  pair.$2.data.setIsCentral(central);
}

void main() {
  test('central edge assigns bead count from doubled target radius', () {
    final centralTarget = _node(10, 0, 25);
    final ignoredTarget = _node(30, 0, 40);
    final central = _pair(_node(0, 0, 10), centralTarget);
    final ignored = _pair(_node(20, 0, 10), ignoredTarget);
    _setCentral(central, true);
    _setCentral(ignored, false);
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..edges.addAll([central.$1, ignored.$1]);
    final strategy = _CountingStrategy();

    graph.updateBeadCount(strategy);

    expect(centralTarget.data.beadCount, 5);
    expect(ignoredTarget.data.beadCount, -1);
    expect(strategy.calls, [50]);
  });

  test('local maximum receives bead count even without central incoming edge', () {
    final maximum = _node(0, 0, 30);
    final downhill = _pair(maximum, _node(10, 0, 20));
    _setCentral(downhill, false);
    downhill.$2.next = downhill.$1;
    maximum.incidentEdge = downhill.$1;
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..edges.addAll([downhill.$1, downhill.$2])
      ..nodes.add(maximum);
    final strategy = _CountingStrategy();

    expect(maximum.isLocalMaximum(), isTrue);
    graph.updateBeadCount(strategy);

    expect(maximum.data.beadCount, 6);
    expect(strategy.calls, [60]);
  });

  test('negative local-maximum radius is reconstructed from radial neighbor', () {
    final maximum = _node(0, 0, -1);
    final downhill = _pair(maximum, _node(10, 0, -2));
    _setCentral(downhill, false);
    downhill.$2.next = downhill.$1;
    maximum.incidentEdge = downhill.$1;
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..edges.addAll([downhill.$1, downhill.$2])
      ..nodes.add(maximum);
    final strategy = _CountingStrategy();

    expect(maximum.isLocalMaximum(), isTrue);
    graph.updateBeadCount(strategy);

    // Source starts at coord_t::max and takes min(neighbor radius + edge norm):
    // -2 + 10 = 8, then asks the strategy for thickness 16.
    expect(maximum.data.distanceToBoundary, 8);
    expect(maximum.data.beadCount, 1);
    expect(strategy.calls, [16]);
  });

  test('zero-distance boundary node is not treated as local maximum', () {
    final boundary = _node(0, 0, 0);
    final downhill = _pair(boundary, _node(10, 0, -1));
    _setCentral(downhill, false);
    downhill.$2.next = downhill.$1;
    boundary.incidentEdge = downhill.$1;
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..edges.addAll([downhill.$1, downhill.$2])
      ..nodes.add(boundary);
    final strategy = _CountingStrategy();

    graph.updateBeadCount(strategy);

    expect(boundary.data.beadCount, -1);
    expect(strategy.calls, isEmpty);
  });
}
