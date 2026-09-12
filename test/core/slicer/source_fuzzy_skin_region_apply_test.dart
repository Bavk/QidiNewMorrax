import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_apply.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_policy.dart';

class ZeroRandom implements SourceFuzzyUnitRandom2 {
  int calls = 0;

  @override
  double nextUnit() {
    calls++;
    return 0;
  }
}

SourcePolygon2 rectangle(int minX, int minY, int maxX, int maxY) =>
    SourcePolygon2([
      SourcePoint2(minX, minY),
      SourcePoint2(maxX, minY),
      SourcePoint2(maxX, maxY),
      SourcePoint2(minX, maxY),
    ]);

SourceExPolygon2 regionBox(int minX, int minY, int maxX, int maxY) =>
    SourceExPolygon2(contour: rectangle(minX, minY, maxX, maxY));

SourceFuzzySkinNoRegionConfig2 config({
  SourceFuzzySkinType2 type = SourceFuzzySkinType2.none,
  SourceFuzzyNoiseType2 noise = SourceFuzzyNoiseType2.perlin,
}) =>
    SourceFuzzySkinNoRegionConfig2(
      type: type,
      fuzzySkinFirstLayer: true,
      thicknessMm: 0.1,
      pointDistanceMm: 0.4,
      noiseType: noise,
    );

void main() {
  test('one painted segment uses whole-polygon source branch', () {
    final polygon = rectangle(0, 0, 200000, 100000);
    final painted = config(type: SourceFuzzySkinType2.external);
    final directRandom = ZeroRandom();
    final applyRandom = ZeroRandom();

    final direct = SourceFuzzySkinGeometry2.fuzzyPolygon(
      polygon: polygon,
      thicknessMm: painted.thicknessMm,
      pointDistanceMm: painted.pointDistanceMm,
      sliceZMm: 0.2,
      noiseSettings: SourceFuzzyNoiseSettings2(
        type: painted.noiseType,
        scaleMm: painted.noiseScaleMm,
        octaves: painted.noiseOctaves,
        persistence: painted.noisePersistence,
      ),
      random: directRandom,
    );
    final result = SourceFuzzySkinApply2.applyPolygon(
      polygon: polygon,
      baseConfig: config(),
      perimeterRegions: [
        SourceFuzzySkinPerimeterRegion2(
          expolygons: [regionBox(-10000, -10000, 210000, 110000)],
          config: painted,
        ),
      ],
      layerIndex: 1,
      perimeterIndex: 0,
      isContour: true,
      sliceZMm: 0.2,
      random: applyRandom,
    );

    expect(result.points, direct.points);
    expect(applyRandom.calls, directRandom.calls);
  });

  test('multiple painted runs fuzzify as independent open polylines', () {
    final polygon = rectangle(0, 0, 200000, 100000);
    final random = ZeroRandom();
    final result = SourceFuzzySkinApply2.applyPolygon(
      polygon: polygon,
      baseConfig: config(),
      perimeterRegions: [
        SourceFuzzySkinPerimeterRegion2(
          expolygons: [regionBox(50000, -10000, 150000, 110000)],
          config: config(type: SourceFuzzySkinType2.external),
        ),
      ],
      layerIndex: 1,
      perimeterIndex: 0,
      isContour: true,
      sliceZMm: 0.2,
      random: random,
    );

    // The vertical stripe intersects the lower and upper perimeter runs.
    // Each deterministic open fuzzy_polyline call consumes one initial spacing
    // draw plus four following spacing draws for a 100k-unit run.
    expect(random.calls, 10);
    expect(result.points.length, greaterThan(polygon.points.length));
    expect(result.points.contains(const SourcePoint2(200000, 0)), true);
    expect(result.points.contains(const SourcePoint2(200000, 100000)), true);
    expect(result.points.any((point) => point.y < 0 || point.y > 100000), true);
    expect(result.points.first, isNot(result.points.last));
  });

  test('identity region still reconstructs segmented boundary without RNG', () {
    final polygon = rectangle(0, 0, 200000, 100000);
    final random = ZeroRandom();
    final result = SourceFuzzySkinApply2.applyPolygon(
      polygon: polygon,
      baseConfig: config(),
      perimeterRegions: [
        SourceFuzzySkinPerimeterRegion2(
          expolygons: [regionBox(50000, -10000, 150000, 110000)],
          config: config(),
        ),
      ],
      layerIndex: 1,
      perimeterIndex: 0,
      isContour: true,
      sliceZMm: 0.2,
      random: random,
    );

    expect(random.calls, 0);
    expect(result.points.contains(const SourcePoint2(50000, 0)), true);
    expect(result.points.contains(const SourcePoint2(150000, 0)), true);
    expect(result.points.contains(const SourcePoint2(150000, 100000)), true);
    expect(result.points.contains(const SourcePoint2(50000, 100000)), true);
    expect(result.points.first, isNot(result.points.last));
  });
}
