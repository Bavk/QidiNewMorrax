import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/orca/orca_profile_materializer.dart';
import 'package:qidi_flow_flutter/core/profiles/profile_repository.dart';

void main() {
  test('materializes resolved QIDI presets as standalone Orca JSON', () async {
    final dir = await Directory.systemTemp.createTemp('orca_profiles_test_');
    addTearDown(() => dir.delete(recursive: true));

    QidiProfile profile(String name, String type) => QidiProfile(
          assetPath: 'assets/$name.json',
          values: {
            'name': name,
            'type': type,
            'inherits': 'base preset',
            'layer_height': '0.2',
          },
        );

    final files = await const OrcaProfileMaterializer().materialize(
      directory: dir,
      machine: profile('machine', 'machine'),
      process: profile('process', 'process'),
      filaments: [profile('PLA', 'filament')],
    );

    final machine =
        jsonDecode(await File(files.machine).readAsString()) as Map<String, dynamic>;
    final process =
        jsonDecode(await File(files.process).readAsString()) as Map<String, dynamic>;
    final filament = jsonDecode(
      await File(files.filaments.single).readAsString(),
    ) as Map<String, dynamic>;

    expect(machine['name'], 'machine');
    expect(process['name'], 'process');
    expect(filament['name'], 'PLA');
    expect(machine.containsKey('inherits'), isFalse);
  });

  test('materializes multiple filament slots in stable order', () async {
    final dir = await Directory.systemTemp.createTemp('orca_multi_profiles_');
    addTearDown(() => dir.delete(recursive: true));

    QidiProfile profile(String name, String type, String temperature) =>
        QidiProfile(
          assetPath: 'assets/$name.json',
          values: {
            'name': name,
            'type': type,
            'nozzle_temperature': [temperature],
          },
        );

    final files = await const OrcaProfileMaterializer().materialize(
      directory: dir,
      machine: profile('machine', 'machine', '0'),
      process: profile('process', 'process', '0'),
      filaments: [
        profile('PLA', 'filament', '210'),
        profile('PETG', 'filament', '245'),
      ],
    );

    expect(files.filaments, hasLength(2));
    expect(files.filaments[0], endsWith('filament_0.json'));
    expect(files.filaments[1], endsWith('filament_1.json'));

    final first = jsonDecode(
      await File(files.filaments[0]).readAsString(),
    ) as Map<String, dynamic>;
    final second = jsonDecode(
      await File(files.filaments[1]).readAsString(),
    ) as Map<String, dynamic>;

    expect(first['name'], 'PLA');
    expect(second['name'], 'PETG');
    expect(first['nozzle_temperature'], ['210']);
    expect(second['nozzle_temperature'], ['245']);
  });

}
