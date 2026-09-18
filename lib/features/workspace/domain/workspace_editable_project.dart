import '../../../core/geometry/point.dart';
import '../../../core/model_io/mesh.dart';
import '../../../core/model_io/three_mf_project_writer.dart';
import '../../../core/model_io/three_mf_transform.dart';

class WorkspaceEditableProject {
  WorkspaceEditableProject({
    required List<WorkspaceEditablePlate> plates,
    required List<WorkspaceEditableObject> objects,
  })  : plates = List.unmodifiable(plates),
        objects = List.unmodifiable(objects) {
    if (this.plates.isEmpty) {
      throw ArgumentError('Editable project must contain at least one plate.');
    }
    for (final object in this.objects) {
      if (object.plateIndex < 0 || object.plateIndex >= this.plates.length) {
        throw ArgumentError(
          'Object "${object.name}" references invalid plate '
          '${object.plateIndex}.',
        );
      }
    }
  }

  factory WorkspaceEditableProject.empty() => WorkspaceEditableProject(
        plates: const [WorkspaceEditablePlate(name: 'Plate 1')],
        objects: const [],
      );

  final List<WorkspaceEditablePlate> plates;
  final List<WorkspaceEditableObject> objects;

  WorkspaceEditableProject addPlate({String? name}) {
    final next = plates.length + 1;
    return WorkspaceEditableProject(
      plates: [
        ...plates,
        WorkspaceEditablePlate(
          name: name?.trim().isNotEmpty == true ? name!.trim() : 'Plate $next',
        ),
      ],
      objects: objects,
    );
  }

  WorkspaceEditableProject renamePlate(int plateIndex, String name) {
    _checkPlate(plateIndex);
    final normalized = name.trim();
    if (normalized.isEmpty) return this;
    return WorkspaceEditableProject(
      plates: [
        for (var i = 0; i < plates.length; i++)
          i == plateIndex ? plates[i].copyWith(name: normalized) : plates[i],
      ],
      objects: objects,
    );
  }

  WorkspaceEditableProject setPlateLocked(int plateIndex, bool locked) {
    _checkPlate(plateIndex);
    return WorkspaceEditableProject(
      plates: [
        for (var i = 0; i < plates.length; i++)
          i == plateIndex ? plates[i].copyWith(locked: locked) : plates[i],
      ],
      objects: objects,
    );
  }

  WorkspaceEditableProject removePlate(
    int plateIndex, {
    int fallbackPlateIndex = 0,
  }) {
    _checkPlate(plateIndex);
    if (plates.length == 1) {
      throw StateError('The last plate cannot be removed.');
    }
    if (fallbackPlateIndex == plateIndex ||
        fallbackPlateIndex < 0 ||
        fallbackPlateIndex >= plates.length) {
      fallbackPlateIndex = plateIndex == 0 ? 1 : 0;
    }

    int remap(int oldIndex) {
      final target = oldIndex == plateIndex ? fallbackPlateIndex : oldIndex;
      return target > plateIndex ? target - 1 : target;
    }

    return WorkspaceEditableProject(
      plates: [
        for (var i = 0; i < plates.length; i++)
          if (i != plateIndex) plates[i],
      ],
      objects: [
        for (final object in objects)
          object.copyWith(plateIndex: remap(object.plateIndex)),
      ],
    );
  }

  WorkspaceEditableProject addObject(
    Mesh mesh, {
    required int plateIndex,
    String? name,
    int extruder = 1,
    Map<String, String> settings = const {},
  }) {
    _checkPlate(plateIndex);
    return WorkspaceEditableProject(
      plates: plates,
      objects: [
        ...objects,
        WorkspaceEditableObject(
          name: name?.trim().isNotEmpty == true ? name!.trim() : mesh.name,
          mesh: mesh,
          plateIndex: plateIndex,
          extruder: extruder,
          settings: settings,
        ),
      ],
    );
  }

  WorkspaceEditableProject removeObject(int objectIndex) {
    _checkObject(objectIndex);
    return WorkspaceEditableProject(
      plates: plates,
      objects: [
        for (var i = 0; i < objects.length; i++)
          if (i != objectIndex) objects[i],
      ],
    );
  }

  WorkspaceEditableProject updateObject(
    int objectIndex, {
    String? name,
    int? plateIndex,
    int? extruder,
    Map<String, String>? settings,
  }) {
    _checkObject(objectIndex);
    if (plateIndex != null) _checkPlate(plateIndex);
    final object = objects[objectIndex];
    return _replaceObject(
      objectIndex,
      object.copyWith(
        name: name,
        plateIndex: plateIndex,
        extruder: extruder,
        settings: settings,
      ),
    );
  }

  WorkspaceEditableProject transformObject(
    int objectIndex, {
    Point3 translation = const Point3(0, 0, 0),
    Point3 scale = const Point3(1, 1, 1),
    Point3 rotationDegrees = const Point3(0, 0, 0),
  }) {
    _checkObject(objectIndex);
    final object = objects[objectIndex];
    return _replaceObject(
      objectIndex,
      object.copyWith(
        mesh: object.mesh.transformed(
          translation: translation,
          scale: scale,
          rotationDegrees: rotationDegrees,
        ),
      ),
    );
  }

  List<int> objectIndicesForPlate(int plateIndex) {
    _checkPlate(plateIndex);
    return [
      for (var i = 0; i < objects.length; i++)
        if (objects[i].plateIndex == plateIndex) i,
    ];
  }

  Mesh? mergedMeshForPlate(int plateIndex) {
    final indices = objectIndicesForPlate(plateIndex);
    if (indices.isEmpty) return null;
    return Mesh(
      name: plates[plateIndex].name,
      triangles: [
        for (final index in indices) ...objects[index].mesh.triangles,
      ],
    );
  }

  ThreeMfProject toThreeMfProject({
    required Map<String, dynamic> projectSettings,
    required ThreeMfTransform workspaceToPrinter,
  }) {
    return ThreeMfProject(
      objects: [
        for (final object in objects)
          ThreeMfProjectObject(
            name: object.name,
            volumes: [
              ThreeMfProjectVolume(
                name: object.name,
                mesh: object.mesh,
              ),
            ],
            instances: [
              ThreeMfProjectInstance(transform: workspaceToPrinter),
            ],
            settings: {
              'extruder': object.extruder.toString(),
              ...object.settings,
            },
          ),
      ],
      plates: [
        for (var plateIndex = 0; plateIndex < plates.length; plateIndex++)
          ThreeMfProjectPlate(
            name: plates[plateIndex].name,
            locked: plates[plateIndex].locked,
            settings: plates[plateIndex].settings,
            instances: [
              for (var objectIndex = 0;
                  objectIndex < objects.length;
                  objectIndex++)
                if (objects[objectIndex].plateIndex == plateIndex)
                  ThreeMfPlateInstance(objectIndex: objectIndex),
            ],
          ),
      ],
      projectSettings: projectSettings,
      metadata: const {
        'QidiNewMorrax:ProjectBoundary': 'editable-generated',
      },
    );
  }

  WorkspaceEditableProject _replaceObject(
    int index,
    WorkspaceEditableObject replacement,
  ) =>
      WorkspaceEditableProject(
        plates: plates,
        objects: [
          for (var i = 0; i < objects.length; i++)
            i == index ? replacement : objects[i],
        ],
      );

  void _checkPlate(int index) {
    if (index < 0 || index >= plates.length) {
      throw RangeError.index(index, plates, 'plateIndex');
    }
  }

  void _checkObject(int index) {
    if (index < 0 || index >= objects.length) {
      throw RangeError.index(index, objects, 'objectIndex');
    }
  }
}

class WorkspaceEditablePlate {
  const WorkspaceEditablePlate({
    required this.name,
    this.locked = false,
    this.settings = const {},
  });

  final String name;
  final bool locked;
  final Map<String, String> settings;

  WorkspaceEditablePlate copyWith({
    String? name,
    bool? locked,
    Map<String, String>? settings,
  }) =>
      WorkspaceEditablePlate(
        name: name ?? this.name,
        locked: locked ?? this.locked,
        settings: Map.unmodifiable(settings ?? this.settings),
      );
}

class WorkspaceEditableObject {
  WorkspaceEditableObject({
    required this.name,
    required this.mesh,
    required this.plateIndex,
    this.extruder = 1,
    Map<String, String> settings = const {},
  }) : settings = Map.unmodifiable(settings);

  final String name;
  final Mesh mesh;
  final int plateIndex;
  final int extruder;
  final Map<String, String> settings;

  WorkspaceEditableObject copyWith({
    String? name,
    Mesh? mesh,
    int? plateIndex,
    int? extruder,
    Map<String, String>? settings,
  }) =>
      WorkspaceEditableObject(
        name: name ?? this.name,
        mesh: mesh ?? this.mesh,
        plateIndex: plateIndex ?? this.plateIndex,
        extruder: extruder ?? this.extruder,
        settings: settings ?? this.settings,
      );
}
