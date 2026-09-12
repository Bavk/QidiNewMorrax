import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_beading_strategy.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_generate_segments_propagation.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_graph.dart';

class _Strategy extends SourceArachneBeadingStrategy2 {
  _Strategy()
      : super(
          optimalWidth: 100,
          wallSplitMiddleThreshold: 0.5,
          wallAddMiddleThreshold: 0.5,
          defaultTransitionLength: 10,
          transitioningAngle: 1,
          name: 'segments-propagation-fixture',
        );

  final List<(int, int)> computeCalls = [];
  final List<int> countCalls = [];

  @override
  SourceArachneBeading2 compute(int thickness, int beadCount) {
    computeCalls.add((thickness, beadCount));
    return SourceArachneBeading2(
      totalThickness: thickness,
      beadWidths: [beadCount * 10],
      toolpathLocations: [beadCount * 5],
      leftOver: beadCount,
    );
  }

  @override
  int getOptimalBeadCount(int thickness) {
    countCalls.add(thickness);
    return thickness ~/ 100;
  }
}

SourceArachneSTHalfEdgeNode2 _node(
  int x,
  int radius, {
  int beadCount = -1,
}) =>
    SourceArachneSTHalfEdgeNode2(
      p: SourcePoint2(x, 0),
      data: SourceArachneSkeletalJoint2(
        distanceToBoundary: radius,
        beadCount: beadCount,
      ),
    );

(SourceArachneSTHalfEdge2, SourceArachneSTHalfEdge2) _pair(
  SourceArachneSTHalfEdgeNode2 from,
  SourceArachneSTHalfEdgeNode2 to, {
  bool central = false,
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

SourceArachneBeadingPropagation2 _beading(
  int total,
  int width,
  int location, {
  int bottom = 0,
  int top = 0,
  bool upwardOnly = false,
}) =>
    SourceArachneBeadingPropagation2(
      SourceArachneBeading2(
        totalThickness: total,
        beadWidths: [width],
        toolpathLocations: [location],
        leftOver: 0,
      ),
    )
      ..distToBottomSource = bottom
      ..distFromTopSource = top
      ..isUpwardPropagatedOnly = upwardOnly;

void main() {
  test('upward propagation copies lower beading and accumulates length', () {
    final lower = _node(0, 50, beadCount: 1);
    final upper = _node(30, 100);
    final edge = _pair(lower, upper).$1;
    final source = _beading(100, 80, 40, bottom: 7);
    lower.data.setBeading(source);
    final ownership = <SourceArachneBeadingPropagation2>[source];
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..nodes.addAll([lower, upper]);

    graph.propagateBeadingsUpward(
      [edge],
      ownership,
      centralFilterDistance: 1000,
    );

    expect(upper.data.hasBeading, isTrue);
    expect(upper.data.beading, isNot(same(source)));
    expect(identical(upper.data.beading!.beading, source.beading), isTrue);
    expect(upper.data.beading!.distToBottomSource, 37);
    expect(upper.data.beading!.distFromTopSource, 0);
    expect(upper.data.beading!.isUpwardPropagatedOnly, isTrue);
    expect(ownership, hasLength(2));
  });

  test('upward propagation never overrides local bead count or existing beading', () {
    final lower = _node(0, 50, beadCount: 1);
    final localUpper = _node(10, 100, beadCount: 2);
    final existingUpper = _node(20, 100);
    final source = _beading(100, 80, 40);
    final existing = _beading(150, 90, 45);
    lower.data.setBeading(source);
    existingUpper.data.setBeading(existing);
    final localEdge = _pair(lower, localUpper).$1;
    final existingEdge = _pair(lower, existingUpper).$1;
    final ownership = <SourceArachneBeadingPropagation2>[source, existing];
    final graph = SourceArachneSkeletalTrapezoidationGraph2();

    graph.propagateBeadingsUpward(
      [localEdge, existingEdge],
      ownership,
      centralFilterDistance: 1000,
    );

    expect(localUpper.data.hasBeading, isFalse);
    expect(existingUpper.data.beading, same(existing));
    expect(ownership, hasLength(2));
  });

  test('downward propagation copies top beading into empty lower node', () {
    final lower = _node(0, 50);
    final upper = _node(30, 100, beadCount: 2);
    final edge = _pair(lower, upper, central: false).$1;
    final top = _beading(200, 120, 60, top: 4);
    upper.data.setBeading(top);
    final ownership = <SourceArachneBeadingPropagation2>[top];
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..nodes.addAll([lower, upper]);

    graph.propagateBeadingsDownward(
      [edge],
      ownership,
      _Strategy(),
      beadingPropagationTransitionDistance: 100,
    );

    expect(lower.data.hasBeading, isTrue);
    expect(lower.data.beading, isNot(same(top)));
    expect(identical(lower.data.beading!.beading, top.beading), isTrue);
    expect(lower.data.beading!.distFromTopSource, 34);
    expect(ownership, hasLength(2));
  });

  test('downward merge resets propagation distances and upward-only flag', () {
    final lower = _node(0, 50);
    final upper = _node(50, 100, beadCount: 2);
    final edge = _pair(lower, upper, central: false).$1;
    final bottom = _beading(
      100,
      100,
      20,
      bottom: 20,
      upwardOnly: true,
    );
    final top = _beading(200, 200, 40);
    lower.data.setBeading(bottom);
    upper.data.setBeading(top);
    final ownership = <SourceArachneBeadingPropagation2>[bottom, top];
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..nodes.addAll([lower, upper]);

    graph.propagateBeadingsDownward(
      [edge],
      ownership,
      _Strategy(),
      beadingPropagationTransitionDistance: 100,
    );

    final merged = lower.data.beading!;
    expect(merged, isNot(same(bottom)));
    expect(merged.isUpwardPropagatedOnly, isFalse);
    expect(merged.distToBottomSource, 0);
    expect(merged.distFromTopSource, 0);
    expect(merged.beading.totalThickness, 200);
    // float ratio top = 20 / 70; source interpolation truncates the width.
    expect(merged.beading.beadWidths.single, 128);
    expect(merged.beading.toolpathLocations.single, 25);
    expect(ownership.where((value) => identical(value, merged)), hasLength(1));
    expect(ownership.any((value) => identical(value, bottom)), isFalse);
  });

  test('ratio at or above one replaces bottom state with top state', () {
    final lower = _node(0, 50);
    final upper = _node(10, 100, beadCount: 2);
    final edge = _pair(lower, upper, central: false).$1;
    final bottom = _beading(100, 100, 20, bottom: 100, upwardOnly: true);
    final top = _beading(200, 200, 40, top: 3);
    lower.data.setBeading(bottom);
    upper.data.setBeading(top);
    final ownership = <SourceArachneBeadingPropagation2>[bottom, top];
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..nodes.addAll([lower, upper]);

    graph.propagateBeadingsDownward(
      [edge],
      ownership,
      _Strategy(),
      beadingPropagationTransitionDistance: 50,
    );

    final replaced = lower.data.beading!;
    expect(identical(replaced.beading, top.beading), isTrue);
    expect(replaced.distFromTopSource, 13);
    expect(replaced.distToBottomSource, top.distToBottomSource);
    expect(replaced.isUpwardPropagatedOnly, top.isUpwardPropagatedOnly);
    expect(ownership.any((value) => identical(value, bottom)), isFalse);
  });

  test('switching-radius interpolation keeps pinned float ratio quirk', () {
    final left = SourceArachneBeading2(
      totalThickness: 100,
      beadWidths: const [20, 20],
      toolpathLocations: const [40, 100],
      leftOver: 0,
    );
    final right = SourceArachneBeading2(
      totalThickness: 120,
      beadWidths: const [40, 40],
      toolpathLocations: const [80, 120],
      leftOver: 0,
    );

    final merged = sourceInterpolateBeadingAtRadius(left, 0.25, right, 60);

    expect(merged.toolpathLocations, [55, 107]);
  });

  test('nearest beading accepts edge exactly at max distance', () {
    final start = _node(0, 10);
    final target = _node(100000, 20, beadCount: 1);
    final pair = _pair(start, target);
    pair.$2.next = pair.$1;
    start.incidentEdge = pair.$1;
    final targetBeading = _beading(40, 20, 10);
    target.data.setBeading(targetBeading);
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..nodes.addAll([start, target]);

    expect(graph.getNearestBeading(start, 100000), same(targetBeading));
    expect(graph.getNearestBeading(start, 99999), isNull);
  });

  test('getOrCreate returns nearby beading without attaching it to unknown node', () {
    final start = _node(0, 10);
    final target = _node(100000, 20, beadCount: 1);
    final pair = _pair(start, target);
    pair.$2.next = pair.$1;
    start.incidentEdge = pair.$1;
    final targetBeading = _beading(40, 20, 10);
    target.data.setBeading(targetBeading);
    final ownership = <SourceArachneBeadingPropagation2>[targetBeading];
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..nodes.addAll([start, target]);

    final result = graph.getOrCreateBeading(start, ownership, _Strategy());

    expect(result, same(targetBeading));
    expect(start.data.hasBeading, isFalse);
    expect(start.data.beadCount, -1);
    expect(ownership, hasLength(1));
  });

  test('getOrCreate synthesizes bead count when no nearby beading exists', () {
    final start = _node(0, 10);
    final target = _node(200000, 30);
    final pair = _pair(start, target, central: true);
    pair.$2.next = pair.$1;
    start.incidentEdge = pair.$1;
    final strategy = _Strategy();
    final ownership = <SourceArachneBeadingPropagation2>[];
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..nodes.addAll([start, target]);

    final result = graph.getOrCreateBeading(start, ownership, strategy);

    // nearest radius candidate = target R 30 + edge length 200000.
    expect(strategy.countCalls, [400060]);
    expect(start.data.beadCount, 4000);
    expect(strategy.computeCalls, [(20, 4000)]);
    expect(result.beading.totalThickness, 20);
    expect(start.data.beading, same(result));
    expect(ownership, [same(result)]);
  });
}
