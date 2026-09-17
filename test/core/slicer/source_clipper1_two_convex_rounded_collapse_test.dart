import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths_prepare_exact.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_two_convex_mixed_point_union.dart';

SourcePolygon2 _poly(List<(int, int)> points) => SourcePolygon2([
      for (final point in points) SourcePoint2(point.$1, point.$2),
    ]);

SourcePolygon2 _rotated(SourcePolygon2 polygon, int start) => SourcePolygon2([
      for (var index = 0; index < polygon.points.length; index++)
        polygon.points[(start + index) % polygon.points.length],
    ]);

void _expectExactAllRotations(
  SourcePolygon2 first,
  SourcePolygon2 second,
  List<SourcePoint2> expected,
) {
  for (var firstRotation = 0; firstRotation < 3; firstRotation++) {
    for (var secondRotation = 0; secondRotation < 3; secondRotation++) {
      final a = _rotated(first, firstRotation);
      final b = _rotated(second, secondRotation);
      for (final values in [[a, b], [b, a]]) {
        expect(SourceClipper1TwoConvexMixedPointUnion2.supports(values), isTrue);
        expect(
          SourceClipper1TwoConvexMixedPointUnion2.union(values).points,
          expected,
        );
      }
    }
  }
}

void main() {
  test('rounded strict-max AEL-contained collapse is exact', () {
    _expectExactAllRotations(
      _poly([(0, 0), (-129, -164), (149, -16)]),
      _poly([(-21, 56), (21, -56), (28, -74)]),
      const [
        SourcePoint2(149, -16),
        SourcePoint2(0, 0),
        SourcePoint2(-129, -164),
      ],
    );
  });

  test('translated scaled rounded AEL collapse is exact', () {
    _expectExactAllRotations(
      _poly([
        (376000000, 761000000),
        (375996396, 760996566),
        (376000527, 760997280),
      ]),
      _poly([
        (375999133, 760998300),
        (375999983, 760999966),
        (376001734, 761003400),
      ]),
      const [
        SourcePoint2(376000527, 760997280),
        SourcePoint2(376000000, 761000000),
        SourcePoint2(375996396, 760996566),
      ],
    );
  });

  test('Arachne zero offset routes rounded AEL collapse exactly', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [
        _poly([(0, 0), (-129, -164), (149, -16)]),
        _poly([(-21, 56), (21, -56), (28, -74)]),
      ],
      0,
    );
    expect(result, hasLength(1));
    expect(result.single.points, const [
      SourcePoint2(149, -16),
      SourcePoint2(0, 0),
      SourcePoint2(-129, -164),
    ]);
  });

  test('rounded strict-max retained inner vertex stays fallback', () {
    final values = [
      _poly([(0, 0), (162, -141), (164, -8)]),
      _poly([(-20, 17), (20, -17), (70, -58)]),
    ];
    expect(SourceClipper1TwoConvexMixedPointUnion2.supports(values), isFalse);
  });

  test('rounded strict-max retained wedge is exact', () {
    _expectExactAllRotations(
      _poly([(0, 0), (-142, -178), (27, -173)]),
      _poly([(-125, -167), (125, 167), (-6, -8)]),
      const [
        SourcePoint2(27, -173),
        SourcePoint2(0, 0),
        SourcePoint2(125, 167),
        SourcePoint2(-6, -8),
        SourcePoint2(-142, -178),
      ],
    );
  });

  test('rounded retained wedge rebases from the source minimum anchor', () {
    _expectExactAllRotations(
      _poly([(0, 0), (-170, -122), (183, -155)]),
      _poly([(142, 107), (-4, -3), (-142, -107)]),
      const [
        SourcePoint2(0, 0),
        SourcePoint2(142, 107),
        SourcePoint2(-4, -3),
        SourcePoint2(-170, -122),
        SourcePoint2(183, -155),
      ],
    );
  });

  test('Arachne zero offset routes rounded retained wedge exactly', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [
        _poly([(0, 0), (-142, -178), (27, -173)]),
        _poly([(-125, -167), (125, 167), (-6, -8)]),
      ],
      0,
    );
    expect(result, hasLength(1));
    expect(result.single.points, const [
      SourcePoint2(27, -173),
      SourcePoint2(0, 0),
      SourcePoint2(125, 167),
      SourcePoint2(-6, -8),
      SourcePoint2(-142, -178),
    ]);
  });
}
