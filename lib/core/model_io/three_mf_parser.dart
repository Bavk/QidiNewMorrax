import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../geometry/point.dart';
import 'mesh.dart';

/// Parsed 3MF package with the complete ZIP payload retained.
///
/// Keeping [entries] is intentional: Qidi/Bambu/Prusa project 3MF files carry
/// project configuration, thumbnails, cut information, layer custom G-code and
/// vendor metadata outside the core mesh XML. A lossless rewrite must not drop
/// an entry merely because the current Flutter layer does not interpret it yet.
class ThreeMfPackage {
  ThreeMfPackage({
    required this.mesh,
    required this.entries,
    required this.metadata,
    this.projectSettings = const {},
    this.modelSettingsXml,
    this.sliceInfoXml,
    this.customGcodePerLayerXml,
  });

  final Mesh mesh;
  final Map<String, Uint8List> entries;
  final Map<String, String> metadata;
  final Map<String, dynamic> projectSettings;
  final String? modelSettingsXml;
  final String? sliceInfoXml;
  final String? customGcodePerLayerXml;

  Uint8List? entry(String path) => entries[_normalizeArchivePath(path)];
}

class ThreeMfParser {
  const ThreeMfParser();

  Mesh parse(Uint8List bytes, {String name = '3MF model'}) =>
      parsePackage(bytes, name: name).mesh;

  ThreeMfPackage parsePackage(Uint8List bytes, {String name = '3MF model'}) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final entries = <String, Uint8List>{};
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final content = file.content;
      final raw = content is Uint8List
          ? Uint8List.fromList(content)
          : Uint8List.fromList((content as List).cast<int>());
      entries[_normalizeArchivePath(file.name)] = raw;
    }

    final rootPath = _findRootModel(entries);
    if (rootPath == null) {
      throw const FormatException('3MF has no 3D/3dmodel.model');
    }

    final documents = <String, _ModelDocument>{};
    _ModelDocument documentFor(String path) {
      final normalized = _normalizeArchivePath(path);
      return documents.putIfAbsent(normalized, () {
        final raw = entries[normalized];
        if (raw == null) {
          throw FormatException('3MF component model is missing: $normalized');
        }
        return _ModelDocument.parse(normalized, raw);
      });
    }

    final root = documentFor(rootPath);
    final triangles = <Triangle>[];
    final buildItems = root.document
        .findAllElements('build')
        .expand((e) => e.findElements('item'))
        .toList();

    if (buildItems.isNotEmpty) {
      for (final item in buildItems) {
        final objectId = int.tryParse(item.getAttribute('objectid') ?? '');
        if (objectId == null) continue;
        final transform = _Transform3.parse(
          item.getAttribute('transform'),
          translationScale: root.unitToMillimeters,
        );
        final printable = item.getAttribute('printable');
        if (printable == '0') continue;
        triangles.addAll(
          _resolveObject(
            root,
            objectId,
            documentFor,
            const <String>{},
          ).map((triangle) => _transformTriangle(triangle, transform)),
        );
      }
    } else {
      for (final objectId in root.objectIds) {
        triangles.addAll(
          _resolveObject(root, objectId, documentFor, const <String>{}),
        );
      }
    }

    if (triangles.isEmpty) {
      throw const FormatException('3MF contains no printable mesh triangles');
    }

    final metadata = <String, String>{};
    for (final node in root.document.rootElement.findElements('metadata')) {
      final key = node.getAttribute('name');
      if (key != null) metadata[key] = node.innerText;
    }

    final projectSettings =
        _decodeJsonEntry(entries, 'Metadata/project_settings.config');
    return ThreeMfPackage(
      mesh: Mesh(name: name, triangles: List.unmodifiable(triangles)),
      entries: Map.unmodifiable(entries),
      metadata: Map.unmodifiable(metadata),
      projectSettings: Map.unmodifiable(projectSettings),
      modelSettingsXml:
          _decodeTextEntry(entries, 'Metadata/model_settings.config'),
      sliceInfoXml: _decodeTextEntry(entries, 'Metadata/slice_info.config'),
      customGcodePerLayerXml:
          _decodeTextEntry(entries, 'Metadata/custom_gcode_per_layer.xml'),
    );
  }

  Iterable<Triangle> _resolveObject(
    _ModelDocument model,
    int objectId,
    _ModelDocument Function(String path) documentFor,
    Set<String> stack,
  ) sync* {
    final recursionKey = '${model.path}#$objectId';
    if (stack.contains(recursionKey)) {
      throw FormatException('3MF component cycle detected at $recursionKey');
    }
    final nextStack = {...stack, recursionKey};
    final object = model.objects[objectId];
    if (object == null) return;

    final mesh = object.findElements('mesh').firstOrNull;
    if (mesh != null) {
      yield* _meshTriangles(mesh, model.unitToMillimeters);
    }

    final components = object.findElements('components').firstOrNull;
    if (components == null) return;
    for (final component in components.findElements('component')) {
      final targetId = int.tryParse(component.getAttribute('objectid') ?? '');
      if (targetId == null) continue;
      final rawPath = _attributeByLocalName(component, 'path');
      final targetModel = rawPath == null
          ? model
          : documentFor(_resolvePartPath(model.path, rawPath));
      final transform = _Transform3.parse(
        component.getAttribute('transform'),
        translationScale: model.unitToMillimeters,
      );
      for (final triangle in _resolveObject(
        targetModel,
        targetId,
        documentFor,
        nextStack,
      )) {
        yield _transformTriangle(triangle, transform);
      }
    }
  }

  Iterable<Triangle> _meshTriangles(
    XmlElement mesh,
    double unitScale,
  ) sync* {
    final verticesNode = mesh.findElements('vertices').firstOrNull;
    final trianglesNode = mesh.findElements('triangles').firstOrNull;
    if (verticesNode == null || trianglesNode == null) return;

    final vertices = <Point3>[];
    for (final vertex in verticesNode.findElements('vertex')) {
      vertices.add(Point3(
        _doubleAttribute(vertex, 'x') * unitScale,
        _doubleAttribute(vertex, 'y') * unitScale,
        _doubleAttribute(vertex, 'z') * unitScale,
      ));
    }
    for (final triangle in trianglesNode.findElements('triangle')) {
      final i1 = int.tryParse(triangle.getAttribute('v1') ?? '');
      final i2 = int.tryParse(triangle.getAttribute('v2') ?? '');
      final i3 = int.tryParse(triangle.getAttribute('v3') ?? '');
      if (i1 == null || i2 == null || i3 == null) continue;
      if (i1 < 0 ||
          i2 < 0 ||
          i3 < 0 ||
          i1 >= vertices.length ||
          i2 >= vertices.length ||
          i3 >= vertices.length) {
        continue;
      }
      yield Triangle(vertices[i1], vertices[i2], vertices[i3]);
    }
  }

  static String? _findRootModel(Map<String, Uint8List> entries) {
    if (entries.containsKey('3D/3dmodel.model')) return '3D/3dmodel.model';
    for (final key in entries.keys) {
      if (key.toLowerCase().endsWith('/3dmodel.model')) return key;
    }
    return null;
  }

  static Map<String, dynamic> _decodeJsonEntry(
    Map<String, Uint8List> entries,
    String path,
  ) {
    final text = _decodeTextEntry(entries, path);
    if (text == null || text.trim().isEmpty) return const {};
    try {
      final value = jsonDecode(text);
      return value is Map ? value.cast<String, dynamic>() : const {};
    } catch (_) {
      return const {};
    }
  }

  static String? _decodeTextEntry(
    Map<String, Uint8List> entries,
    String path,
  ) {
    final value = entries[_normalizeArchivePath(path)];
    return value == null ? null : utf8.decode(value, allowMalformed: true);
  }

  static double _doubleAttribute(XmlElement element, String name) =>
      double.tryParse(element.getAttribute(name) ?? '') ?? 0;
}

class _ModelDocument {
  _ModelDocument({
    required this.path,
    required this.document,
    required this.unitToMillimeters,
    required this.objects,
  });

  final String path;
  final XmlDocument document;
  final double unitToMillimeters;
  final Map<int, XmlElement> objects;

  Iterable<int> get objectIds => objects.keys;

  factory _ModelDocument.parse(String path, Uint8List bytes) {
    final document = XmlDocument.parse(
      utf8.decode(bytes, allowMalformed: false),
    );
    final unit =
        document.rootElement.getAttribute('unit')?.toLowerCase() ?? 'millimeter';
    final unitScale = switch (unit) {
      'micron' => 0.001,
      'millimeter' => 1.0,
      'centimeter' => 10.0,
      'inch' => 25.4,
      'foot' => 304.8,
      'meter' => 1000.0,
      _ => 1.0,
    };
    final objects = <int, XmlElement>{};
    for (final object in document.findAllElements('object')) {
      final id = int.tryParse(object.getAttribute('id') ?? '');
      if (id != null) objects[id] = object;
    }
    return _ModelDocument(
      path: path,
      document: document,
      unitToMillimeters: unitScale,
      objects: objects,
    );
  }
}

class _Transform3 {
  const _Transform3(this.values);

  static const identity = _Transform3(<double>[
    1, 0, 0,
    0, 1, 0,
    0, 0, 1,
    0, 0, 0,
  ]);

  final List<double> values;

  factory _Transform3.parse(String? source, {double translationScale = 1}) {
    if (source == null || source.trim().isEmpty) return identity;
    final values = source.trim().split(RegExp(r'\s+')).map(double.tryParse).toList();
    if (values.length != 12 || values.any((value) => value == null)) {
      return identity;
    }
    final parsed = values.cast<double>().toList();
    parsed[9] *= translationScale;
    parsed[10] *= translationScale;
    parsed[11] *= translationScale;
    return _Transform3(List.unmodifiable(parsed));
  }

  Point3 apply(Point3 point) {
    final m = values;
    return Point3(
      point.x * m[0] + point.y * m[3] + point.z * m[6] + m[9],
      point.x * m[1] + point.y * m[4] + point.z * m[7] + m[10],
      point.x * m[2] + point.y * m[5] + point.z * m[8] + m[11],
    );
  }
}

Triangle _transformTriangle(Triangle triangle, _Transform3 transform) => Triangle(
      transform.apply(triangle.a),
      transform.apply(triangle.b),
      transform.apply(triangle.c),
    );

String _normalizeArchivePath(String path) {
  final clean = path.replaceAll('\\', '/');
  return clean.startsWith('/') ? clean.substring(1) : clean;
}

String _resolvePartPath(String currentModelPath, String referencedPath) {
  final normalizedReference = _normalizeArchivePath(referencedPath);
  if (referencedPath.startsWith('/')) return normalizedReference;
  final slash = currentModelPath.lastIndexOf('/');
  final base = slash < 0 ? '' : currentModelPath.substring(0, slash + 1);
  final segments = <String>[];
  for (final segment in '$base$normalizedReference'.split('/')) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (segments.isNotEmpty) segments.removeLast();
    } else {
      segments.add(segment);
    }
  }
  return segments.join('/');
}

String? _attributeByLocalName(XmlElement element, String name) {
  for (final attribute in element.attributes) {
    if (attribute.name.local == name) return attribute.value;
  }
  return null;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
