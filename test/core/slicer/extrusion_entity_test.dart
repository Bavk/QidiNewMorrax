import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polyline.dart';
import 'package:qidi_flow_flutter/core/slicer/extrusion_entity.dart';

ExtrusionPath2 path({
  ExtrusionRole role = ExtrusionRole.perimeter,
  int start = 0,
  int end = 100000,
  double mm3 = 1,
}) =>
    ExtrusionPath2(
      role: role,
      mm3PerMm: mm3,
      width: 0.4,
      height: 0.2,
      polyline: SourcePolyline2([
        SourcePoint2(start, 0),
        SourcePoint2(end, 0),
      ]),
    );

void main() {
  group('ExtrusionRole exact source semantics', () {
    test('enum order and role strings preserve supplied source', () {
      expect(ExtrusionRole.none.index, 0);
      expect(ExtrusionRole.overhangPerimeter.index, 3);
      expect(ExtrusionRole.supportTransition.index, 16);
      expect(ExtrusionRole.flush.index, 20);
      expect(ExtrusionRole.mixed.index, 21);
      expect(ExtrusionRole.count.index, 22);

      expect(extrusionRoleToString(ExtrusionRole.perimeter), 'Inner wall');
      expect(extrusionRoleToString(ExtrusionRole.externalPerimeter), 'Outer wall');
      expect(extrusionRoleToString(ExtrusionRole.wipeTower), 'Prime tower');
      expect(extrusionRoleFromString('Support transition'), ExtrusionRole.supportTransition);
      expect(extrusionRoleFromString('not-a-source-role'), ExtrusionRole.none);
    });

    test('role classifiers preserve bridge/support/infill distinctions', () {
      expect(isPerimeterRole(ExtrusionRole.overhangPerimeter), true);
      expect(isBridgeRole(ExtrusionRole.overhangPerimeter), true);
      expect(isInfillRole(ExtrusionRole.overhangPerimeter), false);
      expect(isSolidInfillRole(ExtrusionRole.internalInfill), false);
      expect(isSolidInfillRole(ExtrusionRole.bottomSurface), true);
      expect(isSupportRole(ExtrusionRole.supportTransition), true);
    });
  });

  group('ExtrusionPath source behavior', () {
    test('total_volume unscales floating source length without coord rounding', () {
      final diagonal = ExtrusionPath2(
        role: ExtrusionRole.perimeter,
        mm3PerMm: 2,
        width: 0.4,
        height: 0.2,
        polyline: SourcePolyline2(const [
          SourcePoint2(0, 0),
          SourcePoint2(1, 1),
        ]),
      );
      expect(
        diagonal.totalVolume,
        closeTo(2 * 1.4142135623730951 * 0.00001, 1e-15),
      );
    });

    test('overhang setter only affects perimeter/support and clamps 0..10', () {
      final perimeter = path();
      perimeter.setOverhangDegree(50);
      expect(perimeter.getOverhangDegree(), 10);

      final infill = path(role: ExtrusionRole.internalInfill)
        ..overhangDegree = 7;
      infill.setOverhangDegree(2);
      expect(infill.overhangDegree, 7);
      expect(infill.getOverhangDegree(), 0);
    });

    test('can_merge intentionally ignores overhang/customize/cooling/polyline', () {
      final a = path()
        ..overhangDegree = 1
        ..customizeFlag = CustomizeFlag.circleCompensation
        ..coolingNode = 3;
      final b = path(start: 999, end: 1999)
        ..overhangDegree = 9
        ..customizeFlag = CustomizeFlag.floatingVerticalShell
        ..coolingNode = 99;
      expect(a.canMerge(b), true);

      b.smoothSpeed = 1;
      expect(a.canMerge(b), false);
    });

    test('base ExtrusionPath clone preserves base fields', () {
      final source = path()
        ..customizeFlag = CustomizeFlag.circleCompensation
        ..coolingNode = 8;
      final cloned = source.cloneEntity();
      expect(cloned.customizeFlag, CustomizeFlag.circleCompensation);
      expect(cloned.coolingNode, 8);
    });

    test('sloped path inherits source base clone and slices to ExtrusionPath', () {
      final source = ExtrusionPathSloped2.fromPath(
        path(),
        slopeBegin: const ExtrusionSlope2(zRatio: 0.5),
        slopeEnd: const ExtrusionSlope2(zRatio: 1),
      );
      expect(source.cloneEntity().runtimeType, ExtrusionPath2);
    });

    test('oriented path clone preserves oriented dynamic type', () {
      final source = ExtrusionPathOriented2(
        role: ExtrusionRole.perimeter,
        mm3PerMm: 1,
        width: 0.4,
        height: 0.2,
        polyline: SourcePolyline2(const [
          SourcePoint2(0, 0),
          SourcePoint2(10, 0),
        ]),
      );
      expect(source.cloneEntity(), isA<ExtrusionPathOriented2>());
      expect(source.cloneEntity().canReverse, false);
    });
  });

  group('ExtrusionMultiPath source quirks', () {
    test('single-path constructor copies child can_reverse', () {
      final p = path()..setReverseAllowedFalse();
      expect(ExtrusionMultiPath2.fromSinglePath(p).canReverse, false);
    });

    test('vector constructor keeps default multipath can_reverse=true', () {
      final p = path()..setReverseAllowedFalse();
      expect(ExtrusionMultiPath2(paths: [p]).canReverse, true);
    });

    test('source clone resets base customize/cooling due explicit copy ctor', () {
      final source = ExtrusionMultiPath2(paths: [path()])
        ..customizeFlag = CustomizeFlag.circleCompensation
        ..coolingNode = 5;
      final clone = source.cloneEntity();
      expect(clone.customizeFlag, CustomizeFlag.none);
      expect(clone.coolingNode, -1);
    });

    test('as_polyline removes equal connecting point exactly once', () {
      final multi = ExtrusionMultiPath2(paths: [
        path(start: 0, end: 10),
        path(start: 10, end: 20),
      ]);
      expect(
        multi.asPolyline().points,
        const [
          SourcePoint2(0, 0),
          SourcePoint2(10, 0),
          SourcePoint2(20, 0),
        ],
      );
    });
  });

  group('ExtrusionLoop / Collection source behavior', () {
    test('collection reverse does not reverse loop winding', () {
      final loopPath = ExtrusionPath2(
        role: ExtrusionRole.perimeter,
        mm3PerMm: 1,
        width: 0.4,
        height: 0.2,
        polyline: SourcePolyline2(const [
          SourcePoint2(0, 0),
          SourcePoint2(10, 0),
          SourcePoint2(10, 10),
          SourcePoint2(0, 0),
        ]),
      );
      final loop = ExtrusionLoop2(paths: [loopPath]);
      final before = loop.asPolyline().points.toList();
      final collection = ExtrusionEntityCollection2(entities: [loop, path()]);
      collection.reverse();
      final loopAfter = collection.entities.last as ExtrusionLoop2;
      expect(loopAfter.asPolyline().points, before);
    });

    test('collection role returns mixed once child roles differ', () {
      final collection = ExtrusionEntityCollection2(entities: [
        path(role: ExtrusionRole.perimeter),
        path(role: ExtrusionRole.internalInfill),
      ]);
      expect(collection.role, ExtrusionRole.mixed);
    });

    test('source collection clone resets base customize/cooling', () {
      final source = ExtrusionEntityCollection2(entities: [path()])
        ..customizeFlag = CustomizeFlag.circleCompensation
        ..coolingNode = 17;
      final clone = source.cloneEntity();
      expect(clone.customizeFlag, CustomizeFlag.none);
      expect(clone.coolingNode, -1);
    });

    test('translated test_extrusion_entity flatten default removes collections', () {
      final noSort = ExtrusionEntityCollection2(
        noSort: true,
        entities: [path(start: 0, end: 1), path(start: 2, end: 3)],
      );
      final sortable = ExtrusionEntityCollection2(
        entities: [path(start: 4, end: 5)],
      );
      final sample = ExtrusionEntityCollection2(
        entities: [sortable, noSort, sortable],
      );

      final flat = sample.flatten();
      expect(flat.entities.whereType<ExtrusionEntityCollection2>(), isEmpty);
      expect(flat.itemsCount, 4);
    });

    test('translated flatten preserve_order keeps no_sort child and order', () {
      final noSort = ExtrusionEntityCollection2(
        noSort: true,
        entities: [path(start: 10, end: 11), path(start: 20, end: 21)],
      );
      final sortable = ExtrusionEntityCollection2(
        entities: [path(start: 30, end: 31)],
      );
      final sample = ExtrusionEntityCollection2(
        entities: [sortable, noSort, sortable],
      );

      final flat = sample.flatten(preserveOrdering: true);
      final retained = flat.entities.whereType<ExtrusionEntityCollection2>().toList();
      expect(retained, hasLength(1));
      expect(retained.single.entities[0].firstPoint, const SourcePoint2(10, 0));
      expect(retained.single.entities[1].firstPoint, const SourcePoint2(20, 0));
    });

    test('supportTransition survives supportMaterial role filtering', () {
      final filtered = filterByExtrusionRole(
        [
          path(role: ExtrusionRole.supportMaterial),
          path(role: ExtrusionRole.supportTransition),
          path(role: ExtrusionRole.perimeter),
        ],
        ExtrusionRole.supportMaterial,
      );
      expect(filtered.map((e) => e.role).toList(), [
        ExtrusionRole.supportMaterial,
        ExtrusionRole.supportTransition,
      ]);
    });
  });
}
