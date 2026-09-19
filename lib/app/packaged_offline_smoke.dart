import 'dart:convert';
import 'dart:io';

import '../core/gcode/gcode_parser.dart';
import '../core/model_io/model_loader.dart';
import '../core/orca/orca_slicer_engine.dart';
import '../core/profiles/profile_repository.dart';
import '../features/workspace/application/workspace_controller.dart';
import '../features/workspace/domain/workspace_editable_project.dart';

class PackagedOfflineSmokeOptions {
  const PackagedOfflineSmokeOptions({
    required this.modelPath,
    required this.reportPath,
  });

  final String modelPath;
  final String reportPath;

  static PackagedOfflineSmokeOptions parse(List<String> args) {
    String? value(String name) {
      final prefix = name + '=';
      for (var index = 0; index < args.length; index++) {
        final argument = args[index];
        if (argument.startsWith(prefix)) {
          return argument.substring(prefix.length);
        }
        if (argument == name && index + 1 < args.length) {
          return args[index + 1];
        }
      }
      return null;
    }

    final model = value('--model')?.trim();
    final report = value('--report')?.trim();
    if (model == null || model.isEmpty) {
      throw const FormatException(
        'Packaged smoke requires --model <path>.',
      );
    }
    if (report == null || report.isEmpty) {
      throw const FormatException(
        'Packaged smoke requires --report <path>.',
      );
    }
    return PackagedOfflineSmokeOptions(
      modelPath: model,
      reportPath: report,
    );
  }
}

class PackagedOfflineSmoke {
  const PackagedOfflineSmoke._();

  static const flag = '--packaged-offline-smoke';

  static bool requested(List<String> args) => args.contains(flag);

  static Future<int> run(List<String> args) async {
    PackagedOfflineSmokeOptions? options;
    try {
      options = PackagedOfflineSmokeOptions.parse(args);
      final report = await _execute(options);
      await _writeReport(options.reportPath, report);
      stdout.writeln(
        'PACKAGED_OFFLINE_SMOKE_OK ' + jsonEncode(report),
      );
      return 0;
    } catch (error, stackTrace) {
      final reportPath = options?.reportPath;
      final failure = <String, Object?>{
        'status': 'error',
        'error': error.toString(),
        'stack': stackTrace.toString(),
      };
      if (reportPath != null && reportPath.isNotEmpty) {
        try {
          await _writeReport(reportPath, failure);
        } catch (_) {
          // The original smoke failure is the result that matters.
        }
      }
      stderr.writeln(
        'PACKAGED_OFFLINE_SMOKE_ERROR ' + jsonEncode(failure),
      );
      return 1;
    }
  }

  static Future<Map<String, Object?>> _execute(
    PackagedOfflineSmokeOptions options,
  ) async {
    final modelFile = File(options.modelPath);
    if (!await modelFile.exists()) {
      throw StateError(
        'Smoke model does not exist: ' + options.modelPath,
      );
    }

    final modelBytes = await modelFile.readAsBytes();
    final fileName = modelFile.uri.pathSegments.isEmpty
        ? 'smoke-model.stl'
        : modelFile.uri.pathSegments.last;
    final mesh = const ModelLoader().load(modelBytes, fileName);
    if (mesh.triangles.isEmpty) {
      throw StateError('Smoke model contains no triangles.');
    }

    final profiles = ProfileRepository();
    final allProfiles = await profiles.loadAll();
    final machines =
        allProfiles.where((profile) => profile.type == 'machine').toList();
    final machine = _firstWhere(
      machines,
      (profile) => profile.name.contains('X-Plus 4'),
    );
    if (machine == null) {
      throw StateError('Packaged QIDI X-Plus 4 profile was not found.');
    }

    final compatibleFilaments = allProfiles
        .where(
          (profile) =>
              profile.type == 'filament' &&
              profile.isCompatibleWithPrinter(machine.name),
        )
        .toList();
    final compatibleProcesses = allProfiles
        .where(
          (profile) =>
              profile.type == 'process' &&
              profile.isCompatibleWithPrinter(machine.name),
        )
        .toList();
    final filament = _firstWhere(
          compatibleFilaments,
          (profile) => profile.name.contains('PLA'),
        ) ??
        (compatibleFilaments.isEmpty ? null : compatibleFilaments.first);
    final process = _firstWhere(
          compatibleProcesses,
          (profile) => profile.name.contains('0.20'),
        ) ??
        (compatibleProcesses.isEmpty ? null : compatibleProcesses.first);
    if (filament == null || process == null) {
      throw StateError(
        'Packaged QIDI profiles are incomplete for the smoke selection.',
      );
    }

    final project = WorkspaceEditableProject.empty().addObject(
      mesh,
      plateIndex: 0,
      name: mesh.name,
    );
    final controller = WorkspaceController(profiles: profiles);
    controller.updateSelection(
      mesh: mesh,
      sourceModelPath: modelFile.path,
      machine: machine,
      process: process,
      filament: filament,
      editableProject: project,
    );

    final packagedVerified = await controller.engine.verifyPackagedEngine();
    if (!packagedVerified) {
      throw StateError(
        'Smoke executable did not resolve a verified packaged Orca engine.',
      );
    }

    final result = await controller.slice();
    final gcodeFile = File(result.gcodePath);
    if (!await gcodeFile.exists()) {
      throw StateError('Slice completed without selected G-code output.');
    }
    final gcodeText = await gcodeFile.readAsString();
    final previewStats = const GCodeParser().stats(gcodeText);
    if (previewStats.moveCount <= 0 ||
        previewStats.extrusionMoveCount <= 0) {
      throw StateError(
        'Preview parser did not observe printable G-code moves.',
      );
    }

    final selectedMetadata =
        result.sliceMetadata.plate(result.selectedPlate);
    if (selectedMetadata == null) {
      throw StateError(
        'Slice metadata has no selected plate ' +
            result.selectedPlate.toString() +
            '.',
      );
    }

    final bundleFile = File(result.bundlePath);
    final report = <String, Object?>{
      'status': 'ok',
      'model': <String, Object?>{
        'name': mesh.name,
        'triangle_count': mesh.triangles.length,
      },
      'profiles': <String, Object?>{
        'machine': machine.name,
        'process': process.name,
        'filament': filament.name,
      },
      'engine': <String, Object?>{
        'packaged_verified': packagedVerified,
        'version': OrcaSlicerEngine.pinnedVersion,
        'commit': OrcaSlicerEngine.pinnedCommit,
        'executable_name':
            File(controller.engine.executable).uri.pathSegments.last,
      },
      'slice': <String, Object?>{
        'selected_plate': result.selectedPlate,
        'plate_count': result.gcodePathsByPlate.length,
        'bundle_bytes': await bundleFile.length(),
        'gcode_bytes': await gcodeFile.length(),
        'prediction_seconds': selectedMetadata.predictionSeconds,
        'filament_meters': selectedMetadata.totalFilamentMeters,
        'warnings': selectedMetadata.warnings.length,
      },
      'preview': <String, Object?>{
        'move_count': previewStats.moveCount,
        'extrusion_move_count': previewStats.extrusionMoveCount,
        'extrusion_mm': previewStats.extrusionMm,
        'min_x': previewStats.minX,
        'max_x': previewStats.maxX,
        'min_y': previewStats.minY,
        'max_y': previewStats.maxY,
        'min_z': previewStats.minZ,
        'max_z': previewStats.maxZ,
      },
    };

    controller.dispose();
    return report;
  }

  static QidiProfile? _firstWhere(
    Iterable<QidiProfile> profiles,
    bool Function(QidiProfile profile) predicate,
  ) {
    for (final profile in profiles) {
      if (predicate(profile)) return profile;
    }
    return null;
  }

  static Future<void> _writeReport(
    String path,
    Map<String, Object?> report,
  ) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(report),
      flush: true,
    );
  }
}
