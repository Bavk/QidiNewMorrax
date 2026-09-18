import 'dart:async';
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
  Process? _activeProcess;
  bool _cancelRequested = false;

  bool get isRunning => _activeProcess != null;

  bool cancelActiveSlice() {
    final process = _activeProcess;
    if (process == null) return false;
    _cancelRequested = true;
    return process.kill();
  }

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
    String? pipePath,
  }) {
    final settings = <String>[
      request.processProfilePath,
      request.machineProfilePath,
    ];
    return <String>[
      request.modelPath,
      if (pipePath != null && pipePath.isNotEmpty) ...[
        '--pipe',
        pipePath,
      ],
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

  Future<OrcaSlicerResult> slice(
    OrcaSlicerRequest request, {
    void Function(OrcaSlicerProgress progress)? onProgress,
  }) async {
    if (_activeProcess != null) {
      throw StateError('An OrcaSlicer process is already running.');
    }

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

    String? pipePath;
    StreamSubscription<String>? progressSubscription;
    if (Platform.isLinux && onProgress != null) {
      pipePath = _join(outputDirectory.path, '.orca-progress.pipe');
      await _createFifo(pipePath);
      progressSubscription = File(pipePath)
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            final progress = OrcaSlicerProgress.tryParse(line);
            if (progress != null) onProgress(progress);
          });
    }

    final arguments = buildArguments(
      request,
      bundleFileName: bundleFileName,
      pipePath: pipePath,
    );

    final stopwatch = Stopwatch()..start();
    _cancelRequested = false;
    Process process;
    String stdoutText = '';
    String stderrText = '';
    int exitCode;
    try {
      try {
        process = await Process.start(
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
      }

      _activeProcess = process;
      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      final stdoutDone = Completer<void>();
      final stderrDone = Completer<void>();
      final stdoutSubscription = process.stdout
          .transform(utf8.decoder)
          .listen(
            stdoutBuffer.write,
            onDone: stdoutDone.complete,
            onError: stdoutDone.completeError,
          );
      final stderrSubscription = process.stderr
          .transform(utf8.decoder)
          .listen(
            stderrBuffer.write,
            onDone: stderrDone.complete,
            onError: stderrDone.completeError,
          );

      exitCode = await process.exitCode;
      if (_cancelRequested) {
        await stdoutSubscription.cancel();
        await stderrSubscription.cancel();
        throw const OrcaSlicerCancelledException();
      }

      await Future.wait([stdoutDone.future, stderrDone.future]);
      stdoutText = stdoutBuffer.toString();
      stderrText = stderrBuffer.toString();
      if (exitCode != 0) {
        throw OrcaSlicerException(
          'OrcaSlicer exited with code $exitCode.\n'
          '${stderrText.isEmpty ? stdoutText : stderrText}',
          exitCode: exitCode,
        );
      }
    } finally {
      stopwatch.stop();
      _activeProcess = null;
      await progressSubscription?.cancel();
      if (pipePath != null) {
        await _deleteIfPresent(pipePath);
      }
    }

    final bundle = File(bundlePath);
    if (!await bundle.exists()) {
      throw OrcaSlicerException(
        'OrcaSlicer completed successfully but did not create $bundlePath.',
        exitCode: exitCode,
      );
    }

    final plateGcodes = extractPlateGcodes(await bundle.readAsBytes());
    if (plateGcodes.isEmpty) {
      throw const OrcaSlicerException(
        'Sliced 3MF contains no Metadata/plate_N.gcode entries.',
      );
    }

    final availablePlates = plateGcodes.keys.toList()..sort();
    final selectedPlate =
        request.plate == 0 ? availablePlates.first : request.plate;
    final selectedBytes = plateGcodes[selectedPlate];
    if (selectedBytes == null) {
      throw OrcaSlicerException(
        'Sliced 3MF has no plate $selectedPlate. '
        'Available plates: ${availablePlates.join(", ")}',
      );
    }

    final gcodePathsByPlate = <int, String>{};
    for (final entry in plateGcodes.entries) {
      final path = _join(
        outputDirectory.path,
        '$baseName.plate_${entry.key}.gcode',
      );
      await File(path).writeAsBytes(entry.value, flush: true);
      gcodePathsByPlate[entry.key] = path;
    }

    final gcodePath = _join(outputDirectory.path, '$baseName.gcode');
    await File(gcodePath).writeAsBytes(selectedBytes, flush: true);

    return OrcaSlicerResult(
      bundlePath: bundlePath,
      gcodePath: gcodePath,
      gcodePathsByPlate: Map.unmodifiable(gcodePathsByPlate),
      selectedPlate: selectedPlate,
      stdout: stdoutText,
      stderr: stderrText,
      exitCode: exitCode,
      elapsed: stopwatch.elapsed,
    );
  }

  Future<void> _createFifo(String path) async {
    await _deleteIfPresent(path);
    final result = await Process.run('mkfifo', [path]);
    if (result.exitCode != 0) {
      throw OrcaSlicerException(
        'Could not create OrcaSlicer progress FIFO at $path. '
        '${_asText(result.stderr)}',
        exitCode: result.exitCode,
      );
    }
  }

  Future<void> _deleteIfPresent(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type != FileSystemEntityType.notFound) {
      await File(path).delete();
    }
  }

  Map<int, Uint8List> extractPlateGcodes(Uint8List bundleBytes) {
    final archive = ZipDecoder().decodeBytes(bundleBytes, verify: true);
    final result = <int, Uint8List>{};
    const prefix = 'Metadata/plate_';
    const suffix = '.gcode';
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final normalized = file.name.replaceAll('\\\\', '/');
      if (!normalized.startsWith(prefix) || !normalized.endsWith(suffix)) {
        continue;
      }
      final digits = normalized.substring(
        prefix.length,
        normalized.length - suffix.length,
      );
      final plate = int.tryParse(digits);
      if (plate == null || plate <= 0) continue;
      result[plate] = Uint8List.fromList(file.content);
    }
    return Map.unmodifiable(result);
  }

  Uint8List extractPlateGcode(Uint8List bundleBytes, {int plate = 1}) {
    final plates = extractPlateGcodes(bundleBytes);
    final value = plates[plate];
    if (value != null) return value;
    final available = plates.keys.toList()..sort();
    throw OrcaSlicerException(
      'Sliced 3MF has no Metadata/plate_$plate.gcode. '
      'Available plates: ${available.isEmpty ? "none" : available.join(", ")}',
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
    required this.gcodePathsByPlate,
    required this.selectedPlate,
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.elapsed,
  });

  final String bundlePath;
  final String gcodePath;
  final Map<int, String> gcodePathsByPlate;
  final int selectedPlate;
  final String stdout;
  final String stderr;
  final int exitCode;
  final Duration elapsed;
}

class OrcaSlicerProgress {
  const OrcaSlicerProgress({
    required this.plateIndex,
    required this.plateCount,
    required this.platePercent,
    required this.totalPercent,
    required this.message,
    required this.isWarning,
  });

  final int plateIndex;
  final int plateCount;
  final int platePercent;
  final int totalPercent;
  final String message;
  final bool isWarning;

  static OrcaSlicerProgress? tryParse(String line) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) return null;
      final values = decoded.cast<String, dynamic>();
      final warning = values['warning'];
      final message = warning ?? values['message'];
      return OrcaSlicerProgress(
        plateIndex: _intValue(values['plate_index']),
        plateCount: _intValue(values['plate_count']),
        platePercent: _intValue(values['plate_percent']),
        totalPercent: _intValue(values['total_percent']),
        message: message?.toString() ?? '',
        isWarning: warning != null,
      );
    } catch (_) {
      return null;
    }
  }

  static int _intValue(dynamic value) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class OrcaSlicerCancelledException implements Exception {
  const OrcaSlicerCancelledException();

  @override
  String toString() => 'OrcaSlicer slicing was cancelled.';
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
