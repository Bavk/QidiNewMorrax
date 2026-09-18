import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'three_mf_parser.dart';
import 'three_mf_transform.dart';

/// Rebuilds a 3MF ZIP package without silently discarding vendor-specific
/// entries. This intentionally does not pretend that flattened geometry edits
/// can be written back losslessly yet; callers may replace only entries whose
/// semantics they fully own.
class ThreeMfWriter {
  const ThreeMfWriter();

  Uint8List repackWithBuildTransform(
    ThreeMfPackage package,
    ThreeMfTransform transform,
  ) {
    if (transform.isIdentity) return repack(package);

    final rootPath = _rootModelPath(package.entries);
    if (rootPath == null) {
      throw const FormatException('3MF has no root model to transform');
    }
    final raw = package.entries[rootPath];
    if (raw == null) {
      throw FormatException('3MF root model is missing: $rootPath');
    }

    final document = XmlDocument.parse(utf8.decode(raw, allowMalformed: false));
    for (final build in document.findAllElements('build')) {
      for (final item in build.findElements('item')) {
        final existing = ThreeMfTransform.from3mf(
          item.getAttribute('transform'),
        );
        item.setAttribute('transform', (transform * existing).to3mfString());
      }
    }

    return repack(
      package,
      replacements: {
        rootPath: Uint8List.fromList(
          utf8.encode(document.toXmlString(pretty: false)),
        ),
      },
    );
  }

  Uint8List repack(
    ThreeMfPackage package, {
    Map<String, Uint8List> replacements = const {},
    Set<String> removals = const {},
  }) {
    final normalizedReplacements = <String, Uint8List>{
      for (final entry in replacements.entries)
        _normalize(entry.key): Uint8List.fromList(entry.value),
    };
    final normalizedRemovals = removals.map(_normalize).toSet();
    final archive = Archive();

    for (final entry in package.entries.entries) {
      final path = _normalize(entry.key);
      if (normalizedRemovals.contains(path)) continue;
      final value = normalizedReplacements.remove(path) ?? entry.value;
      archive.addFile(ArchiveFile.bytes(path, value));
    }
    for (final entry in normalizedReplacements.entries) {
      if (normalizedRemovals.contains(entry.key)) continue;
      archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
    }
    return ZipEncoder().encodeBytes(archive);
  }

  String? _rootModelPath(Map<String, Uint8List> entries) {
    if (entries.containsKey('3D/3dmodel.model')) return '3D/3dmodel.model';
    for (final key in entries.keys) {
      if (key.toLowerCase().endsWith('/3dmodel.model')) return key;
    }
    return null;
  }

  String _normalize(String path) {
    final value = path.replaceAll('\\', '/');
    return value.startsWith('/') ? value.substring(1) : value;
  }
}
