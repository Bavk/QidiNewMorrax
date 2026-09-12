import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_beading_strategy.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_extrusion_line.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_generate_segments_local_maxima.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_graph.dart';

SourceArachneSTHalfEdgeNode2 _node(
  int x,
  int y,
  int radius,
) =>
    SourceArachneSTHalfEdgeNode2(
      p: SourcePoint2(x, y),
      data: SourceArachneSkeletalJoint2(distanceToBoundary: radius),
    );

SourceArachneBeadingPropagation2 _beading(List<int> widths) =>
    SourceArachneBeadingPropagation2(
      SourceArachneBeading2(
        totalThickness: 2000,
        beadWidths: widths,
        toolpathLocations: [
          for (var index = 0; index < widths.length; index++) index * 100,
        ],
        leftOver: 0,
      ),
    );

void _makeStrictLocalMaximum(
  SourceArachneSTHalfEdgeNode2 peak, {
  required bool central,
}) {
  final lowA = _node(0, 0, 0);
  final lowB = _node(2000, 0, 0);
  final outA = SourceArachneSTHalfEdge2()
    ..from = peak
    ..to = lowA;
  final inA = SourceArachneSTHalfEdge2()
    ..from = lowA
    ..to = peak;
  final outB = SourceArachneSTHalfEdge2()
    ..from = peak
    ..to = lowB;
  final inB = SourceArachneSTHalfEdge2()
    ..from = lowB
    ..to = peak;
  outA.twin = inA;
  inA.twin = outA;
  outB.twin = inB;
  inB.twin = outB;
  inA.next = outB;
  inB.next = outA;
  outA.data.setIsCentral(central);
  outB.data.setIsCentral(central);
  inA.data.setIsCentral(central);
  inB.data.setIsCentral(central);
  peak.incidentEdge = outA;
}

void main() {
  test('odd noncentral strict local maximum generates source six-point circle', () {
    final peak = _node(1000, 2000, 1000);
    peak.data.setBeading(_beading(const [100, 800, 100]));
    _makeStrictLocalMaximum(peak, central: false);
    final graph = SourceArachneSkeletalTrapezoidationGraph2()..nodes.add(peak);
    final generated = <List<SourceArachneExtrusionLine2>>[];

    graph.generateLocalMaximaSingleBeads(generated);

    expect(generated, hasLength(2));
    expect(generated[0], isEmpty);
    expect(generated[1], hasLength(1));
    final line = generated[1].single;
    expect(line.insetIndex, 1);
    expect(line.isOdd, isTrue);
    expect(line.isClosed, isFalse);
    expect(line.junctions.map((junction) => junction.p), const [
      SourcePoint2(1100, 2000),
      SourcePoint2(1050, 2087),
      SourcePoint2(950, 2087),
      SourcePoint2(900, 2000),
      SourcePoint2(950, 1913),
      SourcePoint2(1050, 1913),
    ]);
    expect(line.junctions.map((junction) => junction.w),
        everyElement(800));
    expect(line.junctions.map((junction) => junction.perimeterIndex),
        everyElement(1));
    expect(line.junctions.map((junction) => junction.holeCompensationFlag),
        everyElement(isFalse));
  });

  test('integer width divided by eight before source circle geometry', () {
    final peak = _node(0, 0, 1000);
    peak.data.setBeading(_beading(const [100, 807, 100]));
    _makeStrictLocalMaximum(peak, central: false);
    final graph = SourceArachneSkeletalTrapezoidationGraph2()..nodes.add(peak);
    final generated = <List<SourceArachneExtrusionLine2>>[];

    graph.generateLocalMaximaSingleBeads(generated);

    // 807 / 8 truncates to radius 100 before trig, not 100.875.
    expect(generated[1].single.junctions.first.p, const SourcePoint2(100, 0));
    expect(generated[1].single.junctions.first.w, 807);
  });

  test('even beading never creates a local-maximum single bead', () {
    final peak = _node(1000, 2000, 1000);
    peak.data.setBeading(_beading(const [400, 400]));
    _makeStrictLocalMaximum(peak, central: false);
    final graph = SourceArachneSkeletalTrapezoidationGraph2()..nodes.add(peak);
    final generated = <List<SourceArachneExtrusionLine2>>[];

    graph.generateLocalMaximaSingleBeads(generated);

    expect(generated, isEmpty);
  });

  test('central local maximum is excluded after strict maximum check', () {
    final peak = _node(1000, 2000, 1000);
    peak.data.setBeading(_beading(const [100, 800, 100]));
    _makeStrictLocalMaximum(peak, central: true);
    final graph = SourceArachneSkeletalTrapezoidationGraph2()..nodes.add(peak);
    final generated = <List<SourceArachneExtrusionLine2>>[];

    graph.generateLocalMaximaSingleBeads(generated);

    expect(generated, isEmpty);
  });

  test('node without beading is skipped before radial topology is inspected', () {
    final node = _node(0, 0, 1000);
    final graph = SourceArachneSkeletalTrapezoidationGraph2()..nodes.add(node);
    final generated = <List<SourceArachneExtrusionLine2>>[];

    graph.generateLocalMaximaSingleBeads(generated);

    expect(generated, isEmpty);
  });
}
