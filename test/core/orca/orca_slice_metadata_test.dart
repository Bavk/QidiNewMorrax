import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/orca/orca_slice_metadata.dart';

void main() {
  const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<config>
  <header>
    <header_item key="X-BBL-Client-Type" value="slicer"/>
    <header_item key="OrcaSlicer-Version" value="2.4.2"/>
  </header>
  <plate>
    <metadata key="index" value="1"/>
    <metadata key="printer_model_id" value="Qidi X-Plus 4"/>
    <metadata key="nozzle_diameters" value="0.4"/>
    <metadata key="prediction" value="3661"/>
    <metadata key="weight" value="12.75"/>
    <metadata key="first_layer_time" value="42"/>
    <metadata key="outside" value="false"/>
    <metadata key="support_used" value="true"/>
    <metadata key="label_object_enabled" value="true"/>
    <object identify_id="91" name="cube_id_0_copy_0" skipped="false"/>
    <filament id="1" tray_info_idx="GFL00" type="PLA" color="#FF8800"
      used_m="4.25" used_g="12.75" group_id="0,2"
      nozzle_diameter="0.4" volume_type="Standard"
      used_for_object="true" used_for_support="true"/>
    <warning msg="Toolpath is outside the build area" level="1" error_code="1201"/>
  </plate>
  <plate>
    <metadata key="index" value="2"/>
    <metadata key="prediction" value="59.5"/>
    <metadata key="weight" value=""/>
    <metadata key="first_layer_time" value="12"/>
    <metadata key="outside" value="true"/>
    <metadata key="support_used" value="false"/>
    <metadata key="label_object_enabled" value="false"/>
    <filament id="1" tray_info_idx="" type="PLA" color="#FFFFFF"
      used_m="0.42" used_g="1.25" group_id="0"
      nozzle_diameter="0.4" volume_type="Standard"
      used_for_object="true" used_for_support="false"/>
  </plate>
</config>''';

  test('parses Orca slice_info.config plate estimates and warnings', () {
    final metadata = OrcaSliceMetadata.fromXml(xml);

    expect(metadata.header['OrcaSlicer-Version'], '2.4.2');
    expect(metadata.plates.keys, containsAll([1, 2]));
    expect(metadata.totalPredictionSeconds, 3720.5);
    expect(metadata.totalWeightGrams, 14);

    final plate = metadata.plate(1)!;
    expect(plate.printerModelId, 'Qidi X-Plus 4');
    expect(plate.nozzleDiameters, [0.4]);
    expect(plate.predictionSeconds, 3661);
    expect(plate.weightGrams, 12.75);
    expect(plate.firstLayerTimeSeconds, 42);
    expect(plate.supportUsed, isTrue);
    expect(plate.toolpathOutside, isFalse);
    expect(plate.labelObjectEnabled, isTrue);

    expect(plate.objects.single.name, 'cube_id_0_copy_0');
    expect(plate.objects.single.identifyId, 91);
    expect(plate.objects.single.skipped, isFalse);

    final filament = plate.filaments.single;
    expect(filament.type, 'PLA');
    expect(filament.usedMeters, 4.25);
    expect(filament.usedGrams, 12.75);
    expect(filament.nozzleGroupIds, [0, 2]);
    expect(filament.nozzleDiameter, 0.4);
    expect(filament.usedForObject, isTrue);
    expect(filament.usedForSupport, isTrue);

    final warning = plate.warnings.single;
    expect(warning.message, 'Toolpath is outside the build area');
    expect(warning.level, 1);
    expect(warning.errorCode, '1201');
  });

  test('parses slice metadata directly from sliced 3MF bundle', () {
    final archive = Archive()
      ..addFile(
        ArchiveFile.bytes(
          'Metadata/slice_info.config',
          Uint8List.fromList(utf8.encode(xml)),
        ),
      )
      ..addFile(
        ArchiveFile.bytes(
          'Metadata/plate_1.gcode',
          Uint8List.fromList(utf8.encode('G1 X1\n')),
        ),
      );

    final metadata = OrcaSliceMetadata.fromBundle(
      ZipEncoder().encodeBytes(archive),
    );

    expect(metadata.plate(1)?.predictionSeconds, 3661);
    expect(metadata.warnings, hasLength(1));
  });

  test('fills missing CLI metadata from Orca G-code statistics comments', () {
    const sparseXml = '''<config>
  <plate>
    <metadata key="index" value="1"/>
    <metadata key="prediction" value=""/>
    <metadata key="weight" value=""/>
    <metadata key="first_layer_time" value=""/>
    <filament id="1" type="PLA" used_m="0" used_g="0"
      used_for_object="true" used_for_support="false"/>
    <filament id="2" type="PETG" used_m="0" used_g="0"
      used_for_object="true" used_for_support="false"/>
  </plate>
</config>''';
    final gcode = Uint8List.fromList(utf8.encode('''
; estimated printing time (normal mode) = 1d 2h 3m 4s
; estimated first layer printing time (normal mode) = 2m 5s
; filament used [mm] = 1234.50, 250.00
; filament used [g] = 3.40, 0.75
; total filament used [g] = 4.15
G1 X1
'''));

    final metadata = OrcaSliceMetadata.fromXml(sparseXml)
        .withPlateGcodes({1: gcode});
    final plate = metadata.plate(1)!;

    expect(plate.predictionSeconds, 93784);
    expect(plate.firstLayerTimeSeconds, 125);
    expect(plate.weightGrams, 4.15);
    expect(plate.filaments[0].usedGrams, 3.4);
    expect(plate.filaments[0].usedMeters, 1.2345);
    expect(plate.filaments[1].usedGrams, 0.75);
    expect(plate.filaments[1].usedMeters, 0.25);
  });

  test('slice_info values stay authoritative over G-code fallback', () {
    final gcode = Uint8List.fromList(utf8.encode('''
; estimated printing time (normal mode) = 9h 0m 0s
; estimated first layer printing time (normal mode) = 9m 0s
; total filament used [g] = 99
'''));

    final metadata = OrcaSliceMetadata.fromXml(xml)
        .withPlateGcodes({1: gcode});
    final plate = metadata.plate(1)!;

    expect(plate.predictionSeconds, 3661);
    expect(plate.firstLayerTimeSeconds, 42);
    expect(plate.weightGrams, 12.75);
  });

  test('missing slice_info.config returns empty metadata', () {
    final archive = Archive()
      ..addFile(
        ArchiveFile.bytes(
          'Metadata/plate_1.gcode',
          Uint8List.fromList(utf8.encode('G1 X1\n')),
        ),
      );

    final metadata = OrcaSliceMetadata.fromBundle(
      ZipEncoder().encodeBytes(archive),
    );

    expect(metadata.plates, isEmpty);
    expect(metadata.header, isEmpty);
  });
}
