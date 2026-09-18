import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'mesh.dart';
import 'three_mf_transform.dart';

class ThreeMfProject {
  const ThreeMfProject({
    required this.objects,
    this.plates = const [],
    this.projectSettings = const {},
    this.metadata = const {},
  });

  final List<ThreeMfProjectObject> objects;
  final List<ThreeMfProjectPlate> plates;

  /// Orca/Bambu project_settings.config payload. The runtime normally applies
  /// the selected QIDI presets via CLI, but imported/project-level overrides
  /// can live here without flattening them into machine/process presets.
  final Map<String, dynamic> projectSettings;
  final Map<String, String> metadata;
}

class ThreeMfProjectObject {
  const ThreeMfProjectObject({
    required this.name,
    required this.volumes,
    this.instances = const [ThreeMfProjectInstance()],
    this.settings = const {},
  });

  factory ThreeMfProjectObject.fromMesh(
    Mesh mesh, {
    int extruder = 1,
    ThreeMfTransform transform = ThreeMfTransform.identity,
  }) {
    return ThreeMfProjectObject(
      name: mesh.name,
      volumes: [
        ThreeMfProjectVolume(
          name: mesh.name,
          mesh: mesh,
        ),
      ],
      instances: [ThreeMfProjectInstance(transform: transform)],
      settings: {'extruder': '$extruder'},
    );
  }

  final String name;
  final List<ThreeMfProjectVolume> volumes;
  final List<ThreeMfProjectInstance> instances;
  final Map<String, String> settings;
}

class ThreeMfProjectVolume {
  const ThreeMfProjectVolume({
    required this.name,
    required this.mesh,
    this.type = 'normal_part',
    this.settings = const {},
    this.facets = const {},
    this.transform = ThreeMfTransform.identity,
  });

  final String name;
  final Mesh mesh;

  /// Orca ModelVolume::type_to_string() value (for example normal_part,
  /// modifier, support_enforcer or support_blocker).
  final String type;
  final Map<String, String> settings;
  final Map<int, ThreeMfFacetMetadata> facets;
  final ThreeMfTransform transform;
}

class ThreeMfFacetMetadata {
  const ThreeMfFacetMetadata({
    this.supports,
    this.seam,
    this.color,
    this.fuzzySkin,
  });

  final String? supports;
  final String? seam;
  final String? color;
  final String? fuzzySkin;
}

class ThreeMfProjectInstance {
  const ThreeMfProjectInstance({
    this.transform = ThreeMfTransform.identity,
    this.printable = true,
  });

  final ThreeMfTransform transform;
  final bool printable;
}

class ThreeMfProjectPlate {
  const ThreeMfProjectPlate({
    required this.name,
    required this.instances,
    this.settings = const {},
    this.locked = false,
  });

  final String name;
  final List<ThreeMfPlateInstance> instances;
  final Map<String, String> settings;
  final bool locked;
}

class ThreeMfPlateInstance {
  const ThreeMfPlateInstance({
    required this.objectIndex,
    this.instanceIndex = 0,
    this.identifyId,
  });

  final int objectIndex;
  final int instanceIndex;
  final int? identifyId;
}

/// Writes the Orca/Bambu-flavoured 3MF boundary used between Flutter and the
/// external slicer. Geometry remains standard 3MF while model_settings.config
/// carries volume types, per-object settings and plate membership.
class ThreeMfProjectWriter {
  const ThreeMfProjectWriter();

  Uint8List encode(ThreeMfProject project) {
    if (project.objects.isEmpty) {
      throw ArgumentError.value(project.objects, 'objects', 'must not be empty');
    }
    for (final object in project.objects) {
      if (object.volumes.isEmpty) {
        throw ArgumentError('3MF project object "${object.name}" has no volumes');
      }
      if (object.instances.isEmpty) {
        throw ArgumentError(
          '3MF project object "${object.name}" has no instances',
        );
      }
    }

    final ids = _allocateIds(project);
    final archive = Archive()
      ..addFile(
        ArchiveFile.bytes(
          '[Content_Types].xml',
          Uint8List.fromList(utf8.encode(_contentTypes)),
        ),
      )
      ..addFile(
        ArchiveFile.bytes(
          '_rels/.rels',
          Uint8List.fromList(utf8.encode(_relationships)),
        ),
      )
      ..addFile(
        ArchiveFile.bytes(
          '3D/3dmodel.model',
          Uint8List.fromList(utf8.encode(_modelXml(project, ids))),
        ),
      )
      ..addFile(
        ArchiveFile.bytes(
          '3D/_rels/3dmodel.model.rels',
          Uint8List.fromList(
            utf8.encode(_modelRelationships(project)),
          ),
        ),
      )
      ..addFile(
        ArchiveFile.bytes(
          'Metadata/model_settings.config',
          Uint8List.fromList(utf8.encode(_modelSettingsXml(project, ids))),
        ),
      );

    for (var objectIndex = 0; objectIndex < project.objects.length; objectIndex++) {
      archive.addFile(
        ArchiveFile.bytes(
          _subModelPath(objectIndex),
          Uint8List.fromList(
            utf8.encode(
              _subModelXml(
                project.objects[objectIndex],
                ids[objectIndex],
                objectIndex,
              ),
            ),
          ),
        ),
      );
    }

    if (project.projectSettings.isNotEmpty) {
      archive.addFile(
        ArchiveFile.bytes(
          'Metadata/project_settings.config',
          Uint8List.fromList(
            utf8.encode(
              const JsonEncoder.withIndent('  ').convert(
                project.projectSettings,
              ),
            ),
          ),
        ),
      );
    }
    return ZipEncoder().encodeBytes(archive);
  }

  Future<String> write(
    ThreeMfProject project, {
    required Directory directory,
    String fileName = 'project.3mf',
  }) async {
    await directory.create(recursive: true);
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(encode(project), flush: true);
    return file.path;
  }

  List<_ObjectIds> _allocateIds(ThreeMfProject project) {
    var nextId = 1;
    return [
      for (final object in project.objects)
        (() {
          final volumeIds = <int>[
            for (var i = 0; i < object.volumes.length; i++) nextId++,
          ];
          return _ObjectIds(volumeIds, nextId++);
        })(),
    ];
  }

  String _modelXml(ThreeMfProject project, List<_ObjectIds> ids) {
    final out = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<model unit="millimeter" xml:lang="en-US" '
        'xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02" '
        'xmlns:BambuStudio="http://schemas.bambulab.com/package/2021" '
        'xmlns:p="http://schemas.microsoft.com/3dmanufacturing/production/2015/06" '
        'requiredextensions="p">',
      )
      ..writeln(
        ' <metadata name="Application">BambuStudio-02.06.00.51</metadata>',
      )
      ..writeln(' <metadata name="OrcaSlicer">2.4.2</metadata>')
      ..writeln(' <metadata name="BambuStudio:3mfVersion">1</metadata>');
    for (final entry in project.metadata.entries) {
      out.writeln(
        ' <metadata name="${_xml(entry.key)}">${_xml(entry.value)}</metadata>',
      );
    }
    out.writeln(' <resources>');

    for (var objectIndex = 0;
        objectIndex < project.objects.length;
        objectIndex++) {
      final object = project.objects[objectIndex];
      final objectIds = ids[objectIndex];
      out
        ..writeln(
          '  <object id="${objectIds.parentId}" '
          'p:UUID="${_parentUuid(objectIndex)}" type="model">',
        )
        ..writeln('   <components>');
      for (var volumeIndex = 0;
          volumeIndex < object.volumes.length;
          volumeIndex++) {
        final volume = object.volumes[volumeIndex];
        out.writeln(
          '    <component p:path="/${_subModelPath(objectIndex)}" '
          'objectid="${objectIds.volumeIds[volumeIndex]}" '
          'p:UUID="${_componentUuid(objectIndex, volumeIndex)}" '
          'transform="${volume.transform.to3mfString()}"/>',
        );
      }
      out
        ..writeln('   </components>')
        ..writeln('  </object>');
    }

    out
      ..writeln(' </resources>')
      ..writeln(' <build p:UUID="2c7c17d8-22b5-4d84-8835-1976022ea369">');
    for (var objectIndex = 0;
        objectIndex < project.objects.length;
        objectIndex++) {
      final object = project.objects[objectIndex];
      final parentId = ids[objectIndex].parentId;
      for (final instance in object.instances) {
        out.writeln(
          '  <item objectid="$parentId" '
          'p:UUID="${_buildItemUuid(parentId)}" '
          'transform="${instance.transform.to3mfString()}" '
          'printable="${instance.printable ? 1 : 0}" auto_drop="0"/>',
        );
      }
    }
    out
      ..writeln(' </build>')
      ..writeln('</model>');
    return out.toString();
  }

  String _subModelXml(
    ThreeMfProjectObject object,
    _ObjectIds objectIds,
    int objectIndex,
  ) {
    final out = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<model unit="millimeter" xml:lang="en-US" '
        'xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02" '
        'xmlns:BambuStudio="http://schemas.bambulab.com/package/2021" '
        'xmlns:p="http://schemas.microsoft.com/3dmanufacturing/production/2015/06" '
        'requiredextensions="p">',
      )
      ..writeln(' <metadata name="BambuStudio:3mfVersion">1</metadata>')
      ..writeln(' <resources>');
    for (var volumeIndex = 0;
        volumeIndex < object.volumes.length;
        volumeIndex++) {
      _writeVolumeMesh(
        out,
        object.volumes[volumeIndex],
        objectIds.volumeIds[volumeIndex],
        _volumeUuid(objectIndex, volumeIndex),
      );
    }
    out
      ..writeln(' </resources>')
      ..writeln(' <build/>')
      ..writeln('</model>');
    return out.toString();
  }

  void _writeVolumeMesh(
    StringBuffer out,
    ThreeMfProjectVolume volume,
    int objectId,
    String uuid,
  ) {
    out
      ..writeln(
        '  <object id="$objectId" p:UUID="$uuid" type="model">',
      )
      ..writeln('   <mesh>')
      ..writeln('    <vertices>');
    var vertexIndex = 0;
    final triangleIndices = <(int, int, int)>[];
    for (final triangle in volume.mesh.triangles) {
      final a = vertexIndex++;
      final b = vertexIndex++;
      final c = vertexIndex++;
      triangleIndices.add((a, b, c));
      for (final point in [triangle.a, triangle.b, triangle.c]) {
        out.writeln(
          '     <vertex x="${_number(point.x)}" y="${_number(point.y)}" '
          'z="${_number(point.z)}"/>',
        );
      }
    }
    out
      ..writeln('    </vertices>')
      ..writeln('    <triangles>');
    for (var index = 0; index < triangleIndices.length; index++) {
      final t = triangleIndices[index];
      final facet = volume.facets[index];
      final attrs = StringBuffer();
      if (facet?.supports != null) {
        attrs.write(' paint_supports="${_xml(facet!.supports!)}"');
      }
      if (facet?.seam != null) {
        attrs.write(' paint_seam="${_xml(facet!.seam!)}"');
      }
      if (facet?.color != null) {
        attrs.write(' paint_color="${_xml(facet!.color!)}"');
      }
      if (facet?.fuzzySkin != null) {
        attrs.write(' paint_fuzzy_skin="${_xml(facet!.fuzzySkin!)}"');
      }
      out.writeln(
        '     <triangle v1="${t.$1}" v2="${t.$2}" '
        'v3="${t.$3}"$attrs/>',
      );
    }
    out
      ..writeln('    </triangles>')
      ..writeln('   </mesh>')
      ..writeln('  </object>');
  }

  String _modelSettingsXml(ThreeMfProject project, List<_ObjectIds> ids) {
    final out = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<config>');

    for (var objectIndex = 0;
        objectIndex < project.objects.length;
        objectIndex++) {
      final object = project.objects[objectIndex];
      final objectIds = ids[objectIndex];
      out
        ..writeln('  <object id="${objectIds.parentId}">')
        ..writeln(
          '    <metadata key="name" value="${_xml(object.name)}"/>',
        );
      for (final setting in object.settings.entries) {
        out.writeln(
          '    <metadata key="${_xml(setting.key)}" '
          'value="${_xml(setting.value)}"/>',
        );
      }
      for (var volumeIndex = 0;
          volumeIndex < object.volumes.length;
          volumeIndex++) {
        final volume = object.volumes[volumeIndex];
        out
          ..writeln(
            '    <part id="${objectIds.volumeIds[volumeIndex]}" '
            'subtype="${_xml(volume.type)}">',
          )
          ..writeln(
            '      <metadata key="name" value="${_xml(volume.name)}"/>',
          )
          ..writeln(
            '      <metadata key="matrix" '
            'value="1 0 0 0 0 1 0 0 0 0 1 0 0 0 0 1"/>',
          );
        for (final setting in volume.settings.entries) {
          out.writeln(
            '      <metadata key="${_xml(setting.key)}" '
            'value="${_xml(setting.value)}"/>',
          );
        }
        out.writeln(
          '      <mesh_stat edges_fixed="0" degenerate_facets="0" '
          'facets_removed="0" facets_reversed="0" backwards_edges="0"/>',
        );
        out.writeln('    </part>');
      }
      out.writeln('  </object>');
    }

    final plates = project.plates.isEmpty
        ? [
            ThreeMfProjectPlate(
              name: 'Plate 1',
              instances: [
                for (var objectIndex = 0;
                    objectIndex < project.objects.length;
                    objectIndex++)
                  for (var instanceIndex = 0;
                      instanceIndex <
                          project.objects[objectIndex].instances.length;
                      instanceIndex++)
                    ThreeMfPlateInstance(
                      objectIndex: objectIndex,
                      instanceIndex: instanceIndex,
                    ),
              ],
            ),
          ]
        : project.plates;

    var identify = 1;
    for (var plateIndex = 0; plateIndex < plates.length; plateIndex++) {
      final plate = plates[plateIndex];
      out
        ..writeln('  <plate>')
        ..writeln(
          '    <metadata key="plater_id" value="${plateIndex + 1}"/>',
        )
        ..writeln(
          '    <metadata key="plater_name" value="${_xml(plate.name)}"/>',
        )
        ..writeln(
          '    <metadata key="locked" value="${plate.locked}"/>',
        );
      for (final setting in plate.settings.entries) {
        out.writeln(
          '    <metadata key="${_xml(setting.key)}" '
          'value="${_xml(setting.value)}"/>',
        );
      }
      for (final placement in plate.instances) {
        if (placement.objectIndex < 0 ||
            placement.objectIndex >= project.objects.length) {
          throw RangeError.index(
            placement.objectIndex,
            project.objects,
            'objectIndex',
          );
        }
        final object = project.objects[placement.objectIndex];
        if (placement.instanceIndex < 0 ||
            placement.instanceIndex >= object.instances.length) {
          throw RangeError.index(
            placement.instanceIndex,
            object.instances,
            'instanceIndex',
          );
        }
        out
          ..writeln('    <model_instance>')
          ..writeln(
            '      <metadata key="object_id" '
            'value="${ids[placement.objectIndex].parentId}"/>',
          )
          ..writeln(
            '      <metadata key="instance_id" '
            'value="${placement.instanceIndex}"/>',
          )
          ..writeln(
            '      <metadata key="identify_id" '
            'value="${placement.identifyId ?? identify++}"/>',
          )
          ..writeln('    </model_instance>');
      }
      out.writeln('  </plate>');
    }

    out
      ..writeln('  <assemble>')
      ..writeln('  </assemble>')
      ..writeln('</config>');
    return out.toString();
  }

  static String _number(double value) {
    if (value.abs() < 1e-15) return '0';
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 1e-12) return rounded.toInt().toString();
    return value.toStringAsPrecision(17);
  }

  static String _xml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  static const _contentTypes =
      '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\n'
      ' <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\n'
      ' <Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/>\n'
      ' <Default Extension="config" ContentType="application/octet-stream"/>\n'
      '</Types>\n';

  static const _relationships =
      '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
      ' <Relationship Target="/3D/3dmodel.model" Id="rel0" '
      'Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/>\n'
      '</Relationships>\n';
}

class _ObjectIds {
  const _ObjectIds(this.volumeIds, this.parentId);
  final List<int> volumeIds;
  final int parentId;
}
