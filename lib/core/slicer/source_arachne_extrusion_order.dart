import 'dart:math' as math;

import '../geometry/source_polygon.dart';
import 'classic_wall_sequence.dart';
import 'source_arachne_extrusion_line.dart';
import 'source_arachne_region_order.dart';

/// Source-shaped `PerimeterGeneratorArachneExtrusion` payload before
/// `traverse_extrusions()`.
class SourceArachneOrderedExtrusion2 {
  const SourceArachneOrderedExtrusion2({
    required this.extrusion,
    required this.isContour,
    this.fuzzify = false,
  });

  final SourceArachneExtrusionLine2 extrusion;
  final bool isContour;
  final bool fuzzify;
}

/// Direct source-order port of the Arachne extrusion topological + nearest
/// ordering loop in `PerimeterGenerator::process_arachne()`.
class SourceArachneExtrusionOrder2 {
  const SourceArachneExtrusionOrder2._();

  static bool isOuterWallFirst({
    required SourceWallSequence2 wallSequence,
    required int layerId,
  }) {
    var result = wallSequence == SourceWallSequence2.outerInner ||
        wallSequence == SourceWallSequence2.innerOuterInner;
    if (layerId == 0) {
      result = wallSequence == SourceWallSequence2.outerInner;
    }
    return result;
  }

  static List<SourceArachneOrderedExtrusion2> order({
    required List<List<SourceArachneExtrusionLine2>> totalPerimeters,
    required SourceWallSequence2 wallSequence,
    required int layerId,
  }) {
    final outerFirst = isOuterWallFirst(
      wallSequence: wallSequence,
      layerId: layerId,
    );
    final allExtrusions = <SourceArachneExtrusionLine2>[];
    if (outerFirst) {
      for (var perimeterIndex = 0;
          perimeterIndex < totalPerimeters.length;
          perimeterIndex++) {
        allExtrusions.addAll(totalPerimeters[perimeterIndex]);
      }
    } else {
      for (var perimeterIndex = totalPerimeters.length - 1;
          perimeterIndex >= 0;
          perimeterIndex--) {
        allExtrusions.addAll(totalPerimeters[perimeterIndex]);
      }
    }

    if (allExtrusions.isEmpty) return const [];

    final blocked = List<int>.filled(allExtrusions.length, 0);
    final blocking = <List<int>>[
      for (var index = 0; index < allExtrusions.length; index++) <int>[],
    ];
    final indexByExtrusion = <SourceArachneExtrusionLine2, int>{
      for (var index = 0; index < allExtrusions.length; index++)
        allExtrusions[index]: index,
    };

    final constraints = SourceArachneRegionOrderBuilder2.getRegionOrder(
      allExtrusions,
      outerToInner: outerFirst,
    );
    for (final constraint in constraints) {
      final before = indexByExtrusion[constraint.before];
      final after = indexByExtrusion[constraint.after];
      if (before == null || after == null) {
        throw StateError('Pinned region order referenced an unknown extrusion');
      }
      blocked[after]++;
      blocking[before].add(after);
    }

    final processed = List<bool>.filled(allExtrusions.length, false);
    var currentPosition = allExtrusions.first.junctions.isEmpty
        ? const _SourceOrderPoint(0, 0)
        : _SourceOrderPoint.fromSource(
            allExtrusions.first.junctions.first.p,
          );
    final ordered = <SourceArachneOrderedExtrusion2>[];

    while (ordered.length < allExtrusions.length) {
      final availableOpen = <int>[];
      final availableClosed = <int>[];
      for (var candidate = 0;
          candidate < allExtrusions.length;
          candidate++) {
        if (processed[candidate] || blocked[candidate] != 0) continue;
        if (allExtrusions[candidate].isClosed) {
          availableClosed.add(candidate);
        } else {
          availableOpen.add(candidate);
        }
      }
      final available = <int>[...availableOpen, ...availableClosed];
      if (available.isEmpty) {
        throw StateError('Pinned Arachne region constraints formed a cycle');
      }

      var bestCandidate = available.first;
      var bestDistance = double.maxFinite;
      var isBestClosed = false;

      for (final candidateIndex in available) {
        final path = allExtrusions[candidateIndex];
        if (path.junctions.isEmpty) {
          if (bestDistance == double.maxFinite) {
            bestCandidate = candidateIndex;
            isBestClosed = path.isClosed;
          }
          continue;
        }

        final candidatePosition =
            _SourceOrderPoint.fromSource(path.junctions.first.p);
        // Source variable is named `distance_sqr`, but the expression uses
        // Eigen `.norm()`: ordinary Euclidean distance.
        final distance = currentPosition.distanceTo(candidatePosition);
        if (distance < bestDistance) {
          if (path.isClosed ||
              (!path.isClosed && bestDistance != double.maxFinite) ||
              (!path.isClosed && !isBestClosed)) {
            bestCandidate = candidateIndex;
            bestDistance = distance;
            isBestClosed = path.isClosed;
          }
        }
      }

      final bestPath = allExtrusions[bestCandidate];
      ordered.add(
        SourceArachneOrderedExtrusion2(
          extrusion: bestPath,
          isContour: _isContour(bestPath),
          fuzzify: false,
        ),
      );
      processed[bestCandidate] = true;
      for (final unlocked in blocking[bestCandidate]) {
        blocked[unlocked]--;
      }

      if (bestPath.junctions.isNotEmpty) {
        currentPosition = _SourceOrderPoint.fromSource(
          bestPath.isClosed
              ? bestPath.junctions.first.p
              : bestPath.junctions.last.p,
        );
      }
    }

    if (wallSequence == SourceWallSequence2.innerOuterInner &&
        ordered.length > 2) {
      _applyInnerOuterInnerSourceReorder(ordered);
    }
    return ordered;
  }

  static bool _isContour(SourceArachneExtrusionLine2 line) {
    if (!line.isClosed) return false;
    final polygon = SourcePolygon2([
      for (final junction in line.junctions) junction.p,
    ]);
    // Pinned Arachne convention: contours are clockwise, holes CCW.
    return polygon.isClockwise;
  }

  static void _applyInnerOuterInnerSourceReorder(
    List<SourceArachneOrderedExtrusion2> ordered,
  ) {
    var position = 0;
    while (position < ordered.length) {
      var outer = -1;
      var firstInternal = -1;
      var secondInternal = -1;
      var scanIndex = position;

      for (; scanIndex < ordered.length; scanIndex++) {
        switch (ordered[scanIndex].extrusion.insetIndex) {
          case 0:
            if (outer == -1) outer = scanIndex;
          case 1:
            if (firstInternal == -1 &&
                scanIndex > outer &&
                outer != -1) {
              firstInternal = scanIndex;
            }
          case 2:
            if (ordered[scanIndex].extrusion.insetIndex == 2 &&
                secondInternal == -1 &&
                scanIndex > firstInternal &&
                outer != -1) {
              secondInternal = scanIndex;
            }
        }
        if (outer > -1 && firstInternal > -1 && secondInternal > -1) {
          break;
        }
      }

      if (outer > -1 && firstInternal > -1 && secondInternal > -1) {
        final temp = ordered[secondInternal];
        ordered[secondInternal] = ordered[firstInternal];
        ordered[firstInternal] = ordered[outer];
        ordered[outer] = temp;
      } else {
        break;
      }
      position = scanIndex + 1;
    }
  }
}

class _SourceOrderPoint {
  const _SourceOrderPoint(this.x, this.y);

  factory _SourceOrderPoint.fromSource(dynamic point) =>
      _SourceOrderPoint(point.x as int, point.y as int);

  final int x;
  final int y;

  double distanceTo(_SourceOrderPoint other) {
    final dx = (x - other.x).toDouble();
    final dy = (y - other.y).toDouble();
    return math.sqrt(dx * dx + dy * dy);
  }
}
