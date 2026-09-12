import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_extrusion_line.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_region_order.dart';

SourceArachneExtrusionLine2 _line({
  required int inset,
  required int x,
  int width = 100,
  bool odd = false,
}) =>
    SourceArachneExtrusionLine2(
      insetIndex: inset,
      isOdd: odd,
      junctions: [
        SourceArachneExtrusionJunction2(
          p: SourcePoint2(x, 0),
          w: width,
          perimeterIndex: inset,
        ),
      ],
    );

void main() {
  test('zero-width input returns no region constraints', () {
    final outer = _line(inset: 0, x: 0, width: 0);
    final inner = _line(inset: 1, x: 0, width: 0);

    expect(
      SourceArachneRegionOrderBuilder2.getRegionOrder(
        [outer, inner],
        outerToInner: true,
      ),
      isEmpty,
    );
  });

  test('outer-to-inner constrains adjacent even wall pair', () {
    final outer = _line(inset: 0, x: 0);
    final inner = _line(inset: 1, x: 100);

    final order = SourceArachneRegionOrderBuilder2.getRegionOrder(
      [inner, outer],
      outerToInner: true,
    );

    expect(order, contains(SourceArachneRegionOrder2(outer, inner)));
    expect(order, hasLength(1));
  });

  test('inner-to-outer reverses adjacent even wall constraint', () {
    final outer = _line(inset: 0, x: 0);
    final inner = _line(inset: 1, x: 100);

    final order = SourceArachneRegionOrderBuilder2.getRegionOrder(
      [outer, inner],
      outerToInner: false,
    );

    expect(order, contains(SourceArachneRegionOrder2(inner, outer)));
    expect(order, hasLength(1));
  });

  test('non-adjacent inset indices never create a requirement', () {
    final outer = _line(inset: 0, x: 0);
    final deep = _line(inset: 2, x: 1);

    expect(
      SourceArachneRegionOrderBuilder2.getRegionOrder(
        [outer, deep],
        outerToInner: true,
      ),
      isEmpty,
    );
  });

  test('same inset index never creates a requirement', () {
    final a = _line(inset: 1, x: 0);
    final b = _line(inset: 1, x: 1);

    expect(
      SourceArachneRegionOrderBuilder2.getRegionOrder(
        [a, b],
        outerToInner: true,
      ),
      isEmpty,
    );
  });

  test('width radius uses inclusive shorter_then boundary', () {
    final outer = _line(inset: 0, x: 0, width: 100);
    final exact = _line(inset: 1, x: 190, width: 100);
    final outside = _line(inset: 1, x: 191, width: 100);

    final exactOrder = SourceArachneRegionOrderBuilder2.getRegionOrder(
      [outer, exact],
      outerToInner: true,
    );
    final outsideOrder = SourceArachneRegionOrderBuilder2.getRegionOrder(
      [outer, outside],
      outerToInner: true,
    );

    expect(exactOrder, contains(SourceArachneRegionOrder2(outer, exact)));
    expect(outsideOrder, isEmpty);
  });

  test('float32 1.9f then coord_t truncation is preserved', () {
    final outer = _line(inset: 0, x: 0, width: 5);
    final atNine = _line(inset: 1, x: 9, width: 5);
    final atTen = _line(inset: 1, x: 10, width: 5);

    expect(
      SourceArachneRegionOrderBuilder2.getRegionOrder(
        [outer, atNine],
        outerToInner: true,
      ),
      contains(SourceArachneRegionOrder2(outer, atNine)),
    );
    expect(
      SourceArachneRegionOrderBuilder2.getRegionOrder(
        [outer, atTen],
        outerToInner: true,
      ),
      isEmpty,
    );
  });

  test('odd wall always follows enclosing lower-index even wall', () {
    final outer = _line(inset: 0, x: 0, odd: false);
    final odd = _line(inset: 1, x: 10, odd: true);

    final outerFirst = SourceArachneRegionOrderBuilder2.getRegionOrder(
      [outer, odd],
      outerToInner: true,
    );
    final innerFirst = SourceArachneRegionOrderBuilder2.getRegionOrder(
      [outer, odd],
      outerToInner: false,
    );

    expect(outerFirst, contains(SourceArachneRegionOrder2(outer, odd)));
    expect(innerFirst, contains(SourceArachneRegionOrder2(outer, odd)));
  });

  test('odd wall does not constrain a lower-index wall that does not enclose it', () {
    final oddOuter = _line(inset: 0, x: 0, odd: true);
    final evenInner = _line(inset: 1, x: 10, odd: false);

    expect(
      SourceArachneRegionOrderBuilder2.getRegionOrder(
        [oddOuter, evenInner],
        outerToInner: true,
      ),
      isEmpty,
    );
  });
}
