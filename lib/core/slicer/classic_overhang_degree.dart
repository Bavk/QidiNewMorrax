import 'dart:math' as math;
import 'dart:typed_data';

import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import '../geometry/source_polyline.dart';
import 'extrusion_entity.dart';

class SourceClassicDegreePolyline2 {
  SourceClassicDegreePolyline2(
    SourcePolyline2 polyline, {
    this.degree = 0,
  }) : polyline = polyline.copy();

  final SourcePolyline2 polyline;
  double degree;
}

class SourceClassicDegreeSplitLines2 {
  SourceClassicDegreeSplitLines2._({
    required this.start,
    required this.middle,
    required this.end,
  });

  factory SourceClassicDegreeSplitLines2.fromPolyline(
    SourcePolyline2 polyline, {
    required bool upsampling,
  }) {
    final length = polyline.length;
    if (length < 2 * SourceClassicOverhangDegree2.cutLength) {
      return SourceClassicDegreeSplitLines2._(
        start: <SourceClassicDegreePolyline2>[],
        middle: [SourceClassicDegreePolyline2(polyline)],
        end: <SourceClassicDegreePolyline2>[],
      );
    }

    var cutCount = math.min(
      (length / SourceClassicOverhangDegree2.cutLength).truncate(),
      upsampling ? SourceClassicOverhangDegree2.insertPointCount : 2,
    );
    final finalCutLength = math.min(
      polyline.length / cutCount,
      SourceClassicOverhangDegree2.cutLength,
    );
    final direction = polyline.lastPoint - polyline.firstPoint;

    // Source halves this integer before both the trim calculation and the
    // cut-polyline lambda execute.
    cutCount = cutCount ~/ 2;
    final trimLength = finalCutLength * cutCount;
    final middleLength = length - trimLength;
    final startPoint = SourceClassicOverhangDegree2._pointAlong(
      polyline.firstPoint,
      direction,
      trimLength / length,
    );
    final endPoint = SourceClassicOverhangDegree2._pointAlong(
      polyline.firstPoint,
      direction,
      (length - trimLength) / length,
    );

    List<SourceClassicDegreePolyline2> cutPolyline(
      double baseLength,
      SourcePoint2 firstPoint,
      SourcePoint2 lastPoint,
    ) {
      // The C++ lambda parameter is float even though callers pass double.
      final baseLengthF = SourceClassicOverhangDegree2._f32(baseLength);
      final output = <SourceClassicDegreePolyline2>[];
      var start = firstPoint;
      for (var count = 0; count < cutCount - 1; count++) {
        final t = ((count + 1) * SourceClassicOverhangDegree2.cutLength +
                baseLengthF) /
            length;
        final end = SourceClassicOverhangDegree2._pointAlong(
          firstPoint,
          direction,
          t,
        );
        output.add(SourceClassicDegreePolyline2(SourcePolyline2([start, end])));
        start = end;
      }
      output.add(
        SourceClassicDegreePolyline2(SourcePolyline2([start, lastPoint])),
      );
      return output;
    }

    return SourceClassicDegreeSplitLines2._(
      start: cutPolyline(0, polyline.firstPoint, startPoint),
      middle: [
        SourceClassicDegreePolyline2(SourcePolyline2([startPoint, endPoint])),
      ],
      end: cutPolyline(middleLength, endPoint, polyline.lastPoint),
    );
  }

  final List<SourceClassicDegreePolyline2> start;
  List<SourceClassicDegreePolyline2> middle;
  final List<SourceClassicDegreePolyline2> end;
}

/// Linear-search equivalent of QIDI `OverhangDistancer`.
///
/// The source uses an AABB tree only as an accelerator. Observable numeric
/// behavior retained here: the query point is first represented as `Vec2f`,
/// then promoted back to double for the distance calculation, and the final
/// distance is returned as float.
class SourceClassicOverhangDistancer2 {
  SourceClassicOverhangDistancer2(List<SourcePolygon2> layerPolygons)
      : _lines = [
          for (final polygon in layerPolygons) ...polygon.lines(),
        ];

  final List<SourceLine2> _lines;

  double distanceFromPerimeter(SourcePoint2 point) {
    if (_lines.isEmpty) return SourceClassicOverhangDegree2.floatMax;

    final px = SourceClassicOverhangDegree2._f32(point.x.toDouble());
    final py = SourceClassicOverhangDegree2._f32(point.y.toDouble());
    var bestSquared = double.infinity;
    for (final line in _lines) {
      final squared = _squaredDistanceToSegment(px, py, line);
      if (squared < bestSquared) bestSquared = squared;
    }
    return SourceClassicOverhangDegree2._f32(math.sqrt(bestSquared));
  }

  static double _squaredDistanceToSegment(
    double px,
    double py,
    SourceLine2 line,
  ) {
    final ax = line.a.x.toDouble();
    final ay = line.a.y.toDouble();
    final bx = line.b.x.toDouble();
    final by = line.b.y.toDouble();
    final vx = bx - ax;
    final vy = by - ay;
    final wx = px - ax;
    final wy = py - ay;
    final lengthSquared = vx * vx + vy * vy;
    if (lengthSquared == 0) return wx * wx + wy * wy;
    var t = (wx * vx + wy * vy) / lengthSquared;
    if (t < 0) t = 0;
    if (t > 1) t = 1;
    final dx = ax + t * vx - px;
    final dy = ay + t * vy - py;
    return dx * dx + dy * dy;
  }
}

/// Literal classic-path port of QIDI `OverhangDetector.cpp` degree helpers.
class SourceClassicOverhangDegree2 {
  const SourceClassicOverhangDegree2._();

  static const int overhangSamplingNumber = 6;
  static const double minDegreeGapClassic = 0.1;
  static const int maxOverhangDegree = overhangSamplingNumber - 1;
  static const int insertPointCount = 3;
  static const double cutLength = 60000;
  static const double floatMax = 3.4028234663852886e38;
  static const List<double> nonUniformDegreeMap = [0, 10, 25, 50, 75, 100];

  static double baseDegree(double degree, double degreeTrace) {
    final base = (degree / degreeTrace).truncate() * degreeTrace;
    return base >= maxOverhangDegree ? maxOverhangDegree.toDouble() : base;
  }

  static double mappedDegree(
    double overhangDistance,
    double lowerBound,
    double upperBound,
  ) {
    final thisDegree =
        (overhangDistance - lowerBound) / (upperBound - lowerBound) * 100;
    var terraced = 0.0;
    if (thisDegree >= 100) {
      terraced = maxOverhangDegree.toDouble();
    } else if (thisDegree > Slic3rUnits.epsilon * 100) {
      var upperIndex = 0;
      while (upperIndex < nonUniformDegreeMap.length &&
          nonUniformDegreeMap[upperIndex] <= thisDegree) {
        upperIndex++;
      }
      final lowerIndex = upperIndex - 1;
      final t = (thisDegree - nonUniformDegreeMap[lowerIndex]) /
          (nonUniformDegreeMap[upperIndex] -
              nonUniformDegreeMap[lowerIndex]);
      terraced = (1 - t) * lowerIndex + t * upperIndex;
    }
    return terraced;
  }

  static List<SourceClassicDegreeSplitLines2> prepareSplitPolylines(
    SourcePolyline2 polyline,
  ) {
    if (polyline.points.length == 2) {
      return [
        SourceClassicDegreeSplitLines2.fromPolyline(
          polyline,
          upsampling: true,
        ),
      ];
    }

    final output = <SourceClassicDegreeSplitLines2>[];
    for (var i = 0; i + 1 < polyline.points.length; i++) {
      output.add(SourceClassicDegreeSplitLines2.fromPolyline(
        SourcePolyline2([polyline.points[i], polyline.points[i + 1]]),
        upsampling: false,
      ));
    }
    return output;
  }

  static List<SourceClassicDegreePolyline2> gradePolyline({
    required SourcePolyline2 polyline,
    required SourceClassicOverhangDistancer2 distancer,
    required double lowerBound,
    required double upperBound,
  }) {
    final splitLines = prepareSplitPolylines(polyline);
    final output = <SourceClassicDegreePolyline2>[];

    void checkOverhang(List<SourceClassicDegreePolyline2> lines) {
      for (final line in lines) {
        final a = line.polyline.firstPoint;
        final b = line.polyline.lastPoint;
        final midpoint = SourcePoint2((a.x + b.x) ~/ 2, (a.y + b.y) ~/ 2);
        final distance = distancer.distanceFromPerimeter(midpoint);
        line.degree = mappedDegree(distance, lowerBound, upperBound);
      }
    }

    for (final split in splitLines) {
      if (split.start.isEmpty) {
        checkOverhang(split.middle);
      } else {
        checkOverhang(split.start);
        checkOverhang(split.end);
      }
      _smoothDegrees(split);
      output
        ..addAll(split.start)
        ..addAll(split.middle)
        ..addAll(split.end);
    }

    return _mergeWithDegree(output);
  }

  static List<ExtrusionPath2> detect({
    required List<SourcePolygon2> lowerPolygons,
    required List<SourcePolyline2> middleOverhangPolylines,
    required ExtrusionRole role,
    required double extrusionMm3PerMm,
    required double extrusionWidth,
    required double layerHeight,
    required double lowerBound,
    required double upperBound,
  }) {
    final distancer = SourceClassicOverhangDistancer2(lowerPolygons);
    final paths = <ExtrusionPath2>[];
    for (final polyline in middleOverhangPolylines) {
      final graded = gradePolyline(
        polyline: polyline,
        distancer: distancer,
        lowerBound: lowerBound,
        upperBound: upperBound,
      );
      for (final segment in graded) {
        paths.add(ExtrusionPath2(
          polyline: segment.polyline,
          overhangDegree: segment.degree,
          curveDegree: 0,
          role: role,
          mm3PerMm: extrusionMm3PerMm,
          width: extrusionWidth,
          height: layerHeight,
        ));
      }
    }
    return paths;
  }

  static void _smoothDegrees(SourceClassicDegreeSplitLines2 lines) {
    if (lines.start.isEmpty || lines.middle.isEmpty) return;

    final d1 = lines.start.last.degree;
    final d2 = lines.end.first.degree;
    final middle = lines.middle.first.polyline;
    if (middle.length < 2 * cutLength ||
        (d2 - d1).abs() < minDegreeGapClassic) {
      lines.middle.first.degree = (d2 + d1) / 2;
      return;
    }

    final length = middle.length;
    final lengthCut = (length / cutLength).truncate();
    final degreeCut =
        ((d2 - d1).abs() / minDegreeGapClassic / 0.6).truncate();
    final count = math.min(lengthCut, degreeCut);
    final cutGap = length / count;
    final degreeGap = (d2 - d1) / count;
    final direction = middle.lastPoint - middle.firstPoint;
    var start = middle.firstPoint;
    final output = <SourceClassicDegreePolyline2>[];

    for (var index = 0; index < count - 1; index++) {
      final t = (index + 1) * cutGap / length;
      final end = _pointAlong(middle.firstPoint, direction, t);
      output.add(SourceClassicDegreePolyline2(
        SourcePolyline2([start, end]),
        degree: d1 + (index + 1) * degreeGap,
      ));
      start = end;
    }
    output.add(SourceClassicDegreePolyline2(
      SourcePolyline2([start, middle.lastPoint]),
      degree: d1 + count * degreeGap,
    ));
    lines.middle = output;
  }

  static List<SourceClassicDegreePolyline2> _mergeWithDegree(
    List<SourceClassicDegreePolyline2> input,
  ) {
    final output = <SourceClassicDegreePolyline2>[];
    var merged = SourcePolyline2();
    var degreeBase = -1.0;

    for (final item in input) {
      final degree = baseDegree(item.degree, minDegreeGapClassic);
      if (!merged.isEmpty && degreeBase != degree) {
        output.add(SourceClassicDegreePolyline2(merged, degree: degreeBase));
        merged = SourcePolyline2();
      }
      degreeBase = degree;
      merged.appendPolyline(item.polyline);
    }

    if (!merged.isEmpty) {
      output.add(SourceClassicDegreePolyline2(merged, degree: degreeBase));
    }
    return output;
  }

  /// `Point dir` is non-const at both source call sites (`SplitLines` and
  /// `smoothing_degrees`), so `dir * t` resolves to the member operator and
  /// constructs Point(double,double), which uses C `lrint` (ties-to-even).
  static SourcePoint2 _pointAlong(
    SourcePoint2 first,
    SourcePoint2 direction,
    double ratio,
  ) =>
      SourcePoint2(
        first.x + _lrint(direction.x * ratio),
        first.y + _lrint(direction.y * ratio),
      );

  static int _lrint(double value) {
    final lower = value.floor();
    final fraction = value - lower;
    if (fraction < 0.5) return lower;
    if (fraction > 0.5) return lower + 1;
    return lower.isEven ? lower : lower + 1;
  }

  static double _f32(double value) {
    final storage = Float32List(1)..[0] = value;
    return storage[0];
  }
}
