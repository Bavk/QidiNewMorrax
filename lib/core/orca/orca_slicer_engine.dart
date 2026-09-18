import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Runtime bridge to the pinned OrcaSlicer engine.
///
/// QidiNewMorrax intentionally does not reimplement polygon clipping, Arachne,
/// infill, supports or G-code generation in Dart anymore. OrcaSlicer owns the
/// complete slicing pipeline; Dart owns application state, profiles, Preview
/// and printer/device integration.
class OrcaSlicerEngine {
  OrcaSlicerEngine({String? executable})
      : executable = executable ?? defaultExecutable();

  static const pinnedVersion = '2.4.2';
  static const pinnedCommit = '8500fcdccaa10b5099ac20d252af3a7c560046f1';

  final String executable;

  static String defaultExecutable() {
    final configured = Platform.environment['ORCA_SLICER_BIN'];
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    if (Platform.isMacOS) {
      return '/Applications/OrcaSlicer.app/Contents/MacOS/OrcaSlicer';
    }
    if (Platform.isWindows) return 'OrcaSlicer.exe';
    return 'orca-slicer';
  }

  List<String> buildArguments(
    OrcaSlicerRequest request, {
    required String bundleFileName,
  }) {
    final settings = <String>[
      request.processProfilePath,
      request.machineProfilePath,
    ];
    return <String>[
      request.modelPath,
      '--load-settings',
      settings.join(';'),
      if (request.filamentProfilePaths.isNotEmpty) ...[
        '--load-filaments',
        request.filamentProfilePaths.join(';'),
      ],
      '--arrange',
      request.arrange ? '1' : '0',
      '--orient',
      request.orient ? '1' : '0',
      if (request.ensureOnBed) '--ensure-on-bed',
      '--slice',
      request.plate.toString(),
      '--export-3mf',
      bundleFileName,
      '--outputdir',
      request.outputDirectory,
      '--debug',
      request.debugLevel.toString(),
    ];
  }

  Future<OrcaSlicerResult> slice(OrcaSlicerRequest request) async {
    await _requireFile(request.modelPath, 'model');
    await _requireFile(request.machineProfilePath, 'machine profile');
    await _requireFile(request.processProfilePath, 'process profile');
    for (final path in request.filamentProfilePaths) {
      await _requireFile(path, 'filament profile');
    }

    final outputDirectory = Directory(request.outputDirectory);
    await outputDirectory.create(recursive: true);
    final baseName = _fileStem(request.modelPath);
    final bundleFileName = '$baseName.gcode.3mf';
    final bundlePath = _join(outputDirectory.path, bundleFileName);
    final arguments = buildArguments(
      request,
      bundleFileName: bundleFileName,
    );

    final stopwatch = Stopwatch()..start();
    ProcessResult process;
    try {
      process = await Process.run(
        executable,
        arguments,
        runInShell: Platform.isWindows,
      );
    } on ProcessException catch (error) {
      throw OrcaSlicerException(
        'Could not start OrcaSlicer at "$executable". '
        'Install OrcaSlicer $pinnedVersion or set ORCA_SLICER_BIN.',
        cause: error,
      );
    } finally {
      stopwatch.stop();
    }

    final stdoutText = _asText(process.stdout);
    final stderrText = _asText(process.stderr);
    if (process.exitCode != 0) {
      throw OrcaSlicerException(
        'OrcaSlicer exited with code ${process.exitCode}.\n'
        '${stderrText.isEmpty ? stdoutText : stderrText}',
        exitCode: process.exitCode,
      );
    }

    final bundle = File(bundlePath);
    if (!await bundle.exists()) {
      throw OrcaSlicerException(
        'OrcaSlicer completed successfully but did not create $bundlePath.',
        exitCode: process.exitCode,
      );
    }

    final gcodeBytes = extractPlateGcode(
      await bundle.readAsBytes(),
      plate: request.plate == 0 ? 1 : request.plate,
    );
    final gcodePath = _join(outputDirectory.path, '$baseName.gcode');
    await File(gcodePath).writeAsBytes(gcodeBytes, flush: true);

    return OrcaSlicerResult(
      bundlePath: bundlePath,
      gcodePath: gcodePath,
      stdout: stdoutText,
      stderr: stderrText,
      exitCode: process.exitCode,
      elapsed: stopwatch.elapsed,
    );
  }

  Uint8List extractPlateGcode(Uint8List bundleBytes, {int plate = 1}) {
    final archive = ZipDecoder().decodeBytes(bundleBytes, verify: true);
    final wanted = 'Metadata/plate_$plate.gcode';
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final normalized = file.name.replaceAll('\\', '/');
      if (normalized == wanted) {
        return Uint8List.fromList(file.content);
      }
    }

    final available = archive.files
        .where((file) => file.isFile && file.name.toLowerCase().endsWith('.gcode'))
        .map((file) => file.name)
        .toList(growable: false);
    throw OrcaSlicerException(
      'Sliced 3MF has no $wanted. '
      'Available G-code entries: ${available.isEmpty ? "none" : available.join(", ")}',
    );
  }

  static Future<void> _requireFile(String path, String label) async {
    if (!await File(path).exists()) {
      throw OrcaSlicerException('OrcaSlicer $label does not exist: $path');
    }
  }

  static String _asText(Object? value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is List<int>) return utf8.decode(value, allowMalformed: true);
    return value.toString();
  }

  static String _fileStem(String path) {
    final normalized = path.replaceAll('\\', '/');
    final name = normalized.split('/').last;
    final dot = name.lastIndexOf('.');
    final stem = dot <= 0 ? name : name.substring(0, dot);
    return stem.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  }

  static String _join(String directory, String name) {
    if (directory.endsWith('/') || directory.endsWith('\\')) {
      return '$directory$name';
    }
    return '$directory${Platform.pathSeparator}$name';
  }
}

class OrcaSlicerRequest {
  const OrcaSlicerRequest({
    required this.modelPath,
    required this.machineProfilePath,
    required this.processProfilePath,
    required this.filamentProfilePaths,
    required this.outputDirectory,
    this.plate = 0,
    this.arrange = false,
    this.orient = false,
    this.ensureOnBed = true,
    this.debugLevel = 2,
  });

  final String modelPath;
  final String machineProfilePath;
  final String processProfilePath;
  final List<String> filamentProfilePaths;
  final String outputDirectory;
  final int plate;
  final bool arrange;
  final bool orient;
  final bool ensureOnBed;
  final int debugLevel;
}

class OrcaSlicerResult {
  const OrcaSlicerResult({
    required this.bundlePath,
    required this.gcodePath,
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.elapsed,
  });

  final String bundlePath;
  final String gcodePath;
  final String stdout;
  final String stderr;
  final int exitCode;
  final Duration elapsed;
}

class OrcaSlicerException implements Exception {
  const OrcaSlicerException(
    this.message, {
    this.exitCode,
    this.cause,
  });

  final String message;
  final int? exitCode;
  final Object? cause;

  @override
  String toString() => message;
}
