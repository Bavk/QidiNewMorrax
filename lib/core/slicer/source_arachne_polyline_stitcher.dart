import 'dart:math' as math;

import '../geometry/source_geometry.dart';
import 'source_arachne_extrusion_line.dart';
import 'source_arachne_wall_tool_paths.dart';

class SourceArachnePolylineStitchResult2 {
  const SourceArachnePolylineStitchResult2({
    required this.lines,
    required this.polygons,
  });

  final List<SourceArachneExtrusionLine2> lines;
  final List<SourceArachneExtrusionLine2> polygons;
}

/// Specialized port of pinned
/// `PolylineStitcher<VariableWidthLines, ExtrusionLine, ExtrusionJunction>`.
///
/// Endpoint lookup follows the same square-cell traversal as `SquareGrid`.
/// Within a cell endpoints retain insertion order (front, back for each input
/// line); source uses an unordered_multimap here, but equivalent endpoints are
/// intentionally indistinguishable below the snap threshold.
class SourceArachnePolylineStitcher2 {
  const SourceArachnePolylineStitcher2._();

  static SourceArachnePolylineStitchResult2 stitch(
    List<SourceArachneExtrusionLine2> lines, {
    required int maxStitchDistance,
    int? snapDistance,
  }) {
    if (lines.isEmpty) {
      return const SourceArachnePolylineStitchResult2(
        lines: [],
        polygons: [],
      );
    }
    if (maxStitchDistance <= 0) {
      throw ArgumentError.value(
        maxStitchDistance,
        'maxStitchDistance',
        'Pinned SparsePointGrid requires a positive cell size',
      );
    }

    final snap = snapDistance ??
        SourceArachneWallToolPathsPreprocess2.scaleDouble(0.01);
    final grid = _EndpointGrid(maxStitchDistance);
    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      if (line.junctions.isEmpty) {
        throw StateError('Pinned PolylineStitcher requires non-empty lines');
      }
      grid.insert(_Endpoint(lineIndex, 0), line.front.p);
      grid.insert(
        _Endpoint(lineIndex, line.junctions.length - 1),
        line.back.p,
      );
    }

    final processed = List<bool>.filled(lines.length, false);
    final resultLines = <SourceArachneExtrusionLine2>[];
    final resultPolygons = <SourceArachneExtrusionLine2>[];
    final sourceEpsilon =
        SourceArachneWallToolPathsPreprocess2.scaleDouble(0.01);

    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      if (processed[lineIndex]) continue;
      processed[lineIndex] = true;
      final sourceLine = lines[lineIndex];
      final chain = sourceLine.copy();
      var shouldClose = sourceLine.isOdd;
      var closestIsClosingPolygon = false;

      for (final goInReverseDirection in const [false, true]) {
        if (goInReverseDirection) {
          _reverse(chain);
        }
        var chainLength = _polylineLength(chain);

        while (true) {
          final from = chain.back.p;
          _Endpoint? closest;
          var closestDistance = 0x7fffffff;
          closestIsClosingPolygon = false;

          search:
          for (final nearby in grid.nearby(from, maxStitchDistance)) {
            final nearbyLine = lines[nearby.lineIndex];
            final nearbyPoint = nearbyLine.junctions[nearby.pointIndex].p;
            var distance = _norm(nearbyPoint - from);
            if (distance > maxStitchDistance) continue;

            var isClosingSegment = false;
            final fromFront = nearbyPoint - chain.front.p;
            if (fromFront.squaredLength < snap * snap) {
              if (chainLength + distance < 3 * maxStitchDistance ||
                  chain.junctions.length <= 2) {
                continue;
              }
              isClosingSegment = true;
              if (!shouldClose) {
                distance += sourceEpsilon;
              } else {
                distance -= sourceEpsilon;
              }
            } else if (processed[nearby.lineIndex]) {
              continue;
            }

            var nearbyWouldBeReversed = nearby.pointIndex != 0;
            nearbyWouldBeReversed =
                nearbyWouldBeReversed != goInReverseDirection;
            if (!nearbyLine.isOdd && nearbyWouldBeReversed) {
              continue;
            }
            if (chain.isOdd != nearbyLine.isOdd) {
              continue;
            }

            if (distance < closestDistance) {
              closestDistance = distance;
              closest = nearby;
              closestIsClosingPolygon = isClosingSegment;
            }
            if (distance < snap) {
              break search;
            }
          }

          if (closest == null || closestIsClosingPolygon) {
            break;
          }

          final closestLine = lines[closest.lineIndex];
          final closestPoint =
              closestLine.junctions[closest.pointIndex].p;
          final segmentDistance = _norm(chain.back.p - closestPoint);
          assert(segmentDistance <= maxStitchDistance + sourceEpsilon);
          final oldSize = chain.junctions.length;

          if (closest.pointIndex == 0) {
            final start = segmentDistance < snap ? 1 : 0;
            for (var index = start;
                index < closestLine.junctions.length;
                index++) {
              chain.junctions.add(closestLine.junctions[index].copy());
            }
          } else {
            var index = closestLine.junctions.length - 1;
            if (segmentDistance < snap) index--;
            for (; index >= 0; index--) {
              chain.junctions.add(closestLine.junctions[index].copy());
            }
          }

          for (var index = oldSize;
              index < chain.junctions.length;
              index++) {
            chainLength += _norm(
              chain.junctions[index].p - chain.junctions[index - 1].p,
            );
          }
          shouldClose = shouldClose && !closestLine.isOdd;
          assert(!processed[closest.lineIndex]);
          processed[closest.lineIndex] = true;
        }

        if (closestIsClosingPolygon) {
          if (goInReverseDirection) {
            _reverse(chain);
          }
          break;
        }
      }

      if (closestIsClosingPolygon) {
        resultPolygons.add(chain);
      } else {
        if (!sourceLine.isOdd) {
          // The second source pass reverses the chain. Non-reversible even
          // walls are restored to their original direction before output.
          _reverse(chain);
        }
        resultLines.add(chain);
      }
    }

    return SourceArachnePolylineStitchResult2(
      lines: resultLines,
      polygons: resultPolygons,
    );
  }

  /// Direct `WallToolPaths::stitchToolPaths()` composition.
  static void stitchToolPaths(
    List<List<SourceArachneExtrusionLine2>> toolpaths,
    int beadWidthX,
  ) {
    final stitchDistance = beadWidthX - 1;
    for (var wallIndex = 0; wallIndex < toolpaths.length; wallIndex++) {
      final stitched = stitch(
        toolpaths[wallIndex],
        maxStitchDistance: stitchDistance,
      );
      final wallLines = <SourceArachneExtrusionLine2>[
        ...stitched.lines,
      ];

      for (final wallPolygon in stitched.polygons) {
        if (wallPolygon.junctions.isEmpty) continue;
        if (wallPolygon.front.p != wallPolygon.back.p &&
            _norm(wallPolygon.back.p - wallPolygon.front.p) <
                stitchDistance) {
          wallPolygon.junctions.add(wallPolygon.front.copy());
        }
        wallPolygon.isClosed = true;
        wallLines.add(wallPolygon);
      }
      toolpaths[wallIndex] = wallLines;
    }
  }

  static void _reverse(SourceArachneExtrusionLine2 line) {
    final reversed = line.junctions.reversed.toList(growable: false);
    line.junctions.setAll(0, reversed);
  }

  static int _polylineLength(SourceArachneExtrusionLine2 line) {
    if (line.junctions.isEmpty) return 0;
    var length = 0;
    var previous = line.front.p;
    for (final junction in line.junctions) {
      length += _norm(junction.p - previous);
      previous = junction.p;
    }
    if (line.isClosed) {
      length += _norm(line.front.p - line.back.p);
    }
    return length;
  }

  static int _norm(SourcePoint2 vector) =>
      math.sqrt(vector.squaredLength.toDouble()).truncate();
}

class _Endpoint {
  const _Endpoint(this.lineIndex, this.pointIndex);

  final int lineIndex;
  final int pointIndex;
}

class _EndpointGrid {
  _EndpointGrid(this.cellSize);

  final int cellSize;
  final Map<(int, int), List<_Endpoint>> _cells = {};

  void insert(_Endpoint endpoint, SourcePoint2 point) {
    final key = (_gridCoord(point.x), _gridCoord(point.y));
    (_cells[key] ??= <_Endpoint>[]).add(endpoint);
  }

  Iterable<_Endpoint> nearby(SourcePoint2 point, int radius) sync* {
    final minX = _gridCoord(point.x - radius);
    final maxX = _gridCoord(point.x + radius);
    final minY = _gridCoord(point.y - radius);
    final maxY = _gridCoord(point.y + radius);
    for (var gridY = minY; gridY <= maxY; gridY++) {
      for (var gridX = minX; gridX <= maxX; gridX++) {
        final values = _cells[(gridX, gridY)];
        if (values == null) continue;
        yield* values;
      }
    }
  }

  int _gridCoord(int coordinate) => coordinate ~/ cellSize;
}
