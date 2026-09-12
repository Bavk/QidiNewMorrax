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
  });

  final SourceFuzzySkinType2 type;
  final bool fuzzySkinFirstLayer;
  final double thicknessMm;
  final double pointDistanceMm;
  final SourceFuzzyNoiseType2 noiseType;
}

/// Source `apply_fuzzy_skin()` composition for the branch where
/// `perimeter_regions.empty()`.
///
/// The policy decision is exact. Classic displacement geometry is ported and
/// consumes an explicit source random stream. Other source noise algorithms are
/// deliberately rejected only when geometry would actually be fuzzified; an
/// identity policy branch never consults the noise implementation, matching the
/// source control flow.
class SourceFuzzySkinNoRegionApply2 {
  const SourceFuzzySkinNoRegionApply2._();

  static SourcePolygon2 applyPolygon({
    required SourcePolygon2 polygon,
    required SourceFuzzySkinNoRegionConfig2 config,
    required int layerIndex,
    required int perimeterIndex,
    required bool isContour,
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

    if (config.noiseType != SourceFuzzyNoiseType2.classic) {
      throw UnsupportedError(
        'source fuzzy ${config.noiseType.name} noise is not ported yet',
      );
    }

    return SourceFuzzySkinGeometry2.fuzzyClassicPolygon(
      polygon: polygon,
      thicknessMm: config.thicknessMm,
      pointDistanceMm: config.pointDistanceMm,
      random: random,
    );
  }
}
