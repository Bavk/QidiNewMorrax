import 'dart:math' as math;

import '../geometry/source_geometry.dart';
import 'source_arachne_extrusion_line.dart';
import 'source_fuzzy_skin_geometry.dart';

/// Pinned `FuzzySkin.cpp::fuzzy_extrusion_line()` for the represented Arachne
/// `ExtrusionLine` subset.
class SourceFuzzySkinArachne2 {
  const SourceFuzzySkinArachne2._();

  static SourceArachneExtrusionLine2 fuzzyExtrusionLine({
    required SourceArachneExtrusionLine2 extrusion,
    required double thicknessMm,
    required double pointDistanceMm,
    required double sliceZMm,
    required SourceFuzzyNoiseSettings2 noiseSettings,
    required SourceFuzzySkinMode2 mode,
    required SourceFuzzyUnitRandom2 random,
  }) {
    if (extrusion.junctions.length < 2) {
      throw StateError(
        'source fuzzy Arachne extrusion line requires at least two junctions',
      );
    }
    if (!thicknessMm.isFinite || thicknessMm < 0) {
      throw ArgumentError.value(
        thicknessMm,
        'thicknessMm',
        'must be finite and >= 0',
      );
    }
    if (!pointDistanceMm.isFinite || pointDistanceMm <= 0) {
      throw ArgumentError.value(
        pointDistanceMm,
        'pointDistanceMm',
        'must be finite and > 0',
      );
    }

    final thickness = thicknessMm / Slic3rUnits.scalingFactor;
    final pointDistance = pointDistanceMm / Slic3rUnits.scalingFactor;
    final minDistance = pointDistance * 3.0 / 4.0;
    final randomRange = pointDistance / 2.0;
    final minExtrusionWidth = 0.01 / Slic3rUnits.scalingFactor;
    var distanceLeftOver =
        SourceFuzzySkinGeometry2.unitRandom(random) * (minDistance / 2.0);
    final deterministicNoise =
        SourceFuzzySkinGeometry2.noiseModule(noiseSettings);

    var p0 = extrusion.front;
    final output = <SourceArachneExtrusionJunction2>[];
    for (final p1 in extrusion.junctions) {
      if (p0.p == p1.p) {
        // Source reconstructs this junction without the compensation flag.
        output.add(SourceArachneExtrusionJunction2(
          p: p1.p,
          w: p1.w,
          perimeterIndex: p1.perimeterIndex,
        ));
        continue;
      }

      final dx = p1.p.x - p0.p.x;
      final dy = p1.p.y - p0.p.y;
      final segmentLength = math.sqrt(
        dx.toDouble() * dx.toDouble() + dy.toDouble() * dy.toDouble(),
      );
      var distanceFromP0 = distanceLeftOver;

      while (distanceFromP0 < segmentLength) {
        final ratio = distanceFromP0 / segmentLength;
        final sample = SourcePoint2(
          p0.p.x + (dx * ratio).truncate(),
          p0.p.y + (dy * ratio).truncate(),
        );
        final noiseValue = noiseSettings.type == SourceFuzzyNoiseType2.classic
            ? SourceFuzzySkinGeometry2.unitRandom(random) * 2.0 - 1.0
            : deterministicNoise!.getValue(
                sample.x * Slic3rUnits.scalingFactor,
                sample.y * Slic3rUnits.scalingFactor,
                sliceZMm,
              );
        final r = noiseValue * thickness;
        final normalX = -dy / segmentLength;
        final normalY = dx / segmentLength;

        switch (mode) {
          case SourceFuzzySkinMode2.displacement:
            output.add(SourceArachneExtrusionJunction2(
              p: SourcePoint2(
                sample.x + (normalX * r).truncate(),
                sample.y + (normalY * r).truncate(),
              ),
              w: p1.w,
              perimeterIndex: p1.perimeterIndex,
            ));
            break;
          case SourceFuzzySkinMode2.extrusion:
            final width = math.max(
              p1.w + r + minExtrusionWidth,
              minExtrusionWidth,
            );
            output.add(SourceArachneExtrusionJunction2(
              p: sample,
              w: width.truncate(),
              perimeterIndex: p1.perimeterIndex,
            ));
            break;
          case SourceFuzzySkinMode2.combined:
            final width = math.max(
              p1.w + r + minExtrusionWidth,
              minExtrusionWidth,
            );
            final shift = (width - p1.w) / 2.0;
            output.add(SourceArachneExtrusionJunction2(
              p: SourcePoint2(
                sample.x + (normalX * shift).truncate(),
                sample.y + (normalY * shift).truncate(),
              ),
              w: width.truncate(),
              perimeterIndex: p1.perimeterIndex,
            ));
            break;
        }

        distanceFromP0 += minDistance +
            SourceFuzzySkinGeometry2.unitRandom(random) * randomRange;
      }

      distanceLeftOver = distanceFromP0 - segmentLength;
      p0 = p1;
    }

    // Preserve the pinned fallback bug literally: pointIndex is re-created on
    // every loop, so the same penultimate junction may be repeated.
    while (output.length < 3) {
      var pointIndex = extrusion.junctions.length - 2;
      final source = extrusion.junctions[pointIndex];
      output.add(SourceArachneExtrusionJunction2(
        p: source.p,
        w: source.w,
        perimeterIndex: source.perimeterIndex,
      ));
      if (pointIndex == 0) break;
      --pointIndex;
    }

    // Source keys closure synchronization off endpoint coordinates, not the
    // `is_closed` flag, and synchronizes only position and width.
    if (extrusion.back.p == extrusion.front.p && output.isNotEmpty) {
      output.first.p = output.last.p;
      output.first.w = output.last.w;
    }

    if (output.length < 3) return extrusion.copy();
    return SourceArachneExtrusionLine2(
      insetIndex: extrusion.insetIndex,
      isOdd: extrusion.isOdd,
      isClosed: extrusion.isClosed,
      junctions: output,
    );
  }
}
