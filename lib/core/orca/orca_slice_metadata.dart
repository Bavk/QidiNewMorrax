import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Parsed metadata emitted by OrcaSlicer in Metadata/slice_info.config.
class OrcaSliceMetadata {
  const OrcaSliceMetadata({
    required this.header,
    required this.plates,
  });

  final Map<String, String> header;
  final Map<int, OrcaPlateMetadata> plates;

  OrcaPlateMetadata? plate(int index) => plates[index];

  double get totalPredictionSeconds =>
      plates.values.fold(0, (sum, plate) => sum + plate.predictionSeconds);

  double get totalWeightGrams =>
      plates.values.fold(0, (sum, plate) => sum + plate.weightGrams);

  List<OrcaSliceWarning> get warnings => List.unmodifiable(
        plates.values.expand((plate) => plate.warnings),
      );

  static OrcaSliceMetadata fromBundle(Uint8List bundleBytes) {
    final archive = ZipDecoder().decodeBytes(bundleBytes, verify: true);
    for (final file in archive.files) {
      if (!file.isFile) continue;
      if (file.name.replaceAll('\\', '/') != 'Metadata/slice_info.config') {
        continue;
      }
      return fromXml(
        utf8.decode(List<int>.from(file.content), allowMalformed: true),
      );
    }
    return const OrcaSliceMetadata(header: {}, plates: {});
  }

  static OrcaSliceMetadata fromXml(String xmlText) {
    final document = XmlDocument.parse(xmlText);
    final root = document.rootElement;
    final header = <String, String>{};
    final plates = <int, OrcaPlateMetadata>{};

    for (final element in root.childElements) {
      if (element.localName == 'header') {
        for (final item in element.childElements) {
          if (item.localName != 'header_item') continue;
          final key = item.getAttribute('key');
          if (key == null || key.isEmpty) continue;
          header[key] = item.getAttribute('value') ?? '';
        }
        continue;
      }
      if (element.localName != 'plate') continue;
      final plate = OrcaPlateMetadata._fromXml(element);
      if (plate.index > 0) plates[plate.index] = plate;
    }

    return OrcaSliceMetadata(
      header: Map.unmodifiable(header),
      plates: Map.unmodifiable(plates),
    );
  }
}

class OrcaPlateMetadata {
  const OrcaPlateMetadata({
    required this.index,
    required this.printerModelId,
    required this.nozzleDiameters,
    required this.predictionSeconds,
    required this.weightGrams,
    required this.firstLayerTimeSeconds,
    required this.toolpathOutside,
    required this.supportUsed,
    required this.labelObjectEnabled,
    required this.objects,
    required this.filaments,
    required this.warnings,
  });

  final int index;
  final String printerModelId;
  final List<double> nozzleDiameters;
  final double predictionSeconds;
  final double weightGrams;
  final double firstLayerTimeSeconds;
  final bool toolpathOutside;
  final bool supportUsed;
  final bool labelObjectEnabled;
  final List<OrcaSliceObject> objects;
  final List<OrcaSliceFilament> filaments;
  final List<OrcaSliceWarning> warnings;

  static OrcaPlateMetadata _fromXml(XmlElement element) {
    final values = <String, String>{};
    final objects = <OrcaSliceObject>[];
    final filaments = <OrcaSliceFilament>[];
    final warnings = <OrcaSliceWarning>[];

    for (final child in element.childElements) {
      if (child.localName == 'metadata') {
        final key = child.getAttribute('key');
        if (key != null) values[key] = child.getAttribute('value') ?? '';
      } else if (child.localName == 'object') {
        objects.add(OrcaSliceObject(
          identifyId: _int(child.getAttribute('identify_id')),
          name: child.getAttribute('name') ?? '',
          skipped: _bool(child.getAttribute('skipped')),
        ));
      } else if (child.localName == 'filament') {
        filaments.add(OrcaSliceFilament(
          id: _int(child.getAttribute('id')),
          trayInfoId: child.getAttribute('tray_info_idx') ?? '',
          type: child.getAttribute('type') ?? '',
          color: child.getAttribute('color') ?? '',
          usedMeters: _double(child.getAttribute('used_m')),
          usedGrams: _double(child.getAttribute('used_g')),
          nozzleGroupIds: _intList(child.getAttribute('group_id')),
          nozzleDiameter: _double(child.getAttribute('nozzle_diameter')),
          nozzleVolumeType: child.getAttribute('volume_type') ?? '',
          usedForObject: _bool(child.getAttribute('used_for_object')),
          usedForSupport: _bool(child.getAttribute('used_for_support')),
        ));
      } else if (child.localName == 'warning') {
        warnings.add(OrcaSliceWarning(
          message: child.getAttribute('msg') ?? '',
          level: _int(child.getAttribute('level')),
          errorCode: child.getAttribute('error_code') ?? '',
        ));
      }
    }

    final declaredWeight = _double(values['weight']);
    final filamentWeight = filaments.fold<double>(
      0,
      (sum, filament) => sum + filament.usedGrams,
    );

    return OrcaPlateMetadata(
      index: _int(values['index']),
      printerModelId: values['printer_model_id'] ?? '',
      nozzleDiameters: _doubleList(values['nozzle_diameters']),
      predictionSeconds: _double(values['prediction']),
      weightGrams: declaredWeight > 0 ? declaredWeight : filamentWeight,
      firstLayerTimeSeconds: _double(values['first_layer_time']),
      toolpathOutside: _bool(values['outside']),
      supportUsed: _bool(values['support_used']),
      labelObjectEnabled: _bool(values['label_object_enabled']),
      objects: List.unmodifiable(objects),
      filaments: List.unmodifiable(filaments),
      warnings: List.unmodifiable(warnings),
    );
  }
}

class OrcaSliceObject {
  const OrcaSliceObject({
    required this.identifyId,
    required this.name,
    required this.skipped,
  });

  final int identifyId;
  final String name;
  final bool skipped;
}

class OrcaSliceFilament {
  const OrcaSliceFilament({
    required this.id,
    required this.trayInfoId,
    required this.type,
    required this.color,
    required this.usedMeters,
    required this.usedGrams,
    required this.nozzleGroupIds,
    required this.nozzleDiameter,
    required this.nozzleVolumeType,
    required this.usedForObject,
    required this.usedForSupport,
  });

  final int id;
  final String trayInfoId;
  final String type;
  final String color;
  final double usedMeters;
  final double usedGrams;
  final List<int> nozzleGroupIds;
  final double nozzleDiameter;
  final String nozzleVolumeType;
  final bool usedForObject;
  final bool usedForSupport;
}

class OrcaSliceWarning {
  const OrcaSliceWarning({
    required this.message,
    required this.level,
    required this.errorCode,
  });

  final String message;
  final int level;
  final String errorCode;
}

int _int(String? value) => int.tryParse(value?.trim() ?? '') ?? 0;

double _double(String? value) =>
    double.tryParse(value?.trim() ?? '') ?? 0;

bool _bool(String? value) {
  final normalized = value?.trim().toLowerCase();
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

List<int> _intList(String? value) => List.unmodifiable(
      (value ?? '')
          .split(RegExp(r'[ ,;]+'))
          .map((part) => int.tryParse(part))
          .whereType<int>(),
    );

List<double> _doubleList(String? value) => List.unmodifiable(
      (value ?? '')
          .split(RegExp(r'[ ,;]+'))
          .map((part) => double.tryParse(part))
          .whereType<double>(),
    );
