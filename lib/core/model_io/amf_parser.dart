import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../geometry/point.dart';
import 'mesh.dart';

/// Geometry-focused AMF importer for the AMF variants used by Slic3r/QIDI.
///
/// It supports plain AMF/XML, zip-compressed AMF, document units, multiple
/// objects/volumes and constellation instances with translation, XYZ rotation,
/// scale, mirror and printable flags. Material/color/config metadata is not yet
/// mapped into the Flutter scene model and remains a parity item in the ledger.
class AmfParser {
  const AmfParser();

  Mesh parse(Uint8List bytes, {String name = 'AMF model'}) {
    final xmlBytes = _unwrap(bytes);
    final document =
        XmlDocument.parse(utf8.decode(xmlBytes, allowMalformed: false));
    final root = document.rootElement;
    if (root.name.local.toLowerCase() != 'amf') {
      throw const FormatException('AMF root element is missing');
    }
    final unitScale = _unitToMillimeters(root.getAttribute('unit'));
    final objects = <String, Mesh>{};

    for (final object in root.findElements('object')) {
      final id = object.getAttribute('id');
      if (id == null || id.isEmpty) continue;
      final meshNode = object.findElements('mesh').firstOrNull;
      if (meshNode == null) continue;
      final verticesNode = meshNode.findElements('vertices').firstOrNull;
      if (verticesNode == null) continue;
      final vertices = <Point3>[];
      for (final vertex in verticesNode.findElements('vertex')) {
        final coordinates = vertex.findElements('coordinates').firstOrNull;
        if (coordinates == null) continue;
        vertices.add(Point3(
          _childDouble(coordinates, 'x') * unitScale,
          _childDouble(coordinates, 'y') * unitScale,
          _childDouble(coordinates, 'z') * unitScale,
        ));
      }
      final triangles = <Triangle>[];
      for (final volume in meshNode.findElements('volume')) {
        for (final triangle in volume.findElements('triangle')) {
          final a = _childInt(triangle, 'v1');
          final b = _childInt(triangle, 'v2');
          final c = _childInt(triangle, 'v3');
          if (a == null || b == null || c == null) continue;
          if (a < 0 ||
              b < 0 ||
              c < 0 ||
              a >= vertices.length ||
              b >= vertices.length ||
              c >= vertices.length) {
            continue;
          }
          triangles.add(Triangle(vertices[a], vertices[b], vertices[c]));
        }
      }
      if (triangles.isNotEmpty) {
        objects[id] = Mesh(
          name: '$name#$id',
          triangles: List.unmodifiable(triangles),
        );
      }
    }

    if (objects.isEmpty) {
      throw const FormatException('AMF contains no mesh triangles');
    }

    final instantiated = <String>{};
    final output = <Triangle>[];
    for (final constellation in root.findElements('constellation')) {
      for (final instance in constellation.findElements('instance')) {
        final objectId = instance.getAttribute('objectid');
        if (objectId == null) continue;
        final source = objects[objectId];
        if (source == null) continue;
        instantiated.add(objectId);
        if (!_childBool(instance, 'printable', fallback: true)) continue;
        final uniformScale = _childDouble(instance, 'scale', fallback: 1);
        final sx = _childDouble(
              instance,
              'scalex',
              fallback: uniformScale,
            ) *
            _mirror(instance, 'mirrorx');
        final sy = _childDouble(
              instance,
              'scaley',
              fallback: uniformScale,
            ) *
            _mirror(instance, 'mirrory');
        final sz = _childDouble(
              instance,
              'scalez',
              fallback: uniformScale,
            ) *
            _mirror(instance, 'mirrorz');
        final transformed = source.transformed(
          translation: Point3(
            _childDouble(instance, 'deltax') * unitScale,
            _childDouble(instance, 'deltay') * unitScale,
            _childDouble(instance, 'deltaz') * unitScale,
          ),
          rotationDegrees: Point3(
            _childDouble(instance, 'rx'),
            _childDouble(instance, 'ry'),
            _childDouble(instance, 'rz'),
          ),
          scale: Point3(sx, sy, sz),
        );
        output.addAll(transformed.triangles);
      }
    }

    for (final entry in objects.entries) {
      if (!instantiated.contains(entry.key)) {
        output.addAll(entry.value.triangles);
      }
    }
    if (output.isEmpty) {
      throw const FormatException('AMF contains no printable mesh triangles');
    }
    return Mesh(name: name, triangles: List.unmodifiable(output));
  }

  Uint8List _unwrap(Uint8List bytes) {
    if (bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4b) {
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      for (final file in archive.files) {
        if (!file.isFile) continue;
        final lower = file.name.toLowerCase();
        if (lower.endsWith('.amf') || lower.endsWith('.xml')) {
          return Uint8List.fromList(file.content);
        }
      }
      throw const FormatException(
        'ZIP.AMF archive contains no AMF/XML document',
      );
    }
    return bytes;
  }

  double _unitToMillimeters(String? raw) =>
      switch (raw?.trim().toLowerCase()) {
        'inch' => 25.4,
        'feet' || 'foot' => 304.8,
        'meter' => 1000.0,
        'micron' => 0.001,
        _ => 1.0,
      };

  static double _childDouble(
    XmlElement parent,
    String name, {
    double fallback = 0,
  }) {
    final node = parent.findElements(name).firstOrNull;
    return double.tryParse(node?.innerText.trim() ?? '') ?? fallback;
  }

  static int? _childInt(XmlElement parent, String name) {
    final node = parent.findElements(name).firstOrNull;
    return int.tryParse(node?.innerText.trim() ?? '');
  }

  static bool _childBool(
    XmlElement parent,
    String name, {
    required bool fallback,
  }) {
    final node = parent.findElements(name).firstOrNull;
    if (node == null) return fallback;
    final value = node.innerText.trim().toLowerCase();
    if (value == '0' || value == 'false') return false;
    if (value == '1' || value == 'true') return true;
    return fallback;
  }

  static double _mirror(XmlElement parent, String name) {
    final node = parent.findElements(name).firstOrNull;
    if (node == null) return 1;
    final value = double.tryParse(node.innerText.trim());
    if (value == null || value == 0) return 1;
    return value < 0 ? -1 : 1;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
