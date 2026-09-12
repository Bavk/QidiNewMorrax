import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_apply_exact.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_geometry_exact.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_policy.dart';

class SpacingSequence implements SourceFuzzySpacingRandom2 {
  SpacingSequence(this.values);
  final List<double> values;
  int index = 0;
  @override
  double nextUnit() {
    if (index >= values.length) throw StateError('spacing sequence exhausted');
    return values[index++];
  }
}

class DisplacementSequence implements SourceFuzzyClassicDisplacementRandom2 {
  DisplacementSequence(this.values);
  final List<double> values;
  int index = 0;
  @override
  double nextSignedUnit() {
    if (index >= values.length) {
      throw StateError('displacement sequence exhausted');
    }
    return values[index++];
  }
}

SourcePolygon2 box() => SourcePolygon2(const [
      SourcePoint2(0, 0),
      SourcePoint2(100000, 0),
      SourcePoint2(100000, 100000),
      SourcePoint2(0, 100000),
    ]);

SourceFuzzySkinNoRegionExactConfig2 config({
  SourceFuzzySkinType2 type = SourceFuzzySkinType2.external,
  bool firstLayer = true,
  SourceFuzzyNoiseTypeExact2 noise = SourceFuzzyNoiseTypeExact2.classic,
}) =>
    SourceFuzzySkinNoRegionExactConfig2(
      type: type,
      fuzzySkinFirstLayer: firstLayer,
      thicknessMm: 0.1,
      pointDistanceMm: 0.4,
      noiseType: noise,
    );

void main() {
  test('identity policy consumes neither source rng', () {
    final polygon = box();
    final spacing = SpacingSequence(const []);
    final displacement = DisplacementSequence(const []);
    final result = SourceFuzzySkinNoRegionExactApply2.applyPolygon(
      polygon: polygon,
      config: config(type: SourceFuzzySkinType2.none),
      layerIndex: 2,
      perimeterIndex: 0,
      isContour: true,
      spacingRandom: spacing,
      displacementRandom: displacement,
    );

    expect(identical(result, polygon), true);
    expect(spacing.index, 0);
    expect(displacement.index, 0);
  });

  test('Classic geometry consumes spacing and displacement independently', () {
    final spacing = SpacingSequence(List<double>.filled(32, 0));
    final displacement = DisplacementSequence(List<double>.filled(32, 0.5));
    final result = SourceFuzzySkinNoRegionExactApply2.applyPolygon(
      polygon: box(),
      config: config(),
      layerIndex: 1,
      perimeterIndex: 0,
      isContour: true,
      spacingRandom: spacing,
      displacementRandom: displacement,
    );

    expect(result.points.length, greaterThan(4));
    expect(spacing.index, displacement.index + 1);
    expect(result.points.any((point) => point.x < 0 || point.y < 0), true);
  });

  test('External hole remains identity even when noise implementation is absent', () {
    final polygon = box();
    final result = SourceFuzzySkinNoRegionExactApply2.applyPolygon(
      polygon: polygon,
      config: config(noise: SourceFuzzyNoiseTypeExact2.perlin),
      layerIndex: 1,
      perimeterIndex: 0,
      isContour: false,
      spacingRandom: SpacingSequence(const []),
      displacementRandom: DisplacementSequence(const []),
    );

    expect(identical(result, polygon), true);
  });

  test('required non-Classic geometry remains explicit unsupported', () {
    expect(
      () => SourceFuzzySkinNoRegionExactApply2.applyPolygon(
        polygon: box(),
        config: config(noise: SourceFuzzyNoiseTypeExact2.perlin),
        layerIndex: 1,
        perimeterIndex: 0,
        isContour: true,
        spacingRandom: SpacingSequence(const []),
        displacementRandom: DisplacementSequence(const []),
      ),
      throwsUnsupportedError,
    );
  });
}
