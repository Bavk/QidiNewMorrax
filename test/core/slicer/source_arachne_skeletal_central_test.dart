import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_beading_strategy.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_central.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_graph.dart';

class _Strategy extends SourceArachneBeadingStrategy2 {
  _Strategy({double angle = math.pi / 2})
      : super(
          optimalWidth: 100,
          wallSplitMiddleThreshold: 0.4,
          wallAddMiddleThreshold: 0.5,
          defaultTransitionLength: 10,
          transitioningAngle: angle,
          name: 'central-fixture',
        );

  @override
  SourceArachneBeading2 compute(int thickness, int beadCount) =>
      SourceArachneBeading2(totalThickness: thickness, leftOver: thickness);

  @override
  int getOptimalBeadCount(int thickness) => 0;
}

SourceArachneSTHalfEdgeNode2 node(int x, int y, int distance) =>
    SourceArachneSTHalfEdgeNode2(
      p: SourcePoint2(x, y),
      data: SourceArachneSkeletalJoint2(distanceToBoundary: distance),
    );

(SourceArachneSTHalfEdge2, SourceArachneSTHalfEdge2) pair(
  SourceArachneSTHalfEdgeNode2 from,
  SourceArachneSTHalfEdgeNode2 to, {
  SourceArachneSkeletalEdgeType2 type =
      SourceArachneSkeletalEdgeType2.normal,
}) {
  final first = SourceArachneSTHalfEdge2(
    SourceArachneSkeletalEdgeData2(type: type),
  )
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
  test('updateIsCentral copies already-set twin before edge-type checks', () {
    final edges = pair(
      node(0, 0, 25),
      node(10, 0, 25),
      type: SourceArachneSkeletalEdgeType2.extraVd,
    );
    edges.$2.data.setIsCentral(true);
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..edges.add(edges.$1);

    graph.updateIsCentral(_Strategy());

    expect(edges.$1.data.centralIsSet, isTrue);
    expect(edges.$1.data.isCentral, isTrue);
  });

  test('EXTRA_VD edge is noncentral and twin later copies the result', () {
    final edges = pair(
      node(0, 0, 100),
      node(10, 0, 100),
      type: SourceArachneSkeletalEdgeType2.extraVd,
    );
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..edges.addAll([edges.$1, edges.$2]);

    graph.updateIsCentral(_Strategy());

    expect(edges.$1.data.isCentral, isFalse);
    expect(edges.$2.data.isCentral, isFalse);
  });

  test('outer edge filter uses strict less-than transition-half boundary', () {
    final below = pair(node(0, 0, 24), node(10, 0, 24));
    final atBoundary = pair(node(20, 0, 25), node(30, 0, 25));
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..edges.addAll([
        below.$1,
        below.$2,
        atBoundary.$1,
        atBoundary.$2,
      ]);

    graph.updateIsCentral(_Strategy());

    expect(below.$1.data.isCentral, isFalse);
    expect(atBoundary.$1.data.isCentral, isTrue);
  });

  test('central cap comparison keeps source strict dR < dD * cap', () {
    final central = pair(node(0, 0, 25), node(10, 0, 32));
    final noncentral = pair(node(20, 0, 25), node(30, 0, 33));
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..edges.addAll([
        central.$1,
        central.$2,
        noncentral.$1,
        noncentral.$2,
      ]);

    graph.updateIsCentral(_Strategy());

    // cap = sin(pi/4) ~= 0.70710677; 7 < 7.071..., while 8 is not.
    expect(central.$1.data.isCentral, isTrue);
    expect(noncentral.$1.data.isCentral, isFalse);
  });

  test('large dD is rounded to float before cap multiplication', () {
    final edges = pair(
      node(0, 0, 25),
      node(16777217, 0, 8388633),
    );
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..edges.addAll([edges.$1, edges.$2]);

    graph.updateIsCentral(_Strategy(angle: math.pi / 3));

    // Source converts dD=16777217 to float => 16777216 before multiplying
    // cap=0.5, producing 8388608. Strict comparison with dR=8388608 fails.
    // A Dart-double multiplication without this source float boundary would
    // incorrectly compare against 8388608.5 and mark the edge central.
    expect(edges.$1.data.isCentral, isFalse);
    expect(edges.$2.data.isCentral, isFalse);
  });

  test('missing twin follows source release continue without setting state', () {
    final edge = SourceArachneSTHalfEdge2()
      ..from = node(0, 0, 25)
      ..to = node(10, 0, 25);
    final graph = SourceArachneSkeletalTrapezoidationGraph2()..edges.add(edge);

    graph.updateIsCentral(_Strategy());

    expect(edge.data.centralIsSet, isFalse);
    expect(() => edge.data.isCentral, throwsStateError);
  });

  test('isEndOfCentral accepts boundary end and rejects noncentral edge', () {
    final edges = pair(node(0, 0, 10), node(10, 0, 20));
    final graph = SourceArachneSkeletalTrapezoidationGraph2();

    edges.$1.data.setIsCentral(true);
    expect(graph.isEndOfCentral(edges.$1), isTrue);

    edges.$1.data.setIsCentral(false);
    expect(graph.isEndOfCentral(edges.$1), isFalse);
  });

  test('isEndOfCentral scans radial next edges for another central branch', () {
    final end = pair(node(0, 0, 10), node(10, 0, 20));
    final radial = pair(node(10, 0, 20), node(20, 0, 15));
    end.$1.data.setIsCentral(true);
    end.$2.data.setIsCentral(true);
    radial.$1.data.setIsCentral(false);
    radial.$2.data.setIsCentral(false);
    end.$1.next = radial.$1;
    radial.$2.next = end.$2;
    final graph = SourceArachneSkeletalTrapezoidationGraph2();

    expect(graph.isEndOfCentral(end.$1), isTrue);

    radial.$1.data.setIsCentral(true);
    expect(graph.isEndOfCentral(end.$1), isFalse);
  });

  test('filterCentral preserves pinned contradictory top-level predicate', () {
    final low = node(0, 0, 10);
    final maximum = node(10, 0, 20);
    final end = pair(low, maximum);
    end.$1.data.setIsCentral(true);
    end.$2.data.setIsCentral(true);

    final downhill = pair(maximum, node(20, 0, 5));
    downhill.$2.next = downhill.$1;
    maximum.incidentEdge = downhill.$1;

    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..edges.addAll([end.$1, end.$2, downhill.$1, downhill.$2]);

    expect(maximum.isLocalMaximum(), isTrue);
    graph.filterCentral(1000);

    // Pinned source asks for localMaximum && !localMaximum, so recursion is
    // unreachable and this otherwise eligible central end is left untouched.
    expect(end.$1.data.isCentral, isTrue);
    expect(end.$2.data.isCentral, isTrue);
  });

  test('filterOuterCentral clears only prev-null edge pairs', () {
    final boundary = pair(node(0, 0, 10), node(10, 0, 20));
    final chained = pair(node(20, 0, 20), node(30, 0, 30));
    for (final edge in [boundary.$1, boundary.$2, chained.$1, chained.$2]) {
      edge.data.setIsCentral(true);
    }
    final sentinel = SourceArachneSTHalfEdge2();
    chained.$1.prev = sentinel;
    chained.$2.prev = sentinel;

    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..edges.addAll([boundary.$1, boundary.$2, chained.$1, chained.$2]);

    graph.filterOuterCentral();

    expect(boundary.$1.data.isCentral, isFalse);
    expect(boundary.$2.data.isCentral, isFalse);
    expect(chained.$1.data.isCentral, isTrue);
    expect(chained.$2.data.isCentral, isTrue);
  });
}
