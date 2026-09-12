import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/medial_axis_postprocess.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/thick_polyline.dart';

SourceExPolygon2 square10mm() => SourceExPolygon2(
      contour: SourcePolygon2(const [
        SourcePoint2(0, 0),
        SourcePoint2(1000000, 0),
        SourcePoint2(1000000, 1000000),
        SourcePoint2(0, 1000000),
      ]),
    );

void main() {
  const post = MedialAxisPostProcessor();

  test('extends true medial-axis endpoints to ExPolygon contour', () {
    final result = post.process(
      expolygon: square10mm(),
      maxWidth: 500000,
      rawPolylines: [
        ThickPolyline2(
          points: const [
            SourcePoint2(200000, 500000),
            SourcePoint2(800000, 500000),
          ],
          width: const [100000, 100000],
          startIsEndpoint: true,
          endIsEndpoint: true,
        ),
      ],
    );

    expect(result, hasLength(1));
    expect(result.single.firstPoint, const SourcePoint2(0, 500000));
    expect(result.single.lastPoint, const SourcePoint2(1000000, 500000));
  });

  test('does not extend endpoint already on any ExPolygon boundary', () {
    final expolygon = SourceExPolygon2(
      contour: square10mm().contour,
      holes: [
        SourcePolygon2(const [
          SourcePoint2(400000, 400000),
          SourcePoint2(400000, 600000),
          SourcePoint2(600000, 600000),
          SourcePoint2(600000, 400000),
        ]),
      ],
    );
    final result = post.process(
      expolygon: expolygon,
      maxWidth: 1000000,
      rawPolylines: [
        ThickPolyline2(
          points: const [
            SourcePoint2(400000, 500000),
            SourcePoint2(0, 500000),
          ],
          width: const [100000, 100000],
          startIsEndpoint: true,
          endIsEndpoint: true,
        ),
      ],
    );

    expect(result, hasLength(1));
    expect(result.single.firstPoint, const SourcePoint2(400000, 500000));
  });

  test('removes source-style short endpoint branches after extension attempt', () {
    final result = post.process(
      expolygon: square10mm(),
      maxWidth: 20000,
      rawPolylines: [
        ThickPolyline2(
          points: const [
            SourcePoint2(450000, 500000),
            SourcePoint2(550000, 500000),
          ],
          width: const [100000, 100000],
          startIsEndpoint: true,
          endIsEndpoint: false,
        ),
      ],
    );
    expect(result, isEmpty);
  });

  test('after pruning, greedily reconnects source-compatible consecutive branches', () {
    final result = post.process(
      expolygon: square10mm(),
      maxWidth: 1000,
      rawPolylines: [
        ThickPolyline2(
          points: const [
            SourcePoint2(100000, 100000),
            SourcePoint2(200000, 100000),
          ],
          width: const [10000, 10000],
        ),
        ThickPolyline2(
          points: const [
            SourcePoint2(200000, 100000),
            SourcePoint2(300000, 100000),
          ],
          width: const [10000, 10000],
        ),
        // Forces the source `removed` path, then gets pruned.
        ThickPolyline2(
          points: const [
            SourcePoint2(500000, 500000),
            SourcePoint2(505000, 500000),
          ],
          width: const [10000, 10000],
          startIsEndpoint: true,
        ),
      ],
    );

    expect(result, hasLength(1));
    expect(
      result.single.points.map((p) => p.x).toList(),
      [100000, 200000, 300000],
    );
    expect(result.single.width, [10000, 10000, 10000, 10000]);
  });
}
