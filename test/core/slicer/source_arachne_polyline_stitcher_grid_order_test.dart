import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_extrusion_line.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_polyline_stitcher.dart';

SourceArachneExtrusionLine2 _evenLine(List<int> xs) =>
    SourceArachneExtrusionLine2(
      insetIndex: 0,
      isOdd: false,
      junctions: [
        for (final x in xs)
          SourceArachneExtrusionJunction2(
            p: SourcePoint2(x, 0),
            w: 2000,
            perimeterIndex: 0,
          ),
      ],
    );

void main() {
  test('same-cell snap search follows pinned libstdc++ reverse insertion order',
      () {
    final result = SourceArachnePolylineStitcher2.stitch(
      [
        _evenLine([0, 1000]),
        _evenLine([1005, 2000]),
        _evenLine([1006, 3000]),
      ],
      maxStitchDistance: 100,
      snapDistance: 10,
    );

    // `SparsePointGrid` stores endpoints in an unordered_multimap. With the
    // pinned libstdc++ behavior used by the source, equal cell keys iterate in
    // reverse insertion order. Therefore line 2's front endpoint is the first
    // candidate strictly inside snap distance and the search stops there even
    // though line 1 is geometrically one unit closer.
    expect(result.polygons, isEmpty);
    expect(result.lines, hasLength(2));
    expect(
      result.lines.first.junctions.map((junction) => junction.p.x).toList(),
      [0, 1000, 3000],
    );
    expect(
      result.lines.last.junctions.map((junction) => junction.p.x).toList(),
      [1005, 2000],
    );
  });
}
