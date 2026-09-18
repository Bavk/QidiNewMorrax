import 'package:flutter/material.dart';

import '../../calibration/presentation/calibration_page.dart';
import '../../device/presentation/device_page.dart';
import '../../prepare/presentation/prepare_page.dart';
import '../../preview/presentation/preview_page.dart';
import '../../project/presentation/project_page.dart';
import '../../../core/orca/orca_slicer_engine.dart';
import '../application/workspace_controller.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  var _index = 0;
  final _workspace = WorkspaceController();

  @override
  void initState() {
    super.initState();
    _workspace.addListener(_workspaceChanged);
  }

  @override
  void dispose() {
    _workspace.removeListener(_workspaceChanged);
    _workspace.dispose();
    super.dispose();
  }

  void _workspaceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _slicePlate() async {
    try {
      await _workspace.slice();
      if (!mounted) return;
      setState(() => _index = 1);
    } on OrcaSlicerCancelledException {
      return;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  static const _destinations = [
    (Icons.layers_outlined, 'Prepare'),
    (Icons.view_in_ar_outlined, 'Preview'),
    (Icons.qr_code_scanner_outlined, 'Device'),
    (Icons.list_alt_outlined, 'Project'),
    (Icons.tune_outlined, 'Calibration'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        children: [
          Material(
            color: scheme.surfaceContainerHighest,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 64,
                child: Row(
                  children: [
                    const SizedBox(width: 10),
                    const IconButton(
                      onPressed: null,
                      icon: Icon(Icons.menu),
                      tooltip: 'Application menu parity pending',
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Qidi Flow',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 28),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (var i = 0; i < _destinations.length; i++)
                                _TopDestination(
                                  icon: _destinations[i].$1,
                                  label: _destinations[i].$2,
                                  selected: i == _index,
                                  onTap: () => setState(() => _index = i),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_index == 0) ...[
                      Tooltip(
                        message: _workspace.slicing
                            ? (_workspace.statusMessage ?? 'Cancel current slice')
                            : _workspace.canSlice
                            ? 'Slice with OrcaSlicer ${OrcaSlicerEngine.pinnedVersion}'
                            : 'Select a model, printer, process and filament',
                        child: FilledButton.icon(
                          onPressed: _workspace.slicing
                              ? _workspace.cancelSlice
                              : _workspace.canSlice
                              ? _slicePlate
                              : null,
                          icon: _workspace.slicing
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    value: _workspace.slicingPercent == null
                                        ? null
                                        : _workspace.slicingPercent! / 100,
                                  ),
                                )
                              : const Icon(Icons.content_cut_outlined, size: 18),
                          label: Text(
                            _workspace.slicing
                                ? _workspace.slicingPercent == null
                                      ? 'Cancel slice'
                                      : 'Cancel ${_workspace.slicingPercent}%'
                                : 'Slice plate',
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                PreparePage(controller: _workspace),
                PreviewPage(
                  gcodePath: _workspace.lastGcodePath,
                  gcodePathsByPlate: _workspace.lastGcodePathsByPlate,
                  selectedPlate: _workspace.lastSelectedPlate,
                  sliceMetadata: _workspace.lastSelectedPlateMetadata,
                  onPlateChanged: _workspace.selectLastPlate,
                ),
                DevicePage(
                  gcodePath: _workspace.lastGcodePath,
                  sliceMetadata: _workspace.lastSelectedPlateMetadata,
                ),
                const ProjectPage(),
                const CalibrationPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopDestination extends StatelessWidget {
  const _TopDestination({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
