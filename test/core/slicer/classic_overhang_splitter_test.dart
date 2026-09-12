import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polyline.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_overhang_splitter.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_overhang_support.dart';
import 'package:qidi_flow_flutter/core/slicer/extrusion_entity.dart';
import 'package:qidi_flow_flutter/core/slicer/flow.dart';

SourcePolygon2 box(int minX, int minY, int maxX, int maxY) =>
    SourcePolygon2([
      SourcePoint2(minX, minY),
      SourcePoint2(maxX, minY),
      SourcePoint2(maxX, maxY),
      SourcePoint2(minX, maxY),
    ]);

final supportedFlow = Flow.nonBridging(
  width: 0.45,
  height: 0.2,
  nozzleDiameter: 0.4,
);
final overhangFlow = Flow.bridging(
  diameter: 0.4,
  nozzleDiameter: 0.4,
);

void main() {
  const splitter = SourceClassicOverhangSplitter2();

  test('detect_bridge_wall marks straight run as degree 6', () {
    final straight = SourcePolyline2(const [
      SourcePoint2(0, 0),
      SourcePoint2(50, 0),
      SourcePoint2(100, 0),
    ]);

    expect(splitter.unsupportedOverhangDegree(straight), 6);
  });

  test('detect_bridge_wall marks bent run as degree 5', () {
    final bent = SourcePolyline2(const [
      SourcePoint2(0, 0),
      SourcePoint2(100, 0),
      SourcePoint2(100, 100),
    ]);

    expect(splitter.unsupportedOverhangDegree(bent), 5);
  });

  test('fully supported loop keeps perimeter role and source layer height', () {
    final paths = splitter.splitWithoutSpeedGrading(
      polygon: box(0, 0, 100, 100),
      lowerPolygonsSeries: [
        [box(-50, -50, 150, 150)],
      ],
      supportedRole: ExtrusionRole.externalPerimeter,
      supportedFlow: supportedFlow,
      overhangFlow: overhangFlow,
      layerHeight: 0.2,
    );

    expect(paths, hasLength(1));
    expect(paths.single.role, ExtrusionRole.externalPerimeter);
    expect(paths.single.getOverhangDegree(), 0);
    expect(paths.single.mm3PerMm, closeTo(supportedFlow.mm3PerMm, 1e-12));
    expect(paths.single.width, supportedFlow.width);
    expect(paths.single.height, 0.2);
  });

  test('half-supported loop preserves supported run and open-subject seam', () {
    final paths = splitter.splitWithoutSpeedGrading(
      polygon: box(0, 0, 100, 100),
      lowerPolygonsSeries: [
        [box(50, -50, 150, 150)],
      ],
      supportedRole: ExtrusionRole.externalPerimeter,
      supportedFlow: supportedFlow,
      overhangFlow: overhangFlow,
      layerHeight: 0.2,
    );

    expect(paths, hasLength(3));
    final supported = paths.singleWhere(
      (path) => path.role == ExtrusionRole.externalPerimeter,
    );
    final unsupported = paths
        .where((path) => path.role == ExtrusionRole.overhangPerimeter)
        .toList(growable: false);

    expect(supported.getOverhangDegree(), 0);
    expect(supported.mm3PerMm, closeTo(supportedFlow.mm3PerMm, 1e-12));
    expect(supported.height, 0.2);

    expect(unsupported, hasLength(2));
    expect(
      unsupported.map((path) => path.getOverhangDegree()).toSet(),
      {5, 6},
    );
    for (final path in unsupported) {
      expect(path.mm3PerMm, closeTo(overhangFlow.mm3PerMm, 1e-12));
      expect(path.width, overhangFlow.width);
      expect(path.height, overhangFlow.height);
      expect(path.polyline.isClosed, false);
    }
  });

  test('fully unsupported loop uses overhang role and flow', () {
    final paths = splitter.splitWithoutSpeedGrading(
      polygon: box(0, 0, 100, 100),
      lowerPolygonsSeries: [
        [box(200, 200, 300, 300)],
      ],
      supportedRole: ExtrusionRole.perimeter,
      supportedFlow: supportedFlow,
      overhangFlow: overhangFlow,
      layerHeight: 0.2,
    );

    expect(paths, hasLength(1));
    expect(paths.single.role, ExtrusionRole.overhangPerimeter);
    expect(paths.single.getOverhangDegree(), 5);
    expect(paths.single.mm3PerMm, closeTo(overhangFlow.mm3PerMm, 1e-12));
  });

  test('speed grading keeps front-supported perimeter at degree zero', () {
    final support = [box(-50000, -50000, 250000, 250000)];
    final paths = splitter.splitWithSpeedGrading(
      polygon: box(0, 0, 200000, 200000),
      lowerPolygonsSeries: [support, support],
      overhangDistBoundary: const SourceOverhangDistanceBoundary2(0, 200000),
      supportedRole: ExtrusionRole.externalPerimeter,
      supportedFlow: supportedFlow,
      overhangFlow: overhangFlow,
      layerHeight: 0.2,
    );

    expect(paths, hasLength(1));
    expect(paths.single.role, ExtrusionRole.externalPerimeter);
    expect(paths.single.overhangDegree, 0);
    expect(paths.single.mm3PerMm, closeTo(supportedFlow.mm3PerMm, 1e-12));
    expect(paths.single.width, supportedFlow.width);
    expect(paths.single.height, 0.2);
  });

  test('speed grading assigns intermediate degrees with normal wall flow', () {
    final paths = splitter.splitWithSpeedGrading(
      polygon: box(0, 0, 200000, 200000),
      lowerPolygonsSeries: [
        [box(-50000, -50000, 100000, 250000)],
        [box(-50000, -50000, 250000, 250000)],
      ],
      overhangDistBoundary: const SourceOverhangDistanceBoundary2(0, 200000),
      supportedRole: ExtrusionRole.externalPerimeter,
      supportedFlow: supportedFlow,
      overhangFlow: overhangFlow,
      layerHeight: 0.2,
    );

    expect(paths, isNotEmpty);
    expect(
      paths.every((path) => path.role == ExtrusionRole.externalPerimeter),
      true,
    );
    expect(
      paths.any((path) => path.overhangDegree > 0 && path.overhangDegree < 5),
      true,
    );
    expect(paths.any((path) => path.overhangDegree == 0), true);
    for (final path in paths) {
      expect(path.mm3PerMm, closeTo(supportedFlow.mm3PerMm, 1e-12));
      expect(path.width, supportedFlow.width);
      expect(path.height, 0.2);
    }
  });

  test('speed grading leaves fully unsupported run on overhang flow', () {
    final remote = [box(300000, 300000, 400000, 400000)];
    final paths = splitter.splitWithSpeedGrading(
      polygon: box(0, 0, 100000, 100000),
      lowerPolygonsSeries: [remote, remote],
      overhangDistBoundary: const SourceOverhangDistanceBoundary2(0, 200000),
      supportedRole: ExtrusionRole.perimeter,
      supportedFlow: supportedFlow,
      overhangFlow: overhangFlow,
      layerHeight: 0.2,
    );

    expect(paths, hasLength(1));
    expect(paths.single.role, ExtrusionRole.overhangPerimeter);
    expect(paths.single.getOverhangDegree(), 5);
    expect(paths.single.mm3PerMm, closeTo(overhangFlow.mm3PerMm, 1e-12));
    expect(paths.single.width, overhangFlow.width);
    expect(paths.single.height, overhangFlow.height);
  });
}
