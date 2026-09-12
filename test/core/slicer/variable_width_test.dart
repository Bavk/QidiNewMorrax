import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/thick_polyline.dart';
import 'package:qidi_flow_flutter/core/slicer/extrusion_entity.dart';
import 'package:qidi_flow_flutter/core/slicer/flow.dart';
import 'package:qidi_flow_flutter/core/slicer/variable_width.dart';

void main() {
  const variableWidth = SourceVariableWidth2();
  final flow = Flow.nonBridging(
    width: 0.4,
    height: 0.2,
    nozzleDiameter: 0.4,
  );

  test('QIDI variable_width converts constant spacing to source Flow width', () {
    final out = <ExtrusionEntity2>[];
    variableWidth.variableWidth(
      [
        ThickPolyline2(
          points: const [SourcePoint2(0, 0), SourcePoint2(100000, 0)],
          width: const [40000, 40000],
        ),
      ],
      ExtrusionRole.externalPerimeter,
      flow,
      out,
    );

    expect(out, hasLength(1));
    final path = out.single as ExtrusionPath2;
    expect(path.polyline.points,
        const [SourcePoint2(0, 0), SourcePoint2(100000, 0)]);
    // C++ float oracle for:
    // unscale<float>(40000) + 0.2f * float(1 - PI/4).
    expect(path.width, closeTo(0.44292032718658447, 1e-12));
    expect(path.mm3PerMm, closeTo(0.08, 2e-8));
    expect(path.height, 0.2);
  });

  test('QIDI width filter keeps an in-tolerance range as one weighted path', () {
    final out = <ExtrusionEntity2>[];
    variableWidth.variableWidth(
      [
        ThickPolyline2(
          points: const [
            SourcePoint2(0, 0),
            SourcePoint2(100000, 0),
            SourcePoint2(200000, 0),
          ],
          width: const [40000, 43000, 43000, 42000],
        ),
      ],
      ExtrusionRole.externalPerimeter,
      flow,
      out,
    );

    expect(out, hasLength(1));
    final path = out.single as ExtrusionPath2;
    expect(path.polyline.points, const [
      SourcePoint2(0, 0),
      SourcePoint2(100000, 0),
      SourcePoint2(200000, 0),
    ]);
    // Equal-length segments average to source spacing 42000.
    expect(path.width, closeTo(0.46292036771774292, 1e-12));
    expect(path.mm3PerMm, closeTo(0.084, 2e-8));
  });

  test('QIDI large width delta splits at source tolerance and truncates point', () {
    final out = <ExtrusionEntity2>[];
    variableWidth.variableWidth(
      [
        ThickPolyline2(
          points: const [SourcePoint2(-1, -1), SourcePoint2(100, 34)],
          width: const [40000, 50000],
        ),
      ],
      ExtrusionRole.externalPerimeter,
      flow,
      out,
    );

    expect(out, hasLength(2));
    final first = out[0] as ExtrusionPath2;
    final second = out[1] as ExtrusionPath2;

    // 10000 / scale_(0.05=5000) => 2 segments. Eigen cast<coord_t>
    // truncates the midpoint (49.5, 16.5) toward zero.
    expect(first.polyline.points,
        const [SourcePoint2(-1, -1), SourcePoint2(49, 16)]);
    expect(second.polyline.points,
        const [SourcePoint2(49, 16), SourcePoint2(100, 34)]);
    expect(first.width, closeTo(0.46792036294937134, 1e-12));
    expect(second.width, closeTo(0.51792037487030029, 1e-12));
  });

  test('QIDI newer helper retains tiny segment in final averaged polyline', () {
    final out = <ExtrusionEntity2>[];
    variableWidth.variableWidth(
      [
        ThickPolyline2(
          points: const [
            SourcePoint2(0, 0),
            SourcePoint2(5, 0),
            SourcePoint2(100, 0),
          ],
          width: const [40000, 40000, 40000, 40000],
        ),
      ],
      ExtrusionRole.externalPerimeter,
      flow,
      out,
    );

    final path = out.single as ExtrusionPath2;
    expect(path.polyline.points, const [
      SourcePoint2(0, 0),
      SourcePoint2(5, 0),
      SourcePoint2(100, 0),
    ]);
  });

  test('older multi-path helper absorbs tiny line into following segment', () {
    final result = variableWidth.thickPolylineToMultiPath(
      ThickPolyline2(
        points: const [
          SourcePoint2(0, 0),
          SourcePoint2(5, 0),
          SourcePoint2(100, 0),
        ],
        width: const [40000, 40000, 40000, 40000],
      ),
      ExtrusionRole.externalPerimeter,
      flow,
      SourceVariableWidth2.qidiTolerance,
      Slic3rUnits.scaledEpsilon.toDouble(),
      0,
    );

    expect(result.paths, hasLength(1));
    expect(result.paths.single.polyline.points,
        const [SourcePoint2(0, 0), SourcePoint2(100, 0)]);
  });

  test('older helper preserves bridge flow for overhang perimeter', () {
    final bridge = Flow.bridging(diameter: 0.4, nozzleDiameter: 0.4);
    final result = variableWidth.thickPolylineToMultiPath(
      ThickPolyline2(
        points: const [SourcePoint2(0, 0), SourcePoint2(100000, 0)],
        width: const [20000, 60000],
      ),
      ExtrusionRole.overhangPerimeter,
      bridge,
      50000,
      Slic3rUnits.scaledEpsilon.toDouble(),
      7,
    );

    final path = result.paths.single;
    expect(path.width, bridge.width);
    expect(path.height, bridge.height);
    expect(path.mm3PerMm, bridge.mm3PerMm);
    expect(path.overhangDegree, 7);
  });

  test('variable_width wraps a closed result in ExtrusionLoop', () {
    final out = <ExtrusionEntity2>[];
    variableWidth.variableWidth(
      [
        ThickPolyline2(
          points: const [
            SourcePoint2(0, 0),
            SourcePoint2(100000, 0),
            SourcePoint2(0, 0),
          ],
          width: const [40000, 40000, 40000, 40000],
        ),
      ],
      ExtrusionRole.gapFill,
      flow,
      out,
    );

    expect(out, hasLength(1));
    expect(out.single, isA<ExtrusionLoop2>());
    final loop = out.single as ExtrusionLoop2;
    expect(loop.paths.single.firstPoint, loop.paths.single.lastPoint);
    expect(loop.role, ExtrusionRole.gapFill);
  });
}
