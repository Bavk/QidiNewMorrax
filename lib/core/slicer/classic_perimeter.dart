import '../geometry/clipper_geometry.dart';
import '../geometry/expolygon.dart';
import '../geometry/polygon.dart';
import '../geometry/source_geometry.dart';
import '../geometry/source_medial_axis.dart';
import '../geometry/source_polygon.dart';
import '../geometry/thick_polyline.dart';

class ClassicPerimeterSettings {
  const ClassicPerimeterSettings({
    required this.wallLoops,
    required this.externalPerimeterWidth,
    required this.externalPerimeterSpacing,
    required this.perimeterWidth,
    required this.perimeterSpacing,
    this.externalNozzleDiameter,
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

  /// Source `ext_perimeter_flow.nozzle_diameter()`. It is required only when
  /// [detectThinWall] is enabled. The port deliberately does not guess this
  /// value from extrusion width because the C++ source does not do that.
  final double? externalNozzleDiameter;

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
    required this.thinWalls,
    required this.effectiveLoopCount,
  });

  final List<ClassicPerimeterLoop> loops;
  final List<ExPolygon2> innerRegion;

  /// Direct output of source `ExPolygon::medial_axis()` in source-coordinate
  /// units. Converting these to variable-width `ExtrusionPath`s is a separate
  /// source stage and is intentionally not folded into this shell result.
  final List<ThickPolyline2> thinWalls;

  final int effectiveLoopCount;
}

/// Ports the onion-shell / thin-wall portion of
/// `PerimeterGenerator::process_classic()`.
///
/// Source arithmetic is evaluated in the original integer `coord_t` domain
/// before deltas are passed through the millimeter-facing Clipper adapter.
/// This matters for truncation, the literal `- 1` safety coordinate and the
/// QIDI smaller-external-width branch.
class ClassicPerimeterShellGenerator {
  const ClassicPerimeterShellGenerator({
    this.clipper = const ClipperGeometry(),
  });

  static const double insetOverlapTolerance = 0.4;
  static const double smallerExternalInsetOverlapTolerance = 0.22;
  static const double narrowLoopLengthThreshold = 10;

  /// `ClipperSafetyOffset` from `ClipperUtils.hpp`, in scaled source units.
  static const double clipperSafetyOffset = 10;

  final ClipperGeometry clipper;

  ClassicPerimeterResult generate(
    List<ExPolygon2> surfaces,
    ClassicPerimeterSettings settings, {
    required int layerIndex,
  }) {
    _validate(settings);
    if (surfaces.isEmpty || settings.wallLoops <= 0) {
      return ClassicPerimeterResult(
        loops: const [],
        innerRegion: List.unmodifiable(surfaces),
        thinWalls: const [],
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
        thinWalls: const [],
        effectiveLoopCount: 0,
      );
    }

    // Literal source scaled values from `Flow::scaled_width/spacing()`.
    final perimeterSpacing = _scale(settings.perimeterSpacing);
    final extPerimeterWidth = _scale(settings.externalPerimeterWidth);
    final extPerimeterSpacing = _scale(settings.externalPerimeterSpacing);

    final extPerimeterSpacing2 = _scale(
      settings.preciseOuterWall && settings.innerOuterWallSequence
          ? 0.5 *
              (settings.externalPerimeterWidth + settings.perimeterWidth)
          : 0.5 *
              (settings.externalPerimeterSpacing + settings.perimeterSpacing),
    );

    // C++ converts these floating products back to coord_t by truncation.
    final minSpacing =
        (perimeterSpacing * (1 - insetOverlapTolerance)).truncate();
    final extMinSpacing =
        (extPerimeterSpacing * (1 - insetOverlapTolerance)).truncate();
    final extMinSpacingSmaller = (extPerimeterSpacing *
            (1 - smallerExternalInsetOverlapTolerance))
        .truncate();

    // Source first constructs a new Flow width and then calls scaled_width(),
    // which introduces another coord_t truncation before the /2 offset below.
    final smallerExternalWidth = (extPerimeterWidth -
            0.5 *
                smallerExternalInsetOverlapTolerance *
                extPerimeterSpacing)
        .truncate();

    var last = clipper.offsetExPolygons(surfaces, 0);
    final output = <ClassicPerimeterLoop>[];
    final thinWalls = <ThickPolyline2>[];
    var effectiveLoopNumber = requestedLoopNumber;

    for (var i = 0;; i++) {
      var offsets = <ExPolygon2>[];
      var smallerWidthOffsets = <ExPolygon2>[];

      if (i == 0) {
        if (settings.detectThinWall) {
          // Source:
          // offset2_ex(last,
          //   -(ext_width/2. + ext_min_spacing/2. - 1),
          //   +(ext_min_spacing/2. - 1));
          offsets = clipper.offset2Ex(
            last,
            _unscale(
              -(extPerimeterWidth / 2.0 + extMinSpacing / 2.0 - 1.0),
            ),
            _unscale(extMinSpacing / 2.0 - 1.0),
          );

          final nozzleDiameter = settings.externalNozzleDiameter!;
          final minWidth = _scale(nozzleDiameter / 3.0);

          // `offset()` returns polygons in C++; geometry is represented here as
          // ExPolygons and flattened with source contour/hole winding before
          // `diff_ex`, preserving the same non-zero fill geometry.
          final grownOffsets = clipper.offsetExPolygons(
            offsets,
            _unscale(extPerimeterWidth / 2.0 + clipperSafetyOffset),
          );
          final thinArea = clipper.differenceEx(
            _flatten(last),
            _flatten(grownOffsets),
          );
          final openedThinArea = clipper.openingEx(
            thinArea,
            _unscale(minWidth / 2.0),
          );

          for (final expolygon in openedThinArea) {
            final result = SourceExPolygonMedialAxis2.buildThick(
              expolygon: _toSourceExPolygon(expolygon),
              minWidth: minWidth.toDouble(),
              maxWidth: (extPerimeterWidth + extPerimeterSpacing2).toDouble(),
            );
            thinWalls.addAll(result.polylines);
          }
        } else {
          for (final expolygon in last) {
            final narrowProbe = clipper.offset2Ex(
              [expolygon],
              _unscale(
                -(extPerimeterWidth / 2.0 +
                    extMinSpacingSmaller / 2.0),
              ),
              _unscale(extMinSpacingSmaller / 2.0),
            );

            // Source compares scaled area against
            // `(ext_width + ext_min_spacing_smaller) * scale_(10mm)`.
            final useSmallerWidth = narrowProbe.isEmpty &&
                _scaledArea(expolygon) <
                    (extPerimeterWidth + extMinSpacingSmaller) *
                        _scale(narrowLoopLengthThreshold.toDouble());

            if (useSmallerWidth) {
              smallerWidthOffsets.addAll(
                clipper.offsetExPolygon(
                  expolygon,
                  _unscale(-smallerExternalWidth / 2.0),
                ),
              );
            } else {
              offsets.addAll(
                clipper.offsetExPolygon(
                  expolygon,
                  _unscale(-extPerimeterWidth / 2.0),
                ),
              );
            }
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
        final distance = i == 1 ? extPerimeterSpacing2 : perimeterSpacing;
        offsets = clipper.offset2Ex(
          last,
          _unscale(-(distance + minSpacing / 2.0 - 1.0)),
          _unscale(minSpacing / 2.0 - 1.0),
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

      // Exact source behavior is `last = std::move(offsets)`. The QIDI
      // smaller-width outer loops are output loops only and are deliberately
      // NOT fed back into subsequent inner-perimeter generation.
      last = offsets;
    }

    return ClassicPerimeterResult(
      loops: List.unmodifiable(output),
      innerRegion: List.unmodifiable(last),
      thinWalls: List.unmodifiable(thinWalls),
      effectiveLoopCount: effectiveLoopNumber + 1,
    );
  }

  ExPolygon2 _largest(List<ExPolygon2> polygons) =>
      polygons.reduce((a, b) => a.area >= b.area ? a : b);

  List<Polygon2> _flatten(List<ExPolygon2> expolygons) => [
        for (final expolygon in expolygons) ...[
          expolygon.contour,
          ...expolygon.holes,
        ],
      ];

  SourceExPolygon2 _toSourceExPolygon(ExPolygon2 value) => SourceExPolygon2(
        contour: _toSourcePolygon(value.contour),
        holes: [for (final hole in value.holes) _toSourcePolygon(hole)],
      );

  SourcePolygon2 _toSourcePolygon(Polygon2 value) => SourcePolygon2(
        value.points.map(
          (point) => SourcePoint2(
            _recoverClipperCoord(point.x),
            _recoverClipperCoord(point.y),
          ),
        ),
      );

  int _recoverClipperCoord(double millimeters) =>
      (millimeters / Slic3rUnits.scalingFactor).round();

  int _scale(double millimeters) => Slic3rUnits.scaleTruncated(millimeters);

  double _unscale(num sourceCoordinate) =>
      sourceCoordinate.toDouble() * Slic3rUnits.scalingFactor;

  double _scaledArea(ExPolygon2 value) =>
      value.area /
      (Slic3rUnits.scalingFactor * Slic3rUnits.scalingFactor);

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
    if (settings.detectThinWall &&
        (settings.externalNozzleDiameter == null ||
            settings.externalNozzleDiameter! <= 0)) {
      throw ArgumentError(
        'externalNozzleDiameter must be > 0 when detectThinWall is enabled; '
        'the source uses ext_perimeter_flow.nozzle_diameter() directly.',
      );
    }
  }
}
