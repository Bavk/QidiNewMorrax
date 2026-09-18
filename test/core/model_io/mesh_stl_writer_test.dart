import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/point.dart';
import 'package:qidi_flow_flutter/core/model_io/mesh.dart';
import 'package:qidi_flow_flutter/core/model_io/mesh_stl_writer.dart';

void main() {
  test('writes current Prepare mesh as Orca interchange STL', () async {
    final dir = await Directory.systemTemp.createTemp('mesh_stl_writer_test_');
    addTearDown(() => dir.delete(recursive: true));

    final mesh = Mesh(
      name: 'triangle',
      triangles: const [
        Triangle(
          Point3(0, 0, 0),
          Point3(10, 0, 0),
          Point3(0, 10, 0),
        ),
      ],
    );

    final path = await const MeshStlWriter().write(mesh, directory: dir);
    final text = await File(path).readAsString();

    expect(text, contains('solid qidi_new_morrax'));
    expect(text, contains('facet normal'));
    expect(text, contains('vertex 10.0000000000000 0 0'));
    expect(text, contains('endsolid qidi_new_morrax'));
  });
}
