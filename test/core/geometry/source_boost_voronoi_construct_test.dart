import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_boost_voronoi_builder.dart';

void main() {
  test('single point snapshot matches Boost 1.83 C++ oracle', () {
    final snapshot = (SourceBoostVoronoiBuilder2()..insertPoint(0, 0))
        .constructSnapshot();

    expect(snapshot.vertices, isEmpty);
    expect(snapshot.edges, isEmpty);
    expect(snapshot.cells, hasLength(1));
    final cell = snapshot.cells.single;
    expect(cell.sourceIndex, 0);
    expect(cell.sourceCategory, 0);
    expect(cell.incidentEdge, -1);
    expect(cell.degenerate, true);
  });

  test('two point snapshot matches Boost 1.83 line-edge topology', () {
    final builder = SourceBoostVoronoiBuilder2()
      ..insertPoint(0, 0)
      ..insertPoint(10, 0);
    final snapshot = builder.constructSnapshot();

    expect(snapshot.vertices, isEmpty);
    expect(
      snapshot.cells
          .map((c) => [
                c.sourceIndex,
                c.sourceCategory,
                c.incidentEdge,
                c.degenerate,
              ])
          .toList(),
      [
        [0, 0, 0, false],
        [1, 0, 1, false],
      ],
    );
    expect(
      snapshot.edges.map(_edgeTuple).toList(),
      [
        [-1, -1, 0, 1, 0, 0, 1, true, true, false],
        [-1, -1, 1, 0, 1, 1, 0, true, true, false],
      ],
    );
  });

  test('three vertical points use Boost collinear beach-line initialization', () {
    final builder = SourceBoostVoronoiBuilder2()
      ..insertPoint(0, 0)
      ..insertPoint(0, 10)
      ..insertPoint(0, 20);
    final snapshot = builder.constructSnapshot();

    expect(snapshot.vertices, isEmpty);
    expect(
      snapshot.cells
          .map((c) => [c.sourceIndex, c.sourceCategory, c.incidentEdge])
          .toList(),
      [
        [0, 0, 0],
        [1, 0, 2],
        [2, 0, 3],
      ],
    );
    expect(
      snapshot.edges.map(_edgeTuple).toList(),
      [
        [-1, -1, 0, 1, 0, 0, 1, true, true, false],
        [-1, -1, 1, 0, 2, 2, 3, true, true, false],
        [-1, -1, 1, 3, 1, 1, 0, true, true, false],
        [-1, -1, 2, 2, 3, 3, 2, true, true, false],
      ],
    );
  });

  test('three point circle event matches complete Boost 1.83 topology', () {
    final builder = SourceBoostVoronoiBuilder2()
      ..insertPoint(0, 0)
      ..insertPoint(0, 10)
      ..insertPoint(10, 0);
    final snapshot = builder.constructSnapshot();

    expect(snapshot.vertices, hasLength(1));
    expect(snapshot.vertices.single.x, 5);
    expect(snapshot.vertices.single.y, 5);
    expect(snapshot.vertices.single.incidentEdge, 5);
    expect(
      snapshot.cells
          .map((c) => [c.sourceIndex, c.sourceCategory, c.incidentEdge])
          .toList(),
      [
        [0, 0, 2],
        [1, 0, 5],
        [2, 0, 4],
      ],
    );
    expect(
      snapshot.edges.map(_edgeTuple).toList(),
      [
        [0, -1, 0, 1, 2, 2, 3, true, true, false],
        [-1, 0, 1, 0, 5, 5, 4, true, true, false],
        [-1, 0, 0, 3, 0, 0, 1, true, true, false],
        [0, -1, 2, 2, 4, 4, 5, true, true, false],
        [-1, 0, 2, 5, 3, 3, 2, true, true, false],
        [0, -1, 1, 4, 1, 1, 0, true, true, false],
      ],
    );
  });

  test('square segment diagram matches full Boost 1.83 half-edge golden', () {
    final builder = SourceBoostVoronoiBuilder2()
      ..insertSegment(0, 0, 100, 0)
      ..insertSegment(100, 0, 100, 100)
      ..insertSegment(100, 100, 0, 100)
      ..insertSegment(0, 100, 0, 0);
    final snapshot = builder.constructSnapshot();

    expect(snapshot.vertices, hasLength(5));
    expect(snapshot.cells, hasLength(8));
    expect(snapshot.edges, hasLength(24));
    expect(
      snapshot.vertices.map((v) => [v.x, v.y, v.incidentEdge]).toList(),
      [
        [0.0, 0.0, 7],
        [-0.0, 100.0, 11],
        [100.0, -0.0, 17],
        [50.0, 50.0, 19],
        [100.0, 100.0, 23],
      ],
    );
    expect(snapshot.vertices[1].x.isNegative, true);
    expect(snapshot.vertices[2].y.isNegative, true);

    expect(
      snapshot.cells
          .map((c) => [
                c.sourceIndex,
                c.sourceCategory,
                c.incidentEdge,
                c.degenerate,
              ])
          .toList(),
      [
        [0, 1, 4, false],
        [3, 9, 10, false],
        [2, 2, 8, false],
        [0, 8, 17, false],
        [2, 9, 23, false],
        [0, 2, 14, false],
        [1, 8, 20, false],
        [1, 2, 22, false],
      ],
    );

    expect(
      snapshot.edges.map(_edgeTuple).toList(),
      [
        [0, -1, 0, 1, 4, 4, 5, false, true, false],
        [-1, 0, 1, 0, 7, 2, 3, false, true, false],
        [1, -1, 1, 3, 1, 10, 11, false, true, false],
        [-1, 1, 2, 2, 8, 8, 9, false, true, false],
        [-1, 0, 0, 5, 0, 0, 1, false, true, false],
        [0, -1, 3, 4, 12, 6, 7, false, true, false],
        [3, 0, 3, 7, 5, 17, 16, true, true, true],
        [0, 3, 1, 6, 10, 1, 0, true, true, true],
        [1, -1, 2, 9, 3, 3, 2, false, true, false],
        [-1, 1, 4, 8, 11, 23, 22, false, true, false],
        [3, 1, 1, 11, 2, 7, 6, true, true, true],
        [1, 3, 4, 10, 19, 9, 8, true, true, true],
        [-1, 2, 3, 13, 17, 5, 4, false, true, false],
        [2, -1, 5, 12, 14, 14, 15, false, true, false],
        [-1, 2, 5, 15, 13, 13, 12, false, true, false],
        [2, -1, 6, 14, 20, 16, 17, false, true, false],
        [3, 2, 6, 17, 15, 18, 19, true, true, true],
        [2, 3, 3, 16, 6, 12, 13, true, true, true],
        [4, 3, 6, 19, 16, 20, 21, true, true, true],
        [3, 4, 4, 18, 23, 11, 10, true, true, true],
        [-1, 4, 6, 21, 18, 15, 14, false, true, false],
        [4, -1, 7, 20, 22, 22, 23, false, true, false],
        [-1, 4, 7, 23, 21, 21, 20, false, true, false],
        [4, -1, 4, 22, 9, 19, 18, false, true, false],
      ],
    );
  });
}

List<Object> _edgeTuple(dynamic edge) => [
      edge.vertex0,
      edge.vertex1,
      edge.cell,
      edge.twin,
      edge.next,
      edge.prev,
      edge.rotNext,
      edge.primary,
      edge.linear,
      edge.finite,
    ];
