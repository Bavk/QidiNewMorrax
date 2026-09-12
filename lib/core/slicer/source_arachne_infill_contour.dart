import 'dart:typed_data';

import '../geometry/clipper_geometry.dart';
import '../geometry/expolygon.dart';
import '../geometry/point.dart';
import '../geometry/polygon.dart';
import '../geometry/source_arc_fitter.dart';
import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import 'classic_perimeter.dart' show ClassicPerimeterShellGenerator;
import 'classic_perimeter_fill_boundary.dart' show SourceFloatOrPercent2;
import 'surface.dart';

class SourceArachneInfillContourSettings2 {
  const SourceArachneInfillContourSettings2({
    required this.externalPerimeterSpacingSource,
    required this.perimeterSpacingSource,
    required this.solidInfillSpacingSource,
    required this.spacingSource,
    required this.surfaceSimplifyResolutionSource,
    required this.infillWallOverlap,
  });

  final int externalPerimeterSpacingSource;
  final int perimeterSpacingSource;
  final int solidInfillSpacingSource;

  /// Pinned caller passes external mixed spacing for a single generated wall,
  /// otherwise the regular perimeter spacing.
  final int spacingSource;
  final int surfaceSimplifyResolutionSource;
  final SourceFloatOrPercent2 infillWallOverlap;
}

class SourceArachneInfillContourResult2 {
  const SourceArachneInfillContourResult2({
    required this.fillSurfaces,
    required this.fillNoOverlap,
    required this.resolvedInsertSource,
    required this.minPerimeterInfillSpacingSource,
    required this.filteredOutAsTooSmall,
  });

  final List<Surface2> fillSurfaces;
  final List<SourceExPolygon2> fillNoOverlap;
  final int resolvedInsertSource;
  final int minPerimeterInfillSpacingSource;
  final bool filteredOutAsTooSmall;
}

/// Direct port of pinned
/// `PerimeterGenerator::add_infill_contour_for_arachne()`.
class SourceArachneInfillContour2 {
  const SourceArachneInfillContour2({
    this.clipper = const ClipperGeometry(),
  });

  final ClipperGeometry clipper;

  SourceArachneInfillContourResult2 build({
    required List<SourceExPolygon2> infillContour,
    required int loops,
    required bool isInnerPart,
    required SourceArachneInfillContourSettings2 settings,
  }) {
    _validate(settings);

    var contour = _toMillimeterExPolygons(infillContour);
    final halfSpacingSource = _f32(settings.spacingSource / 2.0);
    final shrunkenProbe = clipper.offsetExPolygons(
      contour,
      _unscale(-halfSpacingSource),
    );
    final filteredOut = shrunkenProbe.isEmpty;
    if (filteredOut) {
      contour = const [];
    }

    var insert = loops < 0 ? 0 : settings.externalPerimeterSpacingSource;
    if (isInnerPart || loops > 0) {
      insert = settings.perimeterSpacingSource;
    }
    insert = _scale(
      settings.infillWallOverlap.getAbsValue(_unscale(insert.toDouble())),
    );

    final simplifiedUnion = _simplifiedUnion(
      contour,
      settings.surfaceSimplifyResolutionSource.toDouble(),
    );
    final minPerimeterInfillSpacing =
        (settings.solidInfillSpacingSource *
                (1.0 - ClassicPerimeterShellGenerator.insetOverlapTolerance))
            .truncate();
    final halfMin = minPerimeterInfillSpacing / 2.0;

    final fill = clipper.offset2Ex(
      simplifiedUnion,
      _unscale(_f32(-halfMin)),
      _unscale(_f32(insert + halfMin)),
    );
    final noOverlap = clipper.offset2Ex(
      simplifiedUnion,
      _unscale(_f32(-halfMin)),
      _unscale(_f32(halfMin)),
    );

    return SourceArachneInfillContourResult2(
      fillSurfaces: List.unmodifiable([
        for (final expolygon in fill)
          Surface2(
            surfaceType: SurfaceType.internal,
            expolygon: _toSourceExPolygon(expolygon),
          ),
      ]),
      fillNoOverlap: List.unmodifiable([
        for (final expolygon in noOverlap) _toSourceExPolygon(expolygon),
      ]),
      resolvedInsertSource: insert,
      minPerimeterInfillSpacingSource: minPerimeterInfillSpacing,
      filteredOutAsTooSmall: filteredOut,
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

  List<ExPolygon2> _toMillimeterExPolygons(
    List<SourceExPolygon2> values,
  ) =>
      [
        for (final value in values)
          ExPolygon2(
            contour: _toMillimeterPolygon(value.contour),
            holes: [
              for (final hole in value.holes) _toMillimeterPolygon(hole),
            ],
          ),
      ];

  Polygon2 _toMillimeterPolygon(SourcePolygon2 value) => Polygon2([
        for (final point in value.points)
          Point2(
            point.x * Slic3rUnits.scalingFactor,
            point.y * Slic3rUnits.scalingFactor,
          ),
      ]);

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

  int _scale(double millimeters) =>
      Slic3rUnits.scaleTruncated(millimeters);

  double _unscale(num sourceCoordinate) =>
      sourceCoordinate.toDouble() * Slic3rUnits.scalingFactor;

  double _f32(num value) =>
      Float32List.fromList([value.toDouble()]).first;

  void _validate(SourceArachneInfillContourSettings2 settings) {
    if (settings.externalPerimeterSpacingSource <= 0 ||
        settings.perimeterSpacingSource <= 0 ||
        settings.solidInfillSpacingSource <= 0 ||
        settings.spacingSource <= 0 ||
        settings.surfaceSimplifyResolutionSource < 0 ||
        !settings.infillWallOverlap.value.isFinite ||
        settings.infillWallOverlap.value < 0) {
      throw ArgumentError('Invalid pinned Arachne infill-contour settings');
    }
  }
}
