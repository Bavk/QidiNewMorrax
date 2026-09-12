import 'package:clipper2/clipper2.dart' as c2;

import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import '../geometry/source_polyline.dart';
import 'source_arachne_extrusion_line.dart';

class SourcePolylineClipSegment2 {
  const SourcePolylineClipSegment2({
    required this.polyline,
    required this.clipIndex,
  });

  final SourcePolyline2 polyline;
  final int clipIndex;
}

class SourceExtrusionClipSegment2 {
  const SourceExtrusionClipSegment2({
    required this.extrusion,
    required this.clipIndex,
  });

  final SourceArachneExtrusionLine2 extrusion;
  final int clipIndex;
}

class SourceLineSegmentationRegion2<T> {
  SourceLineSegmentationRegion2({
    required Iterable<SourceExPolygon2> expolygons,
    required this.value,
  }) : expolygons = List.unmodifiable(expolygons);

  final List<SourceExPolygon2> expolygons;
  final T value;
}

class SourcePolylineRegionSegment2<T> {
  const SourcePolylineRegionSegment2({
    required this.polyline,
    required this.value,
  });

  final SourcePolyline2 polyline;
  final T value;
}

class SourceExtrusionRegionSegment2<T> {
  const SourceExtrusionRegionSegment2({
    required this.extrusion,
    required this.value,
  });

  final SourceArachneExtrusionLine2 extrusion;
  final T value;
}

/// Source-shaped Polyline/Polygon/Arachne subset of
/// `Algorithm/LineSegmentation/LineSegmentation.cpp`.
///
/// QIDI carries subject indexes through Clipper-Z. `clipper2 0.0.3` exposes a
/// Z callback as well, so intersection points use the same 32-bit ZAttributes
/// layout. The Dart port currently drops the input Z on some surviving open
/// terminal endpoints; [_repairLostSubjectVertexZ] restores only those points
/// whose decoded source index is inconsistent with their exact XY coordinate.
class SourceLineSegmentation2 {
  const SourceLineSegmentation2._();

  static const double _pointOnLineThresholdSquared = 100.0;

  static List<SourcePolylineClipSegment2> polylineSegmentation({
    required SourcePolyline2 subject,
    required List<List<SourceExPolygon2>> clipGroups,
    int defaultClipIndex = 0,
  }) {
    if (subject.points.length < 2) {
      throw StateError('source line segmentation requires at least two points');
    }
    _validateDefaultClipIndex(defaultClipIndex);

    final subjectPath = _subjectPath(subject.points);
    final ranges = _subjectSegmentation(
      subjectPath,
      clipGroups,
      defaultClipIndex,
    );
    if (ranges.isEmpty) {
      return [
        SourcePolylineClipSegment2(
          polyline: subject.copy(),
          clipIndex: defaultClipIndex,
        ),
      ];
    }
    if (ranges.length == 1) {
      return [
        SourcePolylineClipSegment2(
          polyline: subject.copy(),
          clipIndex: ranges.single.clipIndex,
        ),
      ];
    }

    return List.unmodifiable([
      for (final range in ranges)
        SourcePolylineClipSegment2(
          polyline: _createPolylineSegment(range, subject),
          clipIndex: range.clipIndex,
        ),
    ]);
  }

  static List<SourcePolylineClipSegment2> polygonSegmentation({
    required SourcePolygon2 subject,
    required List<List<SourceExPolygon2>> clipGroups,
    int defaultClipIndex = 0,
  }) {
    if (subject.points.length < 3) {
      throw StateError(
        'source polygon segmentation requires at least three points',
      );
    }
    return polylineSegmentation(
      subject: SourcePolyline2([
        ...subject.points,
        subject.points.first,
      ]),
      clipGroups: clipGroups,
      defaultClipIndex: defaultClipIndex,
    );
  }

  static List<SourceExtrusionClipSegment2> extrusionSegmentation({
    required SourceArachneExtrusionLine2 subject,
    required List<List<SourceExPolygon2>> clipGroups,
    int defaultClipIndex = 0,
  }) {
    if (subject.junctions.length < 2) {
      throw StateError(
        'source extrusion segmentation requires at least two junctions',
      );
    }
    _validateDefaultClipIndex(defaultClipIndex);

    // Closed Arachne ExtrusionLine already duplicates its closing point.
    final subjectPath = _subjectPath([
      for (final junction in subject.junctions) junction.p,
    ]);
    final ranges = _subjectSegmentation(
      subjectPath,
      clipGroups,
      defaultClipIndex,
    );
    if (ranges.isEmpty) {
      return [
        SourceExtrusionClipSegment2(
          extrusion: subject.copy(),
          clipIndex: defaultClipIndex,
        ),
      ];
    }
    if (ranges.length == 1) {
      return [
        SourceExtrusionClipSegment2(
          extrusion: subject.copy(),
          clipIndex: ranges.single.clipIndex,
        ),
      ];
    }

    return List.unmodifiable([
      for (final range in ranges)
        SourceExtrusionClipSegment2(
          extrusion: _createExtrusionSegment(range, subject),
          clipIndex: range.clipIndex,
        ),
    ]);
  }

  static List<SourcePolylineRegionSegment2<T>> polylineRegionSegmentation<T>({
    required SourcePolyline2 subject,
    required T baseValue,
    required List<SourceLineSegmentationRegion2<T>> regions,
  }) {
    final segmented = polylineSegmentation(
      subject: subject,
      clipGroups: [for (final region in regions) region.expolygons],
    );
    return List.unmodifiable([
      for (final segment in segmented)
        SourcePolylineRegionSegment2<T>(
          polyline: segment.polyline,
          value: segment.clipIndex == 0
              ? baseValue
              : regions[segment.clipIndex - 1].value,
        ),
    ]);
  }

  static List<SourcePolylineRegionSegment2<T>> polygonRegionSegmentation<T>({
    required SourcePolygon2 subject,
    required T baseValue,
    required List<SourceLineSegmentationRegion2<T>> regions,
  }) {
    if (subject.points.length < 3) {
      throw StateError(
        'source polygon segmentation requires at least three points',
      );
    }
    return polylineRegionSegmentation(
      subject: SourcePolyline2([
        ...subject.points,
        subject.points.first,
      ]),
      baseValue: baseValue,
      regions: regions,
    );
  }

  static List<SourceExtrusionRegionSegment2<T>> extrusionRegionSegmentation<T>({
    required SourceArachneExtrusionLine2 subject,
    required T baseValue,
    required List<SourceLineSegmentationRegion2<T>> regions,
  }) {
    final segmented = extrusionSegmentation(
      subject: subject,
      clipGroups: [for (final region in regions) region.expolygons],
    );
    return List.unmodifiable([
      for (final segment in segmented)
        SourceExtrusionRegionSegment2<T>(
          extrusion: segment.extrusion,
          value: segment.clipIndex == 0
              ? baseValue
              : regions[segment.clipIndex - 1].value,
        ),
    ]);
  }

  static List<_SourceLineRegionRange2> _subjectSegmentation(
    c2.Path64 subject,
    List<List<SourceExPolygon2>> clipGroups,
    int defaultClipIndex,
  ) {
    final ranges = <_SourceLineRegionRange2>[];
    for (var groupIndex = 0; groupIndex < clipGroups.length; groupIndex++) {
      final clips = _clipPaths(clipGroups[groupIndex]);
      if (clips.isEmpty) continue;
      ranges.addAll(_intersectionWithRegion(
        subject,
        clips,
        groupIndex + defaultClipIndex + 1,
      ));
    }
    return _createContinuousRanges(
      ranges,
      defaultClipIndex,
      subject.length - 1,
    );
  }

  static List<_SourceLineRegionRange2> _intersectionWithRegion(
    c2.Path64 subject,
    c2.Paths64 clips,
    int regionIndex,
  ) {
    final clipper = c2.Clipper64();
    clipper.preserveCollinear = true;
    clipper.zCallback = (edge1Bottom, edge1Top, edge2Bottom, edge2Top, _) {
      final edge1BottomZ = _SourceZAttributes2.decode(edge1Bottom.z);
      final edge1TopZ = _SourceZAttributes2.decode(edge1Top.z);
      final edge2BottomZ = _SourceZAttributes2.decode(edge2Bottom.z);
      final edge2TopZ = _SourceZAttributes2.decode(edge2Top.z);

      if (edge1BottomZ.isClipPoint != edge1TopZ.isClipPoint ||
          edge2BottomZ.isClipPoint != edge2TopZ.isClipPoint) {
        throw StateError('source LineSegmentation edge Z identity mismatch');
      }

      if (!edge1BottomZ.isClipPoint && !edge1TopZ.isClipPoint) {
        _requireAdjacentSubjectIndexes(edge1BottomZ, edge1TopZ);
        return _SourceZAttributes2(
          isNewPoint: true,
          pointIndex: _minInt(
            edge1BottomZ.pointIndex,
            edge1TopZ.pointIndex,
          ),
        ).encode();
      }
      if (!edge2BottomZ.isClipPoint && !edge2TopZ.isClipPoint) {
        _requireAdjacentSubjectIndexes(edge2BottomZ, edge2TopZ);
        return _SourceZAttributes2(
          isNewPoint: true,
          pointIndex: _minInt(
            edge2BottomZ.pointIndex,
            edge2TopZ.pointIndex,
          ),
        ).encode();
      }
      throw StateError(
        'source LineSegmentation intersection has no subject edge',
      );
    };

    clipper.addOpenSubject(subject);
    clipper.addClips(clips);
    final solution = clipper.execute(c2.ClipType.intersection, c2.FillRule.nonZero);
    if (solution == null) return const [];

    final ranges = <_SourceLineRegionRange2>[];
    for (final intersection in solution.open) {
      final range = _createLineRegionRange(
        intersection,
        subject,
        regionIndex,
      );
      if (range != null) ranges.add(range);
    }
    return ranges;
  }

  static _SourceLineRegionRange2? _createLineRegionRange(
    c2.Path64 intersection,
    c2.Path64 subject,
    int regionIndex,
  ) {
    if (intersection.length < 2) return null;

    final normalized = <c2.Point64>[...intersection];
    for (var index = 0; index < normalized.length; index++) {
      var point = normalized[index];
      var z = _SourceZAttributes2.decode(point.z);

      if (!z.isClipPoint && !z.isNewPoint) {
        final repaired = _repairLostSubjectVertexZ(point, z, subject);
        if (repaired != null) {
          normalized[index] = repaired;
          point = repaired;
          z = _SourceZAttributes2.decode(repaired.z);
        }
      }

      if (!z.isClipPoint) continue;

      final subjectLineIndex = _findClosestLineToPoint(subject, point);
      if (subjectLineIndex != null) {
        normalized[index] = c2.Point64(
          point.x,
          point.y,
          _SourceZAttributes2(
            isNewPoint: true,
            pointIndex: subjectLineIndex,
          ).encode(),
        );
      }

      if (_SourceZAttributes2.decode(normalized[index].z).isClipPoint) {
        return null;
      }
    }

    if (_needReverse(normalized, subject)) {
      normalized.setAll(0, normalized.reversed.toList(growable: false));
    }

    final beginZ = _SourceZAttributes2.decode(normalized.first.z);
    final endZ = _SourceZAttributes2.decode(normalized.last.z);
    final beginIndex = beginZ.pointIndex;
    final endIndex = endZ.pointIndex;
    if (beginIndex >= subject.length || endIndex >= subject.length) return null;
    if (beginZ.isNewPoint && beginIndex + 1 >= subject.length) return null;
    if (endZ.isNewPoint && endIndex + 1 >= subject.length) return null;

    final beginT = beginZ.isNewPoint
        ? _projectPointOnLine(
            subject[beginIndex],
            subject[beginIndex + 1],
            normalized.first,
          ).t
        : 0.0;
    final endT = endZ.isNewPoint
        ? _projectPointOnLine(
            subject[endIndex],
            subject[endIndex + 1],
            normalized.last,
          ).t
        : 0.0;
    if (beginT == double.maxFinite || endT == double.maxFinite) return null;

    return _SourceLineRegionRange2(
      beginIndex: beginIndex,
      beginT: beginT,
      endIndex: endIndex,
      endT: endT,
      clipIndex: regionIndex,
    );
  }

  static c2.Point64? _repairLostSubjectVertexZ(
    c2.Point64 point,
    _SourceZAttributes2 z,
    c2.Path64 subject,
  ) {
    if (z.pointIndex < subject.length) {
      final indexed = subject[z.pointIndex];
      if (indexed.x == point.x && indexed.y == point.y) return null;
    }

    int? exactIndex;
    for (var index = 0; index < subject.length; index++) {
      final candidate = subject[index];
      if (candidate.x != point.x || candidate.y != point.y) continue;
      if (exactIndex != null) {
        // Ambiguous equal-XY endpoints (for example a closed seam) retain the
        // Z supplied by Clipper rather than inventing a source index.
        return null;
      }
      exactIndex = index;
    }
    if (exactIndex == null) return null;

    return c2.Point64(
      point.x,
      point.y,
      _SourceZAttributes2(pointIndex: exactIndex).encode(),
    );
  }

  static bool _needReverse(c2.Path64 intersection, c2.Path64 subject) {
    for (var index = 1; index < intersection.length; index++) {
      final previous = intersection[index - 1];
      final current = intersection[index];
      final previousZ = _SourceZAttributes2.decode(previous.z);
      final currentZ = _SourceZAttributes2.decode(current.z);
      if (previousZ.isClipPoint || currentZ.isClipPoint) continue;

      final maxPointIndex = subject.length - 1;
      var validOrder = previousZ.pointIndex <= currentZ.pointIndex;
      if (currentZ.pointIndex == maxPointIndex && previousZ.pointIndex == 0) {
        validOrder = false;
      }
      if (currentZ.pointIndex == 0 && previousZ.pointIndex == maxPointIndex) {
        validOrder = true;
      }

      if (!validOrder && _sourcePoint(previous) != _sourcePoint(current)) {
        return true;
      }
      if (currentZ.pointIndex == previousZ.pointIndex) {
        if (currentZ.pointIndex >= subject.length) return false;
        final subjectPoint = subject[currentZ.pointIndex];
        final previousDistance = _squaredDistance(previous, subjectPoint);
        final currentDistance = _squaredDistance(current, subjectPoint);
        if (previousDistance > currentDistance) return true;
      }
    }
    return false;
  }

  static int? _findClosestLineToPoint(c2.Path64 subject, c2.Point64 query) {
    int? closest;
    var minDistanceSquared = double.maxFinite;
    for (var lineIndex = 0; lineIndex + 1 < subject.length; lineIndex++) {
      final projection = _projectPointOnLine(
        subject[lineIndex],
        subject[lineIndex + 1],
        query,
      );
      if (projection.distanceSquared <= _pointOnLineThresholdSquared) {
        return lineIndex;
      }
      if (projection.distanceSquared < minDistanceSquared) {
        minDistanceSquared = projection.distanceSquared;
        closest = lineIndex;
      }
    }
    return closest;
  }

  static _SourceProjectionInfo2 _projectPointOnLine(
    c2.Point64 from,
    c2.Point64 to,
    c2.Point64 query,
  ) {
    final lineX = (to.x - from.x).toDouble();
    final lineY = (to.y - from.y).toDouble();
    final queryX = (query.x - from.x).toDouble();
    final queryY = (query.y - from.y).toDouble();
    final lengthSquared = lineX * lineX + lineY * lineY;
    if (lengthSquared <= 0) {
      return const _SourceProjectionInfo2(
        t: double.maxFinite,
        distanceSquared: double.maxFinite,
      );
    }

    final projected = queryX * lineX + queryY * lineY;
    final t = (projected / lengthSquared).clamp(0.0, 1.0).toDouble();
    if (projected < 0 || projected > lengthSquared) {
      return _SourceProjectionInfo2(
        t: t,
        distanceSquared: double.maxFinite,
      );
    }

    final projectedX = t * lineX;
    final projectedY = t * lineY;
    final dx = projectedX - queryX;
    final dy = projectedY - queryY;
    return _SourceProjectionInfo2(
      t: t,
      distanceSquared: dx * dx + dy * dy,
    );
  }

  static List<_SourceLineRegionRange2> _createContinuousRanges(
    List<_SourceLineRegionRange2> ranges,
    int defaultClipIndex,
    int totalLineCount,
  ) {
    if (ranges.isEmpty) return const [];
    ranges.sort(_compareRange);

    for (var index = 1; index < ranges.length; index++) {
      final previous = ranges[index - 1];
      final current = ranges[index];
      if (previous.isInside(current)) {
        final saved = previous.copy();
        current
          ..beginIndex = saved.beginIndex
          ..beginT = saved.beginT
          ..endIndex = saved.endIndex
          ..endT = saved.endT
          ..clipIndex = saved.clipIndex;
        previous
          ..beginIndex = current.beginIndex
          ..beginT = current.beginT
          ..endIndex = current.beginIndex
          ..endT = current.beginT;
      } else if (previous.overlaps(current)) {
        current
          ..beginIndex = previous.endIndex
          ..beginT = previous.endT;
      }
    }

    final output = <_SourceLineRegionRange2>[];
    var previousLineIndex = 0;
    var previousT = 0.0;
    for (final current in ranges) {
      if (current.isZeroLength) continue;
      if (previousLineIndex != current.beginIndex ||
          previousT != current.beginT) {
        output.add(_SourceLineRegionRange2(
          beginIndex: previousLineIndex,
          beginT: previousT,
          endIndex: current.beginIndex,
          endT: current.beginT,
          clipIndex: defaultClipIndex,
        ));
      }
      output.add(current.copy());
      previousLineIndex = current.endIndex;
      previousT = current.endT;
    }

    final lastLineIndex = totalLineCount - 1;
    if ((previousLineIndex == lastLineIndex && previousT == 1.0) ||
        (previousLineIndex == totalLineCount && previousT == 0.0)) {
      return output;
    }
    output.add(_SourceLineRegionRange2(
      beginIndex: previousLineIndex,
      beginT: previousT,
      endIndex: lastLineIndex,
      endT: 1.0,
      clipIndex: defaultClipIndex,
    ));
    return output;
  }

  static SourcePolyline2 _createPolylineSegment(
    _SourceLineRegionRange2 range,
    SourcePolyline2 subject,
  ) {
    final points = <SourcePoint2>[];
    if (range.beginT == 0.0) {
      points.add(subject.points[range.beginIndex]);
    } else {
      points.add(_sourceLerpPoint(
        subject.points[range.beginIndex],
        subject.points[range.beginIndex + 1],
        range.beginT,
      ));
    }

    for (var lineIndex = range.beginIndex + 1;
        lineIndex <= range.endIndex;
        lineIndex++) {
      points.add(subject.points[lineIndex]);
    }

    if (range.endT == 0.0) {
      points.add(subject.points[range.endIndex]);
    } else if (range.endT == 1.0) {
      points.add(subject.points[range.endIndex + 1]);
    } else {
      points.add(_sourceLerpPoint(
        subject.points[range.endIndex],
        subject.points[range.endIndex + 1],
        range.endT,
      ));
    }
    return SourcePolyline2(points);
  }

  static SourceArachneExtrusionLine2 _createExtrusionSegment(
    _SourceLineRegionRange2 range,
    SourceArachneExtrusionLine2 subject,
  ) {
    final junctions = <SourceArachneExtrusionJunction2>[];
    if (range.beginT == 0.0) {
      junctions.add(subject.junctions[range.beginIndex].copy());
    } else {
      final from = subject.junctions[range.beginIndex];
      final to = subject.junctions[range.beginIndex + 1];
      if (from.perimeterIndex != to.perimeterIndex) {
        throw StateError(
          'source extrusion segmentation requires equal perimeter indexes '
          'across interpolated junctions',
        );
      }
      junctions.add(SourceArachneExtrusionJunction2(
        p: _sourceLerpPoint(from.p, to.p, range.beginT),
        w: _sourceLerpWidth(from.w, to.w, range.beginT),
        perimeterIndex: from.perimeterIndex,
      ));
    }

    for (var lineIndex = range.beginIndex + 1;
        lineIndex <= range.endIndex;
        lineIndex++) {
      junctions.add(subject.junctions[lineIndex].copy());
    }

    if (range.endT == 0.0) {
      junctions.add(subject.junctions[range.endIndex].copy());
    } else if (range.endT == 1.0) {
      junctions.add(subject.junctions[range.endIndex + 1].copy());
    } else {
      final from = subject.junctions[range.endIndex];
      final to = subject.junctions[range.endIndex + 1];
      if (from.perimeterIndex != to.perimeterIndex) {
        throw StateError(
          'source extrusion segmentation requires equal perimeter indexes '
          'across interpolated junctions',
        );
      }
      junctions.add(SourceArachneExtrusionJunction2(
        p: _sourceLerpPoint(from.p, to.p, range.endT),
        w: _sourceLerpWidth(from.w, to.w, range.endT),
        perimeterIndex: from.perimeterIndex,
      ));
    }

    // The source two-argument ExtrusionLine constructor forces split segments
    // open even when the original line is closed.
    return SourceArachneExtrusionLine2(
      insetIndex: subject.insetIndex,
      isOdd: subject.isOdd,
      junctions: junctions,
    );
  }

  static SourcePoint2 _sourceLerpPoint(
    SourcePoint2 a,
    SourcePoint2 b,
    double t,
  ) {
    // `lerp(Point, Point, double)` evaluates `(1-t)*a + t*b`; QIDI Point's
    // scalar multiplication truncates each product to coord_t before addition.
    final oneMinusT = 1.0 - t;
    return SourcePoint2(
      (a.x * oneMinusT).truncate() + (b.x * t).truncate(),
      (a.y * oneMinusT).truncate() + (b.y * t).truncate(),
    );
  }

  static int _sourceLerpWidth(int a, int b, double t) =>
      ((1.0 - t) * a + t * b).truncate();

  static c2.Path64 _subjectPath(List<SourcePoint2> points) {
    return [
      for (var index = 0; index < points.length; index++)
        c2.Point64(
          points[index].x,
          points[index].y,
          _SourceZAttributes2(pointIndex: index).encode(),
        ),
    ];
  }

  static c2.Paths64 _clipPaths(List<SourceExPolygon2> expolygons) {
    final clipZ = const _SourceZAttributes2(isClipPoint: true).encode();
    return [
      for (final expolygon in expolygons) ...[
        [
          for (final point in expolygon.contour.points)
            c2.Point64(point.x, point.y, clipZ),
        ],
        for (final hole in expolygon.holes)
          [
            for (final point in hole.points)
              c2.Point64(point.x, point.y, clipZ),
          ],
      ],
    ];
  }

  static SourcePoint2 _sourcePoint(c2.Point64 point) =>
      SourcePoint2(point.x, point.y);

  static double _squaredDistance(c2.Point64 a, c2.Point64 b) {
    final dx = (a.x - b.x).toDouble();
    final dy = (a.y - b.y).toDouble();
    return dx * dx + dy * dy;
  }

  static int _compareRange(
    _SourceLineRegionRange2 a,
    _SourceLineRegionRange2 b,
  ) {
    final indexCompare = a.beginIndex.compareTo(b.beginIndex);
    return indexCompare != 0 ? indexCompare : a.beginT.compareTo(b.beginT);
  }

  static void _validateDefaultClipIndex(int defaultClipIndex) {
    if (defaultClipIndex < 0) {
      throw ArgumentError.value(
        defaultClipIndex,
        'defaultClipIndex',
        'must be >= 0',
      );
    }
  }

  static void _requireAdjacentSubjectIndexes(
    _SourceZAttributes2 a,
    _SourceZAttributes2 b,
  ) {
    if ((a.pointIndex - b.pointIndex).abs() != 1) {
      throw StateError(
        'source LineSegmentation intersection edge indexes are not adjacent',
      );
    }
  }

  static int _minInt(int a, int b) => a < b ? a : b;
}

class _SourceZAttributes2 {
  const _SourceZAttributes2({
    this.isClipPoint = false,
    this.isNewPoint = false,
    this.pointIndex = 0,
  });

  final bool isClipPoint;
  final bool isNewPoint;
  final int pointIndex;

  int encode() {
    if (pointIndex < 0 || pointIndex >= (1 << 30)) {
      throw StateError('source LineSegmentation point index exceeds 30 bits');
    }
    return (isClipPoint ? 1 << 31 : 0) |
        (isNewPoint ? 1 << 30 : 0) |
        (pointIndex & 0x3fffffff);
  }

  static _SourceZAttributes2 decode(int raw) {
    final value = raw & 0xffffffff;
    return _SourceZAttributes2(
      isClipPoint: (value & (1 << 31)) != 0,
      isNewPoint: (value & (1 << 30)) != 0,
      pointIndex: value & 0x3fffffff,
    );
  }
}

class _SourceProjectionInfo2 {
  const _SourceProjectionInfo2({
    required this.t,
    required this.distanceSquared,
  });

  final double t;
  final double distanceSquared;
}

class _SourceLineRegionRange2 {
  _SourceLineRegionRange2({
    required this.beginIndex,
    required this.beginT,
    required this.endIndex,
    required this.endT,
    required this.clipIndex,
  });

  int beginIndex;
  double beginT;
  int endIndex;
  double endT;
  int clipIndex;

  bool overlaps(_SourceLineRegionRange2 other) {
    if (endIndex < other.beginIndex || beginIndex > other.endIndex) {
      return false;
    }
    if (endIndex == other.beginIndex && endT <= other.beginT) return false;
    if (beginIndex == other.endIndex && beginT >= other.endT) return false;
    return true;
  }

  bool isInside(_SourceLineRegionRange2 inner) {
    if (!overlaps(inner)) return false;
    final startsAfter = beginIndex < inner.beginIndex ||
        (beginIndex == inner.beginIndex && beginT <= inner.beginT);
    final endsBefore = endIndex > inner.endIndex ||
        (endIndex == inner.endIndex && endT >= inner.endT);
    return startsAfter && endsBefore;
  }

  bool get isZeroLength => beginIndex == endIndex && beginT == endT;

  _SourceLineRegionRange2 copy() => _SourceLineRegionRange2(
        beginIndex: beginIndex,
        beginT: beginT,
        endIndex: endIndex,
        endT: endT,
        clipIndex: clipIndex,
      );
}
