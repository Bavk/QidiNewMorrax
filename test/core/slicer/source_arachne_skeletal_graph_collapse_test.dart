import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_graph.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_graph_collapse.dart';

SourceArachneSTHalfEdgeNode2 node(int x, int y) =>
    SourceArachneSTHalfEdgeNode2(p: SourcePoint2(x, y));

(SourceArachneSTHalfEdge2, SourceArachneSTHalfEdge2) twinPair(
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

({
  SourceArachneSTHalfEdge2 start,
  SourceArachneSTHalfEdge2 middle,
  SourceArachneSTHalfEdge2 end,
  SourceArachneSTHalfEdge2 startTwin,
  SourceArachneSTHalfEdge2 middleTwin,
  SourceArachneSTHalfEdge2 endTwin,
  SourceArachneSTHalfEdgeNode2 a,
  SourceArachneSTHalfEdgeNode2 b,
  SourceArachneSTHalfEdgeNode2 c,
  SourceArachneSTHalfEdgeNode2 d,
}) threeEdgeCell() {
  final a = node(0, 0);
  final b = node(1000, 0);
  final c = node(1003, 4);
  final d = node(3000, 0);
  final startPair = twinPair(a, b);
  final middlePair = twinPair(b, c);
  final endPair = twinPair(c, d);

  final start = startPair.$1;
  final middle = middlePair.$1;
  final end = endPair.$1;
  final startTwin = startPair.$2;
  final middleTwin = middlePair.$2;
  final endTwin = endPair.$2;

  start.next = middle;
  middle
    ..prev = start
    ..next = end;
  end.prev = middle;

  // Opposite side of the same source cell.
  endTwin.next = middleTwin;
  middleTwin
    ..prev = endTwin
    ..next = startTwin;
  startTwin.prev = middleTwin;

  // Keep the opposite chain from becoming another outer-loop start after the
  // represented collapse. It may belong to an adjacent source cell.
  endTwin.prev = SourceArachneSTHalfEdge2();

  b.incidentEdge = middle;
  c.incidentEdge = end;

  return (
    start: start,
    middle: middle,
    end: end,
    startTwin: startTwin,
    middleTwin: middleTwin,
    endTwin: endTwin,
    a: a,
    b: b,
    c: c,
    d: d,
  );
}

({
  SourceArachneSTHalfEdge2 start,
  SourceArachneSTHalfEdge2 end,
  SourceArachneSTHalfEdge2 startTwin,
  SourceArachneSTHalfEdge2 endTwin,
  SourceArachneSTHalfEdgeNode2 a,
  SourceArachneSTHalfEdgeNode2 b,
  SourceArachneSTHalfEdgeNode2 c,
  SourceArachneSTHalfEdgeNode2 d,
}) twoEdgeCell({
  required int ax,
  required int ay,
  required int bx,
  required int by,
  required int cx,
  required int cy,
  required int dx,
  required int dy,
}) {
  final a = node(ax, ay);
  final b = node(bx, by);
  final c = node(cx, cy);
  final d = node(dx, dy);
  final startPair = twinPair(a, b);
  final endPair = twinPair(c, d);
  final start = startPair.$1;
  final end = endPair.$1;
  final startTwin = startPair.$2;
  final endTwin = endPair.$2;

  start.next = end;
  end.prev = start;
  endTwin.next = startTwin;
  startTwin.prev = endTwin;

  // Represents attachment to a neighboring cell and prevents the opposite
  // side from being treated as another chain start in this isolated fixture.
  endTwin.prev = SourceArachneSTHalfEdge2();

  a.incidentEdge = start;
  b.incidentEdge = startTwin;
  c.incidentEdge = end;
  d.incidentEdge = endTwin;

  return (
    start: start,
    end: end,
    startTwin: startTwin,
    endTwin: endTwin,
    a: a,
    b: b,
    c: c,
    d: d,
  );
}

void main() {
  test('collapseSmallEdges collapses short middle and rewires both chains', () {
    final cell = threeEdgeCell();
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..nodes.addAll([cell.a, cell.b, cell.c, cell.d])
      ..edges.addAll([
        cell.start,
        cell.middle,
        cell.end,
        cell.endTwin,
        cell.middleTwin,
        cell.startTwin,
      ]);

    graph.collapseSmallEdges(5);

    expect(graph.nodes, hasLength(3));
    expect(graph.nodes.any((value) => identical(value, cell.c)), isFalse);
    expect(graph.edges, hasLength(4));
    expect(graph.edges.any((value) => identical(value, cell.middle)), isFalse);
    expect(
      graph.edges.any((value) => identical(value, cell.middleTwin)),
      isFalse,
    );

    expect(cell.start.next, same(cell.end));
    expect(cell.end.prev, same(cell.start));
    expect(cell.end.from, same(cell.b));
    expect(cell.endTwin.to, same(cell.b));
    expect(cell.endTwin.next, same(cell.startTwin));
    expect(cell.startTwin.prev, same(cell.endTwin));
    expect(cell.b.incidentEdge, same(cell.startTwin));
  });

  test('whole-cell collapse treats exact snap distance as inclusive', () {
    final cell = twoEdgeCell(
      ax: 0,
      ay: 0,
      bx: 0,
      by: 100,
      cx: 10,
      cy: 100,
      dx: 10,
      dy: 0,
    );
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..nodes.addAll([cell.a, cell.b, cell.c, cell.d])
      ..edges.addAll([
        cell.start,
        cell.end,
        cell.endTwin,
        cell.startTwin,
      ]);

    graph.collapseSmallEdges(10);

    expect(graph.nodes, hasLength(3));
    expect(graph.nodes.any((value) => identical(value, cell.a)), isFalse);
    expect(graph.edges, hasLength(2));
    expect(graph.edges[0], same(cell.endTwin));
    expect(graph.edges[1], same(cell.startTwin));
    expect(cell.startTwin.to, same(cell.d));
    expect(cell.startTwin.twin, same(cell.endTwin));
    expect(cell.endTwin.twin, same(cell.startTwin));
    expect(cell.d.incidentEdge, same(cell.endTwin));
    expect(cell.c.incidentEdge, same(cell.startTwin));
  });

  test('cell is not collapsed when only one opposite side is short', () {
    final cell = twoEdgeCell(
      ax: 0,
      ay: 0,
      bx: 0,
      by: 100,
      cx: 20,
      cy: 100,
      dx: 10,
      dy: 0,
    );
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..nodes.addAll([cell.a, cell.b, cell.c, cell.d])
      ..edges.addAll([
        cell.start,
        cell.end,
        cell.endTwin,
        cell.startTwin,
      ]);

    graph.collapseSmallEdges(10);

    expect(graph.nodes, hasLength(4));
    expect(graph.edges, hasLength(4));
    expect(cell.start.twin, same(cell.startTwin));
    expect(cell.end.twin, same(cell.endTwin));
  });

  test('identity cursor survives removals and reaches the next source cell', () {
    final first = twoEdgeCell(
      ax: 0,
      ay: 0,
      bx: 0,
      by: 100,
      cx: 5,
      cy: 100,
      dx: 5,
      dy: 0,
    );
    final second = twoEdgeCell(
      ax: 1000,
      ay: 0,
      bx: 1000,
      by: 100,
      cx: 1005,
      cy: 100,
      dx: 1005,
      dy: 0,
    );
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..nodes.addAll([
        first.a,
        first.b,
        first.c,
        first.d,
        second.a,
        second.b,
        second.c,
        second.d,
      ])
      ..edges.addAll([
        first.start,
        first.end,
        first.endTwin,
        first.startTwin,
        second.start,
        second.end,
        second.endTwin,
        second.startTwin,
      ]);

    graph.collapseSmallEdges(5);

    expect(graph.nodes, hasLength(6));
    expect(graph.nodes.any((value) => identical(value, first.a)), isFalse);
    expect(graph.nodes.any((value) => identical(value, second.a)), isFalse);
    expect(graph.edges, hasLength(4));
    expect(graph.edges, [
      same(first.endTwin),
      same(first.startTwin),
      same(second.endTwin),
      same(second.startTwin),
    ]);
  });

  test('short middle without twin fails at the pinned source assertion seam', () {
    final a = node(0, 0);
    final b = node(1000, 0);
    final c = node(1003, 4);
    final d = node(3000, 0);
    final start = SourceArachneSTHalfEdge2()
      ..from = a
      ..to = b;
    final middle = SourceArachneSTHalfEdge2()
      ..from = b
      ..to = c;
    final end = SourceArachneSTHalfEdge2()
      ..from = c
      ..to = d;
    start.next = middle;
    middle
      ..prev = start
      ..next = end;
    end.prev = middle;

    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..nodes.addAll([a, b, c, d])
      ..edges.addAll([start, middle, end]);

    expect(() => graph.collapseSmallEdges(5), throwsStateError);
  });
}
