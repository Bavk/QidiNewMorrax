import '../geometry/polygon.dart';

/// Pinned `TopOneWallType` order from `PrintConfig.hpp`.
enum SourceTopOneWallType2 {
  none,
  allTop,
  topmost,
}

/// Source process inputs that are not part of `ClassicPerimeterSettings` flow
/// geometry but affect `PerimeterGenerator::process_classic()` wall count and
/// the in-loop `TopOneWallType::Alltop` producer.
class SourceClassicTopOneWallContext2 {
  const SourceClassicTopOneWallContext2({
    this.type = SourceTopOneWallType2.none,
    this.onlyOneWallFirstLayer = false,
    this.upperSlices,
    this.lowerSlices,
    this.topAreaThresholdPercent = 0,
    this.sparseInfillLineWidthMm = 0,
  });

  final SourceTopOneWallType2 type;
  final bool onlyOneWallFirstLayer;

  /// Source nullability is semantically significant. `upper_slices == nullptr`
  /// triggers the topmost one-wall gate, while a non-null empty list means the
  /// current represented island has no upper coverage and therefore becomes an
  /// all-top candidate inside the `Alltop` producer.
  final List<Polygon2>? upperSlices;
  final List<Polygon2>? lowerSlices;

  final double topAreaThresholdPercent;
  final double sparseInfillLineWidthMm;
}
