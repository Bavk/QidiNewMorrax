import 'dart:convert';
import 'dart:typed_data';

import '../geometry/point.dart';
import 'mesh.dart';

class StlParser {
  const StlParser();

  Mesh parse(Uint8List bytes, {String name = 'STL model'}) {
    if (_looksBinary(bytes)) return _parseBinary(bytes, name);
    return _parseAscii(utf8.decode(bytes, allowMalformed: true), name);
  }

  bool _looksBinary(Uint8List bytes) {
    if (bytes.length < 84) return false;
    final data = ByteData.sublistView(bytes);
    final count = data.getUint32(80, Endian.little);
    final expected = 84 + count * 50;
    if (expected == bytes.length) return true;
    final header = ascii.decode(
      bytes.sublist(0, bytes.length < 80 ? bytes.length : 80),
      allowInvalid: true,
    ).trimLeft();
    return !header.toLowerCase().startsWith('solid');
  }

  Mesh _parseBinary(Uint8List bytes, String name) {
    final data = ByteData.sublistView(bytes);
    final count = data.getUint32(80, Endian.little);
    if (84 + count * 50 > bytes.length) {
      throw const FormatException('Invalid binary STL length');
    }
    final triangles = <Triangle>[];
    var offset = 84;
    for (var i = 0; i < count; i++, offset += 50) {
      Point3 vertex(int base) => Point3(
            data.getFloat32(offset + base, Endian.little),
            data.getFloat32(offset + base + 4, Endian.little),
            data.getFloat32(offset + base + 8, Endian.little),
          );
      triangles.add(Triangle(vertex(12), vertex(24), vertex(36)));
    }
    return Mesh(name: name, triangles: triangles);
  }

  Mesh _parseAscii(String text, String name) {
    final values = <Point3>[];
    final vertex = RegExp(
      r'^\s*vertex\s+([-+0-9.eE]+)\s+([-+0-9.eE]+)\s+([-+0-9.eE]+)',
      multiLine: true,
      caseSensitive: false,
    );
    for (final match in vertex.allMatches(text)) {
      values.add(Point3(
        double.parse(match.group(1)!),
        double.parse(match.group(2)!),
        double.parse(match.group(3)!),
      ));
    }
    if (values.length < 3) {
      throw const FormatException('ASCII STL contains no triangles');
    }
    final triangles = <Triangle>[];
    for (var i = 0; i + 2 < values.length; i += 3) {
      triangles.add(Triangle(values[i], values[i + 1], values[i + 2]));
    }
    return Mesh(name: name, triangles: triangles);
  }
}
