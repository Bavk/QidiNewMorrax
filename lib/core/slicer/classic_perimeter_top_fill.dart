import 'dart:math' as math;
import 'dart:typed_data';

import '../geometry/clipper_geometry.dart';
import '../geometry/expolygon.dart';
import '../geometry/point.dart';
import '../geometry/polygon.dart';
import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';

class SourceClassicTopFillSettings2 {
  const SourceClassicTopFillSettings2({
    required this.wallLoops,
    required this.externalPerimeterWidthMm,
    required this.externalPerimeterSpacingMm,
    required this.perimeterWidthMm,
    required this.perimeterSpacingMm,
    required this.sparseInfillLineWidthMm,
    required this.topAreaThresholdPercent,
    this.hasGapFill = false,
  });

  /// Source `config->wall_loops.value`. This is intentionally separate from
  /// `loop_number`, which may also include extra-perimeter policy.
  final int wallLoops;
  final double externalPerimeterWidthMm;
  final double externalPerimeterSpacingMm;
  final double perimeterWidthMm;
  final double perimeterSpacingMm;
  final double sparseInfillLineWidthMm;
  final double topAreaThresholdPercent;
  final bool hasGapFill;
}

class SourceClassicTopFillResult2 {
  const SourceClassicTopFillResult2({
    required this.applied,
    required this.last,
    required this.topFills,
    required this.fillClip,
    required this.tempGap,
    required this.innerPolygons,
    required this.bridgeChecker,
    required this.bridgeMerged,
    required this.offsetTopSurfaceSource,
    required this.minWidthTopSurfaceSource,
    required this.finalFillClipDeltaSource,
  });

  /// Whether the pinned `i == 0 && i != loop_number && Alltop && upper_slices`
  /// branch was entered.
  final bool applied;

  /// Source `last` after the branch, before the next classic shell iteration.
  final List<ExPolygon2> last;
  final List<ExPolygon2> topFills;
  final List<ExPolygon2> fillClip;
  final List<ExPolygon2> tempGap;
  final List<ExPolygon2> innerPolygons;
  final List<ExPolygon2> bridgeChecker;
  final bool bridgeMerged;

  final int offsetTopSurfaceSource;
  final double minWidthTopSurfaceSource;
  final double finalFillClipDeltaSource;
}

/// Ports the pinned `TopOneWallType::Alltop` producer inside
/// `PerimeterGenerator::process_classic()`.
///
/// This is deliberately the producer only: it creates source `top_fills`,
/// `fill_clip` and the mutated `last` geometry consumed by the already-ported
/// final fill-boundary block. It does not pretend to replace the surrounding
/// classic shell loop yet, because the source executes this branch immediately
/// after the first perimeter offset and the following iteration may still
/// reduce `loop_number`.
class SourceClassicTopFillAllTop2 {
  const SourceClassicTopFillAllTop2({
    this.clipper = const ClipperGeometry(),
  });

  final ClipperGeometry clipper;

  SourceClassicTopFillResult2 produce({
    required List<ExPolygon2> last,
    required int loopNumber,
    required SourceClassicTopFillSettings2 settings,
    required List<Polygon2>? upperSlices,
    List<Polygon2>? lowerSlices,
  }) {
    _validate(settings, loopNumber);

    // Source gate at i == 0:
    // i != loop_number && top_one_wall_type == Alltop && upper_slices != NULL.
    // This helper already represents i == 0 and Alltop, therefore only the
    // remaining two conditions are visible here. If `last` is empty the source
    // shell would have broken before reaching this branch.
    if (loopNumber <= 0 || upperSlices == null || last.isEmpty) {
      return SourceClassicTopFillResult2(
        applied: false,
        last: List.unmodifiable(last),
        topFills: const [],
        fillClip: const [],
        tempGap: const [],
        innerPolygons: const [],
        bridgeChecker: const [],
        bridgeMerged: false,
        offsetTopSurfaceSource: 0,
        minWidthTopSurfaceSource: 0,
        finalFillClipDeltaSource: 0,
      );
    }

    final externalWidth = _scale(settings.externalPerimeterWidthMm);
    final externalSpacing = _scale(settings.externalPerimeterSpacingMm);
    final perimeterWidth = _scale(settings.perimeterWidthMm);
    final perimeterSpacing = _scale(settings.perimeterSpacingMm);

    // Preserve the source scale -> unscaled -> 1.5 -> scale sequence rather
    // than algebraically cancelling it. The final assignment is coord_t
    // truncation.
    var offsetTopSurface = _scale(
      1.5 *
          (settings.wallLoops == 0
              ? 0.0
              : _unscale(
                  externalWidth +
                      perimeterSpacing * (settings.wallLoops - 1),
                )),
    );
    final innerWallSpan = settings.wallLoops <= 1
        ? 0
        : perimeterSpacing * (settings.wallLoops - 1);
    if (offsetTopSurface > 0.9 * innerWallSpan) {
      offsetTopSurface -= (0.9 * innerWallSpan).truncate();
    } else {
      offsetTopSurface = 0;
    }

    final minWidthTopSurface =
        (settings.topAreaThresholdPercent / 100.0) *
            math.max(externalSpacing / 2.0, perimeterWidth / 2.0);

    final bounds = _boundsOf(last).inflated(Slic3rUnits.scaledEpsilon);
    final upperClipped = _clipPolygonsWithSubjectBounds(upperSlices, bounds);

    // Source `offset(Polygons, float delta)` has an explicit float boundary.
    final upperGrown = clipper.offsetPolygonsEx(
      upperClipped,
      _unscale(_float32(minWidthTopSurface)),
    );

    // Source virtual second-perimeter clip.
    var fillClip = clipper.offsetExPolygons(
      last,
      _unscale(_float32(-externalSpacing.toDouble())),
    );

    var topPolygons = _differenceWithSafety(
      last,
      _flatten(upperGrown),
    );
    final tempGap = clipper.differenceEx(
      _flatten(topPolygons),
      _flatten(fillClip),
    );

    final innerClipDelta = offsetTopSurface +
        minWidthTopSurface -
        (externalSpacing ~/ 2).toDouble();
    final grownTopPolygons = clipper.offsetExPolygons(
      topPolygons,
      _unscale(_float32(innerClipDelta)),
    );
    var innerPolygons = _differenceWithSafety(
      last,
      _flatten(grownTopPolygons),
    );

    var bridgeChecker = <ExPolygon2>[];
    var bridgeMerged = false;
    if (lowerSlices != null) {
      final lowerClipped = _clipPolygonsWithSubjectBounds(lowerSlices, bounds);
      final unsupported = _differenceWithSafety(last, lowerClipped);
      final bridgeOffset = math.max(
        externalSpacing.toDouble(),
        perimeterWidth.toDouble(),
      );
      bridgeChecker = clipper.offsetExPolygons(
        unsupported,
        _unscale(_float32(1.5 * bridgeOffset)),
      );

      if (bridgeChecker.isNotEmpty &&
          clipper
              .intersectionEx(
                _flatten(bridgeChecker),
                _flatten(innerPolygons),
              )
              .isNotEmpty) {
        innerPolygons = clipper.unionEx([
          ..._flatten(innerPolygons),
          ..._flatten(bridgeChecker),
        ]);
        bridgeMerged = true;
      }
    }

    topPolygons = _differenceWithSafety(
      fillClip,
      _flatten(innerPolygons),
    );
    final topFills = clipper.unionEx(_flatten(topPolygons));

    // `scale_` is a macro returning double here; unlike source coord_t values,
    // sparse_infill_line_width is not truncated before the subtraction.
    final sparseHalfScaled =
        (settings.sparseInfillLineWidthMm / 2.0) /
            Slic3rUnits.scalingFactor;
    final finalFillClipDelta =
        (externalSpacing ~/ 2).toDouble() - sparseHalfScaled;
    fillClip = clipper.offsetExPolygons(
      last,
      _unscale(_float32(finalFillClipDelta)),
    );

    var updatedLast = clipper.intersectionEx(
      _flatten(innerPolygons),
      _flatten(last),
    );
    if (settings.hasGapFill) {
      updatedLast = clipper.unionEx([
        ..._flatten(updatedLast),
        ..._flatten(tempGap),
      ]);
    }

    return SourceClassicTopFillResult2(
      applied: true,
      last: List.unmodifiable(updatedLast),
      topFills: List.unmodifiable(topFills),
      fillClip: List.unmodifiable(fillClip),
      tempGap: List.unmodifiable(tempGap),
      innerPolygons: List.unmodifiable(innerPolygons),
      bridgeChecker: List.unmodifiable(bridgeChecker),
      bridgeMerged: bridgeMerged,
      offsetTopSurfaceSource: offsetTopSurface,
      minWidthTopSurfaceSource: minWidthTopSurface,
      finalFillClipDeltaSource: finalFillClipDelta,
    );
  }

  /// Source `ApplySafetyOffset::Yes` grows every clip path by
  /// `ClipperSafetyOffset == 10.f` before difference. The existing Clipper
  /// adapter unions valid oriented polygon offsets before the difference;
  /// for the represented normalized slice geometry this is equivalent to the
  /// source non-zero clip region while retaining the exact 10-unit boundary.
  List<ExPolygon2> _differenceWithSafety(
    List<ExPolygon2> subject,
    List<Polygon2> clip,
  ) {
    if (subject.isEmpty) return const [];
    if (clip.isEmpty) {
      return clipper.differenceEx(_flatten(subject), const []);
    }
    final safetyClip = clipper.offsetPolygonsEx(
      clip,
      _unscale(_float32(10.0)),
    );
    return clipper.differenceEx(
      _flatten(subject),
      _flatten(safetyClip),
    );
  }

  List<Polygon2> _clipPolygonsWithSubjectBounds(
    List<Polygon2> input,
    _SourceBounds2 bounds,
  ) {
    final output = <Polygon2>[];
    for (final polygon in input) {
      final source = SourcePolygon2([
        for (final point in polygon.points)
          SourcePoint2(
            _recoverClipperCoord(point.x),
            _recoverClipperCoord(point.y),
          ),
      ]);
      final clipped = _clipPolygonWithSubjectBounds(source, bounds);
      if (clipped.points.isNotEmpty) {
        output.add(_toMillimeterPolygon(clipped));
      }
    }
    return List.unmodifiable(output);
  }

  /// Literal port of `clip_clipper_polygon_with_subject_bbox_templ()` used by
  /// this source branch. It is an optimization clip, not a geometric rectangle
  /// intersection: vertices that cannot affect clipping inside [bounds] are
  /// discarded while crossing/corner candidates are retained.
  SourcePolygon2 _clipPolygonWithSubjectBounds(
    SourcePolygon2 source,
    _SourceBounds2 bounds,
  ) {
    final points = source.points;
    if (points.length < 3) return SourcePolygon2(const []);

    int sides(SourcePoint2 point) {
      var value = 0;
      if (point.x < bounds.minX) value += 1; // Left
      if (point.x > bounds.maxX) value += 2; // Right
      if (point.y > bounds.maxY) value += 4; // Top
      if (point.y < bounds.minY) value += 8; // Bottom
      return value;
    }

    final output = <SourcePoint2>[];
    var sidesPrev = sides(points.last);
    var sidesThis = sides(points.first);
    final lastIndex = points.length - 1;
    for (var i = 0; i < lastIndex; i++) {
      final sidesNext = sides(points[i + 1]);
      if (sidesThis == 0 ||
          (sidesPrev & sidesThis & sidesNext) == 0) {
        output.add(points[i]);
        sidesPrev = sidesThis;
      }
      sidesThis = sidesNext;
    }

    if (output.isNotEmpty) {
      final sidesNext = sides(output.first);
      if (sidesThis == 0 ||
          (sidesPrev & sidesThis & sidesNext) == 0) {
        output.add(points.last);
      }
    }

    return SourcePolygon2(output);
  }

  _SourceBounds2 _boundsOf(List<ExPolygon2> expolygons) {
    SourcePoint2? first;
    var minX = 0;
    var minY = 0;
    var maxX = 0;
    var maxY = 0;
    for (final expolygon in expolygons) {
      for (final polygon in [expolygon.contour, ...expolygon.holes]) {
        for (final point in polygon.points) {
          final source = SourcePoint2(
            _recoverClipperCoord(point.x),
            _recoverClipperCoord(point.y),
          );
          if (first == null) {
            first = source;
            minX = maxX = source.x;
            minY = maxY = source.y;
          } else {
            minX = math.min(minX, source.x);
            minY = math.min(minY, source.y);
            maxX = math.max(maxX, source.x);
            maxY = math.max(maxY, source.y);
          }
        }
      }
    }
    if (first == null) {
      throw StateError('source top-fill bounds require non-empty last geometry');
    }
    return _SourceBounds2(minX, minY, maxX, maxY);
  }

  List<Polygon2> _flatten(List<ExPolygon2> expolygons) => [
        for (final expolygon in expolygons) ...[
          expolygon.contour,
          ...expolygon.holes,
        ],
      ];

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
    SourceClassicTopFillSettings2 settings,
    int loopNumber,
  ) {
    if (loopNumber < -1) {
      throw ArgumentError.value(loopNumber, 'loopNumber', 'must be >= -1');
    }
    if (settings.wallLoops < 0) {
      throw ArgumentError.value(
        settings.wallLoops,
        'wallLoops',
        'must be >= 0',
      );
    }
    for (final value in [
      settings.externalPerimeterWidthMm,
      settings.externalPerimeterSpacingMm,
      settings.perimeterWidthMm,
      settings.perimeterSpacingMm,
    ]) {
      if (!value.isFinite || value <= 0) {
        throw ArgumentError('resolved perimeter widths/spacings must be > 0');
      }
    }
    if (!settings.sparseInfillLineWidthMm.isFinite ||
        settings.sparseInfillLineWidthMm < 0 ||
        !settings.topAreaThresholdPercent.isFinite ||
        settings.topAreaThresholdPercent < 0) {
      throw ArgumentError(
        'sparse infill width and top-area threshold must be finite and >= 0',
      );
    }
  }
}

class _SourceBounds2 {
  const _SourceBounds2(this.minX, this.minY, this.maxX, this.maxY);

  final int minX;
  final int minY;
  final int maxX;
  final int maxY;

  _SourceBounds2 inflated(int amount) => _SourceBounds2(
        minX - amount,
        minY - amount,
        maxX + amount,
        maxY + amount,
      );
}