import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polyline.dart';
import 'package:qidi_flow_flutter/core/slicer/extrusion_entity.dart';
import 'package:qidi_flow_flutter/core/slicer/source_shortest_path.dart';

ExtrusionPath2 path(
  int x0,
  int x1, {
  bool canReverse = true,
}) =>
    ExtrusionPath2(
      role: ExtrusionRole.perimeter,
      mm3PerMm: 0.1,
      width: 0.4,
      height: 0.2,
      canReverse: canReverse,
      polyline: SourcePolyline2([
        SourcePoint2(x0, 0),
        SourcePoint2(x1, 0),
      ]),
    );

ExtrusionLoop2 loopAt(int x) {
  final p = ExtrusionPath2(
    role: ExtrusionRole.externalPerimeter,
    mm3PerMm: 0.1,
    width: 0.4,
    height: 0.2,
    polyline: SourcePolyline2([
      SourcePoint2(x, 0),
      SourcePoint2(x + 10, 0),
      SourcePoint2(x + 10, 10),
      SourcePoint2(x, 10),
      SourcePoint2(x, 0),
    ]),
  );
  return ExtrusionLoop2(paths: [p]);
}

void main() {
  test('single reversible entity starts at endpoint nearest start_near', () {
    final entities = <ExtrusionEntity2>[path(100, 0)];
    expect(
      SourceShortestPath2.chainExtrusionEntities(
        entities,
        startNear: const SourcePoint2(0, 0),
      ),
      const [SourceEntityChainEntry2(0, true)],
    );
  });

  test('multi-fragment chain records reversals needed by nearest endpoints', () {
    final entities = <ExtrusionEntity2>[
      path(0, 10),
      path(30, 20),
      path(40, 50),
    ];

    expect(
      SourceShortestPath2.chainExtrusionEntities(
        entities,
        startNear: const SourcePoint2(0, 0),
      ),
      const [
        SourceEntityChainEntry2(0, false),
        SourceEntityChainEntry2(1, true),
        SourceEntityChainEntry2(2, false),
      ],
    );
  });

  test('non-reversible orientation triggers source closest-point fallback', () {
    final entities = <ExtrusionEntity2>[
      path(0, 10),
      path(30, 20, canReverse: false),
    ];

    expect(
      SourceShortestPath2.chainExtrusionEntities(
        entities,
        startNear: const SourcePoint2(0, 0),
      ),
      const [
        SourceEntityChainEntry2(0, false),
        SourceEntityChainEntry2(1, false),
      ],
    );
  });

  test('loop reversal chosen internally is suppressed by wrapper contract', () {
    final entities = <ExtrusionEntity2>[loopAt(100)];
    expect(
      SourceShortestPath2.chainExtrusionEntities(
        entities,
        startNear: const SourcePoint2(110, 10),
      ),
      const [SourceEntityChainEntry2(0, false)],
    );
  });

  test('reorder applies reversal to open entity and preserves chain order', () {
    final first = path(0, 10);
    final second = path(30, 20);
    final entities = <ExtrusionEntity2>[first, second];
    const chain = [
      SourceEntityChainEntry2(1, true),
      SourceEntityChainEntry2(0, false),
    ];

    SourceShortestPath2.reorderExtrusionEntities(entities, chain);

    expect(identical(entities[0], second), true);
    expect(entities[0].firstPoint, const SourcePoint2(20, 0));
    expect(entities[0].lastPoint, const SourcePoint2(30, 0));
    expect(identical(entities[1], first), true);
  });
}
