import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_arc_fitter.dart';
import 'package:qidi_flow_flutter/core/geometry/source_circle.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polyline.dart';

void main() {
  test('QIDI append suppresses identical consecutive point', () {
    final line = SourcePolyline2();
    line
      ..append(const SourcePoint2(0, 0))
      ..append(const SourcePoint2(0, 0))
      ..append(const SourcePoint2(10, 0));
    expect(line.points, const [SourcePoint2(0, 0), SourcePoint2(10, 0)]);
  });

  test('raw Points constructor preserves adjacent duplicates', () {
    final line = SourcePolyline2(const [
      SourcePoint2(0, 0),
      SourcePoint2(0, 0),
      SourcePoint2(10, 0),
    ]);
    expect(line.points, hasLength(3));
  });

  test('clipEnd removes whole segments then truncates inserted coord_t point', () {
    final line = SourcePolyline2(const [
      SourcePoint2(0, 0),
      SourcePoint2(100, 0),
      SourcePoint2(100, 100),
    ]);
    line.clipEnd(150);
    expect(line.points, const [SourcePoint2(0, 0), SourcePoint2(50, 0)]);
  });

  test('clipEnd exact total length leaves the source first-point quirk', () {
    final line = SourcePolyline2(const [
      SourcePoint2(0, 0),
      SourcePoint2(100, 0),
    ]);
    line.clipEnd(100);

    // `Polyline::clip_end()` pops the last point, subtracts the exact segment
    // length to zero and exits the `while (distance > 0)` loop. It therefore
    // retains the original first point instead of clearing the polyline.
    expect(line.points, const [SourcePoint2(0, 0)]);
  });

  test('clipStart mirrors source reverse/clip/reverse behavior', () {
    final line = SourcePolyline2(const [
      SourcePoint2(0, 0),
      SourcePoint2(100, 0),
      SourcePoint2(100, 100),
    ]);
    line.clipStart(50);
    expect(
      line.points,
      const [
        SourcePoint2(50, 0),
        SourcePoint2(100, 0),
        SourcePoint2(100, 100),
      ],
    );
  });

  test('extendEnd casts normalized displacement to coord_t before append', () {
    final line = SourcePolyline2(const [
      SourcePoint2(0, 0),
      SourcePoint2(3, 4),
    ]);
    line.extendEnd(10);
    expect(line.lastPoint, const SourcePoint2(9, 12));
  });

  test('simplifyByFittingArc stores QIDI fitting metadata', () {
    final line = SourcePolyline2(const [
      SourcePoint2(100000, 0),
      SourcePoint2(86603, 50000),
      SourcePoint2(50000, 86603),
      SourcePoint2(0, 100000),
    ]);

    line.simplifyByFittingArc(SourceArcSegment2.defaultScaledResolution);

    expect(line.fittingResult, hasLength(1));
    expect(line.fittingResult.single.pathType, MovePathType2.arcCcw);
    expect(line.fittingResult.single.startPointIndex, 0);
    expect(line.fittingResult.single.endPointIndex, line.points.length - 1);
  });

  test('reverse remaps fitting indexes and flips arc direction/type', () {
    final line = _quarterArcPolyline();
    line.reverse();

    expect(line.points.first, const SourcePoint2(0, 100000));
    expect(line.points.last, const SourcePoint2(100000, 0));
    expect(line.fittingResult.single.startPointIndex, 0);
    expect(line.fittingResult.single.endPointIndex, 2);
    expect(line.fittingResult.single.pathType, MovePathType2.arcCw);
    expect(line.fittingResult.single.arcData.direction, ArcDirection2.cw);
  });

  test('splitAtIndex clips one arc into two source arc metadata ranges', () {
    final line = _quarterArcPolyline();
    final split = line.splitAtIndex(1)!;

    expect(split.first.points, hasLength(2));
    expect(split.second.points, hasLength(2));
    expect(split.first.fittingResult, hasLength(1));
    expect(split.second.fittingResult, hasLength(1));
    expect(split.first.fittingResult.single.pathType, MovePathType2.arcCcw);
    expect(split.second.fittingResult.single.pathType, MovePathType2.arcCcw);
    expect(split.first.fittingResult.single.endPointIndex, 1);
    expect(split.second.fittingResult.single.startPointIndex, 0);
    expect(split.second.fittingResult.single.endPointIndex, 1);
  });

  test('clipEnd(0) preserves source quirk: terminal arc downgrades to linear', () {
    final line = _quarterArcPolyline();
    line.clipEnd(0);
    expect(line.fittingResult.single.pathType, MovePathType2.linear);
  });
}

SourcePolyline2 _quarterArcPolyline() {
  final line = SourcePolyline2(const [
    SourcePoint2(100000, 0),
    SourcePoint2(70710, 70710),
    SourcePoint2(0, 100000),
  ]);
  line.fittingResult.add(PathFittingData2(
    startPointIndex: 0,
    endPointIndex: 2,
    pathType: MovePathType2.arcCcw,
    arcData: SourceArcSegment2(
      center: const SourcePoint2(0, 0),
      radius: 100000,
      startPoint: const SourcePoint2(100000, 0),
      endPoint: const SourcePoint2(0, 100000),
      direction: ArcDirection2.ccw,
    ),
  ));
  return line;
}
