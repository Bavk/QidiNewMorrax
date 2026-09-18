import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/model_io/mesh.dart';
import '../../../core/model_io/mesh_stl_writer.dart';
import '../../../core/orca/orca_profile_materializer.dart';
import '../../../core/orca/orca_slicer_engine.dart';
import '../../../core/profiles/profile_repository.dart';

class WorkspaceController extends ChangeNotifier {
  WorkspaceController({
    OrcaSlicerEngine? engine,
    ProfileRepository? profiles,
  })  : engine = engine ?? OrcaSlicerEngine(),
        profiles = profiles ?? ProfileRepository();

  final OrcaSlicerEngine engine;
  final ProfileRepository profiles;

  Mesh? mesh;
  String? sourceModelPath;
  QidiProfile? machine;
  QidiProfile? process;
  QidiProfile? filament;

  bool slicing = false;
  String? lastGcodePath;
  String? lastBundlePath;
  String? statusMessage;
  Object? error;

  bool get canSlice =>
      mesh != null && machine != null && process != null && filament != null;

  void updateSelection({
    Mesh? mesh,
    String? sourceModelPath,
    QidiProfile? machine,
    QidiProfile? process,
    QidiProfile? filament,
  }) {
    this.mesh = mesh;
    this.sourceModelPath = sourceModelPath;
    this.machine = machine;
    this.process = process;
    this.filament = filament;
    error = null;
    notifyListeners();
  }

  Future<OrcaSlicerResult> slice() async {
    if (!canSlice) {
      throw StateError('Select a model, printer, process and filament first.');
    }
    if (slicing) {
      throw StateError('A slice is already running.');
    }

    slicing = true;
    error = null;
    statusMessage = 'Preparing OrcaSlicer job…';
    notifyListeners();

    try {
      final job = await Directory.systemTemp.createTemp('qidi_orca_job_');
      final modelDirectory = Directory(
        '${job.path}${Platform.pathSeparator}model',
      );
      final profileDirectory = Directory(
        '${job.path}${Platform.pathSeparator}profiles',
      );
      final outputDirectory = Directory(
        '${job.path}${Platform.pathSeparator}output',
      );

      final modelPath = await const MeshStlWriter().write(
        mesh!,
        directory: modelDirectory,
      );

      statusMessage = 'Resolving QIDI profiles…';
      notifyListeners();

      final resolvedMachine =
          await profiles.resolved(machine!.name) ?? machine!;
      final resolvedProcess =
          await profiles.resolved(process!.name) ?? process!;
      final resolvedFilament =
          await profiles.resolved(filament!.name) ?? filament!;

      final profileFiles = await const OrcaProfileMaterializer().materialize(
        directory: profileDirectory,
        machine: resolvedMachine,
        process: resolvedProcess,
        filaments: [resolvedFilament],
      );

      statusMessage = 'Slicing with OrcaSlicer…';
      notifyListeners();

      final result = await engine.slice(
        OrcaSlicerRequest(
          modelPath: modelPath,
          machineProfilePath: profileFiles.machine,
          processProfilePath: profileFiles.process,
          filamentProfilePaths: profileFiles.filaments,
          outputDirectory: outputDirectory.path,
        ),
      );

      lastGcodePath = result.gcodePath;
      lastBundlePath = result.bundlePath;
      statusMessage =
          'OrcaSlicer finished in ${result.elapsed.inMilliseconds / 1000}s';
      return result;
    } catch (caught) {
      error = caught;
      statusMessage = 'Slicing failed';
      rethrow;
    } finally {
      slicing = false;
      notifyListeners();
    }
  }
}
