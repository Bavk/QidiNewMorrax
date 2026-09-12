import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_extrusion_line.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_apply.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_policy.dart';

class EmptyRandom implements SourceFuzzyUnitRandom2 {
  @override
  double nextUnit() => throw StateError('identity branch consumed random');
}

class ZeroRandom implements SourceFuzzyUnitRandom2 {
  int calls = 0;

  @override
  double nextUnit() {
    calls++;
    return 0;
  }
}

SourceArachneExtrusionLine2 line() => SourceArachneExtrusionLine2(
      insetIndex: 6,
      isOdd: false,
      junctions: [
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(0, 0),
          w: 20000,
          perimeterIndex: 0,
        ),
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(100000, 0),
          w: 20000,
          perimeterIndex: 0,
        ),
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(200000, 0),
          w: 20000,
          perimeterIndex: 0,
        ),
      ],
    );

SourceExPolygon2 stripe(int minX, int maxX) => SourceExPolygon2(
      contour: SourcePolygon2([
        SourcePoint2(minX, -10000),
        SourcePoint2(maxX, -10000),
        SourcePoint2(maxX, 10000),
        SourcePoint2(minX, 10000),
      ]),
    );

SourceFuzzySkinNoRegionConfig2 config({
  SourceFuzzySkinType2 type = SourceFuzzySkinType2.none,
  SourceFuzzySkinMode2 mode = SourceFuzzySkinMode2.displacement,
}) =>
    SourceFuzzySkinNoRegionConfig2(
      type: type,
      fuzzySkinFirstLayer: true,
      thicknessMm: 0.1,
      pointDistanceMm: 0.4,
      noiseType: SourceFuzzyNoiseType2.classic,
      mode: mode,
    );

void main() {
  test('Arachne identity branch preserves metadata without RNG', () {
    final source = line();
    final result = SourceFuzzySkinApply2.applyExtrusionLine(
      extrusion: source,
      baseConfig: config(),
      perimeterRegions: const [],
      layerIndex: 1,
      perimeterIndex: 0,
      isContour: true,
      sliceZMm: 0.2,
      random: EmptyRandom(),
    );

    expect(result.junctions, source.junctions);
    expect(result.insetIndex, 6);
    expect(result.isOdd, false);
    expect(result.isClosed, false);
    expect(identical(result, source), false);
  });

  test('Arachne whole-line fuzzy applies selected width mode', () {
    final random = ZeroRandom();
    final result = SourceFuzzySkinApply2.applyExtrusionLine(
      extrusion: line(),
      baseConfig: config(
        type: SourceFuzzySkinType2.external,
        mode: SourceFuzzySkinMode2.extrusion,
      ),
      perimeterRegions: const [],
      layerIndex: 1,
      perimeterIndex: 0,
      isContour: true,
      sliceZMm: 0.2,
      random: random,
    );

    expect(result.junctions.length, greaterThan(3));
    expect(result.junctions.any((junction) => junction.w != 20000), true);
    expect(result.insetIndex, 6);
    expect(random.calls, greaterThan(0));
  });

  test('painted Arachne region fuzzifies only segmented middle run', () {
    final random = ZeroRandom();
    final result = SourceFuzzySkinApply2.applyExtrusionLine(
      extrusion: line(),
      baseConfig: config(),
      perimeterRegions: [
        SourceFuzzySkinPerimeterRegion2(
          expolygons: [stripe(50000, 150000)],
          config: config(type: SourceFuzzySkinType2.external),
        ),
      ],
      layerIndex: 1,
      perimeterIndex: 0,
      isContour: true,
      sliceZMm: 0.2,
      random: random,
    );

    expect(result.insetIndex, 6);
    expect(result.isOdd, false);
    expect(result.isClosed, false);
    expect(result.front.p, const SourcePoint2(0, 0));
    expect(result.back.p, const SourcePoint2(200000, 0));
    expect(
      result.junctions.any(
        (junction) =>
            junction.p.x >= 50000 &&
            junction.p.x <= 150000 &&
            junction.p.y != 0,
      ),
      true,
    );
    expect(
      result.junctions
          .where((junction) => junction.p.x < 50000 || junction.p.x > 150000)
          .every((junction) => junction.p.y == 0),
      true,
    );
    expect(random.calls, greaterThan(0));
  });

  test('region seam duplicate removal ignores differing widths like source', () {
    final source = SourceArachneExtrusionLine2(
      insetIndex: 0,
      isOdd: false,
      junctions: [
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(0, 0),
          w: 10000,
          perimeterIndex: 0,
        ),
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(100000, 0),
          w: 30000,
          perimeterIndex: 0,
        ),
        SourceArachneExtrusionJunction2(
          p: const SourcePoint2(200000, 0),
          w: 50000,
          perimeterIndex: 0,
        ),
      ],
    );
    final result = SourceFuzzySkinApply2.applyExtrusionLine(
      extrusion: source,
      baseConfig: config(),
      perimeterRegions: [
        SourceFuzzySkinPerimeterRegion2(
          expolygons: [stripe(50000, 150000)],
          config: config(),
        ),
      ],
      layerIndex: 1,
      perimeterIndex: 0,
      isContour: true,
      sliceZMm: 0.2,
      random: EmptyRandom(),
    );

    for (var index = 1; index < result.junctions.length; index++) {
      expect(result.junctions[index - 1].p == result.junctions[index].p, false);
    }
  });
}
