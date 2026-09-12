import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_beading_strategy.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_extrusion_line.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_graph.dart';

SourceArachneSTHalfEdgeNode2 node(
  int x,
  int y,
  int distance,
) =>
    SourceArachneSTHalfEdgeNode2(
      p: SourcePoint2(x, y),
      data: SourceArachneSkeletalJoint2(distanceToBoundary: distance),
    );

(SourceArachneSTHalfEdge2, SourceArachneSTHalfEdge2) twinPair(
  SourceArachneSTHalfEdgeNode2 a,
  SourceArachneSTHalfEdgeNode2 b,
) {
  final forward = SourceArachneSTHalfEdge2()
    ..from = a
    ..to = b;
  final backward = SourceArachneSTHalfEdge2()
    ..from = b
    ..to = a;
  forward.twin = backward;
  backward.twin = forward;
  return (forward, backward);
}

List<SourceArachneSTHalfEdge2> radialFan(
  SourceArachneSTHalfEdgeNode2 center,
  List<SourceArachneSTHalfEdgeNode2> outer, {
  required List<bool> central,
}) {
  final outgoing = <SourceArachneSTHalfEdge2>[];
  final incoming = <SourceArachneSTHalfEdge2>[];
  for (var index = 0; index < outer.length; index++) {
    final pair = twinPair(center, outer[index]);
    pair.$1.data.setIsCentral(central[index]);
    pair.$2.data.setIsCentral(central[index]);
    outgoing.add(pair.$1);
    incoming.add(pair.$2);
  }
  for (var index = 0; index < outgoing.length; index++) {
    incoming[index].next = outgoing[(index + 1) % outgoing.length];
  }
  center.incidentEdge = outgoing.first;
  return outgoing;
}

void main() {
  test('skeletal edge and joint defaults preserve pinned enum/data state', () {
    expect(
      SourceArachneSkeletalEdgeType2.values,
      const [
        SourceArachneSkeletalEdgeType2.normal,
        SourceArachneSkeletalEdgeType2.extraVd,
        SourceArachneSkeletalEdgeType2.transitionEnd,
      ],
    );

    final edge = SourceArachneSkeletalEdgeData2();
    expect(edge.type, SourceArachneSkeletalEdgeType2.normal);
    expect(edge.centralIsSet, isFalse);
    expect(() => edge.isCentral, throwsStateError);
    expect(edge.holeCompensationFlag, isFalse);
    expect(edge.hasTransitions(), isFalse);
    expect(edge.hasTransitionEnds(), isFalse);
    expect(edge.hasExtrusionJunctions(), isFalse);

    final joint = SourceArachneSkeletalJoint2();
    expect(joint.distanceToBoundary, -1);
    expect(joint.beadCount, -1);
    expect(joint.transitionRatio, 0);
    expect(joint.hasBeading, isFalse);
  });

  test('edge storage and BeadingPropagation preserve source ownership payload', () {
    final edge = SourceArachneSkeletalEdgeData2();
    edge.setIsCentral(true);
    edge.setHoleCompensationFlag(true);
    edge.setTransitions([
      const SourceArachneTransitionMiddle2(
        pos: 10,
        lowerBeadCount: 2,
        featureRadius: 30,
      ),
    ]);
    edge.setTransitionEnds([
      const SourceArachneTransitionEnd2(
        pos: 12,
        lowerBeadCount: 2,
        isLowerEnd: true,
      ),
    ]);
    edge.setExtrusionJunctions([
      SourceArachneExtrusionJunction2(
        p: const SourcePoint2(1, 2),
        w: 3,
        perimeterIndex: 4,
      ),
    ]);

    expect(edge.centralIsSet, isTrue);
    expect(edge.isCentral, isTrue);
    expect(edge.holeCompensationFlag, isTrue);
    expect(edge.hasTransitions(), isTrue);
    expect(edge.hasTransitionEnds(), isTrue);
    expect(edge.hasExtrusionJunctions(), isTrue);

    final propagation = SourceArachneBeadingPropagation2(
      SourceArachneBeading2(totalThickness: 100, leftOver: 100),
    );
    expect(propagation.distToBottomSource, 0);
    expect(propagation.distFromTopSource, 0);
    expect(propagation.isUpwardPropagatedOnly, isFalse);

    final joint = SourceArachneSkeletalJoint2()..setBeading(propagation);
    expect(joint.hasBeading, isTrue);
    expect(joint.beading, same(propagation));
  });

  test('direct half-edge height comparison controls upward methods', () {
    final low = node(0, 0, 10);
    final high = node(100, 0, 20);
    final pair = twinPair(low, high);

    expect(pair.$1.canGoUp(), isTrue);
    expect(pair.$1.isUpward(), isTrue);
    expect(pair.$1.distToGoUp(), 0);

    expect(pair.$2.canGoUp(), isFalse);
    expect(pair.$2.isUpward(), isFalse);
    expect(pair.$2.distToGoUp(), isNull);
  });

  test('equal plateau recursion finds upward branch and adds edge length', () {
    final a = node(0, 0, 10);
    final b = node(100, 0, 10);
    final c = node(200, 0, 20);
    final plateau = twinPair(a, b);
    final rising = twinPair(b, c);

    plateau.$1.next = rising.$1;
    rising.$2.next = plateau.$2;

    expect(plateau.$1.canGoUp(), isTrue);
    expect(plateau.$1.canGoUp(strict: true), isFalse);
    expect(plateau.$1.distToGoUp(), 100);
  });

  test('equal dead plateau uses x-major Point ordering opposite on twin', () {
    final highX = node(10, 0, 7);
    final lowX = node(0, 50, 7);
    final pair = twinPair(highX, lowX);
    pair.$1.next = pair.$2;
    pair.$2.next = pair.$1;

    expect(pair.$1.distToGoUp(), isNull);
    expect(pair.$2.distToGoUp(), isNull);
    expect(pair.$1.isUpward(), isTrue);
    expect(pair.$2.isUpward(), isFalse);
  });

  test('getNextUnconnected follows next chain then returns terminal twin', () {
    final a = node(0, 0, 0);
    final b = node(1, 0, 0);
    final c = node(2, 0, 0);
    final d = node(3, 0, 0);
    final first = twinPair(a, b).$1;
    final second = twinPair(b, c).$1;
    final terminalPair = twinPair(c, d);
    first.next = second;
    second.next = terminalPair.$1;

    expect(first.getNextUnconnected(), same(terminalPair.$2));

    terminalPair.$1.next = first;
    expect(first.getNextUnconnected(), isNull);
  });

  test('node central and multi-intersection rotate through twin-next fan', () {
    final center = node(0, 0, 10);
    final outer = [
      node(10, 0, 5),
      node(0, 10, 5),
      node(-10, 0, 5),
    ];
    radialFan(center, outer, central: const [true, true, true]);

    expect(center.isCentral, isTrue);
    expect(center.isMultiIntersection(), isTrue);

    final twoCenter = node(0, 0, 10);
    radialFan(
      twoCenter,
      [node(10, 0, 5), node(0, 10, 5), node(-10, 0, 5)],
      central: const [true, false, true],
    );
    expect(twoCenter.isCentral, isTrue);
    expect(twoCenter.isMultiIntersection(), isFalse);
  });

  test('node local maximum follows recursive canGoUp source contract', () {
    final center = node(0, 0, 10);
    final outer = [
      node(10, 0, 5),
      node(0, 10, 5),
      node(-10, 0, 5),
    ];
    radialFan(center, outer, central: const [false, false, false]);
    expect(center.isLocalMaximum(), isTrue);

    outer.first.data.distanceToBoundary = 20;
    expect(center.isLocalMaximum(), isFalse);

    center.data.distanceToBoundary = 0;
    expect(center.isLocalMaximum(), isFalse);
  });

  test('graph container retains pointer-shaped edge and node identity', () {
    final graph = SourceArachneSkeletalTrapezoidationGraph2();
    final a = node(0, 0, 0);
    final b = node(1, 0, 1);
    final pair = twinPair(a, b);
    graph.nodes.addAll([a, b]);
    graph.edges.addAll([pair.$1, pair.$2]);

    expect(graph.nodes[0], same(a));
    expect(graph.edges[0].twin, same(graph.edges[1]));
  });
}
