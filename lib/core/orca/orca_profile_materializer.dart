import 'dart:convert';
import 'dart:io';

import '../profiles/profile_repository.dart';

class OrcaProfileFiles {
  const OrcaProfileFiles({
    required this.machine,
    required this.process,
    required this.filaments,
  });

  final String machine;
  final String process;
  final List<String> filaments;
}

/// Writes Flutter asset-backed QIDI presets to real files for OrcaSlicer CLI.
///
/// OrcaSlicer CLI consumes the same JSON preset family used by Bambu/Orca.
/// The selected presets are resolved through the existing QIDI inheritance
/// loader before being written, so the engine gets self-contained JSON files.
class OrcaProfileMaterializer {
  const OrcaProfileMaterializer();

  Future<OrcaProfileFiles> materialize({
    required Directory directory,
    required QidiProfile machine,
    required QidiProfile process,
    required List<QidiProfile> filaments,
  }) async {
    await directory.create(recursive: true);
    final machinePath = await _write(directory, 'machine.json', machine);
    final processPath = await _write(directory, 'process.json', process);
    final filamentPaths = <String>[];
    for (var index = 0; index < filaments.length; index++) {
      filamentPaths.add(
        await _write(directory, 'filament_$index.json', filaments[index]),
      );
    }
    return OrcaProfileFiles(
      machine: machinePath,
      process: processPath,
      filaments: List.unmodifiable(filamentPaths),
    );
  }

  Future<String> _write(
    Directory directory,
    String fileName,
    QidiProfile profile,
  ) async {
    final values = Map<String, dynamic>.of(profile.values);
    values.putIfAbsent('name', () => profile.name);
    values.putIfAbsent('type', () => profile.type);
    values.remove('inherits');
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(values),
      flush: true,
    );
    return file.path;
  }
}
