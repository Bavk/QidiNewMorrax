import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/extrusion_entity.dart';
import 'package:qidi_flow_flutter/core/slicer/flow.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_extrusion_line.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_extrusion_line_variable_width.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_extrusion_order.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_extrusion_traversal.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_apply.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_policy.dart';

class EmptyRandom implements SourceFuzzyUnitRandom2 {
  @override
  double nextUnit() => throw StateError('identity traversal consumed RNG');
}

SourceFuzzySkinNoRegionConfig2 identityFuzzy() =>
    const SourceFuzzySkinNoRegionConfig2(
      type: SourceFuzzySkinType2.none,
      fuzzySkinFirstLayer: true,
      thicknessMm: 0.1,
      pointDistanceMm: 0.4,
      noiseType: SourceFuzzyNoiseType2.classic,
    );

Flow perimeterFlow() => Flow.nonBridging(
      width: 0.45,
      height: 0.2,
      nozzleDiameter: 0.4,
    );

Flow externalFlow() => Flow.nonBridging(
      width: 0.42,
      height: 0.2,
      nozzleDiameter: 0.4,
    );

SourceArachneExtrusionJunction2 junction(
  int x,
  int y, {
  int width = 40000,
  bool compensate = false,
}) =>
    SourceArachneExtrusionJunction2(
      p: SourcePoint2(x, y),
      w: width,
      perimeterIndex: 0,
      holeCompensationFlag: compensate,
    );

SourceArachneExtrusionTraversalSettings2 settings({
  bool detectOverhangWall = false,
  bool zDirectionOutwallSpeedContinuous = false,
}) =>
    SourceArachneExtrusionTraversalSettings2(
      perimeterFlow: perimeterFlow(),
      externalPerimeterFlow: externalFlow(),
      fuzzyConfig: identityFuzzy(),
      layerId: 1,
      sliceZMm: 0.2,
      detectOverhangWall: detectOverhangWall,
      zDirectionOutwallSpeedContinuous: zDirectionOutwallSpeedContinuous,
    );

void main() {
  test('toThickPolyline preserves source segment endpoint widths and flags', () {
    final line = SourceArachneExtrusionLine2(
      insetIndex: 0,
      isOdd: false,
      junctions: [
        junction(0, 0, width: 10000),
        junction(100000, 0, width: 20000),
        junction(200000, 0, width: 30000),
      ],
    );

    final thick = line.toThickPolylineSource();
    expect(thick.points, const [
      SourcePoint2(0, 0),
      SourcePoint2(100000, 0),
      SourcePoint2(200000, 0),
    ]);
    expect(thick.width, const [10000, 20000, 20000, 30000]);
    expect(thick.startIsEndpoint, true);
    expect(thick.endIsEndpoint, true);
  });

  test('closed external contour becomes oriented loop with compensation', () {
    final line = SourceArachneExtrusionLine2(
      insetIndex: 0,
      isOdd: false,
      isClosed: true,
      junctions: [
        junction(0, 0, compensate: true),
        junction(0, 200000, compensate: true),
        junction(200000, 200000, compensate: true),
        junction(200000, 0, compensate: true),
        junction(0, 0, compensate: true),
      ],
    );

    final result = SourceArachneExtrusionTraversal2.traverse(
      orderedExtrusions: [
        SourceArachneOrderedExtrusion2(
          extrusion: line,
          isContour: true,
        ),
      ],
      settings: settings(),
      random: EmptyRandom(),
    );

    expect(result.entities, hasLength(1));
    final loop = result.entities.single as ExtrusionLoop2;
    expect(loop.role, ExtrusionRole.externalPerimeter);
    expect(loop.loopRole, ExtrusionLoopRoles.defaultRole);
    expect(loop.isCounterClockwise, true);
    expect(loop.customizeFlag, CustomizeFlag.circleCompensation);
    expect(
      loop.paths.every(
        (path) => path.customizeFlag == CustomizeFlag.circleCompensation,
      ),
      true,
    );
  });

  test('open internal wall becomes one connected source multipath', () {
    final line = SourceArachneExtrusionLine2(
      insetIndex: 1,
      isOdd: false,
      junctions: [
        junction(0, 0),
        junction(100000, 0),
        junction(200000, 0),
      ],
    );

    final result = SourceArachneExtrusionTraversal2.traverse(
      orderedExtrusions: [
        SourceArachneOrderedExtrusion2(
          extrusion: line,
          isContour: false,
        ),
      ],
      settings: settings(),
      random: EmptyRandom(),
    );

    expect(result.entities, hasLength(1));
    final multi = result.entities.single as ExtrusionMultiPath2;
    expect(multi.role, ExtrusionRole.perimeter);
    expect(multi.firstPoint, const SourcePoint2(0, 0));
    expect(multi.lastPoint, const SourcePoint2(200000, 0));
    expect(multi.customizeFlag, CustomizeFlag.none);
  });

  test('active overhang branch is rejected instead of approximated', () {
    final line = SourceArachneExtrusionLine2(
      insetIndex: 0,
      isOdd: false,
      junctions: [junction(0, 0), junction(100000, 0)],
    );

    expect(
      () => SourceArachneExtrusionTraversal2.traverse(
        orderedExtrusions: [
          SourceArachneOrderedExtrusion2(
            extrusion: line,
            isContour: false,
          ),
        ],
        settings: settings(detectOverhangWall: true),
        random: EmptyRandom(),
      ),
      throwsUnsupportedError,
    );
  });

  test('QIDI outwall-node producer is rejected until composed', () {
    expect(
      () => SourceArachneExtrusionTraversal2.traverse(
        orderedExtrusions: const [],
        settings: settings(zDirectionOutwallSpeedContinuous: true),
        random: EmptyRandom(),
      ),
      throwsUnsupportedError,
    );
  });
}
