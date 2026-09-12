import 'dart:convert';
import 'dart:typed_data';

import '../geometry/point.dart';
import 'mesh.dart';

class ObjParser {
  const ObjParser();

  Mesh parse(Uint8List bytes, {String name = 'OBJ model'}) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final vertices = <Point3>[];
    final triangles = <Triangle>[];

    int resolveIndex(String token) {
      final raw = int.parse(token.split('/').first);
      if (raw > 0) return raw - 1;
      return vertices.length + raw;
    }

    for (final rawLine in const LineSplitter().convert(text)) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final parts = line.split(RegExp(r'\s+'));
      if (parts.first == 'v' && parts.length >= 4) {
        vertices.add(Point3(
          double.parse(parts[1]),
          double.parse(parts[2]),
          double.parse(parts[3]),
        ));
      } else if (parts.first == 'f' && parts.length >= 4) {
        final indices = parts.skip(1).map(resolveIndex).toList(growable: false);
        for (var i = 1; i + 1 < indices.length; i++) {
          final ia = indices[0];
          final ib = indices[i];
          final ic = indices[i + 1];
          if (ia < 0 ||
              ib < 0 ||
              ic < 0 ||
              ia >= vertices.length ||
              ib >= vertices.length ||
              ic >= vertices.length) {
            throw const FormatException('OBJ face index outside vertex list');
          }
          triangles.add(Triangle(vertices[ia], vertices[ib], vertices[ic]));
        }
      }
    }
    if (triangles.isEmpty) throw const FormatException('OBJ contains no faces');
    return Mesh(name: name, triangles: triangles);
  }
}
