import 'dart:typed_data';

import '../geometry/clipper_geometry.dart';
import '../geometry/expolygon.dart';
import '../geometry/point.dart';
import '../geometry/polygon.dart';
import '../geometry/source_arc_fitter.dart';
import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import 'classic_perimeter.dart' show ClassicPerimeterShellGenerator;
import 'surface.dart';

/// Source `ConfigOptionFloatOrPercent` value semantics required by
/// `PerimeterGenerator::process_classic()` infill-wall overlap.
class SourceFloatOrPercent2 {
  const SourceFloatOrPercent2.absolute(this.value) : percent = false;
  const SourceFloatOrPercent2.percent(this.value) : percent = true;

  final double value;
  final bool percent;

  double getAbsValue(double ratioOver) =>
      percent ? ratioOver * value / 100.0 : value;
}

class SourceClassicFillBoundarySettings2 {
  const SourceClassicFillBoundarySettings2({
    required this.externalPerimeterSpacingMm,
    required this.perimeterSpacingMm,
    required this.solidInfillSpacingMm,
    required this.infillWallOverlap,
    this.surfaceSimplifyResolutionMm = 0,
  });

  final double externalPerimeterSpacingMm;
  final double perimeterSpacingMm;
  final double solidInfillSpacingMm;
  final SourceFloatOrPercent2 infillWallOverlap;
  final double surfaceSimplifyResolutionMm;
}

class SourceClassicFillBoundaryResult2 {
  const SourceClassicFillBoundaryResult2({
    required this.fillSurfaces,
    required this.fillNoOverlap,
    required this.insetSource,
    required this.infillPerimeterOverlapSource,
    required this.minPerimeterInfillSpacingSource,
  });

  final List<Surface2> fillSurfaces;
  final List<SourceExPolygon2> fillNoOverlap;

  /// Final source `inset` after subtracting resolved infill-wall overlap.
  final int insetSource;
  final int infillPerimeterOverlapSource;
  final int minPerimeterInfillSpacingSource;
}

/// Ports the final classic `process_classic()` block that converts the
/// remaining `last` geometry into `fill_surfaces` and `fill_no_overlap`.
///
/// The helper deliberately accepts the already-produced `last`, `top_fills`
/// and `fill_clip` geometry. Top-one-wall discovery itself is a preceding
/// source branch and remains outside this scoped helper.
class SourceClassicFillBoundary2 {
  const SourceClassicFillBoundary2({
    this.clipper = const ClipperGeometry(),
  });

  final ClipperGeometry clipper;

  SourceClassicFillBoundaryResult2 build({
    required List<ExPolygon2> last,
    required int effectiveLoopCount,
    required SourceClassicFillBoundarySettings2 settings,
    List<ExPolygon2> topFills = const [],
    List<ExPolygon2> fillClip = const [],
  }) {
    _validate(settings, effectiveLoopCount);

    final externalSpacing = _scale(settings.externalPerimeterSpacingMm);
    final perimeterSpacing = _scale(settings.perimeterSpacingMm);
    final solidInfillSpacing = _scale(settings.solidInfillSpacingMm);

    // Source loop_number is zero based. No generated perimeter means -1.
    final loopNumber = effectiveLoopCount - 1;
    var inset = loopNumber < 0
        ? 0
        : loopNumber == 0
            ? externalSpacing ~/ 2
            : perimeterSpacing ~/ 2;

    var infillPerimeterOverlap = 0;
    if (inset > 0) {
      final ratioOverMm =
          _unscale(inset + solidInfillSpacing ~/ 2);
      infillPerimeterOverlap = _scale(
        settings.infillWallOverlap.getAbsValue(ratioOverMm),
      );
      inset -= infillPerimeterOverlap;
    }

    final notFilled = _simplifiedUnion(
      last,
      _scale(settings.surfaceSimplifyResolutionMm).toDouble(),
    );
    final minPerimeterInfillSpacing =
        (solidInfillSpacing *
                (1.0 - ClassicPerimeterShellGenerator.insetOverlapTolerance))
            .truncate();

    final halfMin = minPerimeterInfillSpacing / 2.0;
    var infill = clipper.offset2Ex(
      notFilled,
      _unscale(_float32(-inset - halfMin)),
      _unscale(_float32(halfMin)),
    );

    // Source computes this even when top_fills is empty.
    final topInfill = clipper.intersectionEx(
      _flatten(fillClip),
      _flatten(
        clipper.offsetExPolygons(
          topFills,
          _unscale((externalSpacing ~/ 2).toDouble()),
        ),
      ),
    );
    if (topFills.isNotEmpty) {
      final grownTopInfill = clipper.offsetExPolygons(
        topInfill,
        _unscale(infillPerimeterOverlap.toDouble()),
      );
      infill = clipper.unionEx([
        ..._flatten(infill),
        ..._flatten(grownTopInfill),
      ]);
    }

    final fillSurfaces = <Surface2>[
      for (final expolygon in infill)
        Surface2(
          surfaceType: SurfaceType.internal,
          expolygon: _toSourceExPolygon(expolygon),
        ),
    ];

    List<ExPolygon2> noOverlap;
    if (minPerimeterInfillSpacing ~/ 2 > infillPerimeterOverlap) {
      // Preserve the source's subtle numeric boundary: the first half uses
      // `/ 2.` (double), while the second uses integer `/ 2` before subtracting
      // the coord_t overlap.
      noOverlap = clipper.offset2Ex(
        notFilled,
        _unscale(_float32(-inset - halfMin)),
        _unscale(
          _float32(
            (minPerimeterInfillSpacing ~/ 2) - infillPerimeterOverlap,
          ),
        ),
      );
    } else {
      noOverlap = clipper.offsetExPolygons(
        notFilled,
        _unscale((-inset - infillPerimeterOverlap).toDouble()),
      );
    }
    if (topFills.isNotEmpty) {
      noOverlap = clipper.unionEx([
        ..._flatten(noOverlap),
        ..._flatten(topInfill),
      ]);
    }

    return SourceClassicFillBoundaryResult2(
      fillSurfaces: List.unmodifiable(fillSurfaces),
      fillNoOverlap: List.unmodifiable([
        for (final expolygon in noOverlap) _toSourceExPolygon(expolygon),
      ]),
      insetSource: inset,
      infillPerimeterOverlapSource: infillPerimeterOverlap,
      minPerimeterInfillSpacingSource: minPerimeterInfillSpacing,
    );
  }

  List<ExPolygon2> _simplifiedUnion(
    List<ExPolygon2> input,
    double toleranceSource,
  ) {
    if (input.isEmpty) return const [];

    final polygons = <Polygon2>[];
    for (final expolygon in input) {
      final source = _toSourceExPolygon(expolygon);
      for (final polygon in [source.contour, ...source.holes]) {
        final simplified = _simplifyClosedPolygon(polygon, toleranceSource);
        if (simplified.points.length >= 3) {
          polygons.add(_toMillimeterPolygon(simplified));
        }
      }
    }
    return clipper.unionEx(polygons);
  }

  SourcePolygon2 _simplifyClosedPolygon(
    SourcePolygon2 polygon,
    double tolerance,
  ) {
    if (polygon.points.length < 3 || tolerance <= 0) return polygon;
    final closed = <SourcePoint2>[...polygon.points, polygon.points.first];
    final simplified = ArcFitter2.douglasPeucker(closed, tolerance);
    if (simplified.length > 1 && simplified.first == simplified.last) {
      simplified.removeLast();
    }
    return SourcePolygon2(simplified);
  }

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

  int _recoverClipperCoord(double millimeters) =>
      (millimeters / Slic3rUnits.scalingFactor).round();

  int _scale(double millimeters) =>
      Slic3rUnits.scaleTruncated(millimeters);

  double _unscale(num sourceCoordinate) =>
      sourceCoordinate.toDouble() * Slic3rUnits.scalingFactor;

  double _float32(num value) =>
      Float32List.fromList([value.toDouble()]).first;

  void _validate(
    SourceClassicFillBoundarySettings2 settings,
    int effectiveLoopCount,
  ) {
    if (effectiveLoopCount < 0) {
      throw ArgumentError.value(
        effectiveLoopCount,
        'effectiveLoopCount',
        'must be >= 0',
      );
    }
    if (!settings.externalPerimeterSpacingMm.isFinite ||
        settings.externalPerimeterSpacingMm <= 0 ||
        !settings.perimeterSpacingMm.isFinite ||
        settings.perimeterSpacingMm <= 0 ||
        !settings.solidInfillSpacingMm.isFinite ||
        settings.solidInfillSpacingMm <= 0) {
      throw ArgumentError('all source fill spacings must be finite and > 0');
    }
    if (!settings.surfaceSimplifyResolutionMm.isFinite ||
        settings.surfaceSimplifyResolutionMm < 0 ||
        !settings.infillWallOverlap.value.isFinite ||
        settings.infillWallOverlap.value < 0) {
      throw ArgumentError(
        'simplify resolution and infill wall overlap must be finite and >= 0',
      );
    }
  }
}
