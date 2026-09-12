import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import 'source_arachne_extrusion_line.dart';
import 'source_fuzzy_skin_arachne.dart';
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
    this.mode = SourceFuzzySkinMode2.displacement,
    this.noiseScaleMm = 1.0,
    this.noiseOctaves = 4,
    this.noisePersistence = 0.5,
  });

  final SourceFuzzySkinType2 type;
  final bool fuzzySkinFirstLayer;
  final double thicknessMm;
  final double pointDistanceMm;
  final SourceFuzzyNoiseType2 noiseType;
  final SourceFuzzySkinMode2 mode;
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

/// Pinned `apply_fuzzy_skin(...)` composition for represented Polygon and
/// Arachne ExtrusionLine paths, including painted/per-region segmentation.
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
      final shouldFuzzify = _shouldFuzzify(
        config: config,
        layerIndex: layerIndex,
        perimeterIndex: perimeterIndex,
        isContour: isContour,
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

  static SourceArachneExtrusionLine2 applyExtrusionLine({
    required SourceArachneExtrusionLine2 extrusion,
    required SourceFuzzySkinNoRegionConfig2 baseConfig,
    required List<SourceFuzzySkinPerimeterRegion2> perimeterRegions,
    required int layerIndex,
    required int perimeterIndex,
    required bool isContour,
    required double sliceZMm,
    required SourceFuzzyUnitRandom2 random,
  }) {
    if (perimeterRegions.isEmpty) {
      if (!_shouldFuzzify(
        config: baseConfig,
        layerIndex: layerIndex,
        perimeterIndex: perimeterIndex,
        isContour: isContour,
      )) {
        return extrusion.copy();
      }
      return _fuzzyExtrusionLine(
        extrusion: extrusion,
        config: baseConfig,
        sliceZMm: sliceZMm,
        random: random,
      );
    }

    final segments = SourceLineSegmentation2.extrusionRegionSegmentation(
      subject: extrusion,
      baseValue: baseConfig,
      regions: [
        for (final region in perimeterRegions)
          SourceLineSegmentationRegion2(
            expolygons: region.expolygons,
            value: region.config,
          ),
      ],
    );
    final output = <SourceArachneExtrusionJunction2>[];

    for (final segment in segments) {
      final config = segment.value;
      final transformed = _shouldFuzzify(
        config: config,
        layerIndex: layerIndex,
        perimeterIndex: perimeterIndex,
        isContour: isContour,
      )
          ? _fuzzyExtrusionLine(
              extrusion: segment.extrusion,
              config: config,
              sliceZMm: sliceZMm,
              random: random,
            )
          : segment.extrusion;

      if (transformed.isEmpty) continue;
      if (output.isNotEmpty && output.last.p == transformed.front.p) {
        // Source ignores width differences when removing a region seam point.
        output.removeLast();
      }
      output.addAll([
        for (final junction in transformed.junctions) junction.copy(),
      ]);
    }

    if (output.isEmpty) {
      throw StateError(
        'source fuzzy region segmentation produced no Arachne extrusion',
      );
    }
    return SourceArachneExtrusionLine2(
      insetIndex: extrusion.insetIndex,
      isOdd: extrusion.isOdd,
      isClosed: extrusion.isClosed,
      junctions: output,
    );
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
    if (!_shouldFuzzify(
      config: config,
      layerIndex: layerIndex,
      perimeterIndex: perimeterIndex,
      isContour: isContour,
    )) {
      return polygon;
    }

    return SourceFuzzySkinGeometry2.fuzzyPolygon(
      polygon: polygon,
      thicknessMm: config.thicknessMm,
      pointDistanceMm: config.pointDistanceMm,
      sliceZMm: sliceZMm,
      noiseSettings: _noiseSettings(config),
      random: random,
    );
  }

  static SourceArachneExtrusionLine2 _fuzzyExtrusionLine({
    required SourceArachneExtrusionLine2 extrusion,
    required SourceFuzzySkinNoRegionConfig2 config,
    required double sliceZMm,
    required SourceFuzzyUnitRandom2 random,
  }) =>
      SourceFuzzySkinArachne2.fuzzyExtrusionLine(
        extrusion: extrusion,
        thicknessMm: config.thicknessMm,
        pointDistanceMm: config.pointDistanceMm,
        sliceZMm: sliceZMm,
        noiseSettings: _noiseSettings(config),
        mode: config.mode,
        random: random,
      );

  static bool _shouldFuzzify({
    required SourceFuzzySkinNoRegionConfig2 config,
    required int layerIndex,
    required int perimeterIndex,
    required bool isContour,
  }) =>
      SourceFuzzySkinPolicy2.shouldFuzzify(
        type: config.type,
        layerIndex: layerIndex,
        perimeterIndex: perimeterIndex,
        isContour: isContour,
        fuzzySkinFirstLayer: config.fuzzySkinFirstLayer,
      );

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

/// Compatibility wrapper for the already-verified empty-region Polygon branch.
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
