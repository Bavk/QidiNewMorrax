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

  test('Classic noise displaces perpendicular to horizontal segment', () {
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

  test('polygon wrapper removes consecutive and closing duplicates', () {
    final result = SourceFuzzySkinGeometry2.fuzzyClassicPolygon(
      polygon: SourcePolygon2(const [
        SourcePoint2(0, 0),
        SourcePoint2(100000, 0),
        SourcePoint2(100000, 100000),
        SourcePoint2(0, 100000),
      ]),
      thicknessMm: 0,
      pointDistanceMm: 0.5,
      random: SequenceRandom(zeroDisplacementSequence(12)),
    );

    expect(result.points.length, greaterThanOrEqualTo(3));
    for (var i = 1; i < result.points.length; i++) {
      expect(result.points[i], isNot(result.points[i - 1]));
    }
    expect(result.points.last, isNot(result.points.first));
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
