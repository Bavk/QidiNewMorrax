import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../gcode/gcode_parser.dart';
import '../model_io/model_loader.dart';
import '../profiles/profile_repository.dart';
import '../../features/workspace/application/workspace_controller.dart';

class PackagedOfflineSmoke {
  const PackagedOfflineSmoke();

  static const machineProfileName = 'Qidi X-Plus 4 0.4 nozzle';
  static const processProfileName = '0.20mm Standard @Qidi XPlus4';
  static const filamentProfileName =
      'Qidi Generic PLA @Qidi X-Plus 4 0.4 nozzle';

  Future<Map<String, Object?>> run({required String modelPath}) async {
    final modelFile = File(modelPath);
    if (!await modelFile.exists()) {
      throw StateError('Smoke model does not exist: $modelPath');
    }

    final repository = ProfileRepository();
    final machine = await repository.findByName(machineProfileName);
    final process = await repository.findByName(processProfileName);
    final filament = await repository.findByName(filamentProfileName);
    if (machine == null || process == null || filament == null) {
      final available = await repository.loadAll();
      throw StateError(
        'Packaged QIDI profile catalog is incomplete. '
        'Required: $machineProfileName / $processProfileName / '
        '$filamentProfileName. Loaded ${available.length} profiles.',
      );
    }

    final bytes = Uint8List.fromList(await modelFile.readAsBytes());
    final mesh = const ModelLoader().load(
      bytes,
      modelFile.uri.pathSegments.isEmpty
          ? 'smoke.stl'
          : modelFile.uri.pathSegments.last,
    );

    final controller = WorkspaceController(profiles: repository);
    controller.updateSelection(
      mesh: mesh,
      sourceModelPath: modelFile.path,
      machine: machine,
      process: process,
      filament: filament,
    );

    final result = await controller.slice();
    final gcodePath = controller.lastGcodePath;
    if (gcodePath == null) {
      throw StateError('Workspace completed without a selected G-code path.');
    }
    final gcode = await File(gcodePath).readAsString();
    final stats = const GCodeParser().stats(gcode);
    final metadata = controller.lastSelectedPlateMetadata;
    final packagedEngineVerified =
        await controller.engine.verifyPackagedEngine();

    if (stats.moveCount <= 0 || stats.extrusionMoveCount <= 0) {
      throw StateError(
        'Preview input contains no printable motion: '
        '${stats.moveCount} moves / ${stats.extrusionMoveCount} extrusion.',
      );
    }
    if (metadata == null || metadata.predictionSeconds <= 0) {
      throw StateError(
        'Selected plate has no authoritative Orca prediction metadata.',
      );
    }

    return <String, Object?>{
      'success': true,
      'model': modelFile.path,
      'model_triangles': mesh.triangles.length,
      'engine_executable': controller.engine.executable,
      'packaged_engine_verified': packagedEngineVerified,
      'bundle_path': result.bundlePath,
      'gcode_path': gcodePath,
      'selected_plate': controller.lastSelectedPlate,
      'available_plates': controller.lastGcodePathsByPlate.keys.toList()..sort(),
      'move_count': stats.moveCount,
      'extrusion_move_count': stats.extrusionMoveCount,
      'prediction_seconds': metadata.predictionSeconds,
      'filament_meters': metadata.totalFilamentMeters,
      'warning_count': metadata.warnings.length,
      'preview_ready': true,
    };
  }

  static Future<void> writeResult(
    String path,
    Map<String, Object?> result,
  ) async {
    await File(path).writeAsString(
      const JsonEncoder.withIndent('  ').convert(result),
      flush: true,
    );
  }
}
