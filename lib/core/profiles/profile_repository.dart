import 'dart:convert';

import 'package:flutter/services.dart';

class QidiProfile {
  QidiProfile({required this.assetPath, required Map<String, dynamic> values})
      : values = Map.unmodifiable(values);

  final String assetPath;
  final Map<String, dynamic> values;

  String get name => values['name']?.toString() ?? assetPath.split('/').last;
  String get type => values['type']?.toString() ?? 'unknown';
  String? get inherits => values['inherits']?.toString();
  String? get printerModel => values['printer_model']?.toString();

  List<String> get compatiblePrinters {
    final value = values['compatible_printers'];
    if (value is List) {
      return value.map((item) => item.toString()).toList(growable: false);
    }
    if (value is String && value.isNotEmpty) return <String>[value];
    return const <String>[];
  }

  bool isCompatibleWithPrinter(String? printerName) {
    if (printerName == null || printerName.isEmpty) return true;
    final compatible = compatiblePrinters;
    return compatible.isEmpty || compatible.contains(printerName);
  }

  String? stringValue(String key) {
    final value = values[key];
    if (value == null) return null;
    if (value is List && value.isNotEmpty) return value.first.toString();
    return value.toString();
  }

  double? doubleValue(String key) => double.tryParse(stringValue(key) ?? '');
}

class ProfileRepository {
  List<QidiProfile>? _cache;

  Future<List<QidiProfile>> loadAll() async {
    if (_cache != null) return _cache!;
    try {
      final decoded = jsonDecode(
        await rootBundle.loadString('assets/generated/profile_catalog.json'),
      );
      if (decoded is List) {
        final profiles = <QidiProfile>[];
        for (final item in decoded) {
          if (item is! Map) continue;
          final map = item.cast<String, dynamic>();
          final values = map['values'];
          if (values is Map) {
            profiles.add(QidiProfile(
              assetPath: map['assetPath']?.toString() ?? '',
              values: values.cast<String, dynamic>(),
            ));
          }
        }
        if (profiles.isNotEmpty) {
          _cache = List.unmodifiable(profiles);
          return _cache!;
        }
      }
    } catch (_) {
      // Fall through to the original asset tree.
    }

    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final paths = manifest
        .listAssets()
        .where((path) =>
            path.startsWith('assets/resources/profiles/') &&
            path.endsWith('.json'))
        .toList()
      ..sort();
    final profiles = <QidiProfile>[];
    for (final path in paths) {
      try {
        final decoded = jsonDecode(await rootBundle.loadString(path));
        if (decoded is Map<String, dynamic>) {
          profiles.add(QidiProfile(assetPath: path, values: decoded));
        }
      } catch (_) {
        // Continue loading the remainder of the supplied source profile tree.
      }
    }
    _cache = List.unmodifiable(profiles);
    return _cache!;
  }

  Future<List<QidiProfile>> byType(String type) async =>
      (await loadAll()).where((p) => p.type == type).toList(growable: false);

  Future<QidiProfile?> findByName(String name) async {
    for (final profile in await loadAll()) {
      if (profile.name == name) return profile;
    }
    return null;
  }

  Future<QidiProfile?> resolved(String name) async {
    final all = await loadAll();
    final index = <String, QidiProfile>{for (final p in all) p.name: p};
    final target = index[name];
    if (target == null) return null;
    final stack = <String>{};

    Map<String, dynamic> merge(QidiProfile profile) {
      if (!stack.add(profile.name)) return Map.of(profile.values);
      final parentName = profile.inherits;
      final parent = parentName == null ? null : index[parentName];
      final result = parent == null ? <String, dynamic>{} : merge(parent);
      result.addAll(profile.values);
      stack.remove(profile.name);
      return result;
    }

    return QidiProfile(assetPath: target.assetPath, values: merge(target));
  }
}
