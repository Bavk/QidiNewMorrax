import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths_prepare_exact.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_two_convex_contact_union.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_two_convex_partial_collinear_union.dart';

SourcePolygon2 _poly(List<(int, int)> points) => SourcePolygon2([
      for (final point in points) SourcePoint2(point.$1, point.$2),
    ]);

void _expectPartialUnion(
  SourcePolygon2 first,
  SourcePolygon2 second,
  List<SourcePoint2> expected,
) {
  for (final values in [
    [first, second],
    [second, first],
  ]) {
    expect(
      SourceClipper1TwoConvexPartialCollinearUnion2.supports(values),
      isTrue,
    );
    expect(
      SourceClipper1TwoConvexPartialCollinearUnion2.union(values).points,
      expected,
    );
  }
}

void main() {
  test('slanted host-start endpoint overlap matches pinned join start', () {
    _expectPartialUnion(
      _poly([(0, 0), (80000, 120000), (-20000, 100000)]),
      _poly([(40000, 60000), (0, 0), (80000, -10000)]),
      const [
        SourcePoint2(-20000, 100000),
        SourcePoint2(0, 0),
        SourcePoint2(80000, -10000),
        SourcePoint2(40000, 60000),
        SourcePoint2(80000, 120000),
      ],
    );
  });

  test('descending host-start endpoint overlap keeps interior join point', () {
    _expectPartialUnion(
      _poly([(0, 0), (80000, -120000), (100000, -20000)]),
      _poly([(40000, -60000), (0, 0), (-40000, -70000)]),
      const [
        SourcePoint2(40000, -60000),
        SourcePoint2(80000, -120000),
        SourcePoint2(100000, -20000),
        SourcePoint2(0, 0),
        SourcePoint2(-40000, -70000),
      ],
    );
  });

  test('horizontal rightward host-end overlap matches pinned join start', () {
    _expectPartialUnion(
      _poly([(0, 0), (120000, 0), (60000, 60000)]),
      _poly([(120000, 0), (60000, 0), (90000, -60000)]),
      const [
        SourcePoint2(90000, -60000),
        SourcePoint2(120000, 0),
        SourcePoint2(60000, 60000),
        SourcePoint2(0, 0),
        SourcePoint2(60000, 0),
      ],
    );
  });

  test('horizontal leftward host-end overlap matches pinned join start', () {
    _expectPartialUnion(
      _poly([(0, 0), (-120000, 0), (-60000, -60000)]),
      _poly([(-120000, 0), (-60000, 0), (-90000, 60000)]),
      const [
        SourcePoint2(0, 0),
        SourcePoint2(-60000, 0),
        SourcePoint2(-90000, 60000),
        SourcePoint2(-120000, 0),
        SourcePoint2(-60000, -60000),
      ],
    );
  });

  test('increasing-Y non-horizontal host-end overlap is exact', () {
    _expectPartialUnion(
      _poly([(0, 0), (80000, 120000), (-20000, 100000)]),
      _poly([(80000, 120000), (40000, 60000), (120000, 50000)]),
      const [
        SourcePoint2(0, 0),
        SourcePoint2(40000, 60000),
        SourcePoint2(120000, 50000),
        SourcePoint2(80000, 120000),
        SourcePoint2(-20000, 100000),
      ],
    );
  });

  test('guarded decreasing-Y non-horizontal host-end overlap is exact', () {
    _expectPartialUnion(
      _poly([(104400, -316800), (794400, -112800), (68400, -220800)]),
      _poly([(-498600, -460800), (104400, -316800), (97200, -297600)]),
      const [
        SourcePoint2(104400, -316800),
        SourcePoint2(794400, -112800),
        SourcePoint2(68400, -220800),
        SourcePoint2(97200, -297600),
        SourcePoint2(-498600, -460800),
      ],
    );
  });

  test('rightward horizontal staggered overlap is exact', () {
    _expectPartialUnion(
      _poly([(0, 0), (120000, 0), (60000, 60000)]),
      _poly([(180000, 0), (60000, 0), (120000, -60000)]),
      const [
        SourcePoint2(120000, -60000),
        SourcePoint2(180000, 0),
        SourcePoint2(120000, 0),
        SourcePoint2(60000, 60000),
        SourcePoint2(0, 0),
        SourcePoint2(60000, 0),
      ],
    );
  });

  test('leftward horizontal staggered overlap is exact', () {
    _expectPartialUnion(
      _poly([(0, 0), (-120000, 0), (-60000, -60000)]),
      _poly([(-60000, 0), (60000, 0), (0, 60000)]),
      const [
        SourcePoint2(-60000, -60000),
        SourcePoint2(0, 0),
        SourcePoint2(60000, 0),
        SourcePoint2(0, 60000),
        SourcePoint2(-60000, 0),
        SourcePoint2(-120000, 0),
      ],
    );
  });

  test('negative-slope non-horizontal staggered overlap is exact', () {
    _expectPartialUnion(
      _poly([(0, 0), (-80000, 120000), (-140000, -20000)]),
      _poly([(-120000, 180000), (-40000, 60000), (60000, 140000)]),
      const [
        SourcePoint2(0, 0),
        SourcePoint2(-40000, 60000),
        SourcePoint2(60000, 140000),
        SourcePoint2(-120000, 180000),
        SourcePoint2(-80000, 120000),
        SourcePoint2(-140000, -20000),
      ],
    );
  });

  test('Arachne zero offset routes partial collinear triangles off fallback', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [
        _poly([(0, 0), (80000, 120000), (-20000, 100000)]),
        _poly([(40000, 60000), (0, 0), (80000, -10000)]),
      ],
      0,
    );

    expect(result, hasLength(1));
    expect(
      result.single.points,
      const [
        SourcePoint2(-20000, 100000),
        SourcePoint2(0, 0),
        SourcePoint2(80000, -10000),
        SourcePoint2(40000, 60000),
        SourcePoint2(80000, 120000),
      ],
    );
  });

  test('Arachne routes increasing-Y host-end join off fallback', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [
        _poly([(0, 0), (80000, 120000), (-20000, 100000)]),
        _poly([(80000, 120000), (40000, 60000), (120000, 50000)]),
      ],
      0,
    );

    expect(result, hasLength(1));
    expect(
      result.single.points,
      const [
        SourcePoint2(0, 0),
        SourcePoint2(40000, 60000),
        SourcePoint2(120000, 50000),
        SourcePoint2(80000, 120000),
        SourcePoint2(-20000, 100000),
      ],
    );
  });

  test('decreasing-Y host-end without guest start stays on seam', () {
    expect(
      SourceClipper1TwoConvexPartialCollinearUnion2.supports([
        _poly([(56000, 107000), (104000, 113000), (56000, 119000)]),
        _poly([(20000, 115000), (56000, 107000), (56000, 113000)]),
      ]),
      isFalse,
    );
  });

  test('other non-horizontal staggered overlap stays on compatibility seam', () {
    expect(
      SourceClipper1TwoConvexPartialCollinearUnion2.supports([
        _poly([(0, 0), (80000, 120000), (-20000, 100000)]),
        _poly([(120000, 180000), (40000, 60000), (140000, 80000)]),
      ]),
      isFalse,
    );
  });

  test('negative-slope staggered state requires pinned triangle start', () {
    expect(
      SourceClipper1TwoConvexPartialCollinearUnion2.supports([
        _poly([(-63000, -14000), (-75000, 70000), (-162000, 79000)]),
        _poly([(-79000, 98000), (-69000, 28000), (102000, 31000)]),
      ]),
      isFalse,
    );
  });

  test('proper crossing remains owned by the proper-convex helper', () {
    expect(
      SourceClipper1TwoConvexPartialCollinearUnion2.supports([
        _poly([(0, 0), (100000, 0), (50000, 100000)]),
        _poly([(25000, 25000), (125000, 25000), (75000, 125000)]),
      ]),
      isFalse,
    );
  });

  test('contact helper uses exact standalone triangle starts and scan order', () {
    final first =
        _poly([(0, 0), (-58035, 15231), (-68708, -13389)]);
    final second =
        _poly([(0, 0), (57679, -16527), (48850, 10660)]);

    for (final values in [
      [first, second],
      [second, first],
    ]) {
      final result = SourceClipper1TwoConvexContactUnion2.unionAll(values);
      expect(
        result.map((polygon) => polygon.points).toList(),
        const [
          [
            SourcePoint2(0, 0),
            SourcePoint2(-58035, 15231),
            SourcePoint2(-68708, -13389),
          ],
          [
            SourcePoint2(48850, 10660),
            SourcePoint2(0, 0),
            SourcePoint2(57679, -16527),
          ],
        ],
      );
    }
  });

  test('contact helper rejects wider convex shared-edge state', () {
    expect(
      SourceClipper1TwoConvexContactUnion2.supports([
        _poly([(0, 0), (100000, 0), (120000, 80000), (0, 100000)]),
        _poly([(100000, 0), (0, 0), (0, -100000), (120000, -80000)]),
      ]),
      isFalse,
    );
  });

  test('strict-contained decreasing-Y join stays on compatibility seam', () {
    expect(
      SourceClipper1TwoConvexContactUnion2.supports([
        _poly([(0, 0), (80000, -120000), (100000, -20000)]),
        _poly([(20000, -30000), (-40000, -50000), (60000, -90000)]),
      ]),
      isFalse,
    );
  });
}
