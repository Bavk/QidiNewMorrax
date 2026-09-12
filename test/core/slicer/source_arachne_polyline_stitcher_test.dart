import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_extrusion_line.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_polyline_stitcher.dart';

SourceArachneExtrusionLine2 _line(
  List<int> xs, {
  required bool odd,
  int inset = 0,
  int width = 2000,
}) =>
    SourceArachneExtrusionLine2(
      insetIndex: inset,
      isOdd: odd,
      junctions: [
        for (var index = 0; index < xs.length; index++)
          SourceArachneExtrusionJunction2(
            p: SourcePoint2(xs[index], 0),
            w: width + index,
            perimeterIndex: inset,
            holeCompensationFlag: index.isOdd,
          ),
      ],
    );

void main() {
  test('snap-connect joins odd lines and skips duplicate-near endpoint', () {
    final first = _line([0, 1000], odd: true);
    final second = _line([1005, 2000], odd: true);

    final result = SourceArachnePolylineStitcher2.stitch(
      [first, second],
      maxStitchDistance: 100,
      snapDistance: 10,
    );

    expect(result.polygons, isEmpty);
    expect(result.lines, hasLength(1));
    // Pinned implementation tries the reverse extension pass after the forward
    // join. Odd lines are reversible, so a non-closed result remains reversed.
    expect(
      result.lines.single.junctions.map((junction) => junction.p.x).toList(),
      [2000, 1000, 0],
    );
    expect(result.lines.single.junctions, hasLength(3));
  });

  test('even wall refuses connection that would reverse candidate', () {
    final first = _line([0, 1000], odd: false);
    final second = _line([2000, 1005], odd: false);

    final result = SourceArachnePolylineStitcher2.stitch(
      [first, second],
      maxStitchDistance: 100,
      snapDistance: 10,
    );

    expect(result.polygons, isEmpty);
    expect(result.lines, hasLength(2));
    expect(
      result.lines[0].junctions.map((junction) => junction.p.x).toList(),
      [0, 1000],
    );
    expect(
      result.lines[1].junctions.map((junction) => junction.p.x).toList(),
      [2000, 1005],
    );
  });

  test('odd and even source lines are never stitched together', () {
    final odd = _line([0, 1000], odd: true);
    final even = _line([1005, 2000], odd: false);

    final result = SourceArachnePolylineStitcher2.stitch(
      [odd, even],
      maxStitchDistance: 100,
      snapDistance: 10,
    );

    expect(result.polygons, isEmpty);
    expect(result.lines, hasLength(2));
  });

  test('single long odd chain closes through its own processed front', () {
    final line = SourceArachneExtrusionLine2(
      insetIndex: 0,
      isOdd: true,
      junctions: [
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(0, 0),
          w: 12000,
          perimeterIndex: 0,
        ),
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(20000, 0),
          w: 12000,
          perimeterIndex: 0,
        ),
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(20000, 20000),
          w: 12000,
          perimeterIndex: 0,
        ),
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(0, 500),
          w: 12000,
          perimeterIndex: 0,
        ),
      ],
    );

    final result = SourceArachnePolylineStitcher2.stitch(
      [line],
      maxStitchDistance: 10000,
      snapDistance: 999,
    );

    expect(result.lines, isEmpty);
    expect(result.polygons, hasLength(1));
    expect(result.polygons.single.isClosed, isFalse);
    expect(result.polygons.single.junctions, hasLength(4));
  });

  test('tiny chain is deliberately not closed into a polygon', () {
    final line = SourceArachneExtrusionLine2(
      insetIndex: 0,
      isOdd: true,
      junctions: [
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(0, 0),
          w: 12000,
          perimeterIndex: 0,
        ),
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(1000, 0),
          w: 12000,
          perimeterIndex: 0,
        ),
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(1000, 1000),
          w: 12000,
          perimeterIndex: 0,
        ),
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(0, 500),
          w: 12000,
          perimeterIndex: 0,
        ),
      ],
    );

    final result = SourceArachnePolylineStitcher2.stitch(
      [line],
      maxStitchDistance: 10000,
      snapDistance: 999,
    );

    expect(result.polygons, isEmpty);
    expect(result.lines, hasLength(1));
  });

  test('WallToolPaths stitch reconnects near closure and marks line closed', () {
    final polygonCandidate = SourceArachneExtrusionLine2(
      insetIndex: 0,
      isOdd: true,
      junctions: [
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(0, 0),
          w: 12000,
          perimeterIndex: 0,
        ),
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(20000, 0),
          w: 12000,
          perimeterIndex: 0,
        ),
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(20000, 20000),
          w: 12000,
          perimeterIndex: 0,
        ),
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(0, 500),
          w: 12000,
          perimeterIndex: 0,
        ),
      ],
    );
    final toolpaths = <List<SourceArachneExtrusionLine2>>[
      [polygonCandidate],
    ];

    SourceArachnePolylineStitcher2.stitchToolPaths(toolpaths, 10001);

    expect(toolpaths.single, hasLength(1));
    final closed = toolpaths.single.single;
    expect(closed.isClosed, isTrue);
    expect(closed.junctions, hasLength(5));
    expect(closed.front.p, closed.back.p);
    expect(closed.front.w, closed.back.w);
  });

  test('snap join copies candidate junction metadata literally', () {
    final first = _line([0, 1000], odd: true, width: 3000);
    final second = _line([1005, 2000], odd: true, width: 4000);

    final result = SourceArachnePolylineStitcher2.stitch(
      [first, second],
      maxStitchDistance: 100,
      snapDistance: 10,
    );

    final byX = {
      for (final junction in result.lines.single.junctions)
        junction.p.x: junction,
    };
    expect(byX[2000]!.w, 4001);
    expect(byX[2000]!.holeCompensationFlag, isTrue);
  });
}
