import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/orca/orca_project_settings_builder.dart';
import 'package:qidi_flow_flutter/core/profiles/profile_repository.dart';

void main() {
  QidiProfile profile(
    String name,
    String type,
    Map<String, dynamic> values,
  ) =>
      QidiProfile(
        assetPath: 'assets/$type/$name.json',
        values: <String, dynamic>{
          'name': name,
          'type': type,
          ...values,
        },
      );

  test('builds project settings required by Orca BBS 3MF loader', () {
    final machine = profile(
      'Qidi X-Plus 4 0.4 nozzle',
      'machine',
      const {
        'printer_model': 'Qidi X-Plus 4',
        'printer_settings_id': 'Qidi X-Plus 4 0.4 nozzle',
        'nozzle_diameter': ['0.4'],
        'printable_height': '280',
        'inherits': 'fdm_qidi_x3_common',
      },
    );
    final process = profile(
      '0.20mm Standard @Qidi XPlus4',
      'process',
      const {
        'layer_height': '0.2',
        'inherits': '0.20mm Standard @Qidi X3',
        'compatible_printers': ['Qidi X-Plus 4 0.4 nozzle'],
      },
    );
    final filament = profile(
      'Qidi Generic PLA @Qidi X-Plus 4 0.4 nozzle',
      'filament',
      const {
        'filament_settings_id': [
          'Qidi Generic PLA @Qidi X-Plus 4 0.4 nozzle',
        ],
        'nozzle_temperature': ['210'],
        'inherits': 'Qidi Generic PLA',
      },
    );

    final settings = const OrcaProjectSettingsBuilder().build(
      machine: machine,
      process: process,
      filaments: [filament],
    );

    expect(settings['_name'], 'project_settings');
    expect(settings['_from'], 'project');
    expect(settings['_version'], '2.4.2');
    expect(settings['printer_settings_id'], machine.name);
    expect(settings['print_settings_id'], process.name);
    expect(settings['filament_settings_id'], [filament.name]);
    expect(settings['nozzle_diameter'], ['0.4']);
    expect(settings['layer_height'], '0.2');
    expect(
      settings['compatible_printers'],
      ['Qidi X-Plus 4 0.4 nozzle'],
    );
    expect(settings['nozzle_temperature'], ['210']);
    expect(settings['printer_model'], 'Qidi X-Plus 4');
    expect(
      settings['inherits_group'],
      [
        '0.20mm Standard @Qidi X3',
        'Qidi Generic PLA',
        'fdm_qidi_x3_common',
      ],
    );

    expect(settings, isNot(contains('name')));
    expect(settings, isNot(contains('type')));
    expect(settings, isNot(contains('inherits')));
  });

  test('combines vector filament settings for multiple filaments', () {
    final machine = profile(
      'Machine',
      'machine',
      const {'nozzle_diameter': ['0.4', '0.4']},
    );
    final process = profile('Process', 'process', const {});
    final filamentA = profile(
      'PLA',
      'filament',
      const {'nozzle_temperature': ['210']},
    );
    final filamentB = profile(
      'PETG',
      'filament',
      const {'nozzle_temperature': ['245']},
    );

    final settings = const OrcaProjectSettingsBuilder().build(
      machine: machine,
      process: process,
      filaments: [filamentA, filamentB],
    );

    expect(settings['filament_settings_id'], ['PLA', 'PETG']);
    expect(settings['nozzle_temperature'], ['210', '245']);
    expect(settings['different_settings_to_system'], ['', '', '', '']);
  });
}
