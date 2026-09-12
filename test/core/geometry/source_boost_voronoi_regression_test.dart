import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_boost_voronoi_builder.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';

void main() {
  test('Voronoi missing edges - points 12067 matches Boost 1.83 oracle', () {
    final builder = SourceBoostVoronoiBuilder2();
    for (final point in const [
      SourcePoint2(-10, -20),
      SourcePoint2(10, -20),
      SourcePoint2(5, 0),
      SourcePoint2(10, 20),
      SourcePoint2(-10, 20),
      SourcePoint2(-5, 0),
    ]) {
      builder.insertPoint(point.x, point.y);
    }

    final snapshot = builder.constructSnapshot();
    expect(snapshot.vertices, hasLength(4));
    expect(snapshot.cells, hasLength(6));
    expect(snapshot.edges, hasLength(18));
    expect(
      snapshot.vertices.map((v) => [v.x, v.y]).toList(),
      [
        [-47.5, 0.0],
        [0.0, -11.875],
        [0.0, 11.875],
        [47.5, 0.0],
      ],
    );
    expect(snapshot.vertices.every((v) => v.x.isFinite && v.y.isFinite), true);
  });

  test('Voronoi division by zero 12903 keeps exact-fallback output finite', () {
    final builder = SourceBoostVoronoiBuilder2();
    for (final point in const [
      SourcePoint2(1, 1),
      SourcePoint2(3, 1),
      SourcePoint2(1, 3),
      SourcePoint2(3, 3),
      SourcePoint2(-1, 1),
      SourcePoint2(1, -1),
      SourcePoint2(5, 1),
      SourcePoint2(3, -1),
      SourcePoint2(-1, 3),
      SourcePoint2(1, 5),
      SourcePoint2(5, 3),
      SourcePoint2(3, 5),
    ]) {
      builder.insertPoint(point.x, point.y);
    }

    final snapshot = builder.constructSnapshot();
    expect(snapshot.vertices, hasLength(9));
    expect(snapshot.cells, hasLength(12));
    expect(snapshot.edges, hasLength(40));
    expect(snapshot.vertices.every((v) => v.x.isFinite && v.y.isFinite), true);
    expect(
      snapshot.vertices.take(5).map((v) => [v.x, v.y]).toList(),
      [
        [0.0, 0.0],
        [0.0, 2.0],
        [0.0, 4.0],
        [2.0, 0.0],
        [2.0, 2.0],
      ],
    );
  });

  test('Voronoi missing vertex 1 preserves raw Boost regression topology', () {
    const points = [
      SourcePoint2(25000000, 25000000),
      SourcePoint2(-25000000, 25000000),
      SourcePoint2(-25000000, -25000000),
      SourcePoint2(-12412500, -25000000),
      SourcePoint2(25000000, -25000000),
    ];
    final builder = SourceBoostVoronoiBuilder2();
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      builder.insertSegment(a.x, a.y, b.x, b.y);
    }

    final snapshot = builder.constructSnapshot();
    expect(snapshot.vertices, hasLength(6));
    expect(snapshot.cells, hasLength(10));
    expect(snapshot.edges, hasLength(30));
    expect(snapshot.vertices.every((v) => v.x.isFinite && v.y.isFinite), true);
    expect(snapshot.vertices[2].x, -12412500);
    expect(snapshot.vertices[2].y, -12412500);
  });

  test('Intersecting Voronoi edges regression retains close distinct vertices', () {
    const points = [
      SourcePoint2(25000000, 25000000),
      SourcePoint2(-25000000, 25000000),
      SourcePoint2(-25000000, -25000000),
      SourcePoint2(146872, -25000000),
      SourcePoint2(25000000, -25000000),
      SourcePoint2(25000000, -146873),
    ];
    final builder = SourceBoostVoronoiBuilder2();
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      builder.insertSegment(a.x, a.y, b.x, b.y);
    }

    final snapshot = builder.constructSnapshot();
    expect(snapshot.vertices, hasLength(8));
    expect(snapshot.cells, hasLength(12));
    expect(snapshot.edges, hasLength(38));
    expect(snapshot.vertices[3].x, 146873);
    expect(snapshot.vertices[3].y, -146873);
    expect(snapshot.vertices[4].x, 146872);
    expect(snapshot.vertices[4].y, closeTo(-146871.9999999799, 1e-8));
  });
}
