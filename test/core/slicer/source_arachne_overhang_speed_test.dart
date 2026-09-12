import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polyline.dart';
import 'package:qidi_flow_flutter/core/slicer/extrusion_entity.dart';
import 'package:qidi_flow_flutter/core/slicer/flow.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_extrusion_line.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_overhang_speed.dart';

SourcePolygon2 _rect(int minX, int minY, int maxX, int maxY) =>
    SourcePolygon2([
      SourcePoint2(minX, minY),
      SourcePoint2(maxX, minY),
      SourcePoint2(maxX, maxY),
      SourcePoint2(minX, maxY),
    ]);

SourceArachneExtrusionJunction2 _junction(int x, int y, {int width = 40000}) =>
    SourceArachneExtrusionJunction2(
      p: SourcePoint2(x, y),
      w: width,
      perimeterIndex: 0,
    );

Flow _flow() => Flow.nonBridging(
      width: 0.4,
      height: 0.2,
      nozzleDiameter: 0.4,
    );

void main() {
  test('speed grader splits mapped Arachne degree at quarter boundaries', () {
    final extrusion = SourceArachneExtrusionLine2(
      insetIndex: 0,
      isOdd: false,
      junctions: [
        _junction(0, 0),
        _junction(150000, 0),
      ],
    );
    final support = _rect(-500000, -500000, 150000, 500000);

    final paths = SourceArachneOverhangSpeed2.gradeSupported(
      extrusion: extrusion,
      lowerLayerPolygons: [support],
      nozzleDiameterMm: 0.4,
      role: ExtrusionRole.externalPerimeter,
      flow: _flow(),
    );

    expect(paths, isNotEmpty);
    final degrees = paths.map((path) => path.overhangDegree).toSet();
    expect(degrees, contains(0.0));
    expect(degrees, contains(0.25));
    expect(degrees, contains(1.0));
    expect(degrees.any((degree) => degree >= 4.5), isTrue);
    expect(
      paths.every((path) => path.role == ExtrusionRole.externalPerimeter),
      isTrue,
    );
  });

  test('smooth pass truncates fractional get_overhang_degree like source', () {
    final paths = <ExtrusionPath2>[
      ExtrusionPath2(
        polyline: SourcePolyline2(const [
          SourcePoint2(0, 0),
          SourcePoint2(10000, 0),
        ]),
        role: ExtrusionRole.externalPerimeter,
        overhangDegree: 0.75,
        mm3PerMm: 1,
        width: 0.4,
        height: 0.2,
      ),
      ExtrusionPath2(
        polyline: SourcePolyline2(const [
          SourcePoint2(10000, 0),
          SourcePoint2(20000, 0),
        ]),
        role: ExtrusionRole.externalPerimeter,
        overhangDegree: 0.75,
        mm3PerMm: 1,
        width: 0.4,
        height: 0.2,
      ),
    ];

    SourceArachneOverhangSpeed2.smoothOverhangLevel(paths);

    expect(paths.map((path) => path.overhangDegree), everyElement(0.0));
  });

  test('unsupported bridge remains degree six after speed grading', () {
    final extrusion = SourceArachneExtrusionLine2(
      insetIndex: 0,
      isOdd: false,
      junctions: [
        _junction(0, 0),
        _junction(300000, 0),
      ],
    );
    final support = _rect(-500000, -500000, 150000, 500000);
    final overhangFlow = Flow.bridging(
      diameter: 0.4,
      nozzleDiameter: 0.4,
    );

    final paths = SourceArachneOverhangSpeed2.splitWithSpeedGrading(
      extrusion: extrusion,
      lowerLayerPolygons: [support],
      nozzleDiameterMm: 0.4,
      supportedRole: ExtrusionRole.externalPerimeter,
      supportedFlow: _flow(),
      overhangFlow: overhangFlow,
    );

    expect(paths, isNotEmpty);
    expect(paths.first.firstPoint, const SourcePoint2(0, 0));
    expect(paths.last.lastPoint, const SourcePoint2(300000, 0));
    expect(paths.last.role, ExtrusionRole.overhangPerimeter);
    expect(paths.last.overhangDegree, 6);
    expect(paths.last.width, overhangFlow.width);
    expect(paths.last.height, overhangFlow.height);
  });
}
