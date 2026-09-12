import 'dart:typed_data';

import '../geometry/clipper_geometry.dart';
import '../geometry/expolygon.dart';
import '../geometry/point.dart';
import '../geometry/polygon.dart';
import '../geometry/source_arc_fitter.dart';
import '../geometry/source_geometry.dart';
import '../geometry/source_medial_axis.dart';
import '../geometry/source_polygon.dart';
import '../geometry/thick_polyline.dart';
import 'extrusion_covered_geometry.dart';
import 'extrusion_entity.dart';
import 'flow.dart';
import 'variable_width.dart';

class ClassicPerimeterSettings {
  const ClassicPerimeterSettings({
    required this.wallLoops,
    required this.externalPerimeterWidth,
    required this.externalPerimeterSpacing,
    required this.perimeterWidth,
    required this.perimeterSpacing,
    this.externalPerimeterFlow,
    this.solidInfillFlow,
    this.hasGapFill = false,
    this.filterOutGapFill = 0,
    this.surfaceSimplifyResolution = 0,
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

  /// Source `ext_perimeter_flow`. Classic thin-wall generation uses this same
  /// object twice: its nozzle diameter defines `min_width = nozzle / 3`, then
  /// the resulting ThickPolylines are passed to `variable_width()` with the
  /// complete flow to construct extrusion entities.
  final Flow? externalPerimeterFlow;

  /// Source `solid_infill_flow`, consumed by classic gap-fill
  /// `variable_width(..., erGapFill, solid_infill_flow, ...)`.
  final Flow? solidInfillFlow;

  /// Source `has_gap_fill` gate.
  final bool hasGapFill;

  /// Source `filter_out_gap_fill` configuration value in millimeters.
  final double filterOutGapFill;

  /// Source surface simplification resolution in millimeters. It is scaled to
  /// `coord_t` before the exact `Polygon::douglas_peucker()` sequence.
  final double surfaceSimplifyResolution;

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
    required this.thinWallExtrusions,
    required this.gapFillPolylines,
    required this.gapFillExtrusions,
    required this.effectiveLoopCount,
  });

  final List<ClassicPerimeterLoop> loops;
  final List<ExPolygon2> innerRegion;

  /// Direct output of source `ExPolygon::medial_axis()` in source-coordinate
  /// units. Kept as explicit evidence even though the source consumer stage is
  /// now represented by [thinWallExtrusions].
  final List<ThickPolyline2> thinWalls;

  /// Source `variable_width(thin_walls, erExternalPerimeter,
  /// ext_perimeter_flow, ...)` output. The later source chaining / recursive
  /// loop traversal stage is intentionally not claimed here yet.
  final List<ExtrusionEntity2> thinWallExtrusions;

  /// Source ThickPolylines produced by the classic gap-fill medial axis after
  /// opening, maximum-width removal, simplification and length filtering.
  final List<ThickPolyline2> gapFillPolylines;

  /// Source `variable_width(..., erGapFill, solid_infill_flow, ...)` output.
  final List<ExtrusionEntity2> gapFillExtrusions;

  final int effectiveLoopCount;
}

/// Ports the onion-shell / thin-wall / gap-fill portion of
/// `PerimeterGenerator::process_classic()`.
///
/// Source arithmetic is evaluated in the original integer `coord_t` domain
/// before deltas are passed through the millimeter-facing Clipper adapter.
/// This matters for truncation, explicit `float(...)` casts, the literal
/// safety-coordinate offsets, and the QIDI smaller-external-width branch.
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
        thinWallExtrusions: const [],
        gapFillPolylines: const [],
        gapFillExtrusions: const [],
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
        thinWallExtrusions: const [],
        gapFillPolylines: const [],
        gapFillExtrusions: const [],
        effectiveLoopCount: 0,
      );
    }

    // Literal source scaled values from `Flow::scaled_width/spacing()`.
    final perimeterWidth = _scale(settings.perimeterWidth);
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
    final gaps = <ExPolygon2>[];
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

          final externalFlow = settings.externalPerimeterFlow!;
          final minWidth = _scale(externalFlow.nozzleDiameter / 3.0);

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

        // Source deliberately looks for gaps before testing whether this extra
        // onion-shell iteration is beyond the requested perimeter count.
        if (settings.hasGapFill) {
          final firstGapSide = clipper.offsetExPolygons(
            last,
            _unscale(_float32(-0.5 * distance)),
          );
          final secondGapSide = clipper.offsetExPolygons(
            offsets,
            _unscale(
              _float32(0.5 * distance + clipperSafetyOffset),
            ),
          );
          gaps.addAll(clipper.differenceEx(
            _flatten(firstGapSide),
            _flatten(secondGapSide),
          ));
        }
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

    final thinWallExtrusions = <ExtrusionEntity2>[];
    if (thinWalls.isNotEmpty) {
      const SourceVariableWidth2().variableWidth(
        thinWalls,
        ExtrusionRole.externalPerimeter,
        settings.externalPerimeterFlow!,
        thinWallExtrusions,
      );
    }

    final gapFillPolylines = <ThickPolyline2>[];
    final gapFillExtrusions = <ExtrusionEntity2>[];
    if (settings.hasGapFill && gaps.isNotEmpty) {
      // Source:
      // min = 0.2 * perimeter_width * (1 - INSET_OVERLAP_TOLERANCE)
      // max = 2 * perimeter_spacing
      final minGapWidth =
          0.2 * perimeterWidth * (1 - insetOverlapTolerance);
      final maxGapWidth = 2.0 * perimeterSpacing;

      final opened = clipper.openingEx(
        gaps,
        _unscale(_float32(minGapWidth / 2.0)),
      );
      final tooWide = clipper.offset2Ex(
        gaps,
        _unscale(_float32(-maxGapWidth / 2.0)),
        _unscale(
          _float32(maxGapWidth / 2.0 + clipperSafetyOffset),
        ),
      );
      final gapRegions = clipper.differenceEx(
        _flatten(opened),
        _flatten(tooWide),
      );

      final simplifyTolerance =
          _scale(settings.surfaceSimplifyResolution).toDouble();
      for (final expolygon in gapRegions) {
        var source = _toSourceExPolygon(expolygon);
        if (simplifyTolerance > 0) {
          source = _douglasPeucker(source, simplifyTolerance);
        }
        if (source.contour.points.length < 3) continue;

        final medial = SourceExPolygonMedialAxis2.buildThick(
          expolygon: source,
          minWidth: minGapWidth,
          maxWidth: maxGapWidth,
        );
        gapFillPolylines.addAll(medial.polylines);
      }

      final minimumLength = _scale(settings.filterOutGapFill).toDouble();
      gapFillPolylines.removeWhere(
        (polyline) => polyline.length < minimumLength,
      );

      if (gapFillPolylines.isNotEmpty) {
        const SourceVariableWidth2().variableWidth(
          gapFillPolylines,
          ExtrusionRole.gapFill,
          settings.solidInfillFlow!,
          gapFillExtrusions,
        );

        if (gapFillExtrusions.isNotEmpty && last.isNotEmpty) {
          final covered = gapFillExtrusions.polygonsCoveredByWidth(
            scaledEpsilon: clipperSafetyOffset,
            clipper: clipper,
          );
          last = clipper.differenceEx(
            _flatten(last),
            [for (final polygon in covered) _toMillimeterPolygon(polygon)],
          );
        }
      }
    }

    return ClassicPerimeterResult(
      loops: List.unmodifiable(output),
      innerRegion: List.unmodifiable(last),
      thinWalls: List.unmodifiable(thinWalls),
      thinWallExtrusions: List.unmodifiable(thinWallExtrusions),
      gapFillPolylines: List.unmodifiable(gapFillPolylines),
      gapFillExtrusions: List.unmodifiable(gapFillExtrusions),
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

  Polygon2 _toMillimeterPolygon(SourcePolygon2 value) => Polygon2([
        for (final point in value.points)
          Point2(
            point.x * Slic3rUnits.scalingFactor,
            point.y * Slic3rUnits.scalingFactor,
          ),
      ]);

  SourceExPolygon2 _douglasPeucker(
    SourceExPolygon2 value,
    double tolerance,
  ) =>
      SourceExPolygon2(
        contour: _douglasPeuckerPolygon(value.contour, tolerance),
        holes: [
          for (final hole in value.holes)
            _douglasPeuckerPolygon(hole, tolerance),
        ],
      );

  SourcePolygon2 _douglasPeuckerPolygon(
    SourcePolygon2 value,
    double tolerance,
  ) {
    if (value.points.isEmpty) return value;
    final closed = <SourcePoint2>[...value.points, value.points.first];
    final simplified = ArcFitter2.douglasPeucker(closed, tolerance);
    if (simplified.length > 1 && simplified.first == simplified.last) {
      simplified.removeLast();
    }
    return SourcePolygon2(simplified);
  }

  int _recoverClipperCoord(double millimeters) =>
      (millimeters / Slic3rUnits.scalingFactor).round();

  int _scale(double millimeters) => Slic3rUnits.scaleTruncated(millimeters);

  double _unscale(num sourceCoordinate) =>
      sourceCoordinate.toDouble() * Slic3rUnits.scalingFactor;

  double _scaledArea(ExPolygon2 value) =>
      value.area /
      (Slic3rUnits.scalingFactor * Slic3rUnits.scalingFactor);

  double _float32(double value) => Float32List.fromList([value]).first;

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
    if (settings.detectThinWall && settings.externalPerimeterFlow == null) {
      throw ArgumentError(
        'externalPerimeterFlow is required when detectThinWall is enabled; '
        'the source uses ext_perimeter_flow for both nozzle diameter and '
        'variable-width extrusion conversion.',
      );
    }
    if (settings.hasGapFill && settings.solidInfillFlow == null) {
      throw ArgumentError(
        'solidInfillFlow is required when hasGapFill is enabled; source gap '
        'fill converts MedialAxis ThickPolylines with solid_infill_flow.',
      );
    }
    if (settings.filterOutGapFill < 0 ||
        settings.surfaceSimplifyResolution < 0) {
      throw ArgumentError(
        'filterOutGapFill and surfaceSimplifyResolution must be >= 0',
      );
    }
  }
}
