import '../geometry/source_polygon.dart';

/// Exact source ordering from `PrintConfig.hpp`.
enum SourceFuzzySkinType2 {
  none,
  external,
  all,
  allWalls,
  disabledFuzzy,
}

/// Policy-only port of the classic/Arachne fuzzy-skin decisions shared by
/// `FuzzySkin.cpp` and classic `PerimeterGenerator::traverse_loops()`.
///
/// This file deliberately does not approximate fuzzy geometry. Callers may use
/// [identityPolygon] only when [shouldFuzzify] is false; a geometry-producing
/// branch throws until the displacement/noise and perimeter-region segmentation
/// source paths are ported.
class SourceFuzzySkinPolicy2 {
  const SourceFuzzySkinPolicy2._();

  /// Literal `should_fuzzify(const PrintRegionConfig&, layer_idx,
  /// perimeter_idx, is_contour)` behavior from the pinned source.
  static bool shouldFuzzify({
    required SourceFuzzySkinType2 type,
    required int layerIndex,
    required int perimeterIndex,
    required bool isContour,
    required bool fuzzySkinFirstLayer,
  }) {
    if (layerIndex < 0) {
      throw ArgumentError.value(layerIndex, 'layerIndex', 'must be >= 0');
    }
    if (perimeterIndex < 0) {
      throw ArgumentError.value(
        perimeterIndex,
        'perimeterIndex',
        'must be >= 0',
      );
    }

    if (type == SourceFuzzySkinType2.none ||
        type == SourceFuzzySkinType2.disabledFuzzy) {
      return false;
    }
    if (!fuzzySkinFirstLayer && layerIndex <= 0) return false;

    final fuzzifyContours =
        perimeterIndex == 0 || type == SourceFuzzySkinType2.allWalls;
    final fuzzifyHoles =
        fuzzifyContours &&
        (type == SourceFuzzySkinType2.all ||
            type == SourceFuzzySkinType2.allWalls);
    return isContour ? fuzzifyContours : fuzzifyHoles;
  }

  /// Literal classic `fuzzy_skin_allows_overhang_slowdown()` quirk.
  ///
  /// `None` and `Disabled_fuzzy` both leave geometry unchanged, but they are
  /// intentionally *not* equivalent here: Disabled always allows slowdown,
  /// while None allows it only without painted/per-region fuzzy regions.
  static bool allowsOverhangSlowdown({
    required SourceFuzzySkinType2 type,
    required bool perimeterRegionsEmpty,
  }) =>
      type == SourceFuzzySkinType2.disabledFuzzy ||
      (type == SourceFuzzySkinType2.none && perimeterRegionsEmpty);

  /// Safe identity-only representation of `apply_fuzzy_skin()`.
  ///
  /// The pinned source returns the input polygon unchanged whenever
  /// [shouldFuzzify] is false. If source would fuzzify, fail explicitly instead
  /// of silently treating the unfuzzified polygon as source-equivalent.
  static SourcePolygon2 identityPolygon({
    required SourcePolygon2 polygon,
    required SourceFuzzySkinType2 type,
    required int layerIndex,
    required int perimeterIndex,
    required bool isContour,
    required bool fuzzySkinFirstLayer,
  }) {
    if (shouldFuzzify(
      type: type,
      layerIndex: layerIndex,
      perimeterIndex: perimeterIndex,
      isContour: isContour,
      fuzzySkinFirstLayer: fuzzySkinFirstLayer,
    )) {
      throw UnsupportedError(
        'source fuzzy geometry is required for this policy branch',
      );
    }
    return polygon;
  }
}
