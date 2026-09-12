import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_beading_strategy.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_graph.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_initialization.dart';

SourceArachneSTHalfEdgeNode2 node(int x, int y) =>
    SourceArachneSTHalfEdgeNode2(p: SourcePoint2(x, y));

(SourceArachneSTHalfEdge2, SourceArachneSTHalfEdge2) twins(
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

void main() {
  test('pointy quad split clones only the second shared start node', () {
    final shared = node(0, 0);
    shared.data
      ..distanceToBoundary = 123
      ..beadCount = 4
      ..transitionRatio = 0.25;
    final propagation = SourceArachneBeadingPropagation2(
      SourceArachneBeading2(totalThickness: 100, leftOver: 100),
    );
    shared.data.setBeading(propagation);

    final a = node(10, 0);
    final b = node(0, 10);
    final firstPair = twins(shared, a);
    final secondPair = twins(shared, b);
    shared.incidentEdge = firstPair.$1;

    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..nodes.addAll([shared, a, b])
      ..edges.addAll([
        firstPair.$1,
        firstPair.$2,
        secondPair.$1,
        secondPair.$2,
      ]);

    graph.separatePointyQuadEndNodes();

    expect(graph.nodes, hasLength(4));
    final clone = graph.nodes.last;
    expect(firstPair.$1.from, same(shared));
    expect(secondPair.$1.from, same(clone));
    expect(secondPair.$2.to, same(clone));
    expect(clone.p, shared.p);
    expect(clone.data.distanceToBoundary, 123);
    expect(clone.data.beadCount, 4);
    expect(clone.data.transitionRatio, 0.25);
    expect(clone.data.beading, same(propagation));
    expect(clone.incidentEdge, same(secondPair.$1));
    expect(shared.incidentEdge, same(firstPair.$1));
  });

  test('pointy quad split clones every start after the first identity hit', () {
    final shared = node(0, 0);
    final ends = [node(10, 0), node(0, 10), node(-10, 0)];
    final pairs = [for (final end in ends) twins(shared, end)];
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..nodes.addAll([shared, ...ends]);
    for (final pair in pairs) {
      graph.edges.addAll([pair.$1, pair.$2]);
    }

    graph.separatePointyQuadEndNodes();

    expect(graph.nodes, hasLength(6));
    expect(pairs[0].$1.from, same(shared));
    expect(pairs[1].$1.from, same(graph.nodes[4]));
    expect(pairs[2].$1.from, same(graph.nodes[5]));
    expect(pairs[1].$2.to, same(graph.nodes[4]));
    expect(pairs[2].$2.to, same(graph.nodes[5]));
  });

  test('non-start edge sharing a from node does not trigger pointy split', () {
    final shared = node(0, 0);
    final a = node(10, 0);
    final b = node(0, 10);
    final firstPair = twins(shared, a);
    final secondPair = twins(shared, b);
    secondPair.$1.prev = firstPair.$1;

    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..nodes.addAll([shared, a, b])
      ..edges.addAll([
        firstPair.$1,
        firstPair.$2,
        secondPair.$1,
        secondPair.$2,
      ]);

    graph.separatePointyQuadEndNodes();

    expect(graph.nodes, hasLength(3));
    expect(secondPair.$1.from, same(shared));
  });

  test('incident normalization assigns every chain start from node', () {
    final a = node(0, 0);
    final b = node(10, 0);
    final c = node(20, 0);
    final first = SourceArachneSTHalfEdge2()
      ..from = a
      ..to = b;
    final second = SourceArachneSTHalfEdge2()
      ..from = b
      ..to = c
      ..prev = first;
    final otherStart = SourceArachneSTHalfEdge2()
      ..from = b
      ..to = a;
    a.incidentEdge = second;
    b.incidentEdge = second;

    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..nodes.addAll([a, b, c])
      ..edges.addAll([first, second, otherStart]);

    graph.normalizeStartIncidentEdges();

    expect(a.incidentEdge, same(first));
    // Source iterates in edge-list order; the later chain start wins if two
    // different starts still share this node before pointy separation.
    expect(b.incidentEdge, same(otherStart));
  });

  test('pointy split rejects malformed start without twin at assertion seam', () {
    final shared = node(0, 0);
    final first = SourceArachneSTHalfEdge2()
      ..from = shared
      ..to = node(1, 0);
    final malformed = SourceArachneSTHalfEdge2()
      ..from = shared
      ..to = node(0, 1);
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..nodes.add(shared)
      ..edges.addAll([first, malformed]);

    expect(() => graph.separatePointyQuadEndNodes(), throwsStateError);
  });
}
