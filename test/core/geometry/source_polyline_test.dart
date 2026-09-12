import 'package:flutter_test/flutter_test.dart';
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

  test('clipEnd removes whole segments then truncates inserted coord_t point', () {
    final line = SourcePolyline2(const [
      SourcePoint2(0, 0),
      SourcePoint2(100, 0),
      SourcePoint2(100, 100),
    ]);
    line.clipEnd(150);
    // 100 units remove the vertical segment; 50 units then remove half of the
    // horizontal segment from its end.
    expect(line.points, const [SourcePoint2(0, 0), SourcePoint2(50, 0)]);
  });

  test('clipEnd clears a path when clipping its complete length', () {
    final line = SourcePolyline2(const [
      SourcePoint2(0, 0),
      SourcePoint2(100, 0),
    ]);
    line.clipEnd(100);
    expect(line.points, isEmpty);
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

  test('arc fitting remains explicit pending behavior', () {
    final line = SourcePolyline2(const [
      SourcePoint2(0, 0),
      SourcePoint2(10, 0),
    ]);
    expect(() => line.simplifyByFittingArc(1), throwsUnsupportedError);
  });
}
