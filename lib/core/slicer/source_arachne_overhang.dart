import 'dart:math' as math;

import 'package:clipper2/clipper2.dart' as c2;

import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import '../geometry/thick_polyline.dart';
import 'extrusion_entity.dart';
import 'flow.dart';
import 'source_arachne_extrusion_line.dart';
import 'source_arachne_top_one_wall.dart';
import 'source_shortest_path.dart';
import 'variable_width.dart';

/// Pinned non-speed branch of Arachne overhang traversal.
///
/// This is intentionally separate from the classic overhang splitter because
/// source Arachne clipping carries extrusion width in Clipper Z and interpolates
/// that width at every new intersection point.
class SourceArachneOverhang2 {
  const SourceArachneOverhang2._();

  static List<ExtrusionPath2> splitWithoutSpeedGrading({
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
        'Pinned Arachne overhang split requires a positive nozzle diameter',
      );
    }

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

    // Pinned source calls clip_clipper_polygon_with_subject_bbox(..., true):
    // the helper first performs its cheap vertex-pruning test, but when that
    // result is non-empty it returns the entire original lower polygon.
    final clippedLower = <SourcePolygon2>[];
    for (final polygon in lowerLayerPolygons) {
      if (SourceArachneTopOneWall2.clipWithSubjectBounds(
        [polygon],
        bbox,
      ).isNotEmpty) {
        clippedLower.add(polygon);
      }
    }

    final subject = <c2.Point64>[
      for (final junction in extrusion.junctions)
        c2.Point64(junction.p.x, junction.p.y, junction.w),
    ];
    final clips = <c2.Path64>[
      for (final polygon in clippedLower)
        if (polygon.points.length >= 3)
          [
            for (final point in polygon.points)
              c2.Point64(point.x, point.y, 0),
          ],
    ];

    final supported = _clipExtrusion(
      subject,
      clips,
      c2.ClipType.intersection,
    );
    final unsupported = _clipExtrusion(
      subject,
      clips,
      c2.ClipType.difference,
    );

    final variableWidth = SourceVariableWidth2();
    final paths = <ExtrusionPath2>[];
    for (final thick in supported) {
      paths.addAll(
        variableWidth
            .thickPolylineToMultiPath(
              thick,
              supportedRole,
              supportedFlow,
              SourceVariableWidth2.qidiTolerance,
              Slic3rUnits.scaledEpsilon.toDouble(),
              0,
            )
            .paths,
      );
    }

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

    var startPoint = paths.first.firstPoint;
    if (!extrusion.isClosed) {
      final occurrence = <SourcePoint2, _SourceArachneEndpointInfo2>{};
      for (final path in paths) {
        for (final point in [path.firstPoint, path.lastPoint]) {
          final info = occurrence.putIfAbsent(
            point,
            _SourceArachneEndpointInfo2.new,
          );
          info.occurrence++;
          if (path.role == ExtrusionRole.overhangPerimeter) {
            info.isOverhang = true;
          }
        }
      }

      // Pinned source iterates an unordered_map. The represented fixtures avoid
      // ambiguous multiple non-overhang endpoints; preserve the source rule of
      // selecting an occurrence-one endpoint and preferring a supported one.
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
    return List.unmodifiable([
      for (final entity in entities) entity as ExtrusionPath2,
    ]);
  }

  static List<ThickPolyline2> _clipExtrusion(
    c2.Path64 subject,
    c2.Paths64 clips,
    c2.ClipType clipType,
  ) {
    if (subject.length < 2) return const [];
    if (clips.isEmpty) {
      if (clipType == c2.ClipType.intersection) return const [];
      return [_toThickPolyline(subject)];
    }

    final clipper = c2.Clipper64();
    clipper.zCallback = (e1Bottom, e1Top, e2Bottom, e2Top, point) {
      assert((e1Bottom.z == 0) == (e1Top.z == 0));
      assert((e2Bottom.z == 0) == (e2Top.z == 0));

      var start = e1Bottom;
      var end = e1Top;
      if (start.z <= 0 && end.z <= 0) {
        start = e2Bottom;
        end = e2Top;
      }
      if (start.z <= 0 && end.z <= 0) return 0;

      assert(start.z > 0 && end.z > 0);
      final dx = end.x - start.x;
      final dy = end.y - start.y;
      final lengthSquared = dx * dx + dy * dy;
      if (lengthSquared == 0) return start.z;
      final px = point.x - start.x;
      final py = point.y - start.y;
      final distanceSquared = px * px + py * py;
      final t = math.sqrt(distanceSquared / lengthSquared);
      return start.z + ((end.z - start.z) * t).toInt();
    };

    clipper
      ..addOpenSubject(subject)
      ..addClips(clips);
    final solution = clipper.execute(clipType, c2.FillRule.nonZero);
    if (solution == null) return const [];

    final result = <ThickPolyline2>[];
    for (final rawPath in solution.open) {
      if (rawPath.length < 2) continue;
      final repaired = <c2.Point64>[...rawPath];
      for (var index = 0; index < repaired.length; index++) {
        if (repaired[index].z != 0) continue;
        repaired[index] = _repairZeroWidth(repaired[index], subject);
      }
      if (repaired.any((point) => point.z <= 0)) {
        throw StateError('Pinned clip_extrusion produced non-positive width');
      }
      result.add(_toThickPolyline(repaired));
    }
    return List.unmodifiable(result);
  }

  static c2.Point64 _repairZeroWidth(
    c2.Point64 point,
    c2.Path64 subject,
  ) {
    if (subject.length <= 2) return point;

    var bestDistanceSquared = double.maxFinite;
    var bestSegment = -1;
    var bestX = 0.0;
    var bestY = 0.0;
    for (var index = 0; index + 1 < subject.length; index++) {
      final a = subject[index];
      final b = subject[index + 1];
      final dx = (b.x - a.x).toDouble();
      final dy = (b.y - a.y).toDouble();
      final lengthSquared = dx * dx + dy * dy;
      if (lengthSquared == 0) continue;
      var t = ((point.x - a.x) * dx + (point.y - a.y) * dy) /
          lengthSquared;
      if (t < 0) t = 0;
      if (t > 1) t = 1;
      final projectedX = a.x + dx * t;
      final projectedY = a.y + dy * t;
      final px = point.x - projectedX;
      final py = point.y - projectedY;
      final distanceSquared = px * px + py * py;
      if (distanceSquared < bestDistanceSquared) {
        bestDistanceSquared = distanceSquared;
        bestSegment = index;
        bestX = projectedX;
        bestY = projectedY;
      }
    }
    if (bestSegment < 0 ||
        bestDistanceSquared > Slic3rUnits.scaledEpsilon.toDouble()) {
      return point;
    }

    final a = subject[bestSegment];
    final b = subject[bestSegment + 1];
    final lineDx = (b.x - a.x).toDouble();
    final lineDy = (b.y - a.y).toDouble();
    final lineLength = math.sqrt(lineDx * lineDx + lineDy * lineDy);
    if (lineLength == 0) return point;
    final distDx = bestX - a.x;
    final distDy = bestY - a.y;
    final distance = math.sqrt(distDx * distDx + distDy * distDy);
    final width = a.z +
        ((distance / lineLength) * (b.z - a.z).toDouble()).toInt();
    return c2.Point64(point.x, point.y, width);
  }

  static ThickPolyline2 _toThickPolyline(c2.Path64 path) {
    if (path.length < 2) {
      throw StateError('Pinned ZPath to_thick_polyline requires >= 2 points');
    }
    final points = <SourcePoint2>[
      SourcePoint2(path[0].x, path[0].y),
      SourcePoint2(path[1].x, path[1].y),
    ];
    final widths = <double>[
      path[0].z.toDouble(),
      path[1].z.toDouble(),
    ];
    var previous = path[1];
    for (var index = 2; index < path.length; index++) {
      final current = path[index];
      points.add(SourcePoint2(current.x, current.y));
      widths
        ..add(previous.z.toDouble())
        ..add(current.z.toDouble());
      previous = current;
    }
    return ThickPolyline2(points: points, width: widths);
  }
}

class _SourceArachneEndpointInfo2 {
  int occurrence = 0;
  bool isOverhang = false;
}
