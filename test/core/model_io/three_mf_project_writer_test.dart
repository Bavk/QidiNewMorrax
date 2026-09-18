import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/point.dart';
import 'package:qidi_flow_flutter/core/model_io/mesh.dart';
import 'package:qidi_flow_flutter/core/model_io/three_mf_parser.dart';
import 'package:qidi_flow_flutter/core/model_io/three_mf_project_writer.dart';
import 'package:qidi_flow_flutter/core/model_io/three_mf_transform.dart';
import 'package:qidi_flow_flutter/core/model_io/three_mf_writer.dart';

void main() {
  const projectSettings = <String, dynamic>{
    '_name': 'project_settings',
    '_from': 'project',
    '_version': '2.4.2',
    'printer_settings_id': 'Machine',
    'print_settings_id': 'Process',
    'filament_settings_id': ['Filament'],
    'nozzle_diameter': ['0.4'],
    'layer_height': '0.2',
  };

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

  test('project writer keeps objects, volumes, plates and settings', () {
    final project = ThreeMfProject(
      objects: [
        ThreeMfProjectObject(
          name: 'Object A',
          volumes: [
            ThreeMfProjectVolume(
              name: 'Body A',
              mesh: triangle('A', 0),
              settings: const {'extruder': '1'},
              facets: const {
                0: ThreeMfFacetMetadata(
                  supports: '1',
                  seam: '2',
                  color: '3',
                ),
              },
            ),
            ThreeMfProjectVolume(
              name: 'Modifier A',
              mesh: triangle('modifier', 2),
              type: 'modifier',
              settings: const {'wall_loops': '4'},
            ),
          ],
        ),
        ThreeMfProjectObject.fromMesh(
          triangle('Object B', 30),
          extruder: 2,
        ),
      ],
      plates: const [
        ThreeMfProjectPlate(
          name: 'First',
          instances: [ThreeMfPlateInstance(objectIndex: 0)],
        ),
        ThreeMfProjectPlate(
          name: 'Second',
          instances: [ThreeMfPlateInstance(objectIndex: 1)],
        ),
      ],
      projectSettings: projectSettings,
    );

    final bytes = const ThreeMfProjectWriter().encode(project);
    final package = const ThreeMfParser().parsePackage(bytes);

    expect(package.mesh.triangles, hasLength(3));
    expect(package.projectSettings['layer_height'], '0.2');

    final modelSettings = package.modelSettingsXml!;
    expect(modelSettings, contains('plater_name" value="First"'));
    expect(modelSettings, contains('plater_name" value="Second"'));
    expect(modelSettings, contains('subtype="modifier"'));
    expect(modelSettings, contains('key="extruder" value="2"'));

    final root = utf8.decode(package.entry('3D/3dmodel.model')!);
    expect(root, contains('p:path="/3D/Objects/object_1.model"'));
    expect(root, contains('requiredextensions="p"'));
    expect(package.entry('3D/_rels/3dmodel.model.rels'), isNotNull);

    final child = utf8.decode(package.entry('3D/Objects/object_1.model')!);
    expect(child, contains('paint_supports="1"'));
    expect(child, contains('paint_seam="2"'));
    expect(child, contains('paint_color="3"'));
  });

  test('project writer rejects incomplete Orca project settings', () {
    expect(
      () => const ThreeMfProjectWriter().encode(
        ThreeMfProject(
          objects: [ThreeMfProjectObject.fromMesh(triangle('A', 0))],
          projectSettings: const {'layer_height': '0.2'},
        ),
      ),
      throwsArgumentError,
    );
  });

  test('repack transform preserves vendor entries and transforms build', () {
    final original = const ThreeMfProjectWriter().encode(
      ThreeMfProject(
        objects: [ThreeMfProjectObject.fromMesh(triangle('A', 0))],
        projectSettings: projectSettings,
      ),
    );
    final parsed = const ThreeMfParser().parsePackage(original);
    final withVendor = const ThreeMfWriter().repack(
      parsed,
      replacements: {
        'Metadata/vendor_qidi.bin': Uint8List.fromList([1, 2, 3, 4]),
      },
    );
    final source = const ThreeMfParser().parsePackage(withVendor);

    final moved = const ThreeMfWriter().repackWithBuildTransform(
      source,
      ThreeMfTransform.fromComponents(
        translation: const Point3(25, -5, 3),
      ),
    );
    final result = const ThreeMfParser().parsePackage(moved);

    expect(result.entry('Metadata/vendor_qidi.bin'), [1, 2, 3, 4]);
    expect(result.mesh.bounds.min.x, closeTo(25, 1e-9));
    expect(result.mesh.bounds.min.y, closeTo(-5, 1e-9));
    expect(result.mesh.bounds.min.z, closeTo(3, 1e-9));
  });

  test('3MF transform matches Mesh.transformed component order', () {
    final point = const Point3(3, 4, 5);
    const translation = Point3(7, -2, 11);
    const scale = Point3(2, 3, 0.5);
    const rotation = Point3(20, -15, 37);

    final expected = Mesh(
      triangles: [Triangle(point, point, point)],
    ).transformed(
      translation: translation,
      scale: scale,
      rotationDegrees: rotation,
    ).triangles.single.a;

    final actual = ThreeMfTransform.fromComponents(
      translation: translation,
      scale: scale,
      rotationDegrees: rotation,
    ).apply(point);

    expect(actual.x, closeTo(expected.x, 1e-10));
    expect(actual.y, closeTo(expected.y, 1e-10));
    expect(actual.z, closeTo(expected.z, 1e-10));

    final roundTrip = ThreeMfTransform.from3mf(
      ThreeMfTransform.fromComponents(
        translation: translation,
        scale: scale,
        rotationDegrees: rotation,
      ).to3mfString(),
    ).apply(point);
    expect(roundTrip.x, closeTo(expected.x, 1e-10));
    expect(roundTrip.y, closeTo(expected.y, 1e-10));
    expect(roundTrip.z, closeTo(expected.z, 1e-10));
  });
}
