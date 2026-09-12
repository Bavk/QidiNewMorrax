import 'dart:typed_data';

import 'amf_parser.dart';
import 'mesh.dart';
import 'obj_parser.dart';
import 'stl_parser.dart';
import 'three_mf_parser.dart';

class ModelLoader {
  const ModelLoader();

  Mesh load(Uint8List bytes, String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.amf') ||
        lower.endsWith('.amf.xml') ||
        lower.endsWith('.zip.amf') ||
        lower.endsWith('.xml')) {
      return const AmfParser().parse(bytes, name: fileName);
    }
    if (lower.endsWith('.stl')) {
      return const StlParser().parse(bytes, name: fileName);
    }
    if (lower.endsWith('.obj')) {
      return const ObjParser().parse(bytes, name: fileName);
    }
    if (lower.endsWith('.3mf')) {
      return const ThreeMfParser().parse(bytes, name: fileName);
    }
    throw UnsupportedError('Unsupported model format: $fileName');
  }
}
