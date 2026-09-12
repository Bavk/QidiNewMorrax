import '../geometry/clipper_geometry.dart';
import '../geometry/expolygon.dart';

class ClassicPerimeterSettings {
  const ClassicPerimeterSettings({
    required this.wallLoops,
    required this.externalPerimeterWidth,
    required this.externalPerimeterSpacing,
    required this.perimeterWidth,
    required this.perimeterSpacing,
    this.extraPerimeters = 0,
    this.alternateExtraWall = false,
    this.preciseOuterWall = false,
    this.innerOuterWallSequence = false,
    this.detectThinWall = false,
    this.spiralVase = false,
  });

  final int wallLoops;
  final double externalPerimeterWidth;
  final double externalPerimeterSpacing;
  final double perimeterWidth;
  final double perimeterSpacing;
  final int extraPerimeters;
  final bool alternateExtraWall;
  final bool preciseOuterWall;
  final bool innerOuterWallSequence;
  final bool detectThinWall;
  final bool spiralVase;
}

class ClassicPerimeterLoop {
  const ClassicPerimeterLoop({
    required this.expolygon,
    required this.depth,
    required this.usesSmallerExternalWidth,
  });

  final ExPolygon2 expolygon;
  final int depth;
  final bool usesSmallerExternalWidth;
}

class ClassicPerimeterResult {
  const ClassicPerimeterResult({
    required this.loops,
    required this.innerRegion,
    required this.effectiveLoopCount,
  });

  final List<ClassicPerimeterLoop> loops;
  final List<ExPolygon2> innerRegion;
  final int effectiveLoopCount;
}

/// Ports the onion-shell portion of `PerimeterGenerator::process_classic()`.
///
/// Unsupported source branches throw instead of silently falling back to a
/// similar-looking approximation. Thin-wall medial-axis generation and gap
/// fill remain separate source migration units.
class ClassicPerimeterShellGenerator {
  const ClassicPerimeterShellGenerator({
    this.clipper = const ClipperGeometry(),
  });

  static const double insetOverlapTolerance = 0.4;
  static const double smallerExternalInsetOverlapTolerance = 0.22;
  static const double narrowLoopLengthThreshold = 10;

  final ClipperGeometry clipper;

  ClassicPerimeterResult generate(
    List<ExPolygon2> surfaces,
    ClassicPerimeterSettings settings, {
    required int layerIndex,
  }) {
    _validate(settings);
    if (settings.detectThinWall) {
      throw UnsupportedError(
        'Classic detect_thin_wall requires the source medial-axis/thick-polyline '
        'implementation; it is not silently approximated.',
      );
    }
    if (surfaces.isEmpty || settings.wallLoops <= 0) {
      return ClassicPerimeterResult(
        loops: const [],
        innerRegion: List.unmodifiable(surfaces),
        effectiveLoopCount: 0,
      );
    }

    var requestedLoopNumber = settings.wallLoops + settings.extraPerimeters - 1;
    if (settings.alternateExtraWall && layerIndex.isOdd && !settings.spiralVase) {
      requestedLoopNumber++;
    }
    if (requestedLoopNumber < 0) {
      return ClassicPerimeterResult(
        loops: const [],
        innerRegion: List.unmodifiable(surfaces),
        effectiveLoopCount: 0,
      );
    }

    final perimeterMinSpacing =
        settings.perimeterSpacing * (1 - insetOverlapTolerance);
    final smallerExternalMinSpacing = settings.externalPerimeterSpacing *
        (1 - smallerExternalInsetOverlapTolerance);
    final smallerExternalWidth = settings.externalPerimeterWidth -
        0.5 * smallerExternalInsetOverlapTolerance *
            settings.externalPerimeterSpacing;

    final externalToInternalSpacing =
        settings.preciseOuterWall && settings.innerOuterWallSequence
            ? 0.5 * (settings.externalPerimeterWidth + settings.perimeterWidth)
            : 0.5 *
                (settings.externalPerimeterSpacing + settings.perimeterSpacing);

    var last = clipper.offsetExPolygons(surfaces, 0);
    final output = <ClassicPerimeterLoop>[];
    var effectiveLoopNumber = requestedLoopNumber;

    for (var i = 0;; i++) {
      var offsets = <ExPolygon2>[];
      var smallerWidthOffsets = <ExPolygon2>[];

      if (i == 0) {
        for (final expolygon in last) {
          final narrowProbe = clipper.offset2Ex(
            [expolygon],
            -(settings.externalPerimeterWidth / 2 +
                smallerExternalMinSpacing / 2),
            smallerExternalMinSpacing / 2,
          );

          final useSmallerWidth = narrowProbe.isEmpty &&
              expolygon.area <
                  (settings.externalPerimeterWidth +
                          smallerExternalMinSpacing) *
                      narrowLoopLengthThreshold;

          if (useSmallerWidth) {
            smallerWidthOffsets.addAll(
              clipper.offsetExPolygon(expolygon, -smallerExternalWidth / 2),
            );
          } else {
            offsets.addAll(
              clipper.offsetExPolygon(
                expolygon,
                -settings.externalPerimeterWidth / 2,
              ),
            );
          }
        }

        if (settings.spiralVase &&
            (offsets.length > 1 || smallerWidthOffsets.length > 1)) {
          if (offsets.isNotEmpty) {
            offsets = [_largest(offsets)];
            smallerWidthOffsets = const [];
          } else if (smallerWidthOffsets.isNotEmpty) {
            smallerWidthOffsets = [_largest(smallerWidthOffsets)];
          }
        }
      } else {
        final distance = i == 1
            ? externalToInternalSpacing
            : settings.perimeterSpacing;
        final oneCoordUnit = ClipperGeometry.scalingFactor;
        offsets = clipper.offset2Ex(
          last,
          -(distance + perimeterMinSpacing / 2 - oneCoordUnit),
          perimeterMinSpacing / 2 - oneCoordUnit,
        );
      }

      if (offsets.isEmpty && smallerWidthOffsets.isEmpty) {
        effectiveLoopNumber = i - 1;
        last = const [];
        break;
      }
      if (i > requestedLoopNumber) break;

      for (final expolygon in offsets) {
        output.add(ClassicPerimeterLoop(
          expolygon: expolygon,
          depth: i,
          usesSmallerExternalWidth: false,
        ));
      }
      for (final expolygon in smallerWidthOffsets) {
        output.add(ClassicPerimeterLoop(
          expolygon: expolygon,
          depth: i,
          usesSmallerExternalWidth: true,
        ));
      }

      last = clipper.unionEx([
        for (final expolygon in offsets) ...[
          expolygon.contour,
          ...expolygon.holes,
        ],
        for (final expolygon in smallerWidthOffsets) ...[
          expolygon.contour,
          ...expolygon.holes,
        ],
      ]);
    }

    return ClassicPerimeterResult(
      loops: List.unmodifiable(output),
      innerRegion: List.unmodifiable(last),
      effectiveLoopCount: effectiveLoopNumber + 1,
    );
  }

  ExPolygon2 _largest(List<ExPolygon2> polygons) =>
      polygons.reduce((a, b) => a.area >= b.area ? a : b);

  void _validate(ClassicPerimeterSettings settings) {
    if (settings.wallLoops < 0 || settings.extraPerimeters < 0) {
      throw ArgumentError('wallLoops and extraPerimeters must be >= 0');
    }
    if (settings.externalPerimeterWidth <= 0 ||
        settings.externalPerimeterSpacing <= 0 ||
        settings.perimeterWidth <= 0 ||
        settings.perimeterSpacing <= 0) {
      throw ArgumentError('perimeter widths and spacings must be > 0');
    }
  }
}
