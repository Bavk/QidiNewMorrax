import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'three_mf_parser.dart';

/// Rebuilds a 3MF ZIP package without silently discarding vendor-specific
/// entries. This intentionally does not pretend that flattened geometry edits
/// can be written back losslessly yet; callers may replace only entries whose
/// semantics they fully own.
class ThreeMfWriter {
  const ThreeMfWriter();

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

  String _normalize(String path) {
    final value = path.replaceAll('\\', '/');
    return value.startsWith('/') ? value.substring(1) : value;
  }
}
