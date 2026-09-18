import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../../core/geometry/point.dart';
import '../../../core/model_io/mesh.dart';
import '../../../core/model_io/three_mf_parser.dart';
import '../../../core/model_io/three_mf_project_writer.dart';
import '../../../core/model_io/three_mf_transform.dart';
import '../../../core/model_io/three_mf_writer.dart';
import '../../../core/orca/orca_profile_materializer.dart';
import '../../../core/orca/orca_project_settings_builder.dart';
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
  ThreeMfPackage? sourceProject;
  ThreeMfTransform _sourceProjectTransform = ThreeMfTransform.identity;

  bool slicing = false;
  String? lastGcodePath;
  Map<int, String> lastGcodePathsByPlate = const {};
  int? lastSelectedPlate;
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
    ThreeMfPackage? sourceProject,
  }) {
    if (!identical(this.sourceProject, sourceProject)) {
      _sourceProjectTransform = ThreeMfTransform.identity;
    }
    this.mesh = mesh;
    this.sourceModelPath = sourceModelPath;
    this.machine = machine;
    this.process = process;
    this.filament = filament;
    this.sourceProject = sourceProject;
    error = null;
    notifyListeners();
  }

  void recordModelTransform({
    Point3 translation = const Point3(0, 0, 0),
    Point3 scale = const Point3(1, 1, 1),
    Point3 rotationDegrees = const Point3(0, 0, 0),
  }) {
    if (sourceProject == null) return;
    final delta = ThreeMfTransform.fromComponents(
      translation: translation,
      scale: scale,
      rotationDegrees: rotationDegrees,
    );
    _sourceProjectTransform = delta * _sourceProjectTransform;
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

      statusMessage = 'Resolving QIDI profiles…';
      notifyListeners();

      final resolvedMachine =
          await profiles.resolved(machine!.name) ?? machine!;
      final resolvedProcess =
          await profiles.resolved(process!.name) ?? process!;
      final resolvedFilament =
          await profiles.resolved(filament!.name) ?? filament!;
      final projectSettings = const OrcaProjectSettingsBuilder().build(
        machine: resolvedMachine,
        process: resolvedProcess,
        filaments: [resolvedFilament],
      );

      statusMessage = 'Building 3MF project…';
      notifyListeners();

      final modelPath = await _materializeProject(
        modelDirectory,
        projectSettings: projectSettings,
      );

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
      lastGcodePathsByPlate = result.gcodePathsByPlate;
      lastSelectedPlate = result.selectedPlate;
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

  Future<String> _materializeProject(
    Directory modelDirectory, {
    required Map<String, dynamic> projectSettings,
  }) async {
    await modelDirectory.create(recursive: true);
    final imported = sourceProject;
    if (imported != null) {
      final embedded = imported.projectSettings;
      final validEmbedded = _hasRequiredProjectSettings(embedded);
      final effectiveSettings = validEmbedded
          ? embedded
          : <String, dynamic>{
              ...projectSettings,
              ...embedded,
            };
      final replacements = validEmbedded
          ? const <String, Uint8List>{}
          : <String, Uint8List>{
              'Metadata/project_settings.config': Uint8List.fromList(
                utf8.encode(
                  const JsonEncoder.withIndent(' ').convert(effectiveSettings),
                ),
              ),
            };
      final bytes = const ThreeMfWriter().repackWithBuildTransform(
        imported,
        _sourceProjectTransform,
        replacements: replacements,
      );
      final path =
          '${modelDirectory.path}${Platform.pathSeparator}project.3mf';
      await File(path).writeAsBytes(bytes, flush: true);
      return path;
    }

    final project = ThreeMfProject(
      objects: [ThreeMfProjectObject.fromMesh(mesh!)],
      plates: const [
        ThreeMfProjectPlate(
          name: 'Plate 1',
          instances: [ThreeMfPlateInstance(objectIndex: 0)],
        ),
      ],
      projectSettings: projectSettings,
      metadata: const {
        'QidiNewMorrax:ProjectBoundary': 'generated',
      },
    );
    return const ThreeMfProjectWriter().write(
      project,
      directory: modelDirectory,
    );
  }

  bool _hasRequiredProjectSettings(Map<String, dynamic> settings) =>
      settings['printer_settings_id'] != null &&
      settings['print_settings_id'] != null &&
      settings['filament_settings_id'] != null &&
      settings['nozzle_diameter'] != null;
}
