import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/point.dart';
import 'package:qidi_flow_flutter/core/model_io/mesh.dart';
import 'package:qidi_flow_flutter/core/model_io/three_mf_parser.dart';
import 'package:qidi_flow_flutter/core/model_io/three_mf_project_writer.dart';
import 'package:qidi_flow_flutter/core/model_io/three_mf_transform.dart';
import 'package:qidi_flow_flutter/features/workspace/domain/workspace_editable_project.dart';

void main() {
  Mesh triangle(String name, double x) => Mesh(
        name: name,
        triangles: [
          Triangle(
            Point3(x, 0, 0),
            Point3(x + 10, 0, 0),
            Point3(x, 10, 0),
          ),
        ],
      );

  const projectSettings = <String, dynamic>{
    'printer_settings_id': 'Machine',
    'print_settings_id': 'Process',
    'filament_settings_id': ['Filament'],
    'nozzle_diameter': ['0.4'],
    'printable_area': ['0x0', '100x0', '100x100', '0x100'],
  };

  test('editable project creates and reassigns multi-plate objects', () {
    var project = WorkspaceEditableProject.empty()
        .addObject(triangle('A', 0), plateIndex: 0)
        .addPlate(name: 'Second')
        .addObject(triangle('B', 20), plateIndex: 1);

    expect(project.plates.map((p) => p.name), ['Plate 1', 'Second']);
    expect(project.objectIndicesForPlate(0), [0]);
    expect(project.objectIndicesForPlate(1), [1]);

    project = project.updateObject(0, plateIndex: 1);
    expect(project.objectIndicesForPlate(0), isEmpty);
    expect(project.objectIndicesForPlate(1), [0, 1]);

    project = project.removePlate(0);
    expect(project.plates, hasLength(1));
    expect(project.objects.every((object) => object.plateIndex == 0), isTrue);
  });

  test('object transform and settings remain attached to selected object', () {
    var project = WorkspaceEditableProject.empty()
        .addObject(triangle('A', 0), plateIndex: 0);

    project = project.transformObject(
      0,
      translation: const Point3(5, -2, 3),
    );
    project = project.updateObject(
      0,
      name: 'Renamed',
      extruder: 2,
      settings: const {
        'wall_loops': '4',
        'sparse_infill_density': '25%',
      },
    );

    final object = project.objects.single;
    expect(object.name, 'Renamed');
    expect(object.extruder, 2);
    expect(object.settings['wall_loops'], '4');
    expect(object.settings['sparse_infill_density'], '25%');
    expect(object.mesh.bounds.min.x, 5);
    expect(object.mesh.bounds.min.y, -2);
    expect(object.mesh.bounds.min.z, 3);
  });

  test('editable project serializes plates and per-object overrides to 3MF', () {
    final editable = WorkspaceEditableProject.empty()
        .addObject(
          triangle('A', 0),
          plateIndex: 0,
          settings: const {'wall_loops': '3'},
        )
        .addPlate(name: 'Plate B')
        .addObject(
          triangle('B', 20),
          plateIndex: 1,
          extruder: 2,
          settings: const {'sparse_infill_density': '30%'},
        );

    final project = editable.toThreeMfProject(
      projectSettings: projectSettings,
      workspaceToPrinter: ThreeMfTransform.fromComponents(
        translation: const Point3(50, 50, 0),
      ),
    );
    final bytes = const ThreeMfProjectWriter().encode(project);
    final package = const ThreeMfParser().parsePackage(bytes);
    final settings = package.modelSettingsXml!;

    expect(settings, contains('plater_name" value="Plate 1"'));
    expect(settings, contains('plater_name" value="Plate B"'));
    expect(settings, contains('key="wall_loops" value="3"'));
    expect(settings, contains('key="extruder" value="2"'));
    expect(settings, contains('key="sparse_infill_density" value="30%"'));

    final root = utf8.decode(package.entry('3D/3dmodel.model')!);
    expect(root, contains('QidiNewMorrax:ProjectBoundary'));
    expect(package.mesh.triangles, hasLength(2));
  });

  test('editable object supports modifier and support volumes', () {
    var project = WorkspaceEditableProject.empty()
        .addObject(triangle('Base', 0), plateIndex: 0);

    project = project
        .addVolume(
          0,
          triangle('Modifier', 2),
          name: 'Dense zone',
          type: WorkspaceEditableVolume.modifier,
          settings: const {'sparse_infill_density': '80%'},
        )
        .addVolume(
          0,
          triangle('Enforcer', 4),
          type: WorkspaceEditableVolume.supportEnforcer,
        )
        .addVolume(
          0,
          triangle('Blocker', 6),
          type: WorkspaceEditableVolume.supportBlocker,
        );

    expect(project.objects.single.volumes, hasLength(4));
    expect(
      project.objects.single.volumes.map((volume) => volume.type),
      [
        WorkspaceEditableVolume.normalPart,
        WorkspaceEditableVolume.modifier,
        WorkspaceEditableVolume.supportEnforcer,
        WorkspaceEditableVolume.supportBlocker,
      ],
    );

    project = project.updateVolume(
      0,
      1,
      name: 'Sparse zone',
      type: WorkspaceEditableVolume.modifier,
      settings: const {'sparse_infill_density': '10%'},
    );
    expect(project.objects.single.volumes[1].name, 'Sparse zone');
    expect(
      project.objects.single.volumes[1].settings['sparse_infill_density'],
      '10%',
    );

    project = project.removeVolume(0, 2);
    expect(project.objects.single.volumes, hasLength(3));
    expect(
      () => WorkspaceEditableProject.empty()
          .addObject(triangle('Only', 0), plateIndex: 0)
          .removeVolume(0, 0),
      throwsStateError,
    );
  });

  test('editable volume subtypes and overrides serialize to model settings', () {
    final editable = WorkspaceEditableProject.empty()
        .addObject(triangle('Base', 0), plateIndex: 0)
        .addVolume(
          0,
          triangle('Modifier', 2),
          name: 'Modifier',
          type: WorkspaceEditableVolume.modifier,
          settings: const {
            'wall_loops': '5',
            'sparse_infill_density': '75%',
          },
        )
        .addVolume(
          0,
          triangle('Enforcer', 4),
          name: 'Support Enforcer',
          type: WorkspaceEditableVolume.supportEnforcer,
        )
        .addVolume(
          0,
          triangle('Blocker', 6),
          name: 'Support Blocker',
          type: WorkspaceEditableVolume.supportBlocker,
        );

    final project = editable.toThreeMfProject(
      projectSettings: projectSettings,
      workspaceToPrinter: ThreeMfTransform.identity,
    );
    final bytes = const ThreeMfProjectWriter().encode(project);
    final package = const ThreeMfParser().parsePackage(bytes);
    final settings = package.modelSettingsXml!;

    expect(settings, contains('subtype="normal_part"'));
    expect(settings, contains('subtype="modifier"'));
    expect(settings, contains('subtype="support_enforcer"'));
    expect(settings, contains('subtype="support_blocker"'));
    expect(settings, contains('key="wall_loops" value="5"'));
    expect(settings, contains('key="sparse_infill_density" value="75%"'));
    expect(package.mesh.triangles, hasLength(4));
  });


  test('facet paint keeps channels independent and source-shaped', () {
    final paintedMesh = Mesh(
      name: 'Painted',
      triangles: [
        Triangle(
          const Point3(0, 0, 0),
          const Point3(10, 0, 0),
          const Point3(0, 10, 0),
        ),
        Triangle(
          const Point3(10, 0, 0),
          const Point3(10, 10, 0),
          const Point3(0, 10, 0),
        ),
        Triangle(
          const Point3(0, 10, 0),
          const Point3(10, 10, 0),
          const Point3(5, 15, 0),
        ),
      ],
    );

    var project = WorkspaceEditableProject.empty()
        .addObject(paintedMesh, plateIndex: 0);
    project = project
        .paintFacets(
          0,
          0,
          const [0, 1],
          channel: WorkspaceFacetPaintChannel.supports,
          state: WorkspaceFacetPaintState.enforcer,
        )
        .paintFacets(
          0,
          0,
          const [1],
          channel: WorkspaceFacetPaintChannel.seam,
          state: WorkspaceFacetPaintState.blocker,
        )
        .paintFacets(
          0,
          0,
          const [2],
          channel: WorkspaceFacetPaintChannel.fuzzySkin,
          state: WorkspaceFacetPaintState.enforcer,
        );

    final facets = project.objects.single.volumes.single.facets;
    expect(facets[0]!.supports, '4');
    expect(facets[0]!.seam, isNull);
    expect(facets[1]!.supports, '4');
    expect(facets[1]!.seam, '8');
    expect(facets[2]!.fuzzySkin, '4');

    project = project.clearFacetPaint(
      0,
      0,
      const [1],
      channel: WorkspaceFacetPaintChannel.supports,
    );
    final cleared = project.objects.single.volumes.single.facets[1]!;
    expect(cleared.supports, isNull);
    expect(cleared.seam, '8');

    expect(
      () => project.paintFacets(
        0,
        0,
        const [0],
        channel: WorkspaceFacetPaintChannel.fuzzySkin,
        state: WorkspaceFacetPaintState.blocker,
      ),
      throwsArgumentError,
    );
    expect(
      () => project.paintFacets(
        0,
        0,
        const [99],
        channel: WorkspaceFacetPaintChannel.supports,
        state: WorkspaceFacetPaintState.enforcer,
      ),
      throwsRangeError,
    );

    final modifierProject = WorkspaceEditableProject.empty()
        .addObject(triangle('Base', 0), plateIndex: 0)
        .addVolume(
          0,
          triangle('Modifier', 2),
          type: WorkspaceEditableVolume.modifier,
        );
    expect(
      () => modifierProject.paintFacets(
        0,
        1,
        const [0],
        channel: WorkspaceFacetPaintChannel.supports,
        state: WorkspaceFacetPaintState.enforcer,
      ),
      throwsStateError,
    );
  });

  test('facet paint serializes into Orca triangle attributes', () {
    var project = WorkspaceEditableProject.empty()
        .addObject(triangle('Paint', 0), plateIndex: 0);
    project = project
        .paintFacets(
          0,
          0,
          const [0],
          channel: WorkspaceFacetPaintChannel.supports,
          state: WorkspaceFacetPaintState.enforcer,
        )
        .paintFacets(
          0,
          0,
          const [0],
          channel: WorkspaceFacetPaintChannel.seam,
          state: WorkspaceFacetPaintState.blocker,
        )
        .paintFacets(
          0,
          0,
          const [0],
          channel: WorkspaceFacetPaintChannel.fuzzySkin,
          state: WorkspaceFacetPaintState.enforcer,
        );

    final bytes = const ThreeMfProjectWriter().encode(
      project.toThreeMfProject(
        projectSettings: projectSettings,
        workspaceToPrinter: ThreeMfTransform.identity,
      ),
    );
    final package = const ThreeMfParser().parsePackage(bytes);
    final child = utf8.decode(package.entry('3D/Objects/object_1.model')!);

    expect(child, contains('paint_supports="4"'));
    expect(child, contains('paint_seam="8"'));
    expect(child, contains('paint_fuzzy_skin="4"'));
  });


  test('MMU whole-facet slot encoding matches pinned Orca', () {
    expect(WorkspaceEditableProject.facetColorForFilamentSlot(1), '4');
    expect(WorkspaceEditableProject.facetColorForFilamentSlot(2), '8');
    expect(WorkspaceEditableProject.facetColorForFilamentSlot(3), '0C');
    expect(WorkspaceEditableProject.facetColorForFilamentSlot(4), '1C');
    expect(WorkspaceEditableProject.facetColorForFilamentSlot(16), 'DC');

    expect(WorkspaceEditableProject.filamentSlotFromFacetColor('4'), 1);
    expect(WorkspaceEditableProject.filamentSlotFromFacetColor('8'), 2);
    expect(WorkspaceEditableProject.filamentSlotFromFacetColor('0C'), 3);
    expect(WorkspaceEditableProject.filamentSlotFromFacetColor('DC'), 16);
    expect(WorkspaceEditableProject.filamentSlotFromFacetColor('bad'), isNull);

    expect(
      () => WorkspaceEditableProject.facetColorForFilamentSlot(0),
      throwsRangeError,
    );
    expect(
      () => WorkspaceEditableProject.facetColorForFilamentSlot(17),
      throwsRangeError,
    );
  });

  test('MMU facet paint serializes and remaps removed slots', () {
    final mesh = Mesh(
      name: 'MMU',
      triangles: [
        Triangle(
          const Point3(0, 0, 0),
          const Point3(10, 0, 0),
          const Point3(0, 10, 0),
        ),
        Triangle(
          const Point3(10, 0, 0),
          const Point3(10, 10, 0),
          const Point3(0, 10, 0),
        ),
        Triangle(
          const Point3(0, 10, 0),
          const Point3(10, 10, 0),
          const Point3(5, 15, 0),
        ),
      ],
    );

    var project = WorkspaceEditableProject.empty()
        .addObject(mesh, plateIndex: 0, extruder: 2)
        .paintFacets(
          0,
          0,
          const [0],
          channel: WorkspaceFacetPaintChannel.supports,
          state: WorkspaceFacetPaintState.enforcer,
        )
        .paintFilamentFacets(0, 0, const [0], filamentSlot: 2)
        .paintFilamentFacets(0, 0, const [1], filamentSlot: 3)
        .paintFilamentFacets(0, 0, const [2], filamentSlot: 4);

    var facets = project.objects.single.volumes.single.facets;
    expect(facets[0]!.supports, '4');
    expect(facets[0]!.color, '8');
    expect(facets[1]!.color, '0C');
    expect(facets[2]!.color, '1C');

    final bytes = const ThreeMfProjectWriter().encode(
      project.toThreeMfProject(
        projectSettings: <String, dynamic>{
          ...projectSettings,
          'filament_settings_id': const ['PLA', 'PETG', 'ABS', 'TPU'],
        },
        workspaceToPrinter: ThreeMfTransform.identity,
      ),
    );
    final package = const ThreeMfParser().parsePackage(bytes);
    final child = utf8.decode(package.entry('3D/Objects/object_1.model')!);
    expect(child, contains('paint_color="8"'));

    project = project.remapFilamentFacetSlotsAfterRemoval(2);
    facets = project.objects.single.volumes.single.facets;
    expect(facets[0]!.color, '4');
    expect(facets[0]!.supports, '4');
    expect(facets[1]!.color, '8');
    expect(facets[2]!.color, '0C');

    project = project.clearFilamentFacetPaint(0, 0, const [0]);
    expect(project.objects.single.volumes.single.facets[0]!.color, isNull);
    expect(project.objects.single.volumes.single.facets[0]!.supports, '4');
  });

}
