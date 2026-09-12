import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_beading_strategy.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_graph.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_noncentral.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths.dart';

class _Strategy extends SourceArachneBeadingStrategy2 {
  _Strategy()
      : super(
          optimalWidth: 20,
          wallSplitMiddleThreshold: 0.4,
          wallAddMiddleThreshold: 0.5,
          defaultTransitionLength: 100,
          transitioningAngle: 1,
          name: 'noncentral-fixture',
        );

  @override
  SourceArachneBeading2 compute(int thickness, int beadCount) =>
      SourceArachneBeading2(totalThickness: thickness, leftOver: thickness);

  @override
  int getOptimalBeadCount(int thickness) => thickness ~/ 20;
}

SourceArachneSTHalfEdgeNode2 _node(
  int x,
  int radius,
  int beadCount, {
  double transitionRatio = 0.75,
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
  required bool central,
}) {
  final edge = SourceArachneSTHalfEdge2()
    ..from = from
    ..to = to;
  final twin = SourceArachneSTHalfEdge2()
    ..from = to
    ..to = from;
  edge.twin = twin;
  twin.twin = edge;
  edge.data.setIsCentral(central);
  twin.data.setIsCentral(central);
  return (edge, twin);
}

void _linkAtEnd(
  (SourceArachneSTHalfEdge2, SourceArachneSTHalfEdge2) incoming,
  (SourceArachneSTHalfEdge2, SourceArachneSTHalfEdge2) outgoing,
) {
  incoming.$1.next = outgoing.$1;
  outgoing.$2.next = incoming.$2;
}

SourceArachneSkeletalTrapezoidationGraph2 _graph(
  Iterable<(SourceArachneSTHalfEdge2, SourceArachneSTHalfEdge2)> pairs,
) {
  final graph = SourceArachneSkeletalTrapezoidationGraph2();
  for (final pair in pairs) {
    graph.edges.addAll([pair.$1, pair.$2]);
  }
  return graph;
}

void main() {
  test('same bead-count noncentral edge is dissolved and recomputed', () {
    final boundary = _node(-10, 10, 1);
    final startNode = _node(0, 20, 2);
    final upper = _node(10000, 30, 2);
    final start = _pair(boundary, startNode, central: true);
    final candidate = _pair(startNode, upper, central: false);
    _linkAtEnd(start, candidate);
    final graph = _graph([start, candidate]);

    graph.filterNoncentralRegions(_Strategy());

    expect(candidate.$1.data.isCentral, isTrue);
    expect(candidate.$2.data.isCentral, isTrue);
    expect(upper.data.beadCount, 3);
    expect(upper.data.transitionRatio, 0);
  });

  test('uninitialized chain dissolves recursively and unwinds both edges', () {
    final startNode = _node(0, 20, 2);
    final middle = _node(1000, 25, -1);
    final upper = _node(2000, 30, 2);
    final start = _pair(_node(-1000, 10, 1), startNode, central: true);
    final first = _pair(startNode, middle, central: false);
    final second = _pair(middle, upper, central: false);
    _linkAtEnd(start, first);
    _linkAtEnd(first, second);
    final graph = _graph([start, first, second]);

    graph.filterNoncentralRegions(_Strategy());

    expect(first.$1.data.isCentral, isTrue);
    expect(first.$2.data.isCentral, isTrue);
    expect(second.$1.data.isCentral, isTrue);
    expect(second.$2.data.isCentral, isTrue);
    expect(middle.data.beadCount, 2);
    expect(upper.data.beadCount, 3);
    expect(middle.data.transitionRatio, 0);
    expect(upper.data.transitionRatio, 0);
  });

  test('different adjacent count dissolves only strictly below 0.4mm', () {
    final maxDist =
        SourceArachneWallToolPathsPreprocess2.scaleDouble(0.4);

    SourceArachneSTHalfEdge2 run(int length) {
      final startNode = _node(0, 20, 2);
      final upper = _node(length, 30, 3);
      final start = _pair(_node(-10, 10, 1), startNode, central: true);
      final candidate = _pair(startNode, upper, central: false);
      _linkAtEnd(start, candidate);
      _graph([start, candidate]).filterNoncentralRegions(_Strategy());
      return candidate.$1;
    }

    expect(run(maxDist - 1).data.isCentral, isTrue);
    expect(run(maxDist).data.isCentral, isFalse);
  });

  test('bead-count jump larger than one is not dissolved', () {
    final startNode = _node(0, 20, 2);
    final upper = _node(100, 30, 4);
    final start = _pair(_node(-10, 10, 1), startNode, central: true);
    final candidate = _pair(startNode, upper, central: false);
    _linkAtEnd(start, candidate);
    final graph = _graph([start, candidate]);

    graph.filterNoncentralRegions(_Strategy());

    expect(candidate.$1.data.isCentral, isFalse);
    expect(upper.data.beadCount, 4);
    expect(upper.data.transitionRatio, 0.75);
  });

  test('shorter_then 0.01mm boundary admits a downward tiny edge', () {
    final tiny = SourceArachneWallToolPathsPreprocess2.scaleDouble(0.01);

    SourceArachneSTHalfEdge2 run(int length) {
      final startNode = _node(0, 20, 2);
      final lower = _node(length, 10, 2);
      final start = _pair(_node(-10, 10, 1), startNode, central: true);
      final candidate = _pair(startNode, lower, central: false);
      _linkAtEnd(start, candidate);
      _graph([start, candidate]).filterNoncentralRegions(_Strategy());
      return candidate.$1;
    }

    expect(run(tiny).data.isCentral, isTrue);
    expect(run(tiny + 1).data.isCentral, isFalse);
  });
}
