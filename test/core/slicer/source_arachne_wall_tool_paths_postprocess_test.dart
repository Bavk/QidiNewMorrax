import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_extrusion_line.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths_postprocess.dart';

SourceArachneExtrusionLine2 _line({
  required int width,
  required List<SourcePoint2> points,
  int inset = 0,
  bool odd = false,
  bool closed = false,
}) =>
    SourceArachneExtrusionLine2(
      insetIndex: inset,
      isOdd: odd,
      isClosed: closed,
      junctions: [
        for (final point in points)
          SourceArachneExtrusionJunction2(
            p: point,
            w: width,
            perimeterIndex: inset,
          ),
      ],
    );

List<SourcePoint2> _square(int offset) => [
      SourcePoint2(offset, offset),
      SourcePoint2(offset + 100, offset),
      SourcePoint2(offset + 100, offset + 100),
      SourcePoint2(offset, offset + 100),
      SourcePoint2(offset, offset),
    ];

void main() {
  test('removeSmallLines preserves source back-to-front closure quirk', () {
    final short = _line(
      width: 20,
      odd: true,
      points: [const SourcePoint2(0, 0), const SourcePoint2(3, 0)],
    );
    final toolpaths = <List<SourceArachneExtrusionLine2>>[
      [short],
    ];

    // Pinned shorterThan measures 3 units back->front plus 3 front->back = 6,
    // which remains strictly below min_width / 2 == 10.
    SourceArachneWallToolPathsPostprocess2.removeSmallLines(toolpaths);

    expect(toolpaths.single, isEmpty);
  });

  test('removeSmallLines keeps exact source threshold boundary', () {
    final boundary = _line(
      width: 20,
      odd: true,
      points: [const SourcePoint2(0, 0), const SourcePoint2(5, 0)],
    );
    final toolpaths = <List<SourceArachneExtrusionLine2>>[
      [boundary],
    ];

    // Total source helper length is exactly 10. `length >= check_length`
    // returns false from shorterThan, so the line stays.
    SourceArachneWallToolPathsPostprocess2.removeSmallLines(toolpaths);

    expect(toolpaths.single, hasLength(1));
  });

  test('removeSmallLines only removes odd open lines', () {
    final even = _line(
      width: 20,
      points: [const SourcePoint2(0, 0), const SourcePoint2(3, 0)],
    );
    final closedOdd = _line(
      width: 20,
      odd: true,
      closed: true,
      points: [const SourcePoint2(0, 0), const SourcePoint2(3, 0)],
    );
    final toolpaths = <List<SourceArachneExtrusionLine2>>[
      [even, closedOdd],
    ];

    SourceArachneWallToolPathsPostprocess2.removeSmallLines(toolpaths);

    expect(toolpaths.single, hasLength(2));
  });

  test('removeSmallLines reconsiders swap-with-last source slot', () {
    final firstShort = _line(
      width: 20,
      odd: true,
      points: [const SourcePoint2(0, 0), const SourcePoint2(2, 0)],
    );
    final kept = _line(
      width: 20,
      odd: true,
      points: [const SourcePoint2(0, 0), const SourcePoint2(10, 0)],
    );
    final lastShort = _line(
      width: 20,
      odd: true,
      points: [const SourcePoint2(0, 0), const SourcePoint2(1, 0)],
    );
    final toolpaths = <List<SourceArachneExtrusionLine2>>[
      [firstShort, kept, lastShort],
    ];

    SourceArachneWallToolPathsPostprocess2.removeSmallLines(toolpaths);

    expect(toolpaths.single, hasLength(1));
    expect(toolpaths.single.single.junctions.last.p, const SourcePoint2(10, 0));
  });

  test('separateOutInnerContour extracts zero and one width markers', () {
    final inner = _line(width: 0, closed: true, points: _square(0));
    final first = _line(width: 1, closed: true, points: _square(1000));
    final actual = _line(width: 250, closed: true, points: _square(2000));

    final result =
        SourceArachneWallToolPathsPostprocess2.separateOutInnerContour([
      [inner],
      [first],
      [actual],
    ]);

    expect(result.innerContour, hasLength(1));
    expect(result.firstWallContour, hasLength(1));
    expect(result.toolpaths, hasLength(1));
    expect(result.toolpaths.single.single.junctions.first.w, 250);
  });

  test('odd marker lines do not contribute contour polygons', () {
    final innerOdd = _line(
      width: 0,
      odd: true,
      closed: true,
      points: _square(0),
    );
    final firstOdd = _line(
      width: 1,
      odd: true,
      closed: true,
      points: _square(1000),
    );

    final result =
        SourceArachneWallToolPathsPostprocess2.separateOutInnerContour([
      [innerOdd],
      [firstOdd],
    ]);

    expect(result.innerContour, isEmpty);
    expect(result.firstWallContour, isEmpty);
    expect(result.toolpaths, isEmpty);
  });

  test('last nonempty line first junction selects inset source type', () {
    final marker = _line(width: 0, closed: true, points: _square(0));
    final actual = _line(width: 300, closed: true, points: _square(1000));

    final result =
        SourceArachneWallToolPathsPostprocess2.separateOutInnerContour([
      [marker, actual],
    ]);

    // Source breaks only the inner junction loop, so the later line overwrites
    // the earlier marker classification and the entire inset remains actual.
    expect(result.toolpaths, hasLength(1));
    expect(result.toolpaths.single, hasLength(2));
    expect(result.innerContour, isEmpty);
  });

  test('removeEmptyToolPaths erases empty insets and reports final state', () {
    final actual = _line(
      width: 200,
      points: [const SourcePoint2(0, 0), const SourcePoint2(10, 0)],
    );
    final mixed = <List<SourceArachneExtrusionLine2>>[
      [],
      [actual],
      [],
    ];

    expect(
      SourceArachneWallToolPathsPostprocess2.removeEmptyToolPaths(mixed),
      isFalse,
    );
    expect(mixed, hasLength(1));

    mixed.clear();
    mixed.addAll([[], []]);
    expect(
      SourceArachneWallToolPathsPostprocess2.removeEmptyToolPaths(mixed),
      isTrue,
    );
    expect(mixed, isEmpty);
  });
}
