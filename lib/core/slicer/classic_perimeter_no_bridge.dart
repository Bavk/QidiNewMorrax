import 'dart:math' as math;
import 'dart:typed_data';

import '../geometry/clipper_geometry.dart';
import '../geometry/expolygon.dart';
import '../geometry/point.dart';
import '../geometry/polygon.dart';
import '../geometry/source_arc_fitter.dart';
import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import 'source_bridge_detector.dart';
import 'surface.dart';

/// Pinned `CounterboreHoleBridgingOption` order from `PrintConfig.hpp`.
enum SourceCounterboreHoleBridging2 {
  none,
  bridges,
  filled,
}

class SourceClassicNoBridgeSettings2 {
  const SourceClassicNoBridgeSettings2({
    required this.mode,
    required this.perimeterSpacingMm,
    required this.externalPerimeterWidthMm,
    this.bridgeAngleDegrees = 0,
  });

  final SourceCounterboreHoleBridging2 mode;
  final double perimeterSpacingMm;
  final double externalPerimeterWidthMm;

  /// Source `bridge_angle`: zero delegates to BridgeDetector auto-selection.
  final double bridgeAngleDegrees;
}

class SourceClassicNoBridgeResult2 {
  const SourceClassicNoBridgeResult2({
    required this.surfaces,
    required this.fillSurfaces,
    required this.detectorCalls,
    required this.extractedBridgeRegions,
  });

  /// Source `all_surfaces` after in-place processing.
  final List<Surface2> surfaces;

  /// `stInternal` surfaces appended directly by `process_no_bridge()`.
  final List<Surface2> fillSurfaces;
  final int detectorCalls;
  final int extractedBridgeRegions;
}

/// Literal source-order port of the pinned
/// `PerimeterGenerator::process_no_bridge()` counterbore bridge pre-pass.
///
/// The input surface vector is copied with [Surface2.sourceCopy] first because
/// pinned `process_classic()` starts from `Surfaces all_surfaces =
/// this->slices->surfaces`. That intentionally preserves the supplied source's
/// copy-constructor quirk for QIDI compensation members.
class SourceClassicNoBridge2 {
  const SourceClassicNoBridge2({this.clipper = const ClipperGeometry()});

  static const double bridgeInfillMarginMm = 1.0;

  final ClipperGeometry clipper;

  SourceClassicNoBridgeResult2 process({
    required List<Surface2> surfaces,
    required SourceClassicNoBridgeSettings2 settings,
    List<ExPolygon2>? lowerSlices,
  }) {
    _validate(settings);

    final allSurfaces = [for (final surface in surfaces) Surface2.sourceCopy(surface)];
    final fillSurfaces = <Surface2>[];

    // Exact source gate: chbNone, null lower_slices and non-null empty lower
    // slices all bypass the algorithm.
    if (settings.mode == SourceCounterboreHoleBridging2.none ||
        lowerSlices == null ||
        lowerSlices.isEmpty) {
      return SourceClassicNoBridgeResult2(
        surfaces: List.unmodifiable(allSurfaces),
        fillSurfaces: const [],
        detectorCalls: 0,
        extractedBridgeRegions: 0,
      );
    }

    final perimeterSpacing = _scale(settings.perimeterSpacingMm);
    final extPerimeterWidth = _scale(settings.externalPerimeterWidthMm);
    final bridgedInfillMargin = _scale(bridgeInfillMarginMm).toDouble();
    final detectorAngle = settings.bridgeAngleDegrees * math.pi / 180.0;

    var detectorCalls = 0;
    var extractedBridgeRegions = 0;
    var surfaceIndex = 0;
    while (surfaceIndex < allSurfaces.length) {
      var surface = allSurfaces[surfaceIndex];
      var last = <ExPolygon2>[_toMillimeterExPolygon(surface.expolygon)];

      // `diff_ex(last, *lower_slices, ApplySafetyOffset::Yes)`.
      final unsupported = _differenceWithSafety(last, lowerSlices);
      if (unsupported.isNotEmpty) {
        // Remove small overhangs.
        var unsupportedFiltered = clipper.offset2Ex(
          unsupported,
          _unscale(-perimeterSpacing.toDouble()),
          _unscale(perimeterSpacing.toDouble()),
        );

        if (unsupportedFiltered.isNotEmpty) {
          // Extract useful supported part. The source explicitly uses the
          // safety offset here as well.
          final support = _differenceWithSafety(last, unsupported);
          if (unsupported.isNotEmpty) {
            final bridgeable = <ExPolygon2>[];
            for (final unsupportedIsland in unsupportedFiltered) {
              detectorCalls++;
              final detector = SourceBridgeDetector2(
                expolygon: unsupportedIsland,
                lowerSlices: support,
                spacingSource: perimeterSpacing,
                clipper: clipper,
              );
              if (detector.detectAngle(detectorAngle)) {
                final covered = clipper.unionEx(detector.coverage());
                bridgeable.addAll(covered);
              }
            }

            if (bridgeable.isNotEmpty) {
              switch (settings.mode) {
                case SourceCounterboreHoleBridging2.filled:
                  unsupportedFiltered = _filledBridgeRegions(
                    unsupportedFiltered: unsupportedFiltered,
                    bridgeable: bridgeable,
                    last: last,
                    allSurfaces: allSurfaces,
                    surfaceIndexRef: () => surfaceIndex,
                    setSurfaceIndex: (value) => surfaceIndex = value,
                    perimeterSpacing: perimeterSpacing,
                    bridgedInfillMargin: bridgedInfillMargin,
                  );
                  // `surface` may have moved when an earlier nested surface was
                  // erased. Refresh the source pointer equivalent.
                  if (surfaceIndex >= 0 && surfaceIndex < allSurfaces.length) {
                    surface = allSurfaces[surfaceIndex];
                  }
                  break;

                case SourceCounterboreHoleBridging2.bridges:
                  unsupportedFiltered = _bridgeOnlyRegions(
                    unsupportedFiltered: unsupportedFiltered,
                    bridgeable: bridgeable,
                    last: last,
                    perimeterSpacing: perimeterSpacing,
                    extPerimeterWidth: extPerimeterWidth,
                    bridgedInfillMargin: bridgedInfillMargin,
                  );
                  break;

                case SourceCounterboreHoleBridging2.none:
                  // Guarded above; retain source switch completeness.
                  unsupportedFiltered = const [];
                  break;
              }
            } else {
              unsupportedFiltered = const [];
            }
          }

          if (unsupportedFiltered.isNotEmpty) {
            extractedBridgeRegions += unsupportedFiltered.length;
            _appendInternal(fillSurfaces, unsupportedFiltered);

            // Store extraction into remaining surface shell.
            last = _differenceWithSafety(last, unsupportedFiltered);

            // Remove thin-air islands. The source assumes lower support will
            // itself be extruded and therefore emits unsupported leftovers
            // directly as internal fill.
            var i = 0;
            while (i < last.length) {
              final supportedPart = clipper.intersectionEx(
                _flatten([last[i]]),
                _flatten(support),
              );
              if (supportedPart.isEmpty) {
                _appendInternal(fillSurfaces, [last[i]]);
                last.removeAt(i);
              } else {
                i++;
              }
            }
          }
        }
      }

      if (last.isEmpty) {
        allSurfaces.removeAt(surfaceIndex);
        // Source decrements surface_idx so the for-loop increment revisits the
        // element shifted into this slot. A while-loop simply keeps the index.
        continue;
      }

      surface.expolygon = _toSourceExPolygon(last.first);
      for (var i = 1; i < last.length; i++) {
        allSurfaces.add(
          Surface2.sourceCopyWithExPolygon(
            surface,
            _toSourceExPolygon(last[i]),
          ),
        );
      }
      surfaceIndex++;
    }

    return SourceClassicNoBridgeResult2(
      surfaces: List.unmodifiable(allSurfaces),
      fillSurfaces: List.unmodifiable(fillSurfaces),
      detectorCalls: detectorCalls,
      extractedBridgeRegions: extractedBridgeRegions,
    );
  }

  List<ExPolygon2> _filledBridgeRegions({
    required List<ExPolygon2> unsupportedFiltered,
    required List<ExPolygon2> bridgeable,
    required List<ExPolygon2> last,
    required List<Surface2> allSurfaces,
    required int Function() surfaceIndexRef,
    required void Function(int) setSurfaceIndex,
    required int perimeterSpacing,
    required double bridgedInfillMargin,
  }) {
    final filtered = List<ExPolygon2>.of(unsupportedFiltered);
    var i = 0;
    while (i < filtered.length) {
      final polyUnsupp = filtered[i];
      final contourSimplified = _simplifyPolygon(
        polyUnsupp.contour,
        perimeterSpacing.toDouble(),
      );
      final contourBiggerEx = clipper.offsetPolygonsEx(
        [polyUnsupp.contour],
        _unscale(bridgedInfillMargin),
      );
      final contourBigger = _flatten(contourBiggerEx);

      ExPolygon2 polyUnsuppBigger = polyUnsupp;
      if (contourBigger.length == 1) {
        polyUnsuppBigger = ExPolygon2(
          contour: contourBigger.first,
          holes: polyUnsupp.holes,
        );
      }

      final convex = contourSimplified.length == 1 &&
          !_hasConcavePoint(contourSimplified.first);
      final hasBridge = clipper
          .intersectionEx(_flatten(bridgeable), _flatten([polyUnsupp]))
          .isNotEmpty;
      final bridgeGrowth = clipper.offsetExPolygons(
        bridgeable,
        _unscale(bridgedInfillMargin + perimeterSpacing / 2.0),
      );
      final containingRegion = clipper.unionEx([
        ..._flatten(last),
        ..._flatten(bridgeGrowth),
      ]);
      final entirelyContained = contourBigger.length == 1 &&
          _differenceWithSafety([polyUnsuppBigger], containingRegion).isEmpty;

      if (contourSimplified.length == 1 &&
          contourBigger.length == 1 &&
          convex &&
          hasBridge &&
          entirelyContained) {
        i++;
      } else {
        filtered.removeAt(i);
      }
    }

    final result = List<ExPolygon2>.of(
      clipper.intersectionEx(
        _flatten(last),
        _flatten(
          clipper.offset2Ex(
            filtered,
            _unscale(-perimeterSpacing / 2.0),
            _unscale(bridgedInfillMargin + perimeterSpacing / 2.0),
          ),
        ),
      ),
    );

    for (var resultIndex = 0; resultIndex < result.length; resultIndex++) {
      var expol = result[resultIndex];
      final newHoles = <Polygon2>[];

      var otherIndex = 0;
      while (otherIndex < allSurfaces.length) {
        final currentSurfaceIndex = surfaceIndexRef();
        if (otherIndex == currentSurfaceIndex) {
          otherIndex++;
          continue;
        }

        final other = _toMillimeterExPolygon(allSurfaces[otherIndex].expolygon);
        if (clipper
            .intersectionEx(_flatten([expol]), _flatten([other]))
            .isEmpty) {
          otherIndex++;
          continue;
        }

        final newPoly = clipper.offset2Ex(
          [other],
          _unscale(-bridgedInfillMargin - perimeterSpacing),
          _unscale(perimeterSpacing.toDouble()),
        );
        if (newPoly.length == 1) {
          allSurfaces[otherIndex].expolygon = _toSourceExPolygon(newPoly.first);
          newHoles.add(_makeClockwise(newPoly.first.contour));
          otherIndex++;
        } else {
          final original = allSurfaces[otherIndex];
          for (final split in newPoly) {
            allSurfaces.add(
              Surface2.sourceCopyWithExPolygon(
                original,
                _toSourceExPolygon(split),
              ),
            );
            newHoles.add(_makeClockwise(split.contour));
          }
          allSurfaces.removeAt(otherIndex);
          if (otherIndex < currentSurfaceIndex) {
            setSurfaceIndex(currentSurfaceIndex - 1);
          }
          // Source decrements surface_idx_other and then the loop increments it,
          // therefore inspect the replacement now occupying this slot.
        }
      }

      expol = ExPolygon2(contour: expol.contour, holes: newHoles);
      result[resultIndex] = expol;
    }

    return result;
  }

  List<ExPolygon2> _bridgeOnlyRegions({
    required List<ExPolygon2> unsupportedFiltered,
    required List<ExPolygon2> bridgeable,
    required List<ExPolygon2> last,
    required int perimeterSpacing,
    required int extPerimeterWidth,
    required double bridgedInfillMargin,
  }) {
    final bridgeableSimplified = <ExPolygon2>[];
    for (final poly in bridgeable) {
      bridgeableSimplified.addAll(
        _simplifyExPolygon(poly, perimeterSpacing.toDouble()),
      );
    }
    var bridgeableClosed = clipper.offset2Ex(
      bridgeableSimplified,
      _unscale(-extPerimeterWidth.toDouble()),
      _unscale(extPerimeterWidth.toDouble()),
    );

    var unbridgeable = [
      for (final expol in unsupportedFiltered)
        ExPolygon2(contour: expol.contour),
    ];
    unbridgeable = clipper.differenceEx(
      _flatten(unbridgeable),
      _flatten(bridgeableClosed),
    );
    unbridgeable = clipper.offset2Ex(
      unbridgeable,
      _unscale(-extPerimeterWidth * 2.0),
      _unscale(extPerimeterWidth * 2.0),
    );

    final candidateBridges = _differenceWithSafety(
      unsupportedFiltered,
      unbridgeable,
    );
    var bridgesTemp = clipper.offset2Ex(
      clipper.intersectionEx(_flatten(last), _flatten(candidateBridges)),
      _unscale(-extPerimeterWidth / 4.0),
      _unscale(extPerimeterWidth / 4.0),
    );

    final reference = List<ExPolygon2>.of(last);
    var offsetToDo = bridgedInfillMargin;
    unbridgeable = clipper.differenceEx(
      _flatten(unbridgeable),
      _flatten(
        clipper.offsetExPolygons(
          bridgesTemp,
          _unscale(extPerimeterWidth.toDouble()),
        ),
      ),
    );

    while (offsetToDo > extPerimeterWidth * 1.5) {
      unbridgeable = clipper.offset2Ex(
        unbridgeable,
        _unscale(-extPerimeterWidth / 4.0),
        _unscale(extPerimeterWidth * 2.25),
        joinType: PolygonJoinType.square,
      );
      bridgesTemp = clipper.differenceEx(
        _flatten(bridgesTemp),
        _flatten(unbridgeable),
      );
      bridgesTemp = clipper.offsetExPolygons(
        bridgesTemp,
        _unscale(extPerimeterWidth.toDouble()),
        joinType: PolygonJoinType.miter,
        miterLimit: 6.0,
      );
      unbridgeable = clipper.differenceEx(
        _flatten(unbridgeable),
        _flatten(
          clipper.offsetExPolygons(
            bridgesTemp,
            _unscale(extPerimeterWidth.toDouble()),
          ),
        ),
      );
      offsetToDo -= extPerimeterWidth;
    }

    unbridgeable = clipper.offsetExPolygons(
      unbridgeable,
      _unscale(extPerimeterWidth + offsetToDo),
      joinType: PolygonJoinType.square,
    );
    bridgesTemp = clipper.differenceEx(
      _flatten(bridgesTemp),
      _flatten(unbridgeable),
    );
    var result = clipper.offsetExPolygons(
      bridgesTemp,
      _unscale(offsetToDo),
    );
    result = clipper.intersectionEx(_flatten(result), _flatten(reference));
    return result;
  }

  List<Polygon2> _simplifyPolygon(Polygon2 polygon, double toleranceSource) {
    final source = _toSourcePolygon(polygon);
    if (source.points.length < 3) return const [];
    final closed = [...source.points, source.points.first];
    final simplified = ArcFitter2.douglasPeucker(closed, toleranceSource);
    if (simplified.length < 4) return const [];
    final open = simplified.sublist(0, simplified.length - 1);
    if (open.length < 3) return const [];
    return _flatten(
      clipper.unionEx([_toMillimeterPolygon(SourcePolygon2(open))]),
    );
  }

  List<ExPolygon2> _simplifyExPolygon(
    ExPolygon2 expolygon,
    double toleranceSource,
  ) {
    final polygons = <Polygon2>[];
    polygons.addAll(_simplifyPolygon(expolygon.contour, toleranceSource));
    for (final hole in expolygon.holes) {
      final simplified = _simplifyPolygon(hole.reversed(), toleranceSource);
      for (final polygon in simplified) {
        polygons.add(_makeClockwise(polygon));
      }
    }
    if (polygons.isEmpty) return const [];
    return clipper.unionEx(polygons);
  }

  bool _hasConcavePoint(Polygon2 polygon) {
    final source = _toSourcePolygon(polygon);
    final points = source.points;
    if (points.length < 3) return false;

    var current = points.last;
    final previous = points[points.length - 2];
    var v1x = current.x - previous.x;
    var v1y = current.y - previous.y;
    for (final next in points) {
      final v2x = next.x - current.x;
      final v2y = next.y - current.y;
      final cross = v1x.toDouble() * v2y - v1y.toDouble() * v2x;
      if (cross < 0) return true;
      v1x = v2x;
      v1y = v2y;
      current = next;
    }
    return false;
  }

  List<ExPolygon2> _differenceWithSafety(
    List<ExPolygon2> subject,
    List<ExPolygon2> clip,
  ) {
    if (subject.isEmpty) return const [];
    if (clip.isEmpty) return clipper.unionEx(_flatten(subject));
    final grownClip = clipper.offsetExPolygons(
      clip,
      _unscale(_float32(Slic3rUnits.scaledEpsilon.toDouble())),
    );
    return clipper.differenceEx(_flatten(subject), _flatten(grownClip));
  }

  void _appendInternal(List<Surface2> output, List<ExPolygon2> values) {
    for (final value in values) {
      output.add(
        Surface2(
          surfaceType: SurfaceType.internal,
          expolygon: _toSourceExPolygon(value),
        ),
      );
    }
  }

  Polygon2 _makeClockwise(Polygon2 polygon) =>
      polygon.isClockwise ? polygon : polygon.reversed();

  ExPolygon2 _toMillimeterExPolygon(SourceExPolygon2 value) => ExPolygon2(
        contour: _toMillimeterPolygon(value.contour),
        holes: [for (final hole in value.holes) _toMillimeterPolygon(hole)],
      );

  SourceExPolygon2 _toSourceExPolygon(ExPolygon2 value) => SourceExPolygon2(
        contour: _toSourcePolygon(value.contour),
        holes: [for (final hole in value.holes) _toSourcePolygon(hole)],
      );

  SourcePolygon2 _toSourcePolygon(Polygon2 value) => SourcePolygon2([
        for (final point in value.points)
          SourcePoint2(
            (point.x / Slic3rUnits.scalingFactor).round(),
            (point.y / Slic3rUnits.scalingFactor).round(),
          ),
      ]);

  Polygon2 _toMillimeterPolygon(SourcePolygon2 value) => Polygon2([
        for (final point in value.points)
          Point2(
            point.x * Slic3rUnits.scalingFactor,
            point.y * Slic3rUnits.scalingFactor,
          ),
      ]);

  List<Polygon2> _flatten(List<ExPolygon2> values) => [
        for (final value in values) ...[
          value.contour,
          ...value.holes,
        ],
      ];

  int _scale(double millimeters) => Slic3rUnits.scaleTruncated(millimeters);

  double _unscale(num sourceValue) =>
      sourceValue.toDouble() * Slic3rUnits.scalingFactor;

  double _float32(double value) => Float32List.fromList([value]).first;

  void _validate(SourceClassicNoBridgeSettings2 settings) {
    if (!settings.perimeterSpacingMm.isFinite ||
        settings.perimeterSpacingMm <= 0 ||
        !settings.externalPerimeterWidthMm.isFinite ||
        settings.externalPerimeterWidthMm <= 0 ||
        !settings.bridgeAngleDegrees.isFinite) {
      throw ArgumentError('resolved process_no_bridge settings are invalid');
    }
  }
}
