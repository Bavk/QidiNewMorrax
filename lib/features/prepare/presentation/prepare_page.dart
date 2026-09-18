import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/geometry/point.dart';
import '../../../core/model_io/mesh.dart';
import '../../../core/model_io/model_loader.dart';
import '../../../core/model_io/three_mf_parser.dart';
import '../../../core/profiles/profile_repository.dart';
import '../../workspace/application/workspace_controller.dart';

class PreparePage extends StatefulWidget {
  const PreparePage({super.key, required this.controller});

  final WorkspaceController controller;

  @override
  State<PreparePage> createState() => _PreparePageState();
}

class _PreparePageState extends State<PreparePage> {
  final profiles = ProfileRepository();
  List<QidiProfile> machines = const [];
  List<QidiProfile> allFilaments = const [];
  List<QidiProfile> allProcesses = const [];
  List<QidiProfile> filaments = const [];
  List<QidiProfile> processes = const [];
  QidiProfile? machine;
  QidiProfile? filament;
  QidiProfile? process;
  Mesh? mesh;
  ThreeMfPackage? sourceProject;
  String? modelPath;
  Object? error;
  bool loadingProfiles = true;
  bool loadingModel = false;
  String settingsCategory = 'quality';

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  void _publishSelection() {
    widget.controller.updateSelection(
      mesh: mesh,
      sourceModelPath: modelPath,
      machine: machine,
      process: process,
      filament: filament,
      sourceProject: sourceProject,
    );
  }

  Future<void> _loadProfiles() async {
    try {
      final all = await profiles.loadAll();
      machines = all.where((p) => p.type == 'machine').toList();
      allFilaments = all.where((p) => p.type == 'filament').toList();
      allProcesses = all.where((p) => p.type == 'process').toList();
      machine =
          machines.where((p) => p.name.contains('X-Plus 4')).firstOrNull ??
          machines.firstOrNull;
      _applyMachineCompatibility(resetSelection: true);
      _publishSelection();
    } catch (e) {
      error = e;
    } finally {
      loadingProfiles = false;
      if (mounted) setState(() {});
    }
  }

  void _selectMachine(QidiProfile? value) {
    setState(() {
      machine = value;
      _applyMachineCompatibility(resetSelection: true);
      _publishSelection();
    });
  }

  void _applyMachineCompatibility({required bool resetSelection}) {
    final printerName = machine?.name;
    filaments = allFilaments
        .where((p) => p.isCompatibleWithPrinter(printerName))
        .toList(growable: false);
    processes = allProcesses
        .where((p) => p.isCompatibleWithPrinter(printerName))
        .toList(growable: false);
    if (resetSelection || filament == null || !filaments.contains(filament)) {
      filament =
          filaments.where((p) => p.name.contains('PLA')).firstOrNull ??
          filaments.firstOrNull;
    }
    if (resetSelection || process == null || !processes.contains(process)) {
      process =
          processes.where((p) => p.name.contains('0.20')).firstOrNull ??
          processes.firstOrNull;
    }
  }

  Future<void> _openModel() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['stl', 'obj', '3mf', 'amf', 'xml'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    setState(() {
      loadingModel = true;
      error = null;
    });
    try {
      final bytes =
          file.bytes ??
          (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null) throw StateError('Could not read ${file.name}');
      if (file.name.toLowerCase().endsWith('.3mf')) {
        sourceProject = const ThreeMfParser().parsePackage(
          bytes,
          name: file.name,
        );
        mesh = sourceProject!.mesh;
      } else {
        sourceProject = null;
        mesh = const ModelLoader().load(bytes, file.name);
      }
      modelPath = file.path ?? file.name;
      _publishSelection();
    } catch (e) {
      error = e;
    } finally {
      loadingModel = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _transformModel(_TransformKind kind) async {
    final current = mesh;
    if (current == null) return;
    final result = await showDialog<Point3>(
      context: context,
      builder: (context) => _TransformDialog(kind: kind),
    );
    if (result == null) return;
    widget.controller.recordModelTransform(
      translation:
          kind == _TransformKind.move ? result : const Point3(0, 0, 0),
      rotationDegrees:
          kind == _TransformKind.rotate ? result : const Point3(0, 0, 0),
      scale: kind == _TransformKind.scale ? result : const Point3(1, 1, 1),
    );
    setState(() {
      mesh = switch (kind) {
        _TransformKind.move => current.transformed(translation: result),
        _TransformKind.rotate => current.transformed(rotationDegrees: result),
        _TransformKind.scale => current.transformed(scale: result),
      };
      _publishSelection();
    });
  }

  void _resetModelToBed() {
    final current = mesh;
    if (current == null) return;
    final bounds = current.bounds;
    if (bounds.isEmpty) return;
    final translation = Point3(
      -bounds.center.x,
      -bounds.center.y,
      -bounds.min.z,
    );
    widget.controller.recordModelTransform(translation: translation);
    setState(() {
      mesh = current.transformed(translation: translation);
      _publishSelection();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              SizedBox(height: 390, child: _settingsPanel()),
              const Divider(),
              Expanded(child: _workspace()),
            ],
          );
        }
        return Row(
          children: [
            SizedBox(width: 420, child: _settingsPanel()),
            const VerticalDivider(),
            Expanded(child: _workspace()),
          ],
        );
      },
    );
  }

  Widget _settingsPanel() {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
        children: [
          _SectionHeader(
            icon: Icons.print_outlined,
            title: 'Printer',
            trailing: IconButton(
              onPressed: loadingProfiles ? null : _loadProfiles,
              icon: const Icon(Icons.settings_outlined),
            ),
          ),
          const SizedBox(height: 8),
          _profileDropdown('Printer preset', machines, machine, _selectMachine),
          const SizedBox(height: 10),
          _ReadOnlyValue(
            label: 'Plate type',
            value: machine?.stringValue('bed_type') ?? 'Textured PEI Plate',
          ),
          const SizedBox(height: 18),
          const Divider(),
          const _SectionHeader(
            icon: Icons.inventory_2_outlined,
            title: 'Filament',
            trailing: IconButton(
              onPressed: null,
              icon: Icon(Icons.add),
              tooltip: 'Profile editing parity pending',
            ),
          ),
          const SizedBox(height: 8),
          _profileDropdown(
            'Filament preset',
            filaments,
            filament,
            (value) => setState(() {
              filament = value;
              _publishSelection();
            }),
          ),
          const SizedBox(height: 8),
          if (filament != null)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Chip(
                  label: Text(
                    filament!.stringValue('filament_type') ?? 'Material',
                  ),
                ),
                if (filament!.stringValue('nozzle_temperature') != null)
                  Chip(
                    label: Text(
                      '${filament!.stringValue('nozzle_temperature')} °C',
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 18),
          const Divider(),
          const _SectionHeader(
            icon: Icons.layers_outlined,
            title: 'Process',
            trailing: IconButton(
              onPressed: null,
              icon: Icon(Icons.tune),
              tooltip: 'Profile editing parity pending',
            ),
          ),
          const SizedBox(height: 8),
          _profileDropdown(
            'Process preset',
            processes,
            process,
            (value) => setState(() {
              process = value;
              _publishSelection();
            }),
          ),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'quality', label: Text('Quality')),
              ButtonSegment(value: 'strength', label: Text('Strength')),
              ButtonSegment(value: 'speed', label: Text('Speed')),
            ],
            selected: {settingsCategory},
            onSelectionChanged: (value) {
              if (value.isNotEmpty) {
                setState(() => settingsCategory = value.first);
              }
            },
          ),
          const SizedBox(height: 14),
          if (settingsCategory == 'quality') ...[
            _SettingLine(
              'Layer height',
              process?.stringValue('layer_height') ?? '0.20',
              'mm',
            ),
            _SettingLine(
              'Initial layer',
              process?.stringValue('initial_layer_print_height') ??
                  process?.stringValue('initial_layer_height') ??
                  '0.20',
              'mm',
            ),
          ] else if (settingsCategory == 'strength') ...[
            _SettingLine(
              'Wall loops',
              process?.stringValue('wall_loops') ?? '2',
              '',
            ),
            _SettingLine(
              'Sparse infill',
              process?.stringValue('sparse_infill_density') ?? '15%',
              '',
            ),
            _SettingLine(
              'Top shell layers',
              process?.stringValue('top_shell_layers') ?? '5',
              '',
            ),
            _SettingLine(
              'Bottom shell layers',
              process?.stringValue('bottom_shell_layers') ?? '3',
              '',
            ),
          ] else ...[
            _SettingLine(
              'Outer wall speed',
              process?.stringValue('outer_wall_speed') ?? '—',
              'mm/s',
            ),
            _SettingLine(
              'Inner wall speed',
              process?.stringValue('inner_wall_speed') ?? '—',
              'mm/s',
            ),
            _SettingLine(
              'Sparse infill speed',
              process?.stringValue('sparse_infill_speed') ?? '—',
              'mm/s',
            ),
            _SettingLine(
              'Travel speed',
              process?.stringValue('travel_speed') ?? '—',
              'mm/s',
            ),
          ],
        ],
      ),
    );
  }

  Widget _profileDropdown(
    String label,
    List<QidiProfile> values,
    QidiProfile? value,
    ValueChanged<QidiProfile?> onChanged,
  ) {
    final availableValue = value != null && values.contains(value)
        ? value
        : null;
    return DropdownButtonFormField<QidiProfile>(
      initialValue: availableValue,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final profile in values)
          DropdownMenuItem(
            value: profile,
            child: Text(profile.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: loadingProfiles ? null : onChanged,
    );
  }

  Widget _workspace() {
    final currentMesh = mesh;
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: Row(
            children: [
              const SizedBox(width: 10),
              IconButton(
                onPressed: _openModel,
                icon: const Icon(Icons.add_box_outlined),
                tooltip: 'Add model',
              ),
              const IconButton(
                onPressed: null,
                icon: Icon(Icons.grid_on_outlined),
                tooltip: 'Multi-plate parity pending',
              ),
              const VerticalDivider(indent: 8, endIndent: 8),
              IconButton(
                onPressed: currentMesh == null
                    ? null
                    : () => _transformModel(_TransformKind.move),
                icon: const Icon(Icons.open_with),
                tooltip: 'Move',
              ),
              IconButton(
                onPressed: currentMesh == null
                    ? null
                    : () => _transformModel(_TransformKind.rotate),
                icon: const Icon(Icons.rotate_right),
                tooltip: 'Rotate',
              ),
              IconButton(
                onPressed: currentMesh == null
                    ? null
                    : () => _transformModel(_TransformKind.scale),
                icon: const Icon(Icons.aspect_ratio),
                tooltip: 'Scale',
              ),
              const IconButton(
                onPressed: null,
                icon: Icon(Icons.content_cut),
                tooltip: 'Cut parity pending',
              ),
              IconButton(
                onPressed: currentMesh == null ? null : _resetModelToBed,
                icon: const Icon(Icons.vertical_align_bottom),
                tooltip: 'Center on bed',
              ),
              const Spacer(),
              if (loadingModel)
                const Padding(
                  padding: EdgeInsets.only(right: 14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: currentMesh == null
                    ? _EmptyPlate(onOpen: _openModel)
                    : MeshViewport(mesh: currentMesh),
              ),
              if (currentMesh != null)
                Positioned(
                  left: 14,
                  bottom: 14,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      child: Text(
                        '${currentMesh.name} • ${currentMesh.triangles.length} triangles • ${currentMesh.bounds.width.toStringAsFixed(1)} × ${currentMesh.bounds.depth.toStringAsFixed(1)} × ${currentMesh.bounds.height.toStringAsFixed(1)} mm',
                      ),
                    ),
                  ),
                ),
              if (error != null)
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Text(error.toString()),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.trailing,
  });
  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 19),
      const SizedBox(width: 8),
      Text(
        title,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      const Spacer(),
      if (trailing != null) trailing!,
    ],
  );
}

class _ReadOnlyValue extends StatelessWidget {
  const _ReadOnlyValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(labelText: label),
    child: Text(value),
  );
}

class _SettingLine extends StatelessWidget {
  const _SettingLine(this.label, this.value, this.unit);
  final String label, value, unit;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        SizedBox(
          width: 120,
          child: TextFormField(
            initialValue: value,
            readOnly: true,
            textAlign: TextAlign.end,
            decoration: InputDecoration(
              isDense: true,
              suffixText: unit.isEmpty ? null : unit,
            ),
          ),
        ),
      ],
    ),
  );
}

class _EmptyPlate extends StatelessWidget {
  const _EmptyPlate({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _BedPainter(),
    child: Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.view_in_ar_outlined, size: 46),
              const SizedBox(height: 10),
              Text(
                'Drop or open a 3D model',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.folder_open),
                label: const Text('Open STL / OBJ / 3MF / AMF'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class MeshViewport extends StatefulWidget {
  const MeshViewport({super.key, required this.mesh});
  final Mesh mesh;

  @override
  State<MeshViewport> createState() => _MeshViewportState();
}

class _MeshViewportState extends State<MeshViewport> {
  double yaw = -.65;
  double pitch = .82;
  double zoom = 1;
  Offset? last;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onPanStart: (d) => last = d.localPosition,
    onPanUpdate: (d) {
      final prev = last;
      if (prev == null) return;
      final delta = d.localPosition - prev;
      last = d.localPosition;
      setState(() {
        yaw += delta.dx * .008;
        pitch = (pitch + delta.dy * .008).clamp(-1.45, 1.45).toDouble();
      });
    },
    onScaleUpdate: (d) {
      if (d.pointerCount > 1) {
        setState(() => zoom = (zoom * d.scale).clamp(.25, 8.0).toDouble());
      }
    },
    onDoubleTap: () => setState(() {
      yaw = -.65;
      pitch = .82;
      zoom = 1;
    }),
    child: CustomPaint(
      painter: _MeshPainter(
        mesh: widget.mesh,
        yaw: yaw,
        pitch: pitch,
        zoom: zoom,
      ),
      child: const SizedBox.expand(),
    ),
  );
}

class _BedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const schemeColor = Color(0xFF52575A);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE9EAEB),
    );
    final bedW = size.width * .72;
    final bedH = size.height * .72;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: bedW,
      height: bedH,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(18)),
      Paint()..color = schemeColor,
    );
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .18)
      ..strokeWidth = 1;
    for (var i = 1; i < 20; i++) {
      final x = rect.left + rect.width * i / 20;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), grid);
      final y = rect.top + rect.height * i / 20;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(18)),
      Paint()
        ..color = Colors.white.withValues(alpha: .35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MeshPainter extends CustomPainter {
  _MeshPainter({
    required this.mesh,
    required this.yaw,
    required this.pitch,
    required this.zoom,
  });
  final Mesh mesh;
  final double yaw, pitch, zoom;

  @override
  void paint(Canvas canvas, Size size) {
    _BedPainter().paint(canvas, size);
    final bounds = mesh.bounds;
    final center = bounds.center;
    final extent = math.max(
      bounds.width,
      math.max(bounds.depth, bounds.height),
    );
    if (extent <= 0 || !extent.isFinite) return;
    final scale = math.min(size.width, size.height) * .55 / extent * zoom;
    Offset project(Point3 point) {
      var x = point.x - center.x;
      var y = point.y - center.y;
      var z = point.z - center.z;
      final cy = math.cos(yaw);
      final sy = math.sin(yaw);
      final x1 = x * cy - y * sy;
      final y1 = x * sy + y * cy;
      x = x1;
      y = y1;
      final cp = math.cos(pitch);
      final sp = math.sin(pitch);
      final y2 = y * cp - z * sp;
      z = y * sp + z * cp;
      y = y2;
      final perspective = 1 / (1 + (z / extent) * .22);
      return Offset(
        size.width / 2 + x * scale * perspective,
        size.height / 2 + y * scale * perspective,
      );
    }

    final path = Path();
    const maxTriangles = 28000;
    final step = math.max(1, (mesh.triangles.length / maxTriangles).ceil());
    for (var i = 0; i < mesh.triangles.length; i += step) {
      final t = mesh.triangles[i];
      final a = project(t.a);
      final b = project(t.b);
      final c = project(t.c);
      path.moveTo(a.dx, a.dy);
      path.lineTo(b.dx, b.dy);
      path.lineTo(c.dx, c.dy);
      path.close();
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF0875EE).withValues(alpha: .85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
  }

  @override
  bool shouldRepaint(covariant _MeshPainter old) =>
      old.mesh != mesh ||
      old.yaw != yaw ||
      old.pitch != pitch ||
      old.zoom != zoom;
}

enum _TransformKind { move, rotate, scale }

class _TransformDialog extends StatefulWidget {
  const _TransformDialog({required this.kind});
  final _TransformKind kind;

  @override
  State<_TransformDialog> createState() => _TransformDialogState();
}

class _TransformDialogState extends State<_TransformDialog> {
  late final TextEditingController x;
  late final TextEditingController y;
  late final TextEditingController z;

  @override
  void initState() {
    super.initState();
    final initial = widget.kind == _TransformKind.scale ? '1' : '0';
    x = TextEditingController(text: initial);
    y = TextEditingController(text: initial);
    z = TextEditingController(text: initial);
  }

  @override
  void dispose() {
    x.dispose();
    y.dispose();
    z.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.kind) {
      _TransformKind.move => 'Move model',
      _TransformKind.rotate => 'Rotate model',
      _TransformKind.scale => 'Scale model',
    };
    final suffix = switch (widget.kind) {
      _TransformKind.move => 'mm',
      _TransformKind.rotate => '°',
      _TransformKind.scale => '×',
    };
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: Row(
          children: [
            Expanded(child: _axisField('X', x, suffix)),
            const SizedBox(width: 8),
            Expanded(child: _axisField('Y', y, suffix)),
            const SizedBox(width: 8),
            Expanded(child: _axisField('Z', z, suffix)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final vx = double.tryParse(x.text.replaceAll(',', '.'));
            final vy = double.tryParse(y.text.replaceAll(',', '.'));
            final vz = double.tryParse(z.text.replaceAll(',', '.'));
            if (vx == null || vy == null || vz == null) return;
            if (widget.kind == _TransformKind.scale &&
                (vx == 0 || vy == 0 || vz == 0)) {
              return;
            }
            Navigator.pop(context, Point3(vx, vy, vz));
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _axisField(
    String label,
    TextEditingController controller,
    String suffix,
  ) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    decoration: InputDecoration(labelText: label, suffixText: suffix),
  );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
