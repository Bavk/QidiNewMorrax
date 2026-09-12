import '../geometry/source_polygon.dart';
import 'source_fuzzy_skin_geometry.dart';
import 'source_fuzzy_skin_policy.dart';

class SourceFuzzySkinNoRegionConfig2 {
  const SourceFuzzySkinNoRegionConfig2({
    required this.type,
    required this.fuzzySkinFirstLayer,
    required this.thicknessMm,
    required this.pointDistanceMm,
    required this.noiseType,
    this.noiseScaleMm = 1.0,
    this.noiseOctaves = 4,
    this.noisePersistence = 0.5,
  });

  final SourceFuzzySkinType2 type;
  final bool fuzzySkinFirstLayer;
  final double thicknessMm;
  final double pointDistanceMm;
  final SourceFuzzyNoiseType2 noiseType;
  final double noiseScaleMm;
  final int noiseOctaves;
  final double noisePersistence;
}

/// Source `apply_fuzzy_skin()` composition for `perimeter_regions.empty()`.
class SourceFuzzySkinNoRegionApply2 {
  const SourceFuzzySkinNoRegionApply2._();

  static SourcePolygon2 applyPolygon({
    required SourcePolygon2 polygon,
    required SourceFuzzySkinNoRegionConfig2 config,
    required int layerIndex,
    required int perimeterIndex,
    required bool isContour,
    required double sliceZMm,
    required SourceFuzzyUnitRandom2 random,
  }) {
    final fuzzify = SourceFuzzySkinPolicy2.shouldFuzzify(
      type: config.type,
      layerIndex: layerIndex,
      perimeterIndex: perimeterIndex,
      isContour: isContour,
      fuzzySkinFirstLayer: config.fuzzySkinFirstLayer,
    );
    if (!fuzzify) return polygon;

    return SourceFuzzySkinGeometry2.fuzzyPolygon(
      polygon: polygon,
      thicknessMm: config.thicknessMm,
      pointDistanceMm: config.pointDistanceMm,
      sliceZMm: sliceZMm,
      noiseSettings: SourceFuzzyNoiseSettings2(
        type: config.noiseType,
        scaleMm: config.noiseScaleMm,
        octaves: config.noiseOctaves,
        persistence: config.noisePersistence,
      ),
      random: random,
    );
  }
}
