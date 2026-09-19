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

}
