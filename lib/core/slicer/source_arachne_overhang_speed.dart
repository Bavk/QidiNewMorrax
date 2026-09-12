import 'dart:math' as math;
import 'dart:typed_data';

import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import '../geometry/thick_polyline.dart';
import 'extrusion_entity.dart';
import 'flow.dart';
import 'source_arachne_extrusion_line.dart';
import 'source_arachne_overhang.dart';
import 'source_arachne_top_one_wall.dart';
import 'source_shortest_path.dart';
import 'variable_width.dart';

/// Direct source-order port of the Arachne-specific
/// `detect_overhang_degree()` + `smooth_overhang_level()` path.
class SourceArachneOverhangSpeed2 {
  const SourceArachneOverhangSpeed2._();

  static const double minDegreeGap = 0.25;
  static const List<double> nonUniformDegreeMap = <double>[
    0,
    10,
    25,
    50,
    75,
    100,
  ];

  static List<ExtrusionPath2> splitWithSpeedGrading({
    required SourceArachneExtrusionLine2 extrusion,
    required List<SourcePolygon2> lowerLayerPolygons,
    required double nozzleDiameterMm,
    required ExtrusionRole supportedRole,
    required Flow supportedFlow,
    required Flow overhangFlow,
  }) {
    if (extrusion.junctions.length < 2) {
      throw StateError('Pinned Arachne overhang split requires >= 2 junctions');
    }
    if (!nozzleDiameterMm.isFinite || nozzleDiameterMm <= 0) {
      throw ArgumentError.value(
        nozzleDiameterMm,
        'nozzleDiameterMm',
        'Pinned Arachne speed grading requires a positive nozzle diameter',
      );
    }

    final clippedLower = _pruneLowerLayerPolygons(
      extrusion,
      lowerLayerPolygons,
      nozzleDiameterMm,
    );

    final paths = <ExtrusionPath2>[
      ...gradeSupported(
        extrusion: extrusion,
        lowerLayerPolygons: clippedLower,
        nozzleDiameterMm: nozzleDiameterMm,
        role: supportedRole,
        flow: supportedFlow,
      ),
    ];

    final unsupported = SourceArachneOverhang2.clipExtrusionWidths(
      extrusion: extrusion,
      clipPolygons: clippedLower,
      intersection: false,
    );
    final variableWidth = SourceVariableWidth2();
    for (final thick in unsupported) {
      final chord = (thick.lastPoint - thick.firstPoint).length;
      final overhangDegree = chord < thick.length ? 5.0 : 6.0;
      paths.addAll(
        variableWidth
            .thickPolylineToMultiPath(
              thick,
              ExtrusionRole.overhangPerimeter,
              overhangFlow,
              SourceVariableWidth2.qidiTolerance,
              Slic3rUnits.scaledEpsilon.toDouble(),
              overhangDegree,
            )
            .paths,
      );
    }

    if (paths.isEmpty) return const [];
    final reordered = _chainFromPreferredStart(extrusion, paths);
    smoothOverhangLevel(reordered);
    return List.unmodifiable(reordered);
  }

  /// Pinned `detect_overhang_degree()` output before unsupported bridge paths,
  /// path re-chaining and smoothing.
  static List<ExtrusionPath2> gradeSupported({
    required SourceArachneExtrusionLine2 extrusion,
    required List<SourcePolygon2> lowerLayerPolygons,
    required double nozzleDiameterMm,
    required ExtrusionRole role,
    required Flow flow,
  }) {
    final supported = SourceArachneOverhang2.clipExtrusionWidths(
      extrusion: extrusion,
      clipPolygons: lowerLayerPolygons,
      intersection: true,
    );
    if (supported.isEmpty) return const [];

    final samplingInterval = Slic3rUnits.scaleTruncated(2.0).toDouble();
    final offsetWidth =
        Slic3rUnits.scaleTruncated(nozzleDiameterMm) ~/ 2;
    final variableWidth = SourceVariableWidth2();
    final result = <ExtrusionPath2>[];

    for (final thick in supported) {
      final sampled = _addSamplingPoints(
        _zPointsFromThickPolyline(thick),
        samplingInterval,
      );
      if (sampled.isEmpty) continue;

      final degrees = <double>[
        for (final point in sampled)
          _mappedDegree(
            point,
            lowerLayerPolygons,
            offsetWidth,
          ),
      ];

      var previousPoint = sampled.first;
      var previousDegree = degrees.first;
      var previousLine = <_SourceZPoint2>[sampled.first];

      for (var index = 1; index < sampled.length; index++) {
        final currentPoint = sampled[index];
        final currentDegree = degrees[index];
        if (_inSameDegreeRange(previousDegree, currentDegree)) {
          previousPoint = currentPoint;
          previousDegree = currentDegree;
          previousLine.add(currentPoint);
          continue;
        }

        final splitPoints = _splitPoints(
          previousPoint,
          currentPoint,
          previousDegree,
          currentDegree,
        );
        for (final split in splitPoints) {
          previousLine.add(split.point);
          final targetDegree = previousDegree < currentDegree
              ? split.degree - minDegreeGap
              : split.degree;
          _appendVariableWidth(
            result,
            previousLine,
            role,
            flow,
            targetDegree,
            variableWidth,
          );
          previousLine = <_SourceZPoint2>[split.point];
        }

        previousPoint = currentPoint;
        previousDegree = currentDegree;
        previousLine.add(currentPoint);
      }

      if (previousLine.length > 1) {
        _appendVariableWidth(
          result,
          previousLine,
          role,
          flow,
          _baseDegree(previousDegree),
          variableWidth,
        );
      }
    }

    return List.unmodifiable(result);
  }

  /// Exact Arachne smoothing pass after Clipper re-chaining.
  ///
  /// Note the source quirk: comparisons use integer
  /// `ExtrusionPath::get_overhang_degree()`, which truncates the fractional
  /// quarter-degree values created by `detect_overhang_degree()`.
  static void smoothOverhangLevel(List<ExtrusionPath2> paths) {
    final pathCount = paths.length;
    if (pathCount < 2) return;

    final thresholdLength = Slic3rUnits.scaleTruncated(0.8).toDouble();
    final filterRange = Slic3rUnits.scaleTruncated(6.5).toDouble();
    final oldOverhangSeries = <int>[
      for (final path in paths) _sourceGetOverhangDegree(path),
    ];

    var index = 0;
    while (index < pathCount) {
      final path = paths[index];
      if (path.role != ExtrusionRole.perimeter &&
          path.role != ExtrusionRole.externalPerimeter) {
        index++;
        continue;
      }

      final currentDegree = oldOverhangSeries[index];
      var totalLength = path.length;
      var groupEnd = index + 1;
      while (groupEnd < pathCount) {
        final candidate = paths[groupEnd];
        if (_sourceGetOverhangDegree(candidate) != currentDegree ||
            (candidate.role != ExtrusionRole.perimeter &&
                candidate.role != ExtrusionRole.externalPerimeter)) {
          break;
        }
        totalLength += candidate.length;
        groupEnd++;
      }

      if (totalLength < thresholdLength) {
        var leftTotalLength = (filterRange - totalLength) / 2.0;
        var rightTotalLength = leftTotalLength;
        final neighbors = <_SourceDegreeNeighbor2>[];

        var cursor = index - 1;
        while (leftTotalLength > 0) {
          final neighborIndex = cursor < 0 ? pathCount - 1 : cursor;
          final neighbor = paths[neighborIndex];
          if (neighbor.role == ExtrusionRole.overhangPerimeter) break;
          final length = neighbor.length;
          neighbors.add(
            _SourceDegreeNeighbor2(
              math.min(length, leftTotalLength),
              oldOverhangSeries[neighborIndex],
            ),
          );
          leftTotalLength -= length;
          cursor = neighborIndex - 1;
        }

        cursor = groupEnd;
        while (rightTotalLength > 0) {
          final neighborIndex = cursor % pathCount;
          final neighbor = paths[neighborIndex];
          if (neighbor.role == ExtrusionRole.overhangPerimeter) break;
          final length = neighbor.length;
          neighbors.add(
            _SourceDegreeNeighbor2(
              math.min(length, rightTotalLength),
              oldOverhangSeries[neighborIndex],
            ),
          );
          rightTotalLength -= length;
          cursor++;
        }

        var weightedSum = 0.0;
        var neighborLengthSum = 0.0;
        for (final neighbor in neighbors) {
          weightedSum += neighbor.length * neighbor.degree;
          neighborLengthSum += neighbor.length;
        }
        final average =
            (totalLength * currentDegree + weightedSum) /
            (neighborLengthSum + totalLength);
        final sourceIntegerAverage = average.toInt().clamp(0, 10);
        for (var groupIndex = index;
            groupIndex < groupEnd;
            groupIndex++) {
          paths[groupIndex].overhangDegree = sourceIntegerAverage.toDouble();
        }
      }

      index = groupEnd;
    }
  }

  static List<SourcePolygon2> _pruneLowerLayerPolygons(
    SourceArachneExtrusionLine2 extrusion,
    List<SourcePolygon2> lowerLayerPolygons,
    double nozzleDiameterMm,
  ) {
    final maxWidth = extrusion.junctions
        .map((junction) => junction.w)
        .reduce(math.max);
    final bbox = SourceArachneTopOneWall2.bounds([
      SourcePolygon2([
        for (final junction in extrusion.junctions) junction.p,
      ]),
    ]).inflated(
      maxWidth + Slic3rUnits.scaleTruncated(nozzleDiameterMm),
    );

    return List.unmodifiable([
      for (final polygon in lowerLayerPolygons)
        if (SourceArachneTopOneWall2.clipWithSubjectBounds(
          [polygon],
          bbox,
        ).isNotEmpty)
          polygon,
    ]);
  }

  static List<ExtrusionPath2> _chainFromPreferredStart(
    SourceArachneExtrusionLine2 extrusion,
    List<ExtrusionPath2> paths,
  ) {
    var startPoint = paths.first.firstPoint;
    if (!extrusion.isClosed) {
      final occurrence = <SourcePoint2, _SourceEndpointInfo2>{};
      for (final path in paths) {
        for (final point in <SourcePoint2>[path.firstPoint, path.lastPoint]) {
          final info = occurrence.putIfAbsent(point, _SourceEndpointInfo2.new);
          info.occurrence++;
          if (path.role == ExtrusionRole.overhangPerimeter) {
            info.isOverhang = true;
          }
        }
      }
      for (final entry in occurrence.entries) {
        if (entry.value.occurrence != 1) continue;
        startPoint = entry.key;
        if (!entry.value.isOverhang) break;
      }
    }

    final entities = <ExtrusionEntity2>[...paths];
    SourceShortestPath2.chainAndReorderExtrusionEntities(
      entities,
      startNear: startPoint,
    );
    return <ExtrusionPath2>[
      for (final entity in entities) entity as ExtrusionPath2,
    ];
  }

  static List<_SourceZPoint2> _zPointsFromThickPolyline(ThickPolyline2 thick) {
    if (thick.points.length < 2) return const [];
    final result = <_SourceZPoint2>[
      _SourceZPoint2(thick.points.first, thick.width.first.toInt()),
    ];
    for (var index = 1; index < thick.points.length; index++) {
      result.add(
        _SourceZPoint2(
          thick.points[index],
          thick.width[2 * index - 1].toInt(),
        ),
      );
    }
    return result;
  }

  static List<_SourceZPoint2> _addSamplingPoints(
    List<_SourceZPoint2> path,
    double minimumInterval,
  ) {
    if (path.isEmpty) return const [];
    final sampled = <_SourceZPoint2>[];
    for (var index = 0; index < path.length; index++) {
      final current = path[index];
      sampled.add(current);
      if (index + 1 >= path.length) continue;

      final next = path[index + 1];
      final delta = next.point - current.point;
      final distance = delta.length;
      if (distance <= minimumInterval) continue;

      final sampleCount = (distance / minimumInterval).floor();
      for (var sample = 1; sample <= sampleCount; sample++) {
        final t = sample * minimumInterval / distance;
        sampled.add(
          _SourceZPoint2(
            SourcePoint2(
              (current.point.x + t * delta.x).toInt(),
              (current.point.y + t * delta.y).toInt(),
            ),
            (current.width + t * (next.width - current.width)).toInt(),
          ),
        );
      }
    }
    return sampled;
  }

  static double _mappedDegree(
    _SourceZPoint2 point,
    List<SourcePolygon2> lowerLayerPolygons,
    int offsetWidth,
  ) {
    final signedDistance = _signedDistanceFromPerimeter(
      point.point,
      lowerLayerPolygons,
    );
    final width = _f32(point.width.toDouble());
    final realDistance = offsetWidth + signedDistance;

    late final double rawDegree;
    if (realDistance.abs() > width / 2.0) {
      rawDegree = realDistance < 0 ? 0 : 100;
    } else {
      rawDegree = (width / 2.0 + realDistance) / width * 100.0;
    }

    var highIndex = 0;
    while (highIndex < nonUniformDegreeMap.length &&
        nonUniformDegreeMap[highIndex] <= rawDegree) {
      highIndex++;
    }
    if (highIndex == nonUniformDegreeMap.length) {
      return (nonUniformDegreeMap.length - 1).toDouble();
    }
    final lowIndex = highIndex - 1;
    if (lowIndex < 0) return 0;
    final low = nonUniformDegreeMap[lowIndex];
    final high = nonUniformDegreeMap[highIndex];
    final t = (rawDegree - low) / (high - low);
    return lowIndex * (1.0 - t) + t * highIndex;
  }

  static double _signedDistanceFromPerimeter(
    SourcePoint2 point,
    List<SourcePolygon2> polygons,
  ) {
    if (polygons.isEmpty) return double.infinity;

    var nearest = double.infinity;
    var insideCrossings = 0;
    for (final polygon in polygons) {
      final relation = polygon.pointInPolygon(point);
      if (relation == -1) return 0;
      if (relation == 1) insideCrossings++;
      nearest = math.min(nearest, polygon.distanceToBoundary(point));
    }
    return insideCrossings.isOdd ? -nearest : nearest;
  }

  static double _baseDegree(double degree) =>
      (degree / minDegreeGap).floor() * minDegreeGap;

  static bool _inSameDegreeRange(double left, double right) =>
      (_baseDegree(left) - _baseDegree(right)).abs() < 1e-9;

  static List<_SourceSplitPoint2> _splitPoints(
    _SourceZPoint2 a,
    _SourceZPoint2 b,
    double degreeA,
    double degreeB,
  ) {
    final startDegree =
        _baseDegree(math.min(degreeA, degreeB)) + minDegreeGap;
    final endDegree = _baseDegree(math.max(degreeA, degreeB));
    if (startDegree > endDegree) return const [];

    final deltaDegree = degreeB - degreeA;
    if (deltaDegree.abs() < 1e-6) return const [];

    final result = <_SourceSplitPoint2>[];
    if (degreeA < degreeB) {
      for (var degree = startDegree;
          degree <= endDegree;
          degree += minDegreeGap) {
        result.add(_splitPoint(a, b, degreeA, deltaDegree, degree));
      }
    } else {
      for (var degree = endDegree;
          degree >= startDegree;
          degree -= minDegreeGap) {
        result.add(_splitPoint(a, b, degreeA, deltaDegree, degree));
      }
    }
    return result;
  }

  static _SourceSplitPoint2 _splitPoint(
    _SourceZPoint2 a,
    _SourceZPoint2 b,
    double degreeA,
    double deltaDegree,
    double splitDegree,
  ) {
    final t = (splitDegree - degreeA) / deltaDegree;
    final dx = b.point.x - a.point.x;
    final dy = b.point.y - a.point.y;
    return _SourceSplitPoint2(
      _SourceZPoint2(
        SourcePoint2(
          a.point.x + (dx * t).toInt(),
          a.point.y + (dy * t).toInt(),
        ),
        a.width + ((b.width - a.width) * t).toInt(),
      ),
      splitDegree,
    );
  }

  static void _appendVariableWidth(
    List<ExtrusionPath2> destination,
    List<_SourceZPoint2> line,
    ExtrusionRole role,
    Flow flow,
    double degree,
    SourceVariableWidth2 variableWidth,
  ) {
    if (line.length < 2) return;
    final thick = _toThickPolyline(line);
    destination.addAll(
      variableWidth
          .thickPolylineToMultiPath(
            thick,
            role,
            flow,
            SourceVariableWidth2.qidiTolerance,
            Slic3rUnits.scaledEpsilon.toDouble(),
            degree,
          )
          .paths,
    );
  }

  static ThickPolyline2 _toThickPolyline(List<_SourceZPoint2> path) {
    final points = <SourcePoint2>[path[0].point, path[1].point];
    final widths = <double>[
      path[0].width.toDouble(),
      path[1].width.toDouble(),
    ];
    var previous = path[1];
    for (var index = 2; index < path.length; index++) {
      final current = path[index];
      points.add(current.point);
      widths
        ..add(previous.width.toDouble())
        ..add(current.width.toDouble());
      previous = current;
    }
    return ThickPolyline2(points: points, width: widths);
  }

  static int _sourceGetOverhangDegree(ExtrusionPath2 path) {
    if (path.role == ExtrusionRole.perimeter ||
        path.role == ExtrusionRole.externalPerimeter ||
        path.role == ExtrusionRole.overhangPerimeter ||
        path.role == ExtrusionRole.supportMaterial ||
        path.role == ExtrusionRole.supportMaterialInterface ||
        path.role == ExtrusionRole.supportTransition ||
        path.role == ExtrusionRole.supportIroning) {
      return path.overhangDegree.toInt();
    }
    return 0;
  }

  static double _f32(double value) =>
      Float32List.fromList(<double>[value]).first;
}

class _SourceZPoint2 {
  const _SourceZPoint2(this.point, this.width);

  final SourcePoint2 point;
  final int width;
}

class _SourceSplitPoint2 {
  const _SourceSplitPoint2(this.point, this.degree);

  final _SourceZPoint2 point;
  final double degree;
}

class _SourceDegreeNeighbor2 {
  const _SourceDegreeNeighbor2(this.length, this.degree);

  final double length;
  final int degree;
}

class _SourceEndpointInfo2 {
  int occurrence = 0;
  bool isOverhang = false;
}
