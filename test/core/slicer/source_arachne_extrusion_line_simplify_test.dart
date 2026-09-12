import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_extrusion_line.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_extrusion_line_simplify.dart';

SourceArachneExtrusionJunction2 _junction(
  int x,
  int y,
  int width, {
  int perimeter = 0,
  bool hole = false,
}) =>
    SourceArachneExtrusionJunction2(
      p: SourcePoint2(x, y),
      w: width,
      perimeterIndex: perimeter,
      holeCompensationFlag: hole,
    );

SourceArachneExtrusionLine2 _line(
  List<SourceArachneExtrusionJunction2> junctions, {
  bool closed = false,
}) =>
    SourceArachneExtrusionLine2(
      insetIndex: 0,
      isOdd: false,
      isClosed: closed,
      junctions: junctions,
    );

void main() {
  test('area deviation uses source weighted integer segment widths', () {
    final result = sourceCalculateExtrusionAreaDeviationError(
      _junction(0, 0, 100),
      _junction(10, 0, 200),
      _junction(30, 0, 300),
    );

    expect(result.weightedAverageWidth, 216);
    expect(result.error, 1340);
  });

  test('area deviation <=1 width branch chooses longer segment endpoint', () {
    final result = sourceCalculateExtrusionAreaDeviationError(
      _junction(0, 0, 100),
      _junction(10, 0, 101),
      _junction(30, 0, 100),
    );

    expect(result.weightedAverageWidth, 101);
    expect(result.error, 10);
  });

  test('constant-width collinear middle junction is removed', () {
    final line = _line([
      _junction(0, 0, 100),
      _junction(1000, 0, 100),
      _junction(2000, 0, 100),
    ]);

    line.simplifySource(
      100 * 100,
      50 * 50,
      100,
    );

    expect(line.junctions, hasLength(2));
    expect(line.junctions.first.p, const SourcePoint2(0, 0));
    expect(line.junctions.last.p, const SourcePoint2(2000, 0));
  });

  test('collinear width-area error prevents otherwise free removal', () {
    final line = _line([
      _junction(0, 0, 100),
      _junction(1000, 0, 1000),
      _junction(2000, 0, 1000),
    ]);

    line.simplifySource(
      100 * 100,
      50 * 50,
      100,
    );

    expect(line.junctions, hasLength(3));
    expect(line.junctions[1].w, 1000);
  });

  test('larger area allowance removes the same collinear width change', () {
    final line = _line([
      _junction(0, 0, 100),
      _junction(1000, 0, 1000),
      _junction(2000, 0, 1000),
    ]);

    line.simplifySource(
      100 * 100,
      50 * 50,
      500000,
    );

    expect(line.junctions, hasLength(2));
  });

  test('source squared-length versus scaled 0.025 quirk removes tiny edge', () {
    final line = _line([
      _junction(0, 0, 100),
      _junction(10, 0, 5000, perimeter: 3, hole: true),
      _junction(1000, 100, 100),
    ]);

    line.simplifySource(
      1,
      0,
      0,
    );

    // 10^2 is compared directly with scaled<coord_t>(0.025), so the middle
    // point is removed before width/error checks despite the large width jump.
    expect(line.junctions, hasLength(2));
  });

  test('endpoints remain untouched and closed duplicate is preserved', () {
    final line = _line(
      [
        _junction(0, 0, 100),
        _junction(1000, 0, 100),
        _junction(2000, 0, 100),
        _junction(0, 0, 100),
      ],
      closed: true,
    );

    line.simplifySource(
      100 * 100,
      50 * 50,
      1000,
    );

    expect(line.junctions.first.p, const SourcePoint2(0, 0));
    expect(line.junctions.last.p, const SourcePoint2(0, 0));
    expect(line.isClosed, isTrue);
  });

  test('minimum source path sizes bypass simplification', () {
    final open = _line([
      _junction(0, 0, 100),
      _junction(100, 0, 100),
    ]);
    final closed = _line(
      [
        _junction(0, 0, 100),
        _junction(100, 0, 100),
        _junction(0, 0, 100),
      ],
      closed: true,
    );

    open.simplifySource(1000000, 1000000, 1000000);
    closed.simplifySource(1000000, 1000000, 1000000);

    expect(open.junctions, hasLength(2));
    expect(closed.junctions, hasLength(3));
  });
}
