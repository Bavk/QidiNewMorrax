import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_apply.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_policy.dart';

class SequenceRandom implements SourceFuzzyUnitRandom2 {
  SequenceRandom(this.values);

  final List<double> values;
  int _index = 0;

  int get consumed => _index;

  @override
  double nextUnit() {
    if (_index >= values.length) {
      throw StateError('test random sequence exhausted at $_index');
    }
    return values[_index++];
  }
}

SourcePolygon2 box() => SourcePolygon2(const [
      SourcePoint2(0, 0),
      SourcePoint2(100000, 0),
      SourcePoint2(100000, 100000),
      SourcePoint2(0, 100000),
    ]);

List<double> zeroDisplacementSequence(int samples) => [
      0,
      for (var i = 0; i < samples; i++) ...[0.5, 0],
    ];

SourceFuzzySkinNoRegionConfig2 config({
  SourceFuzzySkinType2 type = SourceFuzzySkinType2.external,
  bool firstLayer = true,
  SourceFuzzyNoiseType2 noise = SourceFuzzyNoiseType2.classic,
}) =>
    SourceFuzzySkinNoRegionConfig2(
      type: type,
      fuzzySkinFirstLayer: firstLayer,
      thicknessMm: 0.1,
      pointDistanceMm: 0.4,
      noiseType: noise,
    );

void main() {
  test('identity policy returns input without consuming the random stream', () {
    final polygon = box();
    final random = SequenceRandom(const []);
    final result = SourceFuzzySkinNoRegionApply2.applyPolygon(
      polygon: polygon,
      config: config(type: SourceFuzzySkinType2.none),
      layerIndex: 3,
      perimeterIndex: 0,
      isContour: true,
      random: random,
    );

    expect(identical(result, polygon), true);
    expect(random.consumed, 0);
  });

  test('External depth-zero contour delegates to Classic source geometry', () {
    final polygon = box();
    final directRandom = SequenceRandom(zeroDisplacementSequence(20));
    final applyRandom = SequenceRandom(zeroDisplacementSequence(20));
    final direct = SourceFuzzySkinGeometry2.fuzzyClassicPolygon(
      polygon: polygon,
      thicknessMm: 0.1,
      pointDistanceMm: 0.4,
      random: directRandom,
    );
    final result = SourceFuzzySkinNoRegionApply2.applyPolygon(
      polygon: polygon,
      config: config(),
      layerIndex: 1,
      perimeterIndex: 0,
      isContour: true,
      random: applyRandom,
    );

    expect(result.points, direct.points);
    expect(applyRandom.consumed, directRandom.consumed);
  });

  test('External hole remains identity and does not inspect noise type', () {
    final polygon = box();
    final random = SequenceRandom(const []);
    final result = SourceFuzzySkinNoRegionApply2.applyPolygon(
      polygon: polygon,
      config: config(noise: SourceFuzzyNoiseType2.perlin),
      layerIndex: 1,
      perimeterIndex: 0,
      isContour: false,
      random: random,
    );

    expect(identical(result, polygon), true);
    expect(random.consumed, 0);
  });

  test('first-layer suppression returns identity before noise implementation', () {
    final polygon = box();
    final random = SequenceRandom(const []);
    final result = SourceFuzzySkinNoRegionApply2.applyPolygon(
      polygon: polygon,
      config: config(
        type: SourceFuzzySkinType2.allWalls,
        firstLayer: false,
        noise: SourceFuzzyNoiseType2.voronoi,
      ),
      layerIndex: 0,
      perimeterIndex: 4,
      isContour: false,
      random: random,
    );

    expect(identical(result, polygon), true);
    expect(random.consumed, 0);
  });

  test('required non-Classic fuzzy geometry fails explicitly', () {
    expect(
      () => SourceFuzzySkinNoRegionApply2.applyPolygon(
        polygon: box(),
        config: config(noise: SourceFuzzyNoiseType2.perlin),
        layerIndex: 1,
        perimeterIndex: 0,
        isContour: true,
        random: SequenceRandom(const []),
      ),
      throwsUnsupportedError,
    );
  });
}
