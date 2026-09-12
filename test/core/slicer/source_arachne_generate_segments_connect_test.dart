import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_extrusion_line.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_generate_segments_connect.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_graph.dart';

SourceArachneSTHalfEdgeNode2 _node(
  int x,
  int y,
  int radius, {
  int beadCount = 2,
  double transitionRatio = 0,
}) =>
    SourceArachneSTHalfEdgeNode2(
      p: SourcePoint2(x, y),
      data: SourceArachneSkeletalJoint2(
        distanceToBoundary: radius,
        beadCount: beadCount,
        transitionRatio: transitionRatio,
      ),
    );

SourceArachneExtrusionJunction2 _junction(
  int x,
  int y, {
  int width = 400,
  int perimeter = 0,
}) =>
    SourceArachneExtrusionJunction2(
      p: SourcePoint2(x, y),
      w: width,
      perimeterIndex: perimeter,
    );

void _central(SourceArachneSTHalfEdge2 edge) => edge.data.setIsCentral(true);

void main() {
  test('getQuadMaxRedgeTo selects edge entering the highest-radius node', () {
    final boundaryA = _node(0, 0, 0);
    final low = _node(10, 0, 1000);
    final peak = _node(20, 0, 5000);
    final boundaryB = _node(30, 0, 0);
    final e0 = SourceArachneSTHalfEdge2()
      ..from = boundaryA
      ..to = low;
    final e1 = SourceArachneSTHalfEdge2()
      ..from = low
      ..to = peak;
    final e2 = SourceArachneSTHalfEdge2()
      ..from = peak
      ..to = boundaryB;
    e0.next = e1;
    e1
      ..prev = e0
      ..next = e2;
    e2.prev = e1;
    final graph = SourceArachneSkeletalTrapezoidationGraph2();

    expect(graph.getQuadMaxRedgeTo(e0), same(e1));
  });

  test('terminal maximum within literal 0.005mm falls back to previous edge', () {
    final boundary = _node(0, 0, 0);
    final almostPeak = _node(10, 0, 5000);
    final terminal = _node(20, 0, 5200);
    final e0 = SourceArachneSTHalfEdge2()
      ..from = boundary
      ..to = almostPeak;
    final e1 = SourceArachneSTHalfEdge2()
      ..from = almostPeak
      ..to = terminal
      ..prev = e0;
    e0.next = e1;
    final graph = SourceArachneSkeletalTrapezoidationGraph2();

    // scaled<coord_t>(0.005) is 499, and 5200 - 499 < 5000.
    expect(graph.getQuadMaxRedgeTo(e0), same(e0));
  });

  test('addToolpathSegment creates an inset path and copies source values', () {
    final graph = SourceArachneSkeletalTrapezoidationGraph2();
    final generated = <List<SourceArachneExtrusionLine2>>[];
    final from = _junction(0, 0, perimeter: 2);
    final to = _junction(10000, 0, perimeter: 2);

    graph.addToolpathSegment(
      generated,
      from,
      to,
      isOdd: false,
      forceNewPath: false,
      fromIs3Way: false,
      toIs3Way: false,
    );

    expect(generated, hasLength(3));
    expect(generated[0], isEmpty);
    expect(generated[1], isEmpty);
    expect(generated[2], hasLength(1));
    expect(generated[2].single.insetIndex, 2);
    expect(generated[2].single.isOdd, isFalse);
    expect(generated[2].single.isClosed, isFalse);
    expect(generated[2].single.junctions, [from, to]);
    expect(generated[2].single.junctions.first, isNot(same(from)));
  });

  test('0.010mm join distance is inclusive at literal 999 source units', () {
    final graph = SourceArachneSkeletalTrapezoidationGraph2();
    final generated = <List<SourceArachneExtrusionLine2>>[
      <SourceArachneExtrusionLine2>[
        SourceArachneExtrusionLine2(
          insetIndex: 0,
          isOdd: false,
          junctions: [_junction(0, 0), _junction(1000, 0)],
        ),
      ],
    ];
    final from = _junction(1999, 0, width: 1398);
    final to = _junction(3000, 0, width: 1398);

    graph.addToolpathSegment(
      generated,
      from,
      to,
      isOdd: false,
      forceNewPath: false,
      fromIs3Way: false,
      toIs3Way: false,
    );

    // Position delta 999 is accepted by shorter_then; width delta 998 is
    // strictly below the same scaled(0.010)==999 threshold.
    expect(generated.single, hasLength(1));
    expect(generated.single.single.junctions.last.p, to.p);
  });

  test('join width difference at exact 999 boundary forces new path', () {
    final graph = SourceArachneSkeletalTrapezoidationGraph2();
    final generated = <List<SourceArachneExtrusionLine2>>[
      <SourceArachneExtrusionLine2>[
        SourceArachneExtrusionLine2(
          insetIndex: 0,
          isOdd: false,
          junctions: [_junction(0, 0), _junction(1000, 0, width: 400)],
        ),
      ],
    ];
    final from = _junction(1000, 0, width: 1399);
    final to = _junction(2000, 0, width: 1399);

    graph.addToolpathSegment(
      generated,
      from,
      to,
      isOdd: false,
      forceNewPath: false,
      fromIs3Way: false,
      toIs3Way: false,
    );

    expect(generated.single, hasLength(2));
    expect(generated.single.last.junctions, [from, to]);
  });

  test('near-to endpoint takes source reverse append branch', () {
    final graph = SourceArachneSkeletalTrapezoidationGraph2();
    final generated = <List<SourceArachneExtrusionLine2>>[
      <SourceArachneExtrusionLine2>[
        SourceArachneExtrusionLine2(
          insetIndex: 0,
          isOdd: true,
          junctions: [_junction(0, 0), _junction(1000, 0)],
        ),
      ],
    ];
    final from = _junction(3000, 0);
    final to = _junction(1000, 0);

    graph.addToolpathSegment(
      generated,
      from,
      to,
      isOdd: true,
      forceNewPath: false,
      fromIs3Way: false,
      toIs3Way: false,
    );

    expect(generated.single, hasLength(1));
    expect(generated.single.single.junctions.last.p, from.p);
  });

  test('two twin quad chains connect into one closed-by-points even line', () {
    final boundaryA = _node(-10000, 0, 0);
    final peak = _node(0, 5000, 5000, beadCount: 2);
    final boundaryB = _node(10000, 0, 0);

    final a0 = SourceArachneSTHalfEdge2()
      ..from = boundaryA
      ..to = peak;
    final a1 = SourceArachneSTHalfEdge2()
      ..from = peak
      ..to = boundaryB
      ..prev = a0;
    a0.next = a1;

    final b0 = SourceArachneSTHalfEdge2()
      ..from = boundaryB
      ..to = peak;
    final b1 = SourceArachneSTHalfEdge2()
      ..from = peak
      ..to = boundaryA
      ..prev = b0;
    b0.next = b1;

    a0.twin = b1;
    b1.twin = a0;
    a1.twin = b0;
    b0.twin = a1;
    for (final edge in [a0, a1, b0, b1]) {
      _central(edge);
    }

    final left = <SourceArachneExtrusionJunction2>[
      _junction(-5000, 2500),
    ];
    final right = <SourceArachneExtrusionJunction2>[
      _junction(5000, 2500),
    ];
    a0.data.setExtrusionJunctions(left);
    b0.data.setExtrusionJunctions(right);

    final graph = SourceArachneSkeletalTrapezoidationGraph2()
      ..nodes.addAll([boundaryA, peak, boundaryB])
      ..edges.addAll([a0, a1, b0, b1]);
    final owners = <List<SourceArachneExtrusionJunction2>>[left, right];
    final generated = <List<SourceArachneExtrusionLine2>>[];

    graph.connectJunctions(owners, generated);

    expect(generated, hasLength(1));
    expect(generated.single, hasLength(1));
    final line = generated.single.single;
    expect(line.isOdd, isFalse);
    expect(line.junctions.map((junction) => junction.p), const [
      SourcePoint2(-5000, 2500),
      SourcePoint2(5000, 2500),
      SourcePoint2(-5000, 2500),
    ]);
    // `connectJunctions` closes by repeated point; source constructor itself
    // keeps `is_closed=false` at this stage.
    expect(line.isClosed, isFalse);
    expect(owners, hasLength(2));
  });
}
