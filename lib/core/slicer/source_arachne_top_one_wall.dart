import 'dart:math' as math;

import 'package:clipper2/clipper2.dart' as c2;

import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import 'source_arachne_wall_tool_paths_prepare.dart';

class SourceArachneTopOneWallDecision2 {
  const SourceArachneTopOneWallDecision2({
    required this.enabled,
    required this.top,
    required this.shrunkArea,
    required this.originalArea,
    required this.minimumTopWidth,
  });

  final bool enabled;
  final List<SourcePolygon2> top;
  final double shrunkArea;
  final double originalArea;
  final double minimumTopWidth;
}

class SourceArachneBounds2 {
  const SourceArachneBounds2({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  final int minX;
  final int minY;
  final int maxX;
  final int maxY;

  SourceArachneBounds2 inflated(int delta) => SourceArachneBounds2(
        minX: minX - delta,
        minY: minY - delta,
        maxX: maxX + delta,
        maxY: maxY + delta,
      );
}

/// Source helpers used by the `TopOneWallType::Alltop` Arachne branch.
class SourceArachneTopOneWall2 {
  const SourceArachneTopOneWall2._();

  static SourceArachneBounds2 bounds(Iterable<SourcePolygon2> polygons) {
    SourcePoint2? first;
    for (final polygon in polygons) {
      if (polygon.points.isNotEmpty) {
        first = polygon.points.first;
        break;
      }
    }
    if (first == null) {
      throw ArgumentError('Pinned get_extents requires non-empty polygons');
    }

    var minX = first.x;
    var minY = first.y;
    var maxX = first.x;
    var maxY = first.y;
    for (final polygon in polygons) {
      for (final point in polygon.points) {
        minX = math.min(minX, point.x);
        minY = math.min(minY, point.y);
        maxX = math.max(maxX, point.x);
        maxY = math.max(maxY, point.y);
      }
    }
    return SourceArachneBounds2(
      minX: minX,
      minY: minY,
      maxX: maxX,
      maxY: maxY,
    );
  }

  /// Literal `ClipperUtils::clip_clipper_polygons_with_subject_bbox()`.
  /// This is a vertex-pruning optimization, not geometric rectangle clipping.
  static List<SourcePolygon2> clipWithSubjectBounds(
    Iterable<SourcePolygon2> polygons,
    SourceArachneBounds2 bounds,
  ) {
    final result = <SourcePolygon2>[];
    for (final polygon in polygons) {
      final clipped = _clipPolygonWithSubjectBounds(polygon, bounds);
      if (clipped.points.isNotEmpty) result.add(clipped);
    }
    return List.unmodifiable(result);
  }

  static List<SourcePolygon2> difference(
    Iterable<SourcePolygon2> subject,
    Iterable<SourcePolygon2> clip,
  ) =>
      _boolean(c2.ClipType.difference, subject, clip);

  static List<SourcePolygon2> intersection(
    Iterable<SourcePolygon2> subject,
    Iterable<SourcePolygon2> clip,
  ) =>
      _boolean(c2.ClipType.intersection, subject, clip);

  static List<SourcePolygon2> union(
    Iterable<SourcePolygon2> subject,
  ) =>
      SourceArachneWallToolPathsPrepare2.unionNonZero(subject);

  /// Direct `PerimeterGenerator::should_enable_top_one_wall()`.
  static SourceArachneTopOneWallDecision2 shouldEnable({
    required List<SourcePolygon2> originalPolygons,
    required List<SourcePolygon2> top,
    required int perimeterWidth,
    required int extPerimeterSpacing,
    required double topAreaThresholdPercent,
  }) {
    final minimumTopWidth = (topAreaThresholdPercent / 100.0) *
        math.max(extPerimeterSpacing / 2.0, perimeterWidth / 2.0);
    final shrunkTop = SourceArachneWallToolPathsPrepare2.offsetPolygons(
      top,
      -minimumTopWidth,
    );
    final shrunkArea = _regionArea(shrunkTop);
    final originalArea = _regionArea(originalPolygons);
    final oneMillimeter = Slic3rUnits.scaleTruncated(1.0);

    if (shrunkArea / (originalArea + Slic3rUnits.epsilon) < 0.1 ||
        originalArea < oneMillimeter * oneMillimeter) {
      return SourceArachneTopOneWallDecision2(
        enabled: false,
        top: const [],
        shrunkArea: shrunkArea,
        originalArea: originalArea,
        minimumTopWidth: minimumTopWidth,
      );
    }

    final expanded = SourceArachneWallToolPathsPrepare2.offsetPolygons(
      shrunkTop,
      minimumTopWidth + perimeterWidth,
    );
    return SourceArachneTopOneWallDecision2(
      enabled: expanded.isNotEmpty,
      top: List.unmodifiable(expanded),
      shrunkArea: shrunkArea,
      originalArea: originalArea,
      minimumTopWidth: minimumTopWidth,
    );
  }

  static SourcePolygon2 _clipPolygonWithSubjectBounds(
    SourcePolygon2 polygon,
    SourceArachneBounds2 bounds,
  ) {
    final source = polygon.points;
    if (source.length < 3) return SourcePolygon2(const []);

    int sides(SourcePoint2 point) {
      var result = 0;
      if (point.x < bounds.minX) result += 1; // Left
      if (point.x > bounds.maxX) result += 2; // Right
      if (point.y > bounds.maxY) result += 4; // Top
      if (point.y < bounds.minY) result += 8; // Bottom
      return result;
    }

    var sidesPrevious = sides(source.last);
    var sidesThis = sides(source.first);
    final output = <SourcePoint2>[];
    final last = source.length - 1;
    for (var index = 0; index < last; index++) {
      final sidesNext = sides(source[index + 1]);
      if (sidesThis == 0 ||
          (sidesPrevious & sidesThis & sidesNext) == 0) {
        output.add(source[index]);
        sidesPrevious = sidesThis;
      }
      sidesThis = sidesNext;
    }

    if (output.isNotEmpty) {
      final sidesNext = sides(output.first);
      if (sidesThis == 0 ||
          (sidesPrevious & sidesThis & sidesNext) == 0) {
        output.add(source.last);
      }
    }
    return SourcePolygon2(output);
  }

  static List<SourcePolygon2> _boolean(
    c2.ClipType type,
    Iterable<SourcePolygon2> subject,
    Iterable<SourcePolygon2> clip,
  ) {
    final subjectPaths = _toPaths(subject);
    if (subjectPaths.isEmpty) return const [];
    final clipPaths = _toPaths(clip);
    if (clipPaths.isEmpty) {
      return type == c2.ClipType.intersection
          ? const []
          : SourceArachneWallToolPathsPrepare2.unionNonZero(subject);
    }

    final clipper = c2.Clipper64()
      ..addSubjects(subjectPaths)
      ..addClips(clipPaths);
    final solution = clipper.execute(type, c2.FillRule.nonZero);
    if (solution == null) return const [];
    return List.unmodifiable([
      for (final path in solution.closed)
        if (path.length >= 3)
          SourcePolygon2([
            for (final point in path) SourcePoint2(point.x, point.y),
          ]),
    ]);
  }

  static c2.Paths64 _toPaths(Iterable<SourcePolygon2> polygons) => [
        for (final polygon in polygons)
          if (polygon.points.length >= 3)
            [
              for (final point in polygon.points) c2.Point64(point.x, point.y),
            ],
      ];

  static double _regionArea(Iterable<SourcePolygon2> polygons) {
    final normalized =
        SourceArachneWallToolPathsPrepare2.unionNonZero(polygons);
    return normalized.fold<double>(
      0,
      (sum, polygon) => sum + polygon.signedArea,
    );
  }
}
