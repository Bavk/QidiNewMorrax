import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter_loop_tree.dart';

SourcePolygon2 box(int min, int max) => SourcePolygon2([
      SourcePoint2(min, min),
      SourcePoint2(max, min),
      SourcePoint2(max, max),
      SourcePoint2(min, max),
    ]);

void main() {
  test('is_internal_contour ignores holes but rejects contour children', () {
    final root = SourcePerimeterLoop2(
      polygon: box(0, 1000),
      depth: 0,
      isContour: true,
    );
    final hole = SourcePerimeterLoop2(
      polygon: box(200, 800).reversed(),
      depth: 0,
      isContour: false,
    );
    root.children.add(hole);
    expect(root.isInternalContour, true);
    expect(hole.isInternalContour, false);

    root.children.add(SourcePerimeterLoop2(
      polygon: box(300, 700),
      depth: 1,
      isContour: true,
    ));
    expect(root.isInternalContour, false);
  });

  test('holes prefer containing deeper holes before contours', () {
    final outer = SourcePerimeterLoop2(
      polygon: box(0, 1000),
      depth: 0,
      isContour: true,
    );
    final shallowHole = SourcePerimeterLoop2(
      polygon: box(300, 700).reversed(),
      depth: 0,
      isContour: false,
    );
    final deepHole = SourcePerimeterLoop2(
      polygon: box(200, 800).reversed(),
      depth: 1,
      isContour: false,
    );

    final roots = SourceClassicPerimeterLoopNester2.nest(
      contoursByDepth: [
        [outer],
        <SourcePerimeterLoop2>[],
      ],
      holesByDepth: [
        [shallowHole],
        [deepHole],
      ],
      loopNumber: 1,
    );

    expect(roots, [outer]);
    expect(outer.children, [deepHole]);
    expect(deepHole.children, [shallowHole]);
  });

  test('deeper contours attach to nearest containing shallower contour', () {
    final depth0 = SourcePerimeterLoop2(
      polygon: box(0, 1000),
      depth: 0,
      isContour: true,
    );
    final depth1 = SourcePerimeterLoop2(
      polygon: box(100, 900),
      depth: 1,
      isContour: true,
    );
    final depth2 = SourcePerimeterLoop2(
      polygon: box(200, 800),
      depth: 2,
      isContour: true,
    );

    final roots = SourceClassicPerimeterLoopNester2.nest(
      contoursByDepth: [
        [depth0],
        [depth1],
        [depth2],
      ],
      holesByDepth: [
        <SourcePerimeterLoop2>[],
        <SourcePerimeterLoop2>[],
        <SourcePerimeterLoop2>[],
      ],
      loopNumber: 2,
    );

    expect(roots, [depth0]);
    expect(depth0.children, [depth1]);
    expect(depth1.children, [depth2]);
  });

  test('unparented deeper contour is not promoted to source root set', () {
    final root = SourcePerimeterLoop2(
      polygon: box(0, 100),
      depth: 0,
      isContour: true,
    );
    final unrelated = SourcePerimeterLoop2(
      polygon: box(200, 300),
      depth: 1,
      isContour: true,
    );

    final roots = SourceClassicPerimeterLoopNester2.nest(
      contoursByDepth: [
        [root],
        [unrelated],
      ],
      holesByDepth: [
        <SourcePerimeterLoop2>[],
        <SourcePerimeterLoop2>[],
      ],
      loopNumber: 1,
    );

    expect(roots, [root]);
    expect(root.children, isEmpty);
  });
}
