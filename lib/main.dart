import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

import 'app/qidi_flow_app.dart';
import 'core/release/packaged_offline_smoke.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final smokeModel =
      Platform.environment['QIDI_PACKAGED_OFFLINE_SMOKE_MODEL']?.trim();
  if (smokeModel != null && smokeModel.isNotEmpty) {
    await _runPackagedOfflineSmoke(smokeModel);
    return;
  }

  runApp(const QidiFlowApp());
}

Future<void> _runPackagedOfflineSmoke(String modelPath) async {
  final resultPath =
      Platform.environment['QIDI_PACKAGED_OFFLINE_SMOKE_RESULT']?.trim();
  try {
    final result = await const PackagedOfflineSmoke().run(
      modelPath: modelPath,
    );
    if (resultPath != null && resultPath.isNotEmpty) {
      await PackagedOfflineSmoke.writeResult(resultPath, result);
    }
    stdout.writeln(jsonEncode(result));
    exit(0);
  } catch (error, stackTrace) {
    final failure = <String, Object?>{
      'success': false,
      'error': error.toString(),
    };
    if (resultPath != null && resultPath.isNotEmpty) {
      await PackagedOfflineSmoke.writeResult(resultPath, failure);
    }
    stderr
      ..writeln(jsonEncode(failure))
      ..writeln(stackTrace);
    exit(1);
  }
}
