import '../geometry/clipper_geometry.dart';
import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import '../geometry/source_polyline.dart';

class SourcePolylineClipSegment2 {
  const SourcePolylineClipSegment2({
    required this.polyline,
    required this.clipIndex,
  });

  final SourcePolyline2 polyline;
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

/// Source-shaped port of the Polyline/Polygon subset of
/// `Algorithm/LineSegmentation/LineSegmentation.cpp`.
///
/// QIDI carries source-point indexes through a Clipper-Z channel. The current
/// pure-Dart Clipper2 package has no Z callback, so this port reconstructs the
/// same `(line_index, t)` attributes by projecting returned intersection
/// endpoints back onto the integer source polyline with QIDI's 10-coordinate
/// `SCALED_EPSILON` threshold. The range ordering, default-gap fill, overlap
/// precedence, segment construction and polygon closing behavior are literal to
/// the pinned source.
class SourceLineSegmentation2 {
  const SourceLineSegmentation2._();

  static const double _pointOnLineThresholdSquared = 100.0;
  static const ClipperGeometry _clipper = ClipperGeometry();

  static List<SourcePolylineClipSegment2> polylineSegmentation({
    required SourcePolyline2 subject,
    required List<List<SourceExPolygon2>> clipGroups,
    int defaultClipIndex = 0,
  }) {
    if (subject.points.length < 2) {
      throw StateError('source line segmentation requires at least two points');
    }
    if (defaultClipIndex < 0) {
      throw ArgumentError.value(
        defaultClipIndex,
        'defaultClipIndex',
        'must be >= 0',
      );
    }

    final ranges = <_SourceLineRegionRange2>[];
    for (var groupIndex = 0; groupIndex < clipGroups.length; groupIndex++) {
      final clip = <SourcePolygon2>[
        for (final expolygon in clipGroups[groupIndex]) ...[
          expolygon.contour,
          ...expolygon.holes,
        ],
      ];
      if (clip.isEmpty) continue;

      final intersections = _clipper.intersectionSourceOpenPolylines(
        [subject],
        clip,
      );
      for (final intersection in intersections) {
        final range = _rangeFromIntersection(
          intersection,
          subject,
          groupIndex + defaultClipIndex + 1,
        );
        if (range != null) ranges.add(range);
      }
    }

    final continuous = _createContinuousRanges(
      ranges,
      defaultClipIndex,
      subject.points.length - 1,
    );
    if (continuous.isEmpty) {
      return [
        SourcePolylineClipSegment2(
          polyline: subject.copy(),
          clipIndex: defaultClipIndex,
        ),
      ];
    }
    if (continuous.length == 1) {
      return [
        SourcePolylineClipSegment2(
          polyline: subject.copy(),
          clipIndex: continuous.single.clipIndex,
        ),
      ];
    }

    return List.unmodifiable([
      for (final range in continuous)
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
      throw StateError('source polygon segmentation requires at least three points');
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

  static List<SourcePolylineRegionSegment2<T>> polylineRegionSegmentation<T>({
    required SourcePolyline2 subject,
    required T baseValue,
    required List<SourceLineSegmentationRegion2<T>> regions,
  }) {
    final segmented = polylineSegmentation(
      subject: subject,
      clipGroups: [
        for (final region in regions) region.expolygons,
      ],
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
      throw StateError('source polygon segmentation requires at least three points');
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

  static _SourceLineRegionRange2? _rangeFromIntersection(
    SourcePolyline2 intersection,
    SourcePolyline2 subject,
    int clipIndex,
  ) {
    if (intersection.points.length < 2) return null;

    final firstNeighbor = intersection.points[1];
    final lastNeighbor = intersection.points[intersection.points.length - 2];
    var begin = _locatePoint(subject, intersection.points.first, firstNeighbor);
    var end = _locatePoint(subject, intersection.points.last, lastNeighbor);
    if (begin == null || end == null) return null;

    if (_comparePosition(begin, end) > 0) {
      final swap = begin;
      begin = end;
      end = swap;
    }

    return _SourceLineRegionRange2(
      beginIndex: begin.lineIndex,
      beginT: begin.t,
      endIndex: end.lineIndex,
      endT: end.t,
      clipIndex: clipIndex,
    );
  }

  static _SourceLinePosition2? _locatePoint(
    SourcePolyline2 subject,
    SourcePoint2 query,
    SourcePoint2 neighbor,
  ) {
    final exactIndexes = <int>[];
    for (var index = 0; index < subject.points.length; index++) {
      if (subject.points[index] == query) exactIndexes.add(index);
    }
    if (exactIndexes.length == 1) {
      return _SourceLinePosition2(exactIndexes.single, 0);
    }
    if (exactIndexes.length > 1) {
      // Polygon segmentation represents a closed polygon as an open polyline
      // whose first point is repeated at the end. In source Clipper-Z those
      // equal XY points retain distinct subject indexes. Reconstruct that
      // distinction from the adjacent intersection point before falling back
      // to geometric projection, otherwise a fully covered polygon collapses
      // to the zero-length [0,0] range.
      final lastIndex = subject.points.length - 1;
      if (subject.points.first == subject.points.last &&
          exactIndexes.first == 0 &&
          exactIndexes.last == lastIndex &&
          lastIndex >= 2) {
        if (neighbor == subject.points[1]) {
          return const _SourceLinePosition2(0, 0);
        }
        if (neighbor == subject.points[lastIndex - 1]) {
          return _SourceLinePosition2(lastIndex, 0);
        }
      }

      final neighborLine = _findClosestLineToPoint(subject, neighbor);
      if (neighborLine != null) {
        for (final index in exactIndexes) {
          if (index == neighborLine) return _SourceLinePosition2(index, 0);
          if (index > 0 && index - 1 == neighborLine) {
            return _SourceLinePosition2(index, 0);
          }
        }
      }
      return _SourceLinePosition2(exactIndexes.first, 0);
    }

    final lineIndex = _findClosestLineToPoint(subject, query);
    if (lineIndex == null) return null;
    final projection = _projectPointOnLine(
      subject.points[lineIndex],
      subject.points[lineIndex + 1],
      query,
    );
    if (!projection.t.isFinite || !projection.distanceSquared.isFinite) {
      return null;
    }
    return _SourceLinePosition2(lineIndex, projection.t);
  }

  static int? _findClosestLineToPoint(
    SourcePolyline2 subject,
    SourcePoint2 query,
  ) {
    int? closest;
    var minDistanceSquared = double.infinity;
    for (var lineIndex = 0;
        lineIndex + 1 < subject.points.length;
        lineIndex++) {
      final projection = _projectPointOnLine(
        subject.points[lineIndex],
        subject.points[lineIndex + 1],
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
    SourcePoint2 from,
    SourcePoint2 to,
    SourcePoint2 query,
  ) {
    final lineX = (to.x - from.x).toDouble();
    final lineY = (to.y - from.y).toDouble();
    final queryX = (query.x - from.x).toDouble();
    final queryY = (query.y - from.y).toDouble();
    final lengthSquared = lineX * lineX + lineY * lineY;
    if (lengthSquared <= 0) {
      return const _SourceProjectionInfo2(
        t: double.infinity,
        distanceSquared: double.infinity,
      );
    }

    final projected = queryX * lineX + queryY * lineY;
    final t = (projected / lengthSquared).clamp(0.0, 1.0).toDouble();
    if (projected < 0 || projected > lengthSquared) {
      return _SourceProjectionInfo2(t: t, distanceSquared: double.infinity);
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

  static int _comparePosition(
    _SourceLinePosition2 a,
    _SourceLinePosition2 b,
  ) {
    final indexCompare = a.lineIndex.compareTo(b.lineIndex);
    return indexCompare != 0 ? indexCompare : a.t.compareTo(b.t);
  }

  static int _compareRange(
    _SourceLineRegionRange2 a,
    _SourceLineRegionRange2 b,
  ) {
    final indexCompare = a.beginIndex.compareTo(b.beginIndex);
    return indexCompare != 0 ? indexCompare : a.beginT.compareTo(b.beginT);
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

class _SourceLinePosition2 {
  const _SourceLinePosition2(this.lineIndex, this.t);

  final int lineIndex;
  final double t;
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
