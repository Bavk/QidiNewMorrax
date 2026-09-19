import 'dart:io';

import 'package:qidi_flow_flutter/core/orca/orca_slicer_engine.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/verify_packaged_orca.dart '
      '<qidi-flow-linux-executable>',
    );
    exitCode = 64;
    return;
  }

  final appExecutable = File(args.single).absolute.path;
  final discovered = OrcaSlicerEngine.defaultExecutable(
    environment: const {},
    resolvedExecutable: appExecutable,
  );
  final expected = File(
    '${File(appExecutable).parent.path}${Platform.pathSeparator}'
    '${OrcaSlicerEngine.packagedEngineDirectoryName}'
    '${Platform.pathSeparator}'
    '${OrcaSlicerEngine.packagedLinuxExecutableName}',
  ).path;

  if (discovered != expected) {
    throw StateError(
      'Packaged Orca discovery mismatch. Expected $expected, got $discovered.',
    );
  }

  final engine = OrcaSlicerEngine(executable: discovered);
  if (!await engine.verifyPackagedEngine()) {
    throw StateError('Packaged Orca provenance manifest was not detected.');
  }

  stdout.writeln(
    'Verified packaged OrcaSlicer '
    'v${OrcaSlicerEngine.pinnedVersion} '
    '(${OrcaSlicerEngine.pinnedCommit}) at $discovered.',
  );
}
