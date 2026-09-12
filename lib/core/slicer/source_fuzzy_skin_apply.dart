import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import 'source_fuzzy_skin_geometry.dart';
import 'source_fuzzy_skin_policy.dart';
import 'source_line_segmentation.dart';

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

class SourceFuzzySkinPerimeterRegion2 {
  SourceFuzzySkinPerimeterRegion2({
    required Iterable<SourceExPolygon2> expolygons,
    required this.config,
  }) : expolygons = List.unmodifiable(expolygons);

  final List<SourceExPolygon2> expolygons;
  final SourceFuzzySkinNoRegionConfig2 config;
}

/// Pinned `apply_fuzzy_skin(Polygon, ...)` composition, including painted /
/// per-region line segmentation.
class SourceFuzzySkinApply2 {
  const SourceFuzzySkinApply2._();

  static SourcePolygon2 applyPolygon({
    required SourcePolygon2 polygon,
    required SourceFuzzySkinNoRegionConfig2 baseConfig,
    required List<SourceFuzzySkinPerimeterRegion2> perimeterRegions,
    required int layerIndex,
    required int perimeterIndex,
    required bool isContour,
    required double sliceZMm,
    required SourceFuzzyUnitRandom2 random,
  }) {
    if (perimeterRegions.isEmpty) {
      return _applyWholePolygon(
        polygon: polygon,
        config: baseConfig,
        layerIndex: layerIndex,
        perimeterIndex: perimeterIndex,
        isContour: isContour,
        sliceZMm: sliceZMm,
        random: random,
      );
    }

    final segments = SourceLineSegmentation2.polygonRegionSegmentation(
      subject: polygon,
      baseValue: baseConfig,
      regions: [
        for (final region in perimeterRegions)
          SourceLineSegmentationRegion2(
            expolygons: region.expolygons,
            value: region.config,
          ),
      ],
    );

    if (segments.length == 1) {
      return _applyWholePolygon(
        polygon: polygon,
        config: segments.single.value,
        layerIndex: layerIndex,
        perimeterIndex: perimeterIndex,
        isContour: isContour,
        sliceZMm: sliceZMm,
        random: random,
      );
    }

    final output = <SourcePoint2>[];
    for (final segment in segments) {
      final config = segment.value;
      final shouldFuzzify = SourceFuzzySkinPolicy2.shouldFuzzify(
        type: config.type,
        layerIndex: layerIndex,
        perimeterIndex: perimeterIndex,
        isContour: isContour,
        fuzzySkinFirstLayer: config.fuzzySkinFirstLayer,
      );
      final points = shouldFuzzify
          ? SourceFuzzySkinGeometry2.fuzzyPolyline(
              polyline: segment.polyline,
              thicknessMm: config.thicknessMm,
              pointDistanceMm: config.pointDistanceMm,
              sliceZMm: sliceZMm,
              noiseSettings: _noiseSettings(config),
              random: random,
            ).points
          : segment.polyline.points;
      if (points.isEmpty) continue;

      if (output.isNotEmpty && output.last == points.first) {
        output.removeLast();
      }
      output.addAll(points);
    }

    if (output.isEmpty) {
      throw StateError('source fuzzy region segmentation produced no polygon');
    }
    if (output.length > 1 && output.first == output.last) {
      output.removeLast();
    }
    return SourcePolygon2(output);
  }

  static SourcePolygon2 _applyWholePolygon({
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
      noiseSettings: _noiseSettings(config),
      random: random,
    );
  }

  static SourceFuzzyNoiseSettings2 _noiseSettings(
    SourceFuzzySkinNoRegionConfig2 config,
  ) =>
      SourceFuzzyNoiseSettings2(
        type: config.noiseType,
        scaleMm: config.noiseScaleMm,
        octaves: config.noiseOctaves,
        persistence: config.noisePersistence,
      );
}

/// Compatibility wrapper for the already-verified empty-region branch.
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
  }) =>
      SourceFuzzySkinApply2.applyPolygon(
        polygon: polygon,
        baseConfig: config,
        perimeterRegions: const [],
        layerIndex: layerIndex,
        perimeterIndex: perimeterIndex,
        isContour: isContour,
        sliceZMm: sliceZMm,
        random: random,
      );
}
