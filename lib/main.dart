import 'dart:io';

import 'package:flutter/widgets.dart';

import 'app/packaged_offline_smoke.dart';
import 'app/qidi_flow_app.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (PackagedOfflineSmoke.requested(args)) {
    exit(await PackagedOfflineSmoke.run(args));
  }

  runApp(const QidiFlowApp());
}
