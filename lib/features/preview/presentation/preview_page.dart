import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/gcode/gcode_parser.dart';

class PreviewPage extends StatefulWidget {
  const PreviewPage({super.key});

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  GCodeStats? stats;
  List<_LayerPath> layers = const [];
  int layerIndex = 0;
  String? fileName;
  Object? error;
  bool loading = false;

  Future<void> _open() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['gcode', 'gco', 'gc'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final bytes = file.bytes ??
          (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null) throw StateError('Could not read ${file.name}');
      final text = utf8.decode(bytes, allowMalformed: true);
      const parser = GCodeParser();
      stats = parser.stats(text);
      layers = _buildLayers(parser, text);
      layerIndex = layers.isEmpty ? 0 : layers.length - 1;
      fileName = file.name;
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = layers.isEmpty
        ? null
        : layers[layerIndex.clamp(0, layers.length - 1).toInt()];
    return Column(
      children: [
        SizedBox(
          height: 58,
          child: Row(
            children: [
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: loading ? null : _open,
                icon: const Icon(Icons.folder_open),
                label: const Text('Open G-code'),
              ),
              const SizedBox(width: 12),
              if (fileName != null)
                Expanded(
                  child: Text(fileName!, overflow: TextOverflow.ellipsis),
                ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: layers.isEmpty
              ? _EmptyPreview(error: error, onOpen: _open)
              : Row(
                  children: [
                    SizedBox(
                      width: 300,
                      child: _StatsPanel(
                        stats: stats!,
                        layers: layers.length,
                        current: current!,
                      ),
                    ),
                    const VerticalDivider(),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _ToolpathPainter(layer: current!),
                            ),
                          ),
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 14,
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'Layer ${layerIndex + 1}/${layers.length}  Z=${current.z.toStringAsFixed(3)}',
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Slider(
                                        value: layerIndex.toDouble(),
                                        min: 0,
                                        max: math.max(0, layers.length - 1).toDouble(),
                                        divisions: layers.length > 1
                                            ? layers.length - 1
                                            : null,
                                        onChanged: (v) => setState(
                                          () => layerIndex = v.round(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  static List<_LayerPath> _buildLayers(GCodeParser parser, String text) {
    var x = 0.0;
    var y = 0.0;
    var z = 0.0;
    var e = 0.0;
    var absolute = true;
    var absoluteE = true;
    final byZ = <double, List<_MoveSegment>>{};
    for (final cmd in parser.parse(text)) {
      if (cmd.command == 'G90') {
        absolute = true;
        continue;
      }
      if (cmd.command == 'G91') {
        absolute = false;
        continue;
      }
      if (cmd.command == 'M82') {
        absoluteE = true;
        continue;
      }
      if (cmd.command == 'M83') {
        absoluteE = false;
        continue;
      }
      if (cmd.command == 'G92') {
        x = cmd.number('X') ?? x;
        y = cmd.number('Y') ?? y;
        z = cmd.number('Z') ?? z;
        e = cmd.number('E') ?? e;
        continue;
      }
      if (cmd.command != 'G0' && cmd.command != 'G1') continue;
      final px = x;
      final py = y;
      final pe = e;
      final vx = cmd.number('X');
      final vy = cmd.number('Y');
      final vz = cmd.number('Z');
      final ve = cmd.number('E');
      x = vx == null ? x : (absolute ? vx : x + vx);
      y = vy == null ? y : (absolute ? vy : y + vy);
      z = vz == null ? z : (absolute ? vz : z + vz);
      e = ve == null ? e : (absoluteE ? ve : e + ve);
      if (px == x && py == y) continue;
      final key = (z * 10000).round() / 10000.0;
      final segments = byZ.putIfAbsent(key, () => <_MoveSegment>[]);
      segments.add(_MoveSegment(px, py, x, y, extrusion: e > pe + 1e-8));
    }
    final zs = byZ.keys.toList()..sort();
    return [
      for (final zz in zs) _LayerPath(zz, List.unmodifiable(byZ[zz]!)),
    ];
  }
}

class _MoveSegment {
  const _MoveSegment(
    this.x1,
    this.y1,
    this.x2,
    this.y2, {
    required this.extrusion,
  });
  final double x1, y1, x2, y2;
  final bool extrusion;
}

class _LayerPath {
  const _LayerPath(this.z, this.segments);
  final double z;
  final List<_MoveSegment> segments;
}

class _EmptyPreview extends StatelessWidget {
  const _EmptyPreview({required this.error, required this.onOpen});
  final Object? error;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.route_outlined, size: 52),
                const SizedBox(height: 12),
                Text(
                  'G-code preview',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Open a G-code file to inspect layers, moves and basic statistics.',
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error.toString()),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Open G-code'),
                ),
              ],
            ),
          ),
        ),
      );
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({
    required this.stats,
    required this.layers,
    required this.current,
  });
  final GCodeStats stats;
  final int layers;
  final _LayerPath current;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text(
            'Preview',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          _row('Layers', '$layers'),
          _row('Moves', '${stats.moveCount}'),
          _row('Extrusion moves', '${stats.extrusionMoveCount}'),
          _row('Travel', '${stats.travelDistanceMm.toStringAsFixed(1)} mm'),
          _row('Extrusion', '${stats.extrusionMm.toStringAsFixed(1)} mm'),
          _row(
            'X',
            '${stats.minX.toStringAsFixed(1)}…${stats.maxX.toStringAsFixed(1)}',
          ),
          _row(
            'Y',
            '${stats.minY.toStringAsFixed(1)}…${stats.maxY.toStringAsFixed(1)}',
          ),
          _row(
            'Z',
            '${stats.minZ.toStringAsFixed(2)}…${stats.maxZ.toStringAsFixed(2)}',
          ),
          _row(
            'Temperatures',
            stats.temperatures.map((e) => e.round()).join(', '),
          ),
          const Divider(height: 28),
          Text('Current layer', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _row('Z', current.z.toStringAsFixed(3)),
          _row('Segments', '${current.segments.length}'),
          _row(
            'Extrusions',
            '${current.segments.where((s) => s.extrusion).length}',
          ),
        ],
      );

  Widget _row(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(a)),
            Flexible(
              child: Text(
                b,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

class _ToolpathPainter extends CustomPainter {
  _ToolpathPainter({required this.layer});
  final _LayerPath layer;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF202426));
    if (layer.segments.isEmpty) return;
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final s in layer.segments) {
      minX = math.min(minX, math.min(s.x1, s.x2));
      maxX = math.max(maxX, math.max(s.x1, s.x2));
      minY = math.min(minY, math.min(s.y1, s.y2));
      maxY = math.max(maxY, math.max(s.y1, s.y2));
    }
    final w = math.max(1.0, maxX - minX);
    final h = math.max(1.0, maxY - minY);
    final scale = math.min((size.width - 60) / w, (size.height - 60) / h);
    Offset p(double x, double y) => Offset(
          (x - (minX + maxX) / 2) * scale + size.width / 2,
          (y - (minY + maxY) / 2) * scale + size.height / 2,
        );
    final travel = Paint()
      ..color = Colors.white.withOpacity(.18)
      ..strokeWidth = 1;
    final extrusion = Paint()
      ..color = const Color(0xFF45A3FF)
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round;
    for (final s in layer.segments) {
      canvas.drawLine(
        p(s.x1, s.y1),
        p(s.x2, s.y2),
        s.extrusion ? extrusion : travel,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ToolpathPainter old) => old.layer != layer;
}
