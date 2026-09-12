import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polyline.dart';
import 'package:qidi_flow_flutter/core/slicer/classic_wall_sequence.dart';
import 'package:qidi_flow_flutter/core/slicer/extrusion_entity.dart';

ExtrusionPath2 openPath(
  int x0,
  int x1, {
  ExtrusionRole role = ExtrusionRole.perimeter,
}) =>
    ExtrusionPath2(
      role: role,
      mm3PerMm: 0.1,
      width: 0.4,
      height: 0.2,
      polyline: SourcePolyline2([
        SourcePoint2(x0, 0),
        SourcePoint2(x1, 0),
      ]),
    );

ExtrusionLoop2 loopAt(
  int x, {
  ExtrusionRole role = ExtrusionRole.perimeter,
  int loopRole = ExtrusionLoopRoles.defaultRole,
}) =>
    ExtrusionLoop2(
      loopRole: loopRole,
      paths: [
        ExtrusionPath2(
          role: role,
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
        ),
      ],
    );

void main() {
  test('OuterInner reverses collection order and only open child direction', () {
    final loop = loopAt(0, role: ExtrusionRole.externalPerimeter);
    final open = openPath(100, 110);
    final collection = ExtrusionEntityCollection2(entities: [loop, open]);
    final originalLoopClockwise =
        (collection.entities.first as ExtrusionLoop2).isClockwise;

    SourceClassicWallSequence2.adjust(
      collection,
      wallSequence: SourceWallSequence2.outerInner,
      layerId: 1,
      brimOuterOnly: false,
      brimWidth: 0,
    );

    expect(collection.entities.first, isA<ExtrusionPath2>());
    expect(collection.entities.first.firstPoint, const SourcePoint2(110, 0));
    expect(collection.entities.first.lastPoint, const SourcePoint2(100, 0));
    final movedLoop = collection.entities.last as ExtrusionLoop2;
    expect(movedLoop.isClockwise, originalLoopClockwise);
  });

  test('first-layer outer-only brim forces outer-first reversal', () {
    final inner = loopAt(0);
    final outer = loopAt(100, role: ExtrusionRole.externalPerimeter);
    final collection = ExtrusionEntityCollection2(entities: [inner, outer]);

    SourceClassicWallSequence2.adjust(
      collection,
      wallSequence: SourceWallSequence2.innerOuter,
      layerId: 0,
      brimOuterOnly: true,
      brimWidth: 2,
    );

    expect(collection.entities.first.role, ExtrusionRole.externalPerimeter);
    expect(collection.entities.last.role, ExtrusionRole.perimeter);
  });

  test('InnerOuterInner inserts held second wall after external wall', () {
    final second = loopAt(
      0,
      loopRole: ExtrusionLoopRoles.secondPerimeter,
    );
    final deeperInner = loopAt(100);
    final outer = loopAt(200, role: ExtrusionRole.externalPerimeter);
    final collection = ExtrusionEntityCollection2(
      entities: [second, deeperInner, outer],
    );

    SourceClassicWallSequence2.adjust(
      collection,
      wallSequence: SourceWallSequence2.innerOuterInner,
      layerId: 1,
      brimOuterOnly: false,
      brimWidth: 0,
    );

    expect(
      collection.entities.map((entity) => entity.firstPoint.x).toList(),
      [100, 200, 0],
    );
  });

  test('InnerOuterInner preserves source trailing-second-wall drop quirk', () {
    final outer = loopAt(0, role: ExtrusionRole.externalPerimeter);
    final trailingSecond = loopAt(
      100,
      loopRole: ExtrusionLoopRoles.secondPerimeter,
    );
    final collection = ExtrusionEntityCollection2(
      entities: [outer, trailingSecond],
    );

    SourceClassicWallSequence2.adjust(
      collection,
      wallSequence: SourceWallSequence2.innerOuterInner,
      layerId: 1,
      brimOuterOnly: false,
      brimWidth: 0,
    );

    expect(collection.entities, hasLength(1));
    expect(collection.entities.single.role, ExtrusionRole.externalPerimeter);
  });

  test('InnerOuterInner requires structural loops like source static_cast', () {
    final collection = ExtrusionEntityCollection2(
      entities: [openPath(0, 10), loopAt(100)],
    );

    expect(
      () => SourceClassicWallSequence2.adjust(
        collection,
        wallSequence: SourceWallSequence2.innerOuterInner,
        layerId: 1,
        brimOuterOnly: false,
        brimWidth: 0,
      ),
      throwsStateError,
    );
  });
}
