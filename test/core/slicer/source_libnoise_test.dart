import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/slicer/source_libnoise.dart';

void main() {
  test('libnoise ValueNoise3D hash matches v1.0.0 source fixtures', () {
    expect(
      SourceLibNoiseCore2.intValueNoise3D(0, 0, 0, 0),
      1376312589,
    );
    expect(
      SourceLibNoiseCore2.valueNoise3D(1, 2, 3, 0),
      closeTo(0.5820278069004416, 1e-15),
    );
    expect(
      SourceLibNoiseCore2.valueNoise3D(-4, 5, -6, 2),
      closeTo(-0.9075282895937562, 1e-15),
    );
  });

  test('gradient hash reaches first and last pinned vector-table rows', () {
    expect(
      SourceLibNoiseCore2.gradientNoise3D(
        -5.75,
        3.5,
        0.75,
        -6,
        3,
        0,
        0,
      ),
      closeTo(-1.4289960700000002, 1e-15),
    );
    expect(
      SourceLibNoiseCore2.gradientNoise3D(
        -7.75,
        5.5,
        4.75,
        -8,
        5,
        4,
        0,
      ),
      closeTo(-1.333456468, 1e-15),
    );
  });

  test('MakeInt32Range preserves libnoise fmod sign semantics', () {
    expect(
      SourceLibNoiseCore2.makeInt32Range(1073741825.25),
      closeTo(-1073741821.5, 0),
    );
    expect(
      SourceLibNoiseCore2.makeInt32Range(-1073741825.25),
      closeTo(1073741821.5, 0),
    );
  });

  test('Perlin/Billow/Ridged octave formulas match integer-coordinate oracle', () {
    final perlin = SourceLibNoisePerlin2(
      frequency: 1,
      octaveCount: 4,
      persistence: 0.5,
    );
    final billow = SourceLibNoiseBillow2(
      frequency: 1,
      octaveCount: 4,
      persistence: 0.5,
    );
    final ridged = SourceLibNoiseRidgedMulti2(
      frequency: 1,
      octaveCount: 4,
    );

    expect(perlin.getValue(0, 0, 0), closeTo(0, 1e-15));
    expect(billow.getValue(0, 0, 0), closeTo(-1.375, 1e-15));
    expect(ridged.getValue(0, 0, 0), closeTo(1.34375, 1e-15));
  });

  test('Voronoi cell displacement matches libnoise v1.0.0 oracle', () {
    const voronoi = SourceLibNoiseVoronoi2(frequency: 1, displacement: 1);
    expect(
      voronoi.getValue(0, 0, 0),
      closeTo(0.37672762479633093, 1e-15),
    );
    expect(
      voronoi.getValue(0.25, -0.5, 1.75),
      closeTo(0.8044787487015128, 1e-15),
    );
  });

  test('source cube-lower quirk maps zero and negative integers below boundary', () {
    expect(SourceLibNoiseCore2.sourceCubeLower(1.0), 1);
    expect(SourceLibNoiseCore2.sourceCubeLower(0.0), -1);
    expect(SourceLibNoiseCore2.sourceCubeLower(-1.0), -2);
    expect(SourceLibNoiseCore2.sourceCubeLower(-1.2), -2);
  });
}
