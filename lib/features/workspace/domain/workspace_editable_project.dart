import '../../../core/geometry/point.dart';
import '../../../core/model_io/mesh.dart';
import '../../../core/model_io/three_mf_project_writer.dart';
import '../../../core/model_io/three_mf_transform.dart';

enum WorkspaceFacetPaintChannel {
  supports,
  seam,
  fuzzySkin,
}

enum WorkspaceFacetPaintState {
  enforcer,
  blocker,
}

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
      if (object.volumes.isEmpty) {
        throw ArgumentError('Object "${object.name}" must contain a volume.');
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
    final objectName =
        name?.trim().isNotEmpty == true ? name!.trim() : mesh.name;
    return WorkspaceEditableProject(
      plates: plates,
      objects: [
        ...objects,
        WorkspaceEditableObject.fromMesh(
          mesh,
          name: objectName,
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

  WorkspaceEditableProject addVolume(
    int objectIndex,
    Mesh mesh, {
    String? name,
    String type = WorkspaceEditableVolume.normalPart,
    Map<String, String> settings = const {},
    Map<int, ThreeMfFacetMetadata> facets = const {},
  }) {
    _checkObject(objectIndex);
    WorkspaceEditableVolume.validateType(type);
    final object = objects[objectIndex];
    final volume = WorkspaceEditableVolume(
      name: name?.trim().isNotEmpty == true ? name!.trim() : mesh.name,
      mesh: mesh,
      type: type,
      settings: settings,
      facets: facets,
    );
    return _replaceObject(
      objectIndex,
      object.copyWith(volumes: [...object.volumes, volume]),
    );
  }

  WorkspaceEditableProject updateVolume(
    int objectIndex,
    int volumeIndex, {
    String? name,
    String? type,
    Map<String, String>? settings,
    Map<int, ThreeMfFacetMetadata>? facets,
  }) {
    _checkVolume(objectIndex, volumeIndex);
    if (type != null) WorkspaceEditableVolume.validateType(type);
    final object = objects[objectIndex];
    final volume = object.volumes[volumeIndex];
    return _replaceObject(
      objectIndex,
      object.copyWith(
        volumes: [
          for (var i = 0; i < object.volumes.length; i++)
            i == volumeIndex
                ? volume.copyWith(
                    name: name,
                    type: type,
                    settings: settings,
                    facets: facets,
                  )
                : object.volumes[i],
        ],
      ),
    );
  }

  WorkspaceEditableProject paintFacets(
    int objectIndex,
    int volumeIndex,
    Iterable<int> triangleIndices, {
    required WorkspaceFacetPaintChannel channel,
    required WorkspaceFacetPaintState state,
  }) {
    _checkVolume(objectIndex, volumeIndex);
    if (channel == WorkspaceFacetPaintChannel.fuzzySkin &&
        state == WorkspaceFacetPaintState.blocker) {
      throw ArgumentError(
        'Fuzzy-skin paint only supports the enabled/enforcer state.',
      );
    }

    final object = objects[objectIndex];
    final volume = object.volumes[volumeIndex];
    if (volume.type != WorkspaceEditableVolume.normalPart) {
      throw StateError(
        'Orca facet painting is only defined for normal_part volumes.',
      );
    }
    final facets = <int, ThreeMfFacetMetadata>{...volume.facets};
    final encoded = state == WorkspaceFacetPaintState.enforcer ? '4' : '8';

    for (final triangleIndex in triangleIndices.toSet()) {
      _checkTriangle(volume, triangleIndex);
      final current = facets[triangleIndex] ?? const ThreeMfFacetMetadata();
      facets[triangleIndex] = switch (channel) {
        WorkspaceFacetPaintChannel.supports => ThreeMfFacetMetadata(
            supports: encoded,
            seam: current.seam,
            color: current.color,
            fuzzySkin: current.fuzzySkin,
          ),
        WorkspaceFacetPaintChannel.seam => ThreeMfFacetMetadata(
            supports: current.supports,
            seam: encoded,
            color: current.color,
            fuzzySkin: current.fuzzySkin,
          ),
        WorkspaceFacetPaintChannel.fuzzySkin => ThreeMfFacetMetadata(
            supports: current.supports,
            seam: current.seam,
            color: current.color,
            fuzzySkin: encoded,
          ),
      };
    }

    return updateVolume(
      objectIndex,
      volumeIndex,
      facets: facets,
    );
  }

  WorkspaceEditableProject paintMaterialFacets(
    int objectIndex,
    int volumeIndex,
    Iterable<int> triangleIndices, {
    required int filamentSlot,
  }) {
    _checkVolume(objectIndex, volumeIndex);
    final object = objects[objectIndex];
    final volume = object.volumes[volumeIndex];
    if (volume.type != WorkspaceEditableVolume.normalPart) {
      throw StateError(
        'Orca material facet painting is only defined for normal_part volumes.',
      );
    }
    final encoded = encodeMaterialFacetSlot(filamentSlot);
    final facets = <int, ThreeMfFacetMetadata>{...volume.facets};

    for (final triangleIndex in triangleIndices.toSet()) {
      _checkTriangle(volume, triangleIndex);
      final current = facets[triangleIndex] ?? const ThreeMfFacetMetadata();
      facets[triangleIndex] = ThreeMfFacetMetadata(
        supports: current.supports,
        seam: current.seam,
        color: encoded,
        fuzzySkin: current.fuzzySkin,
      );
    }

    return updateVolume(
      objectIndex,
      volumeIndex,
      facets: facets,
    );
  }

  WorkspaceEditableProject clearMaterialFacetPaint(
    int objectIndex,
    int volumeIndex,
    Iterable<int> triangleIndices,
  ) {
    _checkVolume(objectIndex, volumeIndex);
    final object = objects[objectIndex];
    final volume = object.volumes[volumeIndex];
    if (volume.type != WorkspaceEditableVolume.normalPart) {
      throw StateError(
        'Orca material facet painting is only defined for normal_part volumes.',
      );
    }
    final facets = <int, ThreeMfFacetMetadata>{...volume.facets};

    for (final triangleIndex in triangleIndices.toSet()) {
      _checkTriangle(volume, triangleIndex);
      final current = facets[triangleIndex];
      if (current == null) continue;
      final updated = ThreeMfFacetMetadata(
        supports: current.supports,
        seam: current.seam,
        fuzzySkin: current.fuzzySkin,
      );
      if (updated.supports == null &&
          updated.seam == null &&
          updated.fuzzySkin == null) {
        facets.remove(triangleIndex);
      } else {
        facets[triangleIndex] = updated;
      }
    }

    return updateVolume(
      objectIndex,
      volumeIndex,
      facets: facets,
    );
  }

  static String encodeMaterialFacetSlot(int filamentSlot) {
    if (filamentSlot < 1 || filamentSlot > 16) {
      throw RangeError.range(filamentSlot, 1, 16, 'filamentSlot');
    }
    if (filamentSlot == 1) return '4';
    if (filamentSlot == 2) return '8';
    return '${(filamentSlot - 3).toRadixString(16).toUpperCase()}C';
  }

  static int decodeMaterialFacetSlot(String encoded) {
    for (var slot = 1; slot <= 16; slot++) {
      if (encodeMaterialFacetSlot(slot) == encoded) return slot;
    }
    throw FormatException('Unsupported Orca material facet code: $encoded');
  }

  WorkspaceEditableProject clearFacetPaint(
    int objectIndex,
    int volumeIndex,
    Iterable<int> triangleIndices, {
    required WorkspaceFacetPaintChannel channel,
  }) {
    _checkVolume(objectIndex, volumeIndex);
    final object = objects[objectIndex];
    final volume = object.volumes[volumeIndex];
    if (volume.type != WorkspaceEditableVolume.normalPart) {
      throw StateError(
        'Orca facet painting is only defined for normal_part volumes.',
      );
    }
    final facets = <int, ThreeMfFacetMetadata>{...volume.facets};

    for (final triangleIndex in triangleIndices.toSet()) {
      _checkTriangle(volume, triangleIndex);
      final current = facets[triangleIndex];
      if (current == null) continue;

      final updated = switch (channel) {
        WorkspaceFacetPaintChannel.supports => ThreeMfFacetMetadata(
            seam: current.seam,
            color: current.color,
            fuzzySkin: current.fuzzySkin,
          ),
        WorkspaceFacetPaintChannel.seam => ThreeMfFacetMetadata(
            supports: current.supports,
            color: current.color,
            fuzzySkin: current.fuzzySkin,
          ),
        WorkspaceFacetPaintChannel.fuzzySkin => ThreeMfFacetMetadata(
            supports: current.supports,
            seam: current.seam,
            color: current.color,
          ),
      };
      if (updated.supports == null &&
          updated.seam == null &&
          updated.color == null &&
          updated.fuzzySkin == null) {
        facets.remove(triangleIndex);
      } else {
        facets[triangleIndex] = updated;
      }
    }

    return updateVolume(
      objectIndex,
      volumeIndex,
      facets: facets,
    );
  }

  WorkspaceEditableProject removeVolume(int objectIndex, int volumeIndex) {
    _checkVolume(objectIndex, volumeIndex);
    final object = objects[objectIndex];
    if (object.volumes.length == 1) {
      throw StateError('The last volume of an object cannot be removed.');
    }
    return _replaceObject(
      objectIndex,
      object.copyWith(
        volumes: [
          for (var i = 0; i < object.volumes.length; i++)
            if (i != volumeIndex) object.volumes[i],
        ],
      ),
    );
  }

  WorkspaceEditableProject transformVolume(
    int objectIndex,
    int volumeIndex, {
    Point3 translation = const Point3(0, 0, 0),
    Point3 scale = const Point3(1, 1, 1),
    Point3 rotationDegrees = const Point3(0, 0, 0),
  }) {
    _checkVolume(objectIndex, volumeIndex);
    final object = objects[objectIndex];
    final volume = object.volumes[volumeIndex];
    return _replaceObject(
      objectIndex,
      object.copyWith(
        volumes: [
          for (var i = 0; i < object.volumes.length; i++)
            i == volumeIndex
                ? volume.copyWith(
                    mesh: volume.mesh.transformed(
                      translation: translation,
                      scale: scale,
                      rotationDegrees: rotationDegrees,
                    ),
                  )
                : object.volumes[i],
        ],
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
        volumes: [
          for (final volume in object.volumes)
            volume.copyWith(
              mesh: volume.mesh.transformed(
                translation: translation,
                scale: scale,
                rotationDegrees: rotationDegrees,
              ),
            ),
        ],
      ),
    );
  }

  WorkspaceEditableProject remapFilamentSlotsAfterRemoval(
    int removedSlot, {
    int replacementSlot = 1,
  }) {
    if (removedSlot < 1 || removedSlot > 16) {
      throw RangeError.range(removedSlot, 1, 16, 'removedSlot');
    }
    if (replacementSlot < 1 || replacementSlot > 16) {
      throw RangeError.range(replacementSlot, 1, 16, 'replacementSlot');
    }

    int remapSlot(int slot) {
      if (slot == removedSlot) return replacementSlot;
      if (slot > removedSlot) return slot - 1;
      return slot;
    }

    return WorkspaceEditableProject(
      plates: plates,
      objects: [
        for (final object in objects)
          object.copyWith(
            extruder: remapSlot(object.extruder),
            volumes: [
              for (final volume in object.volumes)
                volume.copyWith(
                  facets: {
                    for (final entry in volume.facets.entries)
                      entry.key: entry.value.color == null
                          ? entry.value
                          : ThreeMfFacetMetadata(
                              supports: entry.value.supports,
                              seam: entry.value.seam,
                              color: encodeMaterialFacetSlot(
                                remapSlot(
                                  decodeMaterialFacetSlot(entry.value.color!),
                                ),
                              ),
                              fuzzySkin: entry.value.fuzzySkin,
                            ),
                  },
                ),
            ],
          ),
      ],
    );
  }

  void validateExtruderAssignments(int filamentSlotCount) {
    if (filamentSlotCount <= 0) {
      throw StateError('At least one materialized filament slot is required.');
    }
    for (final object in objects) {
      if (object.extruder < 1 || object.extruder > filamentSlotCount) {
        throw StateError(
          'Object "${object.name}" uses extruder ${object.extruder}, '
          'but only $filamentSlotCount filament slot'
          '${filamentSlotCount == 1 ? '' : 's'} are materialized.',
        );
      }
      for (final volume in object.volumes) {
        for (final facet in volume.facets.entries) {
          final color = facet.value.color;
          if (color == null) continue;
          final slot = decodeMaterialFacetSlot(color);
          if (slot > filamentSlotCount) {
            throw StateError(
              'Object "${object.name}" facet ${facet.key} uses material '
              'slot $slot, but only $filamentSlotCount filament slot'
              '${filamentSlotCount == 1 ? '' : 's'} are materialized.',
            );
          }
        }
      }
    }
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
              for (final volume in object.volumes)
                ThreeMfProjectVolume(
                  name: volume.name,
                  mesh: volume.mesh,
                  type: volume.type,
                  settings: volume.settings,
                  facets: volume.facets,
                  transform: volume.transform,
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

  void _checkVolume(int objectIndex, int volumeIndex) {
    _checkObject(objectIndex);
    final volumes = objects[objectIndex].volumes;
    if (volumeIndex < 0 || volumeIndex >= volumes.length) {
      throw RangeError.index(volumeIndex, volumes, 'volumeIndex');
    }
  }

  void _checkTriangle(WorkspaceEditableVolume volume, int triangleIndex) {
    final triangles = volume.mesh.triangles;
    if (triangleIndex < 0 || triangleIndex >= triangles.length) {
      throw RangeError.index(triangleIndex, triangles, 'triangleIndex');
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
    required List<WorkspaceEditableVolume> volumes,
    required this.plateIndex,
    this.extruder = 1,
    Map<String, String> settings = const {},
  })  : volumes = List.unmodifiable(volumes),
        settings = Map.unmodifiable(settings) {
    if (this.volumes.isEmpty) {
      throw ArgumentError('Editable object must contain at least one volume.');
    }
    if (extruder < 1) {
      throw ArgumentError.value(
        extruder,
        'extruder',
        'Orca extruder/material slot indices are 1-based.',
      );
    }
  }

  factory WorkspaceEditableObject.fromMesh(
    Mesh mesh, {
    required String name,
    required int plateIndex,
    int extruder = 1,
    Map<String, String> settings = const {},
  }) =>
      WorkspaceEditableObject(
        name: name,
        volumes: [
          WorkspaceEditableVolume(
            name: name,
            mesh: mesh,
          ),
        ],
        plateIndex: plateIndex,
        extruder: extruder,
        settings: settings,
      );

  final String name;
  final List<WorkspaceEditableVolume> volumes;
  final int plateIndex;
  final int extruder;
  final Map<String, String> settings;

  Mesh get mesh => Mesh(
        name: name,
        triangles: [
          for (final volume in volumes) ...volume.mesh.triangles,
        ],
      );

  WorkspaceEditableObject copyWith({
    String? name,
    List<WorkspaceEditableVolume>? volumes,
    int? plateIndex,
    int? extruder,
    Map<String, String>? settings,
  }) =>
      WorkspaceEditableObject(
        name: name ?? this.name,
        volumes: volumes ?? this.volumes,
        plateIndex: plateIndex ?? this.plateIndex,
        extruder: extruder ?? this.extruder,
        settings: settings ?? this.settings,
      );
}

class WorkspaceEditableVolume {
  WorkspaceEditableVolume({
    required this.name,
    required this.mesh,
    this.type = normalPart,
    Map<String, String> settings = const {},
    Map<int, ThreeMfFacetMetadata> facets = const {},
    this.transform = ThreeMfTransform.identity,
  })  : settings = Map.unmodifiable(settings),
        facets = Map.unmodifiable(facets) {
    validateType(type);
  }

  static const normalPart = 'normal_part';
  static const modifier = 'modifier';
  static const supportEnforcer = 'support_enforcer';
  static const supportBlocker = 'support_blocker';

  static const supportedTypes = <String>{
    normalPart,
    modifier,
    supportEnforcer,
    supportBlocker,
  };

  final String name;
  final Mesh mesh;
  final String type;
  final Map<String, String> settings;
  final Map<int, ThreeMfFacetMetadata> facets;
  final ThreeMfTransform transform;

  WorkspaceEditableVolume copyWith({
    String? name,
    Mesh? mesh,
    String? type,
    Map<String, String>? settings,
    Map<int, ThreeMfFacetMetadata>? facets,
    ThreeMfTransform? transform,
  }) =>
      WorkspaceEditableVolume(
        name: name ?? this.name,
        mesh: mesh ?? this.mesh,
        type: type ?? this.type,
        settings: settings ?? this.settings,
        facets: facets ?? this.facets,
        transform: transform ?? this.transform,
      );

  static void validateType(String type) {
    if (!supportedTypes.contains(type)) {
      throw ArgumentError.value(type, 'type', 'Unsupported Orca volume type');
    }
  }
}
