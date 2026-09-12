import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_beading_strategy.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_generate_segments_junctions.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_graph.dart';

class _Strategy extends SourceArachneBeadingStrategy2 {
  _Strategy()
      : super(
          optimalWidth: 100,
          wallSplitMiddleThreshold: 0.5,
          wallAddMiddleThreshold: 0.5,
          defaultTransitionLength: 10,
          transitioningAngle: 1,
          name: 'segments-junctions-fixture',
        );

  final List<(int, int)> calls = [];

  @override
  SourceArachneBeading2 compute(int thickness, int beadCount) {
    calls.add((thickness, beadCount));
    return SourceArachneBeading2(
      totalThickness: thickness,
      beadWidths: const [100, 300, 500],
      toolpathLocations: const [1000, 3000, 5000],
      leftOver: 0,
    );
  }

  @override
  int getOptimalBeadCount(int thickness) => thickness ~/ 1000;
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
  SourceArachneSTHalfEdgeNode2 low,
  SourceArachneSTHalfEdgeNode2 high,
) {
  final up = SourceArachneSTHalfEdge2()
    ..from = low
    ..to = high;
  final down = SourceArachneSTHalfEdge2()
    ..from = high
    ..to = low;
  up.twin = down;
  down.twin = up;
  up.data.setIsCentral(true);
  down.data.setIsCentral(true);
  return (up, down);
}

SourceArachneBeadingPropagation2 _beading({
  List<int> widths = const [100, 300, 500],
  List<int> locations = const [1000, 3000, 5000],
  int totalThickness = 10000,
}) =>
    SourceArachneBeadingPropagation2(
      SourceArachneBeading2(
        totalThickness: totalThickness,
        beadWidths: widths,
        toolpathLocations: locations,
        leftOver: 0,
      ),
    );

void main() {
  test('upward half-edge gets high-R to low-R source junctions', () {
    final low = _node(0, 1000, beadCount: 1);
    final high = _node(10000, 5000, beadCount: 2);
    final pair = _pair(low, high);
    final topBeading = _beading();
    high.data.setBeading(topBeading);
    pair.$1.data.setHoleCompensationFlag(true);
    final ownership = <SourceArachneBeadingPropagation2>[topBeading];
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..nodes.addAll([low, high])
      ..edges.addAll([pair.$2, pair.$1]);

    final edgeJunctions = graph.generateJunctions(ownership, _Strategy());

    expect(edgeJunctions, hasLength(1));
    expect(pair.$2.data.extrusionJunctions, isNull);
    expect(pair.$1.data.extrusionJunctions, same(edgeJunctions.single));
    expect(edgeJunctions.single.map((value) => value.p), const [
      SourcePoint2(5000, 0),
      SourcePoint2(0, 0),
    ]);
    expect(edgeJunctions.single.map((value) => value.w), [300, 100]);
    expect(edgeJunctions.single.map((value) => value.perimeterIndex), [1, 0]);
    expect(
      edgeJunctions.single.every((value) => value.holeCompensationFlag),
      isTrue,
    );
    expect(ownership, [same(topBeading)]);
  });

  test('same nonnegative bead count skips edge before lazy beading lookup', () {
    final low = _node(0, 1000, beadCount: 2);
    final high = _node(10000, 5000, beadCount: 2);
    final up = _pair(low, high).$1;
    final strategy = _Strategy();
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..nodes.addAll([low, high])
      ..edges.add(up);

    final result = graph.generateJunctions(
      <SourceArachneBeadingPropagation2>[],
      strategy,
    );

    expect(result, isEmpty);
    expect(up.data.extrusionJunctions, isNull);
    expect(strategy.calls, isEmpty);
  });

  test('flat and downward edges generate no junction storage', () {
    final flatA = _node(0, 5000, beadCount: 1);
    final flatB = _node(10000, 5000, beadCount: 2);
    final flat = _pair(flatA, flatB).$1;
    final low = _node(0, 1000, beadCount: 1);
    final high = _node(10000, 5000, beadCount: 2);
    final downward = _pair(low, high).$2;
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..edges.addAll([flat, downward]);

    final result = graph.generateJunctions(
      <SourceArachneBeadingPropagation2>[],
      _Strategy(),
    );

    expect(result, isEmpty);
    expect(flat.data.extrusionJunctions, isNull);
    expect(downward.data.extrusionJunctions, isNull);
  });

  test('exact 0.005mm snap boundary is not snapped', () {
    final low = _node(0, 1000, beadCount: 1);
    final high = _node(10000, 5000, beadCount: 2);
    final up = _pair(low, high).$1;
    final topBeading = _beading(
      widths: const [100, 450, 500],
      locations: const [1000, 4500, 5000],
    );
    high.data.setBeading(topBeading);
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..nodes.addAll([low, high])
      ..edges.add(up);

    final result = graph.generateJunctions(
      <SourceArachneBeadingPropagation2>[topBeading],
      _Strategy(),
    );

    // scaled(0.005)=500, so bead_R == start_R - 500 must take the
    // interpolated branch because source snap comparison is strict `>`.
    expect(result.single.first.p, const SourcePoint2(8750, 0));
    expect(result.single.first.w, 450);
  });

  test('one source unit inside snap threshold snaps to high-R node', () {
    final low = _node(0, 1000, beadCount: 1);
    final high = _node(10000, 5000, beadCount: 2);
    final up = _pair(low, high).$1;
    final topBeading = _beading(
      widths: const [100, 451, 500],
      locations: const [1000, 4501, 5000],
    );
    high.data.setBeading(topBeading);
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..nodes.addAll([low, high])
      ..edges.add(up);

    final result = graph.generateJunctions(
      <SourceArachneBeadingPropagation2>[topBeading],
      _Strategy(),
    );

    expect(result.single.first.p, const SourcePoint2(10000, 0));
    expect(result.single.first.w, 451);
  });

  test('lazy top beading is created and owned before junction generation', () {
    final low = _node(0, 1000, beadCount: 1);
    final high = _node(10000, 5000, beadCount: 2);
    final up = _pair(low, high).$1;
    final strategy = _Strategy();
    final ownership = <SourceArachneBeadingPropagation2>[];
    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..nodes.addAll([low, high])
      ..edges.add(up);

    final result = graph.generateJunctions(ownership, strategy);

    expect(strategy.calls, [(10000, 2)]);
    expect(ownership, hasLength(1));
    expect(high.data.beading, same(ownership.single));
    expect(result.single, hasLength(2));
  });
}
