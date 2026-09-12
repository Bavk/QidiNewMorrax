import 'dart:math' as math;
import 'dart:typed_data';

import '../geometry/clipper_geometry.dart';
import '../geometry/expolygon.dart';
import '../geometry/point.dart';
import '../geometry/polygon.dart';
import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import '../geometry/source_polyline.dart';

class _SourceBridgeDirection2 {
  _SourceBridgeDirection2(this.angle);

  final double angle;
  double coverage = 0;
  double maxLength = 0;
  double anchoredPercent = 0;
}

/// Direct source-shaped port of pinned `libslic3r/BridgeDetector.cpp`.
///
/// Geometry remains on the QIDI `coord_t` grid at every explicit source
/// rotation / line-generation boundary. Polygon booleans delegate to the
/// repository's Clipper compatibility layer, which round-trips through the
/// same 100000-units-per-mm integer grid.
class SourceBridgeDetector2 {
  SourceBridgeDetector2({
    required ExPolygon2 expolygon,
    required List<ExPolygon2> lowerSlices,
    required int spacingSource,
    this.clipper = const ClipperGeometry(),
  }) : this.fromExPolygons(
          expolygons: [expolygon],
          lowerSlices: lowerSlices,
          spacingSource: spacingSource,
          clipper: clipper,
        );

  SourceBridgeDetector2.fromExPolygons({
    required List<ExPolygon2> expolygons,
    required List<ExPolygon2> lowerSlices,
    required this.spacingSource,
    this.clipper = const ClipperGeometry(),
  })  : expolygons = List.unmodifiable(expolygons),
        lowerSlices = List.unmodifiable(lowerSlices) {
    if (spacingSource <= 0) {
      throw ArgumentError.value(
        spacingSource,
        'spacingSource',
        'must be > 0',
      );
    }
    _initialize();
  }

  final List<ExPolygon2> expolygons;
  final List<ExPolygon2> lowerSlices;
  final int spacingSource;
  final ClipperGeometry clipper;

  /// Source fixed brute-force step: five degrees.
  double resolution = math.pi / 36.0;

  /// Source output sentinel before successful detection.
  double angle = -1;

  List<SourcePolyline2> _edges = const [];
  List<ExPolygon2> _anchorRegions = const [];

  List<SourcePolyline2> get supportingEdges => List.unmodifiable(_edges);
  List<ExPolygon2> get anchorRegions => List.unmodifiable(_anchorRegions);

  void _initialize() {
    resolution = math.pi / 36.0;
    angle = -1;

    // `offset(expolygons, float(spacing))`.
    final grown = clipper.offsetExPolygons(
      expolygons,
      _unscale(_float32(spacingSource.toDouble())),
    );

    // Source intersects closed bridge boundaries as open polylines against
    // lower-slice *contours* only.
    final subjects = <SourcePolyline2>[];
    for (final polygon in _flatten(grown)) {
      final points = [for (final p in polygon.points) _toSourcePoint(p)];
      if (points.length >= 2) {
        subjects.add(SourcePolyline2([...points, points.first]));
      }
    }
    final lowerContours = [
      for (final expolygon in lowerSlices) _toSourcePolygon(expolygon.contour),
    ];
    _edges = List.unmodifiable(
      clipper.intersectionSourceOpenPolylines(subjects, lowerContours),
    );

    // `union_safety_offset(lower_slices)` is literally `offset(..., 10.f)`.
    final safetyLower = clipper.offsetExPolygons(
      lowerSlices,
      _unscale(_float32(Slic3rUnits.scaledEpsilon.toDouble())),
    );
    _anchorRegions = List.unmodifiable(
      clipper.intersectionEx(_flatten(grown), _flatten(safetyLower)),
    );
  }

  /// Pinned `BridgeDetector::detect_angle()`.
  bool detectAngle([double bridgeDirectionOverride = 0]) {
    if (_edges.isEmpty || _anchorRegions.isEmpty) return false;

    final candidates = <_SourceBridgeDirection2>[];
    if (bridgeDirectionOverride == 0) {
      for (final candidate in _bridgeDirectionCandidates()) {
        candidates.add(_SourceBridgeDirection2(candidate));
      }
    } else {
      candidates.add(_SourceBridgeDirection2(bridgeDirectionOverride));
    }

    final halfSpacing = _float32(0.5 * _float32(spacingSource.toDouble()));
    final clipArea = clipper.offsetExPolygons(
      expolygons,
      _unscale(halfSpacing),
    );
    final clipPolygons = _flatten(clipArea);
    final anchorSource = [for (final e in _anchorRegions) _toSourceExPolygon(e)];

    var haveCoverage = false;
    for (final candidate in candidates) {
      final bbox = _getExtentsRotated(_anchorRegions, -candidate.angle);
      if (bbox == null) continue;

      final lines = <SourceLine2>[];
      final s = math.sin(candidate.angle);
      final c = math.cos(candidate.angle);
      for (var y = bbox.minY; y <= bbox.maxY; y += spacingSource) {
        lines.add(
          SourceLine2(
            SourcePoint2(
              _cppRound(c * bbox.minX - s * y),
              _cppRound(c * y + s * bbox.minX),
            ),
            SourcePoint2(
              _cppRound(c * bbox.maxX - s * y),
              _cppRound(c * y + s * bbox.maxX),
            ),
          ),
        );
      }

      var totalLength = 0.0;
      var maxLength = 0.0;
      var anchoredLineCount = 0;
      final clippedLines = _intersectionLines(lines, clipPolygons);
      for (final line in clippedLines) {
        if (_expolygonsContain(anchorSource, line.a) &&
            _expolygonsContain(anchorSource, line.b)) {
          final length = line.length;
          totalLength += length;
          maxLength = math.max(maxLength, length);
          anchoredLineCount++;
        }
      }
      if (clippedLines.isNotEmpty && anchoredLineCount > 0) {
        candidate.anchoredPercent = anchoredLineCount / clippedLines.length;
      }
      if (totalLength == 0) continue;

      haveCoverage = true;
      candidate.coverage = totalLength;
      candidate.maxLength = maxLength;
    }

    if (!haveCoverage) return false;

    // Source comparator sorts only by decreasing coverage.
    candidates.sort((a, b) => b.coverage.compareTo(a.coverage));

    var best = 0;
    for (var i = 1;
        i < candidates.length &&
            candidates[best].coverage - candidates[i].coverage < spacingSource;
        i++) {
      if (candidates[i].maxLength < candidates[best].maxLength) best = i;
    }

    angle = candidates[best].angle;
    if (angle >= math.pi) angle -= math.pi;
    return true;
  }

  /// Pinned `BridgeDetector::coverage()`.
  List<Polygon2> coverage([double requestedAngle = -1]) {
    var useAngle = requestedAngle;
    if (useAngle == -1) useAngle = angle;
    if (useAngle == -1) return const [];

    final rotateToVertical = math.pi / 2.0 - useAngle;
    final anchors = [
      for (final polygon in _flatten(_anchorRegions))
        _rotatePolygonSource(polygon, rotateToVertical),
    ];

    final covered = <Polygon2>[];
    for (final sourceExPolygon in expolygons) {
      final rotated = _rotateExPolygonSource(sourceExPolygon, rotateToVertical);
      final expanded = clipper.offsetExPolygon(
        rotated,
        _unscale(
          _float32(0.5 * _float32(spacingSource.toDouble())),
        ),
      );

      for (final expoly in expanded) {
        for (final trapezoid in _getTrapezoids2(expoly)) {
          var supported = 0;
          final supportedLines = _intersectionLines(
            [for (final line in _toSourcePolygon(trapezoid).lines()) line],
            anchors,
          );
          for (final line in supportedLines) {
            if (line.length >= spacingSource) supported++;
          }
          if (supported >= 2) covered.add(trapezoid);
        }
      }
    }

    if (covered.isEmpty) return const [];

    // Unite before rotating back; source explicitly relies on this to avoid
    // tiny rotation gaps between neighboring trapezoids.
    final united = _flatten(clipper.unionEx(covered));
    final rotatedBack = [
      for (final polygon in united)
        _rotatePolygonSource(polygon, -rotateToVertical),
    ];
    final finalCoverage = clipper.intersectionEx(
      _flatten(expolygons),
      rotatedBack,
    );
    return List.unmodifiable(_flatten(finalCoverage));
  }

  List<double> _bridgeDirectionCandidates() {
    final angles = <double>[];
    for (var i = 0; i <= math.pi / resolution; i++) {
      angles.add(i * resolution);
    }

    for (final expolygon in expolygons) {
      final source = _toSourceExPolygon(expolygon);
      for (final line in source.lines()) {
        angles.add(line.direction);
      }
    }

    for (final edge in _edges) {
      if (edge.points.length >= 2 && edge.firstPoint != edge.lastPoint) {
        angles.add(SourceLine2(edge.firstPoint, edge.lastPoint).direction);
      }
    }

    angles.sort();
    const minResolution = math.pi / 180.0;
    var i = 1;
    while (i < angles.length) {
      if (_directionsParallel(angles[i], angles[i - 1], minResolution)) {
        angles.removeAt(i);
      } else {
        i++;
      }
    }
    if (angles.length > 1 &&
        _directionsParallel(angles.first, angles.last, minResolution)) {
      angles.removeLast();
    }
    return angles;
  }

  List<Polygon2> _getTrapezoids2(ExPolygon2 expolygon) {
    final sourcePolygons = [
      _toSourcePolygon(expolygon.contour),
      for (final hole in expolygon.holes) _toSourcePolygon(hole),
    ];
    final points = [for (final polygon in sourcePolygons) ...polygon.points];
    if (points.isEmpty) return const [];

    var minX = points.first.x;
    var minY = points.first.y;
    var maxX = points.first.x;
    var maxY = points.first.y;
    final xx = <int>[];
    for (final point in points) {
      minX = math.min(minX, point.x);
      minY = math.min(minY, point.y);
      maxX = math.max(maxX, point.x);
      maxY = math.max(maxY, point.y);
      xx.add(point.x);
    }
    xx.sort();

    final result = <Polygon2>[];
    for (var i = 0; i + 1 < xx.length; i++) {
      final x = xx[i];
      final nextX = xx[i + 1];
      if (x == nextX) continue;
      final rectangle = _toMillimeterPolygon(
        SourcePolygon2([
          SourcePoint2(x, minY),
          SourcePoint2(nextX, minY),
          SourcePoint2(nextX, maxY),
          SourcePoint2(x, maxY),
        ]),
      );
      result.addAll(
        _flatten(
          clipper.intersectionEx(
            [rectangle],
            [for (final p in sourcePolygons) _toMillimeterPolygon(p)],
          ),
        ),
      );
    }
    return result;
  }

  List<SourceLine2> _intersectionLines(
    List<SourceLine2> lines,
    List<Polygon2> clipPolygons,
  ) {
    if (lines.isEmpty || clipPolygons.isEmpty) return const [];
    final polylines = clipper.intersectionSourceOpenPolylines(
      [
        for (final line in lines) SourcePolyline2([line.a, line.b]),
      ],
      [for (final polygon in clipPolygons) _toSourcePolygon(polygon)],
    );
    return List.unmodifiable([
      for (final polyline in polylines) ...polyline.lines(),
    ]);
  }

  _SourceBounds2? _getExtentsRotated(
    List<ExPolygon2> values,
    double rotation,
  ) {
    SourcePoint2? first;
    var minX = 0;
    var minY = 0;
    var maxX = 0;
    var maxY = 0;
    final s = math.sin(rotation);
    final c = math.cos(rotation);

    // Source `get_extents_rotated(ExPolygon)` uses only the contour; holes
    // cannot enlarge an ExPolygon's bounds.
    for (final value in values) {
      for (final point in value.contour.points) {
        final source = _toSourcePoint(point);
        final x = _cppRound(c * source.x - s * source.y);
        final y = _cppRound(c * source.y + s * source.x);
        if (first == null) {
          first = source;
          minX = maxX = x;
          minY = maxY = y;
        } else {
          minX = math.min(minX, x);
          minY = math.min(minY, y);
          maxX = math.max(maxX, x);
          maxY = math.max(maxY, y);
        }
      }
    }
    if (first == null) return null;
    return _SourceBounds2(minX, minY, maxX, maxY);
  }

  bool _expolygonsContain(
    List<SourceExPolygon2> values,
    SourcePoint2 point,
  ) {
    for (final value in values) {
      if (!value.contour.contains(point)) continue;
      var inHole = false;
      for (final hole in value.holes) {
        if (hole.contains(point, borderResult: false)) {
          inHole = true;
          break;
        }
      }
      if (!inHole) return true;
    }
    return false;
  }

  bool _directionsParallel(double a, double b, double maxDiff) {
    final diff = (a - b).abs();
    final tolerance = maxDiff + Slic3rUnits.epsilon;
    return diff < tolerance || (diff - math.pi).abs() < tolerance;
  }

  ExPolygon2 _rotateExPolygonSource(ExPolygon2 value, double rotation) =>
      ExPolygon2(
        contour: _rotatePolygonSource(value.contour, rotation),
        holes: [
          for (final hole in value.holes) _rotatePolygonSource(hole, rotation),
        ],
      );

  Polygon2 _rotatePolygonSource(Polygon2 value, double rotation) =>
      _toMillimeterPolygon(
        SourcePolygon2([
          for (final point in value.points)
            _toSourcePoint(point).rotated(rotation),
        ]),
      );

  SourceExPolygon2 _toSourceExPolygon(ExPolygon2 value) => SourceExPolygon2(
        contour: _toSourcePolygon(value.contour),
        holes: [for (final hole in value.holes) _toSourcePolygon(hole)],
      );

  SourcePolygon2 _toSourcePolygon(Polygon2 value) => SourcePolygon2([
        for (final point in value.points) _toSourcePoint(point),
      ]);

  SourcePoint2 _toSourcePoint(Point2 value) => SourcePoint2(
        (value.x / Slic3rUnits.scalingFactor).round(),
        (value.y / Slic3rUnits.scalingFactor).round(),
      );

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

  int _cppRound(double value) =>
      value >= 0 ? (value + 0.5).floor() : (value - 0.5).ceil();

  double _float32(double value) => Float32List.fromList([value]).first;

  double _unscale(double sourceValue) =>
      sourceValue * Slic3rUnits.scalingFactor;
}

class _SourceBounds2 {
  const _SourceBounds2(this.minX, this.minY, this.maxX, this.maxY);

  final int minX;
  final int minY;
  final int maxX;
  final int maxY;
}
