import 'dart:math' as math;
import 'dart:typed_data';

import 'package:clipper2/clipper2.dart' as c2;

import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import 'source_arachne_wall_tool_paths.dart';

/// Result of the pinned `WallToolPaths::generate()` prepared-outline stage.
///
/// This deliberately stops before rounded-rectangle width calculations,
/// beading-strategy construction, or `SkeletalTrapezoidation`.
class SourceArachnePreparedOutline2 {
  SourceArachnePreparedOutline2({
    required Iterable<SourcePolygon2> preparedOutline,
    required this.outlineSizeChange,
    required this.totalSignedArea,
    required this.applyHoleCompensation,
    required Iterable<int> holeIndices,
  })  : preparedOutline = List.unmodifiable(preparedOutline),
        holeIndices = List.unmodifiable(holeIndices);

  final List<SourcePolygon2> preparedOutline;
  final bool outlineSizeChange;
  final double totalSignedArea;
  final bool applyHoleCompensation;
  final List<int> holeIndices;

  bool get isEmptyArea => totalSignedArea <= 0;
}

/// Literal front half of pinned `Arachne::WallToolPaths::generate()`.
///
/// Source identity:
/// `bambulab/BambuStudio@f2b55a5a83f266cf56e06c7943a81a08bebb7fad`
/// `src/libslic3r/Arachne/WallToolPaths.cpp`.
class SourceArachneWallToolPathsPrepare2 {
  const SourceArachneWallToolPathsPrepare2._();

  /// Pinned `constexpr coord_t grid_size = scaled<coord_t>(2.)`.
  /// The generic source scaler truncates the binary-double quotient.
  static final int sourceGridSize =
      SourceArachneWallToolPathsPreprocess2.scaleDouble(2.0);

  static SourceArachnePreparedOutline2 prepare(
    SourceArachneWallToolPathsState2 state, {
    bool enableHoleCompensation = false,
    Iterable<int> holeIndices = const <int>[],
  }) {
    final originalOutlineSize = state.outline.length;
    var outlineSizeChange = false;

    var prepared = offsetPolygons(
      state.outline,
      -SourceArachneWallToolPathsPreprocess2.epsilonOffset.toDouble(),
    );
    prepared = offsetPolygons(
      prepared,
      (SourceArachneWallToolPathsPreprocess2.epsilonOffset * 2).toDouble(),
    );
    prepared = offsetPolygons(
      prepared,
      -SourceArachneWallToolPathsPreprocess2.epsilonOffset.toDouble(),
    );
    outlineSizeChange |= prepared.length != originalOutlineSize;

    void updateSizeChange() {
      outlineSizeChange |= prepared.length != originalOutlineSize;
    }

    prepared = SourceArachneWallToolPathsPreprocess2.simplifyPolygons(
      prepared,
      smallestLineSegment:
          SourceArachneWallToolPathsPreprocess2.meshfixMaximumResolution,
      allowedErrorDistance:
          SourceArachneWallToolPathsPreprocess2.meshfixMaximumDeviation,
    );
    updateSizeChange();

    prepared = fixSelfIntersections(
      prepared,
      SourceArachneWallToolPathsPreprocess2.epsilonOffset,
    );
    updateSizeChange();

    prepared = removeDegenerateVertices(prepared);
    updateSizeChange();

    prepared = removeColinearEdges(
      prepared,
      maxDeviationAngle: 0.005,
    );
    updateSizeChange();

    prepared = fixSelfIntersections(
      prepared,
      SourceArachneWallToolPathsPreprocess2.epsilonOffset,
    );
    updateSizeChange();

    prepared = removeDegenerateVertices(prepared);
    updateSizeChange();

    prepared = removeSmallAreas(
      prepared,
      state.smallAreaLength * state.smallAreaLength,
      removeHoles: false,
    );
    updateSizeChange();

    prepared = unionNonZero(prepared);
    updateSizeChange();

    final totalSignedArea = prepared.fold<double>(
      0,
      (sum, polygon) => sum + polygon.signedArea,
    );

    return SourceArachnePreparedOutline2(
      preparedOutline: prepared,
      outlineSizeChange: outlineSizeChange,
      totalSignedArea: totalSignedArea,
      applyHoleCompensation:
          enableHoleCompensation && !outlineSizeChange,
      holeIndices: holeIndices,
    );
  }

  /// Source `offset(Polygons, float delta)` in integer `coord_t` units.
  ///
  /// The production source uses Clipper1 while this Dart repository uses
  /// Clipper2. This adapter keeps the source integer domain, miter join and
  /// effective miter limit 3; broader Clipper1/Clipper2 degeneracy equivalence
  /// remains a separately tracked compatibility seam.
  static List<SourcePolygon2> offsetPolygons(
    Iterable<SourcePolygon2> polygons,
    double delta,
  ) {
    final paths = _toPaths(polygons);
    if (paths.isEmpty) return const <SourcePolygon2>[];
    if (delta == 0) return unionNonZero(polygons);

    final sourceFloatDelta = _f32(delta);
    final offset = c2.Clipper.inflatePaths(
      paths: paths,
      delta: sourceFloatDelta,
      joinType: c2.JoinType.miter,
      endType: c2.EndType.polygon,
      miterLimit: 3,
    );
    return _fromPaths(offset);
  }

  /// Source final `union_(prepared_outline)` using NonZero fill.
  static List<SourcePolygon2> unionNonZero(
    Iterable<SourcePolygon2> polygons,
  ) {
    final paths = _toPaths(polygons);
    if (paths.isEmpty) return const <SourcePolygon2>[];
    return _fromPaths(
      c2.Clipper.union(
        subject: paths,
        fillRule: c2.FillRule.nonZero,
      ),
    );
  }

  /// Port of pinned `fixSelfIntersections(epsilon, Polygons&)`.
  ///
  /// Two source quirks are intentional:
  /// - grid coordinates use truncating integer division, making the zero cell
  ///   twice as wide around the origin;
  /// - both source calls to `ClipperLib::SimplifyPolygons(...)` discard the
  ///   returned `Paths`, so they do not replace `thiss`.
  static List<SourcePolygon2> fixSelfIntersections(
    Iterable<SourcePolygon2> polygons,
    int epsilon,
  ) {
    final points = <List<SourcePoint2>>[
      for (final polygon in polygons) List.of(polygon.points),
    ];
    if (epsilon < 1 || points.isEmpty) {
      return _freeze(points);
    }

    final halfEpsilon = (epsilon + 1) ~/ 2;
    final moveDist = halfEpsilon - 2 > 2 ? halfEpsilon - 2 : 2;
    final halfEpsilonSquared = halfEpsilon * halfEpsilon;
    final grid = _SourceSparseLineGrid2(points, sourceGridSize);

    final polygonCount = points.length;
    for (var polygonIndex = 0;
        polygonIndex < polygonCount;
        polygonIndex++) {
      final pathLength = points[polygonIndex].length;
      for (var pointIndex = 0; pointIndex < pathLength; pointIndex++) {
        var point = points[polygonIndex][pointIndex];
        final candidates = grid.getNearby(point, epsilon);
        for (final candidate in candidates) {
          final candidatePolygon = points[candidate.polygonIndex];
          if (candidatePolygon.isEmpty) continue;
          final nextIndex =
              (candidate.pointIndex + 1) % candidatePolygon.length;
          if (polygonIndex == candidate.polygonIndex &&
              (pointIndex == candidate.pointIndex ||
                  pointIndex == nextIndex)) {
            continue;
          }

          final segmentA = candidatePolygon[candidate.pointIndex];
          final segmentB = candidatePolygon[nextIndex];
          final closest = _closestPointOnSegment(point, segmentA, segmentB);
          if (_squaredDistance(point, closest) <= halfEpsilonSquared) {
            final other =
                points[polygonIndex][(pointIndex + 1) % pathLength];
            final isLeft = _pointIsLeftOfLine(other, segmentA, segmentB) > 0;
            final vector = isLeft
                ? segmentB - segmentA
                : segmentA - segmentB;
            final length = math.sqrt(vector.squaredLength).truncate();
            if (length == 0) {
              throw StateError(
                'Pinned fixSelfIntersections reached a zero-length candidate',
              );
            }

            final dx = (-vector.y * moveDist) ~/ length;
            final dy = (vector.x * moveDist) ~/ length;
            point = SourcePoint2(point.x + dx, point.y + dy);
            points[polygonIndex][pointIndex] = point;
          }
        }
      }
    }

    // Source calls SimplifyPolygons here but ignores its returned Paths.
    return _freeze(points);
  }

  /// Port of source `removeDegenerateVerts(Polygons&)`.
  static List<SourcePolygon2> removeDegenerateVertices(
    Iterable<SourcePolygon2> polygons,
  ) {
    final resultPolygons = <List<SourcePoint2>>[
      for (final polygon in polygons) List.of(polygon.points),
    ];

    var polygonIndex = 0;
    while (polygonIndex < resultPolygons.length) {
      final polygon = resultPolygons[polygonIndex];
      final result = <SourcePoint2>[];
      var changed = false;

      for (var index = 0; index < polygon.length; index++) {
        final last = result.isEmpty ? polygon.last : result.last;
        if (index + 1 == polygon.length && result.isEmpty) break;
        final next = index + 1 == polygon.length
            ? result.first
            : polygon[index + 1];

        if (_isDegenerate(last, polygon[index], next)) {
          changed = true;
          while (result.length > 1 &&
              _isDegenerate(result[result.length - 2], result.last, next)) {
            result.removeLast();
          }
        } else {
          result.add(polygon[index]);
        }
      }

      if (changed) {
        if (result.length > 2) {
          resultPolygons[polygonIndex] = result;
          polygonIndex++;
        } else {
          resultPolygons.removeAt(polygonIndex);
        }
      } else {
        polygonIndex++;
      }
    }

    return _freeze(resultPolygons);
  }

  /// Port of source `removeColinearEdges(Polygons&, max_deviation_angle)`.
  static List<SourcePolygon2> removeColinearEdges(
    Iterable<SourcePolygon2> polygons, {
    double maxDeviationAngle = 0.0005,
  }) {
    final output = <SourcePolygon2>[];
    for (final polygon in polygons) {
      final simplified = _removeColinearPolygon(
        polygon.points,
        maxDeviationAngle,
      );
      if (simplified.length >= 3) {
        output.add(SourcePolygon2(simplified));
      }
    }
    return List.unmodifiable(output);
  }

  /// Port of source `removeSmallAreas(Polygons&, min_area_size, remove_holes)`.
  ///
  /// The `remove_holes == false` branch intentionally preserves the pinned
  /// small-hole bookkeeping quirk: `small_holes` stores polygon copies, so the
  /// later assignment through `hole_it` mutates only that copy while decrementing
  /// `new_end` in the original polygon vector.
  static List<SourcePolygon2> removeSmallAreas(
    Iterable<SourcePolygon2> polygons,
    double minAreaSize, {
    required bool removeHoles,
  }) {
    final values = <SourcePolygon2>[
      for (final polygon in polygons) SourcePolygon2(polygon.points),
    ];
    var newEnd = values.length;

    if (removeHoles) {
      var index = 0;
      while (index < newEnd) {
        if (values[index].signedArea.abs() < minAreaSize) {
          newEnd--;
          values[index] = values[newEnd];
          continue;
        }
        index++;
      }
    } else {
      final smallHoles = <SourcePolygon2>[];
      var index = 0;
      while (index < newEnd) {
        final area = values[index].signedArea;
        if (area.abs() < minAreaSize) {
          if (area >= 0) {
            newEnd--;
            if (index < newEnd) {
              final tmp = values[newEnd];
              values[newEnd] = values[index];
              values[index] = tmp;
              continue;
            } else {
              break;
            }
          } else {
            smallHoles.add(SourcePolygon2(values[index].points));
          }
        }
        index++;
      }

      final removedOutlinesStart = newEnd;
      for (var holeIndex = smallHoles.length - 1;
          holeIndex >= 0;
          holeIndex--) {
        final hole = smallHoles[holeIndex];
        if (hole.points.isEmpty) continue;
        for (var outlineIndex = removedOutlinesStart;
            outlineIndex < values.length;
            outlineIndex++) {
          if (values[outlineIndex].contains(hole.points.first)) {
            newEnd--;
            // Source assigns `*hole_it = std::move(*new_end)`. `hole_it`
            // points into the copied `small_holes` vector, so the assignment
            // has no effect on `thiss`; only the `new_end--` changes output.
            break;
          }
        }
      }
    }

    return List.unmodifiable(values.take(newEnd));
  }

  static List<SourcePoint2> _removeColinearPolygon(
    List<SourcePoint2> input,
    double maxDeviationAngle,
  ) {
    var polygon = List<SourcePoint2>.of(input);
    var removedInIteration = 0;

    do {
      removedInIteration = 0;
      var processIndices = List<bool>.filled(polygon.length, true);
      var go = true;

      while (go) {
        go = false;
        final path = polygon;
        final pathLength = path.length;
        if (pathLength <= 3) return polygon;

        final skipIndices = List<bool>.filled(pathLength, false);
        final newPath = <SourcePoint2>[];
        var pointIndex = 0;
        while (pointIndex < pathLength) {
          if (!processIndices[pointIndex]) {
            newPath.add(path[pointIndex]);
            pointIndex++;
            continue;
          }

          if (pointIndex == pathLength - 1 && skipIndices[0]) {
            skipIndices[newPath.length] = true;
            go = true;
            newPath.add(path[pointIndex]);
            break;
          }

          final previous = path[(pointIndex - 1 + pathLength) % pathLength];
          final point = path[pointIndex];
          final next = path[(pointIndex + 1) % pathLength];

          var angle = _getAngleLeft(previous, point, next);
          final piFloat = _f32(math.pi);
          if (angle >= piFloat) {
            angle = _f32(angle - piFloat);
          }

          if (angle > maxDeviationAngle &&
              angle < math.pi - maxDeviationAngle) {
            newPath.add(point);
          } else if (pointIndex != pathLength - 1) {
            skipIndices[newPath.length] = true;
            go = true;
            newPath.add(next);
            pointIndex++;
          }
          pointIndex++;
        }

        polygon = newPath;
        removedInIteration += pathLength - polygon.length;
        processIndices = List<bool>.of(skipIndices);
      }
    } while (removedInIteration > 0);

    return polygon;
  }

  static bool _isDegenerate(
    SourcePoint2 last,
    SourcePoint2 now,
    SourcePoint2 next,
  ) {
    final lastLine = now - last;
    final nextLine = next - now;
    final dot = lastLine.x * nextLine.x + lastLine.y * nextLine.y;
    final lastNorm = math.sqrt(lastLine.squaredLength);
    final nextNorm = math.sqrt(nextLine.squaredLength);
    return dot.toDouble() == -lastNorm * nextNorm;
  }

  static double _getAngleLeft(
    SourcePoint2 a,
    SourcePoint2 b,
    SourcePoint2 c,
  ) {
    final bax = a.x - b.x;
    final bay = a.y - b.y;
    final bcx = c.x - b.x;
    final bcy = c.y - b.y;
    final dot = bax * bcx + bay * bcy;
    final determinant = bax * bcy - bay * bcx;

    if (determinant == 0) {
      if ((bax != 0 && (bax > 0) == (bcx > 0)) ||
          (bax == 0 && (bay > 0) == (bcy > 0))) {
        return 0;
      }
      return _f32(math.pi);
    }

    final angle = _f32(-math.atan2(determinant.toDouble(), dot.toDouble()));
    if (angle >= 0) return angle;
    return _f32(math.pi * 2 + angle);
  }

  static SourcePoint2 _closestPointOnSegment(
    SourcePoint2 point,
    SourcePoint2 a,
    SourcePoint2 b,
  ) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final ax = point.x - a.x;
    final ay = point.y - a.y;
    final lengthSquared = dx.toDouble() * dx + dy.toDouble() * dy;
    if (lengthSquared == 0) return a;

    final t = (ax.toDouble() * dx + ay.toDouble() * dy) / lengthSquared;
    if (t <= 0) return a;
    if (t >= 1) return b;
    return SourcePoint2(
      (a.x + t * dx).truncate(),
      (a.y + t * dy).truncate(),
    );
  }

  static int _pointIsLeftOfLine(
    SourcePoint2 point,
    SourcePoint2 a,
    SourcePoint2 b,
  ) =>
      (b.x - a.x) * (point.y - a.y) -
      (b.y - a.y) * (point.x - a.x);

  static int _squaredDistance(SourcePoint2 a, SourcePoint2 b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return dx * dx + dy * dy;
  }

  static double _f32(double value) {
    final slot = Float32List(1)..[0] = value;
    return slot[0];
  }

  static c2.Paths64 _toPaths(Iterable<SourcePolygon2> polygons) => [
        for (final polygon in polygons)
          if (polygon.points.length >= 3)
            [
              for (final point in polygon.points)
                c2.Point64(point.x, point.y),
            ],
      ];

  static List<SourcePolygon2> _fromPaths(c2.Paths64 paths) =>
      List.unmodifiable([
        for (final path in paths)
          if (path.length >= 3)
            SourcePolygon2([
              for (final point in path) SourcePoint2(point.x, point.y),
            ]),
      ]);

  static List<SourcePolygon2> _freeze(
    Iterable<List<SourcePoint2>> polygons,
  ) =>
      List.unmodifiable([
        for (final points in polygons) SourcePolygon2(points),
      ]);
}

class _SourceSegmentIndex2 {
  const _SourceSegmentIndex2(this.polygonIndex, this.pointIndex);

  final int polygonIndex;
  final int pointIndex;
}

/// Minimal direct port of the SquareGrid/SparseLineGrid behavior used only by
/// `fixSelfIntersections()`. Segment geometry is dereferenced from the mutable
/// polygon point lists at query time, matching source `PolygonsPointIndex`.
class _SourceSparseLineGrid2 {
  _SourceSparseLineGrid2(this.polygons, this.cellSize) {
    for (var polygonIndex = 0;
        polygonIndex < polygons.length;
        polygonIndex++) {
      for (var pointIndex = 0;
          pointIndex < polygons[polygonIndex].length;
          pointIndex++) {
        final segment = _SourceSegmentIndex2(polygonIndex, pointIndex);
        final polygon = polygons[polygonIndex];
        final start = polygon[pointIndex];
        final end = polygon[(pointIndex + 1) % polygon.length];
        for (final cell in _lineCells(start, end)) {
          cells.putIfAbsent(cell, () => <_SourceSegmentIndex2>[]).add(segment);
        }
      }
    }
  }

  final List<List<SourcePoint2>> polygons;
  final int cellSize;
  final Map<(int, int), List<_SourceSegmentIndex2>> cells = {};

  List<_SourceSegmentIndex2> getNearby(SourcePoint2 point, int radius) {
    final minGrid = _toGridPoint(
      SourcePoint2(point.x - radius, point.y - radius),
    );
    final maxGrid = _toGridPoint(
      SourcePoint2(point.x + radius, point.y + radius),
    );
    final result = <_SourceSegmentIndex2>[];
    for (var gridY = minGrid.$2; gridY <= maxGrid.$2; gridY++) {
      for (var gridX = minGrid.$1; gridX <= maxGrid.$1; gridX++) {
        final values = cells[(gridX, gridY)];
        if (values != null) result.addAll(values);
      }
    }
    return result;
  }

  Iterable<(int, int)> _lineCells(SourcePoint2 first, SourcePoint2 second) sync* {
    var start = first;
    var end = second;
    if (end.x < start.x) {
      final temp = start;
      start = end;
      end = temp;
    }

    final startCell = _toGridPoint(start);
    final endCell = _toGridPoint(end);
    final yDifference = end.y - start.y;
    final yDirection = _nonzeroSign(yDifference);

    var xCellStart = startCell.$1;
    for (var cellY = startCell.$2;
        cellY * yDirection <= endCell.$2 * yDirection;
        cellY += yDirection) {
      final nearestNextY = _toLowerCoord(
        cellY +
            ((_nonzeroSign(cellY) == yDirection || cellY == 0)
                ? yDirection
                : 0),
      );

      late int xCellEnd;
      if (yDifference == 0) {
        xCellEnd = endCell.$1;
      } else {
        final area = (end.x - start.x) * (nearestNextY - start.y);
        var correspondingX = start.x + area ~/ yDifference;
        final remainder = area - (area ~/ yDifference) * yDifference;
        if (correspondingX < 0 && remainder != 0) correspondingX++;
        xCellEnd = _toGridCoord(correspondingX);
        if (xCellEnd < startCell.$1) xCellEnd = xCellStart;
      }

      for (var cellX = xCellStart; cellX <= xCellEnd; cellX++) {
        final cell = (cellX, cellY);
        yield cell;
        if (cell == endCell) return;
      }
      xCellStart = xCellEnd;
    }
  }

  (int, int) _toGridPoint(SourcePoint2 point) =>
      (_toGridCoord(point.x), _toGridCoord(point.y));

  int _toGridCoord(int coordinate) => coordinate ~/ cellSize;

  int _toLowerCoord(int gridCoordinate) => gridCoordinate * cellSize;

  int _nonzeroSign(int value) => value >= 0 ? 1 : -1;
}
