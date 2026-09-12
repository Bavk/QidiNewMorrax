import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_construct_from_polygons.dart';

SourcePolygon2 _square() => SourcePolygon2(const [
      SourcePoint2(0, 0),
      SourcePoint2(100000, 0),
      SourcePoint2(100000, 100000),
      SourcePoint2(0, 100000),
    ]);

SourceArachneConstructedGraph2 _construct({
  bool enableHoleCompensation = false,
  Iterable<int> holeIndices = const <int>[],
}) =>
    SourceArachneConstructFromPolygons2.construct(
      [_square()],
      transitioningAngle: 1.0,
      discretizationStepSize: 10000,
      enableHoleCompensation: enableHoleCompensation,
      holeIndices: holeIndices,
    );

void main() {
  test('real Boost square composes polygon cells into a skeletal graph', () {
    final result = _construct();
    final graph = result.graph;

    expect(result.topology.cells, isNotEmpty);
    expect(result.topology.edges, isNotEmpty);
    expect(graph.nodes, isNotEmpty);
    expect(graph.edges, isNotEmpty);
    expect(
      graph.nodes.where((node) => node.data.distanceToBoundary == 0),
      isNotEmpty,
    );
    expect(
      graph.edges.every((edge) => edge.from != null && edge.to != null),
      isTrue,
    );
  });

  test('post-construction cleanup leaves reciprocal twins and chain starts', () {
    final graph = _construct().graph;

    for (final edge in graph.edges) {
      expect(edge.twin, isNotNull);
      expect(edge.twin!.twin, same(edge));
      if (edge.prev == null) {
        expect(edge.from, isNotNull);
        expect(edge.from!.incidentEdge, same(edge));
      }
    }
  });

  test('construct maps every retained Boost vertex through source identity map', () {
    final result = _construct();

    expect(result.transfer.vdNodeToHeNode, isNotEmpty);
    for (final entry in result.transfer.vdNodeToHeNode.entries) {
      expect(entry.key, inInclusiveRange(0, result.topology.vertices.length - 1));
      expect(result.graph.nodes.any((node) => identical(node, entry.value)), isTrue);
    }
  });

  test('hole compensation is disabled when source polygon is not a hole', () {
    final graph = _construct(
      enableHoleCompensation: true,
      holeIndices: const <int>[],
    ).graph;

    expect(graph.edges.every((edge) => !edge.data.holeCompensationFlag), isTrue);
  });

  test('hole index propagates compensation flag through transferred ribs', () {
    final graph = _construct(
      enableHoleCompensation: true,
      holeIndices: const <int>[0],
    ).graph;

    expect(graph.edges, isNotEmpty);
    expect(graph.edges.every((edge) => edge.data.holeCompensationFlag), isTrue);
  });
}
