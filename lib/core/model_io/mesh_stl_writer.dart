import 'dart:io';

import 'mesh.dart';

/// Minimal interchange writer used only to hand the current Prepare geometry
/// to OrcaSlicer. It does not perform slicing or geometry cleanup.
class MeshStlWriter {
  const MeshStlWriter();

  Future<String> write(
    Mesh mesh, {
    required Directory directory,
    String fileName = 'plate.stl',
  }) async {
    await directory.create(recursive: true);
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    final out = StringBuffer()..writeln('solid qidi_new_morrax');
    for (final triangle in mesh.triangles) {
      final normal = triangle.normal;
      out.writeln(
        '  facet normal ${_n(normal.x)} ${_n(normal.y)} ${_n(normal.z)}',
      );
      out.writeln('    outer loop');
      for (final point in [triangle.a, triangle.b, triangle.c]) {
        out.writeln(
          '      vertex ${_n(point.x)} ${_n(point.y)} ${_n(point.z)}',
        );
      }
      out.writeln('    endloop');
      out.writeln('  endfacet');
    }
    out.writeln('endsolid qidi_new_morrax');
    await file.writeAsString(out.toString(), flush: true);
    return file.path;
  }

  String _n(double value) {
    if (value == 0) return '0';
    return value.toStringAsPrecision(15);
  }
}
