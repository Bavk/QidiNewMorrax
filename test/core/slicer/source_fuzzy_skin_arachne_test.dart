import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_extrusion_line.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_arachne.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_geometry.dart';

class CountingZeroRandom implements SourceFuzzyUnitRandom2 {
  int calls = 0;

  @override
  double nextUnit() {
    calls++;
    return 0;
  }
}

SourceArachneExtrusionLine2 horizontalLine() =>
    SourceArachneExtrusionLine2(
      insetIndex: 2,
      isOdd: false,
      junctions: [
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(0, 0),
          w: 20000,
          perimeterIndex: 7,
          holeCompensationFlag: true,
        ),
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(100000, 0),
          w: 20000,
          perimeterIndex: 7,
          holeCompensationFlag: true,
        ),
      ],
    );

List<(int, int, int, int)> snapshot(SourceArachneExtrusionLine2 line) => [
      for (final junction in line.junctions)
        (
          junction.p.x,
          junction.p.y,
          junction.w,
          junction.perimeterIndex,
        ),
    ];

SourceArachneExtrusionLine2 runClassic(SourceFuzzySkinMode2 mode) =>
    SourceFuzzySkinArachne2.fuzzyExtrusionLine(
      extrusion: horizontalLine(),
      thicknessMm: 0.1,
      pointDistanceMm: 0.4,
      sliceZMm: 0.2,
      noiseSettings: const SourceFuzzyNoiseSettings2(
        type: SourceFuzzyNoiseType2.classic,
      ),
      mode: mode,
      random: SourceFuzzyMt19937Random2.seeded(5489),
    );

void main() {
  test('FuzzySkinMode enum preserves pinned source order', () {
    expect(SourceFuzzySkinMode2.values, [
      SourceFuzzySkinMode2.displacement,
      SourceFuzzySkinMode2.extrusion,
      SourceFuzzySkinMode2.combined,
    ]);
  });

  test('Displacement matches seeded C++ fuzzy_extrusion_line oracle', () {
    final result = runClassic(SourceFuzzySkinMode2.displacement);

    expect(snapshot(result), const [
      (0, 0, 20000, 7),
      (2032, 6700, 20000, 7),
      (51409, -5579, 20000, 7),
      (87572, 944, 20000, 7),
    ]);
    expect(
      result.junctions.every((junction) => !junction.holeCompensationFlag),
      true,
    );
  });

  test('Extrusion matches seeded C++ width oracle', () {
    final result = runClassic(SourceFuzzySkinMode2.extrusion);

    expect(snapshot(result), const [
      (0, 0, 20000, 7),
      (2032, 0, 27700, 7),
      (51409, 0, 15420, 7),
      (87572, 0, 21944, 7),
    ]);
  });

  test('Combined matches seeded C++ position and width oracle', () {
    final result = runClassic(SourceFuzzySkinMode2.combined);

    expect(snapshot(result), const [
      (0, 0, 20000, 7),
      (2032, 3850, 27700, 7),
      (51409, -2289, 15420, 7),
      (87572, 972, 21944, 7),
    ]);
  });

  test('structured noise consumes random_value only for sample spacing', () {
    final random = CountingZeroRandom();
    final result = SourceFuzzySkinArachne2.fuzzyExtrusionLine(
      extrusion: horizontalLine(),
      thicknessMm: 0.1,
      pointDistanceMm: 0.4,
      sliceZMm: 0.2,
      noiseSettings: const SourceFuzzyNoiseSettings2(
        type: SourceFuzzyNoiseType2.perlin,
      ),
      mode: SourceFuzzySkinMode2.displacement,
      random: random,
    );

    expect(result.junctions, hasLength(5));
    expect(random.calls, 5); // initial spacing + four following spacing draws
  });

  test('closed endpoint coordinates synchronize output front position and width', () {
    final line = SourceArachneExtrusionLine2(
      insetIndex: 1,
      isOdd: false,
      isClosed: false, // Source checks endpoint coordinates, not this flag.
      junctions: [
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(0, 0),
          w: 20000,
          perimeterIndex: 3,
        ),
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(100000, 0),
          w: 30000,
          perimeterIndex: 3,
        ),
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(100000, 100000),
          w: 40000,
          perimeterIndex: 3,
        ),
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(0, 0),
          w: 50000,
          perimeterIndex: 3,
        ),
      ],
    );

    final result = SourceFuzzySkinArachne2.fuzzyExtrusionLine(
      extrusion: line,
      thicknessMm: 0.1,
      pointDistanceMm: 0.4,
      sliceZMm: 0.2,
      noiseSettings: const SourceFuzzyNoiseSettings2(
        type: SourceFuzzyNoiseType2.classic,
      ),
      mode: SourceFuzzySkinMode2.combined,
      random: SourceFuzzyMt19937Random2.seeded(5489),
    );

    expect(result.front.p, result.back.p);
    expect(result.front.w, result.back.w);
    expect(result.isClosed, false);
    expect(result.insetIndex, 1);
    expect(result.isOdd, false);
  });
}
