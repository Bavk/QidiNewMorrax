import '../geometry/source_polygon.dart';
import 'source_fuzzy_skin_geometry_exact.dart';
import 'source_fuzzy_skin_policy.dart';

class SourceFuzzySkinNoRegionExactConfig2 {
  const SourceFuzzySkinNoRegionExactConfig2({
    required this.type,
    required this.fuzzySkinFirstLayer,
    required this.thicknessMm,
    required this.pointDistanceMm,
    required this.noiseType,
  });

  final SourceFuzzySkinType2 type;
  final bool fuzzySkinFirstLayer;
  final double thicknessMm;
  final double pointDistanceMm;
  final SourceFuzzyNoiseTypeExact2 noiseType;
}

/// Exact no-painted-region composition of source `apply_fuzzy_skin()` for the
/// Classic noise branch, with source's independent spacing/displacement RNGs.
class SourceFuzzySkinNoRegionExactApply2 {
  const SourceFuzzySkinNoRegionExactApply2._();

  static SourcePolygon2 applyPolygon({
    required SourcePolygon2 polygon,
    required SourceFuzzySkinNoRegionExactConfig2 config,
    required int layerIndex,
    required int perimeterIndex,
    required bool isContour,
    required SourceFuzzySpacingRandom2 spacingRandom,
    required SourceFuzzyClassicDisplacementRandom2 displacementRandom,
  }) {
    final fuzzify = SourceFuzzySkinPolicy2.shouldFuzzify(
      type: config.type,
      layerIndex: layerIndex,
      perimeterIndex: perimeterIndex,
      isContour: isContour,
      fuzzySkinFirstLayer: config.fuzzySkinFirstLayer,
    );
    if (!fuzzify) return polygon;

    if (config.noiseType != SourceFuzzyNoiseTypeExact2.classic) {
      throw UnsupportedError(
        'source fuzzy ${config.noiseType.name} noise is not ported yet',
      );
    }

    return SourceFuzzySkinGeometryExact2.fuzzyClassicPolygon(
      polygon: polygon,
      thicknessMm: config.thicknessMm,
      pointDistanceMm: config.pointDistanceMm,
      spacingRandom: spacingRandom,
      displacementRandom: displacementRandom,
    );
  }
}
