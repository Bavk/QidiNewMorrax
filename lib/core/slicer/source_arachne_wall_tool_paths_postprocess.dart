import 'dart:math' as math;

import 'package:clipper2/clipper2.dart' as c2;

import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import 'source_arachne_extrusion_line.dart';
import 'source_arachne_extrusion_line_simplify.dart';
import 'source_arachne_wall_tool_paths.dart';

/// Result of pinned `WallToolPaths::separateOutInnerContour()`.
class SourceArachneSeparatedContours2 {
  const SourceArachneSeparatedContours2({
    required this.toolpaths,
    required this.innerContour,
    required this.firstWallContour,
  });

  final List<List<SourceArachneExtrusionLine2>> toolpaths;
  final List<SourcePolygon2> innerContour;
  final List<SourcePolygon2> firstWallContour;
}

/// Independently testable post-processing slices from pinned
/// `Arachne::WallToolPaths.cpp`.
class SourceArachneWallToolPathsPostprocess2 {
  const SourceArachneWallToolPathsPostprocess2._();

  static const int wallContourMarkedWidth = 0;
  static const int firstWallContourMarkedWidth = 1;

  /// Direct port of `WallToolPaths::removeSmallLines()`.
  ///
  /// The source helper `shorterThan()` starts with `shape.back()` and then
  /// iterates every junction, so an open line also measures the closing
  /// `back -> front` segment. Preserve that quirk literally.
  static void removeSmallLines(
    List<List<SourceArachneExtrusionLine2>> toolpaths,
  ) {
    for (final inset in toolpaths) {
      var lineIndex = 0;
      while (lineIndex < inset.length) {
        final line = inset[lineIndex];
        var minWidth = 0x7fffffff;
        for (final junction in line.junctions) {
          minWidth = math.min(minWidth, junction.w);
        }

        if (line.isOdd &&
            !line.isClosed &&
            _shorterThan(line, minWidth ~/ 2)) {
          inset[lineIndex] = inset.last;
          inset.removeLast();
          // Source decrements `line_idx` after erase and therefore reconsiders
          // the element moved into the current slot.
          continue;
        }
        lineIndex++;
      }
    }
  }

  /// Direct port of `WallToolPaths::separateOutInnerContour()` excluding the
  /// already independent caller-side storage assignment.
  static SourceArachneSeparatedContours2 separateOutInnerContour(
    List<List<SourceArachneExtrusionLine2>> toolpaths,
  ) {
    final actualToolpaths = <List<SourceArachneExtrusionLine2>>[];
    final innerContour = <SourcePolygon2>[];
    final firstWallContour = <SourcePolygon2>[];

    for (final inset in toolpaths) {
      if (inset.isEmpty) continue;

      _SourcePathType? type;
      for (final line in inset) {
        if (line.junctions.isEmpty) continue;
        final width = line.junctions.first.w;
        if (width == wallContourMarkedWidth) {
          type = _SourcePathType.wallContour;
        } else if (width == firstWallContourMarkedWidth) {
          type = _SourcePathType.firstWallContour;
        } else {
          type = _SourcePathType.actualPath;
        }
        // Pinned source breaks only the inner junction loop, not the line loop.
        // Therefore the first junction of the *last non-empty line* wins.
      }

      if (type == null) {
        throw StateError(
          'Pinned separateOutInnerContour received an inset containing only empty lines',
        );
      }

      if (type == _SourcePathType.wallContour) {
        for (final line in inset) {
          if (line.isOdd) continue;
          if (line.isClosed && line.junctions.isNotEmpty) {
            innerContour.add(_toPolygon(line));
          }
        }
      } else if (type == _SourcePathType.firstWallContour) {
        for (final line in inset) {
          if (line.isOdd) continue;
          if (line.isClosed && line.junctions.isNotEmpty) {
            firstWallContour.add(_toPolygon(line));
          }
        }
      } else {
        actualToolpaths.add([
          for (final line in inset) line.copy(),
        ]);
      }
    }

    return SourceArachneSeparatedContours2(
      toolpaths: actualToolpaths,
      innerContour: _unionEvenOdd(innerContour),
      firstWallContour: _unionEvenOdd(firstWallContour),
    );
  }

  /// Direct port of `WallToolPaths::simplifyToolPaths()`.
  static void simplifyToolPaths(
    List<List<SourceArachneExtrusionLine2>> toolpaths,
  ) {
    final maximumResolution =
        SourceArachneWallToolPathsPreprocess2.meshfixMaximumResolution;
    final maximumDeviation =
        SourceArachneWallToolPathsPreprocess2.meshfixMaximumDeviation;
    final maximumExtrusionAreaDeviation = SourceArachneWallToolPathsPreprocess2
        .meshfixMaximumExtrusionAreaDeviation;
    for (final inset in toolpaths) {
      for (final line in inset) {
        line.simplifySource(
          maximumResolution * maximumResolution,
          maximumDeviation * maximumDeviation,
          maximumExtrusionAreaDeviation,
        );
      }
    }
  }

  /// Direct port of `WallToolPaths::removeEmptyToolPaths()`.
  static bool removeEmptyToolPaths(
    List<List<SourceArachneExtrusionLine2>> toolpaths,
  ) {
    toolpaths.removeWhere((lines) => lines.isEmpty);
    return toolpaths.isEmpty;
  }

  static bool _shorterThan(
    SourceArachneExtrusionLine2 line,
    int checkLength,
  ) {
    if (line.junctions.isEmpty) {
      throw StateError('Pinned shorterThan requires a non-empty shape');
    }

    var previous = line.junctions.last.p;
    var length = 0;
    for (final junction in line.junctions) {
      final point = junction.p;
      final dx = previous.x - point.x;
      final dy = previous.y - point.y;
      length += math.sqrt(dx.toDouble() * dx + dy.toDouble() * dy).truncate();
      if (length >= checkLength) return false;
      previous = point;
    }
    return true;
  }

  static SourcePolygon2 _toPolygon(SourceArachneExtrusionLine2 line) =>
      SourcePolygon2([
        for (final junction in line.junctions) junction.p,
      ]);

  static List<SourcePolygon2> _unionEvenOdd(
    List<SourcePolygon2> polygons,
  ) {
    if (polygons.isEmpty) return const [];
    final paths = <c2.Path64>[
      for (final polygon in polygons)
        if (polygon.points.length >= 3)
          [
            for (final point in polygon.points) c2.Point64(point.x, point.y),
          ],
    ];
    if (paths.isEmpty) return const [];

    final unioned = c2.Clipper.union(
      subject: paths,
      fillRule: c2.FillRule.evenOdd,
    );
    return List.unmodifiable([
      for (final path in unioned)
        if (path.length >= 3)
          SourcePolygon2([
            for (final point in path) SourcePoint2(point.x, point.y),
          ]),
    ]);
  }
}

enum _SourcePathType {
  actualPath,
  wallContour,
  firstWallContour,
}
