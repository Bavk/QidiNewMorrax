import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths_prepare_exact.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_two_convex_contact_union.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_two_convex_full_shared_edge_fixup_union.dart';
import 'package:qidi_flow_flutter/core/slicer/source_clipper1_two_convex_host_end_fixup_union.dart';

SourcePolygon2 _poly(List<(int, int)> points) => SourcePolygon2([
      for (final point in points) SourcePoint2(point.$1, point.$2),
    ]);

SourcePolygon2 _rotated(SourcePolygon2 polygon, int start) => SourcePolygon2([
      for (var index = 0; index < polygon.points.length; index++)
        polygon.points[(start + index) % polygon.points.length],
    ]);

void _expectExact(
  SourcePolygon2 first,
  SourcePolygon2 second,
  List<SourcePoint2> expected,
) {
  for (var firstRotation = 0; firstRotation < 3; firstRotation++) {
    for (var secondRotation = 0; secondRotation < 3; secondRotation++) {
      final rotatedFirst = _rotated(first, firstRotation);
      final rotatedSecond = _rotated(second, secondRotation);
      for (final values in [
        [rotatedFirst, rotatedSecond],
        [rotatedSecond, rotatedFirst],
      ]) {
        expect(
          SourceClipper1TwoConvexFullSharedEdgeFixupUnion2.supports(values),
          isTrue,
        );
        expect(
          SourceClipper1TwoConvexFullSharedEdgeFixupUnion2.union(values).points,
          expected,
        );
      }
    }
  }
}

void _expectExactByInputOrder(
  SourcePolygon2 first,
  SourcePolygon2 second,
  List<SourcePoint2> expectedForward,
  List<SourcePoint2> expectedReverse,
) {
  for (var firstRotation = 0; firstRotation < 3; firstRotation++) {
    for (var secondRotation = 0; secondRotation < 3; secondRotation++) {
      final rotatedFirst = _rotated(first, firstRotation);
      final rotatedSecond = _rotated(second, secondRotation);
      final forward = [rotatedFirst, rotatedSecond];
      final reverse = [rotatedSecond, rotatedFirst];

      expect(
        SourceClipper1TwoConvexFullSharedEdgeFixupUnion2.supports(forward),
        isTrue,
      );
      expect(
        SourceClipper1TwoConvexFullSharedEdgeFixupUnion2.union(forward).points,
        expectedForward,
      );
      expect(
        SourceClipper1TwoConvexFullSharedEdgeFixupUnion2.supports(reverse),
        isTrue,
      );
      expect(
        SourceClipper1TwoConvexFullSharedEdgeFixupUnion2.union(reverse).points,
        expectedReverse,
      );
    }
  }
}

void main() {
  test('vertical full edge removes non-start shared endpoint exactly', () {
    _expectExact(
      _poly([
        (0, 100),
        (0, 0),
        (40, 50),
      ]),
      _poly([
        (0, 0),
        (0, 100),
        (-40, 150),
      ]),
      const [
        SourcePoint2(0, 0),
        SourcePoint2(40, 50),
        SourcePoint2(-40, 150),
      ],
    );
  });

  test('sheared full edge preserves ordinary full-edge raw start', () {
    _expectExact(
      _poly([
        (100, 100),
        (0, 0),
        (90, 50),
      ]),
      _poly([
        (0, 0),
        (100, 100),
        (110, 150),
      ]),
      const [
        SourcePoint2(0, 0),
        SourcePoint2(90, 50),
        SourcePoint2(110, 150),
      ],
    );
  });

  test('horizontal tie keeps greater-X full-edge start after cleanup', () {
    _expectExact(
      _poly([
        (0, 0),
        (100, 0),
        (40, 40),
      ]),
      _poly([
        (100, 0),
        (0, 0),
        (-40, -40),
      ]),
      const [
        SourcePoint2(100, 0),
        SourcePoint2(40, 40),
        SourcePoint2(-40, -40),
      ],
    );
  });

  test('existing fixup gateway delegates full-edge exact subset', () {
    final values = [
      _poly([
        (0, 100),
        (0, 0),
        (40, 50),
      ]),
      _poly([
        (0, 0),
        (0, 100),
        (-40, 150),
      ]),
    ];

    expect(SourceClipper1TwoConvexHostEndFixupUnion2.supports(values), isTrue);
    expect(
      SourceClipper1TwoConvexHostEndFixupUnion2.union(values).points,
      const [
        SourcePoint2(0, 0),
        SourcePoint2(40, 50),
        SourcePoint2(-40, 150),
      ],
    );
  });

  test('Arachne zero offset routes full-edge cleanup off fallback', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [
        _poly([
          (0, 100),
          (0, 0),
          (40, 50),
        ]),
        _poly([
          (0, 0),
          (0, 100),
          (-40, 150),
        ]),
      ],
      0,
    );

    expect(result, hasLength(1));
    expect(
      result.single.points,
      const [
        SourcePoint2(0, 0),
        SourcePoint2(40, 50),
        SourcePoint2(-40, 150),
      ],
    );
  });

  test('removed ordinary start preserves pinned AddPath pointer state', () {
    _expectExactByInputOrder(
      _poly([
        (0, 100),
        (0, 0),
        (40, 50),
      ]),
      _poly([
        (0, 0),
        (0, 100),
        (-40, -50),
      ]),
      const [
        SourcePoint2(40, 50),
        SourcePoint2(0, 100),
        SourcePoint2(-40, -50),
      ],
      const [
        SourcePoint2(0, 100),
        SourcePoint2(-40, -50),
        SourcePoint2(40, 50),
      ],
    );
  });

  test('removed-start equal-Y boundary keeps source pointer asymmetry', () {
    _expectExactByInputOrder(
      _poly([
        (-400, -400),
        (0, 0),
        (-840, -800),
      ]),
      _poly([
        (0, 0),
        (-400, -400),
        (40, 0),
      ]),
      const [
        SourcePoint2(0, 0),
        SourcePoint2(-840, -800),
        SourcePoint2(40, 0),
      ],
      const [
        SourcePoint2(40, 0),
        SourcePoint2(0, 0),
        SourcePoint2(-840, -800),
      ],
    );
  });

  test('ordinary non-fixup full edge stays owned by contact helper', () {
    final values = [
      _poly([
        (0, 100),
        (0, 0),
        (40, 50),
      ]),
      _poly([
        (0, 0),
        (0, 100),
        (-40, 50),
      ]),
    ];

    expect(
      SourceClipper1TwoConvexFullSharedEdgeFixupUnion2.supports(values),
      isFalse,
    );
    expect(SourceClipper1TwoConvexContactUnion2.supports(values), isTrue);
  });
}
