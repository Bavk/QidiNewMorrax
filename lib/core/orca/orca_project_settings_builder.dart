import '../profiles/profile_repository.dart';

/// Builds the DynamicPrintConfig JSON Orca embeds as
/// Metadata/project_settings.config in Bambu/Orca 3MF projects.
///
/// QIDI presets use the same serialized value shapes Orca's save_to_json()
/// emits: scalar config values are strings and vector values are arrays of
/// strings. The selected profiles must already be inheritance-resolved.
class OrcaProjectSettingsBuilder {
  const OrcaProjectSettingsBuilder();

  Map<String, dynamic> build({
    required QidiProfile machine,
    required QidiProfile process,
    required List<QidiProfile> filaments,
  }) {
    if (filaments.isEmpty) {
      throw ArgumentError.value(
        filaments,
        'filaments',
        'at least one filament is required',
      );
    }

    final result = <String, dynamic>{
      '_name': 'project_settings',
      '_from': 'project',
      '_version': '2.4.2',
    };

    _mergeConfig(result, process.values);
    for (final filament in filaments) {
      _mergeFilamentConfig(result, filament.values);
    }
    _mergeConfig(result, machine.values);

    result['print_settings_id'] = process.name;
    result['printer_settings_id'] = machine.name;
    result['filament_settings_id'] = [
      for (final filament in filaments) filament.name,
    ];

    // For a Bambu/Orca 3MF the CLI validates the process embedded in
    // project_settings.config against the selected printer before the external
    // --load-settings process preset replaces it. Keep the resolved process
    // compatibility list here even though compatible_printers is normally
    // preset metadata and is omitted by _mergeConfig().
    final compatiblePrinters = process.values['compatible_printers'];
    if (compatiblePrinters != null) {
      result['compatible_printers'] = _copyValue(compatiblePrinters);
    }

    // Orca CLI reads these without null-checks immediately after identifying a
    // BBS/Orca 3MF, before external --load-settings are applied.
    result.putIfAbsent(
      'nozzle_diameter',
      () => _vectorOrSingle(machine.values['nozzle_diameter'], fallback: '0.4'),
    );
    result.putIfAbsent('printer_model', () => machine.printerModel ?? '');
    result.putIfAbsent(
      'inherits_group',
      () => <String>[
        process.inherits ?? '',
        for (final filament in filaments) filament.inherits ?? '',
        machine.inherits ?? '',
      ],
    );
    result.putIfAbsent(
      'different_settings_to_system',
      () => List<String>.filled(filaments.length + 2, ''),
    );

    return Map.unmodifiable(result);
  }

  void _mergeConfig(
    Map<String, dynamic> target,
    Map<String, dynamic> source,
  ) {
    for (final entry in source.entries) {
      if (_presetMetadataKeys.contains(entry.key)) continue;
      target[entry.key] = _copyValue(entry.value);
    }
  }

  void _mergeFilamentConfig(
    Map<String, dynamic> target,
    Map<String, dynamic> source,
  ) {
    for (final entry in source.entries) {
      if (_presetMetadataKeys.contains(entry.key)) continue;
      final value = entry.value;
      if (value is List) {
        final existing = target[entry.key];
        if (existing is List) {
          target[entry.key] = <dynamic>[
            ...existing.map(_copyValue),
            ...value.map(_copyValue),
          ];
        } else {
          target[entry.key] = value.map(_copyValue).toList(growable: false);
        }
      } else {
        target[entry.key] = _copyValue(value);
      }
    }
  }

  dynamic _copyValue(dynamic value) {
    if (value is List) {
      return value.map(_copyValue).toList(growable: false);
    }
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          entry.key.toString(): _copyValue(entry.value),
      };
    }
    return value;
  }

  List<String> _vectorOrSingle(dynamic value, {required String fallback}) {
    if (value is List) {
      return value.map((item) => item.toString()).toList(growable: false);
    }
    if (value != null) return <String>[value.toString()];
    return <String>[fallback];
  }

  static const _presetMetadataKeys = <String>{
    'name',
    'type',
    'inherits',
    'from',
    'setting_id',
    'filament_id',
    'instantiation',
    'compatible_printers',
    'compatible_prints',
    'description',
    'renamed_from',
  };
}
