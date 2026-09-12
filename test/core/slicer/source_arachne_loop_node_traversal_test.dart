import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/flow.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_extrusion_line.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_extrusion_order.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_extrusion_traversal.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_apply.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_geometry.dart';
import 'package:qidi_flow_flutter/core/slicer/source_fuzzy_skin_policy.dart';
import 'package:qidi_flow_flutter/core/slicer/source_loop_node.dart';

class _NoRandom implements SourceFuzzyUnitRandom2 {
  @override
  double nextUnit() => throw StateError('identity traversal consumed RNG');
}

SourceArachneExtrusionJunction2 _junction(int x, int y, int width) =>
    SourceArachneExtrusionJunction2(
      p: SourcePoint2(x, y),
      w: width,
      perimeterIndex: 0,
    );

Flow _flow(double width) => Flow.nonBridging(
      width: width,
      height: 0.2,
      nozzleDiameter: 0.4,
    );

SourceArachneExtrusionTraversalSettings2 _settings({
  required List<SourceLoopNode2> loopNodes,
  double outerWallLineWidthMm = 0.42,
}) =>
    SourceArachneExtrusionTraversalSettings2(
      perimeterFlow: _flow(0.45),
      externalPerimeterFlow: _flow(0.42),
      fuzzyConfig: const SourceFuzzySkinNoRegionConfig2(
        type: SourceFuzzySkinType2.none,
        fuzzySkinFirstLayer: true,
        thicknessMm: 0.1,
        pointDistanceMm: 0.4,
        noiseType: SourceFuzzyNoiseType2.classic,
      ),
      layerId: 1,
      sliceZMm: 0.2,
      zDirectionOutwallSpeedContinuous: true,
      loopNodes: loopNodes,
      outerWallLineWidthMm: outerWallLineWidthMm,
    );

SourceLoopNode2 _dummyNode() {
  const points = <SourcePoint2>[
    SourcePoint2(-10, -10),
    SourcePoint2(-5, -5),
  ];
  return SourceLoopNode2(
    nodeContour: SourceNodeContour2(
      points: points,
      widths: const <int>[1, 1],
      isLoop: false,
    ),
    nodeId: 0,
    loopId: 99,
    bounds: SourceLoopNodeBounds2.fromPoints(points, offset: 0),
  );
}

void main() {
  test('Arachne producer uses global ids, entity loop ids and external walls only', () {
    final globalNodes = <SourceLoopNode2>[_dummyNode()];
    final external = SourceArachneExtrusionLine2(
      insetIndex: 0,
      isOdd: false,
      junctions: <SourceArachneExtrusionJunction2>[
        _junction(0, 0, 10000),
        _junction(100000, 0, 20000),
      ],
    );
    final internal = SourceArachneExtrusionLine2(
      insetIndex: 1,
      isOdd: false,
      junctions: <SourceArachneExtrusionJunction2>[
        _junction(100000, 0, 30000),
        _junction(200000, 0, 30000),
      ],
    );
    final externalLoop = SourceArachneExtrusionLine2(
      insetIndex: 0,
      isOdd: false,
      isClosed: true,
      junctions: <SourceArachneExtrusionJunction2>[
        _junction(300000, 0, 40000),
        _junction(400000, 0, 41000),
        _junction(400000, 100000, 42000),
        _junction(300000, 100000, 43000),
        _junction(300000, 0, 40000),
      ],
    );

    final result = SourceArachneExtrusionTraversal2.traverse(
      orderedExtrusions: <SourceArachneOrderedExtrusion2>[
        SourceArachneOrderedExtrusion2(
          extrusion: external,
          isContour: false,
        ),
        SourceArachneOrderedExtrusion2(
          extrusion: internal,
          isContour: false,
        ),
        SourceArachneOrderedExtrusion2(
          extrusion: externalLoop,
          isContour: true,
        ),
      ],
      settings: _settings(loopNodes: globalNodes),
      random: _NoRandom(),
    );

    expect(result.entities, hasLength(3));
    expect(result.loopNodeRange, (1, 3));
    expect(globalNodes, hasLength(3));

    final first = globalNodes[1];
    expect(first.nodeId, 1);
    expect(first.loopId, 0);
    expect(first.nodeContour.isLoop, isFalse);
    expect(first.nodeContour.points, const <SourcePoint2>[
      SourcePoint2(0, 0),
      SourcePoint2(100000, 0),
    ]);
    expect(first.nodeContour.widths, const <int>[10000, 20000]);

    // Source passes config->outer_wall_line_width/2 directly to the integer
    // BoundingBox Point constructor, without scale_(). 0.42/2 narrows to zero.
    expect(first.bounds.min, const SourcePoint2(0, 0));
    expect(first.bounds.max, const SourcePoint2(100000, 0));

    final second = globalNodes[2];
    expect(second.nodeId, 2);
    expect(second.loopId, 2);
    expect(second.nodeContour.isLoop, isTrue);
    expect(second.nodeContour.widths, const <int>[
      40000,
      41000,
      42000,
      43000,
      40000,
    ]);
  });

  test('Arachne bbox preserves literal coordf to coord narrowing quirk', () {
    final globalNodes = <SourceLoopNode2>[];
    final external = SourceArachneExtrusionLine2(
      insetIndex: 0,
      isOdd: false,
      junctions: <SourceArachneExtrusionJunction2>[
        _junction(10, 20, 40000),
        _junction(110, 120, 40000),
      ],
    );

    SourceArachneExtrusionTraversal2.traverse(
      orderedExtrusions: <SourceArachneOrderedExtrusion2>[
        SourceArachneOrderedExtrusion2(
          extrusion: external,
          isContour: false,
        ),
      ],
      settings: _settings(
        loopNodes: globalNodes,
        outerWallLineWidthMm: 4.2,
      ),
      random: _NoRandom(),
    );

    expect(globalNodes.single.bounds.min, const SourcePoint2(8, 18));
    expect(globalNodes.single.bounds.max, const SourcePoint2(112, 122));
  });
}
