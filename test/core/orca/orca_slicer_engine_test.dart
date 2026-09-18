import 'dart:convert';
import 'dart:io';
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

  test('buildArguments includes Orca progress pipe when requested', () {
    final engine = OrcaSlicerEngine(executable: '/opt/orca-slicer');
    final request = OrcaSlicerRequest(
      modelPath: '/tmp/project.3mf',
      machineProfilePath: '/tmp/machine.json',
      processProfilePath: '/tmp/process.json',
      filamentProfilePaths: const ['/tmp/filament.json'],
      outputDirectory: '/tmp/out',
    );

    final args = engine.buildArguments(
      request,
      bundleFileName: 'project.gcode.3mf',
      pipePath: '/tmp/orca-progress.pipe',
    );

    expect(
      args,
      containsAllInOrder([
        '/tmp/project.3mf',
        '--pipe',
        '/tmp/orca-progress.pipe',
        '--load-settings',
      ]),
    );
  });

  test('Orca progress parser reads message and warning JSON lines', () {
    final progress = OrcaSlicerProgress.tryParse(
      '{"plate_index":2,"plate_count":3,"plate_percent":40,'
      '"total_percent":55,"message":"Generating infill"}',
    );
    expect(progress, isNotNull);
    expect(progress!.plateIndex, 2);
    expect(progress.plateCount, 3);
    expect(progress.platePercent, 40);
    expect(progress.totalPercent, 55);
    expect(progress.message, 'Generating infill');
    expect(progress.isWarning, isFalse);

    final warning = OrcaSlicerProgress.tryParse(
      '{"plate_index":1,"plate_count":1,"plate_percent":80,'
      '"total_percent":75,"warning":"Thin wall"}',
    );
    expect(warning, isNotNull);
    expect(warning!.message, 'Thin wall');
    expect(warning.isWarning, isTrue);
    expect(OrcaSlicerProgress.tryParse('not json'), isNull);
  });

  test('cancelActiveSlice terminates a running Orca process', () async {
    if (Platform.isWindows) return;

    final temp = await Directory.systemTemp.createTemp('orca_cancel_test_');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    Future<String> fixture(String name) async {
      final file = File('${temp.path}${Platform.pathSeparator}$name');
      await file.writeAsString('{}');
      return file.path;
    }

    final script = File(
      '${temp.path}${Platform.pathSeparator}fake_orca.sh',
    );
    await script.writeAsString('#!/bin/sh\nsleep 30\n');
    final chmod = await Process.run('chmod', ['+x', script.path]);
    expect(chmod.exitCode, 0);

    final engine = OrcaSlicerEngine(executable: script.path);
    final future = engine.slice(
      OrcaSlicerRequest(
        modelPath: await fixture('project.3mf'),
        machineProfilePath: await fixture('machine.json'),
        processProfilePath: await fixture('process.json'),
        filamentProfilePaths: [await fixture('filament.json')],
        outputDirectory: '${temp.path}${Platform.pathSeparator}out',
      ),
    );

    for (var attempt = 0; attempt < 100 && !engine.isRunning; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(engine.isRunning, isTrue);
    expect(engine.cancelActiveSlice(), isTrue);
    await expectLater(
      future,
      throwsA(isA<OrcaSlicerCancelledException>()),
    );
    expect(engine.isRunning, isFalse);
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

  test('extractPlateGcodes exposes every sliced plate', () {
    final archive = Archive()
      ..addFile(
        ArchiveFile.bytes(
          'Metadata/plate_1.gcode',
          Uint8List.fromList(utf8.encode('G1 X1\n')),
        ),
      )
      ..addFile(
        ArchiveFile.bytes(
          'Metadata/plate_2.gcode',
          Uint8List.fromList(utf8.encode('G1 X2\n')),
        ),
      );

    final result = OrcaSlicerEngine(executable: 'unused').extractPlateGcodes(
      ZipEncoder().encodeBytes(archive),
    );

    expect(result.keys, containsAll([1, 2]));
    expect(utf8.decode(result[1]!), 'G1 X1\n');
    expect(utf8.decode(result[2]!), 'G1 X2\n');
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
