import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/expolygon.dart';
import 'package:qidi_flow_flutter/core/geometry/point.dart';
import 'package:qidi_flow_flutter/core/geometry/polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_perimeter.dart';

Polygon2 square(double size) => Polygon2([
      const Point2(0, 0),
      Point2(size, 0),
      Point2(size, size),
      Point2(0, size),
    ]);

void main() {
  const generator = ClassicPerimeterShellGenerator();

  test('ports classic perimeter onion-shell inset distances for equal flows', () {
    final result = generator.generate(
      [ExPolygon2(contour: square(20))],
      const ClassicPerimeterSettings(
        wallLoops: 2,
        externalPerimeterWidth: 0.4,
        externalPerimeterSpacing: 0.4,
        perimeterWidth: 0.4,
        perimeterSpacing: 0.4,
      ),
      layerIndex: 0,
    );

    expect(result.effectiveLoopCount, 2);
    expect(result.loops, hasLength(2));

    final outerBounds = result.loops[0].expolygon.contour.bounds;
    expect(outerBounds.min.x, closeTo(0.2, 2e-5));
    expect(outerBounds.min.y, closeTo(0.2, 2e-5));
    expect(outerBounds.max.x, closeTo(19.8, 2e-5));
    expect(outerBounds.max.y, closeTo(19.8, 2e-5));

    final innerBounds = result.loops[1].expolygon.contour.bounds;
    expect(innerBounds.min.x, closeTo(0.6, 3e-5));
    expect(innerBounds.min.y, closeTo(0.6, 3e-5));
    expect(innerBounds.max.x, closeTo(19.4, 3e-5));
    expect(innerBounds.max.y, closeTo(19.4, 3e-5));
  });

  test('alternate extra wall increments requested loops on odd layers', () {
    const settings = ClassicPerimeterSettings(
      wallLoops: 2,
      externalPerimeterWidth: 0.4,
      externalPerimeterSpacing: 0.4,
      perimeterWidth: 0.4,
      perimeterSpacing: 0.4,
      alternateExtraWall: true,
    );

    final even = generator.generate(
      [ExPolygon2(contour: square(20))],
      settings,
      layerIndex: 0,
    );
    final odd = generator.generate(
      [ExPolygon2(contour: square(20))],
      settings,
      layerIndex: 1,
    );

    expect(even.effectiveLoopCount, 2);
    expect(odd.effectiveLoopCount, 3);
  });

  test('detect thin wall branch stays explicit until medial axis is ported', () {
    expect(
      () => generator.generate(
        [ExPolygon2(contour: square(20))],
        const ClassicPerimeterSettings(
          wallLoops: 2,
          externalPerimeterWidth: 0.4,
          externalPerimeterSpacing: 0.4,
          perimeterWidth: 0.4,
          perimeterSpacing: 0.4,
          detectThinWall: true,
        ),
        layerIndex: 0,
      ),
      throwsUnsupportedError,
    );
  });
}
