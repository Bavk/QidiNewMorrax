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
}
