import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polyline.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_geometry_exact.dart';

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

void main() {
  test('pinned noise enum preserves Classic/Perlin/Billow/Ridged/Voronoi order', () {
    expect(SourceFuzzyNoiseTypeExact2.values, const [
      SourceFuzzyNoiseTypeExact2.classic,
      SourceFuzzyNoiseTypeExact2.perlin,
      SourceFuzzyNoiseTypeExact2.billow,
      SourceFuzzyNoiseTypeExact2.ridgedMulti,
      SourceFuzzyNoiseTypeExact2.voronoi,
    ]);
  });

  test('spacing and Classic displacement consume independent streams', () {
    final spacing = SpacingSequence(const [0, 0, 0, 0, 0]);
    final displacement = DisplacementSequence(const [0.5, 0.5, 0.5, 0.5]);

    final result = SourceFuzzySkinGeometryExact2.fuzzyClassicPolyline(
      polyline: SourcePolyline2(const [
        SourcePoint2(0, 0),
        SourcePoint2(100000, 0),
      ]),
      thicknessMm: 0.1,
      pointDistanceMm: 0.4,
      spacingRandom: spacing,
      displacementRandom: displacement,
    );

    expect(result.points, const [
      SourcePoint2(0, 5000),
      SourcePoint2(30000, 5000),
      SourcePoint2(60000, 5000),
      SourcePoint2(90000, 5000),
    ]);
    expect(spacing.index, 5);
    expect(displacement.index, 4);
  });

  test('new fuzzy call restarts routing but preserves both underlying rng states', () {
    final spacing = SpacingSequence(const [0, 0, 0, 0, 0, 0]);
    final displacement = DisplacementSequence(const [0, 0, 0, 0]);

    final first = SourceFuzzySkinGeometryExact2.fuzzyClassicPolyline(
      polyline: SourcePolyline2(const [
        SourcePoint2(0, 0),
        SourcePoint2(50000, 0),
      ]),
      thicknessMm: 0.1,
      pointDistanceMm: 0.4,
      spacingRandom: spacing,
      displacementRandom: displacement,
    );
    final firstSpacing = spacing.index;
    final firstDisplacement = displacement.index;

    final second = SourceFuzzySkinGeometryExact2.fuzzyClassicPolyline(
      polyline: SourcePolyline2(const [
        SourcePoint2(0, 0),
        SourcePoint2(50000, 0),
      ]),
      thicknessMm: 0.1,
      pointDistanceMm: 0.4,
      spacingRandom: spacing,
      displacementRandom: displacement,
    );

    expect(first.points, const [
      SourcePoint2(0, 0),
      SourcePoint2(30000, 0),
      SourcePoint2(0, 0),
    ]);
    expect(second.points, const [
      SourcePoint2(10000, 0),
      SourcePoint2(40000, 0),
      SourcePoint2(0, 0),
    ]);
    expect(firstSpacing, 3);
    expect(firstDisplacement, 2);
    expect(spacing.index, 6);
    expect(displacement.index, 4);
  });

  test('Classic displacement is rounded to source float before thickness', () {
    final spacing = SpacingSequence(const [0, 0]);
    final displacement = DisplacementSequence(const [0.123456789]);
    final result = SourceFuzzySkinGeometryExact2.fuzzyClassicPolyline(
      polyline: SourcePolyline2(const [
        SourcePoint2(0, 0),
        SourcePoint2(10000, 0),
      ]),
      thicknessMm: 1,
      pointDistanceMm: 1,
      spacingRandom: spacing,
      displacementRandom: displacement,
    );

    expect(result.points.first.y, 12345);
  });

  test('sample and displacement casts truncate toward zero', () {
    final result = SourceFuzzySkinGeometryExact2.fuzzyClassicPolyline(
      polyline: SourcePolyline2(const [
        SourcePoint2(0, 0),
        SourcePoint2(100000, 100000),
      ]),
      thicknessMm: 0.1,
      pointDistanceMm: 0.4,
      spacingRandom: SpacingSequence(const [0, 0, 0, 0, 0, 0]),
      displacementRandom:
          DisplacementSequence(const [0.5, 0.5, 0.5, 0.5, 0.5]),
    );

    expect(result.points.first, const SourcePoint2(-3535, 3535));
  });

  test('pinned fallback repeats the penultimate point', () {
    final result = SourceFuzzySkinGeometryExact2.fuzzyClassicPolyline(
      polyline: SourcePolyline2(const [
        SourcePoint2(0, 0),
        SourcePoint2(10, 0),
        SourcePoint2(20, 0),
      ]),
      thicknessMm: 0.1,
      pointDistanceMm: 100,
      spacingRandom: SpacingSequence(const [0.9]),
      displacementRandom: DisplacementSequence(const []),
    );

    expect(result.points, const [
      SourcePoint2(10, 0),
      SourcePoint2(10, 0),
      SourcePoint2(10, 0),
    ]);
  });

  test('polygon wrapper removes same-neighbor and closing duplicates', () {
    final polygon = SourcePolygon2(const [
      SourcePoint2(0, 0),
      SourcePoint2(100000, 0),
      SourcePoint2(100000, 100000),
      SourcePoint2(0, 100000),
    ]);
    final spacing = SpacingSequence(List<double>.filled(32, 0));
    final displacement = DisplacementSequence(List<double>.filled(32, 0));
    final result = SourceFuzzySkinGeometryExact2.fuzzyClassicPolygon(
      polygon: polygon,
      thicknessMm: 0,
      pointDistanceMm: 0.5,
      spacingRandom: spacing,
      displacementRandom: displacement,
    );

    expect(result.points.length, greaterThanOrEqualTo(3));
    for (var i = 1; i < result.points.length; i++) {
      expect(result.points[i], isNot(result.points[i - 1]));
    }
    expect(result.points.last, isNot(result.points.first));
  });

  test('invalid values are checked independently per source stream', () {
    expect(
      () => SourceFuzzySkinGeometryExact2.fuzzyClassicPolyline(
        polyline: SourcePolyline2(const [
          SourcePoint2(0, 0),
          SourcePoint2(100000, 0),
        ]),
        thicknessMm: 0.1,
        pointDistanceMm: 0.4,
        spacingRandom: SpacingSequence(const [1]),
        displacementRandom: DisplacementSequence(const [0]),
      ),
      throwsStateError,
    );
    expect(
      () => SourceFuzzySkinGeometryExact2.fuzzyClassicPolyline(
        polyline: SourcePolyline2(const [
          SourcePoint2(0, 0),
          SourcePoint2(100000, 0),
        ]),
        thicknessMm: 0.1,
        pointDistanceMm: 0.4,
        spacingRandom: SpacingSequence(const [0]),
        displacementRandom: DisplacementSequence(const [1]),
      ),
      throwsStateError,
    );
  });
}
