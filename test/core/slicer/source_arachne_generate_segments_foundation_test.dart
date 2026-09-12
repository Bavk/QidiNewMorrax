import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_beading_strategy.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_generate_segments_foundation.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_graph.dart';

class _Strategy extends SourceArachneBeadingStrategy2 {
  _Strategy()
      : super(
          optimalWidth: 100,
          wallSplitMiddleThreshold: 0.5,
          wallAddMiddleThreshold: 0.5,
          defaultTransitionLength: 10,
          transitioningAngle: 1,
          name: 'segments-foundation-fixture',
        );

  final List<(int, int)> calls = [];

  @override
  SourceArachneBeading2 compute(int thickness, int beadCount) {
    calls.add((thickness, beadCount));
    if (beadCount == 1) {
      return SourceArachneBeading2(
        totalThickness: thickness,
        beadWidths: const [1],
        toolpathLocations: const [1],
        leftOver: 111,
      );
    }
    return SourceArachneBeading2(
      totalThickness: thickness,
      beadWidths: const [11, 0],
      toolpathLocations: const [11, 20],
      leftOver: 222,
    );
  }

  @override
  int getOptimalBeadCount(int thickness) => thickness ~/ 100;
}

SourceArachneSTHalfEdgeNode2 _node(
  int x,
  int radius, {
  int beadCount = -1,
  double transitionRatio = 0,
}) =>
    SourceArachneSTHalfEdgeNode2(
      p: SourcePoint2(x, 0),
      data: SourceArachneSkeletalJoint2(
        distanceToBoundary: radius,
        beadCount: beadCount,
        transitionRatio: transitionRatio,
      ),
    );

SourceArachneSTHalfEdge2 _interiorEdge(
  int x,
  int fromRadius,
  int toRadius,
) {
  final edge = SourceArachneSTHalfEdge2()
    ..from = _node(x, fromRadius)
    ..to = _node(x + 10, toRadius)
    ..prev = SourceArachneSTHalfEdge2()
    ..next = SourceArachneSTHalfEdge2();
  return edge;
}

void main() {
  test('upward quad mids exclude boundaries/downward and sort high radius first', () {
    final low = _interiorEdge(0, 10, 30);
    final high = _interiorEdge(20, 10, 50);
    final down = _interiorEdge(40, 50, 20);
    final boundary = SourceArachneSTHalfEdge2()
      ..from = _node(60, 10)
      ..to = _node(70, 80)
      ..next = SourceArachneSTHalfEdge2();
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..edges.addAll([low, down, boundary, high]);

    final result = graph.collectUpwardQuadMids();

    expect(result, [same(high), same(low)]);
  });

  test('flat edge precedes equal-height nonflat edge like source comparator', () {
    final flatFrom = _node(10, 50);
    final flatTo = _node(0, 50);
    final flat = SourceArachneSTHalfEdge2()
      ..from = flatFrom
      ..to = flatTo
      ..prev = SourceArachneSTHalfEdge2();
    final flatTwin = SourceArachneSTHalfEdge2()
      ..from = flatTo
      ..to = flatFrom;
    flat.twin = flatTwin;
    flatTwin.twin = flat;
    flat.next = flatTwin;
    flatTwin.next = flat;

    final rising = _interiorEdge(20, 40, 50);
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..edges.addAll([rising, flat]);

    final result = graph.collectUpwardQuadMids();

    expect(result, [same(flat), same(rising)]);
  });

  test('interpolate keeps source float32 right-ratio truncation', () {
    final left = SourceArachneBeading2(
      totalThickness: 10,
      beadWidths: const [1],
      toolpathLocations: const [1],
      leftOver: 1,
    );
    final right = SourceArachneBeading2(
      totalThickness: 20,
      beadWidths: const [11],
      toolpathLocations: const [11],
      leftOver: 2,
    );

    final value = sourceInterpolateBeading(left, 0.1, right);

    // Source float right ratio is 0.899999976..., so the nominal 10 becomes
    // 9.9999997 and coord_t assignment truncates to 9.
    expect(value.beadWidths, [9]);
    expect(value.toolpathLocations, [9]);
    expect(value.totalThickness, 20);
    expect(value.leftOver, 2);
  });

  test('interpolate preserves zero-width markers and longer selected side', () {
    final left = SourceArachneBeading2(
      totalThickness: 30,
      beadWidths: const [0, 30],
      toolpathLocations: const [5, 20],
      leftOver: 7,
    );
    final right = SourceArachneBeading2(
      totalThickness: 20,
      beadWidths: const [10],
      toolpathLocations: const [15],
      leftOver: 9,
    );

    final value = sourceInterpolateBeading(left, 0.5, right);

    expect(value.beadWidths, [0, 30]);
    expect(value.toolpathLocations, [10, 20]);
    expect(value.totalThickness, 30);
    expect(value.leftOver, 7);
  });

  test('storeNodeBeadings skips nonpositive count and computes endpoint beading', () {
    final skipped = _node(0, 50, beadCount: 0);
    final endpoint = _node(10, 50, beadCount: 1);
    final strategy = _Strategy();
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..nodes.addAll([skipped, endpoint]);

    final ownership = graph.storeNodeBeadings(strategy);

    expect(skipped.data.hasBeading, isFalse);
    expect(endpoint.data.hasBeading, isTrue);
    expect(ownership, hasLength(1));
    expect(endpoint.data.beading, same(ownership.single));
    expect(endpoint.data.beading!.beading.totalThickness, 100);
    expect(strategy.calls, [(100, 1)]);
  });

  test('transition node merges low/high beadings at 1-ratio', () {
    final transition = _node(
      0,
      50,
      beadCount: 1,
      transitionRatio: 0.9,
    );
    final strategy = _Strategy();
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..nodes.add(transition);

    final ownership = graph.storeNodeBeadings(strategy);

    expect(ownership, hasLength(1));
    expect(strategy.calls, [(100, 1), (100, 2)]);
    final merged = transition.data.beading!.beading;
    expect(merged.totalThickness, 100);
    expect(merged.beadWidths, [9, 0]);
    expect(merged.toolpathLocations, [9, 20]);
    expect(merged.leftOver, 222);
  });
}
