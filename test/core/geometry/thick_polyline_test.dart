import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/point.dart';
import 'package:qidi_flow_flutter/core/geometry/thick_polyline.dart';

void main() {
  test('thicklines maps source width pairs to each segment', () {
    final polyline = ThickPolyline2(
      points: const [Point2(0, 0), Point2(10, 0), Point2(10, 5)],
      width: const [1, 2, 3, 4],
    );

    final lines = polyline.thickLines();
    expect(lines, hasLength(2));
    expect(lines[0].aWidth, 1);
    expect(lines[0].bWidth, 2);
    expect(lines[1].aWidth, 3);
    expect(lines[1].bWidth, 4);
  });

  test('reverse exactly reverses points/widths and swaps endpoint flags', () {
    final polyline = ThickPolyline2(
      points: const [Point2(0, 0), Point2(10, 0), Point2(20, 0)],
      width: const [1, 2, 3, 4],
      startIsEndpoint: true,
      endIsEndpoint: false,
    );

    polyline.reverse();
    expect(polyline.points.map((p) => p.x).toList(), [20, 10, 0]);
    expect(polyline.width, [4, 3, 2, 1]);
    expect(polyline.startIsEndpoint, false);
    expect(polyline.endIsEndpoint, true);
  });

  test('rebaseAt ports ThickPolyline::rebase_at width indexing', () {
    final polyline = ThickPolyline2(
      points: const [
        Point2(0, 0),
        Point2(10, 0),
        Point2(10, 10),
        Point2(0, 0),
      ],
      width: const [1, 2, 3, 4, 5, 1],
    );

    final rebased = polyline.rebaseAt(1);
    expect(
      rebased.points.map((p) => '${p.x},${p.y}').toList(),
      ['10.0,0.0', '10.0,10.0', '0.0,0.0', '10.0,0.0'],
    );
    expect(rebased.width, [3, 4, 5, 1, 2, 3]);
  });

  test('rebaseAt returns empty source-style result for open polyline', () {
    final open = ThickPolyline2(
      points: const [Point2(0, 0), Point2(1, 0)],
      width: const [1, 1],
    );
    expect(open.rebaseAt(0).isEmpty, true);
  });

  test('getWidthAt retains source indexing quirk', () {
    final polyline = ThickPolyline2(
      points: const [
        Point2(0, 0),
        Point2(1, 0),
        Point2(2, 0),
        Point2(3, 0),
      ],
      width: const [10, 11, 20, 21, 30, 31],
    );
    expect(polyline.getWidthAt(0), 10);
    expect(polyline.getWidthAt(1), 11);
    expect(polyline.getWidthAt(2), 21);
    expect(polyline.getWidthAt(3), 31);
  });

  test('constructor enforces source width cardinality invariant', () {
    expect(
      () => ThickPolyline2(
        points: const [Point2(0, 0), Point2(1, 0), Point2(2, 0)],
        width: const [1, 2],
      ),
      throwsStateError,
    );
  });
}
