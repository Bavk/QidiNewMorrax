import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_wall_sequence.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_extrusion_line.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_extrusion_order.dart';

SourceArachneExtrusionLine2 _line({
  required int inset,
  required List<SourcePoint2> points,
  int width = 10,
  bool closed = false,
  bool odd = false,
}) =>
    SourceArachneExtrusionLine2(
      insetIndex: inset,
      isOdd: odd,
      isClosed: closed,
      junctions: [
        for (final point in points)
          SourceArachneExtrusionJunction2(
            p: point,
            w: width,
            perimeterIndex: inset,
          ),
      ],
    );

List<int> _insets(List<SourceArachneOrderedExtrusion2> ordered) =>
    ordered.map((entry) => entry.extrusion.insetIndex).toList();

void main() {
  test('wall-sequence direction follows source layer-zero override', () {
    expect(
      SourceArachneExtrusionOrder2.isOuterWallFirst(
        wallSequence: SourceWallSequence2.outerInner,
        layerId: 0,
      ),
      isTrue,
    );
    expect(
      SourceArachneExtrusionOrder2.isOuterWallFirst(
        wallSequence: SourceWallSequence2.innerOuter,
        layerId: 4,
      ),
      isFalse,
    );
    expect(
      SourceArachneExtrusionOrder2.isOuterWallFirst(
        wallSequence: SourceWallSequence2.innerOuterInner,
        layerId: 4,
      ),
      isTrue,
    );
    expect(
      SourceArachneExtrusionOrder2.isOuterWallFirst(
        wallSequence: SourceWallSequence2.innerOuterInner,
        layerId: 0,
      ),
      isFalse,
    );
  });

  test('adjacent region constraints preserve outer-to-inner order', () {
    final outer = _line(
      inset: 0,
      points: const [SourcePoint2(0, 0), SourcePoint2(20, 0)],
      width: 100,
    );
    final inner = _line(
      inset: 1,
      points: const [SourcePoint2(50, 0), SourcePoint2(70, 0)],
      width: 100,
    );

    final ordered = SourceArachneExtrusionOrder2.order(
      totalPerimeters: [
        [outer],
        [inner],
      ],
      wallSequence: SourceWallSequence2.outerInner,
      layerId: 2,
    );

    expect(ordered.map((entry) => entry.extrusion).toList(), [outer, inner]);
  });

  test('adjacent region constraints preserve inner-to-outer order', () {
    final outer = _line(
      inset: 0,
      points: const [SourcePoint2(0, 0), SourcePoint2(20, 0)],
      width: 100,
    );
    final inner = _line(
      inset: 1,
      points: const [SourcePoint2(50, 0), SourcePoint2(70, 0)],
      width: 100,
    );

    final ordered = SourceArachneExtrusionOrder2.order(
      totalPerimeters: [
        [outer],
        [inner],
      ],
      wallSequence: SourceWallSequence2.innerOuter,
      layerId: 2,
    );

    expect(ordered.map((entry) => entry.extrusion).toList(), [inner, outer]);
  });

  test('equal-distance tie considers open path before closed path', () {
    final closed = _line(
      inset: 0,
      closed: true,
      width: 1,
      points: const [
        SourcePoint2(0, 0),
        SourcePoint2(0, 100),
        SourcePoint2(100, 100),
        SourcePoint2(100, 0),
        SourcePoint2(0, 0),
      ],
    );
    final open = _line(
      inset: 0,
      width: 1,
      points: const [SourcePoint2(0, 0), SourcePoint2(1000, 0)],
    );

    final ordered = SourceArachneExtrusionOrder2.order(
      totalPerimeters: [
        [closed, open],
      ],
      wallSequence: SourceWallSequence2.outerInner,
      layerId: 2,
    );

    expect(ordered.first.extrusion, same(open));
    expect(ordered.last.extrusion, same(closed));
  });

  test('closed path leaves current position at its front for next choice', () {
    final closed = _line(
      inset: 0,
      closed: true,
      width: 1,
      points: const [
        SourcePoint2(0, 0),
        SourcePoint2(10000, 0),
        SourcePoint2(10000, 10000),
        SourcePoint2(0, 0),
      ],
    );
    final nearFront = _line(
      inset: 0,
      width: 1,
      points: const [SourcePoint2(10, 0), SourcePoint2(20, 0)],
    );
    final nearLastVertex = _line(
      inset: 0,
      width: 1,
      points: const [SourcePoint2(9000, 0), SourcePoint2(9010, 0)],
    );

    final ordered = SourceArachneExtrusionOrder2.order(
      totalPerimeters: [
        [closed, nearFront, nearLastVertex],
      ],
      wallSequence: SourceWallSequence2.outerInner,
      layerId: 2,
    );

    // All three start available. The first closed path wins from its own front
    // at distance zero; source then keeps current_position at that same front.
    expect(ordered[0].extrusion, same(closed));
    expect(ordered[1].extrusion, same(nearFront));
  });

  test('closed clockwise Arachne line is marked contour and CCW is hole', () {
    final clockwise = _line(
      inset: 0,
      closed: true,
      width: 1,
      points: const [
        SourcePoint2(0, 0),
        SourcePoint2(0, 100),
        SourcePoint2(100, 100),
        SourcePoint2(100, 0),
        SourcePoint2(0, 0),
      ],
    );
    final counterClockwise = _line(
      inset: 0,
      closed: true,
      width: 1,
      points: const [
        SourcePoint2(1000, 0),
        SourcePoint2(1100, 0),
        SourcePoint2(1100, 100),
        SourcePoint2(1000, 100),
        SourcePoint2(1000, 0),
      ],
    );

    final ordered = SourceArachneExtrusionOrder2.order(
      totalPerimeters: [
        [clockwise, counterClockwise],
      ],
      wallSequence: SourceWallSequence2.outerInner,
      layerId: 2,
    );
    final byLine = {
      for (final entry in ordered) entry.extrusion: entry.isContour,
    };

    expect(byLine[clockwise], isTrue);
    expect(byLine[counterClockwise], isFalse);
    expect(ordered.every((entry) => entry.fuzzify == false), isTrue);
  });

  test('InnerOuterInner reorders source 0,1,2 triplet to 2,0,1', () {
    final outer = _line(
      inset: 0,
      width: 1,
      points: const [SourcePoint2(0, 0)],
    );
    final first = _line(
      inset: 1,
      width: 1,
      points: const [SourcePoint2(10000, 0)],
    );
    final second = _line(
      inset: 2,
      width: 1,
      points: const [SourcePoint2(20000, 0)],
    );

    final ordered = SourceArachneExtrusionOrder2.order(
      totalPerimeters: [
        [outer],
        [first],
        [second],
      ],
      wallSequence: SourceWallSequence2.innerOuterInner,
      layerId: 2,
    );

    expect(_insets(ordered), [2, 0, 1]);
  });

  test('InnerOuterInner first layer keeps source inner-to-outer base order', () {
    final outer = _line(
      inset: 0,
      width: 1,
      points: const [SourcePoint2(0, 0)],
    );
    final first = _line(
      inset: 1,
      width: 1,
      points: const [SourcePoint2(10000, 0)],
    );
    final second = _line(
      inset: 2,
      width: 1,
      points: const [SourcePoint2(20000, 0)],
    );

    final ordered = SourceArachneExtrusionOrder2.order(
      totalPerimeters: [
        [outer],
        [first],
        [second],
      ],
      wallSequence: SourceWallSequence2.innerOuterInner,
      layerId: 0,
    );

    expect(_insets(ordered), [2, 1, 0]);
  });
}
