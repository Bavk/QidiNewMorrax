import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/expolygon.dart';
import 'package:qidi_flow_flutter/core/geometry/medial_axis_postprocess.dart';
import 'package:qidi_flow_flutter/core/geometry/point.dart';
import 'package:qidi_flow_flutter/core/geometry/polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/thick_polyline.dart';

ExPolygon2 square10() => ExPolygon2(
      contour: Polygon2(const [
        Point2(0, 0),
        Point2(10, 0),
        Point2(10, 10),
        Point2(0, 10),
      ]),
    );

void main() {
  const post = MedialAxisPostProcessor();

  test('extends true medial-axis endpoints to ExPolygon contour', () {
    final result = post.process(
      expolygon: square10(),
      maxWidth: 5,
      rawPolylines: [
        ThickPolyline2(
          points: const [Point2(2, 5), Point2(8, 5)],
          width: const [1, 1],
          startIsEndpoint: true,
          endIsEndpoint: true,
        ),
      ],
    );

    expect(result, hasLength(1));
    expect(result.single.firstPoint.x, closeTo(0, 1e-12));
    expect(result.single.firstPoint.y, closeTo(5, 1e-12));
    expect(result.single.lastPoint.x, closeTo(10, 1e-12));
    expect(result.single.lastPoint.y, closeTo(5, 1e-12));
  });

  test('does not extend endpoint already on any ExPolygon boundary', () {
    final expolygon = ExPolygon2(
      contour: square10().contour,
      holes: [
        Polygon2(const [
          Point2(4, 4),
          Point2(4, 6),
          Point2(6, 6),
          Point2(6, 4),
        ]),
      ],
    );
    final result = post.process(
      expolygon: expolygon,
      maxWidth: 10,
      rawPolylines: [
        ThickPolyline2(
          points: const [Point2(4, 5), Point2(0, 5)],
          width: const [1, 1],
          startIsEndpoint: true,
          endIsEndpoint: true,
        ),
      ],
    );

    expect(result, hasLength(1));
    expect(result.single.firstPoint.x, 4);
    expect(result.single.firstPoint.y, 5);
  });

  test('removes source-style short endpoint branches after extension attempt', () {
    final result = post.process(
      expolygon: square10(),
      maxWidth: 0.2,
      rawPolylines: [
        ThickPolyline2(
          points: const [Point2(4.5, 5), Point2(5.5, 5)],
          width: const [1, 1],
          startIsEndpoint: true,
          endIsEndpoint: false,
        ),
      ],
    );
    expect(result, isEmpty);
  });

  test('after pruning, greedily reconnects source-compatible consecutive branches', () {
    final result = post.process(
      expolygon: square10(),
      maxWidth: 0.01,
      rawPolylines: [
        ThickPolyline2(
          points: const [Point2(1, 1), Point2(2, 1)],
          width: const [0.1, 0.1],
        ),
        ThickPolyline2(
          points: const [Point2(2, 1), Point2(3, 1)],
          width: const [0.1, 0.1],
        ),
        // Forces the source `removed` path, then gets pruned.
        ThickPolyline2(
          points: const [Point2(5, 5), Point2(5.05, 5)],
          width: const [0.1, 0.1],
          startIsEndpoint: true,
        ),
      ],
    );

    expect(result, hasLength(1));
    expect(result.single.points.map((p) => p.x).toList(), [1, 2, 3]);
    expect(result.single.width, [0.1, 0.1, 0.1, 0.1]);
  });
}
