import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_graph.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_graph_mutations.dart';

SourceArachneSTHalfEdgeNode2 n(int x, int y, {int distance = -1}) =>
    SourceArachneSTHalfEdgeNode2(
      p: SourcePoint2(x, y),
      data: SourceArachneSkeletalJoint2(distanceToBoundary: distance),
    );

(SourceArachneSTHalfEdge2, SourceArachneSTHalfEdge2) twins(
  SourceArachneSTHalfEdgeNode2 a,
  SourceArachneSTHalfEdgeNode2 b,
) {
  final first = SourceArachneSTHalfEdge2()
    ..from = a
    ..to = b;
  final second = SourceArachneSTHalfEdge2()
    ..from = b
    ..to = a;
  first.twin = second;
  second.twin = first;
  return (first, second);
}

void main() {
  test('getSource walks prev and next to full source segment endpoints', () {
    final graph = SourceArachneSkeletalTrapezoidationGraph2();
    final a = n(0, 0);
    final b = n(10, 0);
    final c = n(20, 5);
    final d = n(30, 5);
    final before = SourceArachneSTHalfEdge2()
      ..from = a
      ..to = b;
    final middle = SourceArachneSTHalfEdge2()
      ..from = b
      ..to = c;
    final after = SourceArachneSTHalfEdge2()
      ..from = c
      ..to = d;
    before.next = middle;
    middle
      ..prev = before
      ..next = after;
    after.prev = middle;

    final source = graph.getSource(middle);
    expect(source.a, const SourcePoint2(0, 0));
    expect(source.b, const SourcePoint2(30, 5));
  });

  test('makeRib projects with coord_t truncation and prepends EXTRA_VD pair', () {
    final graph = SourceArachneSkeletalTrapezoidationGraph2();
    final a = n(0, 0);
    final b = n(2, 2);
    final previous = SourceArachneSTHalfEdge2()
      ..from = a
      ..to = b;
    previous.data.setHoleCompensationFlag(true);
    graph
      ..nodes.addAll([a, b])
      ..edges.add(previous);

    final back = graph.makeRib(
      previous,
      const SourcePoint2(0, 0),
      const SourcePoint2(5, 2),
      isNextToStartOrEnd: true,
    );

    // Infinite projection is (2.413..., 0.965...), then Eigen cast<coord_t>
    // truncates toward zero to (2, 0). Distance is computed from that point.
    expect(b.data.distanceToBoundary, 2);
    expect(graph.nodes.first.p, const SourcePoint2(2, 0));
    expect(graph.nodes.first.data.distanceToBoundary, 0);
    expect(graph.edges, hasLength(3));
    expect(graph.edges[0], same(back));
    expect(graph.edges[1].data.type, SourceArachneSkeletalEdgeType2.extraVd);
    expect(graph.edges[0].data.type, SourceArachneSkeletalEdgeType2.extraVd);
    expect(graph.edges[0].data.holeCompensationFlag, isTrue);
    expect(graph.edges[1].data.holeCompensationFlag, isTrue);
    expect(previous.next, same(graph.edges[1]));
    expect(graph.edges[1].prev, same(previous));
    expect(graph.edges[1].twin, same(back));
    expect(back.twin, same(graph.edges[1]));
    expect(back.from, same(graph.nodes.first));
    expect(back.to, same(b));
    expect(graph.nodes.first.incidentEdge, same(back));
  });

  test('insertRib splits one side and creates transition-end rib pair', () {
    final graph = SourceArachneSkeletalTrapezoidationGraph2();
    final a = n(0, 0);
    final b = n(5, 2);
    final mid = n(2, 2);
    final edge = SourceArachneSTHalfEdge2()
      ..from = a
      ..to = b;
    edge.data.setHoleCompensationFlag(true);
    graph
      ..nodes.addAll([a, b, mid])
      ..edges.add(edge);

    final result = graph.insertRib(edge, mid);

    expect(mid.data.distanceToBoundary, 2);
    expect(mid.data.transitionRatio, 0);
    expect(graph.nodes.last.p, const SourcePoint2(2, 0));
    expect(graph.nodes.last.data.distanceToBoundary, 0);
    expect(graph.edges, hasLength(4));

    final first = result.first;
    final second = result.second;
    final outward = first.next!;
    final inward = second.prev!;
    expect(first, same(edge));
    expect(first.from, same(a));
    expect(first.to, same(mid));
    expect(second.from, same(mid));
    expect(second.to, same(b));
    expect(outward.data.type, SourceArachneSkeletalEdgeType2.transitionEnd);
    expect(inward.data.type, SourceArachneSkeletalEdgeType2.transitionEnd);
    expect(outward.from, same(mid));
    expect(outward.to, same(graph.nodes.last));
    expect(inward.from, same(graph.nodes.last));
    expect(inward.to, same(mid));
    expect(outward.twin, same(inward));
    expect(inward.twin, same(outward));
    expect(first.twin, isNull);
    expect(second.twin, isNull);
    expect(first.data.isCentral, isTrue);
    expect(second.data.isCentral, isTrue);
    expect(outward.data.isCentral, isFalse);
    expect(inward.data.isCentral, isFalse);
    expect(first.data.holeCompensationFlag, isTrue);
    expect(second.data.holeCompensationFlag, isTrue);
  });

  test('insertNode splits both twins and reconnects four central halves', () {
    final graph = SourceArachneSkeletalTrapezoidationGraph2();
    final a = n(0, 0);
    final b = n(5, 2);
    final pair = twins(a, b);
    pair.$1.data.setHoleCompensationFlag(true);
    pair.$2.data.setHoleCompensationFlag(true);
    graph
      ..nodes.addAll([a, b])
      ..edges.addAll([pair.$1, pair.$2]);

    final returned = graph.insertNode(
      pair.$1,
      const SourcePoint2(2, 2),
      3,
    );

    expect(graph.nodes, hasLength(5));
    expect(graph.edges, hasLength(8));
    final mid = graph.nodes[2];
    expect(mid.p, const SourcePoint2(2, 2));
    expect(mid.data.distanceToBoundary, 2);
    expect(mid.data.beadCount, 3);

    final leftFirst = pair.$1;
    final rightFirst = pair.$2;
    expect(leftFirst.from, same(a));
    expect(leftFirst.to, same(mid));
    expect(rightFirst.from, same(b));
    expect(rightFirst.to, same(mid));

    expect(returned.from, same(mid));
    expect(returned.to, same(b));
    expect(returned.twin, same(rightFirst));
    expect(rightFirst.twin, same(returned));
    expect(leftFirst.twin, isNotNull);
    expect(leftFirst.twin!.from, same(mid));
    expect(leftFirst.twin!.to, same(a));
    expect(leftFirst.twin!.twin, same(leftFirst));

    // Each side gets its own source projection node exactly like source.
    expect(graph.nodes[3].p, const SourcePoint2(2, 0));
    expect(graph.nodes[4].p, const SourcePoint2(2, 0));
  });

  test('insertRib reconnects existing prev/next chain around new halves', () {
    final graph = SourceArachneSkeletalTrapezoidationGraph2();
    final a = n(-5, 0);
    final b = n(0, 0);
    final c = n(5, 2);
    final d = n(10, 2);
    final mid = n(2, 2);
    final before = SourceArachneSTHalfEdge2()
      ..from = a
      ..to = b;
    final target = SourceArachneSTHalfEdge2()
      ..from = b
      ..to = c;
    final after = SourceArachneSTHalfEdge2()
      ..from = c
      ..to = d;
    before.next = target;
    target
      ..prev = before
      ..next = after;
    after.prev = target;
    graph
      ..nodes.addAll([a, b, c, d, mid])
      ..edges.addAll([before, target, after]);

    final result = graph.insertRib(target, mid);

    expect(before.next, same(result.first));
    expect(result.first.prev, same(before));
    expect(result.second.next, same(after));
    expect(after.prev, same(result.second));
    expect(c.incidentEdge, same(after));
  });
}
