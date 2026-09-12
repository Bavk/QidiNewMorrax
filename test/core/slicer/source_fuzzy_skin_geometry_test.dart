import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polyline.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_geometry.dart';

class SequenceRandom implements SourceFuzzyUnitRandom2 {
  SequenceRandom(this.values);

  final List<double> values;
  int _index = 0;

  @override
  double nextUnit() {
    if (_index >= values.length) {
      throw StateError('test random sequence exhausted at $_index');
    }
    return values[_index++];
  }
}

List<double> zeroDisplacementSequence(int samples) => [
      0,
      for (var i = 0; i < samples; i++) ...[0.5, 0],
    ];

void main() {
  test('NoiseType enum preserves pinned source order', () {
    expect(SourceFuzzyNoiseType2.values, const [
      SourceFuzzyNoiseType2.classic,
      SourceFuzzyNoiseType2.perlin,
      SourceFuzzyNoiseType2.billow,
      SourceFuzzyNoiseType2.ridgedMulti,
      SourceFuzzyNoiseType2.voronoi,
    ]);
  });

  test('mt19937 engine matches standard seed oracle', () {
    final random = SourceFuzzyMt19937Random2.seeded(5489);
    expect(
      List<int>.generate(4, (_) => random.nextUint32()),
      const [3499211612, 581869302, 3890346734, 3586334585],
    );
  });

  test('uniform double sequence matches libstdc++ mt19937 oracle', () {
    final random = SourceFuzzyMt19937Random2.seeded(5489);
    const expected = [
      0.1354770042967805,
      0.8350085899945795,
      0.9688677711242314,
      0.2210340429827049,
      0.30816705050700327,
      0.5472205963678519,
    ];
    for (final value in expected) {
      expect(random.nextUnit(), closeTo(value, 1e-15));
    }
  });

  test('Classic open sampling carries exact 0.75 distance and zero noise', () {
    final result = SourceFuzzySkinGeometry2.fuzzyClassicPolyline(
      polyline: SourcePolyline2(const [
        SourcePoint2(0, 0),
        SourcePoint2(100000, 0),
      ]),
      thicknessMm: 0.1,
      pointDistanceMm: 0.4,
      random: SequenceRandom(zeroDisplacementSequence(4)),
    );

    expect(result.points, const [
      SourcePoint2(0, 0),
      SourcePoint2(30000, 0),
      SourcePoint2(60000, 0),
      SourcePoint2(90000, 0),
    ]);
  });

  test('distance_left_over continues sampling across source segments', () {
    final result = SourceFuzzySkinGeometry2.fuzzyClassicPolyline(
      polyline: SourcePolyline2(const [
        SourcePoint2(0, 0),
        SourcePoint2(50000, 0),
        SourcePoint2(100000, 0),
      ]),
      thicknessMm: 0.1,
      pointDistanceMm: 0.4,
      random: SequenceRandom(zeroDisplacementSequence(4)),
    );

    expect(result.points, const [
      SourcePoint2(0, 0),
      SourcePoint2(30000, 0),
      SourcePoint2(60000, 0),
      SourcePoint2(90000, 0),
    ]);
  });

  test('Classic displacement shares random_value stream with spacing', () {
    final result = SourceFuzzySkinGeometry2.fuzzyClassicPolyline(
      polyline: SourcePolyline2(const [
        SourcePoint2(0, 0),
        SourcePoint2(100000, 0),
      ]),
      thicknessMm: 0.1,
      pointDistanceMm: 0.4,
      random: SequenceRandom([
        0,
        0.75, 0,
        0.75, 0,
        0.75, 0,
        0.75, 0,
      ]),
    );

    expect(result.points, const [
      SourcePoint2(0, 5000),
      SourcePoint2(30000, 5000),
      SourcePoint2(60000, 5000),
      SourcePoint2(90000, 5000),
    ]);
  });

  test('source cast truncates diagonal normal displacement toward zero', () {
    final result = SourceFuzzySkinGeometry2.fuzzyClassicPolyline(
      polyline: SourcePolyline2(const [
        SourcePoint2(0, 0),
        SourcePoint2(100000, 100000),
      ]),
      thicknessMm: 0.1,
      pointDistanceMm: 0.4,
      random: SequenceRandom([
        0,
        0.75, 0,
        0.75, 0,
        0.75, 0,
        0.75, 0,
        0.75, 0,
      ]),
    );

    expect(result.points.first, const SourcePoint2(-3535, 3535));
  });

  test('pinned fallback repeatedly appends the penultimate point', () {
    final result = SourceFuzzySkinGeometry2.fuzzyClassicPolyline(
      polyline: SourcePolyline2(const [
        SourcePoint2(0, 0),
        SourcePoint2(10, 0),
        SourcePoint2(20, 0),
      ]),
      thicknessMm: 0.1,
      pointDistanceMm: 100,
      random: SequenceRandom([0.9]),
    );

    expect(result.points, const [
      SourcePoint2(10, 0),
      SourcePoint2(10, 0),
      SourcePoint2(10, 0),
    ]);
  });

  test('pinned fuzzy_polygon preserves fallback duplicates literally', () {
    final result = SourceFuzzySkinGeometry2.fuzzyClassicPolygon(
      polygon: SourcePolygon2(const [
        SourcePoint2(0, 0),
        SourcePoint2(10, 0),
        SourcePoint2(10, 10),
        SourcePoint2(0, 10),
      ]),
      thicknessMm: 0.1,
      pointDistanceMm: 100,
      random: SequenceRandom([0.9]),
    );

    expect(result.points, const [
      SourcePoint2(10, 10),
      SourcePoint2(10, 10),
      SourcePoint2(10, 10),
    ]);
  });

  test('invalid random stream values are rejected explicitly', () {
    expect(
      () => SourceFuzzySkinGeometry2.fuzzyClassicPolyline(
        polyline: SourcePolyline2(const [
          SourcePoint2(0, 0),
          SourcePoint2(100000, 0),
        ]),
        thicknessMm: 0.1,
        pointDistanceMm: 0.4,
        random: SequenceRandom([1]),
      ),
      throwsStateError,
    );
  });
}
