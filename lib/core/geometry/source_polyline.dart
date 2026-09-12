import 'dart:math' as math;

import 'source_arc_fitter.dart';
import 'source_geometry.dart';

class SourcePolylineSplit2 {
  const SourcePolylineSplit2({
    required this.point,
    required this.first,
    required this.second,
  });

  final SourcePoint2 point;
  final SourcePolyline2 first;
  final SourcePolyline2 second;
}

/// Integer-coordinate port of QIDI `libslic3r/Polyline.hpp/.cpp`.
///
/// Unlike a generic Flutter polyline, this type preserves the QIDI
/// `fitting_result` metadata consumed by G-code arc emission. Constructors from
/// raw points intentionally start with empty fitting metadata, exactly like
/// `Polyline(const Points&)`; [copy] preserves it like the C++ copy ctor.
class SourcePolyline2 {
  SourcePolyline2([Iterable<SourcePoint2> points = const []])
      : points = List<SourcePoint2>.of(points),
        fittingResult = <PathFittingData2>[];

  SourcePolyline2._copy(SourcePolyline2 source)
      : points = List<SourcePoint2>.of(source.points),
        fittingResult = [for (final data in source.fittingResult) data.clone()];

  final List<SourcePoint2> points;
  final List<PathFittingData2> fittingResult;

  int get lengthInPoints => points.length;
  bool get isEmpty => points.isEmpty;
  bool get isValid => points.length >= 2;
  bool get isClosed => points.isNotEmpty && points.first == points.last;
  SourcePoint2 get firstPoint => points.first;
  SourcePoint2 get lastPoint => points.last;

  SourcePolyline2 copy() => SourcePolyline2._copy(this);

  void append(SourcePoint2 point) {
    if (points.isNotEmpty && points.last == point) return;
    points.add(point);
    _appendFittingResultAfterAppendPoints();
  }

  void appendBefore(SourcePoint2 point) {
    if (points.isNotEmpty && points.first == point) return;
    if (points.length == 1) {
      fittingResult.clear();
      points.add(point);
      points.setAll(0, points.reversed.toList(growable: false));
    } else {
      reverse();
      append(point);
      reverse();
    }
  }

  /// QIDI `append(const Points&)`: suppress only an identical join point,
  /// retain duplicates already present inside [source], then update fitting
  /// metadata once for the complete appended range.
  void appendPoints(Iterable<SourcePoint2> source) {
    final incoming = List<SourcePoint2>.of(source);
    if (incoming.isEmpty) return;
    if (points.isNotEmpty && points.last == incoming.first) {
      points.addAll(incoming.skip(1));
    } else {
      points.addAll(incoming);
    }
    _appendFittingResultAfterAppendPoints();
  }

  /// Exact non-moving `Polyline::append(const Polyline&)` behavior.
  void appendPolyline(SourcePolyline2 source) {
    if (!source.isValid) return;
    if (points.isEmpty) {
      points.addAll(source.points);
      fittingResult.addAll(source.fittingResult.map((data) => data.clone()));
      return;
    }

    append(source.points.first);
    if (fittingResult.isEmpty && source.fittingResult.isNotEmpty) {
      fittingResult.add(PathFittingData2(
        startPointIndex: 0,
        endPointIndex: points.length - 1,
        pathType: MovePathType2.linear,
      ));
    }
    points.addAll(source.points.skip(1));
    _appendFittingResultAfterAppendPolyline(source);
  }

  void reverse() {
    points.setAll(0, points.reversed.toList(growable: false));
    if (fittingResult.isEmpty) return;
    final size = points.length;
    for (final data in fittingResult) {
      final oldStart = data.startPointIndex;
      data.startPointIndex = size - 1 - data.endPointIndex;
      data.endPointIndex = size - 1 - oldStart;
      if (data.isArcMove) data.reverseArcPath();
    }
    fittingResult.setAll(
      0,
      fittingResult.reversed.toList(growable: false),
    );
  }

  void clear() {
    points.clear();
    fittingResult.clear();
  }

  double get length {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += (points[i] - points[i - 1]).length;
    }
    return total;
  }

  List<SourceLine2> lines() {
    if (points.length < 2) return const [];
    return List<SourceLine2>.generate(
      points.length - 1,
      (i) => SourceLine2(points[i], points[i + 1]),
      growable: false,
    );
  }

  /// Exact metadata-aware `Polyline::clip_end()` behavior. Note that the C++
  /// source still visits the last fitting segment for zero/negative distance;
  /// an arc may therefore downgrade to linear because clipping at its endpoint
  /// fails the source's strict `is_point_inside()` test. This quirk is kept.
  void clipEnd(double distance) {
    if (points.isEmpty) return;
    var removeAfterIndex = points.length;
    while (distance > 0) {
      final last = points.last;
      points.removeLast();
      removeAfterIndex--;
      if (points.isEmpty) {
        fittingResult.clear();
        return;
      }
      final current = points.last;
      final dx = current.x - last.x;
      final dy = current.y - last.y;
      final lengthSquared = dx.toDouble() * dx + dy.toDouble() * dy;
      if (lengthSquared > distance * distance) {
        final segmentLength = math.sqrt(lengthSquared);
        final ratio = distance / segmentLength;
        points.add(SourcePoint2(
          (last.x + dx * ratio).truncate(),
          (last.y + dy * ratio).truncate(),
        ));
        break;
      }
      distance -= math.sqrt(lengthSquared);
    }

    if (fittingResult.isEmpty) return;
    while (fittingResult.isNotEmpty &&
        fittingResult.last.startPointIndex >= removeAfterIndex) {
      fittingResult.removeLast();
    }
    if (fittingResult.isEmpty) return;

    final last = fittingResult.last;
    if (last.pathType == MovePathType2.arcCcw ||
        last.pathType == MovePathType2.arcCw) {
      if (last.arcData.clipEnd(points.last)) {
        points[points.length - 1] = last.arcData.endPoint;
      } else {
        last.pathType = MovePathType2.linear;
      }
    }
    last.endPointIndex = points.length - 1;
  }

  void clipStart(double distance) {
    reverse();
    clipEnd(distance);
    if (points.length >= 2) reverse();
  }

  void extendEnd(double distance) {
    if (points.length < 2) {
      throw StateError('Polyline::extend_end requires at least two points');
    }
    final vector = points.last - points[points.length - 2];
    final norm = vector.length;
    if (norm == 0) return;
    final offset = SourcePoint2(
      (vector.x / norm * distance).truncate(),
      (vector.y / norm * distance).truncate(),
    );
    append(points.last + offset);
  }

  void extendStart(double distance) {
    reverse();
    extendEnd(distance);
    reverse();
  }

  void simplify(double tolerance) {
    final simplified = ArcFitter2.douglasPeucker(points, tolerance);
    points
      ..clear()
      ..addAll(simplified);
    fittingResult.clear();
  }

  void simplifyByFittingArc(double tolerance) {
    final output = ArcFitter2.doArcFittingAndSimplify(points, tolerance);
    points
      ..clear()
      ..addAll(output.points);
    fittingResult
      ..clear()
      ..addAll(output.result);
  }

  void resetToLinearMove() {
    fittingResult
      ..clear()
      ..add(PathFittingData2(
        startPointIndex: 0,
        endPointIndex: points.length - 1,
        pathType: MovePathType2.linear,
      ));
  }

  SourcePolylineSplit2? splitAt(SourcePoint2 requestedPoint) {
    if (points.isEmpty) return null;
    final exactIndex = _findPoint(requestedPoint);
    if (exactIndex != -1) {
      final split = splitAtIndex(exactIndex)!;
      final returnedPoint = split.first.isValid
          ? split.first.lastPoint
          : split.second.firstPoint;
      return SourcePolylineSplit2(
        point: returnedPoint,
        first: split.first,
        second: split.second,
      );
    }

    var lineIndex = 0;
    var projected = firstPoint;
    var minDistance = (projected - requestedPoint).length;
    final sourceLines = lines();
    for (var i = 0; i < sourceLines.length; i++) {
      final candidate = _projectionOntoLine(requestedPoint, sourceLines[i]);
      final distance = (candidate - requestedPoint).length;
      if (distance < minDistance) {
        projected = candidate;
        minDistance = distance;
        lineIndex = i;
      }
    }

    final projectedIndex = _findPoint(projected);
    if (projectedIndex != -1) {
      final split = splitAtIndex(projectedIndex)!;
      split.first.append(requestedPoint);
      split.second.appendBefore(requestedPoint);
      return SourcePolylineSplit2(
        point: requestedPoint,
        first: split.first,
        second: split.second,
      );
    }

    final firstSplit = splitAtIndex(lineIndex)!;
    firstSplit.first.append(requestedPoint);
    final secondSplit = splitAtIndex(lineIndex + 1)!;
    secondSplit.second.appendBefore(requestedPoint);
    return SourcePolylineSplit2(
      point: requestedPoint,
      first: firstSplit.first,
      second: secondSplit.second,
    );
  }

  SourcePolylineSplit2? splitAtIndex(int index) {
    if (index < 0 || index > points.length - 1) return null;
    if (index == 0) {
      final first = SourcePolyline2()..append(firstPoint);
      return SourcePolylineSplit2(
        point: firstPoint,
        first: first,
        second: copy(),
      );
    }
    if (index == points.length - 1) {
      final second = SourcePolyline2()..append(lastPoint);
      return SourcePolylineSplit2(
        point: lastPoint,
        first: copy(),
        second: second,
      );
    }

    final first = SourcePolyline2(points.getRange(0, index + 1));
    final before = _splitFittingResultBeforeIndex(index);
    if (before != null) {
      first.fittingResult.addAll(before.data);
      first.points[first.points.length - 1] = before.point;
    }

    final second = SourcePolyline2(points.getRange(index, points.length));
    final after = _splitFittingResultAfterIndex(index);
    if (after != null) {
      second.fittingResult.addAll(after.data);
      second.points[0] = after.point;
    }

    return SourcePolylineSplit2(
      point: points[index],
      first: first,
      second: second,
    );
  }

  SourcePolylineSplit2? splitAtLength(double targetLength) {
    if (points.isEmpty) return null;
    final totalLength = length;
    if (targetLength < 0 || targetLength > totalLength) return null;

    if (targetLength < Slic3rUnits.scaledEpsilon) {
      final first = SourcePolyline2()..append(firstPoint);
      return SourcePolylineSplit2(
        point: firstPoint,
        first: first,
        second: copy(),
      );
    }
    if ((targetLength - totalLength).abs() <
        Slic3rUnits.scaledEpsilon) {
      final second = SourcePolyline2()..append(lastPoint);
      return SourcePolylineSplit2(
        point: lastPoint,
        first: copy(),
        second: second,
      );
    }

    var lineIndex = 0;
    var accumulated = 0.0;
    var point = firstPoint;
    for (final line in lines()) {
      point = line.b;
      final currentLength = line.length;
      if (accumulated + currentLength >= targetLength) {
        final ratio = (targetLength - accumulated) / currentLength;
        point = SourcePoint2(
          (line.a.x + (line.b.x - line.a.x) * ratio).truncate(),
          (line.a.y + (line.b.y - line.a.y) * ratio).truncate(),
        );
        break;
      }
      accumulated += currentLength;
      lineIndex++;
    }

    final exactIndex = _findPoint(point);
    if (exactIndex != -1) return splitAtIndex(exactIndex);

    final firstSplit = splitAtIndex(lineIndex)!;
    firstSplit.first.append(point);
    final secondSplit = splitAtIndex(lineIndex + 1)!;
    secondSplit.second.appendBefore(point);
    return SourcePolylineSplit2(
      point: point,
      first: firstSplit.first,
      second: secondSplit.second,
    );
  }

  bool get isStraight {
    if (points.length < 2) return true;
    final direction = SourceLine2(firstPoint, lastPoint).direction;
    for (final line in lines()) {
      final diff = (line.direction - direction).abs();
      final maxDiff = Slic3rUnits.epsilon;
      if (!(diff < maxDiff || (diff - math.pi).abs() < maxDiff)) {
        return false;
      }
    }
    return true;
  }

  void _appendFittingResultAfterAppendPoints() {
    if (fittingResult.isEmpty) return;
    if (fittingResult.last.isLinearMove) {
      fittingResult.last.endPointIndex = points.length - 1;
    } else {
      final newStart = fittingResult.last.endPointIndex;
      final newEnd = points.length - 1;
      if (newStart != newEnd) {
        fittingResult.add(PathFittingData2(
          startPointIndex: newStart,
          endPointIndex: newEnd,
          pathType: MovePathType2.linear,
        ));
      }
    }
  }

  void _appendFittingResultAfterAppendPolyline(SourcePolyline2 source) {
    if (fittingResult.isEmpty) return;
    if (source.fittingResult.isNotEmpty) {
      final oldSize = fittingResult.length;
      final indexOffset = fittingResult.last.endPointIndex;
      fittingResult.addAll(source.fittingResult.map((data) => data.clone()));
      for (var i = oldSize; i < fittingResult.length; i++) {
        fittingResult[i].startPointIndex += indexOffset;
        fittingResult[i].endPointIndex += indexOffset;
      }
    } else {
      final newStart = fittingResult.last.endPointIndex;
      final newEnd = points.length - 1;
      if (newStart != newEnd) {
        fittingResult.add(PathFittingData2(
          startPointIndex: newStart,
          endPointIndex: newEnd,
          pathType: MovePathType2.linear,
        ));
      }
    }
  }

  ({SourcePoint2 point, List<PathFittingData2> data})?
      _splitFittingResultBeforeIndex(int index) {
    var newEndpoint = points[index];
    if (fittingResult.isEmpty) return null;
    final data = <PathFittingData2>[];
    for (final source in fittingResult) {
      if (source.startPointIndex < index) {
        data.add(source.clone());
      } else {
        break;
      }
    }
    if (data.isNotEmpty) {
      final last = data.last;
      if (last.isArcMove && last.endPointIndex > index) {
        if (!last.arcData.clipEnd(points[index])) {
          last.pathType = MovePathType2.linear;
        } else {
          newEndpoint = last.arcData.endPoint;
        }
      }
      last.endPointIndex = index;
    }
    return (point: newEndpoint, data: data);
  }

  ({SourcePoint2 point, List<PathFittingData2> data})?
      _splitFittingResultAfterIndex(int index) {
    var newStartPoint = points[index];
    if (fittingResult.isEmpty) return null;
    final data = <PathFittingData2>[];
    for (final source in fittingResult) {
      if (source.endPointIndex > index) data.add(source.clone());
    }
    if (data.isNotEmpty) {
      for (var i = 0; i < data.length; i++) {
        if (i != 0) {
          data[i].startPointIndex -= index;
          data[i].endPointIndex -= index;
        } else {
          data[i].endPointIndex -= index;
          if (data.first.isArcMove && data.first.startPointIndex < index) {
            if (!data.first.arcData.clipStart(points[index])) {
              data.first.pathType = MovePathType2.linear;
            } else {
              newStartPoint = data.first.arcData.startPoint;
            }
          }
          data[i].startPointIndex = 0;
        }
      }
    }
    return (point: newStartPoint, data: data);
  }

  int _findPoint(SourcePoint2 point) => points.indexOf(point);

  static SourcePoint2 _projectionOntoLine(
    SourcePoint2 point,
    SourceLine2 line,
  ) {
    if (line.a == line.b) return line.a;
    final lx = (line.b.x - line.a.x).toDouble();
    final ly = (line.b.y - line.a.y).toDouble();
    final theta = ((line.b.x - point.x) * lx +
            (line.b.y - point.y) * ly) /
        (lx * lx + ly * ly);
    if (0 <= theta && theta <= 1) {
      return SourcePoint2(
        (theta * line.a.x + (1 - theta) * line.b.x).truncate(),
        (theta * line.a.y + (1 - theta) * line.b.y).truncate(),
      );
    }
    final dax = line.a.x - point.x;
    final day = line.a.y - point.y;
    final dbx = line.b.x - point.x;
    final dby = line.b.y - point.y;
    final da = dax.toDouble() * dax + day.toDouble() * day;
    final db = dbx.toDouble() * dbx + dby.toDouble() * dby;
    return da < db ? line.a : line.b;
  }
}
