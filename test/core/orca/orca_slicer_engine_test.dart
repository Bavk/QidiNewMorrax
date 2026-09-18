import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/orca/orca_slicer_engine.dart';

void main() {
  test('buildArguments maps the Dart job to the pinned Orca CLI contract', () {
    final engine = OrcaSlicerEngine(executable: '/opt/orca-slicer');
    final request = OrcaSlicerRequest(
      modelPath: '/tmp/model.stl',
      machineProfilePath: '/tmp/machine.json',
      processProfilePath: '/tmp/process.json',
      filamentProfilePaths: const ['/tmp/filament.json'],
      outputDirectory: '/tmp/out',
      arrange: false,
      orient: false,
      ensureOnBed: true,
    );

    expect(
      engine.buildArguments(request, bundleFileName: 'model.gcode.3mf'),
      [
        '/tmp/model.stl',
        '--load-settings',
        '/tmp/process.json;/tmp/machine.json',
        '--load-filaments',
        '/tmp/filament.json',
        '--arrange',
        '0',
        '--orient',
        '0',
        '--ensure-on-bed',
        '--slice',
        '0',
        '--export-3mf',
        'model.gcode.3mf',
        '--outputdir',
        '/tmp/out',
        '--debug',
        '2',
      ],
    );
  });

  test('extractPlateGcode reads Orca Metadata/plate_N.gcode', () {
    final archive = Archive()
      ..addFile(
        ArchiveFile.bytes(
          'Metadata/plate_1.gcode',
          Uint8List.fromList(utf8.encode('G90\nG1 X10 Y20\n')),
        ),
      )
      ..addFile(
        ArchiveFile.bytes(
          'Metadata/slice_info.config',
          Uint8List.fromList(utf8.encode('<config/>')),
        ),
      );

    final zip = ZipEncoder().encodeBytes(archive);
    final result = OrcaSlicerEngine(executable: 'unused').extractPlateGcode(
      zip,
    );

    expect(utf8.decode(result), 'G90\nG1 X10 Y20\n');
  });

  test('extractPlateGcode rejects a sliced bundle without requested plate', () {
    final archive = Archive()
      ..addFile(
        ArchiveFile.bytes(
          'Metadata/plate_2.gcode',
          Uint8List.fromList(utf8.encode('G90\n')),
        ),
      );

    expect(
      () => OrcaSlicerEngine(executable: 'unused').extractPlateGcode(
        ZipEncoder().encodeBytes(archive),
        plate: 1,
      ),
      throwsA(isA<OrcaSlicerException>()),
    );
  });
}
