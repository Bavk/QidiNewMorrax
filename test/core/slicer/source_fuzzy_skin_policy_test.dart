import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_policy.dart';

SourcePolygon2 box() => SourcePolygon2(const [
      SourcePoint2(0, 0),
      SourcePoint2(100000, 0),
      SourcePoint2(100000, 100000),
      SourcePoint2(0, 100000),
    ]);

bool should({
  required SourceFuzzySkinType2 type,
  int layer = 1,
  int perimeter = 0,
  bool contour = true,
  bool firstLayer = true,
}) =>
    SourceFuzzySkinPolicy2.shouldFuzzify(
      type: type,
      layerIndex: layer,
      perimeterIndex: perimeter,
      isContour: contour,
      fuzzySkinFirstLayer: firstLayer,
    );

void main() {
  test('FuzzySkinType enum preserves pinned source order', () {
    expect(SourceFuzzySkinType2.values, const [
      SourceFuzzySkinType2.none,
      SourceFuzzySkinType2.external,
      SourceFuzzySkinType2.all,
      SourceFuzzySkinType2.allWalls,
      SourceFuzzySkinType2.disabledFuzzy,
    ]);
  });

  test('None and Disabled_fuzzy never fuzzify geometry', () {
    for (final type in [
      SourceFuzzySkinType2.none,
      SourceFuzzySkinType2.disabledFuzzy,
    ]) {
      expect(should(type: type), false);
      expect(should(type: type, perimeter: 3), false);
      expect(should(type: type, contour: false), false);
    }
  });

  test('first-layer switch suppresses every actual fuzzy mode', () {
    for (final type in [
      SourceFuzzySkinType2.external,
      SourceFuzzySkinType2.all,
      SourceFuzzySkinType2.allWalls,
    ]) {
      expect(
        should(type: type, layer: 0, firstLayer: false),
        false,
      );
    }
  });

  test('External fuzzifies only depth-zero contour', () {
    expect(should(type: SourceFuzzySkinType2.external), true);
    expect(
      should(type: SourceFuzzySkinType2.external, perimeter: 1),
      false,
    );
    expect(
      should(type: SourceFuzzySkinType2.external, contour: false),
      false,
    );
  });

  test('All fuzzifies contour and hole only at depth zero', () {
    expect(should(type: SourceFuzzySkinType2.all), true);
    expect(
      should(type: SourceFuzzySkinType2.all, contour: false),
      true,
    );
    expect(
      should(type: SourceFuzzySkinType2.all, perimeter: 1),
      false,
    );
    expect(
      should(
        type: SourceFuzzySkinType2.all,
        perimeter: 1,
        contour: false,
      ),
      false,
    );
  });

  test('AllWalls fuzzifies contours and holes at every depth', () {
    expect(should(type: SourceFuzzySkinType2.allWalls), true);
    expect(
      should(type: SourceFuzzySkinType2.allWalls, perimeter: 4),
      true,
    );
    expect(
      should(
        type: SourceFuzzySkinType2.allWalls,
        perimeter: 4,
        contour: false,
      ),
      true,
    );
  });

  test('None vs Disabled_fuzzy slowdown quirk is preserved', () {
    expect(
      SourceFuzzySkinPolicy2.allowsOverhangSlowdown(
        type: SourceFuzzySkinType2.disabledFuzzy,
        perimeterRegionsEmpty: false,
      ),
      true,
    );
    expect(
      SourceFuzzySkinPolicy2.allowsOverhangSlowdown(
        type: SourceFuzzySkinType2.none,
        perimeterRegionsEmpty: true,
      ),
      true,
    );
    expect(
      SourceFuzzySkinPolicy2.allowsOverhangSlowdown(
        type: SourceFuzzySkinType2.none,
        perimeterRegionsEmpty: false,
      ),
      false,
    );
    for (final type in [
      SourceFuzzySkinType2.external,
      SourceFuzzySkinType2.all,
      SourceFuzzySkinType2.allWalls,
    ]) {
      expect(
        SourceFuzzySkinPolicy2.allowsOverhangSlowdown(
          type: type,
          perimeterRegionsEmpty: true,
        ),
        false,
      );
    }
  });

  test('identity branch returns unchanged immutable polygon', () {
    final polygon = box();
    final result = SourceFuzzySkinPolicy2.identityPolygon(
      polygon: polygon,
      type: SourceFuzzySkinType2.none,
      layerIndex: 3,
      perimeterIndex: 0,
      isContour: true,
      fuzzySkinFirstLayer: true,
    );

    expect(identical(result, polygon), true);
    expect(result.points, polygon.points);
  });

  test('identity branch refuses to fake a required fuzzy transform', () {
    expect(
      () => SourceFuzzySkinPolicy2.identityPolygon(
        polygon: box(),
        type: SourceFuzzySkinType2.external,
        layerIndex: 1,
        perimeterIndex: 0,
        isContour: true,
        fuzzySkinFirstLayer: true,
      ),
      throwsUnsupportedError,
    );
  });
}
